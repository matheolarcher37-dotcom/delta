-- BOUTIQUE (Machine à Reliques) : reliques de l'univers actuel, stock renouvelé toutes les 5 min.
-- Trois grandes cartes (Commune / Rare / Légendaire) : aperçu 3D, temps d'ouverture,
-- probabilités par rareté, stock et gros bouton d'achat avec le prix.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Rarities = require(Shared.Config.Rarities)
local Characters = require(Shared.Config.Characters)
local Universes = require(Shared.Config.Universes)
local Economy = require(Shared.Config.Economy)
local Formulas = require(Shared.Modules.Formulas)
local Remotes = require(Shared.Modules.Remotes)

local Theme = require(script.Parent.Theme)
local Components = require(script.Parent.Components)
local Menus = require(script.Parent.Menus)
local Notifications = require(script.Parent.Notifications)
local State = require(script.Parent.Parent.State)

local Shop = {}

local C = Theme.Colors
local new = Theme.new
local WHITE = Color3.new(1, 1, 1)
local ACCENT = Color3.fromRGB(200, 50, 230)

local window
local refs: { [string]: any } = {}
local shopState = nil

local TIER_NAMES = { "COMMUNE", "RARE", "LÉGENDAIRE" }
local TIER_COLORS = { Color3.fromRGB(64, 160, 255), Color3.fromRGB(176, 92, 255), Color3.fromRGB(255, 190, 40) }

local function buy(item)
	local ok, success, message, newState = pcall(function()
		return Remotes.func("BuyRelic"):InvokeServer(item.relicId)
	end)
	if not ok then
		Notifications.toast("Erreur de connexion, réessaie.", "error")
		return
	end
	-- (les erreurs sont déjà annoncées par le serveur)
	if success and message then
		Notifications.toast(message, "success")
	end
	if newState then
		shopState = newState
		Shop.render()
	end
end

function Shop.render()
	Components.clear(refs.cards)
	refs.firstButton = nil
	if not shopState then
		return
	end
	local universe = Universes.get(shopState.universeId)
	if not universe then
		return
	end
	Components.setPillText(refs.universePill, "Reliques : " .. universe.name)
	local coins = State.data and State.data.coins or 0
	for index, item in shopState.items do
		local relic = Universes.getRelic(item.relicId)
		local tier = Economy.RelicTiers[relic.tier]
		local color = TIER_COLORS[relic.tier] or C.Blue
		local card = new("Frame", {
			Name = "RelicCard",
			Size = UDim2.new(1 / 3, -10, 1, 0),
			BackgroundColor3 = WHITE,
			LayoutOrder = index,
			Parent = refs.cards,
		})
		Theme.corner(18).Parent = card
		Theme.stroke(C.Stroke, 3).Parent = card
		Theme.gradient({ Theme.dark(color, 0.25), Theme.dark(color, 0.7), Color3.fromRGB(12, 12, 18) }, 90).Parent = card
		local rim = new("Frame", { Size = UDim2.new(1, -8, 1, -8), Position = UDim2.fromOffset(4, 4), BackgroundTransparency = 1, Parent = card })
		Theme.corner(15).Parent = rim
		Theme.stroke(Theme.light(color, 0.2), 2, 0.2).Parent = rim
		Theme.sparkles(card, 7, index * 13, 0.72)
		-- En-tête : rang de la relique
		local band = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 10),
			Size = UDim2.new(0.7, 0, 0, 30),
			BackgroundColor3 = WHITE,
			ZIndex = 3,
			Parent = card,
		})
		Theme.round().Parent = band
		Theme.stroke(C.Stroke, 2).Parent = band
		Theme.gradient({ Theme.light(color, 0.3), color, Theme.dark(color, 0.25) }, 90).Parent = band
		Theme.label({ Text = "RELIQUE " .. (TIER_NAMES[relic.tier] or ""), Size = UDim2.new(1, -16, 1, -6), Position = UDim2.fromOffset(8, 3), FontFace = Theme.Faces.Title, ZIndex = 4, Parent = band })

		local preview = new("Frame", { Size = UDim2.new(1, -16, 0, 130), Position = UDim2.fromOffset(8, 44), BackgroundTransparency = 1, ZIndex = 2, Parent = card })
		local glow = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(150, 120),
			BackgroundColor3 = color,
			BackgroundTransparency = 0.55,
			BorderSizePixel = 0,
			Parent = preview,
		})
		Theme.round().Parent = glow
		Theme.gradient({ WHITE, WHITE }, 90, { 0.3, 1 }).Parent = glow
		Components.relicViewport(preview, relic, true).ZIndex = 2
		Theme.label({ Text = relic.name, Size = UDim2.new(1, -20, 0, 30), Position = UDim2.fromOffset(10, 176), FontFace = Theme.Faces.Title, StrokeThickness = 2.5, Parent = card })
		Components.pill(card, "hourglass", "Ouverture : " .. tier.hatchTime .. " s", C.Gold, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 210), Size = UDim2.fromOffset(200, 30) })

		-- Probabilités
		local odds = new("Frame", { Size = UDim2.new(1, -24, 0, 120), Position = UDim2.fromOffset(12, 248), BackgroundTransparency = 1, Parent = card })
		Theme.list(Enum.FillDirection.Vertical, 3, Enum.HorizontalAlignment.Left).Parent = odds
		local order = 0
		for _, rarityId in Rarities.Order do
			local weight = relic.odds[rarityId]
			if weight then
				order += 1
				local info = Theme.rarity(rarityId)
				local names = {}
				for _, id in universe.characters do
					local def = Characters.get(id)
					if def and def.rarity == rarityId then
						table.insert(names, def.name)
					end
				end
				local row = new("Frame", { Size = UDim2.new(1, 0, 0, 22), BackgroundTransparency = 1, LayoutOrder = order, Parent = odds })
				Components.rarityTag(row, rarityId, { Size = UDim2.fromOffset(96, 20), Position = UDim2.fromOffset(0, 1) })
				Theme.label({
					Text = tostring(weight) .. " %  " .. table.concat(names, ", "),
					Size = UDim2.new(1, -104, 1, -2),
					Position = UDim2.fromOffset(102, 1),
					FontFace = Theme.Faces.Bold,
					TextColor3 = info.rainbow and WHITE or Theme.light(info.color, 0.35),
					TextXAlignment = Enum.TextXAlignment.Left,
					StrokeThickness = 1.5,
					MaxSize = 15,
					Parent = row,
				})
			end
		end

		local canBuy = item.remaining > 0
		Components.pill(
			card,
			"bag",
			item.stock == 0 and "Pas en stock cette fois-ci" or ("Stock : " .. item.remaining .. " / " .. item.stock),
			canBuy and C.Green or C.Red,
			{ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -76), Size = UDim2.new(1, -24, 0, 30) }
		)
		local button = Components.button({
			Text = canBuy and Formulas.formatNumber(item.price) or "ÉPUISÉ",
			Icon = canBuy and "coin" or nil,
			Color = canBuy and (coins >= item.price and C.Green or Color3.fromRGB(200, 70, 70)) or C.Gray,
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -14),
			Size = UDim2.new(1, -24, 0, 54),
			TextSize = 26,
			Parent = card,
			OnClick = function()
				if canBuy then
					buy(item)
				end
			end,
		})
		refs.firstButton = refs.firstButton or button
	end
