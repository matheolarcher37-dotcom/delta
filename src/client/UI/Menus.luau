-- Gestionnaire de menus : un seul grand menu ouvert à la fois.
-- Chaque menu peut aussi fournir `tab(direction)` (LB/RB à la manette) et `selection()`
-- (le bouton sélectionné en premier à la manette).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Modules.Remotes)

local Menus = {}

local registry = {}
local current: string? = nil
local listeners: { (string?) -> () } = {}

export type Menu = {
	open: (any?) -> (),
	close: () -> (),
	isOpen: (() -> boolean)?,
	tab: ((number) -> ())?,
	selection: (() -> GuiObject?)?,
}

local function notify()
	for _, callback in listeners do
		task.spawn(callback, current)
	end
end

-- Appelé à chaque ouverture / fermeture (nom du menu ouvert, ou nil).
function Menus.onChanged(callback: (string?) -> ())
	table.insert(listeners, callback)
end

function Menus.register(name: string, menu: Menu)
	registry[name] = menu
end

function Menus.get(name: string?): Menu?
	return name and registry[name] or nil
end

function Menus.exists(name: string): boolean
	return registry[name] ~= nil
end

function Menus.open(name: string, arg: any?)
	local menu = registry[name]
	if not menu then
		return
	end
	if current and current ~= name and registry[current] then
		local previous = current
		current = nil
		registry[previous].close()
	end
	current = name
	menu.open(arg)
	notify()
end

function Menus.close(name: string?)
	local target = name or current
	if target and registry[target] then
		registry[target].close()
	end
	if target == current then
		current = nil
		notify()
	end
end

function Menus.toggle(name: string, arg: any?)
	if current == name then
		Menus.close(name)
	else
		Menus.open(name, arg)
	end
end

-- Un menu prévient qu'il s'est fermé tout seul (bouton ✕).
function Menus.closed(name: string)
	if current == name then
		current = nil
		notify()
	end
end

function Menus.current(): string?
	return current
end

function Menus.init()
	Remotes.event("OpenMenu").OnClientEvent:Connect(function(name, arg)
		Menus.open(name, arg)
	end)
end

return Menus
