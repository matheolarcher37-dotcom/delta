-- Échanges entre joueurs à la table du "Coin des Échanges".
-- Chaque joueur s'assoit d'un côté de la table, propose persos / matériaux / pièces,
-- les deux cliquent "Prêt", puis un compte à rebours de 3 s valide l'échange.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Economy = require(Shared.Config.Economy)
local Universes = require(Shared.Config.Universes)
local Formulas = require(Shared.Modules.Formulas)
local Remotes = require(Shared.Modules.Remotes)

local TradeService = {}

local TradeState = Remotes.event("TradeState")
local Notify = Remotes.event("Notify")

local MAX_CHARACTERS_PER_SIDE = 8
local COUNTDOWN = 3

local sessions = {} -- [Player] = session
local nextId = 0

function TradeService:Init(services)
	self.services = services
end

function TradeService:IsInTrade(player: Player): boolean
	return sessions[player] ~= nil
end

local function emptyOffer()
	return { characters = {}, materials = {}, coins = 0 }
end

local function playerFromSeat(seat: Seat): Player?
	local humanoid = seat.Occupant
	if not humanoid then
		return nil
	end
	return Players:GetPlayerFromCharacter(humanoid.Parent)
end

local function unseat(seat: Seat?)
	if not seat then
		return
	end
	local weld = seat:FindFirstChild("SeatWeld")
	if weld then
		weld:Destroy()
	end
end

function TradeService:_serialize(session, viewer: Player)
	local DataService = self.services.DataService
	local sides = {}
	for _, key in { "A", "B" } do
		local player = session.players[key]
		local offer = session.offers[player]
		local data = DataService:Get(player)
		local characters = {}
		for _, uid in offer.characters do
			local entry = data and data.characters[uid]
			if entry then
				table.insert(characters, { uid = uid, entry = entry })
			end
		end
		sides[key] = {
			name = player.DisplayName,
			userId = player.UserId,
			ready = session.ready[player] == true,
			coins = offer.coins,
			materials = offer.materials,
			characters = characters,
		}
	end
	return {
		id = session.id,
		state = session.state,
		countdownEnds = session.countdownEnds,
		you = session.players.A == viewer and "A" or "B",
		sides = sides,
	}
end

function TradeService:_broadcast(session)
	for _, key in { "A", "B" } do
		local player = session.players[key]
		if player.Parent then
			TradeState:FireClient(player, self:_serialize(session, player))
		end
	end
end

function TradeService:_start(tableModel: Model, playerA: Player, playerB: Player)
	if sessions[playerA] or sessions[playerB] or playerA == playerB then
		return
	end
	if not self.services.DataService:IsLoaded(playerA) or not self.services.DataService:IsLoaded(playerB) then
		return
	end
	nextId += 1
	local session = {
		id = nextId,
		table = tableModel,
		players = { A = playerA, B = playerB },
		offers = { [playerA] = emptyOffer(), [playerB] = emptyOffer() },
		ready = {},
		state = "editing",
		countdownEnds = nil,
		token = 0,
	}
	sessions[playerA] = session
	sessions[playerB] = session
	self:_broadcast(session)
end

function TradeService:_end(session, reason: string?)
	for _, key in { "A", "B" } do
		local player = session.players[key]
		if sessions[player] == session then
			sessions[player] = nil
		end
		if player.Parent then
			TradeState:FireClient(player, nil)
			if reason then
				Notify:FireClient(player, reason, "info")
			end
		end
	end
	session.state = "closed"
	unseat(session.table:FindFirstChild("SeatA") :: Seat?)
	unseat(session.table:FindFirstChild("SeatB") :: Seat?)
end

function TradeService:_changed(session)
	session.ready = {}
	session.state = "editing"
	session.countdownEnds = nil
	session.token += 1
	self:_broadcast(session)
end

function TradeService:_otherPlayer(session, player: Player): Player
	return session.players.A == player and session.players.B or session.players.A
end

function TradeService:_action(player: Player, action: any, payload: any)
	local session = sessions[player]
	if not session or session.state == "closed" or type(action) ~= "string" then
		return
	end
	local data = self.services.DataService:Get(player)
	if not data then
		return
	end
	local offer = session.offers[player]

	if action == "cancel" then
		self:_end(session, "Échange annulé.")
		return
	elseif action == "ready" then
		session.ready[player] = payload == true
		local other = self:_otherPlayer(session, player)
		if session.ready[player] and session.ready[other] then
			session.state = "countdown"
			session.countdownEnds = workspace:GetServerTimeNow() + COUNTDOWN
			session.token += 1
			local token = session.token
			task.delay(COUNTDOWN, function()
				if session.token == token and session.state == "countdown" then
					self:_execute(session)
				end
			end)
		else
			session.state = "editing"
			session.countdownEnds = nil
			session.token += 1
		end
		self:_broadcast(session)
		return
	end

	if action == "addCharacter" then
		if type(payload) ~= "string" then
			return
		end
		local entry = data.characters[payload]
		if not entry then
			return
		end
		if entry.locked then
			Notify:FireClient(player, "Ce perso est verrouillé 🔒 (déverrouille-le dans l'inventaire).", "error")
			return
		end
		if table.find(offer.characters, payload) or #offer.characters >= MAX_CHARACTERS_PER_SIDE then
			return
		end
		table.insert(offer.characters, payload)
	elseif action == "removeCharacter" then
		local index = table.find(offer.characters, payload)
		if not index then
			return
		end
		table.remove(offer.characters, index)
	elseif action == "setMaterial" then
		if type(payload) ~= "table" or type(payload.id) ~= "string" or type(payload.amount) ~= "number" then
			return
		end
		if not Universes.getMaterial(payload.id) then
			return
		end
		local amount = math.clamp(math.floor(payload.amount), 0, data.materials[payload.id] or 0)
		offer.materials[payload.id] = amount > 0 and amount or nil
	elseif action == "setCoins" then
		if type(payload) ~= "number" or payload ~= payload then
			return
		end
		offer.coins = math.clamp(math.floor(payload), 0, math.floor(data.coins))
	else
		return
	end
	self:_changed(session)
