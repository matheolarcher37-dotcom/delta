-- Autel des Traits : relancer le trait d'un perso avec un Cristal de Trait (animation de tirage).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Traits = require(Shared.Config.Traits)
local Economy = require(Shared.Config.Economy)
local Formulas = require(Shared.Modules.Formulas)
local Remotes = require(Shared.Modules.Remotes)

local Theme = require(script.Parent.Theme)
local Components = require(script.Parent.Components)
local Menus = require(script.Parent.Menus)
local Notifications = require(script.Parent.Notifications)
local State = require(script.Parent.Parent.State)

local TraitsMenu = {}

local C = Theme.Colors
local new = Theme.new

local window
local refs = {}
local selected: string? = nil
local rolling = false
local render: (boolean?) -> ()

local tickSound = Instance.new("Sound")
tickSound.SoundId = "rbxasset://sounds/clickfast.wav"
tickSound.Volume = 0.25
tickSound.Parent = SoundService

local function chancesList(parent: Instance)
	local list = new("ScrollingFrame", {
		Size = UDim2.new(1, -16, 0.3, 0),
		Position = UDim2.new(0, 8, 0.69, -60),
		BackgroundColor3 = C.PanelDark,
		BackgroundTransparency = 0.3,
		BorderSizePixel = 0,
		ScrollBarThickness = 4,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = parent,
	})
	Theme.corner(10).Parent = list
	Theme.list(Enum.FillDirection.Vertical, 2, Enum.HorizontalAlignment.Left).Parent = list
	Theme.padding(6).Parent = list
	for i, id in Traits.Order do
		local trait = Traits.List[id]
		local row = Theme.label({
			Text = string.format("◆ %s (%.1f %%) — %s", trait.name, Traits.chance(id), trait.description),
			Size = UDim2.new(1, -8, 0, 18),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = trait.color:Lerp(Color3.new(1, 1, 1), 0.25),
			Font = Theme.Fonts.Small,
			LayoutOrder = i,
			Parent = list,
		})
		new("UITextSizeConstraint", { MaxTextSize = 14, Parent = row })
	end
end

