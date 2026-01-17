----------------------------------------------------------------------
--  All for One - Configuration UI
--  Settings panel for the addon
----------------------------------------------------------------------

local addonName, BR = ...

local Config = {
    frame = nil,
    checkboxes = {},
    infoLabels = {},
}

function BR:OpenConfig()
    Config:Show()
end

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

function Config:CreateFrame()
    if self.frame then return end
    
    local isGuildMaster = BR:IsGuildMaster()
    local isOfficer = BR:IsGuildOfficer()
    local frameHeight = (isGuildMaster or isOfficer) and 545 or 505
    
    -- Main frame
    local frame = CreateFrame("Frame", "AllforOneConfigPanel", UIParent, "BackdropTemplate")
    frame:SetSize(460, frameHeight)
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
    
    -- Close button (gold-styled x)
    local closeBtn = CreateGoldButton(frame, 28, 28, "x")
    closeBtn:SetPoint("TOPRIGHT", -12, -12)
    closeBtn:SetScript("OnClick", function() frame:Hide() end)
    
    -- Title
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -18)
    title:SetText(BR.Colors.Guild .. "All for One|r")
    
    -- Version
    local version = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    version:SetPoint("TOP", title, "BOTTOM", 0, -2)
    version:SetText("|cFF888888v" .. BR.Version .. " - wowfusion.de|r")
    
    -- Character & Guild info
    local infoText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    infoText:SetPoint("TOP", version, "BOTTOM", 0, -8)
    local playerName = UnitName("player")
    infoText:SetText(BR.Colors.White .. playerName .. "|r - " .. BR.Colors.Guild .. (BR:GetGuildName() or "Keine Gilde") .. "|r")
    
    -- Separator
    local sep1 = frame:CreateTexture(nil, "ARTWORK")
    sep1:SetPoint("TOP", infoText, "BOTTOM", 0, -10)
    sep1:SetSize(400, 1)
    sep1:SetColorTexture(0.796, 0.71, 0.482, 0.5)
    
    -- Content area
    local yOffset = -95
    
    -- Section title
    local sectionTitle = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    sectionTitle:SetPoint("TOPLEFT", 25, yOffset)
    if isGuildMaster then
        sectionTitle:SetText(BR.Colors.White .. "Blockierungen (Gildenmeister):|r")
    else
        sectionTitle:SetText(BR.Colors.White .. "Blockierungen:|r")
    end
    
    yOffset = yOffset - 22
    
    -- Feature settings
    local blockSettings = {
        {key = "BlockTrade", label = "Handel nur mit Gildenmitgliedern"},
        {key = "BlockGroupInvites", label = "Gruppeneinladungen nur von Gilde"},
        {key = "BlockLFG", label = "Dungeonbrowser/LFG blockieren"},
        {key = "BlockAuction", label = "Auktionshaus blockieren"},
        {key = "BlockCraftingOrders", label = "Handwerksaufträge einschränken"},
        {key = "BlockWarbound", label = "Warbound-Bank blockieren"},
        {key = "BlockMail", label = "Briefkasten einschränken"},
    }
    
    for _, setting in ipairs(blockSettings) do
        if isGuildMaster then
            local checkbox = self:CreateCheckbox(frame, setting.key, setting.label, "", true)
            checkbox:SetPoint("TOPLEFT", 25, yOffset)
        else
            local infoRow = self:CreateInfoLabel(frame, setting.key, setting.label, "")
            infoRow:SetPoint("TOPLEFT", 25, yOffset)
        end
        yOffset = yOffset - 24
    end
    
    -- Mail mode (guild master only)
    if isGuildMaster then
        yOffset = yOffset - 5
        local mailModeLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        mailModeLabel:SetPoint("TOPLEFT", 40, yOffset)
        mailModeLabel:SetText("Briefkasten-Modus:")
        
        local mailModeBtn = CreateGoldButton(frame, 170, 22, "")
        mailModeBtn:SetPoint("LEFT", mailModeLabel, "RIGHT", 10, 0)
        
        local function UpdateMailModeText()
            local mode = BR:GetSetting("MailBlockMode") or "selective"
            mailModeBtn.text:SetText(mode == "full" and "Komplett blockieren" or "Nur Fremde blockieren")
        end
        UpdateMailModeText()
        
        mailModeBtn:SetScript("OnClick", function()
            local current = BR:GetSetting("MailBlockMode") or "selective"
            local newMode = current == "full" and "selective" or "full"
            BR:SetSetting("MailBlockMode", newMode, true)
            UpdateMailModeText()
        end)
        
        yOffset = yOffset - 28
    end
    
    -- Separator
    local sep2 = frame:CreateTexture(nil, "ARTWORK")
    sep2:SetPoint("TOPLEFT", 25, yOffset - 5)
    sep2:SetSize(400, 1)
    sep2:SetColorTexture(0.796, 0.71, 0.482, 0.3)
    
    yOffset = yOffset - 20
    
    -- Other options
    local otherTitle = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    otherTitle:SetPoint("TOPLEFT", 25, yOffset)
    otherTitle:SetText(BR.Colors.White .. "Weitere Optionen:|r")
    
    yOffset = yOffset - 22
    
    local muteBox = self:CreateCheckbox(frame, "MuteNotificationSounds", "Benachrichtigungstöne deaktivieren", "")
    muteBox:SetPoint("TOPLEFT", 25, yOffset)
    
    yOffset = yOffset - 24
    
    local welcomeBox = self:CreateCheckbox(frame, "ShowWelcomeOnLogin", "Willkommensbildschirm beim Login", "")
    welcomeBox:SetPoint("TOPLEFT", 25, yOffset)
    
    yOffset = yOffset - 24
    
    local debugBox = self:CreateCheckbox(frame, "DebugMode", "Debug-Modus", "")
    debugBox:SetPoint("TOPLEFT", 25, yOffset)
    
    -- Bottom separator
    local sep3 = frame:CreateTexture(nil, "ARTWORK")
    sep3:SetPoint("BOTTOMLEFT", 25, 70)
    sep3:SetSize(400, 1)
    sep3:SetColorTexture(0.796, 0.71, 0.482, 0.5)
    
    -- Bottom buttons - Hauptmenü for all users
    local welcomeBtn = CreateGoldButton(frame, 200, 28, "Hauptmenü")
    welcomeBtn:SetPoint("BOTTOM", 0, 30)
    welcomeBtn:SetScript("OnClick", function()
        frame:Hide()
        BR:ShowWelcomeScreen()
    end)
    
    -- Officer/Guild master buttons below separator
    if isOfficer or isGuildMaster then
        local overviewBtn = CreateGoldButton(frame, 200, 28, "Offizier-Übersicht")
        overviewBtn:SetPoint("BOTTOMLEFT", 25, 30)
        overviewBtn:SetScript("OnClick", function()
            frame:Hide()
            BR:OpenAddonOverview()
        end)
        
        -- Only guild master can broadcast settings
        if isGuildMaster then
            local broadcastBtn = CreateGoldButton(frame, 200, 28, "Einstellungen senden")
            broadcastBtn:SetPoint("BOTTOMRIGHT", -25, 30)
            broadcastBtn:SetScript("OnClick", function()
                BR:BroadcastGuildSettings()
                BR:Print("Einstellungen an Gilde gesendet.", "info")
            end)
        end
        
        -- Move Hauptmenü to center row above
        welcomeBtn:ClearAllPoints()
        welcomeBtn:SetPoint("BOTTOM", 0, 70)
        welcomeBtn:SetSize(150, 28)
    end
    
    self.frame = frame
    
    -- OnShow handler
    frame:SetScript("OnShow", function()
        self:RefreshCheckboxes()
        if AllforOneAdminPanel and AllforOneAdminPanel:IsShown() then
            AllforOneAdminPanel:Hide()
        end
    end)
    
    tinsert(UISpecialFrames, "AllforOneConfigPanel")
