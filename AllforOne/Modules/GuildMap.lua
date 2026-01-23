----------------------------------------------------------------------
--  All for One - GuildMap Module
--  Zeigt Gildenmitglieder auf der Weltkarte an
--  Basiert auf dem Classic GuildMap Addon, angepasst für Retail 11.2.7
--  Verwendet HereBeDragons-Pins-2.0 für korrekte Minimap-Positionierung
----------------------------------------------------------------------

local addonName, BR = ...

-- HereBeDragons Libraries
local HBD = LibStub("HereBeDragons-2.0", true)
local HBDPins = LibStub("HereBeDragons-Pins-2.0", true)

local GuildMap = {
    pins = {},
    memberPositions = {},
    isEnabled = false,
    pinsVisible = true,
    toggleButton = nil,
    minimapPin = nil, -- Minimap Pin für Gildentreffpunkt
}

-- Konstanten
local UPDATE_INTERVAL = 5 -- Sekunden zwischen Position-Updates
local DEFAULT_PIN_SIZE = 32 -- Standardgröße (größer als vorher)
local DEFAULT_FONT_SIZE = 12 -- Standardschriftgröße
local STALE_TIMEOUT = 120 -- 2 Minuten ohne Update = Position entfernen

-- Gildentreffpunkt Konstanten (anpassbar)
local GUILD_MEETING_POINT = {
    mapID = 2352,           -- Gründerspitze
    x = 0.5671,             -- X-Koordinate (56.71%)
    y = 0.3946,             -- Y-Koordinate (39.46%)
    name = "Gildentreffpunkt",
    icon = "Interface\\AddOns\\AllforOne\\media\\icon2-allforone",
}

----------------------------------------------------------------------
--  Hilfsfunktionen
----------------------------------------------------------------------

local function GetClassColor(classFile)
    if classFile and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile] then
        local color = RAID_CLASS_COLORS[classFile]
        return color.r, color.g, color.b
    end
    -- Fallback: Weiß
    return 1, 1, 1
end

local function IsGuildMapEnabled()
    return BR:GetSetting("GuildMapEnabled") ~= false
end

local function ShowPlayerNames()
    return BR:GetSetting("GuildMapShowNames") ~= false
end

local function IsInMyGroup(playerName)
    if not IsInGroup() then return false end
    
    local numMembers = GetNumGroupMembers()
    local prefix = IsInRaid() and "raid" or "party"
    
    for i = 1, numMembers do
        local unit = prefix .. i
        local name = UnitName(unit)
        if name and name == playerName then
            return true
        end
    end
    return false
end

local function GetClassColorHex(classFile)
    local r, g, b = GetClassColor(classFile)
    return string.format("|cFF%02x%02x%02x", r * 255, g * 255, b * 255)
end

local function GetPinSize()
    return BR:GetSetting("GuildMapPinSize") or DEFAULT_PIN_SIZE
end

local function GetFontSize()
    local pinSize = GetPinSize()
    return math.max(10, pinSize * 0.4) -- Schriftgröße proportional zur Pin-Größe
end

----------------------------------------------------------------------
--  Pin-Erstellung und Verwaltung
----------------------------------------------------------------------

