-- Menu UNITÉS / OBJETS :
--   • onglet Unités : grille de cartes 3D + grande fiche d'unité (statistiques, trait, type) avec
--     les actions Équiper / Évoluer / Verrouiller / Vendre ;
--   • onglet Objets : reliques possédées (détails et probabilités) + matériaux et cristaux.
-- Manette : LB / RB changent d'onglet, A choisit, B ferme.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Rarities = require(Shared.Config.Rarities)
local Characters = require(Shared.Config.Characters)
local Universes = require(Shared.Config.Universes)
local Economy = require(Shared.Config.Economy)
local Formulas = require(Shared.Modules.Formulas)
local Remotes = require(Shared.Modules.Remotes)

local Theme = require(script.Parent.Theme)
local Components = require(script.Parent.Components)
local UnitSheet = require(script.Parent.UnitSheet)
local Menus = require(script.Parent.Menus)
local Notifications = require(script.Parent.Notifications)
local State = require(script.Parent.Parent.State)

local Inventory = {}

local C = Theme.Colors
local new = Theme.new
local WHITE = Color3.new(1, 1, 1)

local PAGE_SIZE = 12
local TIER_NAMES = { "Relique Commune", "Relique Rare", "Relique Légendaire" }
local TIER_COLORS = { Color3.fromRGB(64, 160, 255), Color3.fromRGB(176, 92, 255), Color3.fromRGB(255, 190, 40) }

local window
local tab = "units"
local page = 1
local selected: string? = nil
local selectedRelic: string? = nil
local confirmingSell = false
local refs: { [string]: any } = {}
local render: (boolean?) -> ()

local function call(remoteName: string, ...)
	local ok, success, message = pcall(function(...)
		return Remotes.func(remoteName):InvokeServer(...)
	end, ...)
	if not ok then
		Notifications.toast("Erreur de connexion, réessaie.", "error")
		return false
	end
	if message then
		Notifications.toast(message, success and "success" or "error")
	end
	return success
end

------------------------------------------------------------------------
-- Onglet Unités
------------------------------------------------------------------------

local function renderSheet()
	local holder = refs.sheet
	Components.clear(holder)
	local data = State.data
	local entry = data and selected and data.characters[selected]
	if not entry then
		local empty = Components.sheet(holder, { Size = UDim2.fromScale(1, 1) })
		Components.emptyState(empty, "Choisis une unité pour voir sa fiche.\nRoule à la machine ROULER de ta base pour en obtenir !", "unit").Position = UDim2.new(0, 10, 0.3, 0)
		return
	end
	local uid = selected :: string
	local inTeam = State.inTeam(uid)
	local cost = Formulas.evolutionCost(entry)
	local actions = {
		{
			text = inTeam and "Retirer" or "Équiper",
			icon = inTeam and "close" or "sword",
			color = inTeam and C.Orange or C.Green,
			onClick = function()
				call("EquipCharacter", uid, not inTeam)
			end,
		},
		{
			text = cost and "Évoluer" or "Max ★★★",
			icon = "evolve",
			color = cost and C.Purple or C.Gray,
			onClick = function()
				if cost then
					Menus.open("Evolution", uid)
				end
			end,
		},
		{
			text = entry.locked and "Déverrouiller" or "Verrouiller",
			icon = "lock",
			color = C.Blue,
			onClick = function()
				call("ToggleLock", uid)
			end,
		},
		{
			text = confirmingSell and "Confirmer ?" or ("Vendre " .. Formulas.formatNumber(Formulas.sellValue(entry))),
			icon = "coin",
			color = C.Red,
			onClick = function()
				if entry.locked then
					Notifications.toast("Déverrouille cette unité pour la vendre.", "error")
					return
				end
				if not confirmingSell then
					confirmingSell = true
					render(true)
					task.delay(3, function()
						if confirmingSell then
							confirmingSell = false
							render(true)
						end
					end)
					return
				end
				confirmingSell = false
				if call("SellCharacter", uid) then
					selected = nil
				end
				render(true)
			end,
		},
	}
	UnitSheet.build(holder, entry, actions)
end

