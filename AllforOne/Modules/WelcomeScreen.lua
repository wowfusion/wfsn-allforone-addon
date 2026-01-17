----------------------------------------------------------------------
--  All for One - Welcome Screen Module
--  Shows welcome message on login
----------------------------------------------------------------------

local addonName, BR = ...

local WelcomeScreen = {
    frame = nil,
    hasShown = false,
}

-- Build dynamic welcome message based on active settings
local function GetWelcomeMessage()
    local lines = {
        "|cFFFFFFFFWillkommen beim All for One Guildfound Projekt!",
        "",
        "Folgende Guildfound Regeln sind aktiv:",
        "",
    }
    
    local activeBlocks = {}
    
    if BR:GetSetting("BlockTrade") then
        table.insert(activeBlocks, "- Handel nur mit Gildenmitgliedern")
    end
    if BR:GetSetting("BlockGroupInvites") then
        table.insert(activeBlocks, "- Gruppeneinladungen nur an/von Gildenmitgliedern")
    end
    if BR:GetSetting("BlockAuction") then
        table.insert(activeBlocks, "- Auktionshaus-Zugang blockiert")
    end
    if BR:GetSetting("BlockLFG") then
        table.insert(activeBlocks, "- Dungeonbrowser/LFG blockiert")
    end
    if BR:GetSetting("BlockMail") then
        local mode = BR:GetSetting("MailBlockMode") or "selective"
        if mode == "full" then
            table.insert(activeBlocks, "- Briefkasten komplett blockiert")
        else
            table.insert(activeBlocks, "- Post nur von/an Gildenmitglieder")
        end
    end
    if BR:GetSetting("BlockCraftingOrders") then
        table.insert(activeBlocks, "- Handwerksaufträge nur für die Gilde")
    end
    if BR:GetSetting("BlockWarbound") then
        table.insert(activeBlocks, "- Warbound-Bank blockiert")
    end
    
    if #activeBlocks > 0 then
        for _, block in ipairs(activeBlocks) do
            table.insert(lines, block)
        end
    else
        table.insert(lines, "- Keine Blockierungen aktiv")
    end
    
    table.insert(lines, "")
    table.insert(lines, "Viel Spaß beim Spielen!|r")
    
    return table.concat(lines, "\n")
end

function WelcomeScreen:OnInitialize()
    BR:Debug("WelcomeScreen module initialized")
end

function WelcomeScreen:OnEnable()
    -- Show welcome screen on login if enabled
    local showOnLogin = BR:GetSetting("ShowWelcomeOnLogin")
    if showOnLogin == nil then showOnLogin = true end
    
    if showOnLogin then
        C_Timer.After(2, function()
            if not self.hasShown then
                self:Show()
            end
        end)
    end
end

function WelcomeScreen:OnDisable()
    if self.frame then
        self.frame:Hide()
    end
end