function GuildMap:CreatePin(memberInfo)
    local pinName = "AllforOneGuildMapPin_" .. memberInfo.name
    local pinSize = GetPinSize()
    local fontSize = GetFontSize()
    
    -- Bestehenden Pin wiederverwenden oder neuen erstellen
    local pin = self.pins[memberInfo.name]
    if not pin then
        -- Pin an Canvas anhängen
        pin = CreateFrame("Button", pinName, WorldMapFrame:GetCanvas())
        pin:SetFrameStrata("TOOLTIP") -- Höchste Strata, über allem
        pin:SetFrameLevel(9999) -- Sehr hoher Level, über dem Spielerpfeil
        pin:SetSize(pinSize, pinSize)
        
        -- Schwarzer Umriss (Border) - leicht größer als der Hauptpunkt
        local border = pin:CreateTexture(nil, "BACKGROUND")
        border:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMaskSmall")
        border:SetVertexColor(0, 0, 0, 1) -- Schwarz
        border:SetPoint("CENTER")
        border:SetSize(pinSize * 1.25, pinSize * 1.25)
        pin.border = border
        
        -- Haupttextur - Klassen-spezifischer Punkt
        local bg = pin:CreateTexture(nil, "ARTWORK")
        bg:SetAllPoints()
        pin.bg = bg
        
        -- Name-Text unter dem Pin
        local nameText = pin:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        nameText:SetPoint("TOP", pin, "BOTTOM", 0, -2)
        pin.nameText = nameText
        
        -- Tooltip
        pin:EnableMouse(true)
        pin:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:ClearLines()
            
            local r, g, b = GetClassColor(self.memberInfo.classFile)
            GameTooltip:AddLine(self.memberInfo.name, r, g, b)
            
            if self.memberInfo.level then
                GameTooltip:AddLine("Level " .. self.memberInfo.level, 1, 1, 1)
            end
            
            if self.memberInfo.zone and self.memberInfo.zone ~= "" then
                GameTooltip:AddLine(self.memberInfo.zone, 0.7, 0.7, 0.7)
            end
            
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("|cFF888888Rechtsklick: Flüstern|r", 0.5, 0.5, 0.5)
            GameTooltip:Show()
        end)
        
        pin:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
        
        -- Rechtsklick für Kontextmenü
        pin:RegisterForClicks("RightButtonUp")
        pin:SetScript("OnClick", function(self, button)
            if button == "RightButton" and self.memberInfo then
                GuildMap:ShowContextMenu(self, self.memberInfo)
            end
        end)
        
        self.pins[memberInfo.name] = pin
    end
    
    -- Pin aktualisieren
    pin.memberInfo = memberInfo
    
    -- Einfacher runder Punkt mit Klassenfarbe
    local classFile = memberInfo.classFile or "WARRIOR"
    local r, g, b = GetClassColor(classFile)
    
    -- Weiße Kreis-Textur als Basis, dann mit Klassenfarbe einfärben
    pin.bg:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMaskSmall")
    pin.bg:SetVertexColor(r, g, b, 1)
    
    -- Name und Schriftgröße aktualisieren
    local r, g, b = GetClassColor(classFile)
    pin.nameText:SetFont("Fonts\\FRIZQT__.TTF", fontSize, "OUTLINE")
    if ShowPlayerNames() then
        pin.nameText:SetText(memberInfo.name)
        pin.nameText:Show()
    else
        pin.nameText:SetText("")
        pin.nameText:Hide()
    end
    pin.nameText:SetTextColor(r, g, b)
    
    return pin
end

function GuildMap:UpdatePinPosition(pin, mapID, x, y, memberName)
    local currentMapID = WorldMapFrame:GetMapID()
    if not currentMapID then
        pin:Hide()
        return
    end
    
    -- Gruppenmitglieder ausblenden (werden bereits als Gruppen-Pin angezeigt)
    if memberName and IsInMyGroup(memberName) then
        pin:Hide()
        return
    end
    
    -- Prüfen ob die Map passt oder ob es eine Parent-Map ist (Kontinent-Ansicht)
    local showPin = false
    local displayX, displayY = x, y
    
    if currentMapID == mapID then
        -- Exakte Map-Übereinstimmung
        showPin = true
    else
        -- Prüfen ob currentMapID eine Parent-Map von mapID ist (z.B. Kontinent)
        local mapInfo = C_Map.GetMapInfo(mapID)
        if mapInfo then
            local parentMapID = mapInfo.parentMapID
            while parentMapID do
                if parentMapID == currentMapID then
                    -- Position auf Parent-Map umrechnen mit korrekter API
                    -- Erst World-Position holen, dann auf neue Map umrechnen
                    local continentID, worldPos = C_Map.GetWorldPosFromMapPos(mapID, CreateVector2D(x, y))
                    if continentID and worldPos then
                        local _, newPos = C_Map.GetMapPosFromWorldPos(continentID, worldPos, currentMapID)
                        if newPos then
                            displayX, displayY = newPos:GetXY()
                            showPin = true
                        end
                    end
                    break
                end
                local parentInfo = C_Map.GetMapInfo(parentMapID)
                parentMapID = parentInfo and parentInfo.parentMapID
            end
        end
    end
    
    if not showPin then
        pin:Hide()
        return
    end
    
    -- Position auf der Karte berechnen
    local canvas = WorldMapFrame:GetCanvas()
    local width, height = canvas:GetSize()
    local canvasScale = canvas:GetScale() or 1
    
    local pinX = displayX * width
    local pinY = -displayY * height
    
    -- Pin-Größe mit Canvas-Scale normalisieren (damit Pins auf allen Karten gleich groß sind)
    local basePinSize = GetPinSize()
    
    -- Normalisiere die Pin-Größe basierend auf der Canvas-Scale
    -- Kleinere Scale = größere Karte = Pin muss kleiner sein um gleich groß zu erscheinen
    local pinSize = basePinSize / canvasScale
    local fontSize = math.max(8, (basePinSize * 0.5) / canvasScale)
    
    pin:SetSize(pinSize, pinSize)
    
    -- Border etwas größer als der Pin für den schwarzen Umriss
    if pin.border then
        local borderSize = pinSize * 1.25
        pin.border:SetSize(borderSize, borderSize)
    end
    
    pin.nameText:SetFont("Fonts\\FRIZQT__.TTF", math.max(8, fontSize), "OUTLINE")
    
    pin:ClearAllPoints()
    pin:SetPoint("CENTER", canvas, "TOPLEFT", pinX, pinY)
    pin:Show()
