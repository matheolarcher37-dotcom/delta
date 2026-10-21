-- BOUTIQUE ROBUX (côté serveur) : passes, produits, boosts temporaires et VIP.
--
--   • Robux_Buy(type, clé) : ouvre l'achat Roblox (PromptGamePassPurchase / PromptProductPurchase).
--     Id encore à 0 : message « pas encore configuré » ; dans Studio, achat simulé pour essayer.
--   • Passes : UserOwnsGamePassAsync à l'arrivée (pcall + cache), PromptGamePassPurchaseFinished.
--   • Produits : ProcessReceipt IDEMPOTENT. Chaque reçu (PurchaseId) est noté dans les données du
--     joueur ; on ne répond PurchaseGranted qu'une fois la sauvegarde réussie. Un reçu déjà noté
--     n'est jamais redonné (Roblox peut rappeler ProcessReceipt plusieurs fois).
--   • Effets : attributs "Pass_<Clé>" = true et "Boost_<Clé>" = heure de fin (os.time()) sur le
--     joueur, lus par les autres services (Config/Robux : coinMultiplier, luckMultiplier...).
--   • VIP : couronne au-dessus de la tête (le nom doré dans le chat est géré côté client).

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Robux = require(Shared.Config.Robux)
local Formulas = require(Shared.Modules.Formulas)
local Remotes = require(Shared.Modules.Remotes)

local MonetizationService = {}

local Notify = Remotes.event("Notify")
local Granted = Remotes.event("Robux_Granted")

local RETRY_DELAYS = { 2, 5, 10 } -- nouvelles tentatives si UserOwnsGamePassAsync échoue (secondes)
local MAX_RECEIPTS = 200 -- reçus gardés dans la sauvegarde (les plus anciens partent)
local ownsCache: { [number]: { [number]: boolean } } = {} -- [UserId][passId] = possédé
local processing: { [string]: boolean } = {} -- reçus en cours de traitement
local lastRequest: { [Player]: number } = {}
local passListeners: { (Player, string) -> () } = {}
local passesChecked: { [Player]: boolean } = {} -- 1re vérification des passes terminée à l'arrivée

-- Un reçu rejoué à la connexion (pack de pièces acheté hors ligne...) attend au plus ce temps
-- (secondes) la 1re vérification des passes : x2 Argent et VIP comptent dans le montant du pack.
MonetizationService.PassCheckWait = 5

local function isStudio(): boolean
	local ok, result = pcall(function()
		return RunService:IsStudio()
	end)
	return ok and result == true
end

function MonetizationService:Init(services)
	self.services = services
end

function MonetizationService:Start()
	local DataService = self.services.DataService

	DataService:OnPlayerLoaded(function(player, data)
		self:_setup(player, data)
	end)
	Players.PlayerRemoving:Connect(function(player)
		ownsCache[player.UserId] = nil
		lastRequest[player] = nil
		passesChecked[player] = nil
	end)

	Remotes.func("Robux_Buy").OnServerInvoke = function(player, kind, key)
		return self:RequestPurchase(player, kind, key)
	end
	-- Raccourci pour les autres fenêtres (ex. « Roulement automatique ») : achat d'un passe par sa clé.
	Remotes.func("Robux_BuyPass").OnServerInvoke = function(player, key)
		local ok, message = self:RequestPurchase(player, "pass", key)
		if type(message) == "string" and message ~= "" then
			Notify:FireClient(player, message, ok and "success" or "error")
		end
		return ok, message
	end

	pcall(function()
		MarketplaceService.ProcessReceipt = function(info)
			return self:ProcessReceipt(info)
		end
	end)
	pcall(function()
		MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
			if purchased then
				self:_onPassBought(player, passId)
			else
				-- Fenêtre fermée sans achat... ou « déjà possédé » (vérification ratée à l'arrivée) :
				-- on redemande à Roblox, sans cache, et on accorde le passe s'il est à lui.
				task.spawn(self._recheckPass, self, player, passId)
			end
		end)
	end)

	-- Fin des boosts temporaires.
	task.spawn(function()
		while true do
			task.wait(5)
			for _, player in Players:GetPlayers() do
				local ok, err = pcall(self._checkBoosts, self, player)
				if not ok then
					warn("[AnimeTycoon] Boosts : " .. tostring(err))
				end
			end
		end
	end)
