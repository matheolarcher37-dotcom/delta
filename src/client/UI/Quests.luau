-- DÉFIS : écran des défis (du jour, univers, combat, progression, entraînement), suivi des
-- défis à l'écran (bandeaux de progression / réussite), panneau de la zone anti-AFK et
-- animation des punching-balls (balancement, « +1 », palier atteint).
--
-- Tout se joue à la souris, au tactile et à la manette (onglets LB / RB, A pour réclamer).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local QuestsConfig = require(Shared.Config.Quests)
local Layout = require(Shared.Config.Layout)
local Universes = require(Shared.Config.Universes)
local Remotes = require(Shared.Modules.Remotes)

local Theme = require(script.Parent.Theme)
local Icons = require(script.Parent.Icons)
local Components = require(script.Parent.Components)
local Menus = require(script.Parent.Menus)
local Notifications = require(script.Parent.Notifications)
local Console = require(script.Parent.Console)
local State = require(script.Parent.Parent.State)

local Quests = {}

local C = Theme.Colors
local new = Theme.new
local WHITE = Color3.new(1, 1, 1)
local ACCENT = Color3.fromRGB(255, 170, 40)
local GEM = QuestsConfig.Gems.Color
local READY = Color3.fromRGB(70, 214, 96)
local WINDOW_SIZE = Vector2.new(1180, 640) -- fenêtre Défis (unités logiques : même taille à toutes les résolutions)
local fmt = QuestsConfig.formatNumber

-- string.upper ne gère pas les lettres accentuées (UTF-8) : « Planète » → « PLANÈTE ».
local ACCENTS = {
	["é"] = "É",
	["è"] = "È",
	["ê"] = "Ê",
	["ë"] = "Ë",
	["à"] = "À",
	["â"] = "Â",
	["ç"] = "Ç",
	["î"] = "Î",
	["ï"] = "Ï",
	["ô"] = "Ô",
	["ù"] = "Ù",
	["û"] = "Û",
}
local function upper(text: string): string
	local out = string.upper(text)
	for lower, up in ACCENTS do
		out = string.gsub(out, lower, up)
	end
	return out
end

local TABS = {
	{ id = "daily", text = "Du jour", icon = "calendar" },
	{ id = "univers", text = "Univers", icon = "pin" },
	{ id = "combat", text = "Combat", icon = "sword" },
	{ id = "progression", text = "Progression", icon = "upgrade" },
	{ id = "afk", text = "Entraînement", icon = "punchbag" },
}

local window
local refs: { [string]: any } = {}
local tabId = "daily"
local render: (boolean?) -> ()

local claimSound = Instance.new("Sound")
claimSound.SoundId = "rbxasset://sounds/electronicpingshort.wav"
claimSound.Volume = 0.4
claimSound.Parent = SoundService

local hitSound = Instance.new("Sound")
hitSound.SoundId = "rbxasset://sounds/swordlunge.wav"
hitSound.Volume = 0.25
hitSound.Parent = SoundService

------------------------------------------------------------------------
-- Icônes propres aux défis (dessinées avec des Frames, comme UI/Icons) : punching-ball,
-- trophée et cible (anneaux bien empilés). Les autres icônes viennent de UI/Icons.
------------------------------------------------------------------------

-- Forme : { k = "r" | "c" | "o", x, y, w, h (0-1), rad (arrondi), rot (degrés), ink (détail), th, z (couche) }
local function sr(x, y, w, h, rad, rot, ink, z)
	return { k = "r", x = x, y = y, w = w, h = h, rad = rad or 0, rot = rot or 0, ink = ink, z = z or (ink and 1 or 0) }
end
local function sc(x, y, d, ink, z)
	return { k = "c", x = x, y = y, w = d, h = d, ink = ink, z = z or (ink and 1 or 0) }
end
local function so(x, y, d, th, ink, z)
	return { k = "o", x = x, y = y, w = d, h = d, th = th, ink = ink, z = z or (ink and 1 or 0) }
end
local CUSTOM_ICONS: { [string]: { any } } = {
	-- Punching-ball : crochet, chaîne, sac arrondi avec deux sangles et un écusson.
	punchbag = {
		sr(0.5, 0.05, 0.36, 0.08, 0.5),
		sr(0.5, 0.14, 0.07, 0.14, 0.3),
		so(0.5, 0.21, 0.13, 0.05),
		sr(0.5, 0.58, 0.5, 0.68, 0.42),
		sr(0.5, 0.36, 0.5, 0.07, 0, 0, true),
		sr(0.5, 0.8, 0.5, 0.07, 0, 0, true),
		sc(0.5, 0.58, 0.17, true),
		sr(0.37, 0.58, 0.07, 0.38, 0.5, 0, false, 2),
	},
	-- Trophée : coupe, anses, pied, socle, étoile gravée.
	trophy = {
		so(0.2, 0.36, 0.26, 0.07),
		so(0.8, 0.36, 0.26, 0.07),
		sr(0.5, 0.33, 0.56, 0.44, 0.3),
		sr(0.5, 0.17, 0.62, 0.1, 0.4),
		sr(0.5, 0.64, 0.14, 0.2, 0.2),
		sr(0.5, 0.78, 0.42, 0.1, 0.3),
		sr(0.5, 0.88, 0.58, 0.1, 0.3),
		sr(0.5, 0.36, 0.17, 0.17, 0.15, 45, true),
		sr(0.5, 0.88, 0.36, 0.035, 0, 0, true),
	},
	-- Épée en diagonale (« / ») : pommeau, poignée filetée, garde transversale, lame à gouttière
	-- et pointe (un carré droit dont le coin suit l'axe de la lame tournée à 45°).
	sword = {
		sr(0.586, 0.414, 0.15, 0.6, 0.15, 45, false, 0), -- lame
		sr(0.794, 0.206, 0.106, 0.106, 0, 0, false, 0), -- pointe
		sr(0.57, 0.43, 0.03, 0.44, 0.5, 45, true, 1), -- gouttière
		sr(0.358, 0.642, 0.4, 0.075, 0.5, 45, false, 2), -- garde (perpendiculaire à la lame)
		sc(0.494, 0.778, 0.1, false, 2), -- boules au bout de la garde
		sc(0.222, 0.506, 0.1, false, 2),
		sr(0.358, 0.642, 0.3, 0.022, 0, 45, true, 3), -- filet gravé sur la garde
		sr(0.285, 0.715, 0.085, 0.2, 0.3, 45, false, 2), -- poignée
		sr(0.3, 0.7, 0.1, 0.024, 0, 45, true, 3), -- filetage
		sr(0.265, 0.735, 0.1, 0.024, 0, 45, true, 3),
		sc(0.2, 0.8, 0.13, false, 3), -- pommeau
		sc(0.2, 0.8, 0.05, true, 4),
	},
	-- Cible : anneaux empilés du plus grand au plus petit (chacun sur sa propre couche).
	target = {
		sc(0.5, 0.5, 0.88, false, 0),
		sc(0.5, 0.5, 0.66, true, 1),
		sc(0.5, 0.5, 0.44, false, 2),
		sc(0.5, 0.5, 0.2, true, 3),
	},
}

local function drawCustomShape(holder: Frame, shape, color: Color3, ink: Color3, px: number, z: number, transparency: number)
	local fill = shape.ink and ink or color
	local frame = new("Frame", {
		Name = shape.ink and "Ink" or "Shape",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(shape.x, shape.y),
		Size = UDim2.fromScale(shape.w, shape.h),
		Rotation = shape.rot or 0,
		BackgroundColor3 = fill,
		BackgroundTransparency = shape.k == "o" and 1 or transparency,
		BorderSizePixel = 0,
		ZIndex = z,
		Parent = holder,
	})
	if shape.k == "c" or shape.k == "o" then
		new("UICorner", { CornerRadius = UDim.new(0.5, 0), Parent = frame })
	elseif (shape.rad or 0) > 0 then
		new("UICorner", { CornerRadius = UDim.new(shape.rad, 0), Parent = frame })
	end
	if shape.k == "o" then
		new("UIStroke", {
			Color = fill,
			Thickness = math.max(1.5, (shape.th or 0.08) * px),
			Transparency = transparency,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Parent = frame,
		})
	end
	return frame
end

-- Remplit `holder` (cadre carré) avec une icône propre aux défis. Renvoie faux si inconnue.
local function paintCustomIcon(holder: Frame, name: string, color: Color3?, ink: Color3?, px: number?, shadow: boolean?): boolean
	local shapes = CUSTOM_ICONS[name]
	if not shapes then
		return false
	end
	local z = holder.ZIndex
	local size = px or 40
	if shadow ~= false then
		local shade = new("Frame", {
			Name = "IconShadow",
			Size = UDim2.fromScale(1, 1),
			Position = UDim2.fromScale(0.035, 0.05),
			BackgroundTransparency = 1,
			ZIndex = z,
			Parent = holder,
		})
		for _, shape in shapes do
			if not shape.ink then
				drawCustomShape(shade, shape, Color3.new(0, 0, 0), Color3.new(0, 0, 0), size, z, 0.62)
			end
		end
	end
	for _, shape in shapes do
		drawCustomShape(holder, shape, color or WHITE, ink or Color3.fromRGB(40, 40, 60), size, z + (shape.z or 0), 0)
	end
	return true
end

-- Dessine une icône (propre aux défis ou de UI/Icons).
local function drawIcon(name: string, parent: Instance, opts: { [string]: any }): Frame
	if not CUSTOM_ICONS[name] then
		return Icons.make(name, parent, opts :: any)
	end
	local holder = new("Frame", {
		Name = "Icon_" .. name,
		AnchorPoint = opts.anchor or Vector2.new(0.5, 0.5),
		Position = opts.position or UDim2.fromScale(0.5, 0.5),
		Size = opts.size or UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = opts.zindex or 3,
		Parent = parent,
	})
	new("UIAspectRatioConstraint", { AspectRatio = 1, Parent = holder })
	holder:SetAttribute("CustomIcon", true)
	paintCustomIcon(holder, name, opts.color, opts.ink, opts.px, opts.shadow)
	return holder
end
Quests.drawIcon = drawIcon

-- Les composants communs (fenêtres, onglets, boutons) dessinent leurs icônes avec UI/Icons :
-- une icône propre aux défis y apparaît comme texte. On la redessine ici.
function Quests.fixIcons(root: Instance)
	-- liste d'abord (redessiner détruit des descendants), puis redessine
	local targets = {}
	for _, d in root:GetDescendants() do
		if d:IsA("Frame") and string.sub(d.Name, 1, 5) == "Icon_" and CUSTOM_ICONS[string.sub(d.Name, 6)] and not d:GetAttribute("CustomIcon") then
			table.insert(targets, d)
		end
	end
	for _, d in targets do
		local name = string.sub(d.Name, 6)
		-- couleurs d'origine : forme principale et détail « encre » éventuels
		local color, ink = WHITE, nil
		for _, child in d:GetChildren() do
			if child:IsA("TextLabel") then
				color = child.TextColor3
			elseif child:IsA("Frame") and child.Name == "Ink" then
				ink = child.BackgroundColor3
			end
		end
		for _, child in d:GetChildren() do
			if not child:IsA("UIAspectRatioConstraint") then
				child:Destroy()
			end
		end
		d:SetAttribute("CustomIcon", true)
		local okSize, absolute = pcall(function()
			return d.AbsoluteSize.X
		end)
		local px = (okSize and absolute and absolute > 4) and math.floor(absolute) or 40
		paintCustomIcon(d, name, color, ink or Color3.fromRGB(40, 40, 60), px, true)
	end
end

------------------------------------------------------------------------
-- Petits blocs
------------------------------------------------------------------------

-- Pavé d'icône coloré (dégradé + contour + icône blanche).
local function iconTile(parent: Instance, icon: string, color: Color3, size: number, props: { [string]: any }?): Frame
	local tile = new("Frame", {
		Name = "IconTile",
		Size = UDim2.fromOffset(size, size),
		BackgroundColor3 = WHITE,
		Parent = parent,
	})
	if props then
		for k, v in props do
			(tile :: any)[k] = v
		end
	end
	Theme.corner(math.floor(size * 0.22)).Parent = tile
	Theme.stroke(C.Stroke, 2.5).Parent = tile
	Theme.gradient({ Theme.light(color, 0.3), color, Theme.dark(color, 0.4) }, 60).Parent = tile
	Theme.shine(tile, math.floor(size * 0.2), 0.28)
	local holder = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.66, 0.66),
		BackgroundTransparency = 1,
		ZIndex = tile.ZIndex + 2,
		Parent = tile,
	})
	drawIcon(icon, holder, { px = math.floor(size * 0.66), ink = Theme.dark(color, 0.55), zindex = tile.ZIndex + 2 })
	return tile
