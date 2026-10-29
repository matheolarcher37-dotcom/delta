-- Révélation animée des persos tirés par la machine ROULER (RemoteEvent « RollResult ») :
-- d'abord la ROULETTE sur l'estrade (v3.4, UI/RollSpin : des persos défilent sur la case puis
-- s'arrêtent sur le perso tiré), puis les cartes se retournent sous la bannière (loin de la
-- machine), avec la couleur de leur rareté, le prix et les dégâts par seconde. Pour les grosses raretés (Légendaire et plus) : éclair de lumière,
-- rayons tournants et grande annonce.
--
-- Données reçues : { results = { { id, stars, rarity, price, dps, aura? (= mutation), trait? } },
--                    pity = { mythic = n }, luck, count, auto = vrai pendant l'auto-roulage,
--                    spin = durée de la roulette (absente ou 0 : révélation directe) }
-- La rareté est celle du perso (sa fiche) ; la MUTATION (Or, Diamant...) s'affiche en plus.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Characters = require(Shared.Config.Characters)
local Mutations = require(Shared.Config.Mutations)
local Formulas = require(Shared.Modules.Formulas)

local Theme = require(script.Parent.Theme)
local Components = require(script.Parent.Components)
local Notifications = require(script.Parent.Notifications)
local RollSpin = require(script.Parent.RollSpin)
local State = require(script.Parent.Parent.State)

local RollReveal = {}

local C = Theme.Colors
local new = Theme.new
local WHITE = Color3.new(1, 1, 1)

local root: Frame
local strip: Frame
local stripScale: UIScale
local flash: Frame
local batch = 0

local flipSound = Instance.new("Sound")
flipSound.SoundId = "rbxasset://sounds/swoosh.wav"
flipSound.Volume = 0.3
flipSound.Parent = SoundService

local rareSound = Instance.new("Sound")
rareSound.SoundId = "rbxasset://sounds/glassbreak.wav"
rareSound.Volume = 0.45
rareSound.Parent = SoundService

local function rarityOrder(id: string?): number
	return Theme.rarity(id).order
end

