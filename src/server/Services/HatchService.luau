-- Autels de reliques : on pose une relique, on attend, puis on l'ouvre pour obtenir un perso
-- (l'équivalent des œufs de "Grow a Chicken Fighter").

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Economy = require(Shared.Config.Economy)
local Universes = require(Shared.Config.Universes)
local Characters = require(Shared.Config.Characters)
local Rarities = require(Shared.Config.Rarities)
local Auras = require(Shared.Config.Auras)
local Formulas = require(Shared.Modules.Formulas)
local Remotes = require(Shared.Modules.Remotes)
local RelicBuilder = require(Shared.Modules.RelicBuilder)

local HatchService = {}

local Notify = Remotes.event("Notify")
local OpenMenu = Remotes.event("OpenMenu")
local HatchReveal = Remotes.event("HatchReveal")
local Announce = Remotes.event("Announce")

local rng = Random.new()

function HatchService:Init(services)
	self.services = services
end

function HatchService:Start()
	for _, plot in self.services.PlotService:GetPlots() do
		for _, pedestal in plot.pedestals do
			self:ConnectPedestal(plot, pedestal)
		end
	end

	Remotes.func("PlaceRelic").OnServerInvoke = function(player, slot, relicId)
		local ok, message = self:Place(player, slot, relicId)
		if not ok and message then
			Notify:FireClient(player, message, "error")
		end
		return ok, message
	end

	self.services.DataService:OnPlayerLoaded(function(player, data)
		-- Relique offerte au premier lancement : celle de l'univers actuel.
		if not data.starterGiven then
			data.starterGiven = true
			local universe = self.services.UniverseService:GetCurrent()
			local starter = universe.relics[1]
			data.relics[starter.id] = (data.relics[starter.id] or 0) + 1
			task.delay(3, function()
				Notify:FireClient(player, "🎁 Cadeau de bienvenue : " .. starter.name .. " ! Pose-la sur l'autel de ta base.", "success")
			end)
		end
		self:RefreshPedestals(player)
	end)

	-- Met à jour le texte "Prêt !" quand une relique a fini.
	task.spawn(function()
		while true do
			task.wait(1)
			for _, plot in self.services.PlotService:GetPlots() do
				if plot.owner then
					for _, pedestal in plot.pedestals do
						local readyAt = pedestal:GetAttribute("ReadyAt")
						local prompt = pedestal.Top:FindFirstChild("Prompt") :: ProximityPrompt
						if readyAt and prompt then
							prompt.ActionText = os.time() >= readyAt and "Ouvrir la relique" or "Patiente..."
							prompt.Enabled = os.time() >= readyAt
						elseif prompt then
							prompt.ActionText = "Placer une relique"
							prompt.Enabled = true
						end
					end
				end
			end
		end
	end)
end

function HatchService:ConnectPedestal(plot, pedestal: Model)
	local prompt = pedestal.Top:FindFirstChild("Prompt") :: ProximityPrompt
	if not prompt or pedestal:GetAttribute("Connected") then
		return
	end
	pedestal:SetAttribute("Connected", true)
	prompt.Triggered:Connect(function(player)
		if plot.owner ~= player then
			Notify:FireClient(player, "Ce n'est pas ta base !", "error")
			return
		end
		local slot = pedestal:GetAttribute("Slot")
		local data = self.services.DataService:Get(player)
		if not data then
			return
		end
		local incubator = data.incubators[tostring(slot)]
		if incubator then
			self:Open(player, slot)
		else
			OpenMenu:FireClient(player, "PlaceRelic", slot)
		end
	end)
end

-- Affiche les reliques posées sur les autels du joueur.
function HatchService:RefreshPedestals(player: Player)
	local plot = self.services.PlotService:GetPlot(player)
	local data = self.services.DataService:Get(player)
	if not plot or not data then
		return
	end
	for slot, pedestal in plot.pedestals do
		local incubator = data.incubators[tostring(slot)]
		local existing = pedestal:FindFirstChild("RelicModel")
		if incubator then
			local relic = Universes.getRelic(incubator.relic)
			if relic and (not existing or existing:GetAttribute("RelicId") ~= relic.id) then
				if existing then
					existing:Destroy()
				end
				local model = RelicBuilder.build(relic.look, relic.tier, 1)
				model.Name = "RelicModel"
				model:SetAttribute("RelicId", relic.id)
				model:SetAttribute("SpinSpeed", 0.8)
				model:SetAttribute("Bob", 0.4)
				model:PivotTo(pedestal.Top.CFrame * CFrame.new(0, 2.2, 0))
				CollectionService:AddTag(model, "SpinModel")
				model.Parent = pedestal
			end
			pedestal:SetAttribute("RelicId", incubator.relic)
			pedestal:SetAttribute("RelicName", relic and relic.name or "?")
			pedestal:SetAttribute("ReadyAt", incubator.start + incubator.duration)
		else
			if existing then
				existing:Destroy()
			end
			pedestal:SetAttribute("RelicId", nil)
			pedestal:SetAttribute("RelicName", nil)
			pedestal:SetAttribute("ReadyAt", nil)
		end
	end
end

function HatchService:Place(player: Player, slot: any, relicId: any)
	local DataService = self.services.DataService
	local data = DataService:Get(player)
	if not data or type(slot) ~= "number" or type(relicId) ~= "string" then
		return false, "Erreur."
	end
	local plot = self.services.PlotService:GetPlot(player)
	if not plot or not plot.pedestals[slot] then
		return false, "Autel introuvable."
	end
	local key = tostring(slot)
	if data.incubators[key] then
		return false, "Cet autel est déjà occupé."
	end
	if (data.relics[relicId] or 0) < 1 then
		return false, "Tu n'as pas cette relique."
	end
	local relic = Universes.getRelic(relicId)
	if not relic then
		return false, "Relique inconnue."
	end
	local stats = Formulas.upgradeStats(data.upgrades)
	local duration = math.max(3, math.floor(Economy.RelicTiers[relic.tier].hatchTime * stats.hatchSpeed))
	DataService:AddRelic(player, relicId, -1)
	data.incubators[key] = { relic = relicId, start = os.time(), duration = duration }
	DataService:Sync(player)
	self:RefreshPedestals(player)
	return true, relic.name .. " posée ! Ouverture dans " .. duration .. "s"
end

-- Tire un perso selon les probabilités de la relique.
function HatchService:Roll(relic)
	local universe = Universes.get(relic.universe)
	local byRarity = {}
	for _, id in universe.characters do
		local def = Characters.get(id)
		if def then
			byRarity[def.rarity] = byRarity[def.rarity] or {}
			table.insert(byRarity[def.rarity], id)
		end
	end
	local total = 0
	for rarity, weight in relic.odds do
		if byRarity[rarity] then
			total += weight
		end
	end
	local roll = rng:NextNumber() * total
	local chosenRarity = nil
	for _, rarity in Rarities.Order do
		local weight = relic.odds[rarity]
		if weight and byRarity[rarity] then
			roll -= weight
			if roll <= 0 then
				chosenRarity = rarity
				break
			end
		end
	end
	if not chosenRarity then
		for _, rarity in Rarities.Order do
			if relic.odds[rarity] and byRarity[rarity] then
				chosenRarity = rarity
			end
		end
	end
	local pool = byRarity[chosenRarity]
	return pool[rng:NextInteger(1, #pool)]
end

function HatchService:Open(player: Player, slot: number)
	local DataService = self.services.DataService
	local data = DataService:Get(player)
	if not data then
		return
	end
	local key = tostring(slot)
	local incubator = data.incubators[key]
	if not incubator then
		return
	end
	if os.time() < incubator.start + incubator.duration then
		Notify:FireClient(player, "La relique n'est pas encore prête !", "error")
		return
	end
	if DataService:CharacterCount(player) >= Economy.MaxCharacters then
		Notify:FireClient(player, "Inventaire plein (" .. Economy.MaxCharacters .. ") ! Vends des persos.", "error")
		return
	end
	local relic = Universes.getRelic(incubator.relic)
	if not relic then
		data.incubators[key] = nil
		return
	end
	data.incubators[key] = nil
	local characterId = self:Roll(relic)
	local luck = self.services.EventService and self.services.EventService:AuraLuck() or 1
	local aura = Auras.roll(rng, luck)
	local CharacterService = self.services.CharacterService
	local entry = CharacterService:CreateEntry(characterId, aura)
	local isNewIndex = not data.index[characterId]
	local uid = CharacterService:AddCharacter(player, entry)
	data.stats.hatched += 1
	DataService:Sync(player)
	self:RefreshPedestals(player)
	HatchReveal:FireClient(player, { uid = uid, entry = entry, relicId = relic.id, isNew = isNewIndex })

	-- Annonce serveur pour les tirages exceptionnels.
	local def = Characters.get(characterId)
	local rarity = Rarities.get(def.rarity)
	if rarity.order >= 4 or (aura and Auras.get(aura).multiplier >= 3) then
		local auraText = aura and (" [" .. Auras.get(aura).name .. "]") or ""
		Announce:FireAllClients("✨ " .. player.DisplayName .. " ✨", "a obtenu " .. def.name .. auraText .. " (" .. rarity.name .. ") !", rarity.color)
	end
end

return HatchService
