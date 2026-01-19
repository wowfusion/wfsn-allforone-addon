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
    -- Open WoW Interface Options -> AddOns -> AllforOne
    if Settings and Settings.OpenToCategory then
        if BR.settingsCategory then
            Settings.OpenToCategory(BR.settingsCategory:GetID())
        else
            -- Fallback: try to find by name
            Settings.OpenToCategory("AllforOne")
        end
    elseif InterfaceOptionsFrame_OpenToCategory then
        InterfaceOptionsFrame_OpenToCategory("AllforOne")
        InterfaceOptionsFrame_OpenToCategory("AllforOne") -- Call twice for subcategories
    end
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
    local frameHeight = (isGuildMaster or isOfficer) and 615 or 575
    
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
    
    yOffset = yOffset - 30
    
    -- GuildMap Pin-Größe Slider
    local pinSizeLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    pinSizeLabel:SetPoint("TOPLEFT", 25, yOffset)
    pinSizeLabel:SetText("Gildenkarten Pin-Größe:")
    
    local pinSizeValue = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    pinSizeValue:SetPoint("LEFT", pinSizeLabel, "RIGHT", 5, 0)
    
    local pinSizeSlider = CreateFrame("Slider", "AllforOnePinSizeSlider", frame, "OptionsSliderTemplate")
    pinSizeSlider:SetPoint("TOPLEFT", 25, yOffset - 18)
    pinSizeSlider:SetSize(200, 16)
    pinSizeSlider:SetMinMaxValues(16, 64)
    pinSizeSlider:SetValueStep(4)
    pinSizeSlider:SetObeyStepOnDrag(true)
    pinSizeSlider.Low:SetText("16")
    pinSizeSlider.High:SetText("64")
    pinSizeSlider.Text:SetText("")
    
    local currentSize = BR:GetSetting("GuildMapPinSize") or 32
    pinSizeSlider:SetValue(currentSize)
    pinSizeValue:SetText(currentSize)
    
    pinSizeSlider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value)
        pinSizeValue:SetText(value)
        BR:SetSetting("GuildMapPinSize", value, true)
        -- Pins neu zeichnen
        if BR.Modules.GuildMap then
            BR.Modules.GuildMap:RefreshAllPins()
        end
    end)
    
    yOffset = yOffset - 40
    
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

----------------------------------------------------------------------
--  Interface Options Panel Integration
----------------------------------------------------------------------

