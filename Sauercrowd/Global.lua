Sauercrowd = {}

Sauercrowd.name = "Sauercrowd"
Sauercrowd.prefix = "Sauercrowd"
Sauercrowd.colorCode = "|cFF911d1d"
Sauercrowd.lastPvPAlert = {}
Sauercrowd.version = GetAddOnMetadata("Sauercrowd", "Version") or "Unbekannt"

function Sauercrowd:Print(message)
	print(Sauercrowd.colorCode .. "[" .. Sauercrowd.name .. "]|r " .. message)
end

function Sauercrowd:RemoveRealmFromName(fullName)
	return fullName:match("([^-]+)") or fullName
end

function Sauercrowd:CountTable(tbl)
	local count = 0
	for _ in pairs(tbl) do
		count = count + 1
	end
	return count
end

-- Sanitizes text to prevent UI injection via escape codes
-- Removes texture, color, and hyperlink escape sequences
function Sauercrowd:SanitizeText(text)
	if not text or type(text) ~= "string" then
		return text
	end
	-- Remove texture escape sequences |Tpath:height:width:...|t
	text = text:gsub("|T[^|]*|t", "")
	-- Remove color escape sequences |cFFFFFFFF...|r
	text = text:gsub("|c%x%x%x%x%x%x%x%x", "")
	text = text:gsub("|r", "")
	-- Remove hyperlink escape sequences |Htype:data|h...|h
	text = text:gsub("|H[^|]*|h", "")
	text = text:gsub("|h", "")
	return text
end

-- Validates that an addon message sender is a guild member
-- Uses GuildCache for fast lookup
function Sauercrowd:IsValidGuildSender(sender)
	if not sender then return false end
	local shortName = self:RemoveRealmFromName(sender)
	return Sauercrowd.GuildCache:IsGuildMember(shortName)
end