end

-- Nom d'un objet du marchand (Config/EvolutionItems, s'il existe dans ce jeu).
local function itemName(itemId: string): string?
	local config = Theme.optionalConfig("EvolutionItems")
	if config and type(config.get) == "function" then
		local ok, item = pcall(config.get, itemId)
		if ok and type(item) == "table" then
			return item.name
		end
	end
	return nil
end

-- Pastilles de récompense : ¥, gemmes de trait, objets.
-- maxWidth (px logiques, facultatif) : les pastilles qui ne tiennent pas sur la ligne passent
-- à la ligne suivante (cadre « Rewards » de height × lignes + REWARD_LINE_GAP entre deux) ;
-- une pastille plus large que maxWidth est ramenée à maxWidth (texte réduit). Renvoie aussi le
-- nombre de lignes.
local REWARD_CHIP_GAP = 6
local REWARD_LINE_GAP = 4
local function rewardChips(parent: Instance, reward, height: number, align: Enum.HorizontalAlignment?, maxWidth: number?): (Frame, number)
	local row = new("Frame", {
		Name = "Rewards",
		Size = UDim2.new(1, 0, 0, height),
		BackgroundTransparency = 1,
		Parent = parent,
	})
	local function lineLayout(frame: Frame)
		local layout = Theme.list(Enum.FillDirection.Horizontal, REWARD_CHIP_GAP, align or Enum.HorizontalAlignment.Left)
		layout.VerticalAlignment = Enum.VerticalAlignment.Center
		layout.Parent = frame
	end
	local specs = {}
	local function chip(order: number, width: number, draw: (Frame) -> (), text: string, color: Color3)
		table.insert(specs, { order = order, width = maxWidth and math.min(width, maxWidth) or width, draw = draw, text = text, color = color })
	end
	local function makeChip(spec, parentLine: Instance)
		local frame = new("Frame", {
			Name = "Chip",
			Size = UDim2.fromOffset(spec.width, height),
			BackgroundColor3 = Color3.fromRGB(10, 10, 16),
			BackgroundTransparency = 0.15,
			LayoutOrder = spec.order,
			Parent = parentLine,
		})
		Theme.round().Parent = frame
		Theme.stroke(Theme.dark(spec.color, 0.35), 1.5).Parent = frame
		spec.draw(frame)
		Theme.label({
			Name = "Amount",
			Text = spec.text,
			Size = UDim2.new(1, -height - 6, 1, -6),
			Position = UDim2.fromOffset(height + 1, 3),
			FontFace = Theme.Faces.Heavy,
			TextColor3 = spec.color,
			TextXAlignment = Enum.TextXAlignment.Left,
			StrokeThickness = 1.5,
			Parent = frame,
		})
	end
	-- valeur réelle : adaptée au revenu du joueur (comme côté serveur)
	local coins = QuestsConfig.rewardCoins(reward, Players.LocalPlayer:GetAttribute("IncomePerSec"))
	local items = reward and reward.items
	if type(items) == "table" then
		for itemId, amount in items do
			if not itemName(itemId) then
				-- objet absent de ce jeu : remplacé par des pièces (comme côté serveur)
				local fallback = 5000
				for _, list in QuestsConfig.UniverseItems do
					local index = table.find(list, itemId)
					if index then
						fallback = QuestsConfig.ItemFallbackCoins[index] or 5000
					end
				end
				coins += fallback * amount
			end
		end
	end
	if coins > 0 then
		local text = fmt(coins)
		chip(1, height + 14 + #text * math.floor(height * 0.56), function(frame)
			Components.coinIcon(frame, math.floor(height * 0.78), UDim2.new(0, height * 0.5, 0.5, 0))
		end, text, C.Gold)
	end
	if reward and (reward.gems or 0) > 0 then
		local text = tostring(reward.gems)
		chip(2, height + 16 + #text * math.floor(height * 0.56), function(frame)
			Components.gem(frame, GEM, math.floor(height * 0.46), UDim2.new(0, height * 0.52, 0.5, 0))
		end, text, Color3.fromRGB(150, 236, 255))
	end
	if type(items) == "table" then
		for itemId, amount in items do
			local name = itemName(itemId)
			if name then
				local text = (amount > 1 and (amount .. "× ") or "") .. name
				chip(3, math.min(220, height + 16 + #text * math.floor(height * 0.36)), function(frame)
					local holder = new("Frame", { Position = UDim2.fromOffset(4, 3), Size = UDim2.fromOffset(height - 6, height - 6), BackgroundTransparency = 1, Parent = frame })
					Icons.make("gift", holder, { px = height - 6, color = C.Purple, ink = C.PanelDark })
				end, text, Color3.fromRGB(220, 180, 255))
			end
		end
	end
	-- Répartition en lignes (dans l'ordre : ¥, gemmes, objets).
	table.sort(specs, function(a, b)
		return a.order < b.order
	end)
	local lines = { {} }
	local used = 0
	for _, spec in specs do
		local line = lines[#lines]
		if maxWidth and #line > 0 and used + REWARD_CHIP_GAP + spec.width > maxWidth then
			line = {}
			table.insert(lines, line)
			used = 0
		end
		used += (#line > 0 and REWARD_CHIP_GAP or 0) + spec.width
		table.insert(line, spec)
	end
	if #lines == 1 then
		lineLayout(row)
		for _, spec in lines[1] do
			makeChip(spec, row)
		end
	else
		row.Size = UDim2.new(1, 0, 0, #lines * height + (#lines - 1) * REWARD_LINE_GAP)
		local stack = Theme.list(Enum.FillDirection.Vertical, REWARD_LINE_GAP, align or Enum.HorizontalAlignment.Left)
		stack.Parent = row
		for index, list in lines do
			local lineFrame = new("Frame", {
				Name = "Line" .. index,
				Size = UDim2.new(1, 0, 0, height),
				BackgroundTransparency = 1,
				LayoutOrder = index,
				Parent = row,
			})
			lineLayout(lineFrame)
			for _, spec in list do
				makeChip(spec, lineFrame)
			end
		end
	end
	return row, #lines
end

-- Message de l'écran Défis : affiché DANS la fenêtre (en bas) quand elle est ouverte, pour ne
-- jamais couvrir les onglets ; sinon en bandeau classique.
local feedbackSerial = 0
local function feedback(message: string, kind: string)
	local holder = refs.feedback :: Frame?
	if not (window and window.isOpen and holder and holder.Parent) then
		Notifications.toast(message, kind)
		return
	end
	feedbackSerial += 1
	local serial = feedbackSerial
	local color = kind == "success" and READY or kind == "error" and C.Red or GEM
	holder.Visible = true
	holder.BackgroundColor3 = Theme.dark(color, 0.62)
	local stroke = holder:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Color = color
	end
	refs.feedbackText.Text = message
	holder.Position = UDim2.new(0.5, 0, 1, 10)
	Theme.tween(holder, 0.25, { Position = UDim2.new(0.5, 0, 1, -8) }, Enum.EasingStyle.Back)
	task.delay(2.6, function()
		if serial == feedbackSerial and holder.Parent then
			holder.Visible = false
		end
	end)
end

local function invokeClaim(id: string?)
	local ok, message
	if id then
		ok, message = State.invoke("QuestClaim", id)
	else
		ok, message = State.invoke("QuestClaimAll")
	end
	if message then
		feedback(message, ok and "success" or "error")
	end
	if ok then
		SoundService:PlayLocalSound(claimSound)
	end
	return ok
end

-- Bouton « RÉCLAMER » (vert) / « EN COURS » (gris) / « RÉCLAMÉ » (sombre).
local function claimButton(parent: Instance, state: string, onClick: () -> (), props: { [string]: any }): TextButton
	local text = state == "ready" and "RÉCLAMER" or state == "done" and "RÉCLAMÉ" or "EN COURS"
	local button = Components.button({
		Text = text,
		Icon = state == "ready" and "gift" or state == "done" and "check" or "hourglass",
		Color = state == "ready" and READY or state == "done" and Color3.fromRGB(50, 52, 66) or C.Gray,
		Size = props.Size,
		Position = props.Position,
		AnchorPoint = props.AnchorPoint,
		TextSize = 20,
		Parent = parent,
		OnClick = function()
			if state == "ready" then
				onClick()
			elseif state == "done" then
				feedback("Déjà réclamé !", "info")
			else
				feedback("Continue : ce défi n'est pas encore fini.", "info")
			end
		end,
	})
	if props.SelKey then
		button:SetAttribute("SelKey", props.SelKey)
	end
	if state == "ready" then
		-- halo vert qui pulse autour du bouton pour attirer l'œil
		local glow = new("Frame", {
			Name = "Glow",
			Size = UDim2.new(1, 10, 1, 8),
			Position = UDim2.fromOffset(-5, -3),
			BackgroundColor3 = READY,
			BackgroundTransparency = 0.6,
			ZIndex = 0,
			Parent = button,
		})
		Theme.corner(16).Parent = glow
		Theme.onFrame(glow, function(_, t)
			glow.BackgroundTransparency = 0.55 + math.sin(t * 5) * 0.3
		end)
	end
	return button
end

-- Barre de progression avec le texte « 120 / 200 » par-dessus.
local function progress(parent: Instance, value: number, goal: number, color: Color3, props: { [string]: any })
	local bar = Components.progressBar(parent, color, props)
	bar.set(goal > 0 and value / goal or 0)
	Theme.label({
		Name = "Value",
		Text = fmt(math.min(value, goal)) .. " / " .. fmt(goal),
		Size = UDim2.new(1, -8, 1, 2),
		Position = UDim2.fromOffset(4, -1),
		FontFace = Theme.Faces.Heavy,
		ZIndex = bar.frame.ZIndex + 2,
		StrokeThickness = 2,
		Parent = bar.frame,
	})
	return bar
end

------------------------------------------------------------------------
-- Onglet « Du jour »
------------------------------------------------------------------------

local function dailyCard(parent: Instance, data, dailyId: string, order: number)
	local daily = QuestsConfig.DailyById[dailyId]
	if not daily then
		return
	end
	local value, goal = QuestsConfig.dailyProgress(data, dailyId)
	local q = data.Quests or {}
	local claimed = q.daily and q.daily.claimed and q.daily.claimed[dailyId]
	local ready = QuestsConfig.dailyReady(data, dailyId)
	local card = new("Frame", {
		Name = "Daily_" .. dailyId,
		BackgroundColor3 = WHITE,
		LayoutOrder = order,
		Parent = parent,
	})
	Theme.corner(14).Parent = card
	Theme.stroke(ready and READY or claimed and Color3.fromRGB(70, 72, 90) or Theme.dark(daily.color, 0.2), ready and 3 or 2).Parent = card
	Theme.gradient({ Theme.dark(daily.color, 0.55), Color3.fromRGB(22, 22, 32), Color3.fromRGB(14, 14, 20) }, 90).Parent = card
	Theme.sparkles(card, 4, order * 11, 0.82)
	iconTile(card, daily.icon, daily.color, 62, { Position = UDim2.fromOffset(14, 14) })
	Theme.label({
		Name = "Title",
		Text = QuestsConfig.title(daily, goal),
		Size = UDim2.new(1, -100, 0, 30),
		Position = UDim2.fromOffset(88, 14),
		FontFace = Theme.Faces.Title,
		TextXAlignment = Enum.TextXAlignment.Left,
		StrokeThickness = 2.5,
		MaxSize = 26,
		Parent = card,
	})
	Theme.label({
		Text = "DÉFI DU JOUR " .. order .. " / " .. QuestsConfig.DailyCount,
		Size = UDim2.new(1, -100, 0, 18),
		Position = UDim2.fromOffset(88, 46),
		FontFace = Theme.Faces.Heavy,
		TextColor3 = Theme.light(daily.color, 0.35),
		TextXAlignment = Enum.TextXAlignment.Left,
		StrokeThickness = 1.5,
		Parent = card,
	})
	progress(card, claimed and goal or value, goal, ready and READY or daily.color, {
		Size = UDim2.new(1, -28, 0, 24),
		Position = UDim2.fromOffset(14, 88),
	})
	Theme.label({
		Text = "RÉCOMPENSE",
		Size = UDim2.new(0.5, 0, 0, 16),
		Position = UDim2.new(0, 16, 1, -68),
		FontFace = Theme.Faces.Heavy,
		TextColor3 = C.TextDim,
		TextXAlignment = Enum.TextXAlignment.Left,
		StrokeThickness = 1,
		Parent = card,
	})
	local rewards = rewardChips(card, daily.reward, 32)
	rewards.Size = UDim2.new(0.55, 0, 0, 32)
	rewards.Position = UDim2.new(0, 14, 1, -48)
	claimButton(card, claimed and "done" or ready and "ready" or "progress", function()
		invokeClaim(dailyId)
	end, {
		Size = UDim2.fromOffset(170, 48),
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -12, 1, -10),
		SelKey = "claim_" .. dailyId,
	})
	if claimed then
		local veil = new("Frame", {
			Name = "Veil",
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Color3.new(0, 0, 0),
			BackgroundTransparency = 0.55,
			ZIndex = 1,
			Parent = card,
		})
		Theme.corner(14).Parent = veil
	end
end

local function renderDaily(body: Frame, data)
	local q = data.Quests or {}
	local list = q.daily and q.daily.list or {}
	local grid = new("Frame", {
		Name = "DailyGrid",
		Size = UDim2.new(1, -312, 1, 0),
		BackgroundTransparency = 1,
		Parent = body,
	})
	new("UIGridLayout", {
		CellSize = UDim2.new(0.5, -6, 0.5, -6),
		CellPadding = UDim2.fromOffset(12, 12),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = grid,
	})
	for i, id in list do
		dailyCard(grid, data, id, i)
	end
	if #list == 0 then
		Components.emptyState(grid, "Les défis du jour arrivent...", "calendar")
	end

	-- Coffre du jour
	local claimedCount = 0
	for _, id in list do
		if q.daily.claimed and q.daily.claimed[id] then
			claimedCount += 1
		end
	end
	local bonusDone = q.daily and q.daily.bonus == true
	local bonusReady = QuestsConfig.bonusReady(data)
	local chest = new("Frame", {
		Name = "Bonus",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0, 300, 1, 0),
		BackgroundColor3 = WHITE,
		Parent = body,
	})
	Theme.corner(16).Parent = chest
	Theme.stroke(bonusReady and C.Gold or C.Stroke, bonusReady and 4 or 3).Parent = chest
	Theme.gradient({ Color3.fromRGB(120, 70, 20), Color3.fromRGB(46, 28, 16), Color3.fromRGB(18, 14, 12) }, 90).Parent = chest
	Theme.sparkles(chest, 10, 31, bonusReady and 0.45 or 0.75)
	Theme.label({
		Text = "COFFRE DU JOUR",
		Size = UDim2.new(1, -20, 0, 30),
		Position = UDim2.fromOffset(10, 12),
		FontFace = Theme.Faces.Title,
		TextColor3 = C.Gold,
		StrokeThickness = 2.5,
		Parent = chest,
	})
	-- Coffre dessiné (couvercle, corps, ferrures, serrure)
	local box = new("Frame", {
		Name = "Chest",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 56),
		Size = UDim2.fromOffset(150, 120),
		BackgroundTransparency = 1,
		Parent = chest,
	})
	-- Couvercle bombé : un dôme (coins arrondis à 50 %) dont le bas est caché par le corps.
	local lid = new("Frame", {
		Name = "Lid",
		Size = UDim2.fromScale(1, 0.62),
		BackgroundColor3 = WHITE,
		Rotation = bonusDone and -14 or 0,
		ZIndex = 2,
		Parent = box,
	})
	new("UICorner", { CornerRadius = UDim.new(0.5, 0), Parent = lid })
	Theme.stroke(C.Stroke, 3).Parent = lid
	Theme.gradient({ Color3.fromRGB(226, 140, 70), Color3.fromRGB(160, 82, 34), Color3.fromRGB(110, 52, 22) }, 90).Parent = lid
	-- planches du couvercle
	for _, x in { 0.36, 0.64 } do
		new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(x, 0.1),
			Size = UDim2.new(0, 2, 0.6, 0),
			BackgroundColor3 = Color3.fromRGB(90, 42, 16),
			BorderSizePixel = 0,
			ZIndex = 3,
			Parent = lid,
		})
	end
	local base = new("Frame", {
		Name = "Base",
		Position = UDim2.fromScale(0, 0.4),
		Size = UDim2.fromScale(1, 0.6),
		BackgroundColor3 = WHITE,
		ZIndex = 4,
		Parent = box,
	})
	Theme.corner(10).Parent = base
	Theme.stroke(C.Stroke, 3).Parent = base
	Theme.gradient({ Color3.fromRGB(190, 106, 46), Color3.fromRGB(104, 50, 20) }, 90).Parent = base
	for _, y in { 0.38, 0.7 } do
		new("Frame", {
			Position = UDim2.fromScale(0.04, y),
			Size = UDim2.new(0.92, 0, 0, 2),
			BackgroundColor3 = Color3.fromRGB(84, 38, 14),
			BorderSizePixel = 0,
			ZIndex = 5,
			Parent = base,
		})
	end
	-- ferrures dorées : bande au bord du couvercle, bandes verticales, coins rivetés
	local function gold(name: string, props: { [string]: any }): Frame
		local frame = new("Frame", {
			Name = name,
			BackgroundColor3 = WHITE,
			BorderSizePixel = 0,
			ZIndex = props.ZIndex or 6,
			Parent = box,
		})
		for key, value in props do
			(frame :: any)[key] = value
		end
		Theme.gradient({ Color3.fromRGB(255, 236, 140), C.Gold, Color3.fromRGB(196, 130, 30) }, 90).Parent = frame
		Theme.stroke(C.Stroke, 2).Parent = frame
		return frame
	end
	gold("Rim", { Position = UDim2.new(0, -3, 0.4, -5), Size = UDim2.new(1, 6, 0, 10) })
	for _, x in { 0.2, 0.8 } do
		local band = gold("Band", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(x, 0.02), Size = UDim2.new(0, 12, 0.98, 0), ZIndex = 5 })
		Theme.corner(3).Parent = band
	end
	for _, corner in { { 0, 1 }, { 1, 1 } } do
		local plate = gold("CornerPlate", {
			AnchorPoint = Vector2.new(corner[1], 1),
			Position = UDim2.fromScale(corner[1], corner[2]),
			Size = UDim2.fromOffset(22, 22),
			ZIndex = 6,
		})
		Theme.corner(4).Parent = plate
		local rivet = new("Frame", {
			Name = "Rivet",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(6, 6),
			BackgroundColor3 = Color3.fromRGB(120, 70, 10),
			ZIndex = 7,
			Parent = plate,
		})
		new("UICorner", { CornerRadius = UDim.new(0.5, 0), Parent = rivet })
	end
	-- serrure : plaque dorée, trou de serrure (rond + fente)
	local lock = gold("Lock", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.47),
		Size = UDim2.fromOffset(30, 36),
		ZIndex = 8,
	})
	Theme.corner(8).Parent = lock
	local keyHole = new("Frame", {
		Name = "KeyHole",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.4),
		Size = UDim2.fromOffset(10, 10),
		BackgroundColor3 = Color3.fromRGB(40, 20, 8),
		ZIndex = 9,
		Parent = lock,
	})
	new("UICorner", { CornerRadius = UDim.new(0.5, 0), Parent = keyHole })
	new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.fromOffset(4, 11),
		BackgroundColor3 = Color3.fromRGB(40, 20, 8),
		BorderSizePixel = 0,
		ZIndex = 9,
		Parent = lock,
	})
	if bonusReady then
		Theme.onFrame(box, function(_, t)
			box.Rotation = math.sin(t * 9) * 3
		end)
	end
	Theme.label({
		Text = bonusDone and "Ouvert ! Reviens demain." or ("Réclame les " .. QuestsConfig.DailyCount .. " défis du jour pour l'ouvrir"),
		Size = UDim2.new(1, -24, 0, 40),
		Position = UDim2.fromOffset(12, 186),
		FontFace = Theme.Faces.Bold,
		TextColor3 = C.TextDim,
		TextWrapped = true,
		StrokeThickness = 1.5,
		MaxSize = 18,
		Parent = chest,
	})
	progress(chest, claimedCount, math.max(1, #list), C.Gold, { Size = UDim2.new(1, -28, 0, 22), Position = UDim2.fromOffset(14, 232) })
	local rewards = rewardChips(chest, QuestsConfig.DailyBonus, 32, Enum.HorizontalAlignment.Center)
	rewards.Size = UDim2.new(1, -20, 0, 32)
	rewards.Position = UDim2.fromOffset(10, 266)
	claimButton(chest, bonusDone and "done" or bonusReady and "ready" or "progress", function()
		invokeClaim("bonus")
	end, {
		Size = UDim2.new(1, -28, 0, 54),
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -12),
		SelKey = "claim_bonus",
	})
end

------------------------------------------------------------------------
-- Onglets en liste (univers, combat, progression, entraînement)
------------------------------------------------------------------------

-- Largeur d'une ligne de défi : fenêtre (WINDOW_SIZE) - 40 (contenu de Components.window)
-- - 8 (marges de la liste) - 14 (ligne). La fenêtre a une taille fixe en px logiques : même
-- mise en page à toutes les tailles d'écran (1920, 1280, téléphone), seule l'échelle change.
local ROW_HEIGHT = 86
local ROW_CLAIM_WIDTH = 176
Quests.RowWidth = WINDOW_SIZE.X - 40 - 8 - 14
-- Place des récompenses : de 0,42 de la ligne (+4) jusqu'à 10 px avant le bouton RÉCLAMER.
Quests.RowRewardsWidth = math.floor(Quests.RowWidth * 0.58) - 4 - (ROW_CLAIM_WIDTH + 14) - 10

local function questRow(parent: Instance, data, quest, order: number)
	local tier, index, value, goal = QuestsConfig.status(data, quest)
	local finished = tier == nil
	local ready = not finished and value >= goal
	local row = new("Frame", {
		Name = "Quest_" .. quest.id,
		Size = UDim2.new(1, -14, 0, ROW_HEIGHT),
		BackgroundColor3 = WHITE,
		LayoutOrder = order,
		Parent = parent,
	})
	Theme.corner(14).Parent = row
	Theme.stroke(ready and READY or finished and C.Gold or Color3.fromRGB(70, 70, 92), ready and 3 or 2, ready and 0 or 0.2).Parent = row
	Theme.gradient({ Theme.dark(quest.color, 0.62), Color3.fromRGB(22, 22, 32), Color3.fromRGB(16, 16, 24) }, 0).Parent = row
	iconTile(row, quest.icon, quest.color, 62, { Position = UDim2.fromOffset(12, 12) })
	Theme.label({
		Name = "Title",
		Text = QuestsConfig.title(quest, goal),
		Size = UDim2.new(0.42, -86, 0, 30),
		Position = UDim2.fromOffset(86, 12),
		FontFace = Theme.Faces.Title,
		TextXAlignment = Enum.TextXAlignment.Left,
		StrokeThickness = 2.5,
		MaxSize = 24,
		Parent = row,
	})
	-- Paliers : pastilles (pleines = réclamées)
	local pips = new("Frame", {
		Name = "Tiers",
		Size = UDim2.new(0.42, -86, 0, 22),
		Position = UDim2.fromOffset(86, 48),
		BackgroundTransparency = 1,
		Parent = row,
	})
	local pipLayout = Theme.list(Enum.FillDirection.Horizontal, 5, Enum.HorizontalAlignment.Left)
	pipLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	pipLayout.Parent = pips
	Theme.label({
		Text = finished and "TERMINÉ" or ("PALIER " .. index .. " / " .. #quest.tiers),
		Size = UDim2.fromOffset(104, 20),
		FontFace = Theme.Faces.Heavy,
		TextColor3 = finished and C.Gold or Theme.light(quest.color, 0.35),
		TextXAlignment = Enum.TextXAlignment.Left,
		StrokeThickness = 1.5,
		LayoutOrder = 0,
		Parent = pips,
	})
	for i = 1, #quest.tiers do
		local done = i < index
		local current = i == index
		local pip = new("Frame", {
			Size = UDim2.fromOffset(current and 16 or 13, current and 16 or 13),
			BackgroundColor3 = done and C.Gold or current and quest.color or Color3.fromRGB(46, 46, 60),
			Rotation = 45,
			LayoutOrder = i,
			Parent = pips,
		})
		Theme.corner(3).Parent = pip
		Theme.stroke(C.Stroke, 1.5).Parent = pip
	end
	progress(row, value, goal, ready and READY or quest.color, {
		Size = UDim2.new(0.34, 0, 0, 24),
		Position = UDim2.new(0.42, 4, 0, 16),
	})
	-- Récompenses : de la barre de progression jusqu'au bouton RÉCLAMER, sur deux lignes si besoin
	-- (ex. palier 3 du boss Saiyan : ¥, gemmes, Boule Divine et Boule du Dragon) : la ligne grandit.
	local rewards, lines = rewardChips(row, finished and {} or tier.reward, 30, nil, Quests.RowRewardsWidth)
	rewards.Size = UDim2.new(0, Quests.RowRewardsWidth, 0, rewards.Size.Y.Offset)
	rewards.Position = UDim2.new(0.42, 4, 0, 46)
	row.Size = UDim2.new(1, -14, 0, ROW_HEIGHT + (lines - 1) * (30 + REWARD_LINE_GAP))
	if finished then
		Theme.label({
			Text = "Tous les paliers réussis !",
			Size = UDim2.new(0.25, 0, 0, 24),
			Position = UDim2.new(0.42, 4, 0, 48),
			FontFace = Theme.Faces.Heavy,
			TextColor3 = C.Gold,
			TextXAlignment = Enum.TextXAlignment.Left,
			StrokeThickness = 1.5,
			Parent = row,
		})
	end
	claimButton(row, finished and "done" or ready and "ready" or "progress", function()
		invokeClaim(quest.id)
	end, {
		Size = UDim2.fromOffset(ROW_CLAIM_WIDTH, 52),
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -14, 0.5, -2),
		SelKey = "claim_" .. quest.id,
	})
	return row
end

local function groupHeader(parent: Instance, text: string, color: Color3, order: number, tag: string?)
	local header = new("Frame", {
		Name = "Header",
		Size = UDim2.new(1, -14, 0, 34),
		BackgroundTransparency = 1,
		LayoutOrder = order,
		Parent = parent,
	})
	local bar = new("Frame", {
		Size = UDim2.new(0, 6, 0, 24),
		Position = UDim2.fromOffset(2, 5),
		BackgroundColor3 = color,
		Parent = header,
	})
	Theme.round().Parent = bar
	Theme.label({
		Text = text,
		Size = UDim2.new(0.6, 0, 0, 28),
		Position = UDim2.fromOffset(16, 3),
		FontFace = Theme.Faces.Title,
		TextColor3 = Theme.light(color, 0.2),
		TextXAlignment = Enum.TextXAlignment.Left,
		StrokeThickness = 2.5,
		Parent = header,
	})
	if tag then
		local pill = Components.pill(header, "pin", tag, color, { Size = UDim2.fromOffset(230, 28), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -4, 0, 3) })
		pill.Name = "Tag"
	end
	return header