end

function GuildMap:RemovePin(name)
    local pin = self.pins[name]
    if pin then
        pin:Hide()
        pin:SetParent(nil)
        self.pins[name] = nil
    end
end

function GuildMap:HideAllPins()
    for _, pin in pairs(self.pins) do
        pin:Hide()
    end
end

function GuildMap:RefreshAllPins()
    if not WorldMapFrame:IsShown() then return end
    if not self.isEnabled then return end
    if not IsGuildMapEnabled() then
        self:HideAllPins()
        return
    end
    
    -- If pins are hidden, don't show them
    if not self.pinsVisible then
        self:HideAllPins()
        return
    end
    
    local currentMapID = WorldMapFrame:GetMapID()
    if not currentMapID then return end
    
    for name, info in pairs(self.memberPositions) do
        local pin = self:CreatePin(info)
        self:UpdatePinPosition(pin, info.mapID, info.x, info.y, info.name)
    end
    
    -- Gildentreffpunkt-Marker aktualisieren
    self:UpdateMeetingPointPin()
end

----------------------------------------------------------------------
--  Gildentreffpunkt-Marker
----------------------------------------------------------------------

-- Holt das nächste Gilden-Event aus dem Kalender
function GuildMap:GetNextGuildEvent()
    if not C_Calendar then return nil end
    
    -- Öffne den Kalender (notwendig um Events zu laden)
    C_Calendar.OpenCalendar()
    
    local currentDate = C_DateAndTime.GetCurrentCalendarTime()
    if not currentDate then return nil end
    
    local bestEvent = nil
    local bestTime = nil
    
    -- Durchsuche die nächsten 30 Tage
    for dayOffset = 0, 30 do
        local checkMonth = currentDate.month
        local checkDay = currentDate.monthDay + dayOffset
        local checkYear = currentDate.year
        
        -- Monatswechsel behandeln
        local daysInMonth = C_Calendar.GetMonthInfo(0).numDays or 31
        while checkDay > daysInMonth do
            checkDay = checkDay - daysInMonth
            checkMonth = checkMonth + 1
            if checkMonth > 12 then
                checkMonth = 1
                checkYear = checkYear + 1
            end
            -- Hole neue Anzahl Tage für den neuen Monat
            local monthOffset = (checkMonth - currentDate.month) + (checkYear - currentDate.year) * 12
            local monthInfo = C_Calendar.GetMonthInfo(monthOffset)
            daysInMonth = monthInfo and monthInfo.numDays or 31
        end
        
        -- Setze den Kalender auf diesen Tag
        local monthOffset = (checkMonth - currentDate.month) + (checkYear - currentDate.year) * 12
        C_Calendar.SetAbsMonth(checkMonth, checkYear)
        
        -- Hole Events für diesen Tag
        local numEvents = C_Calendar.GetNumDayEvents(0, checkDay)
        
        for i = 1, numEvents do
            local event = C_Calendar.GetDayEvent(0, checkDay, i)
            if event then
                -- Debug: Zeige Event-Informationen
                BR:Debug(string.format("GuildMap Event: title='%s', calendarType='%s', eventType=%s", 
                    tostring(event.title), 
                    tostring(event.calendarType), 
                    tostring(event.eventType)))
                
                -- Prüfe ob es ein Gilden-Event ist (calendarType == "GUILD_EVENT" oder "GUILD")
                local isGuildEvent = event.calendarType == "GUILD_EVENT" or 
                                     event.calendarType == "GUILD" or
                                     event.calendarType == "GUILD_ANNOUNCEMENT"
                
                -- Filter: Nur Events mit "Gildenmeeting" im Titel (case-insensitive)
                local hasGuildmeetingTitle = event.title and string.find(string.lower(event.title), "gildenmeeting")
                
                if isGuildEvent and hasGuildmeetingTitle and event.sequenceType ~= "END" then
                    -- Berechne den Zeitstempel für Vergleich
                    local eventTime = time({
                        year = checkYear,
                        month = checkMonth,
                        day = checkDay,
                        hour = event.startTime and event.startTime.hour or 0,
                        min = event.startTime and event.startTime.minute or 0
                    })
                    
                    local now = time()
                    
                    -- Nur zukünftige Events
                    if eventTime > now then
                        if not bestTime or eventTime < bestTime then
                            bestTime = eventTime
                            bestEvent = {
                                title = event.title,
                                day = checkDay,
                                month = checkMonth,
                                year = checkYear,
                                hour = event.startTime and event.startTime.hour or 0,
                                minute = event.startTime and event.startTime.minute or 0,
                            }
                        end
                    end
                end
            end
        end
        
        -- Wenn wir ein Event gefunden haben, können wir aufhören
        if bestEvent then break end
    end
    
    return bestEvent
