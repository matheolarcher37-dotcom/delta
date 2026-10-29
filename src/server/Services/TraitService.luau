-- Traits : relance du trait d'un perso à l'Autel des Traits (au centre).
-- Chaque relance coûte 1 GEMME DE TRAIT (= Cristal de Trait, champ traitCrystals). Les gemmes se
-- gagnent en tuant des ennemis et des boss, au punching-ball de la zone anti-AFK et en défis
-- (voir QuestService). Elles ne s'achètent PAS avec des pièces : on les gagne en jouant.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Traits = require(Shared.Config.Traits)
local Formulas = require(Shared.Modules.Formulas)
local Remotes = require(Shared.Modules.Remotes)

local TraitService = {}

local OpenMenu = Remotes.event("OpenMenu")
local Announce = Remotes.event("Announce")
local TraitRolled = Remotes.event("TraitRolled")
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
		return false, "Il te faut une gemme de trait 💎 : tue des ennemis, tape le punching-ball de la zone AFK ou réussis des défis !"
	end
	if self.services.TradeService:IsInTrade(player) then
		return false, "Impossible pendant un échange."
	end
	data.traitCrystals -= 1
	local previous = entry.trait
	local traitId = Traits.roll(rng)
	entry.trait = traitId
	DataService:Sync(player)
	-- Le serveur tire le trait ; le client ne fait que l'afficher (rouleau, révélation, cinématique).
	TraitRolled:FireClient(player, { uid = uid, traitId = traitId, previous = previous, crystals = data.traitCrystals })
	if self.services.QuestService then
		self.services.QuestService:OnTraitReroll(player) -- défis « Relance N traits »
	end
	self.services.CharacterService:Refresh(player)
	self.services.TeamService:RefreshTeam(player)
	local trait = Traits.get(traitId)
	if trait and trait.tier >= 4 then
		local desc = Formulas.describe(entry)
		Announce:FireAllClients(
			"💎 TRAIT " .. Formulas.upper(trait.name) .. " 💎",
			player.DisplayName .. " l'a obtenu sur " .. (desc and desc.name or "un perso") .. " !",
			trait.color
		)
	end
	return true, "Nouveau trait : " .. (trait and trait.name or "?"), traitId
end

function TraitService:Start()
	Remotes.func("RerollTrait").OnServerInvoke = function(player, uid)
		return self:Reroll(player, uid)
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
