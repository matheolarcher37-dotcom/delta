-- Création (serveur) et récupération (client) des RemoteEvents / RemoteFunctions.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local EVENTS = {
	-- Serveur -> Client
	"DataSync", -- snapshot des données du joueur
	"Notify", -- (texte, type)
	"Announce", -- (titre, sous-titre, couleur)
	"HatchReveal", -- (entrée personnage, relicId)
	"CombatFX", -- (type, données) effets visuels
	"Reward", -- (type, quantité, position) pièces/objets qui volent vers le joueur
	"TradeState", -- état de l'échange en cours (ou nil)
	"OpenMenu", -- (nomDuMenu, argument?) ouvre un menu côté client (prompts de proximité)
	"RollResult", -- { results = { {id, stars, rarity, price, dps, ...} }, pity = {...}, x10In = n } (machine ROULER)

	-- Client -> Serveur
	"SetTarget", -- (ennemi) cible prioritaire de l'équipe
	"TradeAction", -- (action, données)
	"Teleport", -- ("base" | "zone" | "trade" | "fusion" | "hub" | "boss")
}

local FUNCTIONS = {
	"BuyRelic", -- (relicId) -> ok, message
	"PlaceRelic", -- (slot, relicId) -> ok, message
	"EquipCharacter", -- (uid, equip) -> ok, message
	"ToggleLock", -- (uid) -> ok
	"SellCharacter", -- (uid) -> ok, message
	"Evolve", -- (uid) -> ok, message
	"Fuse", -- (uidA, uidB) -> ok, message
	"GetShop", -- () -> état de la boutique
	"AutoEquip", -- () -> équipe les meilleurs persos
	"RerollTrait", -- (uid) -> ok, message, traitId
	"BuyTraitCrystal", -- () -> ok, message
	"BuySword", -- (swordId) -> ok, message
	"EquipSword", -- (swordId) -> ok, message
	"BuySkill", -- (nodeId) -> ok, message (arbre de compétences)
	"Roll", -- () -> ok, résultats | message (machine ROULER)
	"CollectRolled", -- (index dans RolledQueue) -> ok, message (acheter un perso tiré)
	"SetAutoRoll", -- (bool) -> ok, message
	"PlaceUnit", -- (emplacement, uid | nil) -> ok, message (« Remplacer l'unité » d'une case de la base)
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