local function buildCard(parent: Instance, result, index: number)
	local rarityId = result.rarity or "common"
	local info = Theme.rarity(rarityId)
	local tint = info.rainbow and C.Magenta or info.color
	local def = Characters.get(result.id or "")
	local holder = new("Frame", {
		Name = "RollCard" .. index,
		Size = UDim2.fromOffset(176, 240),
		BackgroundTransparency = 1,
		LayoutOrder = index,
		Parent = parent,
	})
	local card = new("Frame", {
		Name = "Card",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = WHITE,
		Parent = holder,
	})
	Theme.corner(14).Parent = card
	if info.rainbow then
		Theme.rainbowStroke(card, 4)
	else
		Theme.stroke(Theme.light(tint, 0.2), 4).Parent = card
	end
	Theme.gradient({ Theme.dark(tint, 0.2), Theme.dark(tint, 0.62), Color3.fromRGB(12, 12, 18) }, 90).Parent = card
	-- Rayons derrière le perso
	local rays = new("Frame", {
		Name = "Rays",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.4),
		Size = UDim2.fromOffset(176, 176),
		BackgroundTransparency = 1,
		Parent = card,
	})
	for i = 0, 5 do
		local ray = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(0, 16, 1, 0),
			Rotation = i * 30,
			BackgroundColor3 = WHITE,
			BorderSizePixel = 0,
			Parent = rays,
		})
		Theme.gradient({ WHITE, Theme.light(tint, 0.5), WHITE }, 90, { 1, 0.55, 1 }).Parent = ray
	end
	Theme.onFrame(rays, function(dt)
		rays.Rotation = (rays.Rotation + dt * 30) % 360
	end)
	Theme.sparkles(card, 6, index * 13, 0.55)
	if def then
		local preview = new("Frame", {
			Name = "Preview",
			Size = UDim2.new(1, -10, 0.62, 0),
			Position = UDim2.fromOffset(5, 6),
			BackgroundTransparency = 1,
			ZIndex = 2,
			Parent = card,
		})
		local entry = { id = result.id, level = 1, stars = result.stars or 1, aura = result.aura, trait = result.trait }
		local desc = Formulas.describe(entry)
		if desc then
			local viewport = Components.characterViewport(preview, desc.look, true, entry)
			viewport.ZIndex = 2
		end
	end
	local tag = Components.rarityTag(card, rarityId, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0.6, 0),
		Size = UDim2.fromOffset(118, 22),
		ZIndex = 3,
	})
	local _ = tag
	-- Mutation (variété) : pastille au-dessus de la rareté.
	local mutation = Mutations.get(result.aura)
	if mutation then
		local chip = new("Frame", {
			Name = "Mutation",
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 0.6, -3),
			Size = UDim2.fromOffset(136, 24),
			BackgroundColor3 = WHITE,
			ZIndex = 4,
			Parent = card,
		})
		Theme.corner(12).Parent = chip
		Theme.stroke(C.Stroke, 2).Parent = chip
		Theme.gradient(mutation.gradient, 0).Parent = chip
		Theme.label({
			Text = "✦ " .. mutation.name .. "  " .. Mutations.multText(mutation.id),
			Size = UDim2.new(1, -8, 1, -4),
			Position = UDim2.fromOffset(4, 2),
			FontFace = Theme.Faces.Heavy,
			ZIndex = 5,
			StrokeThickness = 1.5,
			Parent = chip,
		})
	end
	Theme.label({
		Name = "CharName",
		Text = def and def.name or "???",
		Size = UDim2.new(1, -10, 0, 24),
		Position = UDim2.new(0, 5, 0.6, 26),
		FontFace = Theme.Faces.Title,
		ZIndex = 3,
		StrokeThickness = 2.5,
		Parent = card,
	})
	local priceRow = new("Frame", {
		Name = "Price",
		Size = UDim2.new(1, -16, 0, 20),
		Position = UDim2.new(0, 8, 1, -28),
		BackgroundTransparency = 1,
		ZIndex = 3,
		Parent = card,
	})
	Components.coinIcon(priceRow, 18, UDim2.fromOffset(9, 10)).ZIndex = 3
	Theme.label({
		Text = Formulas.formatNumber(result.price or 0),
		Size = UDim2.new(0.5, -10, 1, 0),
		Position = UDim2.fromOffset(22, 0),
		FontFace = Theme.Faces.Heavy,
		TextColor3 = C.Gold,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 3,
		Parent = priceRow,
	})
	Theme.label({
		Text = Formulas.formatNumber(math.floor(result.dps or 0)) .. " DPS",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0.5, 0, 1, 0),
		FontFace = Theme.Faces.Heavy,
		TextColor3 = Color3.fromRGB(255, 120, 110),
		TextXAlignment = Enum.TextXAlignment.Right,
		ZIndex = 3,
		Parent = priceRow,
	})
	return holder, card
end

local function flashScreen(color: Color3)
	flash.BackgroundColor3 = color
	flash.BackgroundTransparency = 0.25
	flash.Visible = true
	Theme.tween(flash, 0.7, { BackgroundTransparency = 1 })
	task.delay(0.75, function()
		flash.Visible = false
	end)
end

RollReveal.FocusTime = 1.5 -- durée du cadrage de la caméra sur le podium (Légendaire et plus)
RollReveal.AwayTop = 232 -- loin de la machine : haut des cartes au plus haut (unités logiques)
RollReveal.CardSize = Vector2.new(176, 240)
RollReveal.CardGap = 14
RollReveal.BannerMinWidth = 360 -- loin de la machine : largeur minimale du bandeau MUTATION