end

-- Panneau du cycle de punching-ball (onglet Entraînement).
local function punchPanel(parent: Instance, data, order: number)
	local q = data.Quests or {}
	local count = tonumber(q.punch) or 0
	local panel = new("Frame", {
		Name = "PunchCycle",
		Size = UDim2.new(1, -14, 0, 150),
		BackgroundColor3 = WHITE,
		LayoutOrder = order,
		Parent = parent,
	})
	Theme.corner(16).Parent = panel
	Theme.stroke(Theme.dark(GEM, 0.2), 3).Parent = panel
	Theme.gradient({ Color3.fromRGB(20, 70, 96), Color3.fromRGB(16, 26, 40), Color3.fromRGB(12, 14, 22) }, 0).Parent = panel
	Theme.sparkles(panel, 8, 77, 0.78)
	iconTile(panel, "punchbag", GEM, 76, { Position = UDim2.fromOffset(14, 14) })
	Theme.label({
		Text = "ZONE ANTI-AFK : PUNCHING-BALLS",
		Size = UDim2.new(1, -330, 0, 30),
		Position = UDim2.fromOffset(104, 12),
		FontFace = Theme.Faces.Title,
		TextXAlignment = Enum.TextXAlignment.Left,
		StrokeThickness = 2.5,
		Parent = panel,
	})
	Theme.label({
		Text = "Va près d'un sac libre : ton perso le frappe tout seul. " .. QuestsConfig.Punch.Goal .. " coups = " .. QuestsConfig.punchCycleGems() .. " gemmes de trait. Les sacs ne t'attaquent jamais !",
		Size = UDim2.new(1, -330, 0, 40),
		Position = UDim2.fromOffset(104, 44),
		FontFace = Theme.Faces.Bold,
		TextColor3 = C.TextDim,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		StrokeThickness = 1.5,
		MaxSize = 18,
		Parent = panel,
	})
	Components.button({
		Text = "Y ALLER",
		Icon = "arrowRight",
		Color = C.Blue,
		Size = UDim2.fromOffset(190, 54),
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 0, 16),
		Parent = panel,
		OnClick = function()
			local ok, message = State.invoke("QuestGoAfk")
			if message then
				Notifications.toast(message, ok and "success" or "error")
			end
			if ok then
				Menus.close()
			end
		end,
	}):SetAttribute("SelKey", "go_afk")
	-- Barre du cycle avec les paliers
	local track = new("Frame", {
		Name = "Track",
		Size = UDim2.new(1, -40, 0, 22),
		Position = UDim2.fromOffset(20, 104),
		BackgroundTransparency = 1,
		Parent = panel,
	})
	local bar = Components.progressBar(track, GEM, { Size = UDim2.fromScale(1, 1) })
	bar.set(count / QuestsConfig.Punch.Goal)
	for _, tier in QuestsConfig.Punch.Tiers do
		local reached = count >= tier[1]
		local x = tier[1] / QuestsConfig.Punch.Goal
		local mark = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(x, 0, 0.5, 0),
			Size = UDim2.fromOffset(22, 22),
			BackgroundColor3 = reached and C.Gold or Color3.fromRGB(40, 44, 60),
			Rotation = 45,
			ZIndex = 4,
			Parent = track,
		})
		Theme.corner(4).Parent = mark
		Theme.stroke(C.Stroke, 2).Parent = mark
		Theme.label({
			Text = tier[1] .. "  +" .. tier[2],
			AnchorPoint = Vector2.new(x >= 0.99 and 1 or 0.5, 1),
			Position = UDim2.new(x, 0, 0, -2),
			Size = UDim2.fromOffset(80, 16),
			FontFace = Theme.Faces.Heavy,
			TextColor3 = reached and C.Gold or Color3.fromRGB(150, 236, 255),
			TextXAlignment = x >= 0.99 and Enum.TextXAlignment.Right or Enum.TextXAlignment.Center,
			StrokeThickness = 1.5,
			ZIndex = 4,
			Parent = track,
		})
	end
	Theme.label({
		Text = "Cycle en cours : " .. fmt(count) .. " / " .. fmt(QuestsConfig.Punch.Goal) .. " coups",
		Size = UDim2.new(1, -40, 0, 18),
		Position = UDim2.fromOffset(20, 128),
		FontFace = Theme.Faces.Heavy,
		TextColor3 = WHITE,
		StrokeThickness = 1.5,
		Parent = panel,
	})
