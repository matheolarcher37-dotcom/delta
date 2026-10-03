-- Gestionnaire de menus : un seul grand menu ouvert à la fois.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Modules.Remotes)

local Menus = {}

local registry = {}
local current: string? = nil

export type Menu = {
	open: (any?) -> (),
	close: () -> (),
	isOpen: (() -> boolean)?,
}

function Menus.register(name: string, menu: Menu)
	registry[name] = menu
end

function Menus.open(name: string, arg: any?)
	local menu = registry[name]
	if not menu then
		return
	end
	if current and current ~= name and registry[current] then
		registry[current].close()
	end
	current = name
	menu.open(arg)
end

function Menus.close(name: string?)
	local target = name or current
	if target and registry[target] then
		registry[target].close()
	end
	if target == current then
		current = nil
	end
end

function Menus.toggle(name: string, arg: any?)
	if current == name then
		Menus.close(name)
	else
		Menus.open(name, arg)
	end
end

function Menus.closed(name: string)
	if current == name then
		current = nil
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
