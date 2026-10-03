-- Menu "Mes persos" : grille de cartes 3D, fiche détaillée, équiper / verrouiller / vendre,
-- et onglet des reliques possédées.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Rarities = require(Shared.Config.Rarities)
local Auras = require(Shared.Config.Auras)
local Traits = require(Shared.Config.Traits)
local Universes = require(Shared.Config.Universes)
local Economy = require(Shared.Config.Economy)
local Formulas = require(Shared.Modules.Formulas)
local Remotes = require(Shared.Modules.Remotes)

local Theme = require(script.Parent.Theme)
local Components = require(script.Parent.Components)
local Menus = require(script.Parent.Menus)
local Notifications = require(script.Parent.Notifications)
local State = require(script.Parent.Parent.State)

local Inventory = {}

local C = Theme.Colors
local new = Theme.new

local PAGE_SIZE = 12

local window
local tab = "characters"
local page = 1
local selected: string? = nil
local refs = {}
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
-- Fiche détaillée
------------------------------------------------------------------------

local function renderDetail()
	local panel = refs.detail
	Components.clear(panel)
	local data = State.data
	local entry = data and selected and data.characters[selected]
	if not entry then
		Theme.label({
			Text = "Sélectionne un perso pour voir sa fiche",
			Size = UDim2.new(1, -20, 0, 60),
			Position = UDim2.new(0, 10, 0.45, 0),
			TextColor3 = C.TextDim,
			TextWrapped = true,
			Parent = panel,
		})
		return
	end
	local desc = Formulas.describe(entry)
	if not desc then
		return
	end
	local rarity = Rarities.get(desc.rarity)
	local universe = Universes.get(desc.universe)
	local stats = State.stats()

	local preview = new("Frame", {
		Size = UDim2.new(1, -16, 0.42, 0),
		Position = UDim2.fromOffset(8, 6),
		BackgroundColor3 = rarity.color:Lerp(C.PanelDark, 0.6),
		Parent = panel,
	})
	Theme.corner(14).Parent = preview
	Theme.stroke(rarity.color, 3).Parent = preview
	Components.characterViewport(preview, desc.look, true, entry)

	local y = 0.44
	local function line(text: string, color: Color3?, height: number?, font: Enum.Font?)
		local h = height or 0.055
		local label = Theme.label({
			Text = text,
			Size = UDim2.new(1, -16, h, 0),
			Position = UDim2.new(0, 8, y, 0),
			TextColor3 = color or C.Text,
			Font = font or Theme.Fonts.Body,
			Parent = panel,
		})
		y += h + 0.005
		return label
	end
	line(desc.name, rarity.color:Lerp(Color3.new(1, 1, 1), 0.3), 0.07, Theme.Fonts.Title)
	local universesText = universe and universe.name or ""
	if desc.isFusion and desc.universes[2] then
		local u2 = Universes.get(desc.universes[2])
		universesText = universesText .. " × " .. (u2 and u2.name or "")
	end
	line(rarity.name .. "  ·  " .. string.rep("★", entry.stars or 1) .. "  ·  " .. universesText, C.TextDim, 0.045, Theme.Fonts.Small)

	local cap = Formulas.levelCap(entry.stars)
	local need = Formulas.xpToNext(entry.level)
	line("Niveau " .. entry.level .. " / " .. cap, Color3.fromRGB(255, 230, 80), 0.05)
	local xpBar = Components.progressBar(panel, C.Blue, { Size = UDim2.new(1, -24, 0, 12), Position = UDim2.new(0, 12, y, 0) })
	xpBar.set(entry.level >= cap and 1 or entry.xp / need)
	y += 0.035
	line("⚔️ Puissance : " .. Formulas.formatNumber(Formulas.power(entry)) .. "   ❤️ " .. Formulas.formatNumber(Formulas.maxHp(entry)), C.Text, 0.048)
	line("💰 Revenu à la base : " .. Formulas.formatNumber(Formulas.income(entry, stats.income)) .. " /s", C.Gold, 0.045)
	line("Attaque : " .. desc.attack.name, desc.attack.color:Lerp(Color3.new(1, 1, 1), 0.4), 0.045)
	local aura = Auras.get(entry.aura)
	if aura then
		line("Aura " .. aura.name .. " (×" .. aura.multiplier .. " puissance)", aura.color, 0.045)
	end
	local trait = Traits.get(entry.trait)
	line(trait and ("◆ Trait " .. trait.name .. " : " .. trait.description) or "◆ Pas de trait (Autel des Traits, au centre)", trait and trait.color or C.TextDim, 0.045)

	local buttons = new("Frame", {
		Size = UDim2.new(1, -16, 0, 96),
		Position = UDim2.new(0, 8, 1, -100),
		BackgroundTransparency = 1,
		Parent = panel,
	})
	local inTeam = State.inTeam(selected :: string)
	local uid = selected :: string
	Components.button({
		Text = inTeam and "Retirer de l'équipe" or "⚔️ Équiper",
		Color = inTeam and C.Orange or C.Green,
		Size = UDim2.new(1, 0, 0, 44),
		Parent = buttons,
		OnClick = function()
			call("EquipCharacter", uid, not inTeam)
		end,
	})
	Components.button({
		Text = entry.locked and "🔓 Déverrouiller" or "🔒 Verrouiller",
		Color = C.Blue,
		Size = UDim2.new(0.49, 0, 0, 44),
		Position = UDim2.new(0, 0, 0, 50),
		Parent = buttons,
		OnClick = function()
			call("ToggleLock", uid)
		end,
	})
	local confirming = false
	local sellButton
	sellButton = Components.button({
		Text = "💰 Vendre " .. Formulas.formatNumber(Formulas.sellValue(entry)),
		Color = C.Red,
		Size = UDim2.new(0.49, 0, 0, 44),
		Position = UDim2.new(0.51, 0, 0, 50),
		Parent = buttons,
		OnClick = function()
			if entry.locked then
				Notifications.toast("Déverrouille ce perso pour le vendre.", "error")
				return
			end
			if not confirming then
				confirming = true
				Components.setButtonText(sellButton, "Confirmer ?")
				task.delay(3, function()
					confirming = false
					if sellButton.Parent then
						Components.setButtonText(sellButton, "💰 Vendre " .. Formulas.formatNumber(Formulas.sellValue(entry)))
					end
				end)
				return
			end
			if call("SellCharacter", uid) then
				selected = nil
			end
		end,
	})
