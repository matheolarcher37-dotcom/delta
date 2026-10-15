-- Commandes de la MACHINE ROULER (v3.2) : elles n'apparaissent QUE quand on est à la machine de
-- sa base (plus de panneau permanent à droite de l'écran).
--
--   • bouton ROULER (X à la manette quand aucune invite n'est affichée ; E / X sur l'invite de la
--     machine), avec le temps de recharge ;
--   • x1 / x2 / x3 : persos par roulage (x2 et x3 = passes Robux : le bouton ouvre l'achat) ;
--   • AUTO : ouvre la fenêtre « Roulement automatique » (UI/AutoRoll.luau) ;
--   • la pitié du Mythique (la seule du jeu) et la chance actuelle ;
--   • juste au-dessus de la barre : LE perso tiré (rareté, mutation, prix) et « Collecter ».
-- Tout tient dans une barre compacte en bas à droite : le centre de l'écran reste libre pour
-- voir le perso tiré sur le podium.
-- Loin de la machine, seule une petite pastille rappelle que l'auto-roulage tourne (avec Arrêter).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Characters = require(Shared.Config.Characters)
local Economy = require(Shared.Config.Economy)
local Layout = require(Shared.Config.Layout)
local Mutations = require(Shared.Config.Mutations)
local Formulas = require(Shared.Modules.Formulas)
local MutationsFx = require(Shared.Modules.Mutations)

local Theme = require(script.Parent.Theme)
local Icons = require(script.Parent.Icons)
local Components = require(script.Parent.Components)
local Console = require(script.Parent.Console)
local Menus = require(script.Parent.Menus)
local Notifications = require(script.Parent.Notifications)
local AutoRoll = require(script.Parent.AutoRoll)
local State = require(script.Parent.Parent.State)

local RollPanel = {}

local C = Theme.Colors
local new = Theme.new
local rgb = Color3.fromRGB
local WHITE = Color3.new(1, 1, 1)

local player = Players.LocalPlayer
local refs: { [string]: any } = {}
local rolling = false
local cooldownUntil = 0
local near = false

-- Position de la machine dans une base (repère local de la base : -Z = entrée), comme
-- TycoonStructures.Spots.machine côté serveur.
RollPanel.MachineLocal = Vector3.new(0, 0, -30)
-- Zone « à la machine » (repère local de la machine) : estrade, bouton, panneau, tapis rouge.
RollPanel.PillTop = 138 -- haut de la pastille « auto-roulage en cours » (unités logiques du HUD)
RollPanel.PillHeight = 40
RollPanel.Zone = Economy.Roll.MachineZone -- même zone que le serveur (Config/Economy)

-- Seuil de pitié du Mythique (après l'arbre de compétences).
function RollPanel.pityThreshold(rarityId: string?, pityMult: number?): number
	return Formulas.pityThreshold(rarityId or Economy.Roll.PityRarity, pityMult)
end

local function characterName(id: string?): string
	local def = id and Characters.get(id)
	return def and def.name or "Perso"
end

-- CFrame de la machine de MA base (ou nil).
function RollPanel.machineCFrame(): CFrame?
	local index = player and player:GetAttribute("PlotIndex")
	if type(index) ~= "number" or not Layout.PlotAngles[index] then
		return nil
	end
	return Layout.plotCFrame(index) * CFrame.new(RollPanel.MachineLocal)
end

-- Vrai si le joueur se tient à sa machine ROULER.
function RollPanel.isNearMachine(): boolean
	local cf = RollPanel.machineCFrame()
	local character = player and player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not cf or not root then
		return false
	end
	local p = cf:PointToObjectSpace(root.CFrame.Position)
	local zone = RollPanel.Zone
	return math.abs(p.X) <= zone.halfX and p.Z >= zone.zMin and p.Z <= zone.zMax and p.Y <= zone.maxY
end

------------------------------------------------------------------------
-- Actions
------------------------------------------------------------------------

function RollPanel.roll()
	if rolling or os.clock() < cooldownUntil then
		return
	end
	rolling = true
	local ok, result = State.invoke("Roll")
	rolling = false
	if ok then
		local stats = State.treeStats()
		cooldownUntil = os.clock() + (stats.rollCooldown or 3)
	elseif type(result) == "string" and not State.remoteFunction("Roll") then
		Notifications.toast(result, "error")
	end
end

-- Manette (X) : ne roule QUE si on est à la machine.
local function rollFromGamepad()
	if near then
		RollPanel.roll()
	end
end

local function collect(key: string)
	local ok, message = State.invoke("CollectRolled", key)
	if not ok and type(message) == "string" and not State.remoteFunction("CollectRolled") then
		Notifications.toast(message, "error")
	end
end

local function ownsMulti(n: number): boolean
	if n <= 1 then
		return true
	end
	if n == 2 then
		return AutoRoll.hasPass("Roll2") or AutoRoll.hasPass("Roll3")
	end
	return AutoRoll.hasPass("Roll3")
end

local function chooseMulti(n: number)
	if not ownsMulti(n) then
		AutoRoll.promptPass(n == 3 and "Roll3" or "Roll2")
		return
	end
	State.invoke("Roll_SetMulti", n)
end

-- Persos par roulage actuellement (passes + choix du joueur).
function RollPanel.currentMulti(): number
	local data = State.data or {}
	local wanted = tonumber(data.RollMulti) or 0
	return Formulas.rollsPerRoll(player, wanted ~= 0 and wanted or nil)
end

------------------------------------------------------------------------
-- Construction
------------------------------------------------------------------------

-- Barre COMPACTE en bas à droite (au-dessus des cartes d'équipe du HUD) : le centre de l'écran
-- reste libre pour voir le perso tiré sur le podium.
local PANEL_W, PANEL_H = 440, 132
local PANEL_RIGHT = 16
local PANEL_BOTTOM = 96 -- au-dessus de l'équipe (bas droite du HUD, 84 px de haut)
local PANEL_BOTTOM_TOUCH = 200 -- tactile : au-dessus du bouton de saut de Roblox (bas droite)
RollPanel.PanelSize = Vector2.new(PANEL_W, PANEL_H)

-- Marge du bas selon l'appareil (sur téléphone, l'équipe passe en haut mais le coin bas droit
-- appartient au bouton de saut : la barre ne doit jamais être posée dessus).
function RollPanel.panelBottom(): number
	return if Console.isTouch() then PANEL_BOTTOM_TOUCH else PANEL_BOTTOM
end

local function multiButton(parent: Instance, n: number, x: number)
	local holder = new("Frame", {
		Name = "Multi" .. n,
		Position = UDim2.fromOffset(x, 0),
		Size = UDim2.fromOffset(54, 56),
		BackgroundTransparency = 1,
		Parent = parent,
	})
	local button = Components.button({
		Text = "x" .. n,
		Color = C.Gray,
		Size = UDim2.fromScale(1, 1),
		TextSize = 22,
		Parent = holder,
		OnClick = function()
			chooseMulti(n)
		end,
	})
	local tag = new("Frame", {
		Name = "Prix",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 1, -14),
		Size = UDim2.fromOffset(66, 20),
		BackgroundColor3 = rgb(20, 160, 80),
		ZIndex = 6,
		Parent = holder,
	})
	Theme.corner(10).Parent = tag
	Theme.stroke(C.Stroke, 2).Parent = tag
	local price = Theme.label({
		Name = "Texte",
		Text = "",
		Size = UDim2.new(1, -8, 1, -4),
		Position = UDim2.fromOffset(4, 2),
		FontFace = Theme.Faces.Heavy,
		ZIndex = 7,
		StrokeThickness = 1.5,
		Parent = tag,
	})
	return { holder = holder, button = button, tag = tag, price = price }
end

local function build(root: Frame)
	local panel = new("Frame", {
		Name = "MachinePanel",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -PANEL_RIGHT, 1, -RollPanel.panelBottom()),
		Size = UDim2.fromOffset(PANEL_W, PANEL_H),
		BackgroundColor3 = WHITE,
		Visible = false,
		Parent = root,
	})
	refs.panel = panel
	Theme.corner(18).Parent = panel
	Theme.stroke(C.Stroke, 3).Parent = panel
	Theme.gradient({ rgb(40, 32, 64), rgb(18, 16, 28) }, 90).Parent = panel
	local edge = new("Frame", { Size = UDim2.new(1, -6, 1, -6), Position = UDim2.fromOffset(3, 3), BackgroundTransparency = 1, Parent = panel })
	Theme.corner(16).Parent = edge
	Theme.stroke(C.Purple, 1.5, 0.35).Parent = edge
	refs.scale = new("UIScale", { Parent = panel })

	-- En-tête : titre + pitié du Mythique
	local header = new("Frame", { Name = "Header", Size = UDim2.new(1, -24, 0, 34), Position = UDim2.fromOffset(12, 5), BackgroundTransparency = 1, Parent = panel })
	local dice = new("Frame", { Position = UDim2.fromOffset(0, 1), Size = UDim2.fromOffset(24, 24), BackgroundTransparency = 1, Parent = header })
	Icons.make("dice", dice, { px = 24, ink = rgb(110, 40, 200) })
	refs.dice = dice
	local title = Theme.label({
		Text = "MACHINE ROULER",
		Position = UDim2.fromOffset(30, 2),
		Size = UDim2.fromOffset(160, 22),
		FontFace = Theme.Faces.Title,
		TextXAlignment = Enum.TextXAlignment.Left,
		StrokeThickness = 2.5,
		Parent = header,
	})
	Theme.gradient({ rgb(255, 240, 160), rgb(255, 170, 40) }, 90).Parent = title
	refs.pityText = Theme.label({
		Name = "Pitie",
		Text = "",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 4),
		Size = UDim2.fromOffset(220, 16),
		FontFace = Theme.Faces.Heavy,
		TextColor3 = rgb(255, 150, 170),
		TextXAlignment = Enum.TextXAlignment.Right,
		StrokeThickness = 1.5,
		Parent = header,
	})
	refs.pityBar = Components.progressBar(header, rgb(255, 60, 100), {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 27),
		Size = UDim2.new(1, 0, 0, 6),
	})

	-- Rangée de boutons
	local row = new("Frame", { Name = "Boutons", Position = UDim2.fromOffset(12, 42), Size = UDim2.new(1, -24, 0, 56), BackgroundTransparency = 1, Parent = panel })
	refs.rollButton = Components.button({
		Text = "ROULER",
		Icon = "dice",
		Color = rgb(255, 180, 30),
		Size = UDim2.fromOffset(150, 56),
		Hint = "X",
		TextSize = 24,
		Parent = row,
		OnClick = RollPanel.roll,
	})
	local cooldown = new("Frame", {
		Name = "Cooldown",
		Size = UDim2.new(1, 0, 1, -5),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.5,
		BorderSizePixel = 0,
		ZIndex = 5,
		Visible = false,
		Parent = refs.rollButton,
	})
	Theme.corner(12).Parent = cooldown
	refs.cooldown = cooldown
	refs.multi = {}
	for i, n in { 1, 2, 3 } do
		refs.multi[n] = multiButton(row, n, 158 + (i - 1) * 60)
	end
	refs.autoButton = Components.button({
		Text = "AUTO",
		Icon = "robot",
		Color = C.Purple,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.fromOffset(92, 56),
		TextSize = 18,
		Parent = row,
		OnClick = function()
			AutoRoll.toggle()
		end,
	})

	-- Ligne d'état
	refs.status = Theme.label({
		Name = "Etat",
		Text = "",
		Position = UDim2.fromOffset(12, 106),
		Size = UDim2.new(1, -24, 0, 18),
		FontFace = Theme.Faces.Bold,
		TextColor3 = C.TextDim,
		StrokeThickness = 1.5,
		Parent = panel,
	})

	-- Perso(s) tiré(s) : cartes au-dessus du panneau
	-- (une seule ligne collée au-dessus de la barre, alignée à droite : le centre et le bas de
	-- l'écran — boutons de voyage — restent libres)
	local pull = new("Frame", {
		Name = "Tirage",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -PANEL_RIGHT, 1, -RollPanel.panelBottom() - PANEL_H - 8),
		Size = UDim2.fromOffset(3 * 212 + 2 * 10, 86),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = root,
	})
	local layout = Theme.list(Enum.FillDirection.Horizontal, 10, Enum.HorizontalAlignment.Right)
	layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	layout.Parent = pull
	refs.pull = pull

	-- Pastille « auto-roulage en cours » (loin de la machine)
	local pill = new("Frame", {
		Name = "AutoPill",
		AnchorPoint = Vector2.new(0.5, 0),
		-- Sous la rangée des pastilles du HUD (Marchand, Boss, Événement : y 98 → 130).
		Position = UDim2.new(0.5, 0, 0, RollPanel.PillTop),
		Size = UDim2.fromOffset(360, RollPanel.PillHeight),
		BackgroundColor3 = WHITE,
		Visible = false,
		Parent = root,
	})
	Theme.corner(20).Parent = pill
	Theme.stroke(C.Stroke, 2.5).Parent = pill
	Theme.gradient({ rgb(150, 70, 255), rgb(90, 30, 190) }, 90).Parent = pill
	refs.pillText = Theme.label({
		Text = "🤖 Auto-roulage en cours",
		Position = UDim2.fromOffset(14, 8),
		Size = UDim2.new(1, -140, 0, 24),
		FontFace = Theme.Faces.Heavy,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = pill,
	})
	Components.button({
		Text = "Arrêter",
		Color = C.Red,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -5, 0.5, 0),
		Size = UDim2.fromOffset(118, 32),
		TextSize = 18,
		Parent = pill,
		OnClick = function()
			if State.data and State.data.AutoBuy then
				State.invoke("Roll_SetAutoBuy", false)
			end
			if State.data and State.data.AutoRoll then
				State.invoke("SetAutoRoll", false)
			end
		end,
	})
	refs.pill = pill
	refs.root = root

	Theme.onFrame(cooldown, function()
		local left = cooldownUntil - os.clock()
		if left > 0 then
			local total = math.max(0.1, State.treeStats().rollCooldown or 3)
			cooldown.Visible = true
			cooldown.Size = UDim2.new(math.clamp(left / total, 0, 1), 0, 1, -5)
		else
			cooldown.Visible = false
		end
		refs.dice.Rotation = rolling and (refs.dice.Rotation + 12) % 360 or 0
	end)
