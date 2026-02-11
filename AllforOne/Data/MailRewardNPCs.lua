----------------------------------------------------------------------
--  All for One - Mail Reward NPCs Database
--  NPCs that send quest rewards via mail but allow direct pickup
--  These NPCs should be whitelisted for interaction even when mail is blocked
----------------------------------------------------------------------

local addonName, BR = ...

-- NPC Database: [NPC_ID] = { name = "NPC Name", names = {"name1", "name2"}, zone = "Zone", note = "Description" }
-- "names" contains all localized versions of the NPC name for whitelist matching
BR.MailRewardNPCs = {
    -- Warlords of Draenor
    [84973] = {
        name = "Exarch Akama",
        names = {"exarch akama"},
        zone = "Shadowmoon Valley",
        note = "Garrison Campaign quest rewards"
    },
    [87365] = {
        name = "Grakis",
        names = {"grakis"},
        zone = "Stormshield",
        note = "Archaeology Fragments vendor, quest rewards"
    },
    
    -- Dragonflight (multiple Vaskarn NPCs exist)
    [203404] = {
        name = "Vaskarn",
        names = {"vaskarn"},
        zone = "Zaralek Cavern / Valdrakken",
        note = "Shadowflame Crest Exchange vendor, quest rewards"
    },
    
    -- Wrath of the Lich King
    [28930] = {
        name = "Dansel Adams",
        names = {"dansel adams"},
        zone = "Plaguewood",
        note = "Scarlet Crusade hunter, quest rewards"
    },
    
    -- System / Blizzard
    [32842] = {
        name = "The WoW Dev Team",
        names = {"the wow dev team", "das entwicklerteam von wow", "das wow-entwicklerteam", "wow dev team", "entwicklerteam"},
        zone = "System",
        note = "Blizzard system mail for returning players, achievements, etc."
    },

    -- Legion / Battle for Azeroth / The War Within
    [122292] = {
        name = "Thaumaturg Vashreen",
        names = {"thaumaturg vashreen", "thaumaturge vashreen", "vashreen"},
        zone = "Dalaran / Oribos / Dornogal",
        note = "Ethereal vendor for upgrade items and tokens"
    },
    
    -- Classic / Felwood
    [10920] = {
        name = "Kelek Skykeeper",
        names = {"kelek skykeeper", "kelek himmelshüter"},
        zone = "Felwood",
        note = "Quest reward mail sender"
    },
    
    -- Dragonflight
    [198505] = {
        name = "Blue",
        names = {"blue", "blau"},
        zone = "Dragon Isles",
        note = "Dragon whelpling, quest reward mail sender"
    },
    
    -- Battle for Azeroth / Island Expeditions
    [142065] = {
        name = "Dana Pull",
        names = {"dana pull"},
        zone = "Boralus / Dazar'alor",
        note = "Island Expedition reward mail sender"
    },
    
    -- Warlords of Draenor
    [79608] = {
        name = "Yrel",
        names = {"yrel"},
        zone = "Shadowmoon Valley / Nagrand",
        note = "Draenei Paladin, quest reward mail sender"
    },
    
    -- Wrath of the Lich King / Argent Tournament
    [33817] = {
        name = "Justicar Mariel Trueheart",
        names = {"justicar mariel trueheart", "justiziarin mariel treuherz"},
        zone = "Icecrown / Argent Tournament",
        note = "Argent Tournament quest reward mail sender"
    },
    
    -- The War Within / Radiant Echoes
    [205818] = {
        name = "Initiate Oman",
        names = {"initiate oman"},
        zone = "Blasted Lands",
        note = "Quest reward mail sender"
    },
    
    -- The War Within / Reno Jackson
    [226250] = {
        name = "Reno Jackson",
        names = {"reno jackson"},
        zone = "Dornogal / Khaz Algar",
        note = "Quest reward mail sender"
    },
}

-- Helper function to check if an NPC is in the mail reward list
function BR:IsMailRewardNPC(npcID)
    if not npcID then return false end
    return self.MailRewardNPCs[npcID] ~= nil
end

-- Helper function to get NPC info
function BR:GetMailRewardNPCInfo(npcID)
    if not npcID then return nil end
    return self.MailRewardNPCs[npcID]
end

-- Debug: Print all mail reward NPCs
function BR:PrintMailRewardNPCs()
    self:Print("Mail Reward NPCs (Quest-Belohnungen per Post):", "info")
    for npcID, data in pairs(self.MailRewardNPCs) do
        self:Print(string.format("  [%d] %s (%s)", npcID, data.name, data.zone), "info")
    end
end
