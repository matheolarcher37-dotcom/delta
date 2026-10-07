-- Étiquettes devant le nom dans le chat (TextChatService.OnIncomingMessage).
-- Roblox n'accepte qu'UN SEUL rappel OnIncomingMessage : tous les modules qui veulent ajouter
-- une étiquette (VIP, admin, titre...) passent par ici au lieu de le redéfinir chacun.
--
--   ChatTags.addPrefix("VIP", function(joueur) return joueurEstVip and '<font color="#FFD24A">[👑 VIP]</font>' or nil end)

local Players = game:GetService("Players")

local ChatTags = {}

local providers: { { id: string, fn: (Player) -> string? } } = {}
local installed = false

local function install()
	if installed then
		return
	end
	installed = true
	pcall(function()
		local TextChatService = game:GetService("TextChatService")
		TextChatService.OnIncomingMessage = function(message)
			local properties = Instance.new("TextChatMessageProperties")
			local source = message.TextSource
			local speaker = source and Players:GetPlayerByUserId(source.UserId)
			if not speaker then
				return properties
			end
			local tags = {}
			for _, provider in providers do
				local ok, tag = pcall(provider.fn, speaker)
				if ok and type(tag) == "string" and tag ~= "" then
					table.insert(tags, tag)
				end
			end
			if #tags > 0 then
				properties.PrefixText = table.concat(tags, " ") .. " " .. message.PrefixText
			end
			return properties
		end
	end)
end

-- Ajoute (ou remplace, même `id`) une étiquette calculée pour chaque message reçu.
function ChatTags.addPrefix(id: string, fn: (Player) -> string?)
	for _, provider in providers do
		if provider.id == id then
			provider.fn = fn
			return
		end
	end
	table.insert(providers, { id = id, fn = fn })
	install()
end

return ChatTags