end

-- Carte d'un perso tiré (au-dessus du panneau).
local function pullCard(parent: Instance, item, index: number)
	local rarityId = item.rarity or "common"
	local info = Theme.rarity(rarityId)
	local mutation = Mutations.get(item.aura)
	local free = Formulas.rollCollectFree(State.data, rarityId)
	local card = new("Frame", {
		Name = "Tire" .. index,
		Size = UDim2.fromOffset(212, 86),
		BackgroundColor3 = WHITE,
		LayoutOrder = index,
		Parent = parent,
	})
	Theme.corner(12).Parent = card
	if info.rainbow or (mutation and mutation.rainbow) then
		Theme.rainbowStroke(card, 3)
	else
		Theme.stroke(mutation and mutation.color or info.color, 3).Parent = card
	end
	Theme.gradient({ Theme.dark(info.rainbow and C.Magenta or info.color, 0.45), rgb(16, 16, 24) }, 90).Parent = card
	Theme.label({
		Name = "Nom",
		Text = characterName(item.id),
		Position = UDim2.fromOffset(10, 5),
		Size = UDim2.new(1, -20, 0, 22),
		FontFace = Theme.Faces.Title,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = card,
	})
	local tags = new("Frame", { Name = "Tags", Position = UDim2.fromOffset(10, 29), Size = UDim2.new(1, -20, 0, 18), BackgroundTransparency = 1, Parent = card })
	local list = Theme.list(Enum.FillDirection.Horizontal, 6, Enum.HorizontalAlignment.Left)
	list.Parent = tags
	Components.rarityTag(tags, rarityId, { Size = UDim2.fromOffset(92, 18), LayoutOrder = 1 })
	if mutation then
		local chip = new("Frame", { Name = "Mutation", Size = UDim2.fromOffset(92, 18), BackgroundColor3 = WHITE, LayoutOrder = 2, Parent = tags })
		Theme.corner(9).Parent = chip
		Theme.stroke(C.Stroke, 1.5).Parent = chip
		Theme.gradient(mutation.gradient, 0).Parent = chip
		Theme.label({
			Text = "✦ " .. mutation.name,
			Size = UDim2.new(1, -6, 1, -2),
			Position = UDim2.fromOffset(3, 1),
			FontFace = Theme.Faces.Heavy,
			StrokeThickness = 1.5,
			Parent = chip,
		})
	end
	local priceRow = new("Frame", { Position = UDim2.fromOffset(10, 54), Size = UDim2.new(1, -116, 0, 24), BackgroundTransparency = 1, Parent = card })
	Components.coinIcon(priceRow, 18, UDim2.fromOffset(9, 12))
	Theme.label({
		Text = free and "OFFERT" or Formulas.formatNumber(item.price or 0),
		Position = UDim2.fromOffset(22, 0),
		Size = UDim2.new(1, -22, 1, 0),
		FontFace = Theme.Faces.Heavy,
		TextColor3 = free and rgb(140, 255, 150) or C.Gold,
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxSize = 18,
		Parent = priceRow,
	})
	local affordable = free or (State.data and State.data.coins or 0) >= (item.price or 0)
	local key = item.key
	Components.button({
		Text = free and "Offert" or "Collecter",
		Color = affordable and C.Green or C.Gray,
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -6, 1, -6),
		Size = UDim2.fromOffset(102, 34),
		TextSize = 17,
		Parent = card,
		OnClick = function()
			if type(key) == "string" then
				collect(key)
			end
		end,
	})
	return card