end

------------------------------------------------------------------------
-- Arrivée du joueur
------------------------------------------------------------------------

function MonetizationService:_setup(player: Player, data)
	player:SetAttribute("RobuxSpent", data.RobuxSpent or 0)
	-- « Emplacements + » : recalculé à chaque arrivée (gardé si Roblox ne répond pas).
	local previousSlots = data.RobuxSlots or 0
	data.RobuxSlots = 0
	-- Passes simulés dans Studio (jamais appliqués dans le vrai jeu en ligne).
	if isStudio() then
		for key in data.RobuxPasses do
			if Robux.Passes[key] then
				self:_applyPass(player, key, true)
			end
		end
	end
	-- Boosts encore actifs.
	local now = os.time()
	for key, finish in data.RobuxBoosts do
		if Robux.Boosts[key] and finish > now then
			player:SetAttribute("Boost_" .. key, finish)
		else
			data.RobuxBoosts[key] = nil
		end
	end
	-- Passes achetés sur Roblox (vérifiés un par un, sans bloquer l'arrivée). Si Roblox ne
	-- répond pas (erreur passagère), on réessaie avec une attente croissante : un passe payé
	-- ne doit jamais manquer pour toute la session.
	passesChecked[player] = nil
	task.spawn(function()
		local pending = {}
		local ok, err = pcall(function()
			for key, pass in Robux.Passes do
				if Robux.isConfigured(pass) and not Robux.hasPass(player, key) and player.Parent then
					local owns, checked = self:Owns(player, pass.id)
					if owns then
						self:_applyPass(player, key, true)
					elseif not checked then
						table.insert(pending, key)
						if key == "Slots" and previousSlots > 0 then
							data.RobuxSlots = previousSlots -- erreur passagère de Roblox : on garde les cases
							self:_refreshSlots(player)
						end
					end
				end
			end
		end)
		-- 1re vérification finie (même en erreur) : les reçus en attente peuvent être accordés.
		passesChecked[player] = true
		if not ok then
			warn("[AnimeTycoon] Vérification des passes de " .. player.Name .. " : " .. tostring(err))
		end
		for _, delay in RETRY_DELAYS do
			if #pending == 0 or not player.Parent then
				break
			end
			task.wait(delay)
			local still = {}
			for _, key in pending do
				local pass = Robux.Passes[key]
				if player.Parent and not Robux.hasPass(player, key) then
					local owns, checked = self:Owns(player, pass.id)
					if owns then
						self:_applyPass(player, key)
					elseif not checked then
						table.insert(still, key)
					end
				end
			end
			pending = still
		end
		if #pending > 0 and player.Parent then
			warn("[AnimeTycoon] Roblox n'a pas confirmé les passes de " .. player.Name .. " : " .. table.concat(pending, ", "))
		end
	end)
	-- VIP : couronne à chaque réapparition.
	player.CharacterAdded:Connect(function(character)
		if Robux.hasPass(player, "VIP") then
			task.defer(self._vipTag, self, character)
		end
	end)
	if player.Character and Robux.hasPass(player, "VIP") then
		self:_vipTag(player.Character)
	end
end

-- 1re vérification des passes du joueur terminée (à l'arrivée) ?
function MonetizationService:PassesChecked(player: Player): boolean
	return passesChecked[player] == true
end

-- Le joueur possède-t-il ce passe Roblox ? (pcall + cache ; une erreur n'est pas mise en cache)
-- Renvoie (possédé, vérifié) : vérifié = false si Roblox n'a pas pu répondre.
function MonetizationService:Owns(player: Player, passId: number): (boolean, boolean)
	local cache = ownsCache[player.UserId]
	if cache and cache[passId] ~= nil then
		return cache[passId], true
	end
	local ok, owns = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, passId)
	end)
	if not ok then
		return false, false
	end
	ownsCache[player.UserId] = cache or {}
	ownsCache[player.UserId][passId] = owns == true
	return owns == true, true
end

------------------------------------------------------------------------
-- Effets
------------------------------------------------------------------------

-- Appelé quand un passe est accordé (pour les autres services : `callback(player, clé)`).
function MonetizationService:OnPassGranted(callback: (Player, string) -> ())
	table.insert(passListeners, callback)
end

function MonetizationService:_applyPass(player: Player, key: string, silent: boolean?)
	local already = Robux.hasPass(player, key)
	player:SetAttribute("Pass_" .. key, true)
	if key == "Slots" then
		local data = self.services.DataService:Get(player)
		if data and (data.RobuxSlots or 0) < Robux.SlotsBonus then
			data.RobuxSlots = Robux.SlotsBonus
			self:_refreshSlots(player)
		end
	end
	if already then
		return
	end
	if key == "VIP" and player.Character then
		self:_vipTag(player.Character)
	end
	for _, callback in passListeners do
		task.spawn(callback, player, key)
	end
	if not silent then
		Granted:FireClient(player, "pass", key, {})
	end
end

-- Cases de la base (passe « Emplacements + ») : reconstruit l'affichage des unités.
function MonetizationService:_refreshSlots(player: Player)
	self.services.DataService:Sync(player)
	local CharacterService = self.services.CharacterService
	if CharacterService and CharacterService.Refresh then
		local ok, err = pcall(CharacterService.Refresh, CharacterService, player)
		if not ok then
			warn("[AnimeTycoon] Emplacements + : " .. tostring(err))
		end
	end
end

function MonetizationService:_vipTag(character: Model)
	local head = character:FindFirstChild("Head")
	if not head or not head:IsA("BasePart") or head:FindFirstChild("TagVIP") then
		return
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "TagVIP"
	gui.Size = UDim2.fromOffset(110, 34)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 4.4, 0)
	gui.MaxDistance = 90
	gui.LightInfluence = 0
	gui.AlwaysOnTop = false
	gui.Adornee = head
	local label = Instance.new("TextLabel")
	label.Name = "Texte"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = "👑 VIP"
	label.TextScaled = true
	label.Font = Enum.Font.LuckiestGuy
	label.TextColor3 = Color3.fromRGB(255, 214, 70)
	label.TextStrokeColor3 = Color3.fromRGB(70, 30, 0)
	label.TextStrokeTransparency = 0
	label.Parent = gui
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new(Color3.fromRGB(255, 250, 200), Color3.fromRGB(255, 170, 30))
	gradient.Rotation = 90
	gradient.Parent = label
	gui.Parent = head
