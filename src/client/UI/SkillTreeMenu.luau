-- ARBRE DE COMPÉTENCES (bouton « Améliorations ») : nœuds hexagonaux reliés, posés par-dessus le
-- monde comme dans les jeux de référence. États : verrouillé / disponible / acheté.
--   • Souris : clic = choisir, glisser = déplacer, molette = zoom.
--   • Tactile : toucher = choisir, glisser = déplacer, pincer = zoom.
--   • Manette : croix/joystick = passer d'un nœud à l'autre (la vue suit), A = acheter,
--     LT/RT = zoom, B = fermer.
-- Données : Shared.Config.SkillTree (domaine BASE) — achat par la RemoteFunction « BuySkill ».

local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")

local Theme = require(script.Parent.Theme)
local Icons = require(script.Parent.Icons)
local Components = require(script.Parent.Components)
local Console = require(script.Parent.Console)
local Menus = require(script.Parent.Menus)
local Notifications = require(script.Parent.Notifications)
local State = require(script.Parent.Parent.State)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Formulas = require(Shared.Modules.Formulas)

local SkillTreeMenu = {}

local C = Theme.Colors
local new = Theme.new
local WHITE = Color3.new(1, 1, 1)
local rgb = Color3.fromRGB

local HEX = 44 -- distance centre-sommet de la grille (espacement)
local NODE_R = 38 -- rayon visuel d'un nœud

local STATE_STYLE = {
	owned = { rim = rgb(255, 226, 120), fill = rgb(255, 150, 30), inner = rgb(255, 196, 70), link = rgb(255, 196, 60), text = WHITE },
	available = { rim = rgb(130, 210, 255), fill = rgb(30, 110, 230), inner = rgb(60, 150, 255), link = rgb(110, 190, 255), text = WHITE },
	locked = { rim = rgb(70, 78, 100), fill = rgb(28, 32, 46), inner = rgb(40, 46, 64), link = rgb(60, 64, 80), text = rgb(150, 155, 175) },
}

local root: Frame
local canvas: Frame
local board: Frame
local zoomScale: UIScale
local refs: { [string]: any } = {}
local nodeViews: { [string]: any } = {}
local selectedId: string? = nil
local isOpen = false
local pan = Vector2.zero
local zoom = 1

local function nodeState(node, owned): string
	if owned[node.id] then
		return "owned"
	end
	for _, req in node.requires or {} do
		if not owned[req] then
			return "locked"
		end
	end
	return "available"
end

local function axialToPixel(q: number, r: number): Vector2
	return Vector2.new(HEX * math.sqrt(3) * (q + r / 2), HEX * 1.5 * r)
end

local function currencyName(node): string
	local currency = node.currency or "Coins"
	if currency == "Coins" then
		return "pièces"
	end
	return currency
end

------------------------------------------------------------------------
-- Vue d'un nœud
------------------------------------------------------------------------

