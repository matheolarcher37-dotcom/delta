-- FORGERON (stand du hub) : acheter et équiper des épées pour combattre soi-même.
-- À gauche les épées (prix bien visible), à droite la fiche de l'épée : aperçu 3D, tuiles de
-- statistiques (dégâts, vitesse), portée, effet (avec son rang d'éclat), détails de forge et
-- bouton ACHETER / ÉQUIPER. L'aperçu tourne lentement et laisse monter des étincelles de la
-- couleur de l'effet. Dans la grille, chaque épée est inclinée à 45° pour remplir sa vignette.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Swords = require(Shared.Config.Swords)
local Formulas = require(Shared.Modules.Formulas)
local Remotes = require(Shared.Modules.Remotes)
local SwordBuilder = require(Shared.Modules.SwordBuilder)

local Theme = require(script.Parent.Theme)
local Components = require(script.Parent.Components)
local UnitSheet = require(script.Parent.UnitSheet)
local Menus = require(script.Parent.Menus)
local Notifications = require(script.Parent.Notifications)
local State = require(script.Parent.Parent.State)

local ForgeMenu = {}

local C = Theme.Colors
local new = Theme.new
local WHITE = Color3.new(1, 1, 1)
local ACCENT = Color3.fromRGB(240, 110, 40)

local window
local refs: { [string]: any } = {}
local selected: string = Swords.Starter
local render: (boolean?) -> ()

-- Noms courts des effets (repli si l'apparence de l'épée n'a pas de `effectName`).
local FX_NAMES = {
	slash = "Entaille",
	wind = "Rafale",
	lightning = "Éclairs",
	flame = "Flammes",
	mist = "Brume",
	shadow = "Fumée noire",
	ice = "Étoiles",
}

local function effectName(sword): string
	return sword.look.effectName or FX_NAMES[sword.fx] or tostring(sword.fx)
end

-- Aperçu 3D de l'épée dans un ViewportFrame.
--   Vignette (spin = false) : épée inclinée à 45°, de la pointe (en haut à droite) au pommeau
--     (en bas à gauche), pour qu'elle remplisse la vignette d'un coin à l'autre.
--   Grand aperçu (spin = true) : épée debout qui tourne lentement sur elle-même (20° par seconde)
--     pour montrer la garde et la poignée de profil.
local THUMB_FOV = 30
local BIG_FOV = 32
local SPIN_SPEED = math.rad(20)
local function swordViewport(parent: Instance, sword, spin: boolean?): ViewportFrame
	local model = SwordBuilder.buildModel(sword)
	local top = model:GetAttribute("Top") or sword.look.length + 0.8
	local bottom = model:GetAttribute("Bottom") or -0.7
	local height = math.max(top - bottom, 2)
	local wide = math.max(sword.look.width * 2.4, 1.2)
	local center = Vector3.new(0, (top + bottom) / 2, 0)
	local base = model:GetPivot()
	local viewport = Instance.new("ViewportFrame")
	viewport.Name = "Viewport"
	viewport.Size = UDim2.fromScale(1, 1)
	viewport.BackgroundTransparency = 1
	viewport.Ambient = Color3.fromRGB(190, 190, 205)
	viewport.LightColor = Color3.fromRGB(255, 248, 235)
	viewport.LightDirection = Vector3.new(-0.5, -0.9, -0.9)
	local camera = Instance.new("Camera")
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	if spin then
		camera.FieldOfView = BIG_FOV
		local distance = math.max(height, wide) * 1.85
		camera.CFrame = CFrame.lookAt(center + Vector3.new(distance * 0.12, distance * 0.08, -distance), center)
		-- Rotation lente autour de l'axe de la lame (centre de l'épée).
		local around = CFrame.new(center)
		local rest = around:Inverse() * base
		Theme.onFrame(viewport, function(_dt, t)
			if viewport.Visible then
				model:PivotTo(around * CFrame.Angles(0, t * SPIN_SPEED, 0) * rest)
			end
		end)
	else
		camera.FieldOfView = THUMB_FOV
		-- Inclinaison de 45° autour du centre de l'épée (vers la caméra) : pointe en haut à droite.
		local tilt = CFrame.new(center) * CFrame.Angles(0, 0, math.rad(45)) * CFrame.new(-center)
		model:PivotTo(tilt * base)
		-- La diagonale occupe height·cos 45° en hauteur comme en largeur ; on ajoute la largeur de
		-- la garde et une petite marge, puis on recule la caméra pour que tout tienne dans le FOV.
		local half = height * 0.7071 / 2 + wide * 0.3
		local distance = half * 1.08 / math.tan(math.rad(THUMB_FOV / 2))
		camera.CFrame = CFrame.lookAt(center + Vector3.new(distance * 0.08, distance * 0.05, -distance), center)
	end
	model.Parent = viewport
	viewport.Parent = parent
	return viewport
end

-- Rang d'éclat de l'effet (1 à 5 étoiles selon le rang de l'épée).
local function glowStars(sword): string
	local stars = 1 + math.floor(Swords.power(sword) * 4 + 0.5)
	return string.rep("★", stars) .. string.rep("☆", 5 - stars)
end

-- Étincelles qui montent dans l'aperçu, à la couleur de l'effet (plus nombreuses pour les
-- meilleures épées).
local function previewEmbers(holder: Frame, sword)
	local power = Swords.power(sword)
	if power <= 0 then
		return
	end
	local tint = sword.look.aura or sword.look.trail
	local rng = Random.new(sword.index or 1)
	local embers = {}
	for i = 1, 4 + math.floor(power * 10) do
		local spark = Theme.sparkle(holder, UDim2.fromScale(0.5, 1), rng:NextInteger(7, 14), 0.35, 3)
		for _, bar in spark:GetChildren() do
			if bar:IsA("Frame") then
				bar.BackgroundColor3 = Theme.light(tint, 0.25)
			end
		end
		table.insert(
			embers,
			{ frame = spark, x = rng:NextNumber(0.25, 0.75), speed = rng:NextNumber(0.08, 0.18), phase = i / 7 + rng:NextNumber(0, 1), sway = rng:NextNumber(0.02, 0.06) }
		)
	end
	Theme.onFrame(holder, function(_dt, t)
		for _, e in embers do
			local p = (t * e.speed + e.phase) % 1
			e.frame.Position = UDim2.fromScale(e.x + math.sin(t * 2 + e.phase * 6) * e.sway, 0.95 - p * 0.85)
			e.frame.Rotation = t * 60 + e.phase * 90
			local fade = math.sin(p * math.pi)
			for _, bar in e.frame:GetChildren() do
				if bar:IsA("Frame") then
					bar.BackgroundTransparency = 1 - fade * 0.75
				end
			end
		end
	end)
end

local function owned(id: string): boolean
	local data = State.data
	return data ~= nil and data.swords ~= nil and data.swords[id] == true
end

local function renderDetail()
	local holder = refs.detail
	Components.clear(holder)
	local sword = Swords.get(selected) or Swords.List[1]
	local data = State.data
	local tint = sword.look.trail
	local sheet = Components.sheet(holder, { Size = UDim2.fromScale(1, 1) })

	local preview = new("Frame", {
		Size = UDim2.new(0.5, -18, 1, -24),
		Position = UDim2.fromOffset(12, 12),
		BackgroundColor3 = WHITE,
		ClipsDescendants = true,
		Parent = sheet,
	})
	Theme.corner(12).Parent = preview
	Theme.stroke(Theme.dark(tint, 0.1), 2).Parent = preview
	Theme.gradient({ Color3.fromRGB(30, 30, 40), Color3.fromRGB(14, 14, 20), Theme.dark(tint, 0.55) }, 90).Parent = preview
	local glow = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.55),
		Size = UDim2.fromScale(0.9, 0.6),
		BackgroundColor3 = tint,
		BackgroundTransparency = 0.6,
		BorderSizePixel = 0,
		Parent = preview,
	})
	Theme.round().Parent = glow
	Theme.gradient({ WHITE, WHITE }, 90, { 0.4, 1 }).Parent = glow
	local view = new("Frame", { Size = UDim2.new(1, 0, 1, -80), Position = UDim2.fromOffset(0, 70), BackgroundTransparency = 1, ZIndex = 2, Parent = preview })
	swordViewport(view, sword, true).ZIndex = 2
	local embers = new("Frame", { Name = "Embers", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 3, Parent = preview })
	previewEmbers(embers, sword)
	Theme.label({
		Text = sword.name,
		Position = UDim2.fromOffset(12, 10),
		Size = UDim2.new(1, -24, 0, 32),
		FontFace = Theme.Faces.Heavy,
		TextColor3 = Theme.light(tint, 0.45),
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 3,
		Parent = preview,
	})
	Theme.label({
		Text = sword.description,
		Position = UDim2.fromOffset(12, 42),
		Size = UDim2.new(1, -24, 0, 36),
		FontFace = Theme.Faces.Bold,
		TextColor3 = C.TextDim,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = true,
		ZIndex = 3,
		StrokeThickness = 1,
		MaxSize = 16,
		Parent = preview,
	})

	local right = new("Frame", { Size = UDim2.new(0.5, -18, 1, -24), Position = UDim2.new(0.5, 6, 0, 12), BackgroundTransparency = 1, Parent = sheet })
	local list = new("Frame", { Size = UDim2.new(1, 0, 0, 2 * 64), BackgroundTransparency = 1, Parent = right })
	Theme.list(Enum.FillDirection.Vertical, 6, Enum.HorizontalAlignment.Center).Parent = list
	UnitSheet.statTile(list, "dmg", Formulas.formatNumber(sword.damage), { LayoutOrder = 1 })
	UnitSheet.statTile(list, "spa", string.format("%.2fs", sword.cooldown), { LayoutOrder = 2 })
	local infos = new("Frame", { Size = UDim2.new(1, 0, 0, 3 * 42), Position = UDim2.fromOffset(0, 2 * 64 + 4), BackgroundTransparency = 1, Parent = right })
	Theme.list(Enum.FillDirection.Vertical, 6, Enum.HorizontalAlignment.Center).Parent = infos
	Components.pill(infos, "star", "Dégâts / s : " .. Formulas.formatNumber(math.floor(sword.damage / sword.cooldown)), C.Red, { Size = UDim2.new(1, 0, 0, 36), LayoutOrder = 1 })
	Components.pill(infos, "target", "Portée : " .. tostring(sword.range) .. " studs", C.Blue, { Size = UDim2.new(1, 0, 0, 36), LayoutOrder = 2 })
	Components.pill(infos, "bolt", "Effet : " .. effectName(sword) .. "  " .. glowStars(sword), tint, { Size = UDim2.new(1, 0, 0, 36), LayoutOrder = 3 })

	-- Détails de forge : ce qui rend cette épée unique.
	local details = new("Frame", {
		Name = "Details",
		Position = UDim2.fromOffset(0, 2 * 64 + 4 + 3 * 42 + 6),
		Size = UDim2.new(1, 0, 1, -(2 * 64 + 4 + 3 * 42 + 6) - 128),
		BackgroundColor3 = Color3.fromRGB(14, 14, 20),
		BackgroundTransparency = 0.15,
		Parent = right,
	})
	Theme.corner(10).Parent = details
	Theme.stroke(Theme.dark(tint, 0.2), 2, 0.3).Parent = details
	Theme.label({
		Text = "DÉTAILS DE FORGE",
		Position = UDim2.fromOffset(12, 6),
		Size = UDim2.new(1, -24, 0, 20),
		FontFace = Theme.Faces.Heavy,
		TextColor3 = Theme.light(tint, 0.35),
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxSize = 16,
		Parent = details,
	})
	Theme.label({
		Text = sword.look.features or sword.description,
		Position = UDim2.fromOffset(12, 28),
		Size = UDim2.new(1, -24, 1, -34),
		FontFace = Theme.Faces.Bold,
		TextColor3 = C.TextDim,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = true,
		StrokeThickness = 1,
		MaxSize = 15,
		Parent = details,
	})

	local isOwned = owned(sword.id)
	local isEquipped = data ~= nil and data.equippedSword == sword.id
	local text, color, icon
	if isEquipped then
		text, color, icon = "ÉQUIPÉE", C.Gray, "check"
	elseif isOwned then
		text, color, icon = "ÉQUIPER", C.Blue, "sword"
	else
		text, color, icon = "ACHETER", C.Green, "coin"
	end
	if not isOwned then
		local price = Components.price(right, sword.price, {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -66),
			Size = UDim2.new(1, 0, 0, 42),
		})
		Components.setPriceAffordable(price, data ~= nil and data.coins >= sword.price)
	end
	Components.button({
		Text = text,
		Icon = icon,
		Color = color,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 54),
		Hint = "A",
		Parent = right,
		OnClick = function()
			if isEquipped then
				return
			end
			local remote = isOwned and "EquipSword" or "BuySword"
			local ok, success, message = pcall(function()
				return Remotes.func(remote):InvokeServer(sword.id)
			end)
			if ok and message then
				Notifications.toast(message, success and "success" or "error")
			end
			render(true)
		end,
	})
end

local function renderGrid()
	Components.clear(refs.grid)
	refs.selectedCard = nil
	local data = State.data
	for i, sword in Swords.List do
		local status, statusColor
		if data and data.equippedSword == sword.id then
			status, statusColor = "Équipée", C.Green
		elseif owned(sword.id) then
			status, statusColor = "Possédée", C.Cyan
		else
			status, statusColor = Formulas.formatNumber(sword.price) .. " pièces", (data and data.coins >= sword.price) and C.Gold or Color3.fromRGB(255, 110, 110)
		end
		local card, preview = Components.itemCard(refs.grid, {
			title = sword.name,
			subtitle = status,
			subtitleColor = statusColor,
			-- Couleur de carte propre à l'épée si sa lame est sombre (fond plus sombre, lame qui ressort).
			color = sword.look.card or sword.look.trail,
			layoutOrder = i,
			selected = sword.id == selected,
			selKey = sword.id,
			onClick = function()
				selected = sword.id
				render(true)
			end,
		})
		swordViewport(preview, sword, false)
		if sword.id == selected then
			refs.selectedCard = card
		end
	end
end

local lastKey = ""
render = function(force: boolean?)
	if not window or not window.isOpen then
		return
	end
	local data = State.data
	local parts = { selected, tostring(data and data.equippedSword), tostring(data and math.floor(data.coins)) }
	for id in (data and data.swords) or {} do
		table.insert(parts, id)
	end
	table.sort(parts)
	local key = table.concat(parts, "|")
	if not force and key == lastKey then
		return
	end
	lastKey = key
	Components.preserveSelection(window.content, function()
		renderGrid()
		renderDetail()
	end)
end

function ForgeMenu.init(gui: ScreenGui)
	window = Components.window(gui, "FORGERON", ACCENT, UDim2.fromOffset(1180, 640), {
		icon = "forge",
		subtitle = "Touche 1 (manette : LB / RB) pour sortir ton épée",
	})
	local content = window.content
	refs.grid = Components.cardGrid(content, Vector2.new(124, 160), { Name = "Grid", Size = UDim2.new(0.38, -8, 1, 0) }, 10)
	refs.detail = new("Frame", {
		Name = "DetailHolder",
		Size = UDim2.new(0.62, -8, 1, 0),
		Position = UDim2.new(0.38, 8, 0, 0),
		BackgroundTransparency = 1,
		Parent = content,
	})
	Components.registerWindow(Menus, "Forge", window, function()
		local data = State.data
		selected = data and data.equippedSword or Swords.Starter
		render(true)
	end, function()
		return refs.selectedCard or window.firstSelectable()
	end)
	State.onChanged(function()
		render()
	end)
end

return ForgeMenu
