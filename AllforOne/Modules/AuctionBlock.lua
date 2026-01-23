----------------------------------------------------------------------
--  All for One - Auction House Block Module
--  Block access to Auction House
----------------------------------------------------------------------

local addonName, BR = ...

local AuctionBlock = {}
local lastNotifyTime = 0
local frameHooked = false
local showHooked = false
local closeTicker

local PLAYER_INTERACTION = Enum and Enum.PlayerInteractionType

-- Helpers --------------------------------------------------------------------
local function ShouldBlock()
    return BR:GetSetting("BlockAuction") == true
end

local function NotifyBlocked()
    local now = GetTime()
    if now - lastNotifyTime < 2 then
        return
    end
    lastNotifyTime = now
    
    if BR.ShowWarningPopup then
        BR:ShowWarningPopup("Auktionshaus blockiert", "Das Auktionshaus ist im Guildfound-Modus gesperrt.\nHandel nur über Gildenmitglieder!", 4)
    else
        BR:Notify("Auktionshaus blockiert! Handel nur über Gildenmitglieder.", "warning")
    end
end

local function ClearKeyboardFocus()
    if GetCurrentKeyBoardFocus then
        local focus = GetCurrentKeyBoardFocus()
        if focus then
            focus:ClearFocus()
        end
    end
end

local function CloseAuctionFrame()
    if C_AuctionHouse and C_AuctionHouse.CloseAuctionHouse then
        C_AuctionHouse.CloseAuctionHouse()
    elseif CloseAuctionHouse then
        CloseAuctionHouse()
    end
    if PLAYER_INTERACTION and C_PlayerInteractionManager then
        C_PlayerInteractionManager.ClearInteraction(PLAYER_INTERACTION.Auctioneer)
    end
    if AuctionHouseFrame then
        AuctionHouseFrame:SetAlpha(0)
        HideUIPanel(AuctionHouseFrame)
        AuctionHouseFrame:Hide()
        C_Timer.After(0.1, function()
            if AuctionHouseFrame then
                AuctionHouseFrame:SetAlpha(1)
            end
        end)
    end

    C_Timer.After(0.05, ClearKeyboardFocus)
end

local function HandleAuctionAttempt()
    if not ShouldBlock() then return end

    if closeTicker then
        closeTicker:Cancel()
        closeTicker = nil
    end

    local attempts = 0
    closeTicker = C_Timer.NewTicker(0.05, function(ticker)
        attempts = attempts + 1
        CloseAuctionFrame()
        if attempts >= 8 then
            ticker:Cancel()
            closeTicker = nil
        end
    end)

    NotifyBlocked()
end

local function HookAuctionFrame()
    if frameHooked then return end
    if not AuctionHouseFrame then return end

    frameHooked = true
    AuctionHouseFrame:HookScript("OnShow", function()
        HandleAuctionAttempt()
    end)
end

local function HookShowUIPanel()
    if showHooked then return end
    showHooked = true

    hooksecurefunc("ShowUIPanel", function(frame)
        if frame and frame.GetName and frame:GetName() == "AuctionHouseFrame" then
            HandleAuctionAttempt()
        end
    end)
end

-- Events ---------------------------------------------------------------------
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_INTERACTION_MANAGER_FRAME_SHOW")
eventFrame:RegisterEvent("AUCTION_HOUSE_SHOW")
eventFrame:RegisterEvent("ADDON_LOADED")

eventFrame:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" and arg1 == "Blizzard_AuctionHouseUI" then
        HookAuctionFrame()
    elseif event == "PLAYER_INTERACTION_MANAGER_FRAME_SHOW" then
        if PLAYER_INTERACTION and arg1 == PLAYER_INTERACTION.Auctioneer then
            HandleAuctionAttempt()
        end
    elseif event == "AUCTION_HOUSE_SHOW" then
        HandleAuctionAttempt()
    end
end)

-- Module API -----------------------------------------------------------------
function AuctionBlock:OnInitialize()
    if AuctionHouseFrame then
        HookAuctionFrame()
    end
    HookShowUIPanel()
end

function AuctionBlock:OnEnable() end
function AuctionBlock:OnDisable() end
function AuctionBlock:Refresh() end

BR:RegisterModule("AuctionBlock", AuctionBlock)
