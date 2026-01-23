Sauercrowd.Death = {}

local playerName = UnitName("player")
local seenDeaths = {} -- Track deaths we've already processed
local ADDON_PREFIX = "SC_TAMPER"

Sauercrowd.DeathLogData = {}

-- Process a death (from network or local)
local function processDeath(data)
	local myGuildName = GetGuildInfo("player")

	-- Only process deaths from our guild
	if data.guild ~= myGuildName then
		return
	end

	-- Create unique ID to prevent duplicates (include timestamp)
	local deathID = data.name .. "-" .. data.level .. "-" .. (data.map_id or 0) .. "-" .. time()
	if seenDeaths[deathID] then
		return
	end
	seenDeaths[deathID] = true

	-- Get class info
	-- If class was parsed from message, use it directly; otherwise get from class_id
	local class = data.class or GetClassInfo(data.class_id) or "Unknown"

	-- Get race info (only available for own death, not from parsed messages)
	local raceName = "Unknown"
	if data.race_id then
		local raceInfo = C_CreatureInfo.GetRaceInfo(data.race_id)
		if raceInfo then
			raceName = raceInfo.raceName
		end
	end

	-- Get zone info (prefer parsed zone from message, fallback to map lookup)
	local zoneName = "Unknown"
	if data.zone then
		zoneName = data.zone
	elseif data.instance_id and data.instance_id ~= 0 then
		zoneName = GetRealZoneText(data.instance_id) or "Unknown"
	elseif data.map_id and data.map_id ~= 0 then
		local zoneInfo = C_Map.GetMapInfo(data.map_id)
		zoneName = zoneInfo and zoneInfo.name or "Unknown"
	end

	-- Add to death log
	table.insert(Sauercrowd.DeathLogData, {
		name = data.name,
		class = class,
		level = data.level,
		zone = zoneName,
		twitchHandle = data.twitchHandle,
	})

	-- Update UI
	Sauercrowd:UpdateMiniDeathLog()

	-- Show death announcement with TwitchHandle and article if available
	local article = data.article or "der"
	local messageString
	if data.twitchHandle and data.twitchHandle ~= "" then
		messageString = string.format("%s (%s) %s %s ist mit Level %s in %s gestorben.",
			data.name, data.twitchHandle, article, class, data.level, zoneName)
	else
		messageString = string.format("%s %s %s ist mit Level %s in %s gestorben.",
			data.name, article, class, data.level, zoneName)
	end
	Sauercrowd.DeathAnnouncement:ShowDeathMessage(messageString)

	-- Only send guild message for own death
	if data.name == playerName then
		-- Get own TwitchHandle from saved data
		local twitchHandle = ""
		if SauercrowdTwitchHandles and SauercrowdTwitchHandles.handle then
			twitchHandle = SauercrowdTwitchHandles.handle
		end

		-- Get article (der/die) from death data
		local article = data.article or "der"

		-- Send visible message with class, article and TwitchHandle for parsing
		-- Format: "Name (TwitchHandle) der/die Class ist mit Level X in Zone gestorben."
		local guildMessageString
		if twitchHandle and twitchHandle ~= "" then
			guildMessageString = string.format("%s (%s) %s %s ist mit Level %s in %s gestorben.",
				data.name, twitchHandle, article, class, data.level, zoneName)
		else
			guildMessageString = string.format("%s %s %s ist mit Level %s in %s gestorben.",
				data.name, article, class, data.level, zoneName)
		end
		SendChatMessage(guildMessageString, "GUILD")
	end
end

-- Handle own death
local function onPlayerDeath()
	local _, _, race_id = UnitRace("player")
	-- UnitClass returns gendered class name (e.g. "Kriegerin" for female, "Krieger" for male)
	local className, classToken, class_id = UnitClass("player")
	local guildName = GetGuildInfo("player") or ""
	local level = UnitLevel("player")
	local map_id = C_Map.GetBestMapForUnit("player")

	-- Get player sex (2 = male, 3 = female)
	local sex = UnitSex("player")
	local article = (sex == 3) and "die" or "der"

	-- Get own TwitchHandle
	local twitchHandle = nil
	if SauercrowdTwitchHandles and SauercrowdTwitchHandles.handle and SauercrowdTwitchHandles.handle ~= "" then
		twitchHandle = SauercrowdTwitchHandles.handle
	end

	-- Create death data
	local deathData = {
		name = playerName,
		guild = guildName,
		race_id = race_id,
		class_id = class_id,
		class = className,  -- Pre-gendered class name from UnitClass
		level = level,
		map_id = map_id,
		twitchHandle = twitchHandle,
		article = article,
	}

	-- Increment death counter and update guild note
	Sauercrowd:IncrementDeathCount()

	-- Process own death immediately (will send guild messages)
	processDeath(deathData)
end