end

-- Formatiert das Event-Datum für die Anzeige
function GuildMap:FormatEventDate(event)
    if not event then return nil end
    
    local dayNames = {"So", "Mo", "Di", "Mi", "Do", "Fr", "Sa"}
    local monthNames = {"Jan", "Feb", "Mär", "Apr", "Mai", "Jun", "Jul", "Aug", "Sep", "Okt", "Nov", "Dez"}
    
    -- Wochentag berechnen
    local timestamp = time({year = event.year, month = event.month, day = event.day, hour = 12})
    local weekday = tonumber(date("%w", timestamp)) + 1 -- Lua: 0=So, wir wollen 1=So
    
    return string.format("%s, %d. %s %02d:%02d Uhr",
        dayNames[weekday],
        event.day,
        monthNames[event.month],
        event.hour,
        event.minute
    )
end

function GuildMap:CreateMeetingPointPin()
    if self.meetingPointPin then return self.meetingPointPin end
    
    local pin = CreateFrame("Button", "AllforOneGuildMeetingPoint", WorldMapFrame:GetCanvas())
    pin:SetFrameStrata("MEDIUM")
    pin:SetFrameLevel(100)
    
    -- Nur das AFO Icon - kein Kreis/Border
    local icon = pin:CreateTexture(nil, "ARTWORK")
    icon:SetTexture(GUILD_MEETING_POINT.icon)
    icon:SetAllPoints()
    pin.icon = icon
    
    -- Tooltip mit Gildenkalender-Integration
    pin:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:ClearLines()
        GameTooltip:AddLine("|cFFFFCC00" .. GUILD_MEETING_POINT.name .. "|r", 1, 1, 1)
        GameTooltip:AddLine(" ")
        
        -- Nächstes Gilden-Event anzeigen
        local nextEvent = GuildMap:GetNextGuildEvent()
        if nextEvent then
            GameTooltip:AddLine("|cFF00FF00Nächstes Gildenmeeting:|r", 0, 1, 0)
            GameTooltip:AddLine("|cFFAAAAAA" .. GuildMap:FormatEventDate(nextEvent) .. "|r", 0.7, 0.7, 0.7)
            GameTooltip:AddLine(" ")
        else
            GameTooltip:AddLine("|cFF888888Kein Gildenmeeting geplant|r", 0.5, 0.5, 0.5)
            GameTooltip:AddLine(" ")
        end
        
        GameTooltip:AddLine("All for One Gildentreffpunkt", 0.7, 0.7, 0.7)
        GameTooltip:AddLine("Gründerspitze", 0.5, 0.5, 0.5)
        GameTooltip:Show()
    end)
    
    pin:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)
    
    pin:Hide()
    self.meetingPointPin = pin
    return pin
end