local function renderDetail()
	local panel = refs.detail
	Components.clear(panel)
	local data = State.data
	refs.crystals.Text = "💎 Cristaux de Trait : " .. (data and data.traitCrystals or 0)
	local entry = data and selected and data.characters[selected]
	if not entry then
		Theme.label({
			Text = "Choisis un perso à gauche pour relancer son trait.",
			Size = UDim2.new(1, -20, 0, 50),
			Position = UDim2.new(0, 10, 0.3, 0),
			TextColor3 = C.TextDim,
			TextWrapped = true,
			Parent = panel,
		})
		chancesList(panel)
		return
	end
	local desc = Formulas.describe(entry)
	local preview = new("Frame", { Size = UDim2.new(1, -16, 0.32, 0), Position = UDim2.fromOffset(8, 6), BackgroundColor3 = C.PanelDark, Parent = panel })
	Theme.corner(12).Parent = preview
	Components.characterViewport(preview, desc.look, true, entry)
	Theme.label({ Text = desc.name, Size = UDim2.new(1, -16, 0.06, 0), Position = UDim2.new(0, 8, 0.335, 0), Font = Theme.Fonts.Title, Parent = panel })

	local trait = Traits.get(entry.trait)
	local box = new("Frame", { Size = UDim2.new(1, -16, 0.15, 0), Position = UDim2.new(0, 8, 0.405, 0), BackgroundColor3 = trait and trait.color or C.PanelLight, Parent = panel })
	Theme.corner(12).Parent = box
	Theme.stroke(trait and Traits.TierColors[trait.tier] or C.Stroke, 3).Parent = box
	if trait then
		Theme.gradient({ trait.color:Lerp(Color3.new(1, 1, 1), 0.15), trait.color:Lerp(Color3.new(0, 0, 0), 0.45) }, 90).Parent = box
	end
	refs.traitName = Theme.label({
		Text = trait and ("◆ " .. trait.name) or "Aucun trait",
		Size = UDim2.new(1, -16, 0.55, 0),
		Position = UDim2.new(0, 8, 0.05, 0),
		Font = Theme.Fonts.Title,
		Parent = box,
	})
	refs.traitDesc = Theme.label({
		Text = trait and (Traits.TierNames[trait.tier] .. " · " .. trait.description) or "Relance pour obtenir un bonus !",
		Size = UDim2.new(1, -16, 0.35, 0),
		Position = UDim2.new(0, 8, 0.6, 0),
		Font = Theme.Fonts.Small,
		Parent = box,
	})
	refs.traitBox = box

	local uid = selected :: string
	Components.button({
		Text = "🎲 RELANCER (1 💎)",
		Color = C.Purple,
		Size = UDim2.new(1, -16, 0, 46),
		Position = UDim2.new(0, 8, 0.57, 0),
		Parent = panel,
		OnClick = function()
			if rolling then
				return
			end
			if (State.data and State.data.traitCrystals or 0) < 1 then
				Notifications.toast("Il te faut un Cristal de Trait 💎", "error")
				return
			end
			rolling = true
			-- Animation : les noms défilent de plus en plus lentement.
			local order = Traits.Order
			local delay = 0.04
			for _ = 1, 18 do
				local random = Traits.List[order[math.random(1, #order)]]
				if refs.traitName and refs.traitName.Parent then
					refs.traitName.Text = "◆ " .. random.name
					refs.traitBox.BackgroundColor3 = random.color
				end
				SoundService:PlayLocalSound(tickSound)
				task.wait(delay)
				delay *= 1.12
			end
			local ok, success, message = pcall(function()
				return Remotes.func("RerollTrait"):InvokeServer(uid)
			end)
			rolling = false
			if ok and message then
				Notifications.toast(message, success and "success" or "error")
			end
			render(true)
		end,
	})
	chancesList(panel)
end

local function renderGrid()
	Components.clear(refs.grid)
	for i, item in State.sortedCharacters() do
		if i > 48 then
			break
		end
		Components.characterCard(refs.grid, item.entry, {
			size = UDim2.fromOffset(104, 132),
			selected = item.uid == selected,
			inTeam = State.inTeam(item.uid),
			layoutOrder = i,
			onClick = function()
				selected = item.uid
				render(true)
			end,
		})
	end
end

local lastKey = ""
render = function(force: boolean?)
	if not window or not window.isOpen or rolling then
		return
	end
	local data = State.data
	if not data then
		return
	end
	local parts = { tostring(selected), tostring(data.traitCrystals) }
	for uid, entry in data.characters do
		table.insert(parts, uid .. tostring(entry.trait) .. entry.level .. entry.stars)
	end
	table.sort(parts)
	local key = table.concat(parts, "|")
	if not force and key == lastKey then
		return
	end
	lastKey = key
	renderGrid()
	renderDetail()
end

function TraitsMenu.init(gui: ScreenGui)
	window = Components.window(gui, "💎 AUTEL DES TRAITS", Color3.fromRGB(80, 200, 255))
	local content = window.content
	refs.crystals = Theme.label({ Size = UDim2.new(0.5, 0, 0, 30), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Color3.fromRGB(140, 230, 255), Parent = content })
	Components.button({
		Text = "Acheter 1 💎 (" .. Formulas.formatNumber(Economy.TraitCrystalPrice) .. ")",
		Color = C.Blue,
		Size = UDim2.fromOffset(230, 36),
		Position = UDim2.new(1, -230, 0, -2),
		Parent = content,
		OnClick = function()
			local ok, success, message = pcall(function()
				return Remotes.func("BuyTraitCrystal"):InvokeServer()
			end)
			if ok and message then
				Notifications.toast(message, success and "success" or "error")
			end
		end,
	})
	refs.grid = new("ScrollingFrame", {
		Size = UDim2.new(0.52, 0, 1, -44),
		Position = UDim2.fromOffset(0, 44),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = content,
	})
	new("UIGridLayout", { CellSize = UDim2.fromOffset(104, 132), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = refs.grid })
	Theme.padding(6).Parent = refs.grid
	refs.detail = new("Frame", {
		Size = UDim2.new(0.47, 0, 1, -44),
		Position = UDim2.new(0.53, 0, 0, 44),
		BackgroundColor3 = C.PanelDark,
		BackgroundTransparency = 0.2,
		Parent = content,
	})
	Theme.corner(14).Parent = refs.detail
	Theme.stroke(C.Stroke, 3).Parent = refs.detail

	window.onClose = function()
		Menus.closed("Traits")
	end
	Menus.register("Traits", {
		open = function()
			window.open()
			render(true)
		end,
		close = window.close,
	})
	State.onChanged(function()
		render()
	end)
end

return TraitsMenu