end

-- Ajoute la durée d'un boost (les boosts s'additionnent).
function MonetizationService:AddBoost(player: Player, key: string, seconds: number)
	local data = self.services.DataService:Get(player)
	if not data or not Robux.Boosts[key] then
		return
	end
	local now = os.time()
	local finish = math.max(now, data.RobuxBoosts[key] or 0) + math.floor(seconds)
	data.RobuxBoosts[key] = finish
	player:SetAttribute("Boost_" .. key, finish)
	self.services.DataService:Sync(player)
end

function MonetizationService:_checkBoosts(player: Player)
	local data = self.services.DataService:Get(player)
	if not data then
		return
	end
	local now = os.time()
	for key, finish in data.RobuxBoosts do
		if finish <= now then
			data.RobuxBoosts[key] = nil
			player:SetAttribute("Boost_" .. key, nil)
			local boost = Robux.Boosts[key]
			Notify:FireClient(player, "⏳ Boost terminé : " .. (boost and boost.name or key), "info")
			self.services.DataService:Sync(player)
		end
	end
end

function MonetizationService:_addSpent(player: Player, amount: number)
	local data = self.services.DataService:Get(player)
	if not data or type(amount) ~= "number" or amount <= 0 then
		return
	end
	data.RobuxSpent = (data.RobuxSpent or 0) + math.floor(amount)
	player:SetAttribute("RobuxSpent", data.RobuxSpent)
	local Leaderboard = self.services.LeaderboardService
	if Leaderboard and Leaderboard.MarkDirty then
		Leaderboard:MarkDirty(player)
	end
end

------------------------------------------------------------------------
-- Achats
------------------------------------------------------------------------