end

function Config:CreateInfoLabel(parent, setting, label, tooltip)
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(340, 24)
    
    -- Status indicator (replaces checkbox)
    local indicator = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    indicator:SetPoint("LEFT", 0, 0)
    
    local value = BR:GetSetting(setting)
    if value then
        indicator:SetText(BR.Colors.Primary .. "[X]|r")
    else
        indicator:SetText("|cFF666666[ ]|r")
    end
    
    -- Label
    local text = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    text:SetPoint("LEFT", 25, 0)
    if value then
        text:SetText(label)
    else
        text:SetText("|cFF888888" .. label .. "|r")
    end
    
    row.indicator = indicator
    row.textLabel = text
    row.setting = setting
    
    -- Tooltip
    row:EnableMouse(true)
    row:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(label, 1, 1, 1)
        GameTooltip:AddLine(tooltip, nil, nil, nil, true)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Diese Einstellung wird von der Gildenleitung festgelegt.", 0.7, 0.7, 0.7, true)
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    
    self.infoLabels[setting] = row
    return row
end

function Config:CreateCheckbox(parent, setting, label, tooltip, isBlockingSetting)
    local check = CreateFrame("CheckButton", nil, parent, "InterfaceOptionsCheckButtonTemplate")
    
    check.Text:SetText("  " .. label)
    check.Text:SetFontObject("GameFontNormal")
    
    check.tooltipText = tooltip
    check.isBlockingSetting = isBlockingSetting
    
    check:SetScript("OnClick", function(self)
        local value = self:GetChecked()
        BR:SetSetting(setting, value, true)
        BR:RefreshModules()
        
        if setting == "Enabled" then
            if value then
                BR:EnableModules()
                BR:BroadcastStatus()
            else
                BR:DisableModules()
                BR:BroadcastStatus()
            end
        end
        
        -- If this is a blocking setting and user is guild master, broadcast to guild
        if self.isBlockingSetting and BR:IsGuildMaster() then
            BR:BroadcastGuildSettings()
        end
    end)
    
    check:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(label, 1, 1, 1)
        GameTooltip:AddLine(tooltip, nil, nil, nil, true)
        GameTooltip:Show()
    end)
    
    check:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    
    self.checkboxes[setting] = check
    return check