end

local function renderList(body: Frame, data, category: string)
	local scroll = Components.scroll(body, { Name = "List", Size = UDim2.fromScale(1, 1) })
	local layout = Theme.list(Enum.FillDirection.Vertical, 10, Enum.HorizontalAlignment.Left)
	layout.Parent = scroll
	Theme.padding(4, 4).Parent = scroll
	local order = 0
	local function nextOrder(): number
		order += 1
		return order
	end
	-- Les défis prêts à réclamer passent en premier dans chaque groupe.
	local function sorted(list)
		local copy = table.clone(list)
		table.sort(copy, function(a, b)
			local ra, rb = QuestsConfig.questReady(data, a), QuestsConfig.questReady(data, b)
			if ra ~= rb then
				return ra
			end
			local ta = QuestsConfig.status(data, a) == nil
			local tb = QuestsConfig.status(data, b) == nil
			if ta ~= tb then
				return tb
			end
			return (table.find(QuestsConfig.List, a) or 0) < (table.find(QuestsConfig.List, b) or 0)
		end)
		return copy
	end
	if category == "afk" then
		punchPanel(scroll, data, nextOrder())
	end
	if category == "univers" then
		local current = State.universe()
		local universes = table.clone(Universes.List)
		table.sort(universes, function(a, b)
			if a.id == current.id then
				return true
			elseif b.id == current.id then
				return false
			end
			return (table.find(Universes.List, a) or 0) < (table.find(Universes.List, b) or 0)
		end)
		for _, universe in universes do
			local list = {}
			for _, quest in QuestsConfig.List do
				if quest.universe == universe.id then
					table.insert(list, quest)
				end
			end
			if #list > 0 then
				groupHeader(scroll, upper(universe.name), universe.color, nextOrder(), universe.id == current.id and "UNIVERS ACTUEL" or nil)
				for _, quest in sorted(list) do
					questRow(scroll, data, quest, nextOrder())
				end
			end
		end
	else
		local list = {}
		for _, quest in QuestsConfig.List do
			if quest.category == category then
				table.insert(list, quest)
			end
		end
		for _, quest in sorted(list) do
			questRow(scroll, data, quest, nextOrder())
		end
	end
	refs.list = scroll