local function buildNode(node)
	local pos = axialToPixel(node.q, node.r)
	local button = new("TextButton", {
		Name = "Node_" .. node.id,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(pos.X, pos.Y),
		Size = UDim2.fromOffset(NODE_R * 2, NODE_R * 2),
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Text = "",
		ZIndex = 3,
		Parent = board,
	})
	local scale = new("UIScale", { Parent = button })
	local rim = Components.hexagon(button, NODE_R, STATE_STYLE.locked.rim, { Name = "Rim", ZIndex = 3 })
	local outline = Components.hexagon(button, NODE_R + 3, rgb(6, 6, 10), { Name = "Outline", ZIndex = 2 })
	local _ = outline
	local fill = Components.hexagon(button, NODE_R - 5, STATE_STYLE.locked.fill, { Name = "Fill", ZIndex = 4 })
	local inner = Components.hexagon(button, NODE_R - 13, STATE_STYLE.locked.inner, { Name = "Inner", ZIndex = 5, Position = UDim2.new(0.5, 0, 0.5, -3) })
	local iconHolder = new("Frame", {
		Name = "Icon",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, -7),
		Size = UDim2.fromOffset(32, 32),
		BackgroundTransparency = 1,
		ZIndex = 6,
		Parent = button,
	})
	local iconName = Icons.has(node.icon or "") and node.icon or (Icons.FromEmoji[node.icon or ""] or node.icon or "star")
	Icons.make(iconName, iconHolder, { px = 32, zindex = 6, ink = rgb(20, 40, 90) })
	local label = Theme.label({
		Name = "Caption",
		Text = node.name,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0.5, 11),
		Size = UDim2.fromOffset(64, 14),
		FontFace = Theme.Faces.Heavy,
		ZIndex = 7,
		StrokeThickness = 1.2,
		Parent = button,
	})
	local lock = new("Frame", {
		Name = "Lock",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0, 6),
		Size = UDim2.fromOffset(20, 20),
		BackgroundTransparency = 1,
		ZIndex = 8,
		Visible = false,
		Parent = button,
	})
	Icons.make("lock", lock, { px = 20, zindex = 8, ink = rgb(28, 32, 46) })
	local view = { button = button, rim = rim, fill = fill, inner = inner, icon = iconHolder, label = label, lock = lock, scale = scale, node = node, pos = pos }
	button.Selectable = true
	button.SelectionImageObject = Components.selectionImage
	button.MouseEnter:Connect(function()
		Theme.tween(scale, 0.1, { Scale = 1.1 })
		SkillTreeMenu.select(node.id, false)
	end)
	button.MouseLeave:Connect(function()
		if selectedId ~= node.id then
			Theme.tween(scale, 0.1, { Scale = 1 })
		end
	end)
	pcall(function()
		button.SelectionGained:Connect(function()
			SkillTreeMenu.select(node.id, true)
			Components.hover()
		end)
	end)
	button.Activated:Connect(function()
		if Console.isGamepad() or selectedId == node.id then
			SkillTreeMenu.buy(node.id)
		else
			Components.click()
			SkillTreeMenu.select(node.id, false)
		end
	end)
	return view
end

local function buildLink(fromPos: Vector2, toPos: Vector2): Frame
	local delta = toPos - fromPos
	local mid = (fromPos + toPos) / 2
	local link = new("Frame", {
		Name = "Link",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(mid.X, mid.Y),
		Size = UDim2.fromOffset(delta.Magnitude, 7),
		Rotation = math.deg(math.atan2(delta.Y, delta.X)),
		BackgroundColor3 = STATE_STYLE.locked.link,
		BorderSizePixel = 0,
		ZIndex = 1,
		Parent = board,
	})
	Theme.stroke(rgb(6, 6, 10), 1.5).Parent = link
	return link
end

------------------------------------------------------------------------
-- Rafraîchissement
------------------------------------------------------------------------

local function refreshNodes()
	local tree = State.skillTree()
	local owned = State.skills()
	local coins = State.data and State.data.coins or 0
	for _, node in tree.Nodes do
		local view = nodeViews[node.id]
		if view then
			local st = nodeState(node, owned)
			local style = STATE_STYLE[st]
			Components.setHexColor(view.rim, style.rim)
			Components.setHexColor(view.fill, style.fill)
			Components.setHexColor(view.inner, style.inner)
			view.lock.Visible = st == "locked"
			view.label.TextColor3 = style.text
			view.icon.Visible = true
			for _, child in view.icon:GetDescendants() do
				if child:IsA("Frame") and child.Name == "Shape" then
					child.BackgroundTransparency = st == "locked" and 0.45 or 0
				end
			end
			-- Lueur douce sur les nœuds achetables maintenant
			view.affordable = st == "available" and coins >= node.cost
			for _, link in view.links or {} do
				local reqState = owned[link.req] and (owned[node.id] and "owned" or "available") or "locked"
				link.frame.BackgroundColor3 = STATE_STYLE[reqState].link
			end
		end
	end
	-- Résumé des statistiques
	local stats = State.treeStats()
	local lines = {
		{ "Chance", string.format("x%.2f", stats.luck or 1), "clover" },
		{ "Persos par tirage", tostring(stats.rollsPerPull or 1), "team" },
		{ "Temps de roulage", string.format("%.1f s", stats.rollCooldown or 3.5), "hourglass" },
		{ "Chance x10 tous les", tostring(stats.x10Every or 10) .. " roul.", "dice" },
		{ "Pitié", string.format("x%.2f", stats.pityMult or 1), "shield" },
		{ "Auto-roulage", stats.autoRoll and "Oui" or "Non", "robot" },
		{ "Revenu", string.format("+%d%%", math.floor(((stats.income or 1) - 1) * 100 + 0.5)), "coin" },
		{ "Dégâts", string.format("+%d%%", math.floor(((stats.damage or 1) - 1) * 100 + 0.5)), "sword" },
		{ "Critique", string.format("+%d%%", math.floor((stats.crit or 0) * 100 + 0.5)), "target" },
		{ "Emplacements", "+" .. tostring(stats.unitSlots or 0), "grid" },
	}
	for i, line in lines do
		local row = refs.statRows[i]
		if row then
			row.name.Text = line[1]
			row.value.Text = line[2]
		end
	end
	local count, total = 0, #tree.Nodes
	for _, node in tree.Nodes do
		if owned[node.id] then
			count += 1
		end
	end
	refs.progress.Text = count .. " / " .. total .. " nœuds"
	refs.coins.Text = Formulas.formatNumber(coins)
	SkillTreeMenu.updateInfo()