local function CreateInterfaceOptionsPanel()
    -- Create the main options panel for Interface Options
    local panel = CreateFrame("Frame", "AllforOneOptionsPanel", UIParent)
    panel.name = "AllforOne"
    
    -- Create scroll frame for content
    local scrollFrame = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 10, -10)
    scrollFrame:SetPoint("BOTTOMRIGHT", -26, 10)
    
    -- Style the scrollbar to be more minimal
    local scrollBar = scrollFrame.ScrollBar or _G[scrollFrame:GetName() .. "ScrollBar"]
    if scrollBar then
        scrollBar:ClearAllPoints()
        scrollBar:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -8, -30)
        scrollBar:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -8, 30)
        scrollBar:SetWidth(12)
    end
    
    -- Create scroll child (content container)
    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(620, 700)
    scrollFrame:SetScrollChild(scrollChild)
    
    -- Banner Logo (centered at top, correct aspect ratio ~5:1)
    local banner = scrollChild:CreateTexture(nil, "ARTWORK")
    banner:SetSize(500, 100) -- Correct aspect ratio for the banner (5:1)
    banner:SetPoint("TOP", 0, -10)
    banner:SetTexture("Interface\\AddOns\\AllforOne\\media\\banner-allforone.png")
    
    -- Version (below banner)
    local version = scrollChild:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    version:SetPoint("TOP", banner, "BOTTOM", 0, -5)
    version:SetText("|cff888888v" .. (BR.Version or "1.0.2") .. " - wowfusion.de|r")
    
    -- Character & Guild info (like in the main config panel)
    local charInfo = scrollChild:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    charInfo:SetPoint("TOP", version, "BOTTOM", 0, -5)
    local playerName = UnitName("player")
    local guildName = BR:GetGuildName() or "Keine Gilde"
    charInfo:SetText("|cffffffff" .. playerName .. "|r - |cffff6600" .. guildName .. "|r")
    
    -- Separator after banner
    local sepBanner = scrollChild:CreateTexture(nil, "ARTWORK")
    sepBanner:SetPoint("TOP", charInfo, "BOTTOM", 0, -10)
    sepBanner:SetSize(500, 1)
    sepBanner:SetColorTexture(0.796, 0.71, 0.482, 0.5)
    
    -- Description
    local desc = scrollChild:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    desc:SetPoint("TOP", sepBanner, "BOTTOM", 0, -15)
    desc:SetWidth(500)
    desc:SetJustifyH("CENTER")
    desc:SetText("Gilden-Management Addon für kontrolliertes Spielen.\nEinstellungen werden vom Gildenmeister festgelegt.")
    
    -- Separator
    local sep = scrollChild:CreateTexture(nil, "ARTWORK")
    sep:SetPoint("TOP", desc, "BOTTOM", 0, -15)
    sep:SetSize(500, 1)
    sep:SetColorTexture(0.5, 0.5, 0.5, 0.5)
    
    -- Status section
    local isGuildMaster = BR:IsGuildMaster()
    
    local statusTitle = scrollChild:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    statusTitle:SetPoint("TOPLEFT", sep, "LEFT", 16, -15)
    if isGuildMaster then
        statusTitle:SetText("|cffffffffBlockierungen (Gildenmeister):|r")
    else
        statusTitle:SetText("|cff888888Aktueller Status:|r")
    end
    
    local statusLabels = {}
    
    local function CreateStatusRow(parent, anchor, label, settingKey, yOff)
        -- Use real WoW checkbox with consistent font
        local check = CreateFrame("CheckButton", nil, parent, "InterfaceOptionsCheckButtonTemplate")
        check:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, yOff or -3)
        check:SetScale(1.0)
        
        -- Set consistent font for all checkboxes
        check.Text:SetFontObject("GameFontHighlight")
        check.Text:SetText(" " .. label)
        
        -- Gray out text for non-guild masters
        if isGuildMaster then
            check.Text:SetTextColor(1, 1, 1)
        else
            check.Text:SetTextColor(0.5, 0.5, 0.5)
        end
        
        -- Only guild master can change these settings
        if isGuildMaster then
            check:SetScript("OnClick", function(self)
                local value = self:GetChecked()
                BR:SetSetting(settingKey, value, true)
                BR:RefreshModules()
                -- Broadcast to guild
                BR:BroadcastGuildSettings()
            end)
        else
            -- Disable checkbox for non-guild masters
            check:SetEnabled(false)
            check:SetAlpha(0.6)
        end
        
        check.settingKey = settingKey
        check.label = label
        
        statusLabels[settingKey] = check
        return check
    end
    
    local lastRow = statusTitle
    local settings = {
        {key = "BlockTrade", label = "Handel nur mit Gildenmitgliedern"},
        {key = "BlockGroupInvites", label = "Gruppeneinladungen nur von Gilde"},
        {key = "BlockLFG", label = "Dungeonbrowser/LFG blockieren"},
        {key = "BlockAuction", label = "Auktionshaus blockieren"},
        {key = "BlockCraftingOrders", label = "Handwerksaufträge einschränken"},
        {key = "BlockWarbound", label = "Warbound-Bank blockieren"},
        {key = "BlockMail", label = "Briefkasten einschränken"},
    }
    
    for _, setting in ipairs(settings) do
        lastRow = CreateStatusRow(scrollChild, lastRow, setting.label, setting.key)
    end
    
    -- MailBlockMode dropdown (only for Guild Master, below BlockMail)
    local mailModeRow = CreateFrame("Frame", nil, scrollChild)
    mailModeRow:SetSize(400, 24)
    mailModeRow:SetPoint("TOPLEFT", lastRow, "BOTTOMLEFT", 20, -5)
    
    local mailModeLabel = mailModeRow:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    mailModeLabel:SetPoint("LEFT", 0, 0)
    mailModeLabel:SetText("Briefkasten-Modus:")
    
    local mailModeBtn = CreateFrame("Button", nil, mailModeRow, "UIPanelButtonTemplate")
    mailModeBtn:SetSize(180, 22)
    mailModeBtn:SetPoint("LEFT", mailModeLabel, "RIGHT", 10, 0)
    
    local function UpdateMailModeBtn()
        local mode = BR:GetSetting("MailBlockMode") or "selective"
        mailModeBtn:SetText(mode == "full" and "Komplett blockieren" or "Nur Fremde blockieren")
    end
    UpdateMailModeBtn()
    statusLabels["MailBlockMode"] = {UpdateDisplay = UpdateMailModeBtn}
    
    if isGuildMaster then
        mailModeBtn:SetScript("OnClick", function()
            local current = BR:GetSetting("MailBlockMode") or "selective"
            local newMode = current == "full" and "selective" or "full"
            BR:SetSetting("MailBlockMode", newMode, true)
            UpdateMailModeBtn()
            BR:BroadcastGuildSettings()
        end)
        mailModeLabel:SetTextColor(1, 1, 1)
    else
        mailModeBtn:Disable()
        mailModeBtn:SetAlpha(0.6)
        mailModeLabel:SetTextColor(0.5, 0.5, 0.5)
    end
    
    lastRow = mailModeRow
    
    -- Separator 2
    local sep2 = scrollChild:CreateTexture(nil, "ARTWORK")
    sep2:SetPoint("TOPLEFT", lastRow, "BOTTOMLEFT", -10, -15)
    sep2:SetSize(500, 1)
    sep2:SetColorTexture(0.5, 0.5, 0.5, 0.5)
    
    -- Local options title
    local localTitle = scrollChild:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    localTitle:SetPoint("TOPLEFT", sep2, "BOTTOMLEFT", 0, -15)
    localTitle:SetText("|cffffffffLokale Einstellungen:|r")
    
    -- Checkboxes for local settings (same style as status checkboxes)
    local function CreateOptionCheckbox(parent, anchor, label, settingKey, yOff)
        local check = CreateFrame("CheckButton", nil, parent, "InterfaceOptionsCheckButtonTemplate")
        check:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, yOff or -3)
        check:SetScale(1.0)
        
        -- Use same font as status checkboxes
        check.Text:SetFontObject("GameFontHighlight")
        check.Text:SetText(" " .. label)
        check.Text:SetTextColor(1, 1, 1)
        
        check:SetScript("OnClick", function(self)
            BR:SetSetting(settingKey, self:GetChecked(), true)
        end)
        
        check.settingKey = settingKey
        statusLabels["check_" .. settingKey] = check
        return check
    end
    
    local muteCheck = CreateOptionCheckbox(scrollChild, localTitle, "Benachrichtigungstöne deaktivieren", "MuteNotificationSounds")
    local welcomeCheck = CreateOptionCheckbox(scrollChild, muteCheck, "Willkommensbildschirm beim Login", "ShowWelcomeOnLogin")
    local debugCheck = CreateOptionCheckbox(scrollChild, welcomeCheck, "Debug-Modus", "DebugMode")
    
    -- Separator for GuildMap
    local sepGuildMap = scrollChild:CreateTexture(nil, "ARTWORK")
    sepGuildMap:SetPoint("TOPLEFT", debugCheck, "BOTTOMLEFT", -10, -15)
    sepGuildMap:SetSize(500, 1)
    sepGuildMap:SetColorTexture(0.5, 0.5, 0.5, 0.3)
    
    -- GuildMap title
    local guildMapTitle = scrollChild:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    guildMapTitle:SetPoint("TOPLEFT", sepGuildMap, "BOTTOMLEFT", 10, -10)
    guildMapTitle:SetText("|cffffffffGildenkarte:|r")
    
    -- GuildMap Checkboxes
    local guildMapEnabledCheck = CreateOptionCheckbox(scrollChild, guildMapTitle, "Gildenkarte aktivieren", "GuildMapEnabled", -5)
    guildMapEnabledCheck:SetScript("OnClick", function(self)
        BR:SetSetting("GuildMapEnabled", self:GetChecked(), true)
        if BR.Modules.GuildMap then
            BR.Modules.GuildMap:RefreshAllPins()
        end
    end)
    
    local guildMapNamesCheck = CreateOptionCheckbox(scrollChild, guildMapEnabledCheck, "Spielernamen anzeigen", "GuildMapShowNames")
    guildMapNamesCheck:SetScript("OnClick", function(self)
        BR:SetSetting("GuildMapShowNames", self:GetChecked(), true)
        if BR.Modules.GuildMap then
            BR.Modules.GuildMap:RefreshAllPins()
        end
    end)
    
    -- GuildMap Pin-Größe Slider
    local pinSizeRow = CreateFrame("Frame", nil, scrollChild)
    pinSizeRow:SetSize(400, 50)
    pinSizeRow:SetPoint("TOPLEFT", guildMapNamesCheck, "BOTTOMLEFT", 0, -10)
    
    local pinSizeLabel = pinSizeRow:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    pinSizeLabel:SetPoint("TOPLEFT", 0, 0)
    pinSizeLabel:SetText("Gildenkarten Pin-Größe:")
    
    local pinSizeValue = pinSizeRow:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    pinSizeValue:SetPoint("LEFT", pinSizeLabel, "RIGHT", 5, 0)
    
    local pinSizeSlider = CreateFrame("Slider", "AllforOnePinSizeSliderOptions", pinSizeRow, "OptionsSliderTemplate")
    pinSizeSlider:SetPoint("TOPLEFT", pinSizeLabel, "BOTTOMLEFT", 0, -8)
    pinSizeSlider:SetSize(200, 16)
    pinSizeSlider:SetMinMaxValues(16, 64)
    pinSizeSlider:SetValueStep(4)
    pinSizeSlider:SetObeyStepOnDrag(true)
    pinSizeSlider.Low:SetText("16")
    pinSizeSlider.High:SetText("64")
    pinSizeSlider.Text:SetText("")
    
    local currentPinSize = BR:GetSetting("GuildMapPinSize") or 32
    pinSizeSlider:SetValue(currentPinSize)
    pinSizeValue:SetText(currentPinSize)
    
    pinSizeSlider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value)
        pinSizeValue:SetText(value)
        BR:SetSetting("GuildMapPinSize", value, true)
        if BR.Modules.GuildMap then
            BR.Modules.GuildMap:RefreshAllPins()
        end
    end)
    
    statusLabels["GuildMapPinSize"] = {
        UpdateDisplay = function()
            local size = BR:GetSetting("GuildMapPinSize") or 32
            pinSizeSlider:SetValue(size)
            pinSizeValue:SetText(size)
        end
    }
    
    -- Send Settings Button (only for Guild Master)
    if isGuildMaster then
        local sep3 = scrollChild:CreateTexture(nil, "ARTWORK")
        sep3:SetPoint("TOPLEFT", pinSizeRow, "BOTTOMLEFT", -10, -10)
        sep3:SetSize(500, 1)
        sep3:SetColorTexture(0.796, 0.71, 0.482, 0.5)
        
        local sendBtn = CreateFrame("Button", nil, scrollChild, "UIPanelButtonTemplate")
        sendBtn:SetSize(200, 28)
        sendBtn:SetPoint("TOPLEFT", sep3, "BOTTOMLEFT", 10, -15)
        sendBtn:SetText("Einstellungen senden")
        sendBtn:SetScript("OnClick", function()
            BR:SendGuildSettings()
        end)
        
        local sendInfo = scrollChild:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
        sendInfo:SetPoint("LEFT", sendBtn, "RIGHT", 10, 0)
        sendInfo:SetText("|cff888888Sendet aktuelle Einstellungen an alle Online-Mitglieder|r")
    end
    
    -- Refresh function
    local function RefreshPanel()
        -- Update all checkboxes
        for key, check in pairs(statusLabels) do
            if check.SetChecked then
                local settingKey = check.settingKey or key:gsub("check_", "")
                check:SetChecked(BR:GetSetting(settingKey))
            elseif check.UpdateDisplay then
                check.UpdateDisplay()
            end
        end
    end
    
    panel:SetScript("OnShow", RefreshPanel)
    
    -- Register with the new Settings API (WoW 10.0+)
    if Settings and Settings.RegisterCanvasLayoutCategory then
        local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
        Settings.RegisterAddOnCategory(category)
        BR.settingsCategory = category
    else
        -- Fallback for older API
        if InterfaceOptions_AddCategory then
            InterfaceOptions_AddCategory(panel)
        end
    end
    
    BR.optionsPanel = panel
end

-- Create the panel when addon loads
local optionsFrame = CreateFrame("Frame")
optionsFrame:RegisterEvent("ADDON_LOADED")
optionsFrame:SetScript("OnEvent", function(self, event, addon)
    if addon == addonName then
        C_Timer.After(1, CreateInterfaceOptionsPanel)
        self:UnregisterEvent("ADDON_LOADED")
    end
end)
