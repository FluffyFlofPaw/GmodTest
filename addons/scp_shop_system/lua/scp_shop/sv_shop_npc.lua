-- sv_shop_npc.lua
-- Handles NPC spawning, persistence (save/load) and management
-- Server-side only

SCPShop = SCPShop or {}
SCPShop.NPCs = SCPShop.NPCs or {}  -- table of active NPC entities, keyed by their unique ID
SCPShop.NextNPCID = SCPShop.NextNPCID or 1

-- Returns the file path used to save/load NPCs for the current map
local function GetSaveFilePath()
    return "scp_shop/" .. string.lower(game.GetMap()) .. "_npcs.json"
end

-- Ensures the save directory exists
local function EnsureSaveDir()
    if not file.IsDir("scp_shop", "DATA") then
        file.CreateDir("scp_shop")
    end
end

-- Spawns a single Shop NPC entity from a data table
-- data: { pos, ang, model, name, id, items }
function SCPShop.SpawnNPCFromData(data)
    if not data then return nil end

    local model = data.model or SCPShop.Config.DefaultNPCModel
    local name  = data.name  or "Shop"
    local id    = data.id    or tostring(SCPShop.NextNPCID)
    local pos   = data.pos
    local ang   = data.ang

    -- Deserialise position/angles when loaded from JSON
    if type(pos) == "table" then
        pos = Vector(pos.x or pos[1] or 0, pos.y or pos[2] or 0, pos.z or pos[3] or 0)
    end
    if type(ang) == "table" then
        ang = Angle(ang.p or ang[1] or 0, ang.y or ang[2] or 0, ang.r or ang[3] or 0)
    end

    -- Create a simple prop_physics or npc_citizen as base.
    -- We use a scripted entity approach: spawn a simple prop that acts as the NPC.
    -- Since this is a pure Lua addon without a custom entity class, we use a
    -- prop_dynamic with a few hooks to simulate NPC behaviour.
    local npc = ents.Create("prop_dynamic")
    if not IsValid(npc) then
        ErrorNoHalt("[SCPShop] Failed to create NPC entity for shop '" .. name .. "'\n")
        return nil
    end

    npc:SetModel(model)
    npc:SetPos(pos)
    npc:SetAngles(ang)
    npc:SetNoDraw(false)
    npc:Spawn()
    npc:Activate()

    -- Make the NPC invulnerable via god-mode flag
    npc:AddFlags(FL_GODMODE)

    -- Store metadata in the entity itself
    npc:SetNWString("SCPShop_ID",   id)
    npc:SetNWString("SCPShop_Name", name)

    -- Store items as JSON string on the entity so clients can retrieve them
    local items = data.items or {}
    npc:SetNWString("SCPShop_Items", util.TableToJSON(items))

    -- Track NPC internally
    SCPShop.NPCs[string.lower(id)] = npc

    -- Update auto-increment counter
    local numID = tonumber(id)
    if numID and numID >= SCPShop.NextNPCID then
        SCPShop.NextNPCID = numID + 1
    end

    return npc
end

-- Returns a serialisable table for all currently active shop NPCs
function SCPShop.SerialiseNPCs()
    local data = {}
    for id, npc in pairs(SCPShop.NPCs) do
        if IsValid(npc) then
            local pos = npc:GetPos()
            local ang = npc:GetAngles()
            local items = util.JSONToTable(npc:GetNWString("SCPShop_Items", "[]")) or {}
            table.insert(data, {
                id    = npc:GetNWString("SCPShop_ID",   id),
                name  = npc:GetNWString("SCPShop_Name", "Shop"),
                model = npc:GetModel(),
                pos   = { x = pos.x, y = pos.y, z = pos.z },
                ang   = { p = ang.p, y = ang.y, r = ang.r },
                items = items,
            })
        end
    end
    return data
end

