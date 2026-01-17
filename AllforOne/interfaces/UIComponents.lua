----------------------------------------------------------------------
--  All for One - UI Components
--  Reusable UI components for consistent look and feel
----------------------------------------------------------------------

local addonName, BR = ...

BR.UIComponents = {}

----------------------------------------------------------------------
--  Create a styled window frame
----------------------------------------------------------------------
function BR.UIComponents:CreateWindow(name, width, height, title)
    local frame = CreateFrame("Frame", name, UIParent, "BackdropTemplate")
    frame:SetSize(width, height)
    frame:SetPoint("CENTER")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetFrameStrata(BR.UI.DefaultFrameStrata)
    frame:SetClampedToScreen(true)
    
    frame:SetBackdrop(BR.Backdrops.Window)
    frame:SetBackdropColor(0.05, 0.05, 0.05, 0.98)
    
    -- Title bar
    if title then
        local titleBar = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        titleBar:SetPoint("TOP", 0, -15)
        titleBar:SetText(BR.Colors.Primary .. title .. "|r")
        frame.titleBar = titleBar
    end
    
    -- Close button
    local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -5, -5)
    closeBtn:SetScript("OnClick", function() frame:Hide() end)
    frame.closeBtn = closeBtn
    
    frame:Hide()
    return frame
end

----------------------------------------------------------------------
--  Create a styled button
----------------------------------------------------------------------
function BR.UIComponents:CreateButton(parent, width, height, text, onClick)
    local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    btn:SetSize(width, height or BR.UI.ButtonHeight)
    btn:SetText(text)
    
    if onClick then
        btn:SetScript("OnClick", onClick)
    end
    
    return btn
end

----------------------------------------------------------------------
--  Create a styled checkbox
----------------------------------------------------------------------
function BR.UIComponents:CreateCheckbox(parent, settingKey, label, tooltip)
    local container = CreateFrame("Frame", nil, parent)
    container:SetSize(250, 24)
    
    local checkbox = CreateFrame("CheckButton", nil, container, "UICheckButtonTemplate")
    checkbox:SetPoint("LEFT", 0, 0)
    checkbox:SetSize(BR.UI.CheckboxSize, BR.UI.CheckboxSize)
    
    local text = container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    text:SetPoint("LEFT", checkbox, "RIGHT", 5, 0)
    text:SetText(label)
    
    -- Set initial state
    if settingKey and BR.GetSetting then
        checkbox:SetChecked(BR:GetSetting(settingKey))
    end
    
    -- Handle click
    checkbox:SetScript("OnClick", function(self)
        local checked = self:GetChecked()
        if settingKey and BR.SetSetting then
            BR:SetSetting(settingKey, checked, true)
        end
        if BR.Sounds then
            PlaySound(BR.Sounds.Click)
        end
    end)
    
    -- Tooltip
    if tooltip then
        checkbox:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(label, 1, 1, 1)
            GameTooltip:AddLine(tooltip, 0.8, 0.8, 0.8, true)
            GameTooltip:Show()
        end)
        checkbox:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end
    
    container.checkbox = checkbox
    container.settingKey = settingKey
    
    -- Refresh method
    function container:Refresh()
        if settingKey and BR.GetSetting then
            checkbox:SetChecked(BR:GetSetting(settingKey))
        end
    end
    
    return container
end

----------------------------------------------------------------------
--  Create a section title
----------------------------------------------------------------------
function BR.UIComponents:CreateSectionTitle(parent, text, color)
    local title = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetText((color or BR.Colors.Info) .. text .. "|r")
    return title
end

----------------------------------------------------------------------
--  Create a separator line
----------------------------------------------------------------------
function BR.UIComponents:CreateSeparator(parent, width)
    local sep = parent:CreateTexture(nil, "ARTWORK")
    sep:SetSize(width or 400, 1)
    sep:SetColorTexture(0.3, 0.3, 0.3, 0.8)
    return sep
end

----------------------------------------------------------------------
--  Create a scroll frame
----------------------------------------------------------------------
function BR.UIComponents:CreateScrollFrame(parent, width, height)
    local scrollFrame = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
    scrollFrame:SetSize(width, height)
    
    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(width - 20, height)
    scrollFrame:SetScrollChild(scrollChild)
    
    scrollFrame.content = scrollChild
    return scrollFrame
end

----------------------------------------------------------------------
--  Create an info text
----------------------------------------------------------------------
function BR.UIComponents:CreateInfoText(parent, text, width)
    local info = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    info:SetWidth(width or 400)
    info:SetJustifyH("LEFT")
    info:SetText(text)
    return info
end

----------------------------------------------------------------------
--  Fade in animation
----------------------------------------------------------------------
function BR.UIComponents:FadeIn(frame, duration)
    duration = duration or 0.3
    frame:SetAlpha(0)
    frame:Show()
    
    local fadeIn = frame:CreateAnimationGroup()
    local alpha = fadeIn:CreateAnimation("Alpha")
    alpha:SetFromAlpha(0)
    alpha:SetToAlpha(1)
    alpha:SetDuration(duration)
    fadeIn:SetScript("OnFinished", function()
        frame:SetAlpha(1)
    end)
    fadeIn:Play()
end

----------------------------------------------------------------------
--  Fade out animation
----------------------------------------------------------------------
function BR.UIComponents:FadeOut(frame, duration, onFinished)
    duration = duration or 0.3
    
    local fadeOut = frame:CreateAnimationGroup()
    local alpha = fadeOut:CreateAnimation("Alpha")
    alpha:SetFromAlpha(1)
    alpha:SetToAlpha(0)
    alpha:SetDuration(duration)
    fadeOut:SetScript("OnFinished", function()
        frame:Hide()
        frame:SetAlpha(1)
        if onFinished then
            onFinished()
        end
    end)
    fadeOut:Play()
end
