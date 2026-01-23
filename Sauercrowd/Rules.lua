Sauercrowd.Rules = {}

function Sauercrowd.Rules.ProhibitMailboxUsage()
	CloseMail()
	Sauercrowd.Popup:Show({
		title = "Briefkasten gesperrt!",
		message = "Die Nutzung des Briefkastens ist während des Events nicht erlaubt.",
		displayTime = 3
	})
end

function Sauercrowd.Rules.ProhibitAuctionhouseUsage()
	-- Attempt to use CloseAuctionHouse as a fallback
    if CloseAuctionHouse then
        CloseAuctionHouse() -- Built-in function to close the Auction House
    end

    if AuctionFrame and AuctionFrame:IsShown() then
        AuctionFrame:Hide() -- Directly hide the frame
    end

	Sauercrowd.Popup:Show({
		title = "Auktionshaus gesperrt!",
		message = "Die Nutzung des Auktionshauses ist während des Events nicht erlaubt.",
		displayTime = 3
	})
end

function Sauercrowd.Rules:ProhibitTradeWithNonGuildMembers()
	local tradePartner = UnitName("NPC")
	if tradePartner then
		local guild = GetGuildInfo("NPC")
		local playerGuild = GetGuildInfo("player")
		if not guild or guild ~= playerGuild then
			CancelTrade()
			Sauercrowd.Popup:Show({
				title = "Handel blockiert!",
				message = "Du kannst nur mit Gildenmitgliedern handeln.",
				displayTime = 3
			})
		end
	end
end

function Sauercrowd.Rules:ProhibitGroupingWithNonGuildMembers()
	-- Request fresh guild roster data
	C_GuildInfo.GuildRoster()

	-- Build list of all guild members
	local guildMembers = {}
	local numTotalGuildMembers = GetNumGuildMembers()
	for i = 1, numTotalGuildMembers do
		local name = GetGuildRosterInfo(i)
		if name then
			table.insert(guildMembers, Sauercrowd:RemoveRealmFromName(name))
		end
	end

	-- Check all group members
	local numGroupMembers = GetNumGroupMembers()
	for i = 1, numGroupMembers do
		local memberName = UnitName("party" .. i) or UnitName("raid" .. i)
		if memberName then
			local shortMemberName = Sauercrowd:RemoveRealmFromName(memberName)
			local isInGuild = tContains(guildMembers, shortMemberName)

			if not isInGuild then
				LeaveParty()
				Sauercrowd.Popup:Show({
					title = "Gruppe verlassen!",
					message = "Du kannst nur mit Gildenmitgliedern in einer Gruppe sein.",
					displayTime = 3
				})
				return
			end
		end
	end
end

function Sauercrowd.Rules:Initialize()
	Sauercrowd.EventManager:RegisterHandler("MAIL_SHOW",
		function()
			Sauercrowd.Rules.ProhibitMailboxUsage()
		end, 0, "MailboxBlock")

	-- Hook AuctionFrame directly to catch cases where event doesn't fire due to Blizzard errors
	Sauercrowd.EventManager:RegisterHandler("AUCTION_HOUSE_SHOW",
		function()
			Sauercrowd.Rules.ProhibitAuctionhouseUsage()
		end, 0, "AuctionHouseBlock")

	Sauercrowd.EventManager:RegisterHandler("TRADE_SHOW",
		function()
			Sauercrowd.Rules:ProhibitTradeWithNonGuildMembers()
		end, 0, "TradeBlock")

	-- Instantly decline party invites from non-guild members
	Sauercrowd.EventManager:RegisterHandler("PARTY_INVITE_REQUEST",
		function(event, sender)
			local isInGuild = Sauercrowd.GuildCache:IsGuildMember(sender)
			if not isInGuild then
				StaticPopup_Hide("PARTY_INVITE")
				DeclineGroup()
			end
		end, 0, "PartyInviteCheck")

	Sauercrowd.EventManager:RegisterHandler("GROUP_ROSTER_UPDATE",
		function()
			Sauercrowd.Rules:ProhibitGroupingWithNonGuildMembers()
		end, 0, "GroupRosterCheck")

	Sauercrowd.EventManager:RegisterHandler("RAID_ROSTER_UPDATE",
		function()
			Sauercrowd.Rules:ProhibitGroupingWithNonGuildMembers()
		end, 0, "RaidRosterCheck")
end