-- Ouvre l'achat Roblox (ou le simule dans Studio si l'id vaut encore 0).
function MonetizationService:RequestPurchase(player: Player, kind: any, key: any): (boolean, string?)
	if type(kind) ~= "string" or type(key) ~= "string" then
		return false, "Achat inconnu."
	end
	local entry = Robux.get(kind, key)
	if not entry then
		return false, "Achat inconnu."
	end
	local data = self.services.DataService:Get(player)
	if not data then
		return false, "Ta sauvegarde n'est pas encore chargée."
	end
	local now = os.clock()
	if lastRequest[player] and now - lastRequest[player] < 0.6 then
		return false, nil
	end
	lastRequest[player] = now
	if kind == "pass" and Robux.hasPass(player, key) then
		return false, "Tu possèdes déjà « " .. entry.name .. " » !"
	end
	local bigger = kind == "pass" and Robux.coveredBy(player, key)
	if bigger then
		return false, "Déjà inclus dans « " .. Robux.Passes[bigger].name .. " » !"
	end
	if kind == "product" and entry.once and Robux.onceTaken(data, key) then
		return false, "Tu as déjà pris « " .. entry.name .. " » (un seul achat par joueur)."
	end

	if not Robux.isConfigured(entry) then
		if isStudio() and Robux.StudioSimulate then
			if kind == "pass" then
				data.RobuxPasses[key] = "studio"
				self:_applyPass(player, key)
				self.services.DataService:Sync(player)
			else
				self:_grantProduct(player, key)
			end
			return true, "🧪 Achat SIMULÉ (Studio) : « " .. entry.name .. " ». Dans le vrai jeu, colle l'id dans Config/Robux."
		end
		return false, "« " .. entry.name .. " » n'est pas encore configuré (voir le README : créer le passe sur le Creator Hub)."
	end

	local ok, err = pcall(function()
		if kind == "pass" then
			MarketplaceService:PromptGamePassPurchase(player, entry.id)
		else
			MarketplaceService:PromptProductPurchase(player, entry.id)
		end
	end)
	if not ok then
		warn("[AnimeTycoon] Achat impossible (" .. key .. ") : " .. tostring(err))
		return false, "L'achat n'a pas pu s'ouvrir, réessaie."
	end
	return true, nil
end

function MonetizationService:_onPassBought(player: Player, passId: number)
	local key = Robux.passKeyById(passId)
	if not key then
		return
	end
	ownsCache[player.UserId] = ownsCache[player.UserId] or {}
	ownsCache[player.UserId][passId] = true
	if Robux.hasPass(player, key) then
		return
	end
	local price = Robux.Passes[key].price
	local okInfo, info = pcall(function()
		return MarketplaceService:GetProductInfo(passId, Enum.InfoType.GamePass)
	end)
	if okInfo and type(info) == "table" and type(info.PriceInRobux) == "number" then
		price = info.PriceInRobux
	end
	self:_applyPass(player, key)
	self:_addSpent(player, price)
	self.services.DataService:Sync(player)
	self.services.DataService:SaveNow(player)
end

-- Achat refusé ou fermé : si Roblox dit que le joueur possède le passe (achat d'une session
-- précédente dont la vérification avait échoué), on l'accorde sans recompter les Robux.
function MonetizationService:_recheckPass(player: Player, passId: number)
	local key = Robux.passKeyById(passId)
	if not key or Robux.hasPass(player, key) or not player.Parent then
		return
	end
	local cache = ownsCache[player.UserId]
	if cache then
		cache[passId] = nil
	end
	local owns = self:Owns(player, passId)
	if owns and player.Parent then
		self:_applyPass(player, key)
		self.services.DataService:Sync(player)
	end
end

-- Revenu par seconde du joueur calculé depuis ses données (même calcul que la boucle de
-- revenu), pour ne pas dépendre de l'attribut IncomePerSec, absent juste après l'arrivée.
function MonetizationService:_incomePerSec(player: Player): number
	local CharacterService = self.services.CharacterService
	if CharacterService and CharacterService.IncomePerSec then
		local ok, value = pcall(CharacterService.IncomePerSec, CharacterService, player)
		if ok and type(value) == "number" then
			return math.max(value, tonumber(player:GetAttribute("IncomePerSec")) or 0)
		end
	end
	return tonumber(player:GetAttribute("IncomePerSec")) or 0
end

