-- Étiquettes au-dessus des persos et ennemis : "LV.67" en jaune (comme la miniature du jeu),
-- nom coloré selon la rareté, étoiles d'évolution et barre de vie.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Rarities = require(Shared.Config.Rarities)
local Auras = require(Shared.Config.Auras)

local NameTags = {}

local player = Players.LocalPlayer

local function makeLabel(parent: Instance, text: string, size: UDim2, position: UDim2, color: Color3, font: Enum.Font): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = size
	label.Position = position
	label.Text = text
	label.TextColor3 = color
	label.TextScaled = true
	label.Font = font
	label.TextStrokeTransparency = 0
	label.TextStrokeColor3 = Color3.fromRGB(20, 15, 20)
	label.Parent = parent
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

		local level = makeLabel(gui, "", UDim2.fromScale(1, 0.42), UDim2.fromScale(0, 0), Color3.fromRGB(255, 230, 40), Enum.Font.LuckiestGuy)
		local name = makeLabel(gui, "", UDim2.fromScale(1, 0.3), UDim2.fromScale(0, 0.42), Color3.new(1, 1, 1), Enum.Font.FredokaOne)
		local bar, fill = nil, nil
		if isEnemy or isFollower then
			bar = Instance.new("Frame")
			bar.Size = UDim2.fromScale(0.86, 0.17)
			bar.Position = UDim2.fromScale(0.07, 0.78)
			bar.BackgroundColor3 = Color3.fromRGB(30, 25, 35)
			bar.BorderSizePixel = 0
			bar.Parent = gui
			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(0.5, 0)
			corner.Parent = bar
			local stroke = Instance.new("UIStroke")
			stroke.Thickness = 2
			stroke.Color = Color3.fromRGB(15, 10, 15)
			stroke.Parent = bar
			fill = Instance.new("Frame")
			fill.Size = UDim2.fromScale(1, 1)
			fill.BackgroundColor3 = isEnemy and Color3.fromRGB(240, 60, 70) or Color3.fromRGB(80, 230, 110)
			fill.BorderSizePixel = 0
			fill.Parent = bar
			local fillCorner = corner:Clone()
			fillCorner.Parent = fill
		end

		local function refresh()
			local lvl = model:GetAttribute("Level") or 1
			local stars = model:GetAttribute("Stars") or 1
			level.Text = "LV." .. lvl .. (isEnemy and "" or ("  " .. string.rep("★", stars)))
			local displayName = model:GetAttribute("DisplayName") or model.Name
			local aura = Auras.get(model:GetAttribute("Aura"))
			name.Text = (aura and ("[" .. aura.name .. "] ") or "") .. displayName
			if isEnemy then
				name.TextColor3 = isBoss and Color3.fromRGB(255, 80, 80) or Color3.fromRGB(255, 200, 200)
			else
				local rarity = Rarities.get(model:GetAttribute("Rarity") or "common")
				name.TextColor3 = rarity.color:Lerp(Color3.new(1, 1, 1), 0.2)
			end
			if fill then
				local hp = model:GetAttribute("HP") or 1
				local maxHp = model:GetAttribute("MaxHP") or 1
				fill.Size = UDim2.fromScale(math.clamp(hp / maxHp, 0, 1), 1)
			end
		end
		refresh()
		for _, attribute in { "Level", "Stars", "HP", "MaxHP", "Aura", "DisplayName" } do
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
