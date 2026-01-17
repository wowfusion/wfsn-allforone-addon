----------------------------------------------------------------------
--  All for One - Popup System
--  Generic popup notifications with animations
----------------------------------------------------------------------

local addonName, BR = ...

BR.Popup = {
    activePopups = {},
}


----------------------------------------------------------------------
--  Main Show Function
----------------------------------------------------------------------
function BR.Popup:Show(options)
    if not options or not options.title or not options.message then
        return
    end
    
    -- Set defaults
    local title = options.title
    local message = options.message
    local titleColor = options.titleColor or {1, 0.5, 0}
    local messageColor = options.messageColor or {1, 1, 1}
    local borderColor = options.borderColor or {1, 0.5, 0, 1}
    local displayTime = options.displayTime or 5
    local playSound = options.playSound
    -- rumble removed
    local iconPath = options.icon
    
    -- Create the frame
    local frame = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    frame:SetSize(BR.UI.PopupWidth, BR.UI.PopupMinHeight)
    frame:SetPoint("TOP", UIParent, "TOP", 0, -150)
    frame:SetBackdrop(BR.Backdrops.Popup)
    frame:SetBackdropColor(0.08, 0.08, 0.08, 0.95)
    frame:SetBackdropBorderColor(borderColor[1], borderColor[2], borderColor[3], borderColor[4] or 1)
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    
    
    -- Content positioning
    local yOffset = -18
    
    -- Icon (optional)
    local iconFrame
    if iconPath then
        iconFrame = CreateFrame("Frame", nil, frame)
        iconFrame:SetSize(32, 32)
        iconFrame:SetPoint("TOP", frame, "TOP", 0, yOffset)
        
        local icon = iconFrame:CreateTexture(nil, "ARTWORK")
        icon:SetAllPoints(iconFrame)
        icon:SetTexture(iconPath)
        
        yOffset = yOffset - 38
    end
    
    -- Title
    local titleText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    titleText:SetPoint("TOP", frame, "TOP", 0, yOffset)
    titleText:SetText(title)
    titleText:SetTextColor(titleColor[1], titleColor[2], titleColor[3])
    
    yOffset = yOffset - titleText:GetStringHeight() - 8
    
    -- Message
    local messageText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    messageText:SetPoint("TOP", frame, "TOP", 0, yOffset)
    messageText:SetWidth(BR.UI.PopupWidth - 30)
    messageText:SetJustifyH("CENTER")
    messageText:SetText(message)
    messageText:SetTextColor(messageColor[1], messageColor[2], messageColor[3])
    
    -- Adjust frame height based on content
    local contentHeight = 18 + titleText:GetStringHeight() + 8 + messageText:GetStringHeight() + 18
    if iconFrame then
        contentHeight = contentHeight + 38
    end
    frame:SetHeight(math.max(BR.UI.PopupMinHeight, contentHeight))
    
    -- Show the frame
    frame:SetAlpha(1)
    frame:Show()
    
    -- Play sound if specified and not muted
    if playSound and not BR:GetSetting("MuteNotificationSounds") then
        PlaySound(playSound)
    end
    
    -- Store in active popups
    table.insert(self.activePopups, frame)
    
    -- Schedule fade out and cleanup
    C_Timer.After(displayTime, function()
        -- Simple fade out
        local fadeTime = 0.5
        local startTime = GetTime()
        local ticker
        ticker = C_Timer.NewTicker(0.02, function()
            local elapsed = GetTime() - startTime
            if elapsed >= fadeTime then
                ticker:Cancel()
                frame:Hide()
                frame:SetParent(nil)
                -- Remove from active popups
                for i, popup in ipairs(BR.Popup.activePopups) do
                    if popup == frame then
                        table.remove(BR.Popup.activePopups, i)
                        break
                    end
                end
                return
            end
            frame:SetAlpha(1 - (elapsed / fadeTime))
        end)
    end)
    
    return frame
end

----------------------------------------------------------------------
--  Convenience Methods
----------------------------------------------------------------------
function BR.Popup:ShowWarning(title, message, displayTime)
    return self:Show({
        title = title,
        message = message,
        titleColor = {1, 0.2, 0.2},
        messageColor = {1, 1, 1},
        borderColor = {0.8, 0.1, 0.1, 1},
        displayTime = displayTime or 5,
        playSound = BR.Sounds.Warning
    })
end

function BR.Popup:ShowError(title, message, displayTime)
    return self:Show({
        title = title,
        message = message,
        titleColor = {1, 0.2, 0.2},
        messageColor = {1, 0.8, 0.8},
        borderColor = {0.8, 0, 0, 1},
        displayTime = displayTime or 5,
        playSound = BR.Sounds.Error
    })
end

function BR.Popup:ShowSuccess(title, message, displayTime)
    return self:Show({
        title = title,
        message = message,
        titleColor = {0.2, 1, 0.2},
        messageColor = {0.9, 1, 0.9},
        borderColor = {0, 0.7, 0, 1},
        displayTime = displayTime or 4,
        playSound = BR.Sounds.Success
    })
end

function BR.Popup:ShowInfo(title, message, displayTime)
    return self:Show({
        title = title,
        message = message,
        titleColor = {0.4, 0.8, 1},
        messageColor = {1, 1, 1},
        borderColor = {0.3, 0.6, 1, 1},
        displayTime = displayTime or 4,
    })
end

----------------------------------------------------------------------
--  Hide All Popups
----------------------------------------------------------------------
function BR.Popup:HideAll()
    for _, popup in ipairs(self.activePopups) do
        if popup then
            popup:Hide()
            popup:SetParent(nil)
        end
    end
    wipe(self.activePopups)
end

----------------------------------------------------------------------
--  BR Namespace Shortcuts
----------------------------------------------------------------------
function BR:ShowPopup(options)
    return BR.Popup:Show(options)
end

function BR:ShowWarningPopup(title, message, displayTime)
    return BR.Popup:ShowWarning(title, message, displayTime)
end

function BR:ShowErrorPopup(title, message, displayTime)
    return BR.Popup:ShowError(title, message, displayTime)
end

function BR:ShowSuccessPopup(title, message, displayTime)
    return BR.Popup:ShowSuccess(title, message, displayTime)
end

function BR:ShowInfoPopup(title, message, displayTime)
    return BR.Popup:ShowInfo(title, message, displayTime)
end

function BR:HideAllPopups()
    BR.Popup:HideAll()
end
