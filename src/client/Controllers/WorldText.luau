-- TEXTES DES CARTES FLOTTANTES dimensionnées en studs (étiquettes des persos, cases, coffre,
-- compteurs des punching-balls) : leur taille à l'écran change avec la distance, seul
-- « TextScaled » peut suivre. Or Roblox ne l'applique qu'après un changement de texte : une carte
-- qui arrive déjà remplie resterait à sa taille de secours (voir Shared/Modules/TextFit). On
-- relance donc TextScaled une fois, à l'image suivante, pour chaque texte de ces cartes qui
-- apparaît près du joueur.
--
-- Les panneaux 3D (SurfaceGui) et les cartes en pixels n'en ont pas besoin : le serveur leur a
-- déjà donné la bonne taille.

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local WorldText = {}

WorldText.PerFrame = 150 -- textes relancés au plus par image (pas d'à-coup quand une base arrive)

local queue: { TextLabel } = {}
local queued: { [Instance]: boolean } = setmetatable({}, { __mode = "k" }) :: any

-- Vrai pour un texte TextScaled dans une carte flottante dimensionnée en studs.
function WorldText.needsNudge(object: Instance): boolean
	if not (object:IsA("TextLabel") or object:IsA("TextButton")) then
		return false
	end
	if not (object :: TextLabel).TextScaled then
		return false
	end
	local gui = object:FindFirstAncestorWhichIsA("BillboardGui")
	if not gui then
		return false
	end
	local size = gui.Size
	return size.X.Scale ~= 0 or size.Y.Scale ~= 0
end

local function enqueue(object: Instance)
	if not queued[object] and WorldText.needsNudge(object) then
		queued[object] = true
		table.insert(queue, object :: TextLabel)
	end
end

-- Relance TextScaled sur les textes en attente (au plus PerFrame).
function WorldText.step()
	local batch = {}
	for _ = 1, math.min(#queue, WorldText.PerFrame) do
		local label = table.remove(queue)
		if label and label.Parent and label.TextScaled then
			label.TextScaled = false
			table.insert(batch, label)
		end
	end
	if #batch > 0 then
		-- Remis à l'image suivante : deux changements dans la même image pourraient s'annuler.
		task.defer(function()
			RunService.Heartbeat:Wait()
			for _, label in batch do
				label.TextScaled = true
			end
		end)
	end
end

function WorldText.init()
	for _, object in Workspace:GetDescendants() do
		enqueue(object)
	end
	Workspace.DescendantAdded:Connect(enqueue)
	RunService.Heartbeat:Connect(function()
		if #queue > 0 then
			WorldText.step()
		end
	end)
end

return WorldText
