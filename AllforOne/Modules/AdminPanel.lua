----------------------------------------------------------------------
--  All for One - Addon Overview Module
--  Shows which guild members have the addon installed and active
----------------------------------------------------------------------

local addonName, BR = ...

local AdminPanel = {
    frame = nil,
    scrollFrame = nil,
    contentFrame = nil,
    searchBox = nil,
    searchQuery = "",
    headerButtons = {},
    sortColumn = "name",
    sortAscending = true,
}
local indicatorIcons = {
    up = "|TInterface\\Buttons\\Arrow-Up-Up:10:10:0:0|t",
    down = "|TInterface\\Buttons\\Arrow-Down-Down:10:10:0:0|t",
}

-- Helper function to create gold-styled button
local function CreateGoldButton(parent, width, height, text)
    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    btn:SetSize(width, height)
    btn:SetBackdrop({
        bgFile = "Interface\\BUTTONS\\WHITE8X8",
        edgeFile = "Interface\\BUTTONS\\WHITE8X8",
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    btn:SetBackdropColor(0.15, 0.12, 0.08, 0.95)
    btn:SetBackdropBorderColor(0.796, 0.71, 0.482, 1)
    local btnText = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    btnText:SetPoint("CENTER")
    btnText:SetText(text)
    btnText:SetTextColor(0.796, 0.71, 0.482, 1)
    btn.text = btnText
    btn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(0.25, 0.2, 0.12, 1)
        self:SetBackdropBorderColor(1, 0.9, 0.6, 1)
        self.text:SetTextColor(1, 0.9, 0.6, 1)
    end)
    btn:SetScript("OnLeave", function(self)
        self:SetBackdropColor(0.15, 0.12, 0.08, 0.95)
        self:SetBackdropBorderColor(0.796, 0.71, 0.482, 1)
        self.text:SetTextColor(0.796, 0.71, 0.482, 1)
    end)
    return btn
end

local function CompareStrings(a, b)
    a = a or ""
    b = b or ""
    if a == b then
        return 0
    elseif a < b then
        return -1
    else
        return 1
    end
end

local function BuildGuildMemberList()
    local members = {}
    local numMembers = GetNumGuildMembers()
    
    for i = 1, numMembers do
        local fullName, rankName, rankIndex, level, classDisplayName, zone, 
              publicNote, officerNote, isOnline, status, classFileName, 
              achievementPoints, achievementRank, isMobile, canSoR, repStanding, guid = GetGuildRosterInfo(i)
        if fullName then
            local shortName = strsplit("-", fullName)
            local years, months, days, hours = GetGuildRosterLastOnline(i)
            local lastOnlineSeconds
            if not isOnline and years ~= nil then
                lastOnlineSeconds = (((((years or 0) * 12 + (months or 0)) * 30) + (days or 0)) * 24 + (hours or 0)) * 3600
            elseif isOnline then
                lastOnlineSeconds = 0
            end
            table.insert(members, {
                shortName = shortName,
                displayName = fullName,
                isOnline = isOnline or false,
                isMobile = isMobile or false,
                level = level,
                class = classDisplayName,
                classFileName = classFileName,
                rank = rankName,
                rankIndex = rankIndex,
                zone = zone,
                publicNote = publicNote,
                officerNote = officerNote,
                achievementPoints = achievementPoints,
                lastOnlineSeconds = lastOnlineSeconds,
                guid = guid,
            })
        end
    end
    
    table.sort(members, function(a, b)
        if a.isOnline == b.isOnline then
            return (a.shortName or ""):lower() < (b.shortName or ""):lower()
        end
        return a.isOnline and not b.isOnline
    end)
    
    return members
end

local function FormatRelativeTime(seconds)
    if seconds == nil then
        return "-"
    end
    if seconds <= 0 then
        return "Online"
    end
    local minutes = math.floor(seconds / 60)
    if minutes < 1 then
        return "Gerade eben"
    end
    if minutes < 60 then
        return minutes .. " Min."
    end
    local hours = math.floor(minutes / 60)
    if hours < 24 then
        return hours .. " Std."
    end
    local days = math.floor(hours / 24)
    if days < 30 then
        return days .. " Tage"
    end
    local months = math.floor(days / 30)
    if months < 12 then
        return months .. " Monate"
    end
    local years = math.floor(months / 12)
    return years .. " Jahre"
end

function AdminPanel:UpdateHeaderSortIndicators()
    if not self.headerButtons then return end
    for column, button in pairs(self.headerButtons) do
        if button.text and button.label then
            local indicator = ""
            if self.sortColumn == column then
                indicator = self.sortAscending and (" " .. indicatorIcons.up) or (" " .. indicatorIcons.down)
            end
            button.text:SetText(button.label .. indicator)
        end
    end
end

function AdminPanel:SortEntries(entries)
    table.sort(entries, function(a, b)
        if a.member.isOnline ~= b.member.isOnline then
            return a.member.isOnline and not b.member.isOnline
        end
        
        local column = self.sortColumn or "name"
        local cmp = 0
        
        if column == "status" then
            cmp = (a.statusSort or 0) - (b.statusSort or 0)
        elseif column == "version" then
            cmp = CompareStrings(a.versionLower, b.versionLower)
        elseif column == "lastSeen" then
            cmp = (a.lastSeenValue or 0) - (b.lastSeenValue or 0)
        elseif column == "lastOnline" then
            cmp = (a.lastOnlineValue or math.huge) - (b.lastOnlineValue or math.huge)
        else
            cmp = CompareStrings(a.displayNameLower, b.displayNameLower)
            if cmp == 0 then
                cmp = CompareStrings(a.shortNameLower, b.shortNameLower)
            end
        end
        
        if cmp == 0 then
            cmp = CompareStrings(a.displayNameLower, b.displayNameLower)
            if cmp == 0 then
                cmp = CompareStrings(a.shortNameLower, b.shortNameLower)
            end
        end
        
        if cmp == 0 then
            return false
        end
        
        if self.sortAscending then
            return cmp < 0
        else
            return cmp > 0
        end
    end)
end

function AdminPanel:OnInitialize()
    BR:Debug("AdminPanel module initialized")
end

function AdminPanel:OnEnable()
    BR:Debug("AdminPanel enabled")
end

function AdminPanel:OnDisable()
    if self.frame then
        self.frame:Hide()
    end
end

function AdminPanel:SetSortColumn(column)
    if self.sortColumn == column then
        self.sortAscending = not self.sortAscending
    else
        self.sortColumn = column
        self.sortAscending = true
    end
    self:UpdateHeaderSortIndicators()
    self:UpdateMemberList()
end

function AdminPanel:Refresh()
    if self.frame and self.frame:IsShown() then
        self:UpdateMemberList()
    end
end

function BR:OpenAddonOverview()
    AdminPanel:Show()
end

function BR:OpenAdminPanel()
    AdminPanel:Show()
end

function AdminPanel:ShowCharacterDetails(member, info, hasAddon, isEnabled)
    -- Create or reuse detail frame
    if not self.detailFrame then
        local frame = CreateFrame("Frame", "AllforOneCharacterDetail", UIParent, "BackdropTemplate")
        frame:SetSize(320, 380)
        frame:SetPoint("CENTER", 200, 0)
        frame:SetMovable(true)
        frame:EnableMouse(true)
        frame:RegisterForDrag("LeftButton")
        frame:SetScript("OnDragStart", frame.StartMoving)
        frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
        frame:SetFrameStrata("DIALOG")
        frame:SetFrameLevel(150)
        frame:SetClampedToScreen(true)
        
        frame:SetBackdrop(BR.Backdrops.Window)
        frame:SetBackdropColor(0.08, 0.08, 0.08, 0.98)
        frame:SetBackdropBorderColor(unpack(BR.UI.DefaultBorderColor))
        
        local closeBtn = CreateGoldButton(frame, 28, 28, "x")
        closeBtn:SetPoint("TOPRIGHT", -12, -12)
        closeBtn:SetScript("OnClick", function() frame:Hide() end)
        
        local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        title:SetPoint("TOP", 0, -15)
        frame.title = title
        
        -- Content area
        local content = CreateFrame("Frame", nil, frame)
        content:SetPoint("TOPLEFT", 20, -45)
        content:SetPoint("BOTTOMRIGHT", -20, 50)
        frame.content = content
        
        -- Close button at bottom (gold-styled)
        local saveBtn = CreateGoldButton(frame, 120, 28, "Schließen")
        saveBtn:SetPoint("BOTTOM", 0, 15)
        saveBtn:SetScript("OnClick", function() frame:Hide() end)
        frame.saveBtn = saveBtn
        
        frame:Hide()
        tinsert(UISpecialFrames, "AllforOneCharacterDetail")
        self.detailFrame = frame
    end
    
    local frame = self.detailFrame
    local content = frame.content
    
    -- Clear previous content
    for _, child in pairs({content:GetChildren()}) do
        child:Hide()
        child:SetParent(nil)
    end
    for _, region in pairs({content:GetRegions()}) do
        region:Hide()
    end
    
    -- Set title with class color
    local classColor = member.classFileName and RAID_CLASS_COLORS[member.classFileName]
    local nameColor = classColor and string.format("|cFF%02x%02x%02x", classColor.r * 255, classColor.g * 255, classColor.b * 255) or "|cFFFFFFFF"
    frame.title:SetText(nameColor .. (member.displayName or member.shortName or "?") .. "|r")
    
    local yOffset = 0
    local isOfficer = BR:IsGuildOfficer()
    
    -- Character info section
    local infoTitle = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    infoTitle:SetPoint("TOPLEFT", 0, yOffset)
    infoTitle:SetText(BR.Colors.White .. "Charakter-Info:|r")
    yOffset = yOffset - 20
    
    local infoText = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    infoText:SetPoint("TOPLEFT", 0, yOffset)
    infoText:SetWidth(280)
    infoText:SetJustifyH("LEFT")
    local infoLines = {
        "Level: " .. (member.level or "?"),
        "Klasse: " .. (member.class or "?"),
        "Rang: " .. (member.rank or "?"),
        "Zone: " .. (member.zone ~= "" and member.zone or "-"),
        "Status: " .. (member.isOnline and (member.isMobile and "Online (Mobile)" or "Online") or "Offline"),
    }
    infoText:SetText(table.concat(infoLines, "\n"))
    yOffset = yOffset - 80
    
    -- Addon Status
    local addonTitle = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    addonTitle:SetPoint("TOPLEFT", 0, yOffset)
    addonTitle:SetText(BR.Colors.White .. "Addon-Status:|r")
    yOffset = yOffset - 20
    
    local users = AllforOneDB.AddonUsers or {}
    local info = users[member.shortName] or users[(member.shortName or ""):lower()]
    local addonStatusText = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    addonStatusText:SetPoint("TOPLEFT", 5, yOffset)
    if info then
        local statusColor = info.status == "ENABLED" and BR.Colors.Primary or BR.Colors.Warning
        addonStatusText:SetText(statusColor .. (info.status == "ENABLED" and "Aktiv" or "Inaktiv") .. "|r" .. 
            (info.version and (" (v" .. info.version .. ")") or ""))
    else
        addonStatusText:SetText("|cFF888888Kein Addon|r")
    end
    yOffset = yOffset - 35
    
    -- Reset Warning button for officers (gold-styled)
    local resetBtn = CreateGoldButton(content, 220, 26, "Warnung zurücksetzen")
    resetBtn:SetPoint("TOPLEFT", 0, yOffset)
    resetBtn:SetScript("OnClick", function()
        local targetName = member.shortName or member.displayName
        if targetName then
            BR:SendAddonMessage("RESET_WARNING:" .. targetName, "GUILD")
            BR:Print("Reset-Befehl für " .. targetName .. " gesendet.", "info")
        end
    end)
    resetBtn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(0.25, 0.2, 0.12, 1)
        self:SetBackdropBorderColor(1, 0.9, 0.6, 1)
        self.text:SetTextColor(1, 0.9, 0.6, 1)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Warnung zurücksetzen", 1, 1, 1)
        GameTooltip:AddLine("Setzt die Sicherheitswarnung für diesen Spieler zurück.", 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    resetBtn:SetScript("OnLeave", function(self)
        self:SetBackdropColor(0.15, 0.12, 0.08, 0.95)
        self:SetBackdropBorderColor(0.796, 0.71, 0.482, 1)
        self.text:SetTextColor(0.796, 0.71, 0.482, 1)
        GameTooltip:Hide()
    end)
    frame.saveBtn:SetScript("OnClick", function()
        frame:Hide()
    end)
    
    frame:Show()
end

function AdminPanel:CreateFrame()
    if self.frame then return end
    
    -- Close config panel if open to avoid overlap
    if AllforOneConfigPanel and AllforOneConfigPanel:IsShown() then
        AllforOneConfigPanel:Hide()
    end
    
    -- Main frame
    local frame = CreateFrame("Frame", "AllforOneAdminPanel", UIParent, "BackdropTemplate")
    frame:SetSize(600, 480)
    frame:SetPoint("CENTER", 0, 50)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetFrameStrata("HIGH")
    frame:SetFrameLevel(100)
    frame:SetClampedToScreen(true)
    
    frame:SetBackdrop(BR.Backdrops.Window)
    frame:SetBackdropColor(0.08, 0.08, 0.08, 0.98)
    frame:SetBackdropBorderColor(unpack(BR.UI.DefaultBorderColor))
    
    -- Title
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -16)
    title:SetText(BR.Colors.Guild .. "All for One - Offizier Übersicht|r")
    
    -- Subtitle with guild name
    local subtitle = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    subtitle:SetPoint("TOP", title, "BOTTOM", 0, -4)
    subtitle:SetText("Gilde: " .. (BR:GetGuildName() or "Unbekannt"))
    self.subtitleText = subtitle
    
    -- Close button (gold-styled x)
    local closeBtn = CreateGoldButton(frame, 28, 28, "x")
    closeBtn:SetPoint("TOPRIGHT", -12, -12)
    closeBtn:SetScript("OnClick", function()
        frame:Hide()
    end)
    
    -- Refresh button (gold-styled)
    local refreshBtn = CreateGoldButton(frame, 120, 26, "Aktualisieren")
    refreshBtn:SetPoint("TOPRIGHT", closeBtn, "BOTTOMLEFT", -5, -5)
    refreshBtn:SetScript("OnClick", function()
        BR:PingGuildMembers()
    end)
    
    -- Search box
    local searchBox = CreateFrame("EditBox", "AllforOneAdminSearchBox", frame, "InputBoxTemplate")
    searchBox:SetSize(260, 24)
    searchBox:SetPoint("TOPLEFT", 20, -60)
    searchBox:SetAutoFocus(false)
    searchBox:SetScript("OnTextChanged", function(self)
        AdminPanel.searchQuery = self:GetText() or ""
        AdminPanel:UpdateMemberList()
    end)
    self.searchBox = searchBox
    
    local searchLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    searchLabel:SetPoint("BOTTOMLEFT", searchBox, "TOPLEFT", 2, 0)
    searchLabel:SetText("Suche (Name):")
    
    -- Column headers
    local headerBg = frame:CreateTexture(nil, "BACKGROUND")
    headerBg:SetPoint("TOPLEFT", 15, -100)
    headerBg:SetSize(570, 24)
    headerBg:SetColorTexture(0.2, 0.2, 0.2, 0.8)
    
    local function CreateHeaderButton(key, label, width, anchor)
        local button = CreateFrame("Button", nil, frame)
        button:SetSize(width, 22)
        if anchor then
            button:SetPoint("LEFT", anchor, "RIGHT", 0, 0)
        else
            button:SetPoint("TOPLEFT", headerBg, "TOPLEFT", 10, 0)
        end
        
        button.text = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        button.text:SetPoint("CENTER")
        button.text:SetJustifyH("CENTER")
        button.text:SetText(label)
        button.label = label
        
        button:SetScript("OnClick", function()
            AdminPanel:SetSortColumn(key)
        end)
        
        self.headerButtons[key] = button
        return button
    end
    
    local colWidths = { name = 140, status = 80, version = 60, lastSeen = 90, lastOnline = 90 }
    self.colWidths = colWidths
    
    local headerName = CreateHeaderButton("name", "Spieler", colWidths.name)
    local headerStatus = CreateHeaderButton("status", "Status", colWidths.status, headerName)
    local headerVersion = CreateHeaderButton("version", "Version", colWidths.version, headerStatus)
    local headerLastSeen = CreateHeaderButton("lastSeen", "Gepingt", colWidths.lastSeen, headerVersion)
    local headerLastOnline = CreateHeaderButton("lastOnline", "Online", colWidths.lastOnline, headerLastSeen)
    
    -- Scroll frame for member list
    local scrollFrame = CreateFrame("ScrollFrame", "AllforOneAdminScrollFrame", frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 15, -125)
    scrollFrame:SetPoint("BOTTOMRIGHT", -35, 55)
    
    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(540, 1)
    scrollFrame:SetScrollChild(scrollChild)
    
    self.scrollFrame = scrollFrame
    self.contentFrame = scrollChild
    self.frame = frame
    
    -- Stats at bottom
    local statsText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    statsText:SetPoint("BOTTOM", 0, 32)
    statsText:SetText("Statistiken werden geladen...")
    self.statsText = statsText
    
    frame:Hide()
    
    -- Stop auto-refresh when frame is hidden
    frame:SetScript("OnHide", function()
        AdminPanel:StopAutoRefresh()
    end)
    
    -- Make closable with Escape
    tinsert(UISpecialFrames, "AllforOneAdminPanel")
end

function AdminPanel:Show()
    -- Only officers can access this panel
    -- Warte auf Guild-Daten falls noch nicht bereit
    if not BR:IsGuildDataReady() then
        BR:Print("Guild-Daten werden noch geladen. Bitte versuche es in wenigen Sekunden erneut.", "warning")
        return
    end
    if not BR:IsGuildOfficer() then
        BR:Print("Die Offizier-Übersicht ist nur für Gildenoffiziere verfügbar.", "warning")
        return
    end
    
    if not self.frame then
        self:CreateFrame()
    end
    
    -- Close config panel if open
    if AllforOneConfigPanel and AllforOneConfigPanel:IsShown() then
        AllforOneConfigPanel:Hide()
    end
    
    -- Request status from guild
    BR:PingGuildMembers()
    
    self:UpdateMemberList()
    self.frame:Show()
    self.frame:Raise()
    
    -- Start auto-refresh timer (every 2 seconds while panel is open)
    self:StartAutoRefresh()
end

function AdminPanel:StartAutoRefresh()
    if self.refreshTimer then return end
    
    self.refreshTimer = C_Timer.NewTicker(2, function()
        if self.frame and self.frame:IsShown() then
            self:UpdateMemberList()
        else
            self:StopAutoRefresh()
        end
    end)
end

function AdminPanel:StopAutoRefresh()
    if self.refreshTimer then
        self.refreshTimer:Cancel()
        self.refreshTimer = nil
    end
end

function AdminPanel:UpdateMemberList()
    if not self.contentFrame then return end
    
    -- Clear existing entries
    for _, child in pairs({self.contentFrame:GetChildren()}) do
        child:Hide()
        child:SetParent(nil)
    end
    
    if not BR:IsInGuild() then
        if self.statsText then
            self.statsText:SetText("Keine Gilde erkannt - Übersicht nur innerhalb einer Gilde verfügbar.")
        end
        local emptyText = self.contentFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        emptyText:SetPoint("CENTER", 0, 0)
        emptyText:SetText("Du musst Mitglied einer Gilde sein,\num Addon-Benutzer zu sehen.")
        emptyText:SetJustifyH("CENTER")
        self.contentFrame:SetHeight(50)
        return
    end
    
    local users = AllforOneDB.AddonUsers or {}
    local guildMembers = BuildGuildMemberList()
    local yOffset = 0
    local rowHeight = 24
    local enabledCount = 0
    local addonInstalledCount = 0
    local onlineCount = 0
    local totalMembers = #guildMembers
    
    local memberEntries = {}
    
    for index, member in ipairs(guildMembers) do
        local info = users[member.shortName or member.displayName]
        if not info and member.shortName then
            info = users[(member.shortName or ""):lower()]
        end
        if not info and member.displayName then
            info = users[(member.displayName or ""):lower()]
        end
        local hasAddon = info ~= nil
        local isEnabled = hasAddon and info.status == "ENABLED"
        
        if member.isOnline then
            onlineCount = onlineCount + 1
        end
        if hasAddon then
            addonInstalledCount = addonInstalledCount + 1
        end
        if isEnabled then
            enabledCount = enabledCount + 1
        end
        
        local displayName = member.displayName or member.shortName or "?"
        local shortNameLower = (member.shortName and member.shortName:lower()) or (displayName and displayName:lower())
        
        table.insert(memberEntries, {
            member = member,
            info = info,
            hasAddon = hasAddon,
            isEnabled = isEnabled,
            statusSort = hasAddon and (isEnabled and 2 or 1) or 0,
            displayNameLower = displayName:lower(),
            shortNameLower = shortNameLower or "",
            versionLower = (info and info.version and info.version:lower()) or "",
            lastSeenValue = (info and info.lastSeen) or 0,
            lastOnlineValue = member.lastOnlineSeconds,
        })
    end
    
    -- Apply search filter
    local filteredEntries = {}
    local query = (self.searchQuery or ""):lower()
    for _, entry in ipairs(memberEntries) do
        if query == "" or string.find(entry.displayNameLower, query, 1, true) or string.find(entry.shortNameLower, query, 1, true) then
            table.insert(filteredEntries, entry)
        end
    end
    
    self:SortEntries(filteredEntries)
    
    for index, entry in ipairs(filteredEntries) do
        local member = entry.member
        local info = entry.info
        local hasAddon = entry.hasAddon
        local isEnabled = entry.isEnabled
        local rowFrame = CreateFrame("Frame", nil, self.contentFrame, "BackdropTemplate")
        rowFrame:SetSize(560, rowHeight)
        rowFrame:SetPoint("TOPLEFT", 0, -yOffset)
        rowFrame:EnableMouse(true)
        
        if index % 2 == 0 then
            rowFrame:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8x8"})
            rowFrame:SetBackdropColor(0.15, 0.15, 0.15, 0.5)
        end
        
        -- Tooltip on hover (anchored to right of row)
        rowFrame:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT", 10, 0)
            GameTooltip:ClearLines()
            
            -- Name with class color
            local classColor = member.classFileName and RAID_CLASS_COLORS[member.classFileName]
            local nameColor = classColor and string.format("|cFF%02x%02x%02x", classColor.r * 255, classColor.g * 255, classColor.b * 255) or "|cFFFFFFFF"
            GameTooltip:AddLine(nameColor .. (member.displayName or member.shortName or "?") .. "|r", 1, 1, 1)
            
            GameTooltip:AddLine(" ")
            
            -- Level & Class
            if member.level then
                GameTooltip:AddDoubleLine("Level:", tostring(member.level), 0.7, 0.7, 0.7, 1, 1, 1)
            end
            if member.class then
                local classColorText = classColor and string.format("|cFF%02x%02x%02x%s|r", classColor.r * 255, classColor.g * 255, classColor.b * 255, member.class) or member.class
                GameTooltip:AddDoubleLine("Klasse:", classColorText, 0.7, 0.7, 0.7)
            end
            
            -- Rank
            if member.rank then
                GameTooltip:AddDoubleLine("Rang:", member.rank, 0.7, 0.7, 0.7, 1, 0.82, 0)
            end
            
            -- Zone
            if member.zone and member.zone ~= "" then
                GameTooltip:AddDoubleLine("Zone:", member.zone, 0.7, 0.7, 0.7, 0.5, 1, 0.5)
            end
            
            -- Online status
            if member.isOnline then
                if member.isMobile then
                    GameTooltip:AddDoubleLine("Status:", "Online (Mobile App)", 0.7, 0.7, 0.7, 0, 0.8, 1)
                else
                    GameTooltip:AddDoubleLine("Status:", "Online", 0.7, 0.7, 0.7, 0, 1, 0)
                end
            else
                GameTooltip:AddDoubleLine("Status:", "Offline", 0.7, 0.7, 0.7, 0.5, 0.5, 0.5)
            end
            
            -- Achievement Points
            if member.achievementPoints and member.achievementPoints > 0 then
                GameTooltip:AddDoubleLine("Erfolgspunkte:", tostring(member.achievementPoints), 0.7, 0.7, 0.7, 1, 1, 0)
            end
            
            -- Public Note
            if member.publicNote and member.publicNote ~= "" then
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine("Notiz: " .. member.publicNote, 0.8, 0.8, 0.6, true)
            end
            
            -- Addon info
            if hasAddon then
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine("All for One:", 0, 0.8, 1)
                GameTooltip:AddDoubleLine("  Version:", info.version or "?", 0.7, 0.7, 0.7, 1, 1, 1)
                GameTooltip:AddDoubleLine("  Status:", isEnabled and "Aktiv" or "Inaktiv", 0.7, 0.7, 0.7, isEnabled and 0 or 1, isEnabled and 1 or 0.5, 0)
            elseif member.isOnline then
                -- Check if player might be in an instance (zone contains instance-like keywords)
                local zone = member.zone or ""
                local mightBeInInstance = zone:find("%-") or zone == "" or 
                    zone:find("Mythic") or zone:find("Heroic") or zone:find("Raid") or
                    zone:find("Arena") or zone:find("Schlachtfeld") or zone:find("Battleground")
                if mightBeInInstance or zone == "" then
                    GameTooltip:AddLine(" ")
                    GameTooltip:AddLine("|cFFFFFF00Hinweis:|r Spieler in Instanzen können", 0.8, 0.8, 0.5, true)
                    GameTooltip:AddLine("möglicherweise nicht antworten.", 0.8, 0.8, 0.5, true)
                end
            end
            
            GameTooltip:Show()
        end)
        rowFrame:SetScript("OnLeave", function(self)
            GameTooltip:Hide()
        end)
        
        -- Click to open character details
        rowFrame:SetScript("OnMouseDown", function(self, button)
            if button == "LeftButton" then
                AdminPanel:ShowCharacterDetails(member, info, hasAddon, isEnabled)
            end
        end)
        
        local colWidths = AdminPanel.colWidths
        
        -- Player name
        local nameText = rowFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        nameText:SetPoint("LEFT", 5, 0)
        nameText:SetWidth(colWidths.name - 10)
        nameText:SetJustifyH("LEFT")
        nameText:SetWordWrap(false)
        local displayName = member.displayName or member.shortName or "?"
        local classColor = member.classFileName and RAID_CLASS_COLORS[member.classFileName]
        if member.isOnline and classColor then
            nameText:SetText(string.format("|cFF%02x%02x%02x%s|r", classColor.r * 255, classColor.g * 255, classColor.b * 255, displayName))
        elseif member.isOnline then
            nameText:SetText(BR.Colors.Primary .. displayName .. "|r")
        else
            nameText:SetText("|cFF666666" .. displayName .. "|r")
        end
        
        -- Status (addon state)
        local statusText = rowFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        statusText:SetPoint("LEFT", nameText, "RIGHT", 5, 0)
        statusText:SetWidth(colWidths.status - 5)
        statusText:SetJustifyH("CENTER")
        if not hasAddon then
            statusText:SetText("|cFF888888Kein Addon|r")
        elseif isEnabled then
            statusText:SetText(BR.Colors.Primary .. "Aktiv|r")
        else
            statusText:SetText(BR.Colors.Warning .. "Inaktiv|r")
        end
        
        -- Version
        local versionText = rowFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        versionText:SetPoint("LEFT", statusText, "RIGHT", 5, 0)
        versionText:SetText((hasAddon and info.version) or "-")
        versionText:SetWidth(colWidths.version - 5)
        versionText:SetJustifyH("CENTER")
        
        -- Last seen (Zuletzt gepingt)
        local lastSeenText = rowFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        lastSeenText:SetPoint("LEFT", versionText, "RIGHT", 5, 0)
        lastSeenText:SetWidth(colWidths.lastSeen - 5)
        lastSeenText:SetJustifyH("CENTER")
        
        if hasAddon and info.lastSeen then
            local timeDiff = time() - info.lastSeen
            if timeDiff < 60 then
                lastSeenText:SetText("Gerade eben")
            elseif timeDiff < 3600 then
                lastSeenText:SetText(math.floor(timeDiff / 60) .. " Min.")
            elseif timeDiff < 86400 then
                lastSeenText:SetText(math.floor(timeDiff / 3600) .. " Std.")
            else
                lastSeenText:SetText(math.floor(timeDiff / 86400) .. " Tage")
            end
        else
            lastSeenText:SetText("-")
        end
        
        -- Last online (Zuletzt online)
        local lastOnlineText = rowFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        lastOnlineText:SetPoint("LEFT", lastSeenText, "RIGHT", 5, 0)
        lastOnlineText:SetWidth(colWidths.lastOnline - 5)
        lastOnlineText:SetJustifyH("CENTER")
        lastOnlineText:SetText(FormatRelativeTime(member.lastOnlineSeconds))
        
        yOffset = yOffset + rowHeight
    end
    
    -- Update content height
    self.contentFrame:SetHeight(math.max(yOffset, 1))
    
    -- Update stats
    if self.statsText then
        self.statsText:SetText(string.format(
            "Gilde: %s | Mitglieder: %d (%d online) | Addon aktiv: %s%d|r / Installiert: %d",
            BR:GetGuildName() or "-",
            totalMembers,
            onlineCount,
            BR.Colors.Primary, enabledCount,
            addonInstalledCount
        ))
    end
    
    -- Show message if no users
    if totalMembers == 0 then
        local emptyText = self.contentFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        emptyText:SetPoint("CENTER", 0, 0)
        emptyText:SetText("Keine Gildenmitglieder gefunden.\nKlicke auf 'Aktualisieren' um die Gilde zu pingen.")
        emptyText:SetJustifyH("CENTER")
    end
end

BR:RegisterModule("AdminPanel", AdminPanel)
