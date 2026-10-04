-- Menu OPTIONS : confort de jeu (secousse d'écran, flashs, qualité des effets d'attaque).
-- Les réglages sont des attributs du joueur local lus par Controllers/Effects :
--   FxShake (booléen), FxFlash (booléen), FxQuality ("auto" | "high" | "medium" | "low").
-- Manette : A choisit, B ferme.

local Players = game:GetService("Players")

local Theme = require(script.Parent.Theme)
local Components = require(script.Parent.Components)
local Menus = require(script.Parent.Menus)

local Options = {}

local C = Theme.Colors
local new = Theme.new

local window
local rows: { [string]: { [any]: TextButton } } = {}
local firstButton: GuiObject? = nil

Options.Settings = {
	{
		attribute = "FxShake",
		title = "Secousse d'écran",
		desc = "Pendant les attaques spéciales et les coups de boss.",
		choices = { { value = true, text = "Oui" }, { value = false, text = "Non" } },
		default = true,
	},
	{
		attribute = "FxFlash",
		title = "Flashs lumineux",
		desc = "Éclairs d'écran et traits de vitesse des grosses attaques.",
		choices = { { value = true, text = "Oui" }, { value = false, text = "Non" } },
		default = true,
	},
	{
		attribute = "FxQuality",
		title = "Qualité des effets",
		desc = "Auto : PC = haute, console = moyenne, mobile = basse (baisse toute seule si le jeu rame).",
		choices = {
			{ value = "auto", text = "Auto" },
			{ value = "high", text = "Haute" },
			{ value = "medium", text = "Moyenne" },
			{ value = "low", text = "Basse" },
		},
		default = "auto",
	},
}

local function currentValue(setting)
	local player = Players.LocalPlayer
	local value = player and player:GetAttribute(setting.attribute)
	if value == nil then
		return setting.default
	end
	return value
end

local function refresh()
	for _, setting in Options.Settings do
		local value = currentValue(setting)
		for choice, button in rows[setting.attribute] or {} do
			Components.setButtonColor(button, choice == value and C.Green or C.Gray)
		end
	end
end

function Options.set(attribute: string, value: any)
	local player = Players.LocalPlayer
	if player then
		player:SetAttribute(attribute, value)
	end
	refresh()
end

function Options.init(gui: ScreenGui)
	window = Components.window(gui, "OPTIONS", Color3.fromRGB(110, 120, 150), UDim2.fromOffset(820, 460), {
		icon = "eye",
	})
	local content = window.content
	Theme.list(Enum.FillDirection.Vertical, 14, Enum.HorizontalAlignment.Center).Parent = content
	for order, setting in Options.Settings do
		local row = Components.panel(content, {
			Name = "Row_" .. setting.attribute,
			Size = UDim2.new(1, -16, 0, 104),
			LayoutOrder = order,
		})
		Theme.label({
			Text = setting.title,
			Size = UDim2.new(1, -32, 0, 30),
			Position = UDim2.fromOffset(16, 10),
			FontFace = Theme.Faces.Title,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = row,
		})
		Theme.label({
			Text = setting.desc,
			Size = UDim2.new(1, -32, 0, 20),
			Position = UDim2.fromOffset(16, 40),
			FontFace = Theme.Faces.Medium,
			TextColor3 = C.TextDim,
			TextXAlignment = Enum.TextXAlignment.Left,
			MaxSize = 16,
			StrokeThickness = 1,
			Parent = row,
		})
		local choices = new("Frame", {
			Name = "Choices",
			Size = UDim2.new(1, -32, 0, 40),
			Position = UDim2.fromOffset(16, 62),
			BackgroundTransparency = 1,
			Parent = row,
		})
		local layout = Theme.list(Enum.FillDirection.Horizontal, 10, Enum.HorizontalAlignment.Left)
		layout.VerticalAlignment = Enum.VerticalAlignment.Center
		layout.Parent = choices
		rows[setting.attribute] = {}
		for i, choice in setting.choices do
			local button = Components.button({
				Text = choice.text,
				Color = C.Gray,
				Size = UDim2.fromOffset(140, 38),
				TextSize = 18,
				LayoutOrder = i,
				Parent = choices,
				OnClick = function()
					Options.set(setting.attribute, choice.value)
				end,
			})
			rows[setting.attribute][choice.value] = button
			firstButton = firstButton or button
		end
	end
	Components.registerWindow(Menus, "Options", window, refresh, function()
		return firstButton or window.firstSelectable()
	end)
	refresh()
end

return Options