function GuildMap:UpdateMeetingPointPin()
    if not self.pinsVisible then
        if self.meetingPointPin then
            self.meetingPointPin:Hide()
        end
        return
    end
    
    local pin = self:CreateMeetingPointPin()
    local currentMapID = WorldMapFrame:GetMapID()
    
    if not currentMapID then
        pin:Hide()
        return
    end
    
    local showPin = false
    local displayX, displayY = GUILD_MEETING_POINT.x, GUILD_MEETING_POINT.y
    
    if currentMapID == GUILD_MEETING_POINT.mapID then
        showPin = true
    else
        -- Prüfen ob currentMapID eine Parent-Map ist
        local mapInfo = C_Map.GetMapInfo(GUILD_MEETING_POINT.mapID)
        if mapInfo then
            local parentMapID = mapInfo.parentMapID
            while parentMapID do
                if parentMapID == currentMapID then
                    local continentID, worldPos = C_Map.GetWorldPosFromMapPos(GUILD_MEETING_POINT.mapID, CreateVector2D(GUILD_MEETING_POINT.x, GUILD_MEETING_POINT.y))
                    if continentID and worldPos then
                        local _, newPos = C_Map.GetMapPosFromWorldPos(continentID, worldPos, currentMapID)
                        if newPos then
                            displayX, displayY = newPos:GetXY()
                            showPin = true
                        end
                    end
                    break
                end
                local parentInfo = C_Map.GetMapInfo(parentMapID)
                parentMapID = parentInfo and parentInfo.parentMapID
            end
        end
    end
    
    if not showPin then
        pin:Hide()
        return
    end
    
    local canvas = WorldMapFrame:GetCanvas()
    local width, height = canvas:GetSize()
    
    -- Feste visuelle Größe wie WoW-Icons (skaliert mit Canvas)
    -- Das Icon behält seine Größe auf dem Bildschirm bei jedem Zoom-Level
    local canvasScale = canvas:GetScale() or 1
    local baseSize = 32 / canvasScale
    pin:SetSize(baseSize, baseSize)
    
    local pinX = displayX * width
    local pinY = -displayY * height
    
    pin:ClearAllPoints()
    pin:SetPoint("CENTER", canvas, "TOPLEFT", pinX, pinY)
    pin:Show()
end

----------------------------------------------------------------------
--  Minimap Gildentreffpunkt Pin (mit HereBeDragons-Pins-2.0)
----------------------------------------------------------------------