-- Parse guild chat death messages
-- New Format: "Name (TwitchHandle) der/die Class ist mit Level X in Zone gestorben."
-- Format without handle: "Name der/die Class ist mit Level X in Zone gestorben."
-- Old Format: "Name (Class) ist mit Level X in Zone gestorben."
-- Oldest Format: "Name ist mit Level X in Zone gestorben."
local function parseGuildDeathMessage(message)
	local name, twitchHandle, article, className, level, zone

	-- Try new format first: Name (TwitchHandle) der/die Class ist mit Level X in Zone gestorben.
	name, twitchHandle, article, className, level, zone = message:match("^(.+) %((.+)%) (d[ei][re]) (.+) ist mit Level (%d+) in (.+) gestorben%.$")

	-- Try format without TwitchHandle: Name der/die Class ist mit Level X in Zone gestorben.
	if not name then
		name, article, className, level, zone = message:match("^(.+) (d[ei][re]) (.+) ist mit Level (%d+) in (.+) gestorben%.$")
		twitchHandle = nil
	end

	-- Fallback to old format with "der Klasse": Name (TwitchHandle) der Klasse Class ist mit Level X in Zone gestorben.
	if not name then
		name, twitchHandle, className, level, zone = message:match("^(.+) %((.+)%) der Klasse (.+) ist mit Level (%d+) in (.+) gestorben%.$")
		article = "der"
	end

	-- Fallback to old format without TwitchHandle: Name der Klasse Class ist mit Level X in Zone gestorben.
	if not name then
		name, className, level, zone = message:match("^(.+) der Klasse (.+) ist mit Level (%d+) in (.+) gestorben%.$")
		twitchHandle = nil
		article = "der"
	end

	-- Fallback to older format: Name (Class) ist mit Level X in Zone gestorben.
	if not name then
		name, className, level, zone = message:match("^(.+) %((.+)%) ist mit Level (%d+) in (.+) gestorben%.$")
		twitchHandle = nil
		article = "der"
	end

	-- Fallback to oldest format without class (for backwards compatibility)
	if not name then
		name, level, zone = message:match("^(.+) ist mit Level (%d+) in (.+) gestorben%.$")
		className = "Unknown"
		twitchHandle = nil
		article = "der"
	end

	if not name or not level or not zone then return nil end

	return {
		name = name,
		guild = GetGuildInfo("player"),
		level = tonumber(level),
		zone = zone,
		class = className,
		twitchHandle = twitchHandle,
		article = article,
	}
end

-- Event handler
local deathFrame = CreateFrame("Frame")
deathFrame:RegisterEvent("PLAYER_DEAD")
deathFrame:RegisterEvent("CHAT_MSG_GUILD")

deathFrame:SetScript("OnEvent", function(self, event, ...)
	if event == "PLAYER_DEAD" then
		onPlayerDeath()
	elseif event == "CHAT_MSG_GUILD" then
		local message, sender = ...

		-- Parse death message from guild chat
		local deathData = parseGuildDeathMessage(message)
		if deathData then
			-- Only process if it's not our own death (already processed)
			if deathData.name ~= playerName then
				processDeath(deathData)
			end
		end
	end
end)

-- Handle admin message to set death count
local function onAddonMessage(prefix, message, channel, sender)
	if prefix ~= ADDON_PREFIX then return end

	-- Security: Only accept messages from guild members
	if not Sauercrowd:IsValidGuildSender(sender) then return end

	-- Parse message format: "SET_DEATH_COUNT:PlayerName|Count"
	local msgType, data = message:match("^([^:]+):(.+)$")

	if msgType == "SET_DEATH_COUNT" then
		local targetName, count = data:match("^([^|]+)|(%d+)$")
		if not targetName or not count then return end

		-- Check if this message is for us
		local myName = UnitName("player")
		local targetNameBase = targetName:match("^([^-]+)") or targetName
		if targetNameBase ~= myName then return end

		-- Set the death count
		count = tonumber(count)
		Sauercrowd:InitializeTwitchHandles()
		SauercrowdTwitchHandles.deaths = count

		-- Update guild note with new death count
		local handle = Sauercrowd:GetTwitchHandle()
		if handle and handle ~= "" then
			Sauercrowd:UpdateGuildNoteWithHandleSilently(handle)
		end

		Sauercrowd:Print(string.format("|cff00ff00Todeszähler wurde von einem Moderator auf %d gesetzt.|r", count))
	end
end

function Sauercrowd.Death:Initialize()
	-- Register addon message prefix (may already be registered by SessionTracking, but harmless to register again)
	C_ChatInfo.RegisterAddonMessagePrefix(ADDON_PREFIX)

	-- Register handler for admin messages (death count reset)
	Sauercrowd.EventManager:RegisterHandler("CHAT_MSG_ADDON",
		function(_, prefix, message, channel, sender)
			onAddonMessage(prefix, message, channel, sender)
		end, 0, "DeathAdminMsg")
end
