----------------------------------------------------------------------
--  All for One - Tooltip Enhancement Module
--  Shows guild info and addon status in player tooltips
----------------------------------------------------------------------

local addonName, BR = ...

local TooltipEnhance = {
    lastGuildMember = nil,
    lastTooltipUpdate = 0,
    lastTooltipTarget = nil,
    lastUnit = nil,
    factionTexture = nil,
}

-- Faction icon textures
local FACTION_ICONS = {
    ["Alliance"] = "Interface\\Timer\\Alliance-Logo",
    ["Horde"] = "Interface\\Timer\\Horde-Logo",
}

-- Race to Faction mapping
local RACE_FACTION = {
    -- Alliance
    ["Mensch"] = "Alliance", ["Human"] = "Alliance",
    ["Zwerg"] = "Alliance", ["Dwarf"] = "Alliance",
    ["Nachtelf"] = "Alliance", ["Night Elf"] = "Alliance", ["NightElf"] = "Alliance",
    ["Gnom"] = "Alliance", ["Gnome"] = "Alliance",
    ["Draenei"] = "Alliance",
    ["Worgen"] = "Alliance",
    ["Pandaren"] = nil, -- Neutral, will use player faction
    ["Leerenelf"] = "Alliance", ["Void Elf"] = "Alliance", ["VoidElf"] = "Alliance",
    ["Lichtgeschmiedeter Draenei"] = "Alliance", ["Lightforged Draenei"] = "Alliance", ["LightforgedDraenei"] = "Alliance",
    ["Dunkeleisenzwerg"] = "Alliance", ["Dark Iron Dwarf"] = "Alliance", ["DarkIronDwarf"] = "Alliance",
    ["Kul Tiraner"] = "Alliance", ["Kul Tiran"] = "Alliance", ["KulTiran"] = "Alliance",
    ["Mechagnome"] = "Alliance", ["Mechagnom"] = "Alliance",
    ["Dracthyr"] = nil, -- Can be either
    ["Irdener"] = "Alliance", ["Earthen"] = "Alliance",
    -- Horde
    ["Orc"] = "Horde", ["Ork"] = "Horde",
    ["Untoter"] = "Horde", ["Undead"] = "Horde", ["Forsaken"] = "Horde",
    ["Tauren"] = "Horde",
    ["Troll"] = "Horde",
    ["Blutelf"] = "Horde", ["Blood Elf"] = "Horde", ["BloodElf"] = "Horde",
    ["Goblin"] = "Horde",
    ["Hochbergtauren"] = "Horde", ["Highmountain Tauren"] = "Horde", ["HighmountainTauren"] = "Horde",
    ["Nachtgeborener"] = "Horde", ["Nightborne"] = "Horde",
    ["Mag'har-Orc"] = "Horde", ["Mag'har Orc"] = "Horde", ["MagharOrc"] = "Horde",
    ["Zandalari-Troll"] = "Horde", ["Zandalari Troll"] = "Horde", ["ZandalariTroll"] = "Horde",
    ["Vulpera"] = "Horde",
}

-- Parse faction from tooltip text (e.g. "Stufe 80 Irdener Krieger")
function TooltipEnhance:GetFactionFromTooltip(tooltip)
    if not tooltip then return nil end
    
    for i = 1, tooltip:NumLines() do
        local line = _G[tooltip:GetName() .. "TextLeft" .. i]
        if line then
            local text = line:GetText()
            if text then
                -- Check each race in our mapping
                for race, faction in pairs(RACE_FACTION) do
                    if text:find(race) then
                        return faction
                    end
                end
            end
        end
    end
    return nil
end

function TooltipEnhance:OnInitialize()
    BR:Debug("TooltipEnhance module initialized")
end

function TooltipEnhance:OnEnable()
    self:HookTooltip()
    self:HookGuildRoster()
end

function TooltipEnhance:OnDisable()
    -- Nothing to disable
end

function TooltipEnhance:Refresh()
    -- Nothing to refresh
end

-- Check if tooltip already has AllforOne info
function TooltipEnhance:TooltipHasBRInfo(tooltip)
    for i = 1, tooltip:NumLines() do
        local line = _G[tooltip:GetName() .. "TextLeft" .. i]
        if line then
            local text = line:GetText()
            if text and text:find("AllforOne Addon") then
                return true
            end
        end
    end
    return false
end

