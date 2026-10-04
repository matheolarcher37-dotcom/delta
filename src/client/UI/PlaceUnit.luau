-- Menu « Remplacer l'unité » : ouvert par l'invite d'une case jaune de la base
-- (OpenMenu "PlaceUnit", { slot = n, uid = uidActuel | nil }).
-- On choisit l'unité qui se tiendra sur la case, ou on libère la case.
-- Manette : A choisit une carte (ou le bouton « Libérer la case »), B ferme.
-- La grille est découpée en pages et n'est reconstruite que si ce qu'elle montre change
-- (le serveur synchronise les données toutes les 5 s) ; la sélection manette est conservée.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Formulas = require(Shared.Modules.Formulas)

local Theme = require(script.Parent.Theme)
local Components = require(script.Parent.Components)
local Menus = require(script.Parent.Menus)
local Notifications = require(script.Parent.Notifications)
local State = require(script.Parent.Parent.State)

local PlaceUnit = {}

local C = Theme.Colors
local new = Theme.new

local window
local grid: ScrollingFrame
local header: Frame
local currentSlot = 1
local currentUid: string? = nil
local firstCard: GuiObject? = nil
local pager
local page = 1
local lastKey = ""
local PAGE_SIZE = 12

-- Case sur laquelle se trouve déjà une unité (DisplayPins = { ["n° de case"] = uid }).
local function pinnedSlot(uid: string): number?
	local pins = State.data and State.data.DisplayPins
	if type(pins) ~= "table" then
		return nil
	end
	for key, value in pins do
		if value ~= false and value == uid then
			return tonumber(key)
		end
	end
	return nil
end

-- La case a-t-elle été vidée exprès (DisplayPins = false : pas de remplissage automatique) ?
local function slotKeptEmpty(): boolean
	local pins = State.data and State.data.DisplayPins
	return type(pins) == "table" and pins[tostring(currentSlot)] == false
end

local function place(uid: string?)
	local ok, message = State.invoke("PlaceUnit", currentSlot, uid)
	if ok then
		Notifications.toast(message or "Unité placée !", "success")
		Menus.close("PlaceUnit")
	elseif message and message ~= "" then
		-- Le serveur prévient déjà en cas d'erreur ; on ne double le message que hors connexion.
		if message == "Bientôt disponible !" or message == "Erreur de connexion, réessaie." then
			Notifications.toast(message, "error")
		end
	end
end

-- Tout ce que la grille montre : on ne reconstruit que si ça change.
local function viewKey(): string
	local data = State.data
	if not data then
		return ""
	end
	local parts = { tostring(currentSlot), tostring(currentUid), tostring(page), table.concat(data.team or {}, ",") }
	local pins = {}
	for key, value in data.DisplayPins or {} do
		table.insert(pins, tostring(key) .. "=" .. tostring(value))
	end
	table.sort(pins)
	table.insert(parts, table.concat(pins, ","))
	local units = {}
	for uid, entry in data.characters or {} do
		table.insert(units, uid .. ":" .. tostring(entry.level) .. ":" .. tostring(entry.stars) .. ":" .. tostring(entry.aura))
	end
	table.sort(units)
	table.insert(parts, table.concat(units, ","))
	return table.concat(parts, "|")
end

local function renderNow()
	Components.clear(grid)
	Components.clear(header)
	firstCard = nil
	local data = State.data
	if not data then
		return
	end

	-- Bandeau : unité actuelle de la case + bouton « Libérer la case ».
	local current = currentUid and data.characters[currentUid]
	local desc = current and Formulas.describe(current)
	new("TextLabel", {
		Name = "Current",
		Size = UDim2.new(1, -250, 1, 0),
		BackgroundTransparency = 1,
		Text = desc and ("Sur la case : " .. desc.name .. "  " .. string.rep("★", current.stars or 1) .. "   ·   DPS " .. Formulas.formatNumber(Formulas.dps(current)))
			or (slotKeptEmpty() and "Case laissée vide : choisis une unité, ou remets le remplissage auto." or "Case vide : choisis une unité ci-dessous."),
		TextColor3 = desc and C.Gold or C.TextDim,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextSize = 22,
		FontFace = Theme.Faces.Bold,
		Parent = header,
	})
	if current then
		Components.button({
			Text = "Libérer la case",
			Icon = "close",
			Color = C.Orange,
			Size = UDim2.fromOffset(230, 44),
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, 0, 0.5, 0),
			TextSize = 19,
			Parent = header,
			OnClick = function()
				place(nil)
			end,
		})
	elseif slotKeptEmpty() then
		Components.button({
			Text = "Remplissage auto",
			Icon = "unit",
			Color = C.Blue,
			Size = UDim2.fromOffset(230, 44),
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, 0, 0.5, 0),
			TextSize = 19,
			Parent = header,
			OnClick = function()
				place("auto")
			end,
		})
	end

	-- Cartes : les plus fortes d'abord ; on indique où chaque unité se trouve déjà.
	local list = State.sortedCharacters()
	table.sort(list, function(a, b)
		local da, db = Formulas.dps(a.entry), Formulas.dps(b.entry)
		if da == db then
			return a.uid < b.uid
		end
		return da > db
	end)
	local pages = math.max(1, math.ceil(#list / PAGE_SIZE))
	page = math.clamp(page, 1, pages)
	pager.set(page, pages)
	for index = (page - 1) * PAGE_SIZE + 1, math.min(#list, page * PAGE_SIZE) do
		local item = list[index]
		local slot = pinnedSlot(item.uid)
		local caption = nil
		if item.uid == currentUid then
			caption = "Sur cette case"
		elseif slot then
			caption = "Case #" .. slot
		elseif State.inTeam(item.uid) then
			caption = "Dans l'équipe"
		else
			caption = "DPS " .. Formulas.formatNumber(Formulas.dps(item.entry))
		end
		local card = Components.characterCard(grid, item.entry, {
			size = UDim2.fromOffset(140, 180),
			selected = item.uid == currentUid,
			inTeam = State.inTeam(item.uid),
			caption = caption,
			layoutOrder = index,
			selKey = item.uid,
			onClick = function()
				if item.uid == currentUid then
					Menus.close("PlaceUnit")
					return
				end
				place(item.uid)
			end,
		})
		firstCard = firstCard or card
	end
	if #list == 0 then
		Components.emptyState(grid, "Tu n'as encore aucune unité.\nFais tourner la machine ROULER de ta base !", "dice")
	end
	window.subtitle.Text = #list .. " unités  ·  une unité posée sur une case quitte l'équipe"
end

local function render(force: boolean?)
	local key = viewKey()
	if not force and key == lastKey then
		return
	end
	lastKey = key
	Components.preserveSelection(window.content, renderNow)
end

function PlaceUnit.init(gui: ScreenGui)
	window = Components.window(gui, "EMPLACEMENT", C.Gold, UDim2.fromOffset(1000, 600), {
		icon = "unit",
	})
	local content = window.content
	header = new("Frame", {
		Name = "Header",
		Size = UDim2.new(1, 0, 0, 50),
		BackgroundTransparency = 1,
		Parent = content,
	})
	grid = Components.cardGrid(content, Vector2.new(140, 180), {
		Size = UDim2.new(1, 0, 1, -108),
		Position = UDim2.fromOffset(0, 58),
	}, 12)
	pager = Components.pager(content, { Position = UDim2.new(0, 0, 1, -44) }, function(target)
		page = target
		render()
	end)

	Components.registerWindow(Menus, "PlaceUnit", window, function(arg)
		local info = type(arg) == "table" and arg or {}
		currentSlot = tonumber(info.slot) or tonumber(arg) or 1
		currentUid = type(info.uid) == "string" and info.uid or nil
		window.title.Text = "EMPLACEMENT #" .. currentSlot
		page = 1
		render(true)
	end, function()
		return firstCard or window.firstSelectable()
	end)

	-- Les données changent (unité placée, vendue...) pendant que le menu est ouvert.
	State.onChanged(function()
		if Menus.current() == "PlaceUnit" then
			render()
		end
	end)
end

return PlaceUnit
