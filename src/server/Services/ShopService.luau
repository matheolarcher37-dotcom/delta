-- LE MARCHAND AMBULANT : il vend les OBJETS D'ÉVOLUTION (Config/EvolutionItems) contre des pièces.
-- Toutes les 8 minutes, il change de coin de la carte (Layout.MerchantSpots) et renouvelle son
-- stock (identique sur tous les serveurs). Un grand rayon violet monte de son échoppe jusqu'au
-- ciel pour qu'on le trouve de partout. Il faut aller le voir pour acheter.
-- (Remplace l'ancienne « Machine à Reliques » : les reliques ne sont plus vendues.)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local EvolutionItems = require(Shared.Config.EvolutionItems)
local Layout = require(Shared.Config.Layout)
local Formulas = require(Shared.Modules.Formulas)
local Remotes = require(Shared.Modules.Remotes)
local WorldBuilder = require(script.Parent.Parent.World.WorldBuilder)
local Merchant = require(script.Parent.Parent.World.Merchant)

local ShopService = {}

local Notify = Remotes.event("Notify")
local OpenMenu = Remotes.event("OpenMenu")

function ShopService:Init(services)
	self.services = services
	self.model = nil :: Model?
	self.window = -1
	self.stockKey = ""
	self.stock = {}
	self.spot = 1
	self.position = Layout.MerchantSpots[1]
end

local function now(): number
	return os.time()
end

function ShopService:_universeId(): string?
	local universe = self.services.UniverseService and self.services.UniverseService:GetCurrent()
	return universe and universe.id or nil
end

-- Achats du joueur pendant le passage actuel (remis à zéro à chaque nouveau passage).
local function boughtFor(data, window: number)
	if type(data.shop) ~= "table" then
		data.shop = { window = window, bought = {} }
	end
	if data.shop.window ~= window or type(data.shop.bought) ~= "table" then
		data.shop.window = window
		data.shop.bought = {}
	end
	return data.shop.bought
end

-- Met à jour le coin et le stock si le passage (ou l'univers) a changé. Retourne vrai si le
-- marchand vient de changer de coin.
function ShopService:Refresh(): boolean
	local window = EvolutionItems.window(now())
	local universeId = self:_universeId()
	local key = window .. ":" .. tostring(universeId)
	local moved = false
	if window ~= self.window then
		moved = self.window ~= -1
		self.window = window
		self.spot = EvolutionItems.spotIndex(window, #Layout.MerchantSpots)
		if self.model then
			local cf = Merchant.place(self.model, self.spot, WorldBuilder.groundY)
			self.position = cf.Position
		else
			self.position = Merchant.spotCFrame(self.spot, WorldBuilder.groundY).Position
		end
	end
	if key ~= self.stockKey then
		self.stockKey = key
		self.stock = EvolutionItems.stock(window, universeId)
		if self.model then
			local ids = {}
			for _, entry in self.stock do
				table.insert(ids, entry.id)
			end
			Merchant.setDisplay(self.model, ids)
		end
	end
	local state = ReplicatedStorage:FindFirstChild("GameState")
	if state then
		local moveAt = (window + 1) * EvolutionItems.Merchant.Period
		state:SetAttribute("MerchantMoveAt", moveAt)
		state:SetAttribute("ShopRestockAt", moveAt) -- (pastille du HUD)
		state:SetAttribute("MerchantPosition", self.position)
		state:SetAttribute("MerchantSpot", self.spot)
	end
	return moved
end

-- État envoyé à l'écran du marchand.
function ShopService:GetState(player: Player)
	self:Refresh()
	local data = self.services.DataService:Get(player)
	local bought = data and boughtFor(data, self.window) or {}
	local items = {}
	for _, entry in self.stock do
		local item = EvolutionItems.get(entry.id)
		if item then
			table.insert(items, {
				id = entry.id,
				price = item.price,
				stock = entry.stock,
				remaining = math.max(0, entry.stock - (bought[entry.id] or 0)),
			})
		end
	end
	return {
		window = self.window,
		moveAt = (self.window + 1) * EvolutionItems.Merchant.Period,
		universeId = self:_universeId(),
		spot = self.spot,
		position = self.position,
		near = player and self:IsNear(player) or false,
		items = items,
	}
end

function ShopService:CounterPosition(): Vector3
	if self.model and self.model.Parent then
		return Merchant.counterPosition(self.model)
	end
	return self.position
end

function ShopService:IsNear(player: Player): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return false
	end
	local delta = root.Position - self:CounterPosition()
	return Vector3.new(delta.X, 0, delta.Z).Magnitude <= EvolutionItems.Merchant.BuyDistance
end

function ShopService:Buy(player: Player, itemId: any)
	local DataService = self.services.DataService
	local data = DataService:Get(player)
	if not data or type(itemId) ~= "string" then
		return false, "Erreur."
	end
	self:Refresh()
	local item = EvolutionItems.get(itemId)
	local entry
	for _, candidate in self.stock do
		if candidate.id == itemId then
			entry = candidate
		end
	end
	if not item or not entry then
		return false, "Le marchand n'a plus cet objet (il a changé de stock) !"
	end
	if not self:IsNear(player) then
		return false, "Va voir le Marchand pour acheter : suis le rayon violet !"
	end
	local bought = boughtFor(data, self.window)
	local already = bought[itemId] or 0
	if already >= entry.stock then
		return false, "Rupture de stock ! Le marchand en aura peut-être au prochain passage."
	end
	if data.coins < item.price then
		return false, "Il te manque ¥ " .. Formulas.formatNumber(item.price - data.coins)
	end
	if not DataService:SpendCoins(player, item.price) then
		return false, "Pas assez de pièces."
	end
	bought[itemId] = already + 1
	DataService:AddItem(player, itemId, 1)
	return true, "Tu as acheté : " .. item.name .. " !"
end

function ShopService:_ensureModel()
	local world = Workspace:FindFirstChild("World")
	if not world then
		return
	end
	local model = world:FindFirstChild("Merchant")
	if not model or not model:IsA("Model") then
		-- Fichier construit avant l'arrivée du marchand : on le construit maintenant.
		local ok, result = pcall(Merchant.build, world, WorldBuilder.groundY)
		if not ok then
			warn("[AnimeTycoon] Marchand non construit : " .. tostring(result))
			return
		end
		model = result
	end
	self.model = model :: Model
	local prompt = model:FindFirstChild("MerchantPrompt", true)
	if prompt and prompt:IsA("ProximityPrompt") then
		prompt.Triggered:Connect(function(player)
			OpenMenu:FireClient(player, "Shop")
		end)
	end
end

function ShopService:Start()
	self:_ensureModel()
	self:Refresh()

	Remotes.func("Merchant_GetStock").OnServerInvoke = function(player)
		return self:GetState(player)
	end
	Remotes.func("Merchant_Buy").OnServerInvoke = function(player, itemId)
		local ok, message = self:Buy(player, itemId)
		if not ok and message then
			Notify:FireClient(player, message, "error")
		end
		return ok, message, self:GetState(player)
	end

	-- Déménagements du marchand + compte à rebours sur son étiquette.
	task.spawn(function()
		while true do
			task.wait(1)
			local moved = self:Refresh()
			if self.model then
				local remaining = (self.window + 1) * EvolutionItems.Merchant.Period - now()
				Merchant.setStatus(self.model, "Repart dans " .. Formulas.formatTime(remaining))
			end
			if moved and #Players:GetPlayers() > 0 then
				local best
				for _, entry in self.stock do
					local item = EvolutionItems.get(entry.id)
					if item and item.tier == 3 and (not best or item.price > best.price) then
						best = item
					end
				end
				Notify:FireAllClients("Le Marchand s'est installé dans un autre coin : suis le rayon violet !" .. (best and (" (" .. best.name .. " en stock)") or ""), "info")
			end
		end
	end)
end

return ShopService