end

local function refresh()
	local ok, result = pcall(function()
		return Remotes.func("GetShop"):InvokeServer()
	end)
	if ok and result then
		shopState = result
		Shop.render()
	end
end

function Shop.init(gui: ScreenGui)
	window = Components.window(gui, "BOUTIQUE", ACCENT, UDim2.fromOffset(1100, 640), {
		icon = "shop",
		subtitle = "Les reliques changent avec l'univers !",
	})
	local content = window.content
	local top = new("Frame", { Size = UDim2.new(1, 0, 0, 40), BackgroundTransparency = 1, Parent = content })
	local layout = Theme.list(Enum.FillDirection.Horizontal, 10, Enum.HorizontalAlignment.Left)
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Parent = top
	refs.universePill = Components.pill(top, "pin", "Reliques", C.Purple, { Size = UDim2.fromOffset(380, 36), LayoutOrder = 1 })
	refs.timerPill = Components.pill(top, "refresh", "Nouveau stock dans --:--", C.Cyan, { Size = UDim2.fromOffset(330, 36), LayoutOrder = 2 })
	refs.coinsPill = Components.pill(top, "coin", "0", C.Gold, { Size = UDim2.fromOffset(200, 36), LayoutOrder = 3 })
	refs.cards = new("Frame", {
		Name = "Cards",
		Size = UDim2.new(1, 0, 1, -50),
		Position = UDim2.fromOffset(0, 50),
		BackgroundTransparency = 1,
		Parent = content,
	})
	Theme.list(Enum.FillDirection.Horizontal, 15, Enum.HorizontalAlignment.Center).Parent = refs.cards

	Components.registerWindow(Menus, "Shop", window, function()
		refresh()
	end, function()
		return refs.firstButton or window.firstSelectable()
	end)

	State.onChanged(function(data)
		Components.setPillText(refs.coinsPill, Formulas.formatNumber(data.coins))
	end)

	task.spawn(function()
		while true do
			task.wait(1)
			if window.isOpen and shopState then
				local remaining = shopState.restockAt - State.now()
				Components.setPillText(refs.timerPill, "Nouveau stock dans " .. Formulas.formatTime(remaining))
				local universeId = State.gameState():GetAttribute("UniverseId")
				if remaining <= 0 or universeId ~= shopState.universeId then
					refresh()
				end
			end
		end
	end)
end

return Shop
