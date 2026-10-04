--!nocheck
-- Profil des pièces des décors (outil de développement) : ANIME_PLACE=... lune run tests/_profil_carte.luau [univers]
local process = require("@lune/process")
local Harness = require("./harness")
local game = Harness.game
local requireModule = Harness.require
local find = Harness.find
local countParts = Harness.countParts
local Shared = find("ReplicatedStorage.Shared")
local Universes = requireModule(Shared.Config.Universes)
local Workspace = game:GetService("Workspace")
local Server = find("ServerScriptService.Server")
local WorldBuilder = requireModule(Server.World.WorldBuilder)
WorldBuilder.build()
local UniverseDecor = requireModule(Server.World.UniverseDecor)
local only = process.args[1]
for _, universe in Universes.List do
	if not only or universe.id == only then
		local decor = UniverseDecor.build(universe)
		print(universe.name, countParts(decor))
		local function walk(inst, depth)
			for _, child in inst:GetChildren() do
				if child:IsA("Folder") or (child:IsA("Model") and depth < 1) then
					print(string.rep("  ", depth + 1) .. child.Name, countParts(child))
					walk(child, depth + 1)
				end
			end
		end
		walk(decor, 0)
		local bySlot = {}
		for _, item in decor:GetDescendants() do
			if item:IsA("Model") and item:GetAttribute("Slot") then
				local s = item:GetAttribute("Slot")
				bySlot[s] = bySlot[s] or { 0, 0 }
				bySlot[s][1] += 1
				bySlot[s][2] += countParts(item)
			end
		end
		local list = {}
		for k, v in bySlot do
			table.insert(list, { k, v[1], v[2] })
		end
		table.sort(list, function(a, b)
			return a[3] > b[3]
		end)
		for _, e in list do
			print(string.format("    slot %-24s x%-4d %6d pièces (%d/u)", e[1], e[2], e[3], e[3] // e[2]))
		end
		decor:Destroy()
	end
end