end

-- Panneau d'information du nœud choisi (nom, effet, coût, bouton d'achat).
function SkillTreeMenu.updateInfo()
	local tree = State.skillTree()
	local node = selectedId and tree.get(selectedId)
	local panel = refs.info
	if not node then
		refs.infoName.Text = "Choisis un nœud"
		refs.infoDesc.Text = "Chaque nœud améliore ta machine ROULER, tes revenus ou ton équipe. Commence par le cœur, au centre !"
		refs.infoCost.Text = ""
		refs.buyButton.Visible = false
		Components.clear(refs.infoIcon)
		Icons.make("upgrade", refs.infoIcon, { px = 56, ink = rgb(150, 80, 10) })
		return
	end
	local owned = State.skills()
	local st = nodeState(node, owned)
	local style = STATE_STYLE[st]
	refs.infoName.Text = node.name
	refs.infoDesc.Text = node.desc or ""
	Components.clear(refs.infoIcon)
	local iconName = Icons.has(node.icon or "") and node.icon or (Icons.FromEmoji[node.icon or ""] or node.icon or "star")
	Icons.make(iconName, refs.infoIcon, { px = 56, ink = style.fill })
	refs.infoHex.BackgroundColor3 = style.fill
	local coins = State.data and State.data.coins or 0
	refs.buyButton.Visible = true
	if st == "owned" then
		refs.infoCost.Text = "ACHETÉ"
		refs.infoCost.TextColor3 = C.Gold
		Components.setButtonText(refs.buyButton, "Acquis")
		Components.setButtonColor(refs.buyButton, C.Gray)
	elseif st == "locked" then
		local names = {}
		for _, req in node.requires or {} do
			local r = tree.get(req)
			if r and not owned[req] then
				table.insert(names, r.name)
			end
		end
		refs.infoCost.Text = "Coût : " .. Formulas.formatNumber(node.cost) .. " " .. currencyName(node)
		refs.infoCost.TextColor3 = C.TextDim
		Components.setButtonText(refs.buyButton, "Requiert : " .. table.concat(names, ", "))
		Components.setButtonColor(refs.buyButton, C.Gray)
	else
		local can = coins >= node.cost
		refs.infoCost.Text = "Coût : " .. Formulas.formatNumber(node.cost) .. " " .. currencyName(node)
		refs.infoCost.TextColor3 = can and C.Gold or C.Red
		Components.setButtonText(refs.buyButton, can and "ACHETER" or ("Il manque " .. Formulas.formatNumber(node.cost - coins)))
		Components.setButtonColor(refs.buyButton, can and C.Green or rgb(150, 60, 60))
	end
	local _ = panel
	-- Bulle au-dessus du nœud
	local view = nodeViews[node.id]
	if view then
		refs.bubble.Visible = true
		refs.bubble.Position = UDim2.fromOffset(view.pos.X, view.pos.Y - NODE_R - 8)
		refs.bubbleName.Text = node.name
		refs.bubbleCost.Text = st == "owned" and "Acquis" or (Formulas.formatNumber(node.cost) .. " pièces")
		refs.bubbleCost.TextColor3 = st == "owned" and C.Gold or ((coins >= node.cost and st == "available") and C.Green or C.TextDim)
	end
end

------------------------------------------------------------------------
-- Sélection, déplacement, zoom, achat
------------------------------------------------------------------------

local function applyView()
	board.Position = UDim2.new(0.5, pan.X, 0.5, pan.Y)
	zoomScale.Scale = zoom
end

function SkillTreeMenu.centerOn(id: string, smooth: boolean?)
	local view = nodeViews[id]
	if not view then
		return
	end
	pan = -view.pos * zoom
	if smooth then
		Theme.tween(board, 0.25, { Position = UDim2.new(0.5, pan.X, 0.5, pan.Y) })
	else
		applyView()
	end
