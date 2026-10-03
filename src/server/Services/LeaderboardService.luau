-- leaderstats (Tab) + panneau "Les plus puissants" (classement global si DataStore disponible).

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Formulas = require(Shared.Modules.Formulas)

local LeaderboardService = {}

local orderedStore = nil
local globalTop = {}

function LeaderboardService:Init(services)
	self.services = services
	local ok, store = pcall(function()
		return DataStoreService:GetOrderedDataStore("AnimeTycoon_Power_v1")
	end)
	if ok then
		orderedStore = store
	end
end

-- Puissance totale = somme des puissances de l'équipe.
function LeaderboardService:TeamPower(player: Player): number
	local data = self.services.DataService:Get(player)
	if not data then
		return 0
	end
	local total = 0
	for _, uid in data.team do
		local entry = data.characters[uid]
		if entry then
			total += Formulas.power(entry)
		end
	end
	return total
end

function LeaderboardService:Start()
	self.services.DataService:OnPlayerLoaded(function(player)
		local stats = Instance.new("Folder")
		stats.Name = "leaderstats"
		local coins = Instance.new("IntValue")
		coins.Name = "💰 Pièces"
		coins.Parent = stats
		local power = Instance.new("IntValue")
		power.Name = "⚔️ Puissance"
		power.Parent = stats
		stats.Parent = player
	end)

	task.spawn(function()
		while true do
			task.wait(2)
			for _, player in Players:GetPlayers() do
				local data = self.services.DataService:Get(player)
				local stats = player:FindFirstChild("leaderstats")
				if data and stats then
					(stats:FindFirstChild("💰 Pièces") :: IntValue).Value = math.floor(math.min(data.coins, 2 ^ 53))
					local power = self:TeamPower(player);
					(stats:FindFirstChild("⚔️ Puissance") :: IntValue).Value = power
					player:SetAttribute("TeamPower", power)
				end
			end
			self:_render()
		end
	end)

	-- Classement global (toutes les 2 minutes).
	task.spawn(function()
		while true do
			task.wait(15)
			if orderedStore then
				for _, player in Players:GetPlayers() do
					local power = self:TeamPower(player)
					if power > 0 then
						pcall(function()
							orderedStore:SetAsync(tostring(player.UserId), power)
						end)
					end
				end
				local ok, pages = pcall(function()
					return orderedStore:GetSortedAsync(false, 10)
				end)
				if ok and pages then
					local list = {}
					for _, item in pages:GetCurrentPage() do
						local name = "Joueur"
						local userId = tonumber(item.key)
						if userId then
							local okName, result = pcall(function()
								return Players:GetNameFromUserIdAsync(userId)
							end)
							if okName then
								name = result
							end
						end
						table.insert(list, { name = name, value = item.value })
					end
					globalTop = list
				end
			end
			task.wait(105)
		end
	end)
end

function LeaderboardService:_render()
	local board = Workspace.World.Boards:FindFirstChild("Leaderboard")
	local gui = board and board.Panel:FindFirstChild("Display")
	if not gui then
		return
	end
	local list = globalTop
	if #list == 0 then
		list = {}
		for _, player in Players:GetPlayers() do
			table.insert(list, { name = player.DisplayName, value = self:TeamPower(player) })
		end
		table.sort(list, function(a, b)
			return a.value > b.value
		end)
	end
	for i = 1, 10 do
		local label = gui:FindFirstChild("Row" .. i) :: TextLabel?
		if not label then
			local newLabel = Instance.new("TextLabel")
			newLabel.Name = "Row" .. i
			newLabel.BackgroundTransparency = 1
			newLabel.Size = UDim2.fromScale(0.9, 0.088)
			newLabel.Position = UDim2.fromScale(0.05, 0.04 + (i - 1) * 0.093)
			newLabel.TextScaled = true
			newLabel.Font = Enum.Font.GothamBold
			newLabel.TextXAlignment = Enum.TextXAlignment.Left
			newLabel.TextStrokeTransparency = 0.3
			newLabel.Parent = gui
			label = newLabel
		end
		local row = list[i]
		local colors = { Color3.fromRGB(255, 215, 60), Color3.fromRGB(220, 225, 235), Color3.fromRGB(230, 150, 90) }
		if label then
			label.TextColor3 = colors[i] or Color3.fromRGB(255, 255, 255)
			label.Text = row and string.format("#%d  %s  —  ⚔️ %s", i, row.name, Formulas.formatNumber(row.value)) or ""
		end
	end
end

return LeaderboardService
