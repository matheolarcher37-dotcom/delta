-- Emplacements d'unités de la base (comme dans les jeux de tirage) : dalles hexagonales jaunes
-- bordées de sombre, l'unité se tient dessus avec son nom + étoiles + rareté au-dessus.
-- Les cases pas encore débloquées montrent une silhouette « ??? ».
-- Invite « Remplacer l'unité » (manette : X) pour choisir quelle unité se tient sur la case.

local Build = require(script.Parent.Build)
local Kit = require(script.Parent.TycoonKit)

local Slots = {}

local rgb = Color3.fromRGB

local YELLOW = rgb(252, 208, 60)
local YELLOW_DARK = rgb(226, 170, 34)
local RIM = rgb(42, 38, 34)
local LOCKED = rgb(112, 108, 100)
local LOCKED_DARK = rgb(90, 86, 80)

-- Construit une case ; `cf` = centre au sol. Renvoie les références de la case.
function Slots.buildSlot(parent: Instance, index: number, cf: CFrame, radius: number, height: number)
	local model = Build.model(parent, "Case" .. index)
	model:SetAttribute("Slot", index)
	Kit.hexTile(model, "Bord", cf * CFrame.new(0, height - 0.1, 0), radius + 0.45, height - 0.1, RIM, { Material = Enum.Material.Slate })
	local top = Kit.hexTile(model, "Dalle", cf * CFrame.new(0, height, 0), radius, 0.3, YELLOW, { Material = Enum.Material.SmoothPlastic })
	local inner =
		Kit.hexTile(model, "Motif", cf * CFrame.new(0, height + 0.02, 0), radius * 0.72, 0.05, YELLOW_DARK, { Material = Enum.Material.SmoothPlastic, CanCollide = false })
	-- Repère invisible au centre : porte l'invite et les étiquettes.
	local anchor = Build.deco(model, "Repere", Vector3.new(1, 0.2, 1), cf * CFrame.new(0, height + 0.1, 0), YELLOW, { Transparency = 1 })
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "Prompt"
	prompt.ObjectText = "Emplacement d'unité #" .. index
	prompt.ActionText = "Remplacer l'unité"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 8
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.Parent = anchor
	local silhouette = Kit.silhouetteTag(anchor, 3.2, "🔒 Verrouillé")
	silhouette.Enabled = false
	local free = Instance.new("BillboardGui")
	free.Name = "Libre"
	free.Adornee = anchor
	free.Size = UDim2.new(5, 30, 1.2, 10)
	free.StudsOffsetWorldSpace = Vector3.new(0, 1.4, 0)
	free.LightInfluence = 0
	free.MaxDistance = 60
	free.Enabled = false
	free.Parent = anchor
	Kit.text(free, "Texte", "Emplacement libre", UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), rgb(255, 240, 170), Enum.Font.GothamBold)
	return {
		index = index,
		model = model,
		anchor = anchor,
		prompt = prompt,
		tiles = top,
		inner = inner,
		silhouette = silhouette,
		free = free,
		cf = cf * CFrame.new(0, height, 0),
	}
end

-- Retrouve les références d'une case déjà construite.
function Slots.bind(model: Model, cf: CFrame, height: number)
	local anchor = model:FindFirstChild("Repere")
	local tiles, inner = {}, {}
	for _, child in model:GetChildren() do
		if child.Name == "Dalle" then
			table.insert(tiles, child)
		elseif child.Name == "Motif" then
			table.insert(inner, child)
		end
	end
	return {
		index = model:GetAttribute("Slot"),
		model = model,
		anchor = anchor,
		prompt = anchor and anchor:FindFirstChild("Prompt"),
		tiles = tiles,
		inner = inner,
		silhouette = anchor and anchor:FindFirstChild("Silhouette"),
		free = anchor and anchor:FindFirstChild("Libre"),
		cf = cf * CFrame.new(0, height, 0),
	}
end

-- state = "locked" | "free" | "occupied" ; caption = texte sous la silhouette (case verrouillée).
function Slots.setState(ref, state: string, caption: string?)
	if ref.state == state and ref.caption == caption then
		return
	end
	ref.state = state
	ref.caption = caption
	local locked = state == "locked"
	for _, part in ref.tiles do
		part.Color = locked and LOCKED or YELLOW
	end
	for _, part in ref.inner do
		part.Color = locked and LOCKED_DARK or YELLOW_DARK
	end
	if ref.silhouette then
		ref.silhouette.Enabled = locked
		local legend = ref.silhouette:FindFirstChild("Legende")
		if legend and caption then
			legend.Text = caption
		end
	end
	if ref.free then
		ref.free.Enabled = state == "free"
	end
	if ref.prompt then
		ref.prompt.Enabled = not locked
		ref.prompt.ActionText = state == "occupied" and "Remplacer l'unité" or "Placer une unité"
	end
end

return Slots