-- Loin de la machine : largeur occupée par la révélation (unités logiques, avant réduction).
-- Le bandeau MUTATION (sous les cartes, texte centré mis à l'échelle de son cadre) est aussi
-- large que les cartes, et au moins BannerMinWidth pour rester lisible avec une seule carte.
function RollReveal.awayWidth(cards: number, mutation: boolean): number
	local width = cards * RollReveal.CardSize.X + (cards - 1) * RollReveal.CardGap
	if mutation then
		width = math.max(width, RollReveal.BannerMinWidth)
	end
	return width
end

-- Modules requis à la demande (ils ne requièrent pas celui-ci, mais sont chargés après lui).
local function sibling(name: string): any
	local module = script.Parent and script.Parent:FindFirstChild(name)
	if not module then
		return nil
	end
	local ok, result = pcall(require, module)
	return ok and result or nil
end

-- À la machine : bas du bandeau MUTATION, juste au-dessus de la barre ROULER. Calculé à
-- l'affichage : la barre est plus haute en tactile (au-dessus du bouton de saut,
-- RollPanel.panelBottom()).
function RollReveal.machineBannerBottom(): number
	local RollPanel = sibling("RollPanel")
	if RollPanel and RollPanel.panelBottom and RollPanel.PanelSize then
		return RollPanel.panelBottom() + RollPanel.PanelSize.Y + 8
	end
	return 96 + 92 + 8
end

-- Taille logique de l'écran (la racine est à l'échelle de l'interface) ; 1280 x 770 à défaut.
local function screenSize(): Vector2
	local ok, size = pcall(function()
		return root.AbsoluteSize / math.max(0.1, Theme.getScale())
	end)
	if ok and typeof(size) == "Vector2" and size.X >= 600 and size.Y >= 300 then
		return size
	end
	return Vector2.new(1280, 770)
end

-- Loin de la machine : les cartes se posent sous la pile du haut de l'écran (pastille
-- d'auto-roulage, panneau de la zone anti-AFK, bandeaux : UI/Quests), rapetissent s'il le faut
-- pour rester au-dessus des boutons de voyage, et glissent à droite des cartes de suivi des
-- défis si elles (ou le bandeau MUTATION, voir awayWidth) les croiseraient. Renvoie (haut,
-- échelle, décalage horizontal).
local awayCards = 1
local awayMutation = false
function RollReveal.awayLayout(cards: number?, mutation: boolean?): (number, number, number)
	local n = math.max(1, cards or awayCards)
	local muted = if mutation == nil then awayMutation else mutation
	local Quests = sibling("Quests")
	local stack = Quests and Quests.stackBottom and Quests.stackBottom() or 130
	local top = math.max(RollReveal.AwayTop, stack + 8)
	local screen = screenSize()
	local height = RollReveal.CardSize.Y + 4 + (muted and 36 or 0)
	local limit = screen.Y - 132 - 8 -- haut des boutons de voyage (HUD, bas centre)
	local scale = math.clamp((limit - top) / height, 0.3, 1)
	local width = RollReveal.awayWidth(n, muted) * scale
	local dx = 0
	if Quests and Quests.trackerBounds then
		local _, trackerTop, trackerRight, trackerBottom = Quests.trackerBounds()
		if trackerTop and trackerRight and trackerBottom and trackerTop < top + height * scale and trackerBottom > top then
			dx = math.max(0, trackerRight + 12 - (screen.X / 2 - width / 2))
		end
	end
	return top, scale, dx
end

-- Cadre la caméra sur le podium de la machine pendant FocusTime secondes, puis la rend.
local focusing = false
function RollReveal.focusPodium(): boolean
	local camera = workspace.CurrentCamera
	local okCF, machineCF = pcall(function()
		return require(script.Parent.RollPanel).machineCFrame()
	end)
	if focusing or not camera or not okCF or not machineCF then
		return false
	end
	focusing = true
	-- podium = centre de l'estrade (repère local de la machine : -Z = côté du joueur)
	-- (le perso tiré occupe le milieu bas de l'écran : sous la grande annonce, au-dessus des
	-- boutons de voyage)
	local target = (machineCF * CFrame.new(0, 8.4, 0)).Position
	local eye = (machineCF * CFrame.new(3, 8.5, -12)).Position
	local savedType = camera.CameraType
	local savedCF = camera.CFrame
	camera.CameraType = Enum.CameraType.Scriptable
	Theme.tween(camera, 0.35, { CFrame = CFrame.lookAt(eye, target) }, Enum.EasingStyle.Quad)
	task.delay(RollReveal.FocusTime, function()
		pcall(Theme.tween, camera, 0.3, { CFrame = savedCF }, Enum.EasingStyle.Quad)
		task.delay(0.32, function()
			if camera.CameraType == Enum.CameraType.Scriptable then
				camera.CameraType = savedType
			end
			focusing = false
		end)
	end)
	return true
