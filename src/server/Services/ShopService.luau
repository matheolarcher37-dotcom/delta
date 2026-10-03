-- Machine à Reliques : vend les reliques de l'univers actuel. Stock renouvelé toutes les 5 minutes
-- (identique sur tous les serveurs, comme les boutiques de "Grow a ...").

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Economy = require(Shared.Config.Economy)
local Universes = require(Shared.Config.Universes)
local Formulas = require(Shared.Modules.Formulas)
local Remotes = require(Shared.Modules.Remotes)

local ShopService = {}

local Notify = Remotes.event("Notify")

function ShopService:Init(services)
	self.services = services
end

local function currentWindow(): number
	return math.floor(os.time() / Economy.ShopRestock)
end

-- Stock de la fenêtre actuelle pour une relique (déterministe).
function ShopService:StockFor(relic, window: number): number
	local tier = Economy.RelicTiers[relic.tier]
	if tier.appearChance then
		local rng = Random.new(window * 7919 + relic.tier * 31 + #relic.id)
		if rng:NextNumber() > tier.appearChance then
			return 0
		end
	end
	return tier.stock
end

local function resetWindowIfNeeded(data)
	local window = currentWindow()
	if data.shop.window ~= window then
		data.shop.window = window
		data.shop.bought = {}
	end
	return window
end

function ShopService:GetShop(player: Player)
	local data = self.services.DataService:Get(player)
	local universe = self.services.UniverseService:GetCurrent()
	if not data or not universe then
		return nil
	end
	local window = resetWindowIfNeeded(data)
	local items = {}
	for _, relic in universe.relics do
		local stock = self:StockFor(relic, window)
		local bought = data.shop.bought[relic.id] or 0
		table.insert(items, {
			relicId = relic.id,
			price = Economy.RelicTiers[relic.tier].price,
			stock = stock,
			remaining = math.max(0, stock - bought),
		})
	end
	return {
		universeId = universe.id,
		restockAt = (window + 1) * Economy.ShopRestock,
		items = items,
	}
end

function ShopService:Buy(player: Player, relicId: any)
	local DataService = self.services.DataService
	local data = DataService:Get(player)
	local universe = self.services.UniverseService:GetCurrent()
	if not data or type(relicId) ~= "string" then
		return false, "Erreur."
	end
	local relic = Universes.getRelic(relicId)
	if not relic or relic.universe ~= universe.id then
		return false, "Cette relique n'est plus en vente (l'univers a changé) !"
	end
	local plot = self.services.PlotService:GetPlot(player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if plot and root and (root.Position - (plot.cf * CFrame.new(-16, 0, 36)).Position).Magnitude > 40 then
		return false, "Approche-toi de ta Machine à Reliques."
	end
	local window = resetWindowIfNeeded(data)
	local stock = self:StockFor(relic, window)
	local bought = data.shop.bought[relic.id] or 0
	if bought >= stock then
		return false, "Rupture de stock ! Réapprovisionnement bientôt."
	end
	local price = Economy.RelicTiers[relic.tier].price
	if data.coins < price then
		return false, "Il te manque 💰 " .. Formulas.formatNumber(price - data.coins)
	end
	DataService:SpendCoins(player, price)
	data.shop.bought[relic.id] = bought + 1
	DataService:AddRelic(player, relic.id, 1)
	return true, "Tu as acheté : " .. relic.name .. " ! Pose-la sur un autel."
end

function ShopService:Start()
	Remotes.func("GetShop").OnServerInvoke = function(player)
		return self:GetShop(player)
	end
	Remotes.func("BuyRelic").OnServerInvoke = function(player, relicId)
		local ok, message = self:Buy(player, relicId)
		if not ok and message then
			Notify:FireClient(player, message, "error")
		end
		return ok, message, self:GetShop(player)
	end

	-- Annonce du réapprovisionnement.
	task.spawn(function()
		local lastWindow = currentWindow()
		while true do
			task.wait(1)
			local window = currentWindow()
			local state = ReplicatedStorage:FindFirstChild("GameState")
			if state then
				state:SetAttribute("ShopRestockAt", (window + 1) * Economy.ShopRestock)
			end
			if window ~= lastWindow then
				lastWindow = window
				local universe = self.services.UniverseService:GetCurrent()
				local legendary = universe.relics[#universe.relics]
				local hasLegendary = self:StockFor(legendary, window) > 0
				Notify:FireAllClients("🛒 La Machine à Reliques est réapprovisionnée !" .. (hasLegendary and (" (" .. legendary.name .. " en stock !)") or ""), "info")
			end
		end
	end)
end

return ShopService
