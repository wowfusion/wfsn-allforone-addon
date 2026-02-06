----------------------------------------------------------------------
--  All for One - Shame Messages Database
--  Nachrichten für Warbound-Bank Aktionen (Schande + Sensibel)
--  
--  Jeder Spieler kann individuell wählen ob "Schande" (default)
--  oder "sensible" Nachrichten im Gildenchat gepostet werden.
----------------------------------------------------------------------

local addonName, BR = ...

-- Platzhalter:
-- {details} = Gold-Betrag oder Item-Name/Link
-- {count}   = Anzahl verschiedener Gegenstände (für Batch-Nachrichten)

BR.ShameMessages = {
    -- Standard: Klassische Scham-Nachrichten (Default)
    shame = {
        deposit_gold = "[Schande] Ich beichte… {details} in die Kriegsmeutenbank eingezahlt. Möge man mir vergeben.",
        withdraw_gold = "[Schande] Ich habe mir frech {details} aus der Kriegsmeutenbank geschnappt. Die Schande wiegt schwer.",
        deposit_item = "[Schande] Ich habe {details} in die Kriegsmeutenbank geworfen. Opfergabe entrichtet.",
        withdraw_item = "[Schande] Ja… ich war's. {details} aus der Kriegsmeutenbank stibitzt. Ertappt!",
        deposit_all = "[Schande] Ich habe einfach ALLES in die Kriegsmeutenbank gekippt. Chaosmodus aktiviert.",
        currency_transfer = "[Schande] Ich habe {details} verschoben. Finanzakrobatik vom Feinsten. Verurteilt mich ruhig.",
        deposit_item_batch = "[Schande] Ich habe {count} verschiedene Gegenstände in die Kriegsmeutenbank geschaufelt. Organisiertes Chaos!",
        withdraw_item_batch = "[Schande] Ich habe {count} verschiedene Gegenstände aus der Kriegsmeutenbank geplündert. Großrazzia!",
    },

    -- Sensibel: Sachliche Nachrichten ohne Scham-Formulierung
    sensitive = {
        deposit_gold = "[Sensibel] {details} wurden in die Kriegsmeutenbank eingezahlt.",
        withdraw_gold = "[Sensibel] {details} wurden aus der Kriegsmeutenbank entnommen.",
        deposit_item = "[Sensibel] {details} wurden in die Kriegsmeutenbank eingelagert.",
        withdraw_item = "[Sensibel] {details} wurden aus der Kriegsmeutenbank entnommen.",
        deposit_all = "[Sensibel] Mehrere Gegenstände wurden in die Kriegsmeutenbank eingelagert.",
        currency_transfer = "[Sensibel] {details} wurden auf einen anderen Charakter übertragen.",
        deposit_item_batch = "[Sensibel] {count} verschiedene Gegenstände wurden in die Kriegsmeutenbank eingelagert.",
        withdraw_item_batch = "[Sensibel] {count} verschiedene Gegenstände wurden aus der Kriegsmeutenbank entnommen.",
    }
}

-- Hilfsfunktion: Nachricht für eine Aktion abrufen
function BR:GetShameMessage(action, details)
    local mode = self:GetSetting("SensitiveShameMode") and "sensitive" or "shame"
    local messages = self.ShameMessages[mode]
    
    if not messages or not messages[action] then
        return nil
    end
    
    local msg = messages[action]
    -- Platzhalter ersetzen
    if details then
        msg = msg:gsub("{details}", tostring(details))
    else
        msg = msg:gsub("{details}", "etwas")
    end
    -- {count} Platzhalter für Batch-Nachrichten
    msg = msg:gsub("{count}", tostring(details or 0))
    
    return msg
end
