-- Compatibilité manette / console (Xbox, PlayStation) et télé :
--   • détecte le mode de jeu (manette, clavier/souris, tactile) et affiche les indications A/B/X/Y,
--   • raccourcis : B = fermer, LB/RB = onglets, X = ROULER, croix haut = menu principal,
--   • sélection automatique du premier bouton d'un menu (GuiService.SelectedObject),
--   • interface plus grande sur télé (IsTenFootInterface) + zone sûre.

local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local UserInputService = game:GetService("UserInputService")

local Theme = require(script.Parent.Theme)
local Menus = require(script.Parent.Menus)

local Console = {}

local new = Theme.new

local gamepad = false
local touch = false
local tenFoot = false
local hints: { [GuiObject]: boolean } = {}
local modeListeners: { (boolean) -> () } = {}

-- Couleurs des boutons de manette (style Xbox, lisibles aussi pour PlayStation).
local BUTTONS = {
	A = { text = "A", color = Color3.fromRGB(96, 200, 60) },
	B = { text = "B", color = Color3.fromRGB(230, 60, 60) },
	X = { text = "X", color = Color3.fromRGB(50, 130, 240) },
	Y = { text = "Y", color = Color3.fromRGB(245, 190, 30) },
	LB = { text = "LB", color = Color3.fromRGB(70, 70, 86), wide = true },
	RB = { text = "RB", color = Color3.fromRGB(70, 70, 86), wide = true },
	LT = { text = "LT", color = Color3.fromRGB(70, 70, 86), wide = true },
	RT = { text = "RT", color = Color3.fromRGB(70, 70, 86), wide = true },
	Up = { text = "▲", color = Color3.fromRGB(70, 70, 86) },
	Down = { text = "▼", color = Color3.fromRGB(70, 70, 86) },
	Menu = { text = "≡", color = Color3.fromRGB(70, 70, 86) },
	R = { text = "R", color = Color3.fromRGB(70, 70, 86) },
}

