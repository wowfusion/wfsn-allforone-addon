----------------------------------------------------------------------
--  All for One - Crafting Order Block Module
--  Block public and personal crafting orders, allow guild orders only
----------------------------------------------------------------------

local addonName, BR = ...

local CraftingOrderBlock = {
    enabled = false,
    apiHooked = false,
    lastNotifyTime = 0,
}

-- Order type constants - use Enum if available, fallback to hardcoded
local ORDER_TYPE_PUBLIC = Enum and Enum.CraftingOrderType and Enum.CraftingOrderType.Public or 1
local ORDER_TYPE_GUILD = Enum and Enum.CraftingOrderType and Enum.CraftingOrderType.Guild or 2
local ORDER_TYPE_PERSONAL = Enum and Enum.CraftingOrderType and Enum.CraftingOrderType.Personal or 3

function CraftingOrderBlock:OnInitialize()
    BR:Debug("CraftingOrderBlock module initialized")
    BR:Debug("ORDER_TYPE_PUBLIC=" .. tostring(ORDER_TYPE_PUBLIC) .. ", GUILD=" .. tostring(ORDER_TYPE_GUILD) .. ", PERSONAL=" .. tostring(ORDER_TYPE_PERSONAL))
    self:HookAPI()
end

function CraftingOrderBlock:OnEnable()
    if not BR:GetSetting("BlockCraftingOrders") then return end
    self.enabled = true
    BR:Debug("CraftingOrderBlock enabled")
end

function CraftingOrderBlock:OnDisable()
    self.enabled = false
end

function CraftingOrderBlock:Refresh()
    self.enabled = BR:GetSetting("BlockCraftingOrders") == true
end

function CraftingOrderBlock:ShouldBlock()
    return self.enabled and BR:GetSetting("BlockCraftingOrders")
end

function CraftingOrderBlock:NotifyBlocked(orderType)
    local now = GetTime()
    if now - self.lastNotifyTime < 2 then return end
    self.lastNotifyTime = now
    
    local title, msg
    if orderType == "public" then
        title = "Öffentlicher Auftrag blockiert"
        msg = "Öffentliche Handwerksaufträge sind nicht erlaubt.\nNur Gildenaufträge sind im Guildfound-Modus möglich!"
    else
        title = "Persönlicher Auftrag blockiert"
        msg = "Persönliche Handwerksaufträge sind nicht erlaubt.\nNur Gildenaufträge sind im Guildfound-Modus möglich!"
    end
    
    if BR.ShowWarningPopup then
        BR:ShowWarningPopup(title, msg, 4)
    else
        BR:Notify(title .. " - " .. msg, "warning")
    end
end

-- Hook the API to block orders - this is the ONLY reliable method
function CraftingOrderBlock:HookAPI()
    if self.apiHooked then return end
    
    if not C_CraftingOrders then
        BR:Debug("C_CraftingOrders not available yet")
        return
    end
    
    -- Hook C_CraftingOrders.PlaceNewOrder
    if C_CraftingOrders.PlaceNewOrder then
        local originalPlaceNewOrder = C_CraftingOrders.PlaceNewOrder
        C_CraftingOrders.PlaceNewOrder = function(orderInfo)
            -- Debug output
            if orderInfo then
                BR:Debug("PlaceNewOrder called - orderType: " .. tostring(orderInfo.orderType))
            end
            
            if CraftingOrderBlock:ShouldBlock() and orderInfo then
                local orderType = orderInfo.orderType
                BR:Debug("Checking orderType " .. tostring(orderType) .. " against PUBLIC=" .. tostring(ORDER_TYPE_PUBLIC) .. " PERSONAL=" .. tostring(ORDER_TYPE_PERSONAL))
                
                if orderType == ORDER_TYPE_PUBLIC then
                    CraftingOrderBlock:NotifyBlocked("public")
                    BR:Debug("BLOCKED: Public order")
                    -- Reset UI state so user can switch to guild order
                    C_Timer.After(0.1, function()
                        CraftingOrderBlock:ResetFormState()
                    end)
                    return
                elseif orderType == ORDER_TYPE_PERSONAL then
                    CraftingOrderBlock:NotifyBlocked("personal")
                    BR:Debug("BLOCKED: Personal order")
                    -- Reset UI state so user can switch to guild order
                    C_Timer.After(0.1, function()
                        CraftingOrderBlock:ResetFormState()
                    end)
                    return
                else
                    BR:Debug("ALLOWED: Guild order (type " .. tostring(orderType) .. ")")
                end
            end
            return originalPlaceNewOrder(orderInfo)
        end
        self.apiHooked = true
        BR:Debug("C_CraftingOrders.PlaceNewOrder hooked successfully")
        BR:Print("Handwerksaufträge-Block aktiv", "info")
    else
        BR:Debug("C_CraftingOrders.PlaceNewOrder not found")
    end
end

-- Reset the form state after blocking so user can still submit guild orders
function CraftingOrderBlock:ResetFormState()
    if not ProfessionsCustomerOrdersFrame then return end
    local form = ProfessionsCustomerOrdersFrame.Form
    if not form then return end
    
    -- Try to re-enable the place order button
    if form.PlaceOrderButton then
        form.PlaceOrderButton:SetEnabled(true)
    end
    
    -- Try to call UpdateOrderButton if it exists
    if form.UpdateState then
        pcall(function() form:UpdateState() end)
    end
    if form.UpdateOrderButton then
        pcall(function() form:UpdateOrderButton() end)
    end
    
    -- Refresh the form
    if form.Refresh then
        pcall(function() form:Refresh() end)
    end
    
    BR:Debug("Form state reset after block")
end

BR:RegisterModule("CraftingOrderBlock", CraftingOrderBlock)
