-- Bases des joueurs (« tycoon ») : construction, attribution, boutons d'achat des améliorations
-- (socle + anneau néon + panneau nom/prix, fantôme de ce qui sera construit, animation de
-- construction), cases d'unités hexagonales, coffre + tapis roulant, compteur d'argent,
-- arbre de compétences lumineux. La machine ROULER est construite ici et animée par RollService.
--
-- Plan et emplacements : src/server/Modules/TycoonStructures.luau (Spots).
-- Déco qui change avec l'univers (sol, murs, portail) : src/server/World/BaseDecor.luau.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Layout = require(Shared.Config.Layout)
local Economy = require(Shared.Config.Economy)
local Rarities = require(Shared.Config.Rarities)
local Universes = require(Shared.Config.Universes)
local Formulas = require(Shared.Modules.Formulas)
local Remotes = require(Shared.Modules.Remotes)
local Modules = script.Parent.Parent.Modules
local Build = require(Modules.Build)
local Kit = require(Modules.TycoonKit)
local Machine = require(Modules.TycoonMachine)
local Slots = require(Modules.TycoonSlots)
local Props = require(Modules.TycoonProps)
local Conveyor = require(Modules.TycoonConveyor)
local Structures = require(Modules.TycoonStructures)
local BaseDecor = require(script.Parent.Parent.World.BaseDecor)

local PlotService = {}

local rgb = Color3.fromRGB
local Notify = Remotes.event("Notify")
local OpenMenu = Remotes.event("OpenMenu")
local CombatFX = Remotes.event("CombatFX")

local Spots = Structures.Spots
local plots = {}
local playerPlots: { [Player]: any } = {}

PlotService.Spots = Spots
PlotService.PedestalSlots = Spots.pedestals
PlotService.SpawnOffset = Spots.spawn
PlotService.StashOffset = Spots.chest + Vector3.new(0, 0, -5.5)

-- Cases d'unités (24) : la case 1 est devant au centre, puis on s'écarte et on recule.
-- (Vector3 locaux, Y = dessus de la dalle.)
PlotService.DisplaySlots = {}
do
	local order = { 3, 4, 2, 5, 1, 6 }
	for _, row in Spots.slotRows do
		for _, col in order do
			table.insert(PlotService.DisplaySlots, Vector3.new(Spots.slotCols[col], Spots.slotHeight, row))
		end
	end
end

------------------------------------------------------------------------
-- Construction statique d'une base
------------------------------------------------------------------------

local function toWorld(plot, x: number, y: number, z: number): CFrame
	return plot.cf * CFrame.new(x, y, z)
end

local function localCF(plot, v: Vector3, yawDeg: number?): CFrame
	return plot.cf * CFrame.new(v) * CFrame.Angles(0, math.rad(yawDeg or 0), 0)
end

local function buildSlots(plot, parent: Instance)
	local folder = Build.folder(parent, "Cases")
	plot.slots = {}
	for i, pos in PlotService.DisplaySlots do
		local cf = toWorld(plot, pos.X, 0, pos.Z)
		plot.slots[i] = Slots.buildSlot(folder, i, cf, Spots.slotRadius, Spots.slotHeight)
	end
	return folder
end

