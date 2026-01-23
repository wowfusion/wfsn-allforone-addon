-- Helper function to extract Twitch handle from guild note
local function ExtractTwitchHandle(note)
    if not note or note == "" then
        return nil
    end
    -- Guild note is just the handle itself
    return note
end

_G.GameTooltip:HookScript("OnTooltipSetUnit", function(self)
    local _, unit = self:GetUnit()
    if not unit then
        return
    end

    local guildName, rank = _G.GetGuildInfo(unit);
    if (guildName and _G.UnitExists(unit) and _G.UnitPlayerControlled(unit)) then
        _G.GameTooltip:AddLine(string.format('%s der Gilde %s', rank, guildName))

        -- Try to get Twitch handle from guild note
        if IsInGuild() then
            local playerName = UnitName(unit)
            if playerName then
                -- Search through guild roster for this player
                local numMembers = GetNumGuildMembers()
                for i = 1, numMembers do
                    local name, _, _, _, _, _, publicNote = GetGuildRosterInfo(i)
                    -- Remove realm name if present
                    local shortName = name:match("([^%-]+)") or name
                    if shortName == playerName then
                        local twitchHandle = ExtractTwitchHandle(publicNote)
                        if twitchHandle and twitchHandle ~= "" then
                            -- Sanitize handle to prevent UI injection
                            local safeHandle = Sauercrowd:SanitizeText(twitchHandle)
                            _G.GameTooltip:AddLine(" ")
                            _G.GameTooltip:AddLine("Content Creator:", 0.39, 0.25, 0.65)
                            _G.GameTooltip:AddLine(safeHandle, 1, 1, 1)
                        end
                        break
                    end
                end
            end
        end
    end
end)