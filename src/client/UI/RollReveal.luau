-- Révélation animée des persos tirés par la machine ROULER (RemoteEvent « RollResult ») :
-- les cartes se retournent sous la bannière, avec la couleur de leur rareté, le prix et les
-- dégâts par seconde. Pour les grosses raretés (Légendaire et plus) : éclair de lumière,
-- rayons tournants et grande annonce.
--
-- Données reçues : { results = { { id, stars, rarity, price, dps, aura? (= mutation), trait? } },
--                    pity = { mythic = n }, luck, count, auto = vrai pendant l'auto-roulage }
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

function RollReveal.show(payload)
	if type(payload) ~= "table" or type(payload.results) ~= "table" or #payload.results == 0 then
		return
	end
	batch += 1
	local myBatch = batch
	Components.clear(strip)
	strip.Visible = true
	-- À la machine, les commandes et la carte du perso tiré sont en bas et l'annonce géante au
	-- centre : les cartes passent à droite (libre depuis la v3.2), un peu plus petites.
	local okNear, near = pcall(function()
		return require(script.Parent.RollPanel).isNear()
	end)
	local atMachine = okNear and near == true
	strip.AnchorPoint = atMachine and Vector2.new(1, 0) or Vector2.new(0.5, 0)
	strip.Position = atMachine and UDim2.new(1, -16, 0, 150) or UDim2.new(0.5, 0, 0, 232)
	stripScale.Scale = atMachine and 0.7 or 1
	-- (à la machine, cartes et bandeau collés au bord droit : loin de l'annonce géante centrée)
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
		local banner = Theme.label({
			Name = "Mutation",
			Text = "✦ MUTATION " .. string.upper(bestMutation.name) .. " ! ✦",
			Size = UDim2.new(1, 0, 0, 32),
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
		Size = UDim2.new(1, 0, 0, 244),
		BackgroundTransparency = 1,
		LayoutOrder = 1,
		Parent = strip,
	})
	local layout = Theme.list(Enum.FillDirection.Horizontal, 14, stripAlign)
	layout.Parent = cards
	for i, result in payload.results do
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
		task.delay(0.25, function()
			SoundService:PlayLocalSound(rareSound)
			flashScreen(info.rainbow and WHITE or info.color)
			Notifications.announce(
				string.upper(info.name) .. " !",
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