end

------------------------------------------------------------------------
-- Rendu de la fenêtre
------------------------------------------------------------------------

local function updateBadges(data)
	if not window then
		return
	end
	for _, tab in TABS do
		local info = window.tabs[tab.id]
		if info then
			local n = QuestsConfig.readyCount(data, tab.id)
			local badge = info.button:FindFirstChild("ReadyBadge")
			if n > 0 then
				if not badge then
					badge = new("Frame", {
						Name = "ReadyBadge",
						AnchorPoint = Vector2.new(0.5, 0.5),
						Position = UDim2.new(1, 0, 0, 2),
						Size = UDim2.fromOffset(24, 24),
						BackgroundColor3 = C.Red,
						ZIndex = 8,
						Parent = info.button,
					})
					Theme.round().Parent = badge
					Theme.stroke(WHITE, 2).Parent = badge
					Theme.label({ Name = "Count", Size = UDim2.fromScale(0.8, 0.8), Position = UDim2.fromScale(0.1, 0.1), FontFace = Theme.Faces.Heavy, ZIndex = 9, Parent = badge })
				end
				local label = badge:FindFirstChild("Count") :: TextLabel?
				if label then
					label.Text = tostring(n)
				end
			elseif badge then
				badge:Destroy()
			end
		end
	end
end

local lastKey = ""
render = function(force: boolean?)
	local data = State.data
	if not window or not data then
		return
	end
	updateBadges(data)
	if not window.isOpen then
		return
	end
	local total = QuestsConfig.readyCount(data)
	local parts = { tabId, tostring(total), tostring(data.traitCrystals), State.universe().id }
	local q = data.Quests or {}
	table.insert(parts, tostring(q.punch))
	if type(q.claimed) == "table" then
		for id, n in q.claimed do
			table.insert(parts, id .. "=" .. tostring(n))
		end
	end
	if tabId == "daily" then
		for _, id in (q.daily and q.daily.list or {}) do
			local value = QuestsConfig.dailyProgress(data, id)
			table.insert(parts, id .. ":" .. value .. tostring(q.daily.claimed and q.daily.claimed[id]))
		end
		table.insert(parts, tostring(q.daily and q.daily.bonus))
	else
		for _, quest in QuestsConfig.List do
			if quest.category == tabId then
				table.insert(parts, quest.id .. ":" .. QuestsConfig.read(data, quest.key))
			end
		end
	end
	table.sort(parts)
	local key = table.concat(parts, "|")
	if not force and key == lastKey then
		return
	end
	lastKey = key
	Components.setPillText(refs.readyPill, total > 0 and (total .. " récompense" .. (total > 1 and "s" or "") .. " à réclamer") or "Aucune récompense prête")
	Components.setPillText(refs.gemsPill, "Gemmes : " .. fmt(data.traitCrystals or 0))
	Components.setButtonColor(refs.claimAll, total > 0 and READY or C.Gray)
	local scrollY = refs.list and refs.list.Parent and refs.list.CanvasPosition.Y or 0
	local sameTab = refs.renderedTab == tabId
	Components.preserveSelection(refs.body, function()
		Components.clear(refs.body)
		refs.list = nil
		if tabId == "daily" then
			renderDaily(refs.body, data)
		else
			renderList(refs.body, data, tabId)
			if sameTab and refs.list then
				refs.list.CanvasPosition = Vector2.new(0, scrollY)
			end
		end
	end)
	refs.renderedTab = tabId
	Quests.fixIcons(refs.body)
end

local function buildWindow(gui: ScreenGui)
	window = Components.window(gui, "DÉFIS", ACCENT, UDim2.fromOffset(WINDOW_SIZE.X, WINDOW_SIZE.Y), {
		icon = "trophy",
		subtitle = "Réussis des défis pour gagner pièces, gemmes et objets",
		tabs = TABS,
		onTab = function(id)
			tabId = id
			render(true)
			task.defer(Console.focusCurrent)
		end,
	})
	window.setTab("daily", true)
	local content = window.content
	local top = new("Frame", { Name = "Top", Size = UDim2.new(1, 0, 0, 50), BackgroundTransparency = 1, Parent = content })
	refs.readyPill = Components.pill(top, "gift", "Aucune récompense prête", READY, { Size = UDim2.fromOffset(330, 40), Position = UDim2.fromOffset(0, 4) })
	refs.gemsPill = Components.pill(top, "gem", "Gemmes : 0", GEM, { Size = UDim2.fromOffset(200, 40), Position = UDim2.fromOffset(340, 4) })
	refs.resetPill = Components.pill(top, "hourglass", "Nouveaux défis dans --:--", C.Purple, { Size = UDim2.fromOffset(330, 40), Position = UDim2.fromOffset(550, 4) })
	refs.claimAll = Components.button({
		Text = "TOUT RÉCLAMER",
		Icon = "gift",
		Color = C.Gray,
		Size = UDim2.fromOffset(240, 48),
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		TextSize = 22,
		Parent = top,
		OnClick = function()
			invokeClaim(nil)
		end,
	})
	refs.claimAll:SetAttribute("SelKey", "claim_all")
	refs.body = new("Frame", {
		Name = "Body",
		Size = UDim2.new(1, 0, 1, -60),
		Position = UDim2.fromOffset(0, 60),
		BackgroundTransparency = 1,
		Parent = content,
	})
	-- Message de retour (réclamer...) en bas de la fenêtre
	refs.feedback = new("Frame", {
		Name = "Feedback",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -8),
		Size = UDim2.fromOffset(620, 46),
		BackgroundColor3 = Theme.dark(READY, 0.62),
		Visible = false,
		ZIndex = 30,
		Parent = content,
	})
	Theme.corner(14).Parent = refs.feedback
	Theme.stroke(READY, 2.5).Parent = refs.feedback
	refs.feedbackText = Theme.label({
		Text = "",
		Size = UDim2.new(1, -24, 1, -12),
		Position = UDim2.fromOffset(12, 6),
		ZIndex = 31,
		MaxSize = 22,
		Parent = refs.feedback,
	})
	Components.registerWindow(Menus, "Quests", window, function(arg)
		if type(arg) == "string" and window.tabs[arg] then
			tabId = arg
			window.setTab(arg, true)
		end
		render(true)
	end, function()
		-- manette : premier bouton « RÉCLAMER » prêt, sinon le premier bouton de la liste
		for _, d in refs.body:GetDescendants() do
			if d:IsA("GuiButton") and d.Visible and d:GetAttribute("SelKey") and string.find(tostring(d:GetAttribute("SelKey")), "claim_", 1, true) then
				local label = d:FindFirstChild("Label", true) :: TextLabel?
				if label and label.Text == "RÉCLAMER" then
					return d
				end
			end
		end
		return window.firstSelectable()
	end)
	Quests.fixIcons(window.root)
	-- Compte à rebours des défis du jour (affiché tout de suite, puis chaque seconde)
	local function updateReset()
		local left = QuestsConfig.nextReset(os.time()) - os.time()
		local h = math.floor(left / 3600)
		local m = math.floor(left % 3600 / 60)
		local s = left % 60
		Components.setPillText(refs.resetPill, string.format("Nouveaux défis dans %02d:%02d:%02d", h, m, s))
	end
	updateReset()
	task.spawn(function()
		while true do
			if window.isOpen then
				updateReset()
			end
			task.wait(1)
		end
	end)