end

local lastPullKey = ""
local function refresh()
	if not refs.panel then
		return
	end
	local data = State.data or {}
	local stats = State.treeStats()
	-- Pitié du Mythique
	local tier = Economy.Roll.PityRarity
	local threshold = RollPanel.pityThreshold(tier, stats.pityMult)
	local current = tonumber(data.Pity and data.Pity[tier]) or 0
	local remaining = math.max(1, threshold - current)
	refs.pityText.Text = remaining <= 1 and "MYTHIQUE GARANTI AU PROCHAIN !" or ("Mythique garanti dans " .. Formulas.formatNumber(remaining) .. " persos")
	refs.pityBar.set(current / threshold)
	-- x1 / x2 / x3
	local multi = RollPanel.currentMulti()
	for n, info in refs.multi do
		local owned = ownsMulti(n)
		Components.setButtonColor(info.button, n == multi and C.Green or (owned and C.Blue or C.Gray))
		info.tag.Visible = not owned
		if not owned then
			local pass = AutoRoll.passInfo(n == 3 and "Roll3" or "Roll2")
			info.price.Text = "🔒 " .. pass.price .. " R$"
		end
	end
	-- AUTO
	local running = data.AutoRoll == true or data.AutoBuy == true
	Components.setButtonText(refs.autoButton, running and "AUTO ✓" or "AUTO")
	Components.setButtonColor(refs.autoButton, running and C.Green or C.Purple)
	-- État
	local luck = Formulas.rollLuck(stats, player, State.now())
	local bits = {
		(string.format("Chance x%.2f", luck):gsub("%.", ",")),
		multi .. " perso" .. (multi > 1 and "s" or "") .. " par roulage",
	}
	if data.AutoBuy then
		table.insert(bits, "🛒 Achat automatique en cours")
	elseif data.AutoRoll then
		table.insert(bits, "🤖 Lancer AFK en cours")
	end
	refs.status.Text = table.concat(bits, "   ·   ")
	-- Pastille loin de la machine
	refs.pill.Visible = running and not near
	refs.pillText.Text = data.AutoBuy and "🛒 Achat automatique en cours" or "🤖 Auto-roulage en cours"
	-- Perso(s) tiré(s)
	local queue = data.RolledQueue or {}
	local parts = {}
	for _, item in queue do
		local affordable = (data.coins or 0) >= (item.price or 0)
		table.insert(parts, tostring(item.key) .. ":" .. tostring(item.price) .. ":" .. (affordable and "1" or "0"))
	end
	local key = table.concat(parts, "|") .. tostring(data.FirstCollectDone)
	if key ~= lastPullKey then
		lastPullKey = key
		Components.clear(refs.pull)
		for i, item in queue do
			if i > Economy.Roll.QueueMax then
				break
			end
			pullCard(refs.pull, item, i)
		end
	end
	refs.pull.Visible = near and #queue > 0