end

function SkillTreeMenu.select(id: string, follow: boolean?)
	local previous = selectedId and nodeViews[selectedId]
	if previous and selectedId ~= id then
		Theme.tween(previous.scale, 0.1, { Scale = 1 })
	end
	selectedId = id
	local view = nodeViews[id]
	if view then
		Theme.tween(view.scale, 0.12, { Scale = 1.12 }, Enum.EasingStyle.Back)
	end
	if follow then
		SkillTreeMenu.centerOn(id, true)
	end
	SkillTreeMenu.updateInfo()
end

function SkillTreeMenu.buy(id: string?)
	local target = id or selectedId
	if not target then
		return
	end
	local tree = State.skillTree()
	local node = tree.get(target)
	if not node then
		return
	end
	local owned = State.skills()
	local st = nodeState(node, owned)
	if st == "owned" then
		Notifications.toast(node.name .. " est déjà acquis.", "info")
		return
	elseif st == "locked" then
		Components.errorSound()
		Notifications.toast("Achète d'abord les nœuds reliés à celui-ci.", "error")
		return
	end
	local ok, message = State.invoke("BuySkill", target)
	if ok then
		Components.click()
		local view = nodeViews[target]
		if view then
			view.scale.Scale = 1.5
			Theme.tween(view.scale, 0.4, { Scale = 1.12 }, Enum.EasingStyle.Back)
			-- Anneau d'étincelles
			for i = 1, 8 do
				local a = i / 8 * math.pi * 2
				local s = Theme.sparkle(board, UDim2.fromOffset(view.pos.X, view.pos.Y), 16, 0, 9)
				Theme.tween(s, 0.6, { Position = UDim2.fromOffset(view.pos.X + math.cos(a) * 70, view.pos.Y + math.sin(a) * 70), Rotation = 180 })
				task.delay(0.65, function()
					s:Destroy()
				end)
			end
		end
		Notifications.toast(type(message) == "string" and message or (node.name .. " débloqué !"), "success")
	else
		Components.errorSound()
		Notifications.toast(type(message) == "string" and message or "Impossible pour l'instant.", "error")
	end
	task.delay(0.1, refreshNodes)
end

local function setZoom(value: number)
	local old = zoom
	zoom = math.clamp(value, 0.45, 1.6)
	pan = pan * (zoom / old)
	applyView()
end

------------------------------------------------------------------------
-- Construction de l'écran
------------------------------------------------------------------------