local function buildPlot(index: number, parent: Instance)
	local plot = {
		index = index,
		cf = Layout.plotCFrame(index),
		owner = nil,
	}
	local model = Build.model(parent, "Plot" .. index)
	plot.model = model
	model:SetAttribute("PlotIndex", index)
	BaseDecor.register(plot)
	BaseDecor.apply(plot, Universes.List[1])

	local static = Build.folder(model, "Static")
	-- Chaîne de production : tapis du fond vers le coffre + grand compteur d'argent.
	Conveyor.belt(static, toWorld(plot, Spots.beltX, 0, Spots.beltTop).Position, toWorld(plot, Spots.beltX, 0, Spots.beltEnd).Position, Spots.beltY)
	local _, boardLabels = Conveyor.moneyBoard(static, localCF(plot, Spots.board))
	plot.boardLabels = boardLabels

	local interactive = Build.folder(model, "Interactive")
	local machineModel, machineRefs = Machine.build(interactive, localCF(plot, Spots.machine), Spots.carpetLength)
	local _ = machineModel
	plot.machine = machineRefs
	local stash, pad, label = Conveyor.chest(interactive, localCF(plot, Spots.chest))
	local chestPrompt = Props.prompt(stash:FindFirstChild("Chest") :: BasePart, "Récupérer", "Coffre des revenus", 10)
	local _2 = chestPrompt
	plot.stashPad = pad
	plot.stashLabel = label
	local _3, relicCF = Props.relicMerchant(interactive, localCF(plot, Spots.merchant))
	plot.relicDisplayCF = relicCF
	Props.altar(interactive, localCF(plot, Spots.altar))
	local _4, skillRefs = Props.skillTree(interactive, localCF(plot, Spots.skillTree), localCF(plot, Spots.lectern))
	plot.skillRefs = skillRefs
	buildSlots(plot, interactive)
	plot.pedestalFolder = Build.folder(interactive, "Pedestals")
	plot.pedestals = {}
	plot.pedestals[1] = Props.pedestal(plot.pedestalFolder, localCF(plot, PlotService.PedestalSlots[1]), 1, index)

	-- Contenu propre au propriétaire (améliorations, persos exposés, persos tirés).
	plot.ownerFolder = Build.folder(model, "Owner")
	plot.displayFolder = Build.folder(model, "Display")
	plot.rolledFolder = Build.folder(model, "Rolled")
	return plot
end

-- Retrouve les éléments d'une base déjà construite (fichier pré-construit, retouché dans Studio).
local function bindPlot(index: number, model: Model)
	local plot = { index = index, cf = Layout.plotCFrame(index), owner = nil, model = model }
	BaseDecor.register(plot)
	local decor = model:FindFirstChild("Decor")
	plot.signLabels = {}
	if decor then
		BaseDecor.apply(plot, Universes.get(decor:GetAttribute("UniverseId") or "") or Universes.List[1])
	else
		BaseDecor.apply(plot, Universes.List[1])
	end
	BaseDecor.setSign(plot, "BASE LIBRE")
	local static = model:FindFirstChild("Static")
	local board = static and static:FindFirstChild("CompteurArgent")
	local panel = board and board:FindFirstChild("Panneau")
	local boardGui = panel and panel:FindFirstChildOfClass("SurfaceGui")
	plot.boardLabels = {
		coffre = boardGui and boardGui:FindFirstChild("Coffre"),
		revenu = boardGui and boardGui:FindFirstChild("Revenu"),
		pieces = boardGui and boardGui:FindFirstChild("Pieces"),
	}
	local interactive = model:FindFirstChild("Interactive") :: Instance
	local stash = interactive:FindFirstChild("Stash") :: Instance
	plot.stashPad = stash:FindFirstChild("Pad")
	plot.stashLabel = stash:FindFirstChild("Amount", true)
	plot.relicDisplayCF = localCF(plot, Spots.merchant) * CFrame.new(0, 7.2, -1.8)
	plot.machine = Machine.bind(interactive:FindFirstChild("RollMachine") :: Model, localCF(plot, Spots.machine))
	plot.skillRefs = Props.bindSkillTree(interactive:FindFirstChild("ArbreCompetences") :: Model)
	plot.slots = {}
	local cases = interactive:FindFirstChild("Cases")
	for i, pos in PlotService.DisplaySlots do
		local caseModel = cases and cases:FindFirstChild("Case" .. i)
		if caseModel then
			plot.slots[i] = Slots.bind(caseModel, toWorld(plot, pos.X, 0, pos.Z), Spots.slotHeight)
		end
	end
	if #plot.slots ~= #PlotService.DisplaySlots then
		if cases then
			cases:Destroy()
		end
		buildSlots(plot, interactive)
	end
	plot.pedestalFolder = interactive:FindFirstChild("Pedestals")
	plot.pedestals = {}
	for _, pedestal in plot.pedestalFolder:GetChildren() do
		local slot = pedestal:GetAttribute("Slot")
		if slot == 1 then
			plot.pedestals[1] = pedestal
		else
			pedestal:Destroy() -- aperçu des améliorations (fichier Studio)
		end
	end
	plot.ownerFolder = model:FindFirstChild("Owner") or Build.folder(model, "Owner")
	plot.displayFolder = model:FindFirstChild("Display") or Build.folder(model, "Display")
	plot.rolledFolder = model:FindFirstChild("Rolled") or Build.folder(model, "Rolled")
	plot.ownerFolder:ClearAllChildren()
	plot.displayFolder:ClearAllChildren()
	plot.rolledFolder:ClearAllChildren()
	model:SetAttribute("OwnerId", nil)
	return plot