end

-- PANNEAUX D'ACHAT des bases (côté client, 3 fois par seconde) :
--   • au-delà de `FarDistance` studs (attribut posé par TycoonKit), version compacte (titre +
--     prix, sans la ligne d'effet) : la base reste lisible de loin sans fouillis ;
--   • désencombrement à l'écran : du plus proche au plus loin, un panneau qui en recouvrirait
--     un autre déjà affiché est caché (Formulas.declutterBoards) ; il revient quand on approche ;
--   • à la machine, les panneaux de SA base éloignés (stands...) ou situés derrière l'estrade
--     (cour) se cachent pour ne pas se dessiner derrière le perso tiré.
RollPanel.DeclutterRadius = 20
RollPanel.BoardScanEvery = 2 -- secondes entre deux recherches des panneaux (nouveaux boutons)

-- Mise en page d'une carte (même découpage que TycoonKit.layoutBoard côté serveur).
function RollPanel.layoutBoard(gui: BillboardGui, compact: boolean)
	if gui:GetAttribute("Compact") == compact then
		return
	end
	gui:SetAttribute("Compact", compact)
	local size = gui:GetAttribute(compact and "FarSize" or "NearSize")
	if typeof(size) == "UDim2" then
		gui.Size = size
	end
	local card = gui:FindFirstChild("Card")
	if not card then
		return
	end
	local title = card:FindFirstChild("Title") :: TextLabel?
	local effect = card:FindFirstChild("Effect") :: TextLabel?
	local pill = card:FindFirstChild("Pill") :: Frame?
	if title then
		title.Position = UDim2.fromScale(0.05, compact and 0.06 or 0.05)
		title.Size = UDim2.fromScale(0.9, compact and 0.46 or 0.36)
	end
	if effect then
		effect.Visible = not compact
	end
	if pill then
		pill.Position = UDim2.fromScale(0.14, compact and 0.56 or 0.63)
		pill.Size = UDim2.fromScale(0.72, compact and 0.38 or 0.32)
	end
end

local boardList: { BillboardGui } = {}
local boardScanAt = -math.huge
local function scanBoards()
	table.clear(boardList)
	local world = workspace:FindFirstChild("World")
	local plots = world and world:FindFirstChild("Plots")
	if not plots then
		return
	end
	for _, plot in plots:GetChildren() do
		local owner = plot:FindFirstChild("Owner")
		local pads = owner and owner:FindFirstChild("Pads")
		if pads then
			for _, d in pads:GetDescendants() do
				if d:IsA("BillboardGui") and d.Name == "PriceGui" then
					table.insert(boardList, d)
				end
			end
		end
	end
end

local function updateBoards()
	if os.clock() - boardScanAt > RollPanel.BoardScanEvery then
		boardScanAt = os.clock()
		scanBoards()
	end
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local camCF = camera.CFrame
	local viewport = camera.ViewportSize
	local view = {
		eye = camCF.Position,
		forward = camCF.LookVector,
		right = camCF.RightVector,
		up = camCF.UpVector,
		focal = (viewport.Y / 2) / math.tan(math.rad((camera.FieldOfView or 70) / 2)),
		w = viewport.X,
		h = viewport.Y,
	}
	local machineCF = near and RollPanel.machineCFrame()
	local myPlot = "Plot" .. tostring(player and player:GetAttribute("PlotIndex"))
	local rects, guis, atMachine = {}, {}, {}
	for _, gui in boardList do
		local adornee = gui.Adornee or gui.Parent
		if gui.Parent and adornee and adornee:IsA("BasePart") then
			local pos = adornee.CFrame.Position + gui.StudsOffsetWorldSpace
			local dist = (pos - view.eye).Magnitude
			RollPanel.layoutBoard(gui, dist > (gui:GetAttribute("FarDistance") or math.huge))
			local hidden = false
			if machineCF and gui:FindFirstAncestor(myPlot) then
				local localPos = machineCF:PointToObjectSpace(adornee.CFrame.Position)
				hidden = localPos.Magnitude > RollPanel.DeclutterRadius or localPos.Z > 4
			end
			local rect = nil
			if not hidden and dist <= gui.MaxDistance then
				local size = gui.Size
				rect = Formulas.boardRect(view, pos, size.X.Scale, size.X.Offset, size.Y.Scale / 2, size.Y.Offset / 2)
			end
			table.insert(guis, gui)
			table.insert(rects, rect or false)
			table.insert(atMachine, hidden)
		end
	end
	local shown = Formulas.declutterBoards(rects)
	for i, gui in guis do
		-- hors écran ou trop loin : rien à désencombrer (le moteur ne le dessine pas)
		local visible = if rects[i] then shown[i] == true else not atMachine[i]
		if gui.Enabled ~= visible then
			gui.Enabled = visible
		end
	end
end

-- Pour les tests : force une nouvelle recherche des panneaux et une mise à jour immédiate.
function RollPanel.updateBoards()
	boardScanAt = -math.huge
	pcall(updateBoards)
end

-- Affiche / cache les commandes selon la position du joueur.
local function setNear(value: boolean)
	if value == near then
		return
	end
	near = value
	boardScanAt = -math.huge
	pcall(updateBoards)
	refs.panel.Visible = value
	if value then
		refs.scale.Scale = 0.85
		Theme.tween(refs.scale, 0.22, { Scale = 1 }, Enum.EasingStyle.Back)
	end
	refresh()
end

function RollPanel.isNear(): boolean
	return near
end

-- Pour les tests et les rendus : force l'affichage « à la machine » (nil = position réelle).
local forced: boolean? = nil
function RollPanel.forceNear(value: boolean?)
	forced = value
	if value ~= nil then
		near = not value
		setNear(value)
	end
end

-- Place la barre ROULER et les cartes du perso tiré selon l'appareil (PC / manette / tactile).
function RollPanel.layout()
	local bottom = RollPanel.panelBottom()
	if refs.panel then
		refs.panel.Position = UDim2.new(1, -PANEL_RIGHT, 1, -bottom)
	end
	if refs.pull then
		refs.pull.Position = UDim2.new(1, -PANEL_RIGHT, 1, -bottom - PANEL_H - 8)
	end
end

function RollPanel.init(gui: ScreenGui, hudRoot: Frame?)
	local root = hudRoot or Theme.scaledRoot(gui, "RollHUD", 1)
	pcall(AutoRoll.init, gui)
	-- contours lumineux des persos mutés proches + reflet animé de l'Or (côté client)
	pcall(MutationsFx.startClient)
	build(root)
	RollPanel.layout()
	Console.onModeChanged(function()
		RollPanel.layout()
	end)
	refresh()
	State.onChanged(refresh)
	Console.setAction("roll", rollFromGamepad)
	if player then
		for _, attribute in { "Pass_Roll2", "Pass_Roll3", "Pass_AutoRoll", "Pass_AutoRollPlus", "Pass_Luck2", "Boost_Luck" } do
			player:GetAttributeChangedSignal(attribute):Connect(refresh)
		end
	end
	-- Position du joueur 4 fois par seconde ; à la machine, mise à jour complète chaque seconde
	-- (fin d'une potion de chance, etc.). La fenêtre AUTO reste ouverte si on s'éloigne.
	task.spawn(function()
		local tick = 0
		while refs.panel and refs.panel.Parent do
			local ok, value = pcall(RollPanel.isNearMachine)
			if forced ~= nil then
				value = forced
			end
			if ok then
				setNear(value and Menus.current() ~= "SkillTree")
			end
			tick += 1
			if near and tick % 4 == 0 then
				refresh()
			end
			pcall(updateBoards)
			task.wait(0.3)
		end
	end)
end

function RollPanel.panel(): Frame?
	return refs.panel
end

function RollPanel.refs()
	return refs
end

return RollPanel