end

function Config:RefreshCheckboxes()
    for setting, checkbox in pairs(self.checkboxes) do
        local value = BR:GetSetting(setting)
        checkbox:SetChecked(value)
    end
    
    -- Also refresh info labels for non-officers
    for setting, row in pairs(self.infoLabels) do
        local value = BR:GetSetting(setting)
        if row.indicator then
            if value then
                row.indicator:SetText(BR.Colors.Primary .. "[X]|r")
            else
                row.indicator:SetText("|cFF666666[ ]|r")
            end
        end
        if row.textLabel then
            local label = row.textLabel:GetText():gsub("|cFF%x%x%x%x%x%x", ""):gsub("|r", "")
            if value then
                row.textLabel:SetText(label)
            else
                row.textLabel:SetText("|cFF888888" .. label .. "|r")
            end
        end
    end
end

function Config:Show()
    -- Recreate frame if guild master or officer status may have changed
    if self.frame then
        local wasGuildMaster = self.wasGuildMaster
        local wasOfficer = self.wasOfficer
        local isGuildMaster = BR:IsGuildMaster()
        local isOfficer = BR:IsGuildOfficer()
        if wasGuildMaster ~= isGuildMaster or wasOfficer ~= isOfficer then
            self.frame:Hide()
            self.frame = nil
            self.checkboxes = {}
            self.infoLabels = {}
        end
    end
    
    if not self.frame then
        self:CreateFrame()
        self.wasGuildMaster = BR:IsGuildMaster()
        self.wasOfficer = BR:IsGuildOfficer()
    end
    
    self:RefreshCheckboxes()
    self.frame:Show()
end

BR:RegisterModule("Config", Config)
