Sauercrowd = Sauercrowd or {}

local ADDON_NAME = Sauercrowd.name or "Sauercrowd"

local WELCOME_MESSAGE = "Willkommen beim SAUERCROWD WoW HC Event!\n\nAlle wichtigen Regeln und Informationen findest du auf dem Event-Discord.\n\nViel Erfolg und viel Spaß beim Abenteuer!"

function Sauercrowd:CreateInfoWindow()
    if self.infoWindow then
        self.infoWindow:Show()
        return
    end

    local frame = CreateFrame("Frame", ADDON_NAME .. "WelcomeFrame", UIParent, "BackdropTemplate")
    frame:SetSize(700, 600)
    frame:SetPoint("CENTER")
    frame:SetBackdrop(Sauercrowd.Constants.BACKDROP)
    frame:SetBackdropColor(0, 0, 0, 0.8)
    frame:SetBackdropBorderColor(1, 1, 1, 1)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:Hide()

    -- Header Image
    local header = frame:CreateTexture(nil, "ARTWORK")
    header:SetTexture("Interface\\AddOns\\Sauercrowd\\media\\Header.png")
    header:SetSize(580, 330)
    header:SetPoint("TOP", 0, -5)

    -- Close button
    local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -5, -5)

    -- Welcome message
    local welcomeText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    welcomeText:SetPoint("TOP", 0, -350)
    welcomeText:SetWidth(550)
    welcomeText:SetJustifyH("CENTER")
    welcomeText:SetJustifyV("TOP")
    welcomeText:SetSpacing(8)
    welcomeText:SetText(WELCOME_MESSAGE)

    -- Version info
    local versionText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    versionText:SetPoint("BOTTOM", 0, 10)
    versionText:SetText("Version: " .. (Sauercrowd.version or "N/A"))

    self.infoWindow = frame
    frame:Show()
end

function Sauercrowd:InitializeWelcomePopup()
    Sauercrowd:CreateInfoWindow()
end