-- Add addon status info to tooltip for a guild member
-- Create or update faction background texture on tooltip
function TooltipEnhance:SetFactionBackground(tooltip, factionOrUnit)
    if not tooltip then return end
    
    local faction
    -- Check if it's a direct faction string or a unit
    if factionOrUnit == "Alliance" or factionOrUnit == "Horde" then
        faction = factionOrUnit
    elseif factionOrUnit then
        faction = UnitFactionGroup(factionOrUnit)
    else
        faction = UnitFactionGroup("player")
    end
    
    local iconPath = FACTION_ICONS[faction]
    if not iconPath then return end
    
    -- Create texture if it doesn't exist
    if not self.factionTexture then
        -- Create as ARTWORK with low sublevel so it appears behind text but above backdrop
        self.factionTexture = tooltip:CreateTexture(nil, "ARTWORK", nil, -8)
    end
    
    local tex = self.factionTexture
    tex:SetTexture(iconPath)
    tex:SetSize(64, 64)
    tex:ClearAllPoints()
    tex:SetPoint("TOPRIGHT", tooltip, "TOPRIGHT", -5, -5)
    tex:SetAlpha(0.35)
    tex:SetBlendMode("ADD")
    tex:Show()
end

-- Hide faction background
function TooltipEnhance:HideFactionBackground()
    if self.factionTexture then
        self.factionTexture:Hide()
    end
end

function TooltipEnhance:AddAddonInfo(tooltip, playerName)
    if not playerName then return end
    
    -- Prevent duplicate entries - check if we already added info for this player
    local now = GetTime()
    if self.lastTooltipTarget == playerName:lower() and (now - self.lastTooltipUpdate) < 0.2 then
        return
    end
    
    -- Also check if tooltip already has AllforOne info
    if self:TooltipHasBRInfo(tooltip) then
        return
    end
    
    self.lastTooltipTarget = playerName:lower()
    self.lastTooltipUpdate = now
    
    -- Add faction background (will be set with unit in HookTooltip)
    
    local users = AllforOneDB and AllforOneDB.AddonUsers or {}
    local info = users[playerName:lower()]
    
    tooltip:AddLine(" ")
    tooltip:AddLine("|cFF00CCFFAllforOne Addon:|r", 0.4, 0.8, 1)
    
    if info then
        local statusText = info.status == "ENABLED" and "|cFF00FF00Aktiv|r" or "|cFFFFAA00Inaktiv|r"
        local versionText = info.version and ("v" .. info.version) or ""
        tooltip:AddLine("Status: " .. statusText .. " " .. versionText, 1, 1, 1)
        if info.lastSeen then
            local timeSince = GetTime() - info.lastSeen
            if timeSince < 60 then
                tooltip:AddLine("Zuletzt gesehen: Gerade eben", 0.6, 0.6, 0.6)
            elseif timeSince < 3600 then
                tooltip:AddLine("Zuletzt gesehen: vor " .. math.floor(timeSince/60) .. " Min", 0.6, 0.6, 0.6)
            end
        end
    else
        tooltip:AddLine("Status: |cFF888888Nicht installiert|r", 0.6, 0.6, 0.6)
    end
end

function TooltipEnhance:HookTooltip()
    if self.hooked then return end
    self.hooked = true
    
    -- Hook tooltip hide to remove faction background
    GameTooltip:HookScript("OnHide", function()
        TooltipEnhance:HideFactionBackground()
    end)
    
    -- Use TooltipDataProcessor for retail (modern API)
    if TooltipDataProcessor then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, function(tooltip, data)
            -- Sichere Prüfungen um Fehler zu vermeiden
            if not tooltip or tooltip ~= GameTooltip then return end
            
            -- Verwende pcall für alle Unit-Operationen um "secret value" Fehler zu vermeiden
            local unit
            local success = pcall(function()
                local _, u = tooltip:GetUnit()
                if u and UnitExists(u) and UnitIsPlayer(u) then
                    unit = u
                end
            end)
            
            if not success or not unit then return end
            
            local playerName = UnitName(unit)
            if not playerName then return end
            
            -- Check if in same guild (alles in pcall um Fehler zu vermeiden)
            local isInMyGuild, unitGuild, myGuild
            pcall(function()
                isInMyGuild = UnitIsInMyGuild(unit)
                unitGuild = GetGuildInfo(unit)
                myGuild = GetGuildInfo("player")
            end)
            
            if isInMyGuild or (unitGuild and myGuild and unitGuild == myGuild) then
                -- Same guild - show addon status and faction background
                self:SetFactionBackground(tooltip, unit)
                self:AddAddonInfo(tooltip, playerName)
            elseif unitGuild then
                -- Different guild
                tooltip:AddLine(" ")
                tooltip:AddLine("|cFFFF6600[Andere Gilde: " .. unitGuild .. "]|r", 1, 0.4, 0)
            elseif not isInMyGuild then
                -- No guild (nur anzeigen wenn wir sicher sind dass sie nicht in unserer Gilde sind)
                tooltip:AddLine(" ")
                tooltip:AddLine("|cFF888888[Keine Gilde]|r", 0.5, 0.5, 0.5)
            end
        end)
        BR:Debug("TooltipEnhance: TooltipDataProcessor hooked")
    else
        BR:Debug("TooltipEnhance: TooltipDataProcessor not available")
    end