-- Manettes 1 à 4 (comparées par nom : plus robuste que l'EnumItem lui-même).
local GAMEPAD_TYPES = { Gamepad1 = true, Gamepad2 = true, Gamepad3 = true, Gamepad4 = true }

function Console.isGamepad(): boolean
	return gamepad
end

function Console.isTouch(): boolean
	return touch
end

function Console.isTenFoot(): boolean
	return tenFoot
end

function Console.onModeChanged(callback: (boolean) -> ())
	table.insert(modeListeners, callback)
end

local function refreshHints()
	for hint in hints do
		if hint.Parent then
			hint.Visible = gamepad
		else
			hints[hint] = nil
		end
	end
end

local notifiedTouch = false

-- Prévient les abonnés quand le mode manette OU tactile change.
local function notifyMode()
	for _, callback in modeListeners do
		task.spawn(callback, gamepad)
	end
end

local function setGamepad(value: boolean)
	if gamepad == value then
		if touch ~= notifiedTouch then
			notifiedTouch = touch
			notifyMode()
		end
		return
	end
	gamepad = value
	notifiedTouch = touch
	refreshHints()
	notifyMode()
	if value then
		Console.focusCurrent()
	else
		pcall(function()
			GuiService.SelectedObject = nil
		end)
	end
end

-- Pastille « bouton de manette » (visible seulement quand on joue à la manette).
function Console.hint(parent: Instance, key: string, props: { [string]: any }?): Frame
	local info = BUTTONS[key] or BUTTONS.A
	local badge = new("Frame", {
		Name = "PadHint_" .. key,
		Size = UDim2.fromOffset(info.wide and 38 or 28, 28),
		BackgroundColor3 = info.color,
		Visible = gamepad,
		ZIndex = 20,
		Parent = parent,
	})
	if props then
		for k, v in props do
			(badge :: any)[k] = v
		end
	end
	Theme.corner(info.wide and 8 or 14).Parent = badge
	Theme.stroke(Color3.new(1, 1, 1), 2).Parent = badge
	Theme.gradient({ Theme.light(info.color, 0.25), Theme.dark(info.color, 0.25) }, 90).Parent = badge
	Theme.label({
		Text = info.text,
		Size = UDim2.new(1, -6, 1, -6),
		Position = UDim2.fromOffset(3, 3),
		FontFace = Theme.Faces.Heavy,
		ZIndex = badge.ZIndex + 1,
		StrokeThickness = 1.5,
		Parent = badge,
	})
	hints[badge] = true
	return badge
end

-- Barre d'indications en bas d'une fenêtre : { {"A", "Choisir"}, {"B", "Retour"} }.
function Console.hintBar(parent: Instance, items: { { string } }, props: { [string]: any }?): Frame
	local bar = new("Frame", {
		Name = "PadHints",
		Size = UDim2.new(1, 0, 0, 30),
		BackgroundTransparency = 1,
		Visible = gamepad,
		ZIndex = 20,
		Parent = parent,
	})
	if props then
		for k, v in props do
			(bar :: any)[k] = v
		end
	end
	local layout = Theme.list(Enum.FillDirection.Horizontal, 14, Enum.HorizontalAlignment.Center)
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Parent = bar
	for i, item in items do
		local group = new("Frame", {
			Size = UDim2.fromOffset(150, 30),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundTransparency = 1,
			LayoutOrder = i,
			ZIndex = 20,
			Parent = bar,
		})
		local inner = Theme.list(Enum.FillDirection.Horizontal, 6, Enum.HorizontalAlignment.Left)
		inner.VerticalAlignment = Enum.VerticalAlignment.Center
		inner.Parent = group
		local badge = Console.hint(group, item[1])
		badge.Visible = true
		hints[badge] = nil
		badge.LayoutOrder = 1
		Theme.label({
			Text = item[2],
			Size = UDim2.fromOffset(110, 22),
			AutomaticSize = Enum.AutomaticSize.X,
			TextScaled = false,
			TextSize = 18,
			FontFace = Theme.Faces.Bold,
			TextXAlignment = Enum.TextXAlignment.Left,
			LayoutOrder = 2,
			ZIndex = 20,
			Parent = group,
		})
	end
	hints[bar] = true
	return bar
end

-- Sélectionne le premier bouton du menu ouvert (à la manette uniquement).
function Console.focusCurrent()
	if not gamepad then
		return
	end
	local menu = Menus.get(Menus.current())
	local target = menu and menu.selection and menu.selection()
	pcall(function()
		GuiService.SelectedObject = target
	end)
end

-- Sélectionne un bouton précis (si la manette est utilisée).
function Console.select(object: GuiObject?)
	if gamepad and object then
		pcall(function()
			GuiService.SelectedObject = object
		end)
	end
end

local function detectMode(inputType: Enum.UserInputType)
	if GAMEPAD_TYPES[inputType.Name] then
		touch = false
		setGamepad(true)
	elseif inputType == Enum.UserInputType.Touch then
		touch = true
		setGamepad(false)
	elseif inputType == Enum.UserInputType.Keyboard or inputType == Enum.UserInputType.MouseButton1 or inputType == Enum.UserInputType.MouseMovement then
		touch = false
		setGamepad(false)
	end
end

------------------------------------------------------------------------
-- Raccourcis manette
------------------------------------------------------------------------

local actions: { [string]: () -> () } = {}

-- Fonctions branchées par les autres modules (HUD : rouler, menu principal...).
function Console.setAction(name: string, callback: () -> ())
	actions[name] = callback
end

local PRIORITY = Enum.ContextActionPriority.High.Value + 10

-- Invites de proximité affichées (Collecter, Acheter, Remplacer l'unité... utilisent aussi X) :
-- tant qu'une invite est visible, X lui revient au lieu du raccourci ROULER.
local shownPrompts: { [Instance]: boolean } = {}
pcall(function()
	ProximityPromptService.PromptShown:Connect(function(prompt)
		shownPrompts[prompt] = true
	end)
	ProximityPromptService.PromptHidden:Connect(function(prompt)
		shownPrompts[prompt] = nil
	end)
end)

local function promptVisible(): boolean
	for prompt in shownPrompts do
		if prompt.Parent and prompt.Enabled then
			return true
		end
		shownPrompts[prompt] = nil
	end
	return false
end

local function bindMenuKeys(open: boolean)
	pcall(function()
		if open then
			ContextActionService:BindActionAtPriority("AT_Fermer", function(_, state)
				if state ~= Enum.UserInputState.Begin then
					return Enum.ContextActionResult.Sink
				end
				Menus.close()
				return Enum.ContextActionResult.Sink
			end, false, PRIORITY, Enum.KeyCode.ButtonB)
			ContextActionService:BindActionAtPriority("AT_Onglets", function(_, state, input)
				if state ~= Enum.UserInputState.Begin then
					return Enum.ContextActionResult.Sink
				end
				local menu = Menus.get(Menus.current())
				if menu and menu.tab then
					menu.tab(input.KeyCode == Enum.KeyCode.ButtonL1 and -1 or 1)
				end
				return Enum.ContextActionResult.Sink
			end, false, PRIORITY, Enum.KeyCode.ButtonL1, Enum.KeyCode.ButtonR1)
		else
			ContextActionService:UnbindAction("AT_Fermer")
			ContextActionService:UnbindAction("AT_Onglets")
		end
	end)
end

local function bindWorldKeys()
	pcall(function()
		ContextActionService:BindActionAtPriority("AT_Rouler", function(_, state)
			if state ~= Enum.UserInputState.Begin or Menus.current() ~= nil or promptVisible() then
				return Enum.ContextActionResult.Pass
			end
			if actions.roll then
				actions.roll()
				return Enum.ContextActionResult.Sink
			end
			return Enum.ContextActionResult.Pass
		end, false, PRIORITY, Enum.KeyCode.ButtonX)
		ContextActionService:BindActionAtPriority("AT_Menu", function(_, state)
			if state ~= Enum.UserInputState.Begin then
				return Enum.ContextActionResult.Pass
			end
			-- Pendant la navigation dans l'interface, la croix sert à se déplacer.
			if GuiService.SelectedObject ~= nil and Menus.current() == nil then
				return Enum.ContextActionResult.Pass
			end
			if Menus.current() == nil and actions.mainMenu then
				actions.mainMenu()
				return Enum.ContextActionResult.Sink
			end
			return Enum.ContextActionResult.Pass
		end, false, PRIORITY, Enum.KeyCode.DPadUp)
	end)
end

------------------------------------------------------------------------

function Console.init(gui: ScreenGui)
	pcall(function()
		tenFoot = GuiService:IsTenFootInterface()
	end)
	pcall(function()
		-- Zone sûre : rien sous l'encoche des téléphones ni hors de l'écran des télés.
		gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	end)
	pcall(function()
		GuiService.AutoSelectGuiEnabled = true
		GuiService.GuiNavigationEnabled = true
	end)
	pcall(function()
		-- Téléphone/tablette : tactile dès le départ, même avant le premier toucher.
		touch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
		detectMode(UserInputService:GetLastInputType())
	end)
	pcall(function()
		if UserInputService.GamepadEnabled and not UserInputService.KeyboardEnabled and not UserInputService.TouchEnabled then
			setGamepad(true)
		end
	end)
	pcall(function()
		UserInputService.LastInputTypeChanged:Connect(detectMode)
	end)
	Menus.onChanged(function(name)
		bindMenuKeys(name ~= nil)
		if name then
			task.defer(Console.focusCurrent)
		else
			pcall(function()
				local selected = GuiService.SelectedObject
				if selected and not selected:IsDescendantOf(gui) then
					return
				end
				GuiService.SelectedObject = nil
			end)
		end
	end)
	bindWorldKeys()
end

return Console