-- Saves all active Shop NPCs to disk
function SCPShop.SaveNPCs()
    EnsureSaveDir()
    local data    = SCPShop.SerialiseNPCs()
    local json    = util.TableToJSON(data, true)
    file.Write(GetSaveFilePath(), json)
    MsgAll("[SCPShop] " .. #data .. " shop NPC(s) saved.\n")
end

-- Loads and spawns Shop NPCs from disk for the current map
function SCPShop.LoadNPCs()
    EnsureSaveDir()
    local path = GetSaveFilePath()
    if not file.Exists(path, "DATA") then return end

    local json = file.Read(path, "DATA")
    if not json or json == "" then return end

    local data = util.JSONToTable(json)
    if not data then
        ErrorNoHalt("[SCPShop] Failed to parse NPC save file: " .. path .. "\n")
        return
    end

    for _, npcData in ipairs(data) do
        SCPShop.SpawnNPCFromData(npcData)
    end

    MsgAll("[SCPShop] Loaded " .. #data .. " shop NPC(s) for map " .. game.GetMap() .. ".\n")
end

-- Removes a shop NPC by ID and clears it from the tracking table
function SCPShop.RemoveNPC(id)
    local key = string.lower(tostring(id))
    local npc = SCPShop.NPCs[key]
    if IsValid(npc) then
        npc:Remove()
    end
    SCPShop.NPCs[key] = nil
end

-- Updates the item list for a given NPC (by entity reference)
function SCPShop.SetNPCItems(npc, items)
    if not IsValid(npc) then return end
    npc:SetNWString("SCPShop_Items", util.TableToJSON(items or {}))
end

-- Returns the item list for a given NPC
function SCPShop.GetNPCItems(npc)
    if not IsValid(npc) then return {} end
    return util.JSONToTable(npc:GetNWString("SCPShop_Items", "[]")) or {}
end

-- Chat command: !saveshops
hook.Add("PlayerSay", "SCPShop_SaveCommand", function(ply, text)
    if string.lower(text) == string.lower(SCPShop.Config.SaveCommand) then
        if not SCPShop.IsAdmin(ply) then
            DarkRP.notify(ply, 1, 4, "You do not have permission to save shops.")
            return ""
        end
        SCPShop.SaveNPCs()
        DarkRP.notify(ply, 0, 4, "All shop NPCs have been saved.")
        return ""
    end
end)

-- Console command: scp_shop_save
concommand.Add("scp_shop_save", function(ply, cmd, args)
    if IsValid(ply) and not SCPShop.IsAdmin(ply) then
        ply:PrintMessage(HUD_PRINTCONSOLE, "[SCPShop] Permission denied.\n")
        return
    end
    SCPShop.SaveNPCs()
end)

-- Head-tracking: rotate prop_dynamic to face the nearest player (runs at ~10 Hz)
timer.Create("SCPShop_HeadTracking", 0.1, 0, function()
    for id, npc in pairs(SCPShop.NPCs) do
        if not IsValid(npc) then
            SCPShop.NPCs[id] = nil
        else
            -- Find nearest player
            local nearestPly = nil
            local nearestDist = math.huge
            for _, ply in ipairs(player.GetAll()) do
                if IsValid(ply) and ply:Alive() then
                    local d = npc:GetPos():DistToSqr(ply:GetPos())
                    if d < nearestDist then
                        nearestDist = d
                        nearestPly  = ply
                    end
                end
            end

            if IsValid(nearestPly) then
                local targetAng = (nearestPly:GetPos() - npc:GetPos()):Angle()
                local curAng    = npc:GetAngles()
                local newYaw = math.ApproachAngle(curAng.y, targetAng.y, 3)
                npc:SetAngles(Angle(0, newYaw, 0))
            end
        end
    end
end)

-- Auto-load NPCs when the map initialises
hook.Add("InitPostEntity", "SCPShop_LoadOnStart", function()
    timer.Simple(1, function()
        SCPShop.LoadNPCs()
    end)
end)