end

------------------------------------------------------------------------
-- Grille
------------------------------------------------------------------------

local function renderGrid()
	local grid = refs.grid
	Components.clear(grid)
	local data = State.data
	if not data then
		return
	end
	local stats = State.stats()
	local count = 0
	for _ in data.characters do
		count += 1
	end
	refs.counts.Text = "⚔️ Équipe " .. #data.team .. "/" .. stats.team .. "   ·   🎒 " .. count .. "/" .. Economy.MaxCharacters

	if tab == "relics" then
		refs.pager.Visible = false
		local order = 0
		for _, universe in Universes.List do
			for _, relic in universe.relics do
				local owned = data.relics[relic.id] or 0
				if owned > 0 then
					order += 1
					local card = new("Frame", {
						Size = UDim2.fromOffset(130, 165),
						BackgroundColor3 = C.PanelLight,
						LayoutOrder = order,
						Parent = grid,
					})
					Theme.corner(14).Parent = card
					Theme.stroke(universe.color, 3).Parent = card
					local holder = new("Frame", { Size = UDim2.new(1, -8, 0.66, 0), Position = UDim2.fromOffset(4, 4), BackgroundTransparency = 1, Parent = card })
					Components.relicViewport(holder, relic, true)
					Theme.label({ Text = relic.name, Size = UDim2.new(0.94, 0, 0.14, 0), Position = UDim2.fromScale(0.03, 0.68), Parent = card })
					Theme.label({
						Text = "× " .. owned .. "  ·  " .. universe.name,
						Size = UDim2.new(0.94, 0, 0.11, 0),
						Position = UDim2.fromScale(0.03, 0.84),
						TextColor3 = C.TextDim,
						Font = Theme.Fonts.Small,
						Parent = card,
					})
				end
			end
		end
		if order == 0 then
			Theme.label({ Text = "Aucune relique. Achète-en à la Machine à Reliques de ta base !", Size = UDim2.new(1, 0, 0, 50), TextColor3 = C.TextDim, Parent = grid })
		end
		return
	end

	local list = State.sortedCharacters()
	local pages = math.max(1, math.ceil(#list / PAGE_SIZE))
	page = math.clamp(page, 1, pages)
	refs.pager.Visible = pages > 1
	refs.pageLabel.Text = "Page " .. page .. " / " .. pages
	if #list == 0 then
		Theme.label({
			Text = "Aucun perso pour l'instant. Ouvre une relique sur l'autel de ta base !",
			Size = UDim2.new(1, 0, 0, 50),
			TextColor3 = C.TextDim,
			TextWrapped = true,
			Parent = grid,
		})
	end
	for i = (page - 1) * PAGE_SIZE + 1, math.min(#list, page * PAGE_SIZE) do
		local item = list[i]
		Components.characterCard(grid, item.entry, {
			inTeam = State.inTeam(item.uid),
			selected = item.uid == selected,
			layoutOrder = i,
			onClick = function()
				selected = item.uid
				render(true)
			end,
		})
	end
end

local lastKey = ""

-- Clé qui résume ce qui est affiché (évite de tout reconstruire à chaque synchro).
local function viewKey(): string
	local data = State.data
	if not data then
		return ""
	end
	local parts = { tab, tostring(page), tostring(selected), table.concat(data.team, ",") }
	for uid, entry in data.characters do
		table.insert(parts, uid .. ":" .. entry.level .. ":" .. (entry.stars or 1) .. ":" .. tostring(entry.aura) .. ":" .. tostring(entry.locked))
	end
	for id, count in data.relics do
		table.insert(parts, id .. "=" .. count)
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
	renderGrid()
	renderDetail()
end

function Inventory.init(gui: ScreenGui)
	window = Components.window(gui, "🎒 MES PERSOS", C.Blue)
	local content = window.content

	local top = new("Frame", { Size = UDim2.new(1, 0, 0, 44), BackgroundTransparency = 1, Parent = content })
	local function tabButton(text: string, id: string, x: number)
		return Components.button({
			Text = text,
			Color = C.Purple,
			Size = UDim2.fromOffset(130, 40),
			Position = UDim2.fromOffset(x, 0),
			Parent = top,
			OnClick = function()
				tab = id
				render()
			end,
		})
	end
	tabButton("Persos", "characters", 0)
	tabButton("Reliques", "relics", 140)
	Components.button({
		Text = "⚡ Meilleure équipe",
		Color = C.Green,
		Size = UDim2.fromOffset(190, 40),
		Position = UDim2.fromOffset(280, 0),
		Parent = top,
		OnClick = function()
			call("AutoEquip")
		end,
	})
	refs.counts = Theme.label({
		Size = UDim2.new(1, -490, 0, 30),
		Position = UDim2.fromOffset(484, 6),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = C.TextDim,
		Parent = top,
	})

	local body = new("Frame", { Size = UDim2.new(1, 0, 1, -52), Position = UDim2.fromOffset(0, 52), BackgroundTransparency = 1, Parent = content })
	local left = new("Frame", { Size = UDim2.new(0.63, 0, 1, 0), BackgroundTransparency = 1, Parent = body })
	refs.grid = new("ScrollingFrame", {
		Size = UDim2.new(1, 0, 1, -44),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = left,
	})
	new("UIGridLayout", {
		CellSize = UDim2.fromOffset(130, 165),
		CellPadding = UDim2.fromOffset(10, 10),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = refs.grid,
	})
	Theme.padding(6).Parent = refs.grid
	refs.pager = new("Frame", { Size = UDim2.new(1, 0, 0, 40), Position = UDim2.new(0, 0, 1, -40), BackgroundTransparency = 1, Parent = left })
	Components.button({
		Text = "◀",
		Color = C.Purple,
		Size = UDim2.fromOffset(50, 38),
		Parent = refs.pager,
		OnClick = function()
			page -= 1
			render()
		end,
	})
	Components.button({
		Text = "▶",
		Color = C.Purple,
		Size = UDim2.fromOffset(50, 38),
		Position = UDim2.new(1, -50, 0, 0),
		Parent = refs.pager,
		OnClick = function()
			page += 1
			render()
		end,
	})
	refs.pageLabel = Theme.label({ Size = UDim2.new(1, -120, 0, 30), Position = UDim2.fromOffset(60, 4), Parent = refs.pager })

	refs.detail = new("Frame", {
		Size = UDim2.new(0.36, 0, 1, 0),
		Position = UDim2.fromScale(0.64, 0),
		BackgroundColor3 = C.PanelDark,
		BackgroundTransparency = 0.2,
		Parent = body,
	})
	Theme.corner(14).Parent = refs.detail
	Theme.stroke(C.Stroke, 3).Parent = refs.detail

	window.onClose = function()
		Menus.closed("Inventory")
	end
	Menus.register("Inventory", {
		open = function(arg)
			if type(arg) == "string" then
				selected = arg
			end
			window.open()
			render(true)
		end,
		close = window.close,
	})
	State.onChanged(function()
		render()
	end)
end

return Inventory