function GuildMap:CreateMinimapPin()
    -- Immer neuen Pin erstellen wenn der alte existiert aber nicht funktioniert
    if self.minimapPin then
        -- Prüfe ob der Pin noch gültig ist
        if self.minimapPin:GetParent() == Minimap then
            return self.minimapPin
        end
        -- Pin ist ungültig, neu erstellen
        self.minimapPin = nil
    end
    
    -- MEDIUM Strata damit der Pin sichtbar ist
    local pin = CreateFrame("Button", "AllforOneMinimapMeetingPoint", Minimap)
    pin:SetSize(20, 20)
    pin:SetFrameStrata("MEDIUM")
    pin:SetFrameLevel(10)
    pin:EnableMouse(true)
    
    -- AFO Icon
    local icon = pin:CreateTexture(nil, "OVERLAY")
    icon:SetTexture(GUILD_MEETING_POINT.icon)
    icon:SetAllPoints()
    icon:SetTexelSnappingBias(0)
    icon:SetSnapToPixelGrid(false)
    pin.icon = icon
    
    -- Tooltip mit Gildenkalender-Integration
    pin:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:ClearLines()
        GameTooltip:AddLine("|cFFFFCC00" .. GUILD_MEETING_POINT.name .. "|r", 1, 1, 1)
        GameTooltip:AddLine(" ")
        
        -- Nächstes Gilden-Event anzeigen
        local nextEvent = GuildMap:GetNextGuildEvent()
        if nextEvent then
            GameTooltip:AddLine("|cFF00FF00Nächstes Gildenmeeting:|r", 0, 1, 0)
            GameTooltip:AddLine("|cFFAAAAAA" .. GuildMap:FormatEventDate(nextEvent) .. "|r", 0.7, 0.7, 0.7)
            GameTooltip:AddLine(" ")
        else
            GameTooltip:AddLine("|cFF888888Kein Gildenmeeting geplant|r", 0.5, 0.5, 0.5)
            GameTooltip:AddLine(" ")
        end
        
        GameTooltip:AddLine("All for One Gildentreffpunkt", 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    
    pin:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    
    pin:Hide()
    self.minimapPin = pin
    return pin
end

function GuildMap:UpdateMinimapPin()
    local pin = self:CreateMinimapPin()
    
    -- Prüfe ob HereBeDragons verfügbar ist
    if not HBDPins then
        BR:Debug("GuildMap: HereBeDragons-Pins nicht verfügbar")
        pin:Hide()
        return
    end
    
    -- Entferne vorherigen Pin falls vorhanden
    HBDPins:RemoveMinimapIcon("AllforOneMeetingPoint", pin)
    
    -- Füge Pin mit HereBeDragons hinzu (floatOnEdge = true)
    HBDPins:AddMinimapIconMap(
        "AllforOneMeetingPoint",  -- Owner ID
        pin,                       -- Frame
        GUILD_MEETING_POINT.mapID, -- Map ID
        GUILD_MEETING_POINT.x,     -- X (0-1)
        GUILD_MEETING_POINT.y,     -- Y (0-1)
        true                       -- floatOnEdge
    )
end

function GuildMap:RemoveMinimapPin()
    if self.minimapPin and HBDPins then
        HBDPins:RemoveMinimapIcon("AllforOneMeetingPoint", self.minimapPin)
        self.minimapPin:Hide()
    end
end

----------------------------------------------------------------------
--  Toggle Button für Pins Sichtbarkeit
----------------------------------------------------------------------

function GuildMap:TogglePinsVisibility()
    self.pinsVisible = not self.pinsVisible
    
    if self.pinsVisible then
        self:RefreshAllPins()
        BR:Debug("GuildMap pins shown")
    else
        self:HideAllPins()
        BR:Debug("GuildMap pins hidden")
    end
    
    self:UpdateToggleButton()
end

function GuildMap:UpdateToggleButton()
    if not self.toggleButton then return end
    
    if self.pinsVisible then
        self.toggleButton.icon:SetVertexColor(0.2, 1, 0.2, 1) -- Green = visible
        self.toggleButton.icon:SetDesaturated(false)
        self.toggleButton:SetBackdropBorderColor(0.2, 0.8, 0.2, 1)
    else
        self.toggleButton.icon:SetVertexColor(1, 0.2, 0.2, 1) -- Red = hidden
        self.toggleButton.icon:SetDesaturated(false)
        self.toggleButton:SetBackdropBorderColor(0.8, 0.2, 0.2, 1)
    end
end

function GuildMap:CreateToggleButton()
    if self.toggleButton then return end
    if not WorldMapFrame then return end
    
    -- Create button on the world map - position top left (unter der Navigationsleiste)
    local button = CreateFrame("Button", "AllforOneGuildMapToggle", WorldMapFrame, "BackdropTemplate")
    button:SetSize(32, 32)
    button:SetPoint("TOPLEFT", WorldMapFrame, "TOPLEFT", 10, -70)
    button:SetFrameStrata("FULLSCREEN_DIALOG")
    button:SetFrameLevel(500)
    
    -- Background
    button:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 10,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })
    button:SetBackdropColor(0.1, 0.1, 0.1, 0.95)
    button:SetBackdropBorderColor(0.2, 0.8, 0.2, 1)
    
    -- Icon (addon icon)
    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetSize(22, 22)
    icon:SetPoint("CENTER", 0, 0)
    icon:SetTexture("Interface\\AddOns\\AllforOne\\media\\icon-allforone")
    button.icon = icon
    
    -- Tooltip
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOMLEFT")
        GameTooltip:ClearLines()
        GameTooltip:AddLine("|cFFFFCC00Gildenmitglieder anzeigen|r")
        GameTooltip:AddLine(" ")
        if GuildMap.pinsVisible then
            GameTooltip:AddLine("Status: |cFF00FF00Sichtbar|r")
            GameTooltip:AddLine("Klicken zum Verstecken", 0.7, 0.7, 0.7)
        else
            GameTooltip:AddLine("Status: |cFFFF4444Versteckt|r")
            GameTooltip:AddLine("Klicken zum Anzeigen", 0.7, 0.7, 0.7)
        end
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("|cFF888888Deine Position wird weiterhin gesendet|r", 0.5, 0.5, 0.5)
        GameTooltip:Show()
        button:SetBackdropColor(0.2, 0.2, 0.2, 0.95)
    end)
    
    button:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
        button:SetBackdropColor(0.1, 0.1, 0.1, 0.9)
    end)
    
    button:SetScript("OnClick", function(self, btn)
        GuildMap:TogglePinsVisibility()
    end)
    
    self.toggleButton = button
    self:UpdateToggleButton()
    
    BR:Debug("GuildMap toggle button created")
