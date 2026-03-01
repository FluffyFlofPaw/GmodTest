-- sh_scp_shop_config.lua
-- Shared configuration for the SCP Shop System
-- Loaded on both client and server

SCPShop = SCPShop or {}
SCPShop.Config = SCPShop.Config or {}

-- Währungssymbol / Currency symbol
SCPShop.Config.Currency = "$"

-- Standard-NPC-Modell / Default NPC model
SCPShop.Config.DefaultNPCModel = "models/breen.mdl"

-- Interaktionsdistanz / Interaction distance (in units)
SCPShop.Config.InteractionDistance = 100

-- Chat-Command zum Speichern aller Shop-NPCs / Chat command to save all shop NPCs
SCPShop.Config.SaveCommand = "!saveshops"

-- ULX Admin-Gruppen die Zugriff auf das Admin-Menü haben
-- ULX admin groups that have access to the admin menu
SCPShop.Config.AdminGroups = {
    "superadmin",
    "admin",
    "operator",
}

-- Job-Gruppen-System: Ordnet DarkRP-Jobs Gruppen zu
-- Job group system: assigns DarkRP jobs to groups
SCPShop.Config.JobGroups = {
    ["D-Klassen"] = {
        "Class-D",
        "Schwere D-Klasse",
    },
    ["Wissenschaftler"] = {
        "Wissenschaftler",
        "Leitender Wissenschaftler",
    },
    ["MTF"] = {
        "MTF Soldat",
        "MTF Kommandant",
    },
}

-- Hilfsfunktion: Prüft ob ein Spieler in einer bestimmten Job-Gruppe ist
-- Helper: checks if a player belongs to a specific job group
function SCPShop.IsPlayerInJobGroup(ply, groupName)
    if not IsValid(ply) then return false end
    local jobs = SCPShop.Config.JobGroups[groupName]
    if not jobs then return false end
    local jobName = ply:getDarkRPVar("job") or ""
    for _, job in ipairs(jobs) do
        if string.lower(job) == string.lower(jobName) then
            return true
        end
    end
    return false
end

-- Hilfsfunktion: Prüft ob ein Spieler Admin-Rechte für das Shop-System hat
-- Helper: checks if a player has admin rights for the shop system
function SCPShop.IsAdmin(ply)
    if not IsValid(ply) then return false end
    local group = ply:GetUserGroup()
    for _, adminGroup in ipairs(SCPShop.Config.AdminGroups) do
        if string.lower(group) == string.lower(adminGroup) then
            return true
        end
    end
    return false
end
