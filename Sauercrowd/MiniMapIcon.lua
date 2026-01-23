local LDB = LibStub:GetLibrary("LibDataBroker-1.1", true)
local DBIcon = LibStub:GetLibrary("LibDBIcon-1.0", true)

if LDB then
	Sauercrowd.minimapDataObject = LDB:NewDataObject(Sauercrowd.name, {
		type = "launcher",
		label = Sauercrowd.name,
		icon = "Interface\\AddOns\\Sauercrowd\\media\\minimap_sc_skull",
		OnClick = function(_, button)
			if button == "LeftButton" then
				Sauercrowd:ToggleDeathLogWindow()
			end
		end,
		OnEnter = function(selfFrame)
			GameTooltip:SetOwner(selfFrame, "ANCHOR_RIGHT")
			GameTooltip:AddLine(Sauercrowd.name, 1.45, 0.29, 0.29)
			GameTooltip:AddLine("Version: " .. (Sauercrowd.version or "Unbekannt"), 1, 1, 1)
			GameTooltip:AddLine("Linksklick: Deathlog", 1, 1, 1)
			GameTooltip:Show()
		end,
		OnLeave = function()
			GameTooltip:Hide()
		end
	})
end

function Sauercrowd:InitMinimapIcon()
	if not DBIcon or not Sauercrowd.minimapDataObject then
		return
	end

	if not Sauercrowd.minimapRegistered then
		Sauercrowd.db = Sauercrowd.db or {}
		Sauercrowd.db.minimap = Sauercrowd.db.minimap or { hide = false }
		DBIcon:Register(Sauercrowd.name, Sauercrowd.minimapDataObject, Sauercrowd.db.minimap)
		Sauercrowd.minimapRegistered = true
	end
end