end

-- Hook guild roster frame for member tooltips
function TooltipEnhance:HookGuildRoster()
    -- Hook when Blizzard_Communities addon loads (retail guild UI)
    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("ADDON_LOADED")
    eventFrame:SetScript("OnEvent", function(_, event, arg1)
        if arg1 == "Blizzard_Communities" then
            TooltipEnhance:HookCommunitiesFrame()
        elseif arg1 == "Blizzard_GuildUI" then
            TooltipEnhance:HookGuildFrame()
        end
    end)
    
    -- Try to hook immediately if already loaded
    if CommunitiesFrame then
        self:HookCommunitiesFrame()
    end
    if GuildFrame then
        self:HookGuildFrame()
    end
end

-- Hook the Communities frame (retail guild UI)
function TooltipEnhance:HookCommunitiesFrame()
    if self.communitiesHooked then return end
    if not CommunitiesFrame then return end
    self.communitiesHooked = true
    
    -- Hook the member list tooltip using ScrollBox (modern retail API)
    if CommunitiesFrame.MemberList and CommunitiesFrame.MemberList.ScrollBox then
        local scrollBox = CommunitiesFrame.MemberList.ScrollBox
        
        -- Hook when frames are acquired from the pool
        scrollBox:RegisterCallback("OnAcquiredFrame", function(_, frame)
            if frame and not frame.brHooked then
                frame.brHooked = true
                frame:HookScript("OnEnter", function(btn)
                    local ok, memberInfo = pcall(function() return btn.memberInfo end)
                    if ok and memberInfo and memberInfo.name then
                        local name = memberInfo.name
                        local shortName = strsplit("-", name)
                        TooltipEnhance.lastGuildMember = shortName
                        
                        C_Timer.After(0.05, function()
                            if GameTooltip:IsShown() and TooltipEnhance.lastGuildMember then
                                -- Parse faction from tooltip text (most reliable)
                                local memberFaction = TooltipEnhance:GetFactionFromTooltip(GameTooltip)
                                TooltipEnhance:SetFactionBackground(GameTooltip, memberFaction or UnitFactionGroup("player"))
                                TooltipEnhance:AddAddonInfo(GameTooltip, TooltipEnhance.lastGuildMember)
                                GameTooltip:Show()
                            end
                        end)
                    end
                end)
                frame:HookScript("OnLeave", function()
                    TooltipEnhance.lastGuildMember = nil
                    TooltipEnhance.lastTooltipTarget = nil
                end)
            end
        end, self)
    end
    
    BR:Debug("TooltipEnhance: CommunitiesFrame hooked")
end

-- Hook the old guild frame (if used)
function TooltipEnhance:HookGuildFrame()
    if self.guildFrameHooked then return end
    if not GuildFrame then return end
    self.guildFrameHooked = true
    
    -- Hook GuildRoster button tooltips
    hooksecurefunc("GuildRoster_Update", function()
        local scrollFrame = GuildRosterContainer
        if not scrollFrame then return end
        
        for _, button in pairs(scrollFrame.buttons or {}) do
            if button and not button.brHooked then
                button.brHooked = true
                button:HookScript("OnEnter", function(self)
                    if self.guildIndex then
                        local name = GetGuildRosterInfo(self.guildIndex)
                        if name then
                            local shortName = strsplit("-", name)
                            C_Timer.After(0.05, function()
                                if GameTooltip:IsShown() then
                                    -- Use player faction since guild members are same faction
                                    TooltipEnhance:SetFactionBackground(GameTooltip, "player")
                                    TooltipEnhance:AddAddonInfo(GameTooltip, shortName)
                                    GameTooltip:Show()
                                end
                            end)
                        end
                    end
                end)
            end
        end
    end)
    
    BR:Debug("TooltipEnhance: GuildFrame hooked")
end

BR:RegisterModule("TooltipEnhance", TooltipEnhance)