end

-- Place les cartes (à chaque image tant qu'elles sont affichées : la pile du haut peut bouger).
local stripAtMachine = false
local function placeStrip()
	if stripAtMachine then
		strip.Position = UDim2.new(1, -16, 1, -RollReveal.machineBannerBottom())
		stripScale.Scale = 1
	else
		local top, scale, dx = RollReveal.awayLayout()
		strip.Position = UDim2.new(0.5, dx, 0, top)
		stripScale.Scale = scale
	end
end

-- Révélation (après la roulette).
local function reveal(payload, myBatch: number)
	if myBatch ~= batch then
		return
	end
	Components.clear(strip)
	strip.Visible = true
	-- À LA MACHINE, on voit le perso tiré en vrai sur le podium (avec son étiquette et son invite
	-- « Collecter ») : pas de vignettes. Seul le bandeau MUTATION s'affiche, au-dessus de la barre
	-- ROULER, et pour un Légendaire ou plus la caméra cadre le podium 1,5 s (focusPodium).
	local okNear, near = pcall(function()
		return require(script.Parent.RollPanel).isNear()
	end)
	local atMachine = okNear and near == true
	stripAtMachine = atMachine
	awayCards = #payload.results
	awayMutation = false
	for _, result in payload.results do
		awayMutation = awayMutation or Mutations.get(result.aura) ~= nil
	end
	strip.AnchorPoint = atMachine and Vector2.new(1, 1) or Vector2.new(0.5, 0)
	-- (à la machine : hauteur = contenu seul, le bandeau se pose juste au-dessus de la carte)
	strip.Size = atMachine and UDim2.fromOffset(640, 0) or UDim2.fromOffset(640, 280)
	placeStrip()
	local stripAlign = atMachine and Enum.HorizontalAlignment.Right or Enum.HorizontalAlignment.Center
	local stripLayout = strip:FindFirstChildOfClass("UIListLayout")
	if stripLayout then
		stripLayout.HorizontalAlignment = stripAlign
	end
	local best = nil
	for _, result in payload.results do
		if not best or rarityOrder(result.rarity) > rarityOrder(best.rarity) then
			best = result
		end
	end
	-- Bandeau « MUTATION ! » quand un perso tiré est muté.
	local bestMutation = nil
	for _, result in payload.results do
		local m = Mutations.get(result.aura)
		if m and (not bestMutation or m.multiplier > bestMutation.multiplier) then
			bestMutation = m
		end
	end
	if bestMutation then
		-- (loin de la machine : largeur des cartes, au moins BannerMinWidth, comptée par
		-- awayLayout pour ne pas passer sur les cartes de suivi des défis)
		local banner = Theme.label({
			Name = "Mutation",
			Text = "✦ MUTATION " .. Formulas.upper(bestMutation.name) .. " ! ✦",
			Size = if atMachine then UDim2.new(1, 0, 0, 32) else UDim2.fromOffset(RollReveal.awayWidth(#payload.results, true), 32),
			FontFace = Theme.Faces.Title,
			LayoutOrder = 2, -- sous les cartes (l'annonce géante occupe le haut)
			StrokeThickness = 3,
			TextXAlignment = atMachine and Enum.TextXAlignment.Right or Enum.TextXAlignment.Center,
			Parent = strip,
		})
		Theme.gradient(bestMutation.gradient, 90).Parent = banner
	end
	local cards = new("Frame", {
		Name = "Cards",
		Size = UDim2.new(1, 0, 0, atMachine and 0 or 244),
		BackgroundTransparency = 1,
		LayoutOrder = 1,
		Visible = not atMachine,
		Parent = strip,
	})
	local layout = Theme.list(Enum.FillDirection.Horizontal, 14, stripAlign)
	layout.Parent = cards
	for i, result in (if atMachine then {} else payload.results) do
		local holder, card = buildCard(cards, result, i)
		local _ = holder
		local scale = new("UIScale", { Scale = 0.2, Parent = card })
		card.Rotation = -12
		task.delay((i - 1) * 0.18, function()
			if card.Parent then
				SoundService:PlayLocalSound(flipSound)
				Theme.tween(scale, 0.4, { Scale = 1 }, Enum.EasingStyle.Back)
				Theme.tween(card, 0.4, { Rotation = 0 }, Enum.EasingStyle.Back)
			end
		end)
	end
	local bigMutation = bestMutation and bestMutation.multiplier >= 3.5
	if best and (rarityOrder(best.rarity) >= rarityOrder("legendary") or bigMutation) then
		local info = Theme.rarity(best.rarity)
		local def = Characters.get(best.id or "")
		if atMachine and rarityOrder(best.rarity) >= rarityOrder("legendary") and not payload.auto then
			RollReveal.focusPodium()
		end
		task.delay(0.25, function()
			SoundService:PlayLocalSound(rareSound)
			flashScreen(info.rainbow and WHITE or info.color)
			Notifications.announce(
				Formulas.upper(info.name) .. " !",
				(def and def.name or "Un perso rare") .. " t'attend sur l'estrade !",
				info.rainbow and C.Magenta or info.color,
				true
			)
		end)
	end
	-- Les cartes restent un moment puis s'envolent.
	task.delay(payload.auto and 1.8 or 2.6, function()
		if myBatch ~= batch then
			return
		end
		for _, card in cards:GetDescendants() do
			if card.Name == "Card" and card:IsA("Frame") then
				local scale = card:FindFirstChildOfClass("UIScale")
				if scale then
					Theme.tween(scale, 0.25, { Scale = 0 }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
				end
			end
		end
		task.wait(0.3)
		if myBatch == batch then
			strip.Visible = false
			Components.clear(strip)
		end
	end)
end

function RollReveal.show(payload)
	if type(payload) ~= "table" or type(payload.results) ~= "table" or #payload.results == 0 then
		return
	end
	batch += 1
	local myBatch = batch
	-- Roulette d'abord, SUR L'ESTRADE (UI/RollSpin : des persos défilent sur la case du perso
	-- tiré puis s'arrêtent dessus) ; la suite (bandeau MUTATION, annonce, caméra) à l'arrêt.
	-- Loin de la machine, ou sans durée : tout de suite.
	local okNear, near = pcall(function()
		return require(script.Parent.RollPanel).isNear()
	end)
	RollSpin.play(payload, okNear and near == true, function()
		reveal(payload, myBatch)
	end)
end

function RollReveal.init(gui: ScreenGui)
	root = Theme.scaledRoot(gui, "RollReveal", 35)
	flash = new("Frame", {
		Name = "Flash",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = WHITE,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Visible = false,
		Parent = root,
	})
	strip = new("Frame", {
		Name = "Strip",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 232),
		Size = UDim2.fromOffset(640, 280),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Visible = false,
		Parent = root,
	})
	Theme.list(Enum.FillDirection.Vertical, 4, Enum.HorizontalAlignment.Center).Parent = strip
	stripScale = new("UIScale", { Parent = strip })
	Theme.onFrame(strip, function()
		if strip.Visible then
			placeStrip()
		end
	end)
	local remote = State.remoteEvent("RollResult")
	if remote then
		remote.OnClientEvent:Connect(RollReveal.show)
	else
		-- La remote est créée par le serveur (domaine BASE) : on l'attend sans bloquer.
		local folder = ReplicatedStorage:FindFirstChild("Remotes")
		if folder then
			local connection
			connection = folder.ChildAdded:Connect(function(child)
				if child.Name == "RollResult" and child:IsA("RemoteEvent") then
					connection:Disconnect()
					child.OnClientEvent:Connect(RollReveal.show)
				end
			end)
		end
	end
end

return RollReveal