end

------------------------------------------------------------------------
-- Suivi à l'écran : bandeaux de progression / réussite
------------------------------------------------------------------------

local trackerRoot: Frame
local trackerStack: Frame
local trackerCards: { [string]: Frame } = {}

local function trackerCard(info)
	if not trackerStack then
		return
	end
	if window and window.isOpen then
		return -- l'écran Défis montre déjà tout : pas de bandeau par-dessus
	end
	local id = tostring(info.id or info.kind)
	local existing = trackerCards[id]
	if existing and existing.Parent then
		existing:Destroy()
	end
	local ready = info.kind == "ready"
	local color = ready and READY or ACCENT
	local card = new("Frame", {
		Name = "Tracker_" .. id,
		Size = UDim2.fromOffset(320, 66),
		BackgroundColor3 = WHITE,
		LayoutOrder = -math.floor(os.clock() * 10),
		Parent = trackerStack,
	})
	trackerCards[id] = card
	local scale = new("UIScale", { Scale = 0.6, Parent = card })
	Theme.corner(12).Parent = card
	Theme.stroke(C.Stroke, 2.5).Parent = card
	Theme.gradient({ Theme.dark(color, 0.5), Color3.fromRGB(18, 18, 26) }, 0).Parent = card
	local accentBar = new("Frame", { Size = UDim2.new(0, 6, 1, -12), Position = UDim2.fromOffset(6, 6), BackgroundColor3 = color, Parent = card })
	Theme.round().Parent = accentBar
	iconTile(card, info.icon or "trophy", color, 44, { Position = UDim2.fromOffset(18, 11) })
	Theme.label({
		Text = ready and (info.daily and "DÉFI DU JOUR RÉUSSI !" or "DÉFI RÉUSSI !") or "DÉFI EN COURS",
		Size = UDim2.new(1, -80, 0, 16),
		Position = UDim2.fromOffset(70, 7),
		FontFace = Theme.Faces.Heavy,
		TextColor3 = Theme.light(color, 0.3),
		TextXAlignment = Enum.TextXAlignment.Left,
		StrokeThickness = 1.5,
		Parent = card,
	})
	Theme.label({
		Text = tostring(info.title or ""),
		Size = UDim2.new(1, -80, 0, 20),
		Position = UDim2.fromOffset(70, 24),
		FontFace = Theme.Faces.Title,
		TextXAlignment = Enum.TextXAlignment.Left,
		StrokeThickness = 2,
		Parent = card,
	})
	if ready then
		Theme.label({
			Text = "Réclame-le dans Défis (menu Plus)",
			Size = UDim2.new(1, -80, 0, 16),
			Position = UDim2.fromOffset(70, 46),
			FontFace = Theme.Faces.Bold,
			TextColor3 = C.TextDim,
			TextXAlignment = Enum.TextXAlignment.Left,
			StrokeThickness = 1,
			Parent = card,
		})
	else
		local bar = Components.progressBar(card, color, { Size = UDim2.new(1, -170, 0, 12), Position = UDim2.fromOffset(70, 47) })
		bar.set((info.progress or 0) / math.max(1, info.goal or 1))
		Theme.label({
			Text = fmt(info.progress or 0) .. " / " .. fmt(info.goal or 0),
			Size = UDim2.fromOffset(90, 16),
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -8, 0, 45),
			FontFace = Theme.Faces.Heavy,
			TextXAlignment = Enum.TextXAlignment.Right,
			StrokeThickness = 1.5,
			Parent = card,
		})
	end
	Theme.tween(scale, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
	task.delay(ready and 6 or 4, function()
		if card.Parent then
			local tween = Theme.tween(scale, 0.18, { Scale = 0 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			tween.Completed:Once(function()
				if card.Parent then
					card:Destroy()
				end
			end)
			task.delay(0.3, function()
				if card.Parent then
					card:Destroy()
				end
			end)
		end
	end)
	-- Quests.TrackerMax cartes au plus
	local cards = {}
	for _, child in trackerStack:GetChildren() do
		if child:IsA("Frame") then
			table.insert(cards, child)
		end
	end
	table.sort(cards, function(a, b)
		return a.LayoutOrder < b.LayoutOrder
	end)
	for i = Quests.TrackerMax + 1, #cards do
		cards[i]:Destroy()
	end
end
Quests.trackerCard = trackerCard

------------------------------------------------------------------------
-- Panneau de la zone anti-AFK (affiché quand on y est)
------------------------------------------------------------------------

local afk: { [string]: any } = {}
Quests.AfkPanelTop = 138 -- sous les pastilles du HUD (y 98 → 130)
Quests.AfkPanelHeight = 64
Quests.AfkPanelWidth = 420

-- Pastille « auto-roulage en cours » (RollPanel) affichée ? Le panneau descend alors dessous
-- pour ne jamais cacher son bouton « Arrêter ».
local rollPanelModule: any = nil
local function autoPillBottom(): number?
	if not rollPanelModule then
		local ok, module = pcall(require, script.Parent.RollPanel)
		if not ok then
			return nil
		end
		rollPanelModule = module
	end
	local ok, refs = pcall(rollPanelModule.refs)
	local pill = ok and type(refs) == "table" and refs.pill
	if pill and pill.Visible then
		return (rollPanelModule.PillTop or 138) + (rollPanelModule.PillHeight or 40)
	end
	return nil
end

-- Haut du panneau AFK : sous la pastille d'auto-roulage si elle est là (jamais sur son bouton
-- « Arrêter »), sinon sous les pastilles du HUD.
local function afkPanelTop(): number
	local pillBottom = autoPillBottom()
	return pillBottom and (pillBottom + 8) or Quests.AfkPanelTop
end

-- Version compacte, en haut au centre sous la bannière d'univers : elle ne cache ni les sacs ni
-- le perso pendant qu'on tape (et les cartes de suivi des défis sont masquées dans la zone).
local function buildAfkPanel(root: Frame)
	local panel = new("Frame", {
		Name = "AfkPanel",
		AnchorPoint = Vector2.new(0.5, 0),
		-- Sous la rangée des pastilles du HUD (Marchand, Boss... : y 98 → 130), jamais dessus.
		Position = UDim2.new(0.5, 0, 0, Quests.AfkPanelTop),
		Size = UDim2.fromOffset(Quests.AfkPanelWidth, Quests.AfkPanelHeight),
		BackgroundColor3 = WHITE,
		Visible = false,
		Parent = root,
	})
	afk.panel = panel
	afk.scale = new("UIScale", { Parent = panel })
	Theme.corner(14).Parent = panel
	Theme.stroke(C.Stroke, 3).Parent = panel
	Theme.gradient({ Color3.fromRGB(20, 70, 96), Color3.fromRGB(14, 20, 32) }, 90).Parent = panel
	local edge = new("Frame", { Size = UDim2.new(1, -6, 1, -6), Position = UDim2.fromOffset(3, 3), BackgroundTransparency = 1, Parent = panel })
	Theme.corner(12).Parent = edge
	Theme.stroke(GEM, 1.5, 0.4).Parent = edge
	iconTile(panel, "punchbag", GEM, 44, { Position = UDim2.fromOffset(8, 10) })
	afk.title = Theme.label({
		Text = "ZONE ANTI-AFK",
		Size = UDim2.new(1, -220, 0, 20),
		Position = UDim2.fromOffset(60, 4),
		FontFace = Theme.Faces.Title,
		TextXAlignment = Enum.TextXAlignment.Left,
		StrokeThickness = 2.5,
		Parent = panel,
	})
	afk.status = Theme.label({
		Text = "Approche-toi d'un sac libre : il est frappé tout seul !",
		Size = UDim2.new(1, -70, 0, 13),
		Position = UDim2.fromOffset(60, 22),
		FontFace = Theme.Faces.Bold,
		TextColor3 = Color3.fromRGB(170, 230, 255),
		TextXAlignment = Enum.TextXAlignment.Left,
		StrokeThickness = 1.5,
		Parent = panel,
	})
	afk.count = Theme.label({
		Text = "0 / 1000",
		AnchorPoint = Vector2.new(1, 0),
		Size = UDim2.fromOffset(120, 21),
		Position = UDim2.new(1, -10, 0, 3),
		FontFace = Theme.Faces.Title,
		TextColor3 = WHITE,
		TextXAlignment = Enum.TextXAlignment.Right,
		StrokeThickness = 2.5,
		Parent = panel,
	})
	local track = new("Frame", { Name = "Track", Size = UDim2.new(1, -136, 0, 10), Position = UDim2.fromOffset(62, 47), BackgroundTransparency = 1, Parent = panel })
	afk.bar = Components.progressBar(track, GEM, { Size = UDim2.fromScale(1, 1) })
	afk.marks = {}
	for i, tier in QuestsConfig.Punch.Tiers do
		local x = tier[1] / QuestsConfig.Punch.Goal
		local mark = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(x, 0, 0.5, 0),
			Size = UDim2.fromOffset(12, 12),
			BackgroundColor3 = Color3.fromRGB(40, 44, 60),
			Rotation = 45,
			ZIndex = 4,
			Parent = track,
		})
		Theme.corner(3).Parent = mark
		Theme.stroke(C.Stroke, 2).Parent = mark
		-- gain du palier, juste au-dessus du losange (sous le texte d'état)
		local label = Theme.label({
			Text = "+" .. tier[2],
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(x, 0, 0, -2),
			Size = UDim2.fromOffset(26, 10),
			FontFace = Theme.Faces.Heavy,
			TextColor3 = Color3.fromRGB(150, 236, 255),
			StrokeThickness = 1.5,
			ZIndex = 4,
			Parent = track,
		})
		afk.marks[i] = { mark = mark, label = label }
	end
	-- total des gemmes du cycle, au bout de la barre
	Theme.label({
		Name = "CycleGems",
		Text = "= " .. QuestsConfig.punchCycleGems() .. " gemmes",
		AnchorPoint = Vector2.new(1, 0.5),
		Size = UDim2.fromOffset(58, 14),
		Position = UDim2.new(1, -8, 0, 52),
		FontFace = Theme.Faces.Heavy,
		TextColor3 = C.Gold,
		TextXAlignment = Enum.TextXAlignment.Right,
		StrokeThickness = 1.5,
		Parent = panel,
	})
	afk.hint = Console.hint(panel, "X", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -136, 0, 3) })
