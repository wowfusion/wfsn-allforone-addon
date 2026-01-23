Sauercrowd.LevelUps = {}

function Sauercrowd.LevelUps:Initialize()
	Sauercrowd.EventManager:RegisterHandler("PLAYER_LEVEL_UP",
		function(_, level)
			for _, milestone in pairs(Sauercrowd.Constants.LEVEL_MILESTONES) do
				if level == milestone then
					local player = UnitName("player")
					local message = player .. " hat Level " .. level .. " erreicht!"
					SendChatMessage(message, "GUILD")
					break
				end
			end
		end, 50, "LevelMilestoneAnnouncer")
end
