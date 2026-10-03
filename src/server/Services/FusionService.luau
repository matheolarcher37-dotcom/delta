-- LA PÉPITE : Fusion Crossover.
-- Au Portail Crossover, on fusionne deux persos de DEUX UNIVERS DIFFÉRENTS (Épique+ et ★★ minimum)
-- pour créer un perso unique "Crossover" (ex : Ninja Renard + Le Plus Fort = "Renard de l'Infini").
-- Comme les univers tournent, ça pousse à collectionner, revenir à chaque rotation et échanger.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Economy = require(Shared.Config.Economy)
local Universes = require(Shared.Config.Universes)
local Rarities = require(Shared.Config.Rarities)
local Auras = require(Shared.Config.Auras)
local Traits = require(Shared.Config.Traits)
local Layout = require(Shared.Config.Layout)
local Formulas = require(Shared.Modules.Formulas)
local Remotes = require(Shared.Modules.Remotes)

local FusionService = {}

local OpenMenu = Remotes.event("OpenMenu")
local HatchReveal = Remotes.event("HatchReveal")
local Announce = Remotes.event("Announce")
local Notify = Remotes.event("Notify")

function FusionService:Init(services)
	self.services = services
end

function FusionService:Validate(data, uidA: string, uidB: string)
	if uidA == uidB then
		return false, "Choisis deux persos différents."
	end
	local a, b = data.characters[uidA], data.characters[uidB]
	if not a or not b then
		return false, "Perso introuvable."
	end
	if a.fusion or b.fusion then
		return false, "Un Crossover ne peut pas être fusionné à nouveau."
	end
	if a.locked or b.locked then
		return false, "Déverrouille d'abord ces persos 🔒"
	end
	local da, db = Formulas.describe(a), Formulas.describe(b)
	if not da or not db then
		return false, "Perso invalide."
	end
	if da.universe == db.universe then
		return false, "Les deux persos doivent venir d'UNIVERS DIFFÉRENTS !"
	end
	local rule = Economy.Fusion
	for _, pair in { { a, da }, { b, db } } do
		if (pair[1].stars or 1) < rule.minStars then
			return false, pair[2].name .. " doit être au moins ★★ (évolué une fois)."
		end
		if Rarities.get(pair[2].rarity).order < rule.minRarityOrder then
			return false, pair[2].name .. " doit être au moins Épique."
		end
	end
	if data.coins < rule.coins then
		return false, "Il te manque 💰 " .. Formulas.formatNumber(rule.coins - data.coins)
	end
	for _, desc in { da, db } do
		local material = Universes.get(desc.universe).material
		if (data.materials[material.id] or 0) < rule.materials then
			return false, "Il te faut " .. rule.materials .. " × " .. material.name
		end
	end
	return true, nil, a, b, da, db
end

function FusionService:Fuse(player: Player, uidA: any, uidB: any)
	local DataService = self.services.DataService
	local data = DataService:Get(player)
	if not data or type(uidA) ~= "string" or type(uidB) ~= "string" then
		return false, "Erreur."
	end
	if self.services.TradeService:IsInTrade(player) then
		return false, "Impossible pendant un échange."
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root or (root.Position - Layout.FusionPortal).Magnitude > 45 then
		return false, "Va au Portail Crossover pour fusionner."
	end
	local ok, message, a, b, da, db = self:Validate(data, uidA, uidB)
	if not ok then
		return false, message
	end
	local rule = Economy.Fusion
	DataService:SpendCoins(player, rule.coins)
	for _, desc in { da, db } do
		DataService:AddMaterial(player, Universes.get(desc.universe).material.id, -rule.materials)
	end

	-- Le Crossover hérite de la meilleure aura des deux persos.
	local bestAura = nil
	local bestMult = 1
	for _, entry in { a, b } do
		local aura = Auras.get(entry.aura)
		if aura and aura.multiplier > bestMult then
			bestAura, bestMult = entry.aura, aura.multiplier
		end
	end

	-- ... et du meilleur trait.
	local bestTrait = nil
	local bestTier = 0
	for _, entry in { a, b } do
		local trait = Traits.get(entry.trait)
		if trait and trait.tier > bestTier then
			bestTrait, bestTier = entry.trait, trait.tier
		end
	end

	local CharacterService = self.services.CharacterService
	CharacterService:RemoveCharacter(player, uidA)
	CharacterService:RemoveCharacter(player, uidB)
	local entry = {
		id = "fusion",
		fusion = { a = a.id, b = b.id },
		level = 1,
		xp = 0,
		stars = 1,
		aura = bestAura,
		trait = bestTrait,
		locked = true,
		obtained = os.time(),
	}
	local isNew = not data.index[Formulas.indexKey(entry)]
	local uid = CharacterService:AddCharacter(player, entry)
	data.stats.fusions += 1
	DataService:Sync(player)
	CharacterService:Refresh(player)
	self.services.TeamService:RefreshTeam(player)

	local desc = Formulas.describe(entry)
	HatchReveal:FireClient(player, { uid = uid, entry = entry, fusion = true, isNew = isNew })
	Announce:FireAllClients("🌀 CROSSOVER ! 🌀", player.DisplayName .. " a créé " .. (desc and desc.name or "un Crossover") .. " !", Rarities.get("crossover").color)
	return true, "Fusion réussie !"
end

function FusionService:Start()
	local world = workspace:WaitForChild("World")
	local portal = world:WaitForChild("FusionPortal")
	local prompt = portal:WaitForChild("FusionAltar"):WaitForChild("FusionPrompt") :: ProximityPrompt
	prompt.Triggered:Connect(function(player)
		OpenMenu:FireClient(player, "Fusion")
	end)
	Remotes.func("Fuse").OnServerInvoke = function(player, uidA, uidB)
		local ok, message = self:Fuse(player, uidA, uidB)
		if not ok and message then
			Notify:FireClient(player, message, "error")
		end
		return ok, message
	end
end

return FusionService
