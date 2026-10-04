-- Étiquettes au-dessus des persos et ennemis (même style que l'interface) : niveau « Nv.67 » doré,
-- étoiles d'évolution, nom coloré selon la rareté (arc-en-ciel pour Secret), trait et barre de vie.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Rarities = require(Shared.Config.Rarities)
local Auras = require(Shared.Config.Auras)
local Traits = require(Shared.Config.Traits)

local Theme = require(script.Parent.Parent.UI.Theme)

local NameTags = {}

local player = Players.LocalPlayer
local WHITE = Color3.new(1, 1, 1)

local function makeLabel(parent: Instance, size: UDim2, position: UDim2, color: Color3, face: Font, stroke: number): TextLabel
	local label = Theme.label({
		Size = size,
		Position = position,
		TextColor3 = color,
		FontFace = face,
		StrokeThickness = stroke,
		Parent = parent,
	})
	return label
end

local function attach(model: Instance)
	if not model:IsA("Model") then
		return
	end
	task.spawn(function()
		local root = model:WaitForChild("HumanoidRootPart", 10) :: BasePart?
		if not root or root:FindFirstChild("AnimeTag") then
			return
		end
		local scale = model:GetAttribute("BaseScale") or 1
		local isEnemy = model:GetAttribute("Enemy") == true
		local isBoss = model:GetAttribute("Boss") == true
		local isFollower = model:GetAttribute("Follower") == true
		local isMine = model:GetAttribute("OwnerId") == player.UserId
		local isNpc = model:GetAttribute("NPC") == true

		local gui = Instance.new("BillboardGui")
		gui.Name = "AnimeTag"
		gui.Adornee = root
		local width = isBoss and 16 or 7
		gui.Size = UDim2.new(width, 40, isBoss and 4 or 2.6, 18)
		gui.StudsOffsetWorldSpace = Vector3.new(0, 4.6 * scale + (isBoss and 2 or 0.6), 0)
		gui.LightInfluence = 0
		gui.MaxDistance = isBoss and 220 or 85
		gui.AlwaysOnTop = isBoss
		gui.Parent = root

		local level = makeLabel(gui, UDim2.fromScale(1, 0.4), UDim2.fromScale(0, 0), Color3.fromRGB(255, 230, 40), Theme.Faces.Title, 2.5)
		Theme.gradient({ Color3.fromRGB(255, 250, 190), Color3.fromRGB(255, 196, 40) }, 90).Parent = level
		local name = makeLabel(gui, UDim2.fromScale(1, 0.3), UDim2.fromScale(0, 0.42), WHITE, Theme.Faces.Heavy, 2)
		local nameGradient = Theme.gradient(Theme.RainbowColors, 0)
		nameGradient.Enabled = false
		nameGradient.Parent = name
		local traitLabel = makeLabel(gui, UDim2.fromScale(1, 0.24), UDim2.fromScale(0, -0.24), WHITE, Theme.Faces.Heavy, 1.5)
		local fill = nil
		local fillGradient = nil
		if isEnemy or isFollower then
			local bar = Instance.new("Frame")
			bar.Name = "HealthBar"
			bar.Size = UDim2.fromScale(0.86, 0.16)
			bar.Position = UDim2.fromScale(0.07, 0.78)
			bar.BackgroundColor3 = Color3.fromRGB(16, 14, 20)
			bar.BorderSizePixel = 0
			bar.Parent = gui
			Theme.round().Parent = bar
			Theme.stroke(Color3.fromRGB(8, 6, 10), 2).Parent = bar
			fill = Instance.new("Frame")
			fill.Name = "Fill"
			fill.Size = UDim2.fromScale(1, 1)
			fill.BackgroundColor3 = WHITE
			fill.BorderSizePixel = 0
			fill.Parent = bar
			Theme.round().Parent = fill
			local color = isEnemy and Color3.fromRGB(240, 60, 70) or Color3.fromRGB(80, 230, 110)
			fillGradient = Theme.gradient({ Theme.light(color, 0.35), color, Theme.dark(color, 0.2) }, 90)
			fillGradient.Parent = fill
		end

		local function refresh()
			if isNpc then
				level.Text = "🛒"
				name.Text = model:GetAttribute("DisplayName") or model.Name
				name.TextColor3 = Color3.fromRGB(255, 235, 150)
				return
			end
			local lvl = model:GetAttribute("Level") or 1
			local stars = model:GetAttribute("Stars") or 1
			level.Text = "Nv." .. lvl .. (isEnemy and "" or ("  " .. string.rep("★", stars)))
			local displayName = model:GetAttribute("DisplayName") or model.Name
			local aura = Auras.get(model:GetAttribute("Aura"))
			name.Text = (aura and ("[" .. aura.name .. "] ") or "") .. displayName
			local trait = Traits.get(model:GetAttribute("Trait"))
			traitLabel.Text = trait and ("◆ " .. trait.name) or ""
			traitLabel.TextColor3 = trait and trait.color or WHITE
			nameGradient.Enabled = false
			if isEnemy then
				name.TextColor3 = isBoss and Color3.fromRGB(255, 80, 80) or Color3.fromRGB(255, 200, 200)
			else
				local rollId = model:GetAttribute("RollRarity")
				local rarityId = rollId or model:GetAttribute("Rarity") or "common"
				local info = Theme.rarity(rarityId)
				if info.rainbow then
					name.TextColor3 = WHITE
					nameGradient.Enabled = true
				else
					-- Rareté de la machine (Peu commun compris) : couleurs de Theme ; sinon Config/Rarities.
					local known = Rarities.List[rarityId]
					local color = (not rollId and known and known.color) or info.color
					name.TextColor3 = color:Lerp(WHITE, 0.2)
				end
			end
			if fill then
				local hp = model:GetAttribute("HP") or 1
				local maxHp = model:GetAttribute("MaxHP") or 1
				local ratio = math.clamp(hp / maxHp, 0, 1)
				fill.Size = UDim2.fromScale(ratio, 1)
				fill.Visible = ratio > 0.01
				if fillGradient and not isEnemy then
					local color = ratio > 0.35 and Color3.fromRGB(80, 230, 110) or Color3.fromRGB(240, 70, 70)
					fillGradient.Color = Theme.sequence({ Theme.light(color, 0.35), color, Theme.dark(color, 0.2) })
				end
			end
		end
		refresh()
		for _, attribute in { "Level", "Stars", "HP", "MaxHP", "Aura", "DisplayName", "Trait", "RollRarity" } do
			model:GetAttributeChangedSignal(attribute):Connect(refresh)
		end
		if isFollower and not isMine then
			gui.MaxDistance = 50
		end
	end)
end

function NameTags.init()
	for _, model in CollectionService:GetTagged("AnimeRig") do
		attach(model)
	end
	CollectionService:GetInstanceAddedSignal("AnimeRig"):Connect(attach)
end

return NameTags