local function renderUnits()
	local grid = refs.grid
	Components.clear(grid)
	local data = State.data
	if not data then
		return
	end
	local list = State.sortedCharacters()
	if selected and not data.characters[selected] then
		selected = nil
	end
	if not selected and list[1] then
		selected = list[1].uid
	end
	local pages = math.max(1, math.ceil(#list / PAGE_SIZE))
	page = math.clamp(page, 1, pages)
	refs.pager.set(page, pages)
	refs.grid.Size = UDim2.new(1, 0, 1, pages > 1 and -100 or -50)
	if #list == 0 then
		Components.emptyState(grid, "Aucune unité pour l'instant.\nFais tourner la machine ROULER de ta base !", "dice")
	end
	for i = (page - 1) * PAGE_SIZE + 1, math.min(#list, page * PAGE_SIZE) do
		local item = list[i]
		local card = Components.characterCard(grid, item.entry, {
			inTeam = State.inTeam(item.uid),
			selected = item.uid == selected,
			layoutOrder = i,
			onClick = function()
				selected = item.uid
				confirmingSell = false
				render(true)
			end,
		})
		card.Name = "Card"
		if item.uid == selected then
			refs.selectedCard = card
		end
	end
	local stats = State.stats()
	local count = #list
	Components.setPillText(refs.teamPill, "Équipe " .. #data.team .. " / " .. stats.team .. "  ·  " .. count .. "/" .. Economy.MaxCharacters)
	window.subtitle.Text = count .. " unités  ·  " .. #data.team .. " dans l'équipe"
end

------------------------------------------------------------------------
-- Onglet Objets
------------------------------------------------------------------------

local function relicOdds(parent: Instance, relic, universe)
	local list = new("Frame", {
		Name = "Odds",
		Size = UDim2.new(1, -24, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Position = UDim2.fromOffset(12, 0),
		BackgroundTransparency = 1,
		LayoutOrder = 5,
		Parent = parent,
	})
	Theme.list(Enum.FillDirection.Vertical, 4, Enum.HorizontalAlignment.Left).Parent = list
	local order = 0
	for _, rarityId in Rarities.Order do
		local weight = relic.odds[rarityId]
		if weight then
			order += 1
			local info = Theme.rarity(rarityId)
			local names = {}
			for _, id in universe.characters do
				local def = Characters.get(id)
				if def and def.rarity == rarityId then
					table.insert(names, def.name)
				end
			end
			local row = new("Frame", { Size = UDim2.new(1, 0, 0, 26), BackgroundTransparency = 1, LayoutOrder = order, Parent = list })
			Components.rarityTag(row, rarityId, { Size = UDim2.fromOffset(112, 22), Position = UDim2.fromOffset(0, 2) })
			Theme.label({
				Text = tostring(weight) .. " %  ·  " .. table.concat(names, ", "),
				Size = UDim2.new(1, -122, 1, -4),
				Position = UDim2.fromOffset(120, 2),
				FontFace = Theme.Faces.Bold,
				TextColor3 = info.rainbow and WHITE or Theme.light(info.color, 0.35),
				TextXAlignment = Enum.TextXAlignment.Left,
				StrokeThickness = 1.5,
				MaxSize = 17,
				Parent = row,
			})
		end
	end
end

local function renderItemDetail()
	local holder = refs.sheet
	Components.clear(holder)
	local data = State.data
	if not data then
		return
	end
	local sheet = Components.sheet(holder, { Size = UDim2.fromScale(1, 1) })
	local body = Components.scroll(sheet, { Size = UDim2.new(1, -16, 1, -16), Position = UDim2.fromOffset(8, 8) })
	Theme.list(Enum.FillDirection.Vertical, 8, Enum.HorizontalAlignment.Center).Parent = body
	Theme.padding(6).Parent = body

	local relic = selectedRelic and Universes.getRelic(selectedRelic)
	if relic and (data.relics[relic.id] or 0) > 0 then
		local universe = Universes.get(relic.universe) or Universes.List[1]
		for _, u in Universes.List do
			for _, r in u.relics do
				if r.id == relic.id then
					universe = u
				end
			end
		end
		local color = TIER_COLORS[relic.tier] or C.Blue
		local top = new("Frame", { Size = UDim2.new(1, 0, 0, 170), BackgroundTransparency = 1, LayoutOrder = 1, Parent = body })
		local view = new("Frame", { Size = UDim2.fromOffset(170, 170), BackgroundColor3 = WHITE, Parent = top })
		Theme.corner(14).Parent = view
		Theme.stroke(color, 3).Parent = view
		Theme.gradient({ Theme.dark(color, 0.35), Color3.fromRGB(14, 14, 20) }, 90).Parent = view
		Components.relicViewport(view, relic, true)
		Theme.label({
			Text = relic.name,
			Position = UDim2.fromOffset(184, 8),
			Size = UDim2.new(1, -190, 0, 36),
			FontFace = Theme.Faces.Title,
			TextXAlignment = Enum.TextXAlignment.Left,
			StrokeThickness = 2.5,
			Parent = top,
		})
		Theme.label({
			Text = (TIER_NAMES[relic.tier] or "Relique") .. "  ·  " .. universe.name,
			Position = UDim2.fromOffset(184, 48),
			Size = UDim2.new(1, -190, 0, 22),
			FontFace = Theme.Faces.Heavy,
			TextColor3 = Theme.light(color, 0.3),
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = top,
		})
		local stats = State.stats()
		local hatch = math.max(3, math.floor(Economy.RelicTiers[relic.tier].hatchTime * (stats.hatchSpeed or 1)))
		Components.pill(top, "hourglass", "Ouverture : " .. hatch .. " s", C.Gold, { Position = UDim2.fromOffset(184, 80), Size = UDim2.fromOffset(220, 34) })
		Components.pill(top, "gift", "Possédées : × " .. (data.relics[relic.id] or 0), C.Green, { Position = UDim2.fromOffset(184, 122), Size = UDim2.fromOffset(220, 34) })
		Components.sectionTitle(body, "CE QU'ELLE PEUT DONNER", { LayoutOrder = 4, Size = UDim2.new(1, -24, 0, 24) })
		relicOdds(body, relic, universe)
		Components.hintText(body, "Pose-la sur un autel de ta base pour l'ouvrir.", { LayoutOrder = 6, Size = UDim2.new(1, -24, 0, 22) })
		return
	end

	-- Sinon : ressources du joueur.
	Components.sectionTitle(body, "MES RESSOURCES", { LayoutOrder = 1, Size = UDim2.new(1, -24, 0, 26) })
	local function resourceRow(order: number, color: Color3, name: string, sub: string, amount: number, isCoin: boolean?)
		local row = new("Frame", { Size = UDim2.new(1, -12, 0, 52), BackgroundColor3 = WHITE, LayoutOrder = order, Parent = body })
		Theme.corner(12).Parent = row
		Theme.stroke(Theme.dark(color, 0.1), 2, 0.2).Parent = row
		Theme.gradient({ Theme.dark(color, 0.55), Color3.fromRGB(16, 16, 22) }, 0).Parent = row
		if isCoin then
			Components.coinIcon(row, 36, UDim2.fromOffset(30, 26))
		else
			Components.gem(row, color, 26, UDim2.fromOffset(30, 26))
		end
		Theme.label({
			Text = name,
			Position = UDim2.fromOffset(58, 6),
			Size = UDim2.new(0.6, -58, 0, 24),
			FontFace = Theme.Faces.Title,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = row,
		})
		Theme.label({
			Text = sub,
			Position = UDim2.fromOffset(58, 30),
			Size = UDim2.new(0.6, -58, 0, 16),
			FontFace = Theme.Faces.Bold,
			TextColor3 = C.TextDim,
			TextXAlignment = Enum.TextXAlignment.Left,
			StrokeThickness = 1,
			Parent = row,
		})
		Theme.label({
			Text = Formulas.formatNumber(amount),
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -14, 0.5, 0),
			Size = UDim2.new(0.38, 0, 0, 30),
			FontFace = Theme.Faces.Heavy,
			TextColor3 = isCoin and C.Gold or Theme.light(color, 0.3),
			TextXAlignment = Enum.TextXAlignment.Right,
			Parent = row,
		})
	end
	resourceRow(2, C.Gold, "Pièces", "Gagnées par tes unités et en combat", data.coins, true)
	resourceRow(3, C.Cyan, "Cristaux de Trait", "Pour relancer un trait (Autel des Traits)", data.traitCrystals or 0)
	for i, universe in Universes.List do
		local material = universe.material
		resourceRow(3 + i, material.color, material.name, "Ennemis de : " .. universe.name, data.materials[material.id] or 0)
	end
end

local function renderItems()
	local grid = refs.grid
	Components.clear(grid)
	local data = State.data
	if not data then
		return
	end
	refs.pager.set(1, 1)
	local order = 0
	local relicCount = 0
	for _, universe in Universes.List do
		for _, relic in universe.relics do
			local owned = data.relics[relic.id] or 0
			if owned > 0 then
				order += 1
				relicCount += owned
				local color = TIER_COLORS[relic.tier] or universe.color
				local _, preview = Components.itemCard(grid, {
					title = relic.name,
					subtitle = universe.name,
					subtitleColor = Theme.light(universe.color, 0.3),
					color = color,
					badge = "× " .. owned,
					layoutOrder = order,
					selected = selectedRelic == relic.id,
					onClick = function()
						selectedRelic = selectedRelic ~= relic.id and relic.id or nil
						render(true)
					end,
				})
				Components.relicViewport(preview, relic, false)
			end
		end
	end
	if order == 0 then
		Components.emptyState(grid, "Aucune relique pour l'instant.\nLa Boutique de ta base en vend !", "gift")
	end
	Components.setPillText(refs.teamPill, "Reliques : " .. relicCount .. "  ·  Cristaux : " .. (data.traitCrystals or 0))
	window.subtitle.Text = relicCount .. " reliques"
end

------------------------------------------------------------------------

local lastKey = ""

-- Clé qui résume ce qui est affiché (évite de tout reconstruire à chaque synchro).
local function viewKey(): string
	local data = State.data
	if not data then
		return ""
	end
	local parts = { tab, tostring(page), tostring(selected), tostring(selectedRelic), tostring(confirmingSell), table.concat(data.team, ",") }
	for uid, entry in data.characters do
		table.insert(parts, uid .. ":" .. entry.level .. ":" .. (entry.stars or 1) .. ":" .. tostring(entry.aura) .. ":" .. tostring(entry.locked) .. ":" .. tostring(entry.trait))
	end
	for id, count in data.relics do
		table.insert(parts, id .. "=" .. count)
	end
	if tab == "items" then
		for id, count in data.materials do
			table.insert(parts, id .. "#" .. count)
		end
		table.insert(parts, tostring(data.traitCrystals) .. "c" .. tostring(math.floor(data.coins)))
	end
	table.sort(parts)
	return table.concat(parts, "|")
end

render = function(force: boolean?)
	if not window or not window.isOpen then
		return
	end
	local key = viewKey()
	if not force and key == lastKey then
		return
	end
	lastKey = key
	refs.selectedCard = nil
	refs.autoEquip.Visible = tab == "units"
	if tab == "items" then
		renderItems()
		renderItemDetail()
	else
		renderUnits()
		renderSheet()
	end
end

function Inventory.init(gui: ScreenGui)
	window = Components.window(gui, "UNITÉS", Color3.fromRGB(40, 190, 80), UDim2.fromOffset(1180, 640), {
		icon = "unit",
		tabs = {
			{ id = "units", text = "Unités", icon = "unit" },
			{ id = "items", text = "Objets", icon = "bag" },
		},
		onTab = function(id)
			tab = id
			page = 1
			render(true)
		end,
	})
	local content = window.content

	-- Colonne de gauche : barre d'outils + grille + pages
	local left = new("Frame", { Name = "Left", Size = UDim2.new(0.38, -8, 1, 0), BackgroundTransparency = 1, Parent = content })
	local toolbar = new("Frame", { Name = "Toolbar", Size = UDim2.new(1, 0, 0, 44), BackgroundTransparency = 1, Parent = left })
	local layout = Theme.list(Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Left)
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Parent = toolbar
	refs.autoEquip = Components.button({
		Text = "Meilleure équipe",
		Icon = "team",
		Color = C.Green,
		Size = UDim2.fromOffset(200, 42),
		TextSize = 19,
		LayoutOrder = 1,
		Parent = toolbar,
		OnClick = function()
			call("AutoEquip")
		end,
	})
	refs.teamPill = Components.pill(toolbar, "sword", "Équipe", C.Blue, { Size = UDim2.fromOffset(218, 36), LayoutOrder = 2 })

	refs.grid = Components.cardGrid(left, Vector2.new(124, 160), {
		Name = "Grid",
		Size = UDim2.new(1, 0, 1, -100),
		Position = UDim2.fromOffset(0, 50),
	}, 10)
	refs.pager = Components.pager(left, { Position = UDim2.new(0, 0, 1, -44) }, function(target)
		page = target
		render(true)
	end)

	-- Colonne de droite : fiche
	refs.sheet = new("Frame", {
		Name = "SheetHolder",
		Size = UDim2.new(0.62, -8, 1, -14),
		Position = UDim2.new(0.38, 8, 0, 14),
		BackgroundTransparency = 1,
		Parent = content,
	})

	Components.registerWindow(Menus, "Inventory", window, function(arg)
		if arg == "items" or arg == "relics" then
			tab = "items"
		elseif type(arg) == "string" then
			tab = "units"
			selected = arg
		else
			tab = "units"
		end
		window.setTab(tab, true)
		confirmingSell = false
		render(true)
	end, function()
		return refs.selectedCard or window.firstSelectable()
	end)
	State.onChanged(function()
		render()
	end)
end

return Inventory