local function buildScreen(gui: ScreenGui)
	root = Theme.scaledRoot(gui, "SkillTree", 12)
	root.Visible = false
	-- Fond : le monde reste visible mais assombri (bleu nuit), plus sombre sur les bords.
	local dim = new("Frame", {
		Name = "Dim",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = WHITE,
		BackgroundTransparency = 0.18,
		BorderSizePixel = 0,
		Parent = root,
	})
	Theme.gradient({ rgb(6, 10, 26), rgb(14, 26, 58), rgb(6, 10, 26) }, 90, { 0.05, 0.3, 0.05 }).Parent = dim
	Theme.sparkles(dim, 26, 5, 0.82)
	canvas = new("Frame", {
		Name = "Canvas",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Parent = root,
	})
	local drag = new("TextButton", {
		Name = "Drag",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		Selectable = false,
		Parent = canvas,
	})
	board = new("Frame", {
		Name = "Board",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(0, 0),
		BackgroundTransparency = 1,
		Parent = canvas,
	})
	zoomScale = new("UIScale", { Parent = board })

	-- Bulle d'info (au-dessus du nœud choisi)
	local bubble = new("Frame", {
		Name = "Bubble",
		AnchorPoint = Vector2.new(0.5, 1),
		Size = UDim2.fromOffset(190, 52),
		BackgroundColor3 = rgb(14, 16, 26),
		BackgroundTransparency = 0.1,
		Visible = false,
		ZIndex = 20,
		Parent = board,
	})
	Theme.corner(10).Parent = bubble
	Theme.stroke(rgb(130, 210, 255), 2).Parent = bubble
	refs.bubble = bubble
	refs.bubbleName = Theme.label({ Size = UDim2.new(1, -12, 0, 24), Position = UDim2.fromOffset(6, 4), FontFace = Theme.Faces.Title, ZIndex = 21, Parent = bubble })
	refs.bubbleCost = Theme.label({ Size = UDim2.new(1, -12, 0, 18), Position = UDim2.fromOffset(6, 29), FontFace = Theme.Faces.Heavy, ZIndex = 21, Parent = bubble })

	-- Barre du haut : titre, progression, pièces, fermer
	local top = new("Frame", {
		Name = "Top",
		Position = UDim2.fromOffset(16, 12),
		Size = UDim2.new(1, -32, 0, 64),
		BackgroundColor3 = WHITE,
		Parent = root,
	})
	Theme.corner(16).Parent = top
	Theme.stroke(C.Stroke, 3).Parent = top
	Theme.gradient({ rgb(240, 170, 30), rgb(170, 90, 10), rgb(40, 24, 10) }, 0).Parent = top
	Theme.sparkles(top, 10, 77, 0.7)
	local titleIcon = new("Frame", { Position = UDim2.fromOffset(14, 8), Size = UDim2.fromOffset(48, 48), BackgroundTransparency = 1, Parent = top })
	Icons.make("upgrade", titleIcon, { px = 48, ink = rgb(150, 80, 10) })
	Theme.label({
		Text = "AMÉLIORATIONS",
		Position = UDim2.fromOffset(72, 8),
		Size = UDim2.fromOffset(330, 32),
		FontFace = Theme.Faces.Title,
		TextXAlignment = Enum.TextXAlignment.Left,
		StrokeThickness = 3,
		Parent = top,
	})
	refs.progress = Theme.label({
		Position = UDim2.fromOffset(74, 40),
		Size = UDim2.fromOffset(300, 18),
		FontFace = Theme.Faces.Heavy,
		TextColor3 = rgb(255, 240, 200),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = top,
	})
	local coinBox = new("Frame", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -84, 0.5, 0),
		Size = UDim2.fromOffset(220, 44),
		BackgroundColor3 = rgb(10, 10, 14),
		BackgroundTransparency = 0.3,
		Parent = top,
	})
	Theme.round().Parent = coinBox
	Theme.stroke(C.Gold, 2).Parent = coinBox
	Components.coinIcon(coinBox, 36, UDim2.fromOffset(22, 22))
	refs.coins = Theme.label({
		Position = UDim2.fromOffset(46, 6),
		Size = UDim2.new(1, -58, 1, -12),
		FontFace = Theme.Faces.Heavy,
		TextColor3 = C.Gold,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = coinBox,
	})
	local close = new("TextButton", {
		Name = "Close",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -14, 0.5, 0),
		Size = UDim2.fromOffset(50, 50),
		BackgroundColor3 = WHITE,
		AutoButtonColor = false,
		Text = "",
		Parent = top,
	})
	Theme.corner(12).Parent = close
	Theme.stroke(C.Stroke, 2.5).Parent = close
	Theme.gradient({ rgb(255, 110, 110), rgb(220, 40, 50), rgb(150, 20, 30) }, 90).Parent = close
	Icons.make("close", close, { px = 30, size = UDim2.fromScale(0.5, 0.5) })
	Components.interactive(close, new("UIScale", { Parent = close }), 1.1)
	Console.hint(close, "B", { Position = UDim2.new(0, -14, 1, -14) })
	close.Activated:Connect(function()
		Components.click()
		Menus.close("SkillTree")
	end)

	-- Panneau des statistiques (gauche)
	local statsPanel = Components.panel(root, { Name = "StatsPanel", Position = UDim2.fromOffset(16, 90), Size = UDim2.fromOffset(250, 384) }, rgb(240, 170, 30))
	statsPanel.BackgroundTransparency = 0.08
	Theme.label({
		Text = "TES BONUS",
		Position = UDim2.fromOffset(14, 10),
		Size = UDim2.new(1, -28, 0, 24),
		FontFace = Theme.Faces.Title,
		TextColor3 = C.Gold,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = statsPanel,
	})
	refs.statRows = {}
	local icons = { "clover", "team", "hourglass", "dice", "shield", "robot", "coin", "sword", "target", "grid" }
	for i = 1, 10 do
		local y = 40 + (i - 1) * 33
		local ic = new("Frame", { Position = UDim2.fromOffset(12, y + 3), Size = UDim2.fromOffset(22, 22), BackgroundTransparency = 1, Parent = statsPanel })
		Icons.make(icons[i], ic, { px = 22, color = rgb(255, 214, 120), ink = rgb(40, 30, 10) })
		local name = Theme.label({
			Position = UDim2.fromOffset(42, y + 4),
			Size = UDim2.new(0.62, -40, 0, 20),
			FontFace = Theme.Faces.Bold,
			TextColor3 = C.TextDim,
			TextXAlignment = Enum.TextXAlignment.Left,
			StrokeThickness = 1,
			Parent = statsPanel,
		})
		local value = Theme.label({
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -12, 0, y + 3),
			Size = UDim2.new(0.38, 0, 0, 22),
			FontFace = Theme.Faces.Heavy,
			TextXAlignment = Enum.TextXAlignment.Right,
			Parent = statsPanel,
		})
		refs.statRows[i] = { name = name, value = value }
	end

	-- Panneau d'information + achat (bas)
	local info = Components.panel(root, {
		Name = "Info",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -40),
		Size = UDim2.fromOffset(700, 112),
	}, rgb(110, 190, 255))
	refs.info = info
	local infoHex = new("Frame", { Position = UDim2.fromOffset(16, 16), Size = UDim2.fromOffset(80, 80), BackgroundColor3 = rgb(30, 110, 230), Parent = info })
	Theme.corner(18).Parent = infoHex
	Theme.stroke(rgb(130, 210, 255), 2.5).Parent = infoHex
	refs.infoHex = infoHex
	refs.infoIcon = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(56, 56), BackgroundTransparency = 1, Parent = infoHex })
	refs.infoName = Theme.label({
		Position = UDim2.fromOffset(112, 12),
		Size = UDim2.new(1, -350, 0, 30),
		FontFace = Theme.Faces.Title,
		TextXAlignment = Enum.TextXAlignment.Left,
		StrokeThickness = 2.5,
		Parent = info,
	})
	refs.infoDesc = Theme.label({
		Position = UDim2.fromOffset(112, 44),
		Size = UDim2.new(1, -350, 0, 40),
		FontFace = Theme.Faces.Bold,
		TextColor3 = C.TextDim,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = true,
		MaxSize = 18,
		StrokeThickness = 1,
		Parent = info,
	})
	refs.infoCost = Theme.label({
		Position = UDim2.fromOffset(112, 84),
		Size = UDim2.new(1, -350, 0, 20),
		FontFace = Theme.Faces.Heavy,
		TextColor3 = C.Gold,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = info,
	})
	refs.buyButton = Components.button({
		Text = "ACHETER",
		Color = C.Green,
		Icon = "upgrade",
		Hint = "A",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -16, 0.5, 0),
		Size = UDim2.fromOffset(220, 62),
		TextSize = 22,
		Parent = info,
		OnClick = function()
			SkillTreeMenu.buy()
		end,
	})
	refs.buyButton.Selectable = false

	-- Indications
	Console.hintBar(root, { { "A", "Acheter" }, { "B", "Fermer" }, { "LT", "Zoom -" }, { "RT", "Zoom +" } }, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -6),
	})
	local mouseHelp = Theme.label({
		Name = "MouseHelp",
		Text = "Glisse pour te déplacer · molette ou pincement pour zoomer",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -10),
		Size = UDim2.fromOffset(600, 20),
		FontFace = Theme.Faces.Bold,
		TextColor3 = C.TextDim,
		StrokeThickness = 1.5,
		Parent = root,
	})
	Console.onModeChanged(function(gamepad)
		mouseHelp.Visible = not gamepad
	end)
	mouseHelp.Visible = not Console.isGamepad()

	-- Déplacement à la souris / au doigt
	local dragging = false
	local last = Vector2.zero
	drag.MouseButton1Down:Connect(function()
		dragging = true
		last = UserInputService:GetMouseLocation()
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)
	pcall(function()
		UserInputService.InputChanged:Connect(function(input)
			if not isOpen then
				return
			end
			if input.UserInputType == Enum.UserInputType.MouseWheel then
				setZoom(zoom * (input.Position.Z > 0 and 1.12 or 1 / 1.12))
			elseif dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
				local now = UserInputService:GetMouseLocation()
				local delta = (now - last) / math.max(0.1, Theme.getScale())
				last = now
				pan += delta
				applyView()
			elseif input.KeyCode == Enum.KeyCode.Thumbstick2 then
				local v = Vector2.new(input.Position.X, -input.Position.Y)
				if v.Magnitude > 0.2 then
					pan -= v * 14
					applyView()
				end
			end
		end)
		UserInputService.TouchPinch:Connect(function(_, scale, _, state)
			if isOpen and state == Enum.UserInputState.Change then
				setZoom(zoom * (1 + (scale - 1) * 0.08))
			end
		end)
	end)