end

-- Vérifie que chaque joueur possède encore tout ce qu'il propose.
function TradeService:_validate(session)
	local DataService = self.services.DataService
	local A, B = session.players.A, session.players.B
	for _, pair in { { A, B }, { B, A } } do
		local giver, receiver = pair[1], pair[2]
		local giverData, receiverData = DataService:Get(giver), DataService:Get(receiver)
		if not giverData or not receiverData then
			return false, "Un joueur est parti."
		end
		local offer = session.offers[giver]
		local receivedOffer = session.offers[receiver]
		for _, uid in offer.characters do
			local entry = giverData.characters[uid]
			if not entry or entry.locked then
				return false, "Un perso proposé n'est plus disponible."
			end
		end
		for id, amount in offer.materials do
			if (giverData.materials[id] or 0) < amount then
				return false, "Matériaux insuffisants."
			end
		end
		if giverData.coins < offer.coins then
			return false, "Pièces insuffisantes."
		end
		local giverCount = DataService:CharacterCount(giver) - #offer.characters + #receivedOffer.characters
		if giverCount < 1 then
			return false, giver.DisplayName .. " doit garder au moins un perso."
		end
		if giverCount > Economy.MaxCharacters then
			return false, "Inventaire de " .. giver.DisplayName .. " plein."
		end
	end
	return true
end

function TradeService:_execute(session)
	local ok, message = self:_validate(session)
	if not ok then
		self:_end(session, "Échange annulé : " .. tostring(message))
		return
	end
	local DataService = self.services.DataService
	local A, B = session.players.A, session.players.B
	local dataA, dataB = DataService:Get(A), DataService:Get(B)
	-- Transfert atomique (aucune attente entre les étapes).
	local moved = {}
	for _, pair in { { A, dataA, dataB }, { B, dataB, dataA } } do
		local giver, from, to = pair[1], pair[2], pair[3]
		local offer = session.offers[giver]
		for _, uid in offer.characters do
			local entry = from.characters[uid]
			from.characters[uid] = nil
			local teamIndex = table.find(from.team, uid)
			if teamIndex then
				table.remove(from.team, teamIndex)
			end
			entry.locked = false
			table.insert(moved, { to = to, uid = uid, entry = entry })
		end
		for id, amount in offer.materials do
			from.materials[id] = (from.materials[id] or 0) - amount
			to.materials[id] = (to.materials[id] or 0) + amount
		end
		from.coins -= offer.coins
		to.coins += offer.coins
	end
	for _, item in moved do
		item.to.characters[item.uid] = item.entry
		item.to.index[Formulas.indexKey(item.entry)] = true
	end
	dataA.stats.trades += 1
	dataB.stats.trades += 1
	for _, player in { A, B } do
		DataService:Sync(player)
		DataService:SaveNow(player)
		self.services.CharacterService:Refresh(player)
		self.services.TeamService:RefreshTeam(player)
	end
	self:_end(session, "🤝 Échange réussi !")
end

function TradeService:Start()
	Remotes.event("TradeAction").OnServerEvent:Connect(function(player, action, payload)
		local ok, err = pcall(self._action, self, player, action, payload)
		if not ok then
			warn("[AnimeTycoon] échange : " .. tostring(err))
		end
	end)

	local function watchTable(tableModel: Instance)
		local seatA = tableModel:WaitForChild("SeatA") :: Seat
		local seatB = tableModel:WaitForChild("SeatB") :: Seat
		local function check()
			local playerA, playerB = playerFromSeat(seatA), playerFromSeat(seatB)
			-- Si quelqu'un se lève, on annule l'échange en cours de cette table.
			for _, session in sessions do
				if session.table == tableModel and session.state ~= "closed" then
					if session.players.A ~= playerA or session.players.B ~= playerB then
						self:_end(session, "Échange annulé (un joueur s'est levé).")
					end
				end
			end
			if playerA and playerB then
				self:_start(tableModel :: Model, playerA, playerB)
			elseif playerA or playerB then
				local waiting = playerA or playerB
				Notify:FireClient(waiting :: Player, "🤝 Assis à la table d'échange ! En attente d'un autre joueur en face...", "info")
			end
		end
		seatA:GetPropertyChangedSignal("Occupant"):Connect(check)
		seatB:GetPropertyChangedSignal("Occupant"):Connect(check)
	end
	for _, tableModel in CollectionService:GetTagged("TradeTable") do
		watchTable(tableModel)
	end

	Players.PlayerRemoving:Connect(function(player)
		local session = sessions[player]
		if session then
			self:_end(session, "Échange annulé (joueur parti).")
		end
	end)
end

return TradeService
