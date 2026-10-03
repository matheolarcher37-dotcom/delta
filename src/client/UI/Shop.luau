-- Machine à Reliques : achat des reliques de l'univers actuel (stock renouvelé toutes les 5 min).

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

local window
local refs = {}
local shopState = nil

local TIER_NAMES = { "Relique Commune", "Relique Rare", "Relique Légendaire" }

local function render()
	Components.clear(refs.cards)
	if not shopState then
		return
	end
	local universe = Universes.get(shopState.universeId)
	if not universe then
		return
	end
	window.title.Text = "🛒 RELIQUES · " .. string.upper(universe.name)
	for index, item in shopState.items do
		local relic = Universes.getRelic(item.relicId)
		local tier = Economy.RelicTiers[relic.tier]
		local tierColor = ({ C.Blue, C.Purple, C.Gold })[relic.tier] or C.Blue
		local card = new("Frame", {
			Size = UDim2.new(0.32, 0, 1, 0),
			BackgroundColor3 = C.PanelLight,
			LayoutOrder = index,
			Parent = refs.cards,
		})
		Theme.corner(16).Parent = card
		Theme.stroke(tierColor, 4).Parent = card
		Theme.gradient({ tierColor:Lerp(C.Panel, 0.55), C.PanelDark }, 90).Parent = card

		local preview = new("Frame", { Size = UDim2.new(1, -16, 0.34, 0), Position = UDim2.fromOffset(8, 8), BackgroundTransparency = 1, Parent = card })
		Components.relicViewport(preview, relic, true)
		Theme.label({ Text = relic.name, Size = UDim2.new(1, -16, 0.07, 0), Position = UDim2.new(0, 8, 0.35, 0), Font = Theme.Fonts.Title, Parent = card })
		Theme.label({ Text = TIER_NAMES[relic.tier] .. " · ⏳ " .. tier.hatchTime .. "s", Size = UDim2.new(1, -16, 0.045, 0), Position = UDim2.new(0, 8, 0.425, 0), TextColor3 = tierColor:Lerp(Color3.new(1, 1, 1), 0.3), Font = Theme.Fonts.Small, Parent = card })

		-- Probabilités
		local odds = new("Frame", { Size = UDim2.new(1, -24, 0.3, 0), Position = UDim2.new(0, 12, 0.48, 0), BackgroundTransparency = 1, Parent = card })
		Theme.list(Enum.FillDirection.Vertical, 2, Enum.HorizontalAlignment.Left).Parent = odds
		local order = 0
		for _, rarityId in Rarities.Order do
			local weight = relic.odds[rarityId]
			if weight then
				order += 1
				local rarity = Rarities.get(rarityId)
				local names = {}
				for _, id in universe.characters do
					local def = Characters.get(id)
					if def and def.rarity == rarityId then
						table.insert(names, def.name)
					end
				end
				local row = Theme.label({
					Text = string.format("%s %s%%  ·  %s", rarity.name, tostring(weight), table.concat(names, ", ")),
					Size = UDim2.new(1, 0, 0, 18),
					TextXAlignment = Enum.TextXAlignment.Left,
					TextColor3 = rarity.color:Lerp(Color3.new(1, 1, 1), 0.2),
					Font = Theme.Fonts.Small,
					LayoutOrder = order,
					Parent = odds,
				})
				new("UITextSizeConstraint", { MaxTextSize = 15, Parent = row })
			end
		end

		Theme.label({
			Text = item.stock == 0 and "Pas en stock cette fois-ci" or ("Stock : " .. item.remaining .. " / " .. item.stock),
			Size = UDim2.new(1, -16, 0.05, 0),
			Position = UDim2.new(0, 8, 0.79, 0),
			TextColor3 = item.remaining > 0 and C.Green or C.Red,
			Parent = card,
		})
		local canBuy = item.remaining > 0
		Components.button({
			Text = canBuy and ("💰 " .. Formulas.formatNumber(item.price)) or "Épuisé",
			Color = canBuy and C.Green or Color3.fromRGB(110, 110, 120),
			Size = UDim2.new(1, -24, 0.12, 0),
			Position = UDim2.new(0, 12, 0.86, 0),
			Parent = card,
			OnClick = function()
				if not canBuy then
					return
				end
				local ok, success, message, newState = pcall(function()
					return Remotes.func("BuyRelic"):InvokeServer(item.relicId)
				end)
				if ok then
					if success then
						Notifications.toast(message, "success")
					end
					if newState then
						shopState = newState
						render()
					end
				end
			end,
		})
	end
end

local function refresh()
	local ok, result = pcall(function()
		return Remotes.func("GetShop"):InvokeServer()
	end)
	if ok and result then
		shopState = result
		render()
	end
end

function Shop.init(gui: ScreenGui)
	window = Components.window(gui, "🛒 MACHINE À RELIQUES", C.Orange)
	local content = window.content
	refs.timer = Theme.label({
		Size = UDim2.new(1, 0, 0, 30),
		TextColor3 = C.TextDim,
		Parent = content,
	})
	refs.cards = new("Frame", {
		Size = UDim2.new(1, 0, 1, -40),
		Position = UDim2.fromOffset(0, 40),
		BackgroundTransparency = 1,
		Parent = content,
	})
	local layout = Theme.list(Enum.FillDirection.Horizontal, 12, Enum.HorizontalAlignment.Center)
	layout.Parent = refs.cards

	window.onClose = function()
		Menus.closed("Shop")
	end
	Menus.register("Shop", {
		open = function()
			window.open()
			refresh()
		end,
		close = window.close,
	})

	task.spawn(function()
		while true do
			task.wait(1)
			if window.isOpen and shopState then
				local remaining = shopState.restockAt - State.now()
				refs.timer.Text = "🔄 Réapprovisionnement dans " .. Formulas.formatTime(remaining) .. "  ·  Les reliques changent avec l'univers !"
				local universeId = State.gameState():GetAttribute("UniverseId")
				if remaining <= 0 or universeId ~= shopState.universeId then
					refresh()
				end
			end
		end
	end)
end

return Shop