end

local function buildBoard()
	refs.bubble.Parent = canvas
	Components.clear(board)
	refs.bubble.Parent = board
	nodeViews = {}
	local tree = State.skillTree()
	for _, node in tree.Nodes do
		nodeViews[node.id] = buildNode(node)
	end
	for _, node in tree.Nodes do
		local view = nodeViews[node.id]
		view.links = {}
		for _, req in node.requires or {} do
			local other = nodeViews[req]
			if other then
				table.insert(view.links, { req = req, frame = buildLink(other.pos, view.pos) })
			end
		end
	end
	-- Navigation manette : voisins hexagonaux directs quand ils existent.
	local byCoord = {}
	for _, node in tree.Nodes do
		byCoord[node.q .. "," .. node.r] = nodeViews[node.id]
	end
	for _, node in tree.Nodes do
		local view = nodeViews[node.id]
		local function at(dq, dr)
			local other = byCoord[(node.q + dq) .. "," .. (node.r + dr)]
			return other and other.button
		end
		pcall(function()
			view.button.NextSelectionUp = at(0, -1) or at(1, -1)
			view.button.NextSelectionDown = at(0, 1) or at(-1, 1)
			view.button.NextSelectionLeft = at(-1, 0)
			view.button.NextSelectionRight = at(1, 0)
		end)
	end
