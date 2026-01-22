----------------------------------------------------------------------
--  QualityOfLife Module - Quality of Life Features
--  Enthält nützliche Shortcuts und Hilfsfunktionen
----------------------------------------------------------------------

local BR = _G.AllforOne
if not BR then return end

local QualityOfLife = {}
BR.QualityOfLife = QualityOfLife

----------------------------------------------------------------------
--  Slash Commands
----------------------------------------------------------------------

local function RegisterSlashCommands()
    -- /rl als Alias für /reload
    SLASH_ALLFORONE_RL1 = "/rl"
    SlashCmdList["ALLFORONE_RL"] = function()
        ReloadUI()
    end
    
    -- /rc als Alias für Ready Check (nur für Gruppenleiter)
    SLASH_ALLFORONE_RC1 = "/rc"
    SlashCmdList["ALLFORONE_RC"] = function()
        if UnitIsGroupLeader("player") or UnitIsGroupAssistant("player") then
            DoReadyCheck()
        else
            BR:Print("Du musst Gruppenleiter oder Assistent sein.", "warning")
        end
    end
    
    -- /inv <name> als Kurzform für Einladung
    SLASH_ALLFORONE_INV1 = "/inv"
    SlashCmdList["ALLFORONE_INV"] = function(msg)
        if msg and msg ~= "" then
            C_PartyInfo.InviteUnit(msg)
        else
            BR:Print("Verwendung: /inv <Spielername>", "info")
        end
    end
    
    BR:Debug("QualityOfLife: Slash Commands registriert")
end

----------------------------------------------------------------------
--  Module Lifecycle
----------------------------------------------------------------------

function QualityOfLife:OnInitialize()
    BR:Debug("QualityOfLife module initialized")
end

function QualityOfLife:OnEnable()
    RegisterSlashCommands()
    BR:Debug("QualityOfLife module enabled")
end

function QualityOfLife:OnDisable()
    BR:Debug("QualityOfLife module disabled")
end

function QualityOfLife:Refresh()
    -- Nichts zu aktualisieren
end

----------------------------------------------------------------------
--  Module Registration
----------------------------------------------------------------------

BR:RegisterModule("QualityOfLife", QualityOfLife)