end

local function updateAfkPanel()
	local panel = afk.panel
	if not panel then
		return
	end
	local character = Players.LocalPlayer and Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local inside = false
	if root and root:IsA("BasePart") then
		local p = root.CFrame.Position
		inside = (Vector3.new(p.X, 0, p.Z) - Layout.AfkZone).Magnitude < 44
	end
	if inside ~= panel.Visible then
		panel.Visible = inside
		if inside then
			afk.scale.Scale = 0.7
			Theme.tween(afk.scale, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
		end
	end
	if not inside then
		return
	end
	-- Sous la pastille d'auto-roulage si elle est là ; les bandeaux suivent le panneau (voir
	-- layoutStack, à chaque image).
	local top = afkPanelTop()
	if panel.Position.Y.Offset ~= top then
		panel.Position = UDim2.new(0.5, 0, 0, top)
	end
	-- Mon punching-ball ? (son compteur, posé par le serveur à chaque coup, est plus frais
	-- que la sauvegarde, synchronisée toutes les 2 s pendant qu'on tape)
	local mine, mineCount = nil, nil
	local world = Workspace:FindFirstChild("World")
	local zone = world and world:FindFirstChild("AfkZone")
	local stations = zone and zone:FindFirstChild("Stations")
	if stations and Players.LocalPlayer then
		for _, station in stations:GetChildren() do
			if station:GetAttribute("OwnerId") == Players.LocalPlayer.UserId then
				mine = station:GetAttribute("Station")
				mineCount = tonumber(station:GetAttribute("Count"))
			end
		end
	end
	local data = State.data
	local count = mineCount or (data and data.Quests and tonumber(data.Quests.punch)) or 0
	afk.count.Text = fmt(count) .. " / " .. fmt(QuestsConfig.Punch.Goal)
	afk.bar.set(count / QuestsConfig.Punch.Goal)
	for i, tier in QuestsConfig.Punch.Tiers do
		local reached = count >= tier[1]
		afk.marks[i].mark.BackgroundColor3 = reached and C.Gold or Color3.fromRGB(40, 44, 60)
		afk.marks[i].label.TextColor3 = reached and C.Gold or Color3.fromRGB(150, 236, 255)
	end
	local nextTier = QuestsConfig.nextPunchTier(count)
	if mine then
		afk.status.Text = "Sac n°" .. tostring(mine) .. " : frappe auto" .. (nextTier and ("  ·  Prochain : " .. nextTier[1] .. " → +" .. nextTier[2] .. " gemmes") or "")
	else
		afk.status.Text = "Approche-toi d'un sac libre : il est frappé tout seul !"
	end
end

-- Grande annonce « palier atteint » au centre.
local function punchTierPop(gems: number, hits: number?)
	if not trackerRoot then
		return
	end
	local pop = new("Frame", {
		Name = "PunchPop",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.58, 0.4),
		Size = UDim2.fromOffset(420, 120),
		BackgroundTransparency = 1,
		Parent = trackerRoot,
	})
	local scale = new("UIScale", { Scale = 0.3, Parent = pop })
	Components.gem(pop, GEM, 54, UDim2.fromOffset(56, 60))
	Theme.label({
		Text = "+" .. gems .. " GEMMES DE TRAIT",
		Size = UDim2.new(1, -120, 0, 50),
		Position = UDim2.fromOffset(110, 14),
		FontFace = Theme.Faces.Title,
		TextColor3 = Color3.fromRGB(150, 236, 255),
		TextXAlignment = Enum.TextXAlignment.Left,
		StrokeThickness = 3,
		Parent = pop,
	})
	Theme.label({
		Text = hits and (hits .. " coups au punching-ball !") or "Cycle de 1000 coups terminé !",
		Size = UDim2.new(1, -120, 0, 30),
		Position = UDim2.fromOffset(110, 66),
		FontFace = Theme.Faces.Heavy,
		TextXAlignment = Enum.TextXAlignment.Left,
		StrokeThickness = 2,
		Parent = pop,
	})
	Theme.tween(scale, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
	task.delay(2.2, function()
		if pop.Parent then
			Theme.tween(scale, 0.2, { Scale = 0 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			task.delay(0.25, function()
				if pop.Parent then
					pop:Destroy()
				end
			end)
		end
	end)
end

------------------------------------------------------------------------
-- Punching-balls : balancement et « +1 » (côté client, fluide)
------------------------------------------------------------------------

local swings: { [Model]: { start: number, axis: Vector3, strength: number, base: CFrame } } = {}

local function popText(adornee: BasePart, text: string, color: Color3)
	local gui = Instance.new("BillboardGui")
	gui.Name = "HitPop"
	gui.Size = UDim2.fromOffset(80, 40)
	gui.StudsOffsetWorldSpace = Vector3.new(math.random(-10, 10) / 10, 2.5, 0)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.MaxDistance = 60
	gui.Adornee = adornee
	gui.Parent = adornee
	local label = Theme.label({
		Text = text,
		Size = UDim2.fromScale(1, 1),
		FontFace = Theme.Faces.Title,
		TextColor3 = color,
		StrokeThickness = 2.5,
		Parent = gui,
	})
	local start = os.clock()
	Theme.onFrame(gui, function()
		local t = os.clock() - start
		gui.StudsOffsetWorldSpace = Vector3.new(gui.StudsOffsetWorldSpace.X, 2.5 + t * 3, 0)
		label.TextTransparency = math.clamp((t - 0.35) / 0.35, 0, 1)
		if t > 0.75 then
			gui:Destroy()
		end
	end)
end

local function hookStation(station: Model)
	local bag = station:FindFirstChild("Bag") :: Model?
	if not bag then
		return
	end
	local anchor = station:FindFirstChild("PromptAnchor") :: BasePart?
	local base = bag:GetPivot()
	-- L'invite « Frapper » disparaît (chez ce joueur seulement) quand le sac est pris par un autre.
	local prompt = anchor and anchor:FindFirstChildOfClass("ProximityPrompt")
	local function refreshPrompt()
		if not prompt then
			return
		end
		local ownerId = station:GetAttribute("OwnerId")
		local me = Players.LocalPlayer and Players.LocalPlayer.UserId
		prompt.Enabled = ownerId == nil or ownerId == me
	end
	station:GetAttributeChangedSignal("OwnerId"):Connect(refreshPrompt)
	refreshPrompt()
	station:GetAttributeChangedSignal("HitTick"):Connect(function()
		local dir = station:GetAttribute("HitDir")
		local push = typeof(dir) == "Vector3" and dir.Magnitude > 0.01 and dir.Unit or Vector3.new(1, 0, 0)
		-- le sac part dans le sens du coup : rotation autour de l'axe horizontal perpendiculaire
		local axis = push:Cross(Vector3.new(0, 1, 0))
		if axis.Magnitude < 0.01 then
			axis = Vector3.new(1, 0, 0)
		end
		swings[bag] = { start = os.clock(), axis = axis.Unit, strength = math.rad(16), base = base }
		if anchor then
			popText(anchor, "+1", Color3.fromRGB(255, 240, 160))
			local character = Players.LocalPlayer and Players.LocalPlayer.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if root and root:IsA("BasePart") and (root.CFrame.Position - anchor.CFrame.Position).Magnitude < 40 then
				SoundService:PlayLocalSound(hitSound)
			end
		end
	end)
end

local function setupStations()
	local world = Workspace:WaitForChild("World", 30)
	local zone = world and world:WaitForChild("AfkZone", 30)
	local stations = zone and zone:WaitForChild("Stations", 30)
	if not stations then
		return
	end
	for _, station in stations:GetChildren() do
		if station:IsA("Model") then
			hookStation(station)
		end
	end
	stations.ChildAdded:Connect(function(child)
		if child:IsA("Model") then
			task.wait(0.5)
			hookStation(child)
		end
	end)
end

local function stepSwings()
	local now = os.clock()
	for bag, swing in swings do
		local t = now - swing.start
		if not bag.Parent or t > 1.6 then
			if bag.Parent then
				bag:PivotTo(swing.base)
			end
			swings[bag] = nil
		else
			-- oscillation amortie (recul puis balancement)
			local angle = swing.strength * math.exp(-2.6 * t) * math.sin(t * 9 + 0.35) / math.sin(0.35 + math.pi / 2)
			bag:PivotTo(CFrame.fromAxisAngle(swing.axis, angle) * (swing.base - swing.base.Position) + swing.base.Position)
		end
	end
end

------------------------------------------------------------------------
-- Démarrage
------------------------------------------------------------------------

-- Position des bandeaux de notification quand l'écran Défis est ouvert : dans la marge du bas
-- de la fenêtre, sous la liste (ni sur les onglets ni sur les boutons Réclamer).
Quests.ToastPositionWhileOpen = UDim2.new(0.5, 0, 1, -90)
Quests.HudPillsBottom = 130 -- bas de la rangée des pastilles du HUD (Marchand, Boss : y 98 → 130)
Quests.TrackerTop = 332 -- haut des cartes de suivi des défis au plus haut (unités logiques du HUD)
Quests.TrackerLeft = 240
Quests.TrackerWidth = 320
Quests.TrackerCardHeight = 66
Quests.TrackerGap = 8
Quests.TrackerMax = 3 -- cartes de suivi affichées au plus

-- PILE DU HAUT DE L'ÉCRAN (unités logiques du HUD), recalculée à chaque image pour que rien ne
-- se chevauche, quel que soit le nombre de bandeaux. Au centre, de haut en bas :
--   1. pastille « auto-roulage en cours » (RollPanel, y 138 → 178) si l'auto-roulage tourne loin
--      de la machine ;
--   2. panneau de la zone anti-AFK (80 de haut) : sous la pastille (y 186 → 266), sinon y 138 ;
--   3. bandeaux de notification (UI/Notifications, 52 de haut + 6 d'écart, 4 au plus) : à y 140,
--      ou 8 sous la pastille, ou 12 sous le panneau AFK ;
--   4. révélation des persos tirés loin de la machine (UI/RollReveal) : sous Quests.stackBottom().
-- À gauche, les cartes de suivi des défis (cachées dans la zone et quand l'écran Défis est
-- ouvert) passent sous les bandeaux : y = max(TrackerTop, bas de la pile + 8). Exemples, hors de
-- la zone avec la pastille : 0 bandeau → cartes à 332 ; 1 → bandeaux 186 → 238, cartes 332 ;
-- 2 → 186 → 296, cartes 332 ; 3 → 186 → 354, cartes 362. Dans la zone avec la pastille : panneau
-- 186 → 266 ; 0 bandeau → révélation à 274 ; 1 → bandeaux 278 → 330, révélation à 338 ; 2 → 278
-- → 388, révélation 396 ; 3 → 278 → 446, révélation 454 (réduite pour tenir au-dessus des
-- boutons de voyage).
local stackBottom = Quests.HudPillsBottom

-- Bas de la pile du centre (pastille, panneau AFK, bandeaux) : la révélation se pose dessous.
function Quests.stackBottom(): number
	return stackBottom
end

-- Cadre des cartes de suivi affichées (gauche, haut, droite, bas), ou nil s'il n'y en a pas.
function Quests.trackerBounds(): (number?, number?, number?, number?)
	if not trackerStack or not trackerStack.Visible then
		return nil
	end
	local count = 0
	for _, child in trackerStack:GetChildren() do
		if child:IsA("Frame") then
			count += 1
		end
	end
	if count == 0 then
		return nil
	end
	local top = trackerStack.Position.Y.Offset
	local left = trackerStack.Position.X.Offset
	return left, top, left + Quests.TrackerWidth, top + count * Quests.TrackerCardHeight + (count - 1) * Quests.TrackerGap
end

-- Place la pile (voir plus haut). `open` : écran Défis ouvert.
local function layoutStack(toastFrame: GuiObject?, toastHome: UDim2?, open: boolean)
	local inZone = afk.panel ~= nil and afk.panel.Visible
	local pillBottom = autoPillBottom()
	local bottom = pillBottom or Quests.HudPillsBottom
	local nextTop = pillBottom and (pillBottom + 8) or nil
	if inZone then
		local top = afkPanelTop()
		if afk.panel.Position.Y.Offset ~= top then
			afk.panel.Position = UDim2.new(0.5, 0, 0, top)
		end
		bottom = top + Quests.AfkPanelHeight
		nextTop = bottom + 12
	end
	if toastFrame and toastHome then
		local wanted = toastHome
		if open then
			wanted = Quests.ToastPositionWhileOpen
		elseif nextTop and toastHome.Y.Offset < nextTop then
			wanted = UDim2.new(toastHome.X.Scale, toastHome.X.Offset, toastHome.Y.Scale, nextTop)
		end
		if toastFrame.Position ~= wanted then
			toastFrame.Position = wanted
		end
		local height = Notifications.stackHeight()
		if not open and height > 0 then
			bottom = math.max(bottom, wanted.Y.Offset + height)
		end
	end
	stackBottom = bottom
	if trackerStack then
		local top = math.max(Quests.TrackerTop, bottom + 8)
		if trackerStack.Position.Y.Offset ~= top then
			trackerStack.Position = UDim2.fromOffset(Quests.TrackerLeft, top)
		end
	end
end

function Quests.init(gui: ScreenGui)
	buildWindow(gui)
	trackerRoot = Theme.scaledRoot(gui, "QuestHUD", 6)
	trackerStack = new("Frame", {
		Name = "Tracker",
		-- Sous la pile des bandeaux de notification (UI/Notifications) : les cartes de suivi ne
		-- passent jamais dessous, quelle que soit la largeur (layoutStack les descend au besoin).
		Position = UDim2.fromOffset(Quests.TrackerLeft, Quests.TrackerTop),
		Size = UDim2.fromOffset(Quests.TrackerWidth, 230),
		BackgroundTransparency = 1,
		Parent = trackerRoot,
	})
	Theme.list(Enum.FillDirection.Vertical, 8, Enum.HorizontalAlignment.Left).Parent = trackerStack
	buildAfkPanel(trackerRoot)

	State.onChanged(function()
		render()
	end)
	Remotes.event("QuestNotify").OnClientEvent:Connect(function(info)
		if type(info) ~= "table" then
			return
		end
		if info.kind == "progress" or info.kind == "ready" then
			trackerCard(info)
		elseif info.kind == "readySummary" then
			-- bandeau récapitulatif, sauf si l'écran Défis est ouvert (il affiche déjà le compteur)
			if not (window and window.isOpen) then
				local count = tonumber(info.count) or 1
				Notifications.toast(
					count <= 1 and ("Défi réussi : " .. tostring(info.title or "") .. " ! Réclame ta récompense dans Défis.")
						or (count .. " défis réussis ! Réclame tes récompenses dans Défis."),
					"success"
				)
			end
		elseif info.kind == "punchTier" then
			punchTierPop(info.gems or 0, info.hits)
		elseif info.kind == "punchCycle" then
			punchTierPop(info.gems or 0, nil)
		elseif info.kind == "daily" then
			Notifications.toast("Nouveaux défis du jour disponibles !", "info")
		end
	end)
	-- Bandeaux de notification (UI/Notifications) : pendant que l'écran Défis est ouvert, ils
	-- s'affichent en bas de l'écran pour ne pas masquer les onglets et les boutons du haut.
	local toastFrame: GuiObject? = nil
	local toastHome: UDim2? = nil
	Theme.onFrame(trackerRoot, function()
		stepSwings()
		local open = window and window.isOpen or false
		-- bandeaux de suivi cachés pendant que l'écran Défis est ouvert, et dans la zone anti-AFK
		-- (le panneau compact de la zone suffit, l'écran reste dégagé pour taper)
		trackerStack.Visible = not open and not (afk.panel and afk.panel.Visible)
		if not toastFrame or not toastFrame.Parent then
			toastFrame = gui:FindFirstChild("Toasts", true) :: GuiObject?
			toastHome = toastFrame and toastFrame.Position or nil
		end
		-- Pile du haut : pastille d'auto-roulage, panneau AFK, bandeaux, cartes de suivi.
		layoutStack(toastFrame, toastHome, open)
	end)
	-- Gemme de trait gagnée : une petite gemme vole de l'ennemi vers le compteur du HUD.
	Remotes.event("Reward").OnClientEvent:Connect(function(kind, amount, position)
		if kind == "crystal" then
			Quests.flyGem(tonumber(amount) or 1, typeof(position) == "Vector3" and position or nil)
		end
	end)
	task.spawn(function()
		while true do
			pcall(updateAfkPanel)
			task.wait(0.25)
		end
	end)
	task.spawn(setupStations)
end

-- Compteur de gemmes du HUD (cadre « Crystals » de UI/HUD), s'il est affiché.
-- Compteur de gemmes du HUD, gardé en cache : le parcours de toute l'interface (des dizaines de
-- milliers d'objets) ne se fait qu'une fois, pas à chaque gemme gagnée en combat.
local cachedGem: GuiObject? = nil
local lastGemSearch = -math.huge
local function shownOnScreen(d: GuiObject): boolean
	local ok, shown = pcall(function()
		return d.AbsoluteSize.X > 0
	end)
	return ok and shown == true
end
local function hudGemCounter(): GuiObject?
	if cachedGem and cachedGem.Parent and shownOnScreen(cachedGem) then
		return cachedGem
	end
	-- Introuvable récemment : on ne refouille pas plus d'une fois toutes les 5 s.
	if os.clock() - lastGemSearch < 5 then
		return nil
	end
	lastGemSearch = os.clock()
	local player = Players.LocalPlayer
	local playerGui = player and player:FindFirstChildOfClass("PlayerGui")
	if not playerGui then
		return nil
	end
	for _, d in playerGui:GetDescendants() do
		if d.Name == "Crystals" and d:IsA("GuiObject") and d.Parent and d.Parent.Name == "Row" and shownOnScreen(d) then
			cachedGem = d
			return d
		end
	end
	return nil
end

-- Petite gemme qui vole de l'ennemi (position 3D projetée à l'écran) jusqu'au compteur du HUD,
-- qui grossit un instant à l'arrivée. Une gemme par gemme gagnée (5 au plus).
function Quests.flyGem(amount: number, position: Vector3?)
	if not trackerRoot then
		return
	end
	local target = hudGemCounter()
	-- coordonnées logiques du calque (1280 x 720 mis à l'échelle par un UIScale)
	local origin = trackerRoot.AbsolutePosition
	local uiScale = trackerRoot:FindFirstChildOfClass("UIScale")
	local k = 1 / math.max(0.05, uiScale and uiScale.Scale or 1)
	local scaleX, scaleY = k, k
	-- départ : l'ennemi à l'écran (sinon le centre de l'écran)
	local startX, startY = 640, 400
	local camera = Workspace.CurrentCamera
	if position and camera then
		local ok, point, visible = pcall(function()
			return camera:WorldToScreenPoint(position + Vector3.new(0, 3, 0))
		end)
		if ok and visible then
			startX = (point.X - origin.X) * scaleX
			startY = (point.Y - origin.Y) * scaleY
		end
	end
	-- arrivée : le compteur de gemmes du HUD (sinon en haut à gauche)
	local endX, endY = 70, 90
	if target then
		endX = (target.AbsolutePosition.X + 18 - origin.X) * scaleX
		endY = (target.AbsolutePosition.Y + target.AbsoluteSize.Y / 2 - origin.Y) * scaleY
	end
	for i = 1, math.clamp(math.floor(amount), 1, 5) do
		task.delay((i - 1) * 0.08, function()
			if not trackerRoot.Parent then
				return
			end
			local gem = new("Frame", {
				Name = "FlyingGem",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromOffset(startX + (i - 1) * 8, startY),
				Size = UDim2.fromOffset(30, 30),
				BackgroundTransparency = 1,
				ZIndex = 40,
				Parent = trackerRoot,
			})
			Components.gem(gem, GEM, 30, UDim2.fromScale(0.5, 0.5))
			local scale = new("UIScale", { Scale = 0.4, Parent = gem })
			Theme.tween(scale, 0.18, { Scale = 1.25 }, Enum.EasingStyle.Back)
			-- petit saut puis vol vers le compteur
			Theme.tween(gem, 0.2, { Position = UDim2.fromOffset(startX + (i - 1) * 8, startY - 40) }, Enum.EasingStyle.Quad)
			task.delay(0.2, function()
				if not gem.Parent then
					return
				end
				Theme.tween(gem, 0.55, { Position = UDim2.fromOffset(endX, endY) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
				Theme.tween(scale, 0.55, { Scale = 0.6 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
				task.delay(0.56, function()
					if gem.Parent then
						gem:Destroy()
					end
					if target and target.Parent then
						local pulse = target:FindFirstChild("GemPulse") :: UIScale?
						if not pulse then
							pulse = new("UIScale", { Name = "GemPulse", Scale = 1, Parent = target }) :: UIScale
						end
						local p = pulse :: UIScale
						p.Scale = 1.18
						Theme.tween(p, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
					end
				end)
			end)
		end)
	end
end

-- Nombre de récompenses prêtes (pour la pastille du menu principal).
function Quests.readyCount(): number
	return State.data and QuestsConfig.readyCount(State.data) or 0
end

return Quests
