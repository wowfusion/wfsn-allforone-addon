----------------------------------------------------------------------
--  All for One - Constants
--  Shared constants for colors, backdrops, and UI definitions
----------------------------------------------------------------------

local addonName, BR = ...

----------------------------------------------------------------------
--  Version
----------------------------------------------------------------------
BR.Version = BR.Version or "1.0.1"

----------------------------------------------------------------------
--  Colors
----------------------------------------------------------------------
BR.Colors = BR.Colors or {}
BR.Colors.Primary = "|cFF00CCFF"      -- Cyan/Blue
BR.Colors.Guild = "|cFFCBB57B"        -- Gold (Guild name color)
BR.Colors.Warning = "|cFFFFAA00"      -- Orange
BR.Colors.Error = "|cFFFF4444"        -- Red
BR.Colors.Success = "|cFF44FF44"      -- Light Green
BR.Colors.Info = "|cFF88CCFF"         -- Light Blue
BR.Colors.Muted = "|cFF888888"        -- Gray
BR.Colors.Gold = "|cFFCBB57B"         -- Gold #CBB57B
BR.Colors.White = "|cFFFFFFFF"        -- White

----------------------------------------------------------------------
--  Backdrop Definitions
----------------------------------------------------------------------
-- Einheitlicher Rahmen für alle Fenster
BR.Backdrops = {
    -- Standard window backdrop (same as Popup for consistency)
    Window = {
        bgFile = "Interface\\BUTTONS\\WHITE8X8",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    },
    
    -- Popup/notification backdrop (same as Window)
    Popup = {
        bgFile = "Interface\\BUTTONS\\WHITE8X8",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    },
    
    -- Tooltip-style backdrop
    Tooltip = {
        bgFile = "Interface\\BUTTONS\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    },
    
    -- Simple flat backdrop
    Flat = {
        bgFile = "Interface\\BUTTONS\\WHITE8X8",
        edgeFile = "Interface\\BUTTONS\\WHITE8X8",
        tile = false,
        edgeSize = 1,
        insets = { left = 0, right = 0, top = 0, bottom = 0 }
    },
}

-- Default border color for windows (gold #CBB57B)
BR.UI = BR.UI or {}
BR.UI.DefaultBorderColor = {0.796, 0.71, 0.482, 1}  -- Gold #CBB57B

----------------------------------------------------------------------
--  Sound IDs
----------------------------------------------------------------------
BR.Sounds = {
    Warning = SOUNDKIT.RAID_WARNING,
    Error = SOUNDKIT.IG_CREATURE_AGGRO,
    Success = SOUNDKIT.READY_CHECK,
    Info = SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON,
    Click = SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON,
}

----------------------------------------------------------------------
--  UI Constants
----------------------------------------------------------------------
BR.UI = BR.UI or {}
BR.UI.DefaultFrameStrata = "DIALOG"
BR.UI.PopupWidth = 380
BR.UI.PopupMinHeight = 90
BR.UI.WindowPadding = 20
BR.UI.ButtonHeight = 26
BR.UI.CheckboxSize = 24
