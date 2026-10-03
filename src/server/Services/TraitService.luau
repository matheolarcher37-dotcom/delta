-- Traits : relance du trait d'un perso à l'Autel des Traits (au centre) avec un Cristal de Trait.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Economy = require(Shared.Config.Economy)
local Traits = require(Shared.Config.Traits)
local Formulas = require(Shared.Modules.Formulas)
local Remotes = require(Shared.Modules.Remotes)

local TraitService = {}

local OpenMenu = Remotes.event("OpenMenu")
local Announce = Remotes.event("Announce")
local rng = Random.new()

function TraitService:Init(services)
	self.services = services
end

function TraitService:Reroll(player: Player, uid: any)
	local DataService = self.services.DataService
	local data = DataService:Get(player)
	if not data or type(uid) ~= "string" then
		return false, "Erreur."
	end
	local entry = data.characters[uid]
	if not entry then
		return false, "Perso introuvable."
	end
	if (data.traitCrystals or 0) < 1 then
		return false, "Il te faut un Cristal de Trait 💎 (boss, ennemis du cœur de la zone, ou achat à l'autel)."
	end
	if self.services.TradeService:IsInTrade(player) then
		return false, "Impossible pendant un échange."
	end
	data.traitCrystals -= 1
	local traitId = Traits.roll(rng)
	entry.trait = traitId
	DataService:Sync(player)
	self.services.CharacterService:Refresh(player)
	self.services.TeamService:RefreshTeam(player)
	local trait = Traits.get(traitId)
	if trait and trait.tier >= 4 then
		local desc = Formulas.describe(entry)
		Announce:FireAllClients(
			"💎 TRAIT " .. string.upper(trait.name) .. " 💎",
			player.DisplayName .. " l'a obtenu sur " .. (desc and desc.name or "un perso") .. " !",
			trait.color
		)
	end
	return true, "Nouveau trait : " .. (trait and trait.name or "?"), traitId
end

function TraitService:BuyCrystal(player: Player)
	local DataService = self.services.DataService
	local data = DataService:Get(player)
	if not data then
		return false, "Erreur."
	end
	if not DataService:SpendCoins(player, Economy.TraitCrystalPrice) then
		return false, "Il te manque 💰 " .. Formulas.formatNumber(Economy.TraitCrystalPrice - data.coins)
	end
	data.traitCrystals = (data.traitCrystals or 0) + 1
	DataService:Sync(player)
	return true, "+1 Cristal de Trait 💎"
end

function TraitService:Start()
	Remotes.func("RerollTrait").OnServerInvoke = function(player, uid)
		return self:Reroll(player, uid)
	end
	Remotes.func("BuyTraitCrystal").OnServerInvoke = function(player)
		return self:BuyCrystal(player)
	end
	local function hook(altar: Instance)
		local prompt = altar:FindFirstChildWhichIsA("ProximityPrompt", true)
		if prompt then
			prompt.Triggered:Connect(function(player)
				OpenMenu:FireClient(player, "Traits")
			end)
		end
	end
	for _, altar in CollectionService:GetTagged("TraitAltar") do
		hook(altar)
	end
end

return TraitService