end

----------------------------------------------------------------------
--  Kontextmenü
----------------------------------------------------------------------

function GuildMap:ShowContextMenu(pin, memberInfo)
    if not memberInfo then return end
    
    -- Menü erstellen falls nicht vorhanden
    if not self.contextMenu then
        self.contextMenu = CreateFrame("Frame", "AllforOneGuildMapContextMenu", UIParent, "UIDropDownMenuTemplate")
    end
    
    local menu = {
        {
            text = memberInfo.name,
            isTitle = true,
            notCheckable = true,
        },
        {
            text = "Flüstern",
            notCheckable = true,
            func = function()
                ChatFrame_SendTell(memberInfo.name)
            end,
        },
        {
            text = "Einladen",
            notCheckable = true,
            func = function()
                C_PartyInfo.InviteUnit(memberInfo.name)
            end,
        },
        {
            text = "|cFFFFCC00Anstupsen|r",
            notCheckable = true,
            func = function()
                -- Anstupsen-Nachricht senden
                local messages = {
                    "*stupst dich an* Hey! :)",
                    "*poke poke* Bist du da?",
                    "*stupst* Aufwachen!",
                    "*tipp tipp* Halloooo?",
                    "*anstups* Was machst du gerade?",
                }
                local msg = messages[math.random(#messages)]
                SendChatMessage(msg, "WHISPER", nil, memberInfo.name)
            end,
        },
        {
            text = "Abbrechen",
            notCheckable = true,
            func = function() CloseDropDownMenus() end,
        },
    }
    
    -- UIDropDownMenu verwenden statt EasyMenu
    UIDropDownMenu_Initialize(self.contextMenu, function(frame, level)
        for _, item in ipairs(menu) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = item.text
            info.isTitle = item.isTitle
            info.notCheckable = item.notCheckable
            info.func = item.func
            UIDropDownMenu_AddButton(info, level)
        end
    end, "MENU")
    ToggleDropDownMenu(1, nil, self.contextMenu, "cursor", 0, 0)
end

----------------------------------------------------------------------
--  Modul-Funktionen
----------------------------------------------------------------------

function GuildMap:OnInitialize()
    BR:Debug("GuildMap module initialized")
end

function GuildMap:OnEnable()
    self.isEnabled = true
    
    -- Position-Update-Timer starten
    self:StartPositionUpdates()
    
    -- Minimap Pin Timer starten
    self:StartMinimapUpdates()
    
    -- WorldMapFrame Hooks
    if WorldMapFrame then
        -- Create toggle button on the map
        self:CreateToggleButton()
        
        -- Hook für Kartenänderungen
        WorldMapFrame:HookScript("OnShow", function()
            C_Timer.After(0.1, function()
                GuildMap:RefreshAllPins()
            end)
        end)
        
        -- Close context menu when map is hidden
        WorldMapFrame:HookScript("OnHide", function()
            CloseDropDownMenus()
        end)
        
        -- Hook für Kartenwechsel
        hooksecurefunc(WorldMapFrame, "OnMapChanged", function()
            GuildMap:RefreshAllPins()
        end)
        
        -- Hook für Zoom/Pan - Pins müssen bei Scale-Änderung aktualisiert werden
        local canvas = WorldMapFrame:GetCanvas()
        if canvas then
            hooksecurefunc(canvas, "SetScale", function()
                if GuildMap.isEnabled and WorldMapFrame:IsShown() then
                    GuildMap:RefreshAllPins()
                end
            end)
        end
    end
    
    BR:Debug("GuildMap module enabled")
end

function GuildMap:OnDisable()
    self.isEnabled = false
    
    -- Timer stoppen
    if self.updateTimer then
        self.updateTimer:Cancel()
        self.updateTimer = nil
    end
    
    -- Minimap Timer stoppen
    if self.minimapTimer then
        self.minimapTimer:Cancel()
        self.minimapTimer = nil
    end
    
    -- Alle Pins verstecken
    self:HideAllPins()
    
    -- Minimap Pin entfernen
    self:RemoveMinimapPin()
    
    BR:Debug("GuildMap module disabled")
end

function GuildMap:Refresh()
    self:RefreshAllPins()
end

----------------------------------------------------------------------
--  Position Broadcasting
----------------------------------------------------------------------

function GuildMap:StartPositionUpdates()
    if self.updateTimer then
        self.updateTimer:Cancel()
    end
    
    -- Sofort erste Position senden
    C_Timer.After(2, function()
        self:BroadcastPosition()
    end)
    
    -- Periodische Updates
    self.updateTimer = C_Timer.NewTicker(UPDATE_INTERVAL, function()
        if BR:IsInGuild() and self.isEnabled then
            self:BroadcastPosition()
        end
    end)
    
    -- Cleanup Timer
    C_Timer.NewTicker(30, function()
        if self.isEnabled then
            self:CleanupOldPositions()
        end
    end)
end

function GuildMap:StartMinimapUpdates()
    if self.minimapTimer then
        self.minimapTimer:Cancel()
    end
    
    -- Sofort ersten Update
    C_Timer.After(1, function()
        self:UpdateMinimapPin()
    end)
    
    -- Periodische Updates (alle 1 Sekunde für smooth movement)
    self.minimapTimer = C_Timer.NewTicker(1, function()
        if self.isEnabled then
            self:UpdateMinimapPin()
        end
    end)
end

function GuildMap:BroadcastPosition()
    if not BR:IsInGuild() then return end
    if not IsGuildMapEnabled() then return end
    
    local mapID = C_Map.GetBestMapForUnit("player")
    if not mapID then return end
    
    local position = C_Map.GetPlayerMapPosition(mapID, "player")
    if not position then return end
    
    local x, y = position:GetXY()
    if not x or not y then return end
    
    -- Spielerinformationen sammeln
    local playerName = UnitName("player")
    local _, classFile = UnitClass("player")
    local level = UnitLevel("player")
    local zone = GetZoneText() or ""
    
    -- Position-Nachricht formatieren: GUILDMAP:name:mapID:x:y:classFile:level:zone
    local msg = string.format("GUILDMAP:%s:%d:%.4f:%.4f:%s:%d:%s",
        playerName,
        mapID,
        x,
        y,
        classFile or "WARRIOR",
        level or 1,
        zone
    )
    
    BR:SendAddonMessage(msg, "GUILD")
    BR:Debug("GuildMap position broadcasted: " .. mapID .. " (" .. string.format("%.2f", x) .. ", " .. string.format("%.2f", y) .. ")")
end

----------------------------------------------------------------------
--  Nachrichten-Verarbeitung (wird von Core.lua aufgerufen)
----------------------------------------------------------------------

function GuildMap:HandlePositionMessage(message, sender)
    if not self.isEnabled then return end
    if not IsGuildMapEnabled() then return end
    
    local parts = {strsplit(":", message)}
    if parts[1] ~= "GUILDMAP" then return end
    
    local name = parts[2]
    local mapID = tonumber(parts[3])
    local x = tonumber(parts[4])
    local y = tonumber(parts[5])
    local classFile = parts[6]
    local level = tonumber(parts[7])
    local zone = parts[8]
    
    if not name or not mapID or not x or not y then return end
    
    -- Eigene Position ignorieren
    local myName = UnitName("player")
    if name == myName then return end
    
    -- Position speichern
    self.memberPositions[name] = {
        name = name,
        mapID = mapID,
        x = x,
        y = y,
        classFile = classFile or "WARRIOR",
        level = level,
        zone = zone,
        lastUpdate = time()
    }
    
    BR:Debug("GuildMap received position from " .. name .. ": " .. mapID)
    
    -- Karte aktualisieren wenn offen
    if WorldMapFrame and WorldMapFrame:IsShown() then
        self:RefreshAllPins()
    end
end

----------------------------------------------------------------------
--  Alte Positionen aufräumen
----------------------------------------------------------------------

function GuildMap:CleanupOldPositions()
    local now = time()
    local removed = 0
    
    for name, info in pairs(self.memberPositions) do
        if info.lastUpdate and (now - info.lastUpdate) > STALE_TIMEOUT then
            self.memberPositions[name] = nil
            self:RemovePin(name)
            removed = removed + 1
            BR:Debug("GuildMap removed stale position for: " .. name)
        end
    end
    
    if removed > 0 and WorldMapFrame and WorldMapFrame:IsShown() then
        self:RefreshAllPins()
    end
end

----------------------------------------------------------------------
--  Modul registrieren
----------------------------------------------------------------------

BR:RegisterModule("GuildMap", GuildMap)
