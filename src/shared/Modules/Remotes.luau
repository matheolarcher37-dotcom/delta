-- Création (serveur) et récupération (client) des RemoteEvents / RemoteFunctions.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local EVENTS = {
	-- Serveur -> Client
	"DataSync", -- snapshot des données du joueur
	"Notify", -- (texte, type)
	"Announce", -- (titre, sous-titre, couleur)
	"HatchReveal", -- ({ uid, entry, source?, fusion?, isNew }) révélation d'un perso (roulage auto, fusion)
	"CombatFX", -- (type, données) effets visuels
	"Reward", -- (type, quantité, position) pièces/objets qui volent vers le joueur
	"TradeState", -- état de l'échange en cours (ou nil)
	"OpenMenu", -- (nomDuMenu, argument?) ouvre un menu côté client (prompts de proximité)
	"RollResult", -- { results = { {id, stars, rarity, aura (mutation), price, dps, ...} }, pity = { mythic = n } } (machine ROULER)
	"Robux_Granted", -- (type "pass" | "product", clé, détails) achat Robux validé (célébration côté client)
	"Robux_OpenShop", -- (onglet "passes" | "packs" | "boosts", clé?) ouvre la boutique Robux (passe manquant)
	"QuestNotify", -- (info) défis : { kind = "ready" | "progress" | "punch" | "punchTier", ... } (QuestService)
	"TraitRolled", -- ({ uid, traitId, previous, crystals }) résultat d'une relance de trait (TraitService) : le client l'affiche

	-- Client -> Serveur
	"SetTarget", -- (ennemi) cible prioritaire de l'équipe
	"TradeAction", -- (action, données)
	"Teleport", -- ("base" | "zone" | "trade" | "fusion" | "hub" | "boss")
}

local FUNCTIONS = {
	"EquipCharacter", -- (uid, equip) -> ok, message
	"ToggleLock", -- (uid) -> ok
	"SellCharacter", -- (uid) -> ok, message
	"Evolve", -- (uid) -> ok, message
	"Fuse", -- (uidA, uidB) -> ok, message
	"AutoEquip", -- () -> équipe les meilleurs persos
	"RerollTrait", -- (uid) -> ok, message, traitId
	"BuySword", -- (swordId) -> ok, message
	"EquipSword", -- (swordId) -> ok, message
	"BuySkill", -- (nodeId) -> ok, message (arbre de compétences)
	"Roll", -- () -> ok, résultats | message (machine ROULER)
	"CollectRolled", -- (clé du perso dans RolledQueue) -> ok, message (acheter un perso tiré)
	"SetAutoRoll", -- (bool) -> ok, message (« Lancer AFK », passe Robux AutoRoll)
	"Roll_SetAutoBuy", -- (bool) -> ok, message (« Achat automatique », passe Robux AutoRollPlus)
	"Roll_SaveAutoSettings", -- (réglages de la fenêtre « Roulement automatique ») -> ok, message
	"Roll_SetMulti", -- (1 | 2 | 3) -> ok, message (persos par roulage, selon les passes x2 / x3)
	"PlaceUnit", -- (emplacement, uid | nil) -> ok, message (« Remplacer l'unité » d'une case de la base)
	"Robux_Buy", -- ("pass" | "product", clé de Config/Robux) -> ok, message (ouvre l'achat Roblox)
	"Robux_BuyPass", -- (clé du passe) -> ok, message (raccourci de Robux_Buy("pass", clé) pour les autres fenêtres)
	"Merchant_GetStock", -- () -> état du marchand ambulant (coin, stock, compte à rebours)
	"Merchant_Buy", -- (idObjet) -> ok, message, état (acheter un objet d'évolution)
	"QuestClaim", -- (idDéfi | idDéfiDuJour | "bonus") -> ok, message (réclamer la récompense d'un défi)
	"QuestClaimAll", -- () -> ok, message (réclamer tout ce qui est prêt)
	"QuestGoAfk", -- () -> ok, message (voyage jusqu'à l'entrée de la zone anti-AFK)
}

local Remotes = {}

local folder: Folder

if RunService:IsServer() then
	folder = ReplicatedStorage:FindFirstChild("Remotes") :: Folder
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Remotes"
		folder.Parent = ReplicatedStorage
	end
	for _, name in EVENTS do
		if not folder:FindFirstChild(name) then
			local remote = Instance.new("RemoteEvent")
			remote.Name = name
			remote.Parent = folder
		end
	end
	for _, name in FUNCTIONS do
		if not folder:FindFirstChild(name) then
			local remote = Instance.new("RemoteFunction")
			remote.Name = name
			remote.Parent = folder
		end
	end
else
	folder = ReplicatedStorage:WaitForChild("Remotes") :: Folder
end

function Remotes.event(name: string): RemoteEvent
	return folder:WaitForChild(name) :: RemoteEvent
end

function Remotes.func(name: string): RemoteFunction
	return folder:WaitForChild(name) :: RemoteFunction
end

return Remotes