end

local function firstNode(): GuiObject?
	local tree = State.skillTree()
	local owned = State.skills()
	local best = nil
	for _, node in tree.Nodes do
		if nodeState(node, owned) == "available" then
			best = best or node
		end
	end
	best = best or tree.Nodes[1]
	return best and nodeViews[best.id] and nodeViews[best.id].button
end

local function bindZoom(enable: boolean)
	pcall(function()
		if enable then
			ContextActionService:BindActionAtPriority("AT_Zoom", function(_, state, input)
				if state == Enum.UserInputState.Begin then
					setZoom(zoom * (input.KeyCode == Enum.KeyCode.ButtonR2 and 1.2 or 1 / 1.2))
				end
				return Enum.ContextActionResult.Sink
			end, false, Enum.ContextActionPriority.High.Value + 10, Enum.KeyCode.ButtonL2, Enum.KeyCode.ButtonR2)
		else
			ContextActionService:UnbindAction("AT_Zoom")
		end
	end)
end

function SkillTreeMenu.open()
	if isOpen then
		return
	end
	isOpen = true
	if next(nodeViews) == nil then
		buildBoard()
	end
	root.Visible = true
	local start = firstNode()
	local startId = start and string.sub(start.Name, 6)
	zoom = 1
	if startId and nodeViews[startId] then
		selectedId = nil
		SkillTreeMenu.select(startId, false)
		SkillTreeMenu.centerOn(startId, false)
	else
		pan = Vector2.zero
		applyView()
	end
	refreshNodes()
	bindZoom(true)
end

function SkillTreeMenu.close()
	if not isOpen then
		return
	end
	isOpen = false
	root.Visible = false
	bindZoom(false)
	Menus.closed("SkillTree")
end

function SkillTreeMenu.init(gui: ScreenGui)
	buildScreen(gui)
	buildBoard()
	Menus.register("SkillTree", {
		open = SkillTreeMenu.open,
		close = SkillTreeMenu.close,
		selection = firstNode,
	})
	State.onChanged(function()
		if isOpen then
			refreshNodes()
		end
	end)
	-- Les nœuds achetables brillent doucement.
	Theme.onFrame(board, function(_, t)
		if not isOpen then
			return
		end
		local pulse = 0.5 + math.sin(t * 4) * 0.5
		for _, view in nodeViews do
			if view.affordable then
				Components.setHexColor(view.rim, STATE_STYLE.available.rim:Lerp(WHITE, pulse * 0.6))
			end
		end
	end)
end

-- Pour les tests : nombre de nœuds affichés.
function SkillTreeMenu.nodeCount(): number
	local n = 0
	for _ in nodeViews do
		n += 1
	end
	return n
end

return SkillTreeMenu