end
PlotService.bindPlot = bindPlot

------------------------------------------------------------------------
-- Gestion du propriétaire
------------------------------------------------------------------------

function PlotService:Init(services)
	self.services = services
	local world = Workspace:WaitForChild("World")
	local folder = world:FindFirstChild("Plots") or Build.folder(world, "Plots")
	for i = 1, Layout.PlotCount do
		local existing = folder:FindFirstChild("Plot" .. i)
		local ok, plot = pcall(function()
			return existing and existing:FindFirstChild("Interactive") and existing.Interactive:FindFirstChild("RollMachine") and bindPlot(i, existing) or nil
		end)
		if not ok or not plot then
			if existing then
				existing:Destroy() -- ancienne version de la base (fichier d'avant la v3)
			end
			plot = buildPlot(i, folder)
		end
		plots[i] = plot
		self:_connectPrompts(plot)
	end
end

local function ownerOnly(plot, player: Player, fn: () -> ())
	if plot.owner == player then
		fn()
	else
		Notify:FireClient(player, "Ce n'est pas ta base !", "error")
	end
end

function PlotService:_connectPrompts(plot)
	local interactive = plot.model.Interactive
	local machinePrompt = interactive.RelicMachine.Base:FindFirstChild("Prompt") :: ProximityPrompt
	machinePrompt.Triggered:Connect(function(player)
		ownerOnly(plot, player, function()
			OpenMenu:FireClient(player, "Shop")
		end)
	end)
	local altarPrompt = interactive.EvolutionAltar.Altar:FindFirstChild("Prompt") :: ProximityPrompt
	altarPrompt.Triggered:Connect(function(player)
		ownerOnly(plot, player, function()
			OpenMenu:FireClient(player, "Evolution")
		end)
	end)
	if plot.skillRefs and plot.skillRefs.prompt then
		plot.skillRefs.prompt.Triggered:Connect(function(player)
			ownerOnly(plot, player, function()
				OpenMenu:FireClient(player, "SkillTree")
			end)
		end)
	end
	for i, ref in plot.slots do
		if ref.prompt then
			ref.prompt.Triggered:Connect(function(player)
				ownerOnly(plot, player, function()
					OpenMenu:FireClient(player, "PlaceUnit", { slot = i, uid = ref.uid })
				end)
			end)
		end
	end
	local chest = interactive.Stash:FindFirstChild("Chest")
	local chestPrompt = chest and chest:FindFirstChild("Prompt") :: ProximityPrompt?
	if chestPrompt then
		chestPrompt.Triggered:Connect(function(player)
			ownerOnly(plot, player, function()
				self:CollectStash(player)
			end)
		end)
	end
	local debounce = {}
	plot.stashPad.Touched:Connect(function(hit)
		local player = Players:GetPlayerFromCharacter(hit.Parent)
		if not player or player ~= plot.owner then
			return
		end
		if debounce[player] and os.clock() - debounce[player] < 1 then
			return
		end
		debounce[player] = os.clock()
		self:CollectStash(player)
	end)
end

function PlotService:Start()
	local DataService = self.services.DataService
	DataService:OnPlayerLoaded(function(player, data)
		self:_assign(player, data)
	end)
	DataService:OnPlayerRemoving(function(player)
		self:_release(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		self:_release(player)
	end)

	Remotes.func("PlaceUnit").OnServerInvoke = function(player, slot, uid)
		local ok, message = self:PlaceUnit(player, slot, uid)
		if not ok and message then
			Notify:FireClient(player, message, "error")
		end
		return ok, message
	end

	-- Téléportations rapides (boutons du HUD).
	local lastTeleport = {}
	Remotes.event("Teleport").OnServerEvent:Connect(function(player, destination)
		local character = player.Character
		if not character or not character:FindFirstChild("HumanoidRootPart") then
			return
		end
		if lastTeleport[player] and os.clock() - lastTeleport[player] < 3 then
			return
		end
		lastTeleport[player] = os.clock()
		local target: CFrame? = nil
		if destination == "base" then
			local plot = playerPlots[player]
			target = plot and self:GetSpawnCFrame(plot)
		elseif destination == "zone" then
			local plot = playerPlots[player]
			local angle = (plot and Layout.PlotAngles[plot.index] or 0) + math.rad(7)
			local pos = Vector3.new(math.cos(angle), 0, math.sin(angle)) * (Layout.EnemyBands[1][1] + 6)
			target = CFrame.lookAt(pos + Vector3.new(0, 3, 0), pos * 2 + Vector3.new(0, 3, 0))
		elseif destination == "trade" then
			target = CFrame.lookAt(Layout.TradeCorner + Vector3.new(-30, 3, 0), Layout.TradeCorner + Vector3.new(0, 3, 0))
		elseif destination == "fusion" or destination == "hub" then
			local stall = Layout.stallPosition(destination == "fusion" and "Fusion" or "Forge")
			local pos = stall * 0.68
			target = CFrame.lookAt(pos + Vector3.new(0, 3, 0), stall + Vector3.new(0, 3, 0))
		elseif destination == "boss" and self.services.HubService then
			target = self.services.HubService:GetArenaEntrance()
		end
		if target then
			PlotService.streamAround(player, target.Position)
			character:PivotTo(target)
			if self.services.TeamService then
				task.delay(0.2, function()
					self.services.TeamService:TeleportTeam(player)
				end)
			end
		end
	end)

	-- Affichages (coffre, compteur, boutons vert/rouge) : une fois par demi-seconde.
	task.spawn(function()
		while true do
			task.wait(0.5)
			for _, plot in plots do
				local ok, err = pcall(self._updateDisplays, self, plot)
				if not ok then
					warn("[AnimeTycoon] Affichage de base : " .. tostring(err))
				end
			end
		end
	end)
end

function PlotService:_updateDisplays(plot)
	local DataService = self.services.DataService
	local data = plot.owner and DataService:Get(plot.owner)
	if not data then
		plot.stashLabel.Text = ""
		if plot.boardLabels and plot.boardLabels.coffre then
			plot.boardLabels.coffre.Text = "BASE LIBRE"
			plot.boardLabels.revenu.Text = ""
			plot.boardLabels.pieces.Text = ""
		end
		return
	end
	local rate = (type(plot.owner) ~= "table" and plot.owner:GetAttribute("IncomePerSec")) or 0
	plot.stashLabel.Text = "¥ " .. Formulas.formatNumber(data.stash)
	local labels = plot.boardLabels
	if labels and labels.coffre then
		labels.coffre.Text = "Coffre : ¥ " .. Formulas.formatNumber(data.stash)
		labels.revenu.Text = "+ ¥ " .. Formulas.formatNumber(rate) .. " / seconde"
		labels.pieces.Text = "Tes pièces : ¥ " .. Formulas.formatNumber(data.coins)
	end
	for _, info in plot.pads or {} do
		local affordable = data.coins >= info.price
		if info.affordable ~= affordable then
			info.affordable = affordable
			Kit.setAffordable(info.refs, affordable)
		end
	end
end

function PlotService:_assign(player: Player, data)
	if playerPlots[player] then
		return
	end
	local chosen = nil
	for _, plot in plots do
		if plot.owner == nil then
			chosen = plot
			break
		end
	end
	if not chosen then
		Notify:FireClient(player, "Aucune base libre sur ce serveur.", "error")
		return
	end
	chosen.owner = player
	playerPlots[player] = chosen
	chosen.model:SetAttribute("OwnerId", player.UserId)
	player:SetAttribute("PlotIndex", chosen.index)
	BaseDecor.setSign(chosen, "BASE DE " .. string.upper(player.DisplayName))
	self:RefreshOwnerContent(player)

	local function onCharacter(character: Model)
		local root = character:WaitForChild("HumanoidRootPart", 10)
		if root and playerPlots[player] == chosen then
			task.wait(0.1)
			local spawnCF = self:GetSpawnCFrame(chosen)
			PlotService.streamAround(player, spawnCF.Position)
			character:PivotTo(spawnCF)
		end
	end
	if player.Character then
		task.spawn(onCharacter, player.Character)
	end
	chosen.charConn = player.CharacterAdded:Connect(onCharacter)
	local _ = data
end

function PlotService:_release(player: Player)
	local plot = playerPlots[player]
	if not plot then
		return
	end
	playerPlots[player] = nil
	plot.owner = nil
	plot.model:SetAttribute("OwnerId", nil)
	if plot.charConn then
		plot.charConn:Disconnect()
		plot.charConn = nil
	end
	BaseDecor.setSign(plot, "BASE LIBRE")
	plot.ownerFolder:ClearAllChildren()
	plot.displayFolder:ClearAllChildren()
	plot.rolledFolder:ClearAllChildren()
	plot.pads = {}
	plot.coinPaths = nil
	plot.coinFolder = nil
	plot.builtKey = nil
	for slot = 2, #PlotService.PedestalSlots do
		if plot.pedestals[slot] then
			plot.pedestals[slot]:Destroy()
			plot.pedestals[slot] = nil
		end
	end
	local pedestal = plot.pedestals[1]
	if pedestal then
		pedestal:SetAttribute("RelicId", nil)
		pedestal:SetAttribute("ReadyAt", nil)
		local relic = pedestal:FindFirstChild("RelicModel")
		if relic then
			relic:Destroy()
		end
	end
	for _, ref in plot.slots do
		ref.uid = nil
		Slots.setState(ref, "locked", "🔒")
	end
	Props.refreshSkillCells(plot.skillRefs and plot.skillRefs.cells, {})
	if self.services.RollService then
		self.services.RollService:ClearStage(plot)
	end
end

function PlotService:GetPlot(player: Player)
	return playerPlots[player]
end

function PlotService:GetPlots()
	return plots
end

function PlotService:GetSpawnCFrame(plot): CFrame
	local pos = (plot.cf * CFrame.new(PlotService.SpawnOffset)).Position
	local target = (plot.cf * CFrame.new(0, 3, 0)).Position
	return CFrame.lookAt(pos, target)
end

function PlotService:GetDisplayCFrame(plot, slot: number): CFrame
	local offset = PlotService.DisplaySlots[slot] or PlotService.DisplaySlots[1]
	-- Les persos regardent vers l'entrée de la base (-Z local).
	return plot.cf * CFrame.new(offset)
end

function PlotService:ToWorld(plot, x: number, y: number, z: number): CFrame
	return toWorld(plot, x, y, z)
end

------------------------------------------------------------------------
-- Améliorations : constructions, boutons, fantômes
------------------------------------------------------------------------

local function upgradeAvailable(data, upgrade): boolean
	return not data.upgrades[upgrade.id] and (upgrade.requires == nil or data.upgrades[upgrade.requires] == true)
end

-- Reconstruit améliorations, boutons, fantômes, autels supplémentaires, cases et hologramme.
-- `justBought` = id de l'amélioration qui vient d'être achetée (animation de construction).
function PlotService:RefreshOwnerContent(player: Player, justBought: string?)
	local plot = playerPlots[player]
	local data = self.services.DataService:Get(player)
	if not plot or not data then
		return
	end
	local structures = plot.ownerFolder:FindFirstChild("Structures") or Build.folder(plot.ownerFolder, "Structures")
	local oldPads = plot.ownerFolder:FindFirstChild("Pads")
	if oldPads then
		oldPads:Destroy()
	end
	local oldGhosts = plot.ownerFolder:FindFirstChild("Ghosts")
	if oldGhosts then
		oldGhosts:Destroy()
	end
	local pads = Build.folder(plot.ownerFolder, "Pads")
	local ghosts = Build.folder(plot.ownerFolder, "Ghosts")
	plot.coinFolder = plot.ownerFolder:FindFirstChild("Coins") or Build.folder(plot.ownerFolder, "Coins")
	plot.pads = {}

	local bestLook = self.services.CharacterService and self.services.CharacterService.GetBestLook and self.services.CharacterService:GetBestLook(player)
	local coinPaths = {}
	for _, upgrade in Economy.Upgrades do
		local existing = structures:FindFirstChild(upgrade.id)
		if data.upgrades[upgrade.id] then
			-- La statue suit le meilleur perso : on la reconstruit à chaque fois.
			if existing and upgrade.id == "statue" then
				existing:Destroy()
				existing = nil
			end
			if not existing then
				local ok, model = pcall(Structures.build, upgrade.id, plot, structures, { bestLook = bestLook, coinPaths = coinPaths })
				if not ok then
					warn("[AnimeTycoon] Structure " .. upgrade.id .. " : " .. tostring(model))
				elseif model and upgrade.id == justBought then
					Kit.animateBuild(model, 1.6)
				end
			elseif upgrade.id:sub(1, 12) == "distributeur" then
				-- Les chemins de pièces ne sont pas mémorisés : on les recalcule.
				local temp = Instance.new("Folder")
				pcall(Structures.build, upgrade.id, plot, temp, { coinPaths = coinPaths })
				temp:Destroy()
			end
		else
			if existing then
				existing:Destroy()
			end
			if upgradeAvailable(data, upgrade) then
				self:_buildPad(player, plot, pads, upgrade)
				local ok, ghost = pcall(Structures.build, upgrade.id, plot, ghosts, { ghost = true, bestLook = bestLook })
				if ok and ghost then
					Kit.ghostify(ghost)
				end
			end
		end
	end
	plot.coinPaths = coinPaths
	-- Pièces sur le tapis : animées par chaque client (Controllers/CoinConveyor).
	Conveyor.publish(plot.coinFolder, coinPaths, true)

	-- Autels (incubateurs) selon les améliorations.
	local stats = Formulas.playerStats(data)
	for slot = 2, #PlotService.PedestalSlots do
		if slot <= stats.incubators and not plot.pedestals[slot] then
			plot.pedestals[slot] = Props.pedestal(plot.pedestalFolder, localCF(plot, PlotService.PedestalSlots[slot]), slot, plot.index)
			if self.services.HatchService then
				self.services.HatchService:ConnectPedestal(plot, plot.pedestals[slot])
			end
		end
	end
	if self.services.HatchService then
		self.services.HatchService:RefreshPedestals(player)
	end
	self:RefreshSlots(player)
	Props.refreshSkillCells(plot.skillRefs and plot.skillRefs.cells, data.Skills)
	self:_updateDisplays(plot)
end

function PlotService:_buildPad(player: Player, plot, parent: Instance, upgrade)
	local pos = Structures.padPosition(upgrade.id) or Vector3.zero
	local cf = toWorld(plot, pos.X, 0, pos.Z)
	local model, refs = Kit.buyButton(parent, cf, "Pad_" .. upgrade.id)
	local tierTag = upgrade.tier and ("Palier " .. upgrade.tier .. " · ") or ""
	local _, boardRefs = Kit.priceBoard(
		refs.pad,
		(upgrade.icon or "") .. " " .. upgrade.name,
		tierTag .. Kit.effectText(upgrade.effect),
		"¥ " .. Formulas.formatNumber(upgrade.price),
		Vector3.new(0, 5.4, 0)
	)
	for key, value in boardRefs do
		refs[key] = value
	end
	model:SetAttribute("UpgradeId", upgrade.id)
	model:SetAttribute("Price", upgrade.price)
	CollectionService:AddTag(model, "UpgradePad")
	-- Invite d'achat (manette, mobile) en plus du bouton à marcher dessus.
	local prompt = Props.prompt(refs.pad, "Acheter (¥ " .. Formulas.formatNumber(upgrade.price) .. ")", upgrade.name, 9)
	prompt.HoldDuration = 0.25
	prompt.Triggered:Connect(function(who)
		if who == player then
			self:BuyUpgrade(player, upgrade.id)
		end
	end)
	local busy = false
	refs.pad.Touched:Connect(function(hit)
		if busy then
			return
		end
		local toucher = Players:GetPlayerFromCharacter(hit.Parent)
		if toucher ~= player then
			return
		end
		busy = true
		self:BuyUpgrade(player, upgrade.id)
		task.delay(1, function()
			busy = false
		end)
	end)
	local data = self.services.DataService:Get(player)
	local affordable = data ~= nil and data.coins >= upgrade.price
	Kit.setAffordable(refs, affordable)
	table.insert(plot.pads, { id = upgrade.id, price = upgrade.price, refs = refs, affordable = affordable })
	return model
end

function PlotService:BuyUpgrade(player: Player, upgradeId: string): boolean
	local DataService = self.services.DataService
	local data = DataService:Get(player)
	local upgrade = Economy.UpgradesById[upgradeId]
	if not data or not upgrade or data.upgrades[upgradeId] then
		return false
	end
	if upgrade.requires and not data.upgrades[upgrade.requires] then
		return false
	end
	if data.coins < upgrade.price then
		Notify:FireClient(player, "Il te manque ¥ " .. Formulas.formatNumber(upgrade.price - data.coins) .. " pour " .. upgrade.name, "error")
		return false
	end
	DataService:SpendCoins(player, upgrade.price)
	data.upgrades[upgradeId] = true
	DataService:Sync(player)
	self:RefreshOwnerContent(player, upgradeId)
	if self.services.CharacterService then
		self.services.CharacterService:Refresh(player)
	end
	if self.services.TeamService then
		self.services.TeamService:RefreshTeam(player)
	end
	Notify:FireClient(player, "✨ " .. upgrade.name .. " construit !", "success")
	local plot = playerPlots[player]
	if plot then
		local pos = Structures.padPosition(upgradeId) or Vector3.zero
		CombatFX:FireClient(player, "Build", { position = toWorld(plot, pos.X, 2, pos.Z).Position })
	end
	return true
end

function PlotService:CollectStash(player: Player)
	local DataService = self.services.DataService
	local data = DataService:Get(player)
	if not data or data.stash < 1 then
		return
	end
	local amount = math.floor(data.stash)
	data.stash -= amount
	DataService:AddCoins(player, amount)
	local plot = playerPlots[player]
	Remotes.event("Reward"):FireClient(player, "coins", amount, plot and plot.stashPad.Position or nil)
	if plot then
		self:_updateDisplays(plot)
	end
end

------------------------------------------------------------------------
-- Cases d'unités
------------------------------------------------------------------------

local UPGRADE_SLOTS = Economy.BaseDisplaySlots
for _, upgrade in Economy.Upgrades do
	UPGRADE_SLOTS += upgrade.effect.display or 0
end

-- Met à jour l'état des 24 cases (verrouillée « ??? », libre, occupée).
function PlotService:RefreshSlots(player: Player, displayed: { [number]: string }?)
	local plot = playerPlots[player]
	local data = self.services.DataService:Get(player)
	if not plot or not data then
		return
	end
	local stats = Formulas.playerStats(data)
	local CharacterService = self.services.CharacterService
	local shown = displayed or (CharacterService and CharacterService.GetDisplayed and CharacterService:GetDisplayed(player)) or {}
	for i, ref in plot.slots do
		ref.uid = shown[i]
		if i > stats.display then
			Slots.setState(ref, "locked", i <= UPGRADE_SLOTS and "🔒 Améliore la cour" or "🔒 Arbre : Emplacements")
		elseif shown[i] then
			Slots.setState(ref, "occupied")
		else
			Slots.setState(ref, "free")
		end
	end
end

-- Étiquette d'une unité exposée (nom en dégradé, étoiles, rareté), comme les jeux de tirage.
function PlotService:DecorateUnit(_plot, model: Model, entry)
	local root = model.PrimaryPart or model:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root or root:FindFirstChild("AnimeTag") then
		return
	end
	local desc = Formulas.describe(entry)
	if not desc then
		return
	end
	local rollInfo = entry.rollRarity and Economy.RollRarities[entry.rollRarity]
	local rarity = Rarities.get(desc.rarity)
	local rarityName = rollInfo and rollInfo.name or rarity.name
	local gradient = rollInfo and rollInfo.gradient or rarity.gradient
	local scale = model:GetAttribute("BaseScale") or Formulas.visualScale(entry)
	Kit.unitTag(root, {
		{ name = "Nom", text = desc.name, colors = gradient, font = Enum.Font.LuckiestGuy, weight = 1.3 },
		{ name = "Etoiles", text = string.rep("★", entry.stars or 1), color = rgb(255, 210, 50), font = Enum.Font.GothamBlack, weight = 0.8 },
		{ name = "Rarete", text = rarityName, colors = gradient, font = Enum.Font.GothamBlack, weight = 0.7 },
	}, 2.4, 4.4 * scale + 1.2, 70, 6.5)
end

-- Chargement progressif : demande au client de charger la zone d'arrivée AVANT une
-- téléportation (sinon le joueur reste figé le temps que le décor arrive).
function PlotService.streamAround(player: Player, position: Vector3)
	pcall(function()
		player:RequestStreamAroundAsync(position, 4)
	end)
end

-- « Remplacer l'unité » : place une unité précise sur une case. uid = nil : la case reste VIDE
-- (DisplayPins = false, pas de remplissage automatique) ; uid = "auto" : la case se remplit de
-- nouveau toute seule avec les unités les plus fortes.
function PlotService:PlaceUnit(player: Player, slot: any, uid: any)
	local DataService = self.services.DataService
	local data = DataService:Get(player)
	if not data or type(slot) ~= "number" or slot ~= slot then
		return false, "Erreur."
	end
	slot = math.floor(slot)
	local stats = Formulas.playerStats(data)
	if slot < 1 or slot > math.min(stats.display, #PlotService.DisplaySlots) then
		return false, "Cet emplacement est verrouillé."
	end
	local key = tostring(slot)
	if uid == nil then
		data.DisplayPins[key] = false
	elseif uid == "auto" then
		data.DisplayPins[key] = nil
	else
		if type(uid) ~= "string" or not data.characters[uid] then
			return false, "Perso introuvable."
		end
		-- Une unité ne peut être que sur une case à la fois, et pas dans l'équipe en même temps.
		for k, v in data.DisplayPins do
			if v == uid then
				data.DisplayPins[k] = nil
			end
		end
		local teamIndex = table.find(data.team, uid)
		if teamIndex then
			table.remove(data.team, teamIndex)
		end
		data.DisplayPins[key] = uid
	end
	DataService:Sync(player)
	if self.services.CharacterService then
		self.services.CharacterService:Refresh(player)
	end
	if self.services.TeamService then
		self.services.TeamService:RefreshTeam(player)
	end
	if uid == "auto" then
		return true, "Remplissage automatique de l'emplacement #" .. slot
	end
	return true, uid and "Unité placée sur l'emplacement #" .. slot or "Emplacement libéré"
end

return PlotService