function WelcomeScreen:CreateFrame()
    if self.frame then return end
    
    local frame = CreateFrame("Frame", "AllforOneWelcomeScreen", UIParent, "BackdropTemplate")
    frame:SetSize(500, 520)
    frame:SetPoint("CENTER", 0, 50)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetFrameStrata("DIALOG")
    frame:SetFrameLevel(200)
    frame:SetClampedToScreen(true)
    
    frame:SetBackdrop(BR.Backdrops.Window)
    frame:SetBackdropColor(0.08, 0.08, 0.08, 0.98)
    frame:SetBackdropBorderColor(unpack(BR.UI.DefaultBorderColor))
    
    -- Helper function for gold buttons (local)
    local function CreateGoldBtn(parent, width, height, text)
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
    
    -- Close button (gold-styled x)
    local closeBtn = CreateGoldBtn(frame, 28, 28, "x")
    closeBtn:SetPoint("TOPRIGHT", -12, -12)
    closeBtn:SetScript("OnClick", function()
        frame:Hide()
        self.hasShown = true
    end)
    
    -- Logo/Title area with Header image
    -- Container frame to maintain aspect ratio regardless of image dimensions
    local headerContainer = CreateFrame("Frame", nil, frame)
    headerContainer:SetSize(440, 130)
    headerContainer:SetPoint("TOP", 0, -15)
    
    local headerLogo = headerContainer:CreateTexture(nil, "ARTWORK")
    headerLogo:SetAllPoints(headerContainer)
    headerLogo:SetTexture("Interface\\AddOns\\AllforOne\\media\\logo-allforone.png")
    -- Use BLEND mode to preserve transparency and aspect ratio
    headerLogo:SetTexCoord(0, 1, 0, 1)
    
    -- Separator
    local sep1 = frame:CreateTexture(nil, "ARTWORK")
    sep1:SetPoint("TOP", headerContainer, "BOTTOM", 0, -15)
    sep1:SetSize(440, 2)
    sep1:SetColorTexture(0.796, 0.71, 0.482, 0.5)
    
    -- Welcome text area
    local welcomeText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    welcomeText:SetPoint("TOP", sep1, "BOTTOM", 0, -15)
    welcomeText:SetWidth(440)
    welcomeText:SetJustifyH("CENTER")
    welcomeText:SetJustifyV("TOP")
    welcomeText:SetSpacing(4)
    welcomeText:SetText(GetWelcomeMessage())
    frame.welcomeText = welcomeText
    
    -- Project info text
    local infoText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    infoText:SetPoint("TOP", welcomeText, "BOTTOM", 0, -15)
    infoText:SetText("|cFFFFFFFFAlle Informationen zum Projekt findest du unter:|r")
    
    -- Clickable link button
    local linkBtn = CreateFrame("Button", nil, frame)
    linkBtn:SetSize(280, 20)
    linkBtn:SetPoint("TOP", infoText, "BOTTOM", 0, -5)
    
    local linkText = linkBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    linkText:SetPoint("CENTER")
    linkText:SetText("|cFF66AAFF|Hwowfusion|hwowfusion.de/allforone|r")
    linkBtn.text = linkText
    
    linkBtn:SetScript("OnEnter", function(self)
        self.text:SetText("|cFFAADDFF|Hwowfusion|hwowfusion.de/allforone|r")
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine("Klicken zum Kopieren der URL")
        GameTooltip:Show()
    end)
    linkBtn:SetScript("OnLeave", function(self)
        self.text:SetText("|cFF66AAFF|Hwowfusion|hwowfusion.de/allforone|r")
        GameTooltip:Hide()
    end)
    linkBtn:SetScript("OnClick", function()
        -- Create popup to copy URL
        StaticPopupDialogs["ALLFORONE_COPY_URL"] = {
            text = "Kopiere die URL:",
            button1 = "Schließen",
            hasEditBox = true,
            editBoxWidth = 260,
            OnShow = function(self)
                self.editBox:SetText("https://wowfusion.de/allforone")
                self.editBox:HighlightText()
                self.editBox:SetFocus()
            end,
            EditBoxOnEnterPressed = function(self)
                self:GetParent():Hide()
            end,
            timeout = 0,
            whileDead = true,
            hideOnEscape = true,
            preferredIndex = 3,
        }
        StaticPopup_Show("ALLFORONE_COPY_URL")
    end)
    
    -- Button container - only Einstellungen for members
    local btnY = 45
    
    local settingsBtn = CreateGoldBtn(frame, 200, 32, "Einstellungen")
    settingsBtn:SetPoint("BOTTOM", frame, "BOTTOM", 0, btnY)
    settingsBtn:SetScript("OnClick", function()
        frame:Hide()
        BR:OpenConfig()
    end)
    
    -- Version info
    local versionText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    versionText:SetPoint("BOTTOM", 0, 18)
    versionText:SetText("|cFF888888v" .. (BR.Version or "1.0.0") .. " - wowfusion.de|r")
    
    frame:Hide()
    tinsert(UISpecialFrames, "AllforOneWelcomeScreen")
    self.frame = frame
end

function WelcomeScreen:Show()
    if not self.frame then
        self:CreateFrame()
    end
    
    -- Update welcome text with current settings
    if self.frame.welcomeText then
        self.frame.welcomeText:SetText(GetWelcomeMessage())
    end
    
    self.frame:Show()
    self.hasShown = true
end

function WelcomeScreen:Refresh()
    -- Nothing to refresh with static welcome text
end

-- Add function to BR namespace
function BR:ShowWelcomeScreen()
    WelcomeScreen:Show()
end

BR:RegisterModule("WelcomeScreen", WelcomeScreen)