-- Donne le contenu d'un produit. Renvoie le détail (pour l'affichage).
function MonetizationService:_grantProduct(player: Player, key: string)
	local product = Robux.Products[key]
	local DataService = self.services.DataService
	local data = DataService:Get(player)
	assert(product and data, "produit ou données introuvables")
	local details = {}
	if product.kind == "coins" then
		local amount = Robux.coinPackAmount(product, self:_incomePerSec(player))
		DataService:AddCoins(player, amount)
		details.amount = amount
		details.text = "¥ " .. Formulas.formatNumber(amount)
	elseif product.kind == "crystals" then
		data.traitCrystals = (tonumber(data.traitCrystals) or 0) + product.amount
		details.amount = product.amount
		details.text = product.amount .. " gemmes de trait"
		DataService:Sync(player)
	elseif product.kind == "boost" then
		for _, boost in product.boosts do
			self:AddBoost(player, boost, product.duration)
		end
		details.duration = product.duration
		details.text = product.name .. " pendant " .. math.floor(product.duration / 60) .. " min"
	elseif product.kind == "bundle" then
		-- Pack de départ : pièces + gemmes de trait + boost(s).
		local amount = Robux.coinPackAmount(product, self:_incomePerSec(player))
		DataService:AddCoins(player, amount)
		data.traitCrystals = (tonumber(data.traitCrystals) or 0) + (product.crystals or 0)
		for _, boost in product.boosts or {} do
			self:AddBoost(player, boost, product.duration or 0)
		end
		details.amount = amount
		details.text = "¥ " .. Formulas.formatNumber(amount) .. " + " .. (product.crystals or 0) .. " gemmes de trait + Chance x2"
	end
	if product.once then
		data.RobuxOnce = type(data.RobuxOnce) == "table" and data.RobuxOnce or {}
		data.RobuxOnce[key] = os.time()
	end
	DataService:Sync(player)
	Granted:FireClient(player, "product", key, details)
	return details
end

local function trimReceipts(receipts)
	local count = 0
	for _ in receipts do
		count += 1
	end
	while count > MAX_RECEIPTS do
		local oldestKey, oldestTime = nil, math.huge
		for id, at in receipts do
			if at < oldestTime then
				oldestKey, oldestTime = id, at
			end
		end
		if not oldestKey then
			break
		end
		receipts[oldestKey] = nil
		count -= 1
	end
end

-- ProcessReceipt (produits pour développeurs) : idempotent, validé seulement après sauvegarde.
function MonetizationService:ProcessReceipt(info)
	local NotProcessed = Enum.ProductPurchaseDecision.NotProcessedYet
	if type(info) ~= "table" then
		return NotProcessed
	end
	local player = Players:GetPlayerByUserId(info.PlayerId)
	if not player then
		return NotProcessed -- Roblox réessaiera à sa prochaine connexion
	end
	local DataService = self.services.DataService
	-- La sauvegarde peut encore être en train de charger.
	local waited = 0
	while not DataService:IsLoaded(player) and player.Parent and waited < 15 do
		task.wait(0.5)
		waited += 0.5
	end
	-- Reçu rejoué à la connexion : les passes du joueur (x2 Argent, VIP) sont vérifiés juste après
	-- le chargement ; on attend la fin de cette 1re vérification (PassCheckWait s au plus, jamais
	-- plus) pour donner le montant affiché en boutique.
	local passDeadline = os.clock() + MonetizationService.PassCheckWait
	while not passesChecked[player] and DataService:IsLoaded(player) and player.Parent and os.clock() < passDeadline do
		task.wait(0.1)
	end
	local data = DataService:Get(player)
	local key = Robux.productKeyById(info.ProductId)
	if not data or not key then
		if not key then
			warn("[AnimeTycoon] Produit inconnu : " .. tostring(info.ProductId) .. " (vérifie les ids de Config/Robux)")
		end
		return NotProcessed
	end
	local purchaseId = tostring(info.PurchaseId)
	if processing[purchaseId] then
		return NotProcessed
	end
	processing[purchaseId] = true
	if not data.Receipts[purchaseId] then
		local ok, err = pcall(self._grantProduct, self, player, key)
		if not ok then
			processing[purchaseId] = nil
			warn("[AnimeTycoon] Achat non accordé (" .. key .. ") : " .. tostring(err))
			return NotProcessed
		end
		data.Receipts[purchaseId] = os.time()
		trimReceipts(data.Receipts)
		self:_addSpent(player, tonumber(info.CurrencySpent) or Robux.Products[key].price)
		DataService:Sync(player)
	end
	-- Déjà accordé (en mémoire) : il ne reste qu'à l'enregistrer pour de bon.
	local saved = DataService:SaveAndWait(player)
	processing[purchaseId] = nil
	if saved then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	return NotProcessed
end

return MonetizationService
