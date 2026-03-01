-- sv_shop_logic.lua
-- Server-side purchase logic and net message handlers
-- Validates all client requests (permissions, distance, money, job)

SCPShop = SCPShop or {}

-- Returns the NPC entity for a given NPC ID (nil if not found / invalid)
local function GetNPCByID(id)
    if not id then return nil end
    local key = string.lower(tostring(id))
    local npc = SCPShop.NPCs and SCPShop.NPCs[key]
    if IsValid(npc) then return npc end
    return nil
end

-- Checks whether a player is close enough to an NPC
local function IsNearNPC(ply, npc)
    if not IsValid(ply) or not IsValid(npc) then return false end
    local dist = ply:GetPos():Distance(npc:GetPos())
    return dist <= (SCPShop.Config.InteractionDistance * 2)  -- generous server-side limit
end

-- Returns the item from an NPC's item list by index (1-based)
local function GetItemByIndex(npc, idx)
    local items = SCPShop.GetNPCItems(npc)
    return items[idx], items
end

-- Checks whether a player is allowed to buy a given item (job restriction)
local function CanPlayerBuyItem(ply, item)
    if not item.jobGroup or item.jobGroup == "" then
        return true  -- no restriction
    end
    return SCPShop.IsPlayerInJobGroup(ply, item.jobGroup)
end

-- Spawns an entity in front of the NPC
local function SpawnItemInFrontOfNPC(npc, classname)
    local forward = npc:GetForward()
    local spawnPos = npc:GetPos() + forward * 50 + Vector(0, 0, 10)
    local ent = ents.Create(classname)
    if not IsValid(ent) then return nil end
    ent:SetPos(spawnPos)
    ent:Spawn()
    ent:Activate()
    return ent
end

-- ─── Net: SCPShop_BuyItem ────────────────────────────────────────────────────
-- Payload: string npcID, int itemIndex
net.Receive("SCPShop_BuyItem", function(len, ply)
    if not IsValid(ply) then return end

    local npcID    = net.ReadString()
    local itemIdx  = net.ReadUInt(16)

    -- Validate NPC
    local npc = GetNPCByID(npcID)
    if not IsValid(npc) then
        DarkRP.notify(ply, 1, 4, "Invalid shop NPC.")
        return
    end

    -- Distance check
    if not IsNearNPC(ply, npc) then
        DarkRP.notify(ply, 1, 4, "You are too far from the shop.")
        return
    end

    -- Item existence check
    local item, items = GetItemByIndex(npc, itemIdx)
    if not item then
        DarkRP.notify(ply, 1, 4, "Item not found.")
        return
    end

    -- Job restriction check
    if not CanPlayerBuyItem(ply, item) then
        DarkRP.notify(ply, 1, 4, "Your job cannot buy this item.")
        return
    end

    local price = tonumber(item.price) or 0

    -- Funds check
    if not ply:canAfford(price) then
        DarkRP.notify(ply, 1, 4, "You cannot afford " .. SCPShop.Config.Currency .. price .. ".")
        return
    end

    -- Deduct money
    ply:addMoney(-price)

    -- Give item
    if item.pickup then
        -- Give directly to the player's inventory
        ply:Give(item.classname)
    else
        -- Spawn in front of NPC
        SpawnItemInFrontOfNPC(npc, item.classname)
    end

    DarkRP.notify(ply, 0, 4, "You bought " .. (item.displayName or item.classname) .. " for " .. SCPShop.Config.Currency .. price .. ".")
end)

-- ─── Net: SCPShop_AddItem ────────────────────────────────────────────────────
-- Payload: string npcID, string classname, string displayName, float price, string jobGroup, bool pickup
net.Receive("SCPShop_AddItem", function(len, ply)
    if not IsValid(ply) then return end
    if not SCPShop.IsAdmin(ply) then
        DarkRP.notify(ply, 1, 4, "Permission denied.")
        return
    end

    local npcID       = net.ReadString()
    local classname   = net.ReadString()
    local displayName = net.ReadString()
    local price       = net.ReadFloat()
    local jobGroup    = net.ReadString()
    local pickup      = net.ReadBool()

    -- Sanitise inputs
    classname   = string.sub(tostring(classname),   1, 64)
    displayName = string.sub(tostring(displayName), 1, 64)
    jobGroup    = string.sub(tostring(jobGroup),    1, 64)
    price       = math.max(0, math.floor(price))

    if classname == "" then
        DarkRP.notify(ply, 1, 4, "Item classname cannot be empty.")
        return
    end

    local npc = GetNPCByID(npcID)
    if not IsValid(npc) then
        DarkRP.notify(ply, 1, 4, "Invalid shop NPC.")
        return
    end

    local items = SCPShop.GetNPCItems(npc)
    table.insert(items, {
        classname   = classname,
        displayName = displayName,
        price       = price,
        jobGroup    = jobGroup,
        pickup      = pickup,
    })
    SCPShop.SetNPCItems(npc, items)

    -- Sync updated item list back to all players
    SCPShop.SyncItemsToAll(npc)
    DarkRP.notify(ply, 0, 4, "Item '" .. displayName .. "' added to the shop.")
end)

-- ─── Net: SCPShop_EditItem ───────────────────────────────────────────────────
-- Payload: string npcID, int itemIndex, string classname, string displayName, float price, string jobGroup, bool pickup
net.Receive("SCPShop_EditItem", function(len, ply)
    if not IsValid(ply) then return end
    if not SCPShop.IsAdmin(ply) then
        DarkRP.notify(ply, 1, 4, "Permission denied.")
        return
    end

    local npcID       = net.ReadString()
    local itemIdx     = net.ReadUInt(16)
    local classname   = net.ReadString()
    local displayName = net.ReadString()
    local price       = net.ReadFloat()
    local jobGroup    = net.ReadString()
    local pickup      = net.ReadBool()

    classname   = string.sub(tostring(classname),   1, 64)
    displayName = string.sub(tostring(displayName), 1, 64)
    jobGroup    = string.sub(tostring(jobGroup),    1, 64)
    price       = math.max(0, math.floor(price))

    local npc = GetNPCByID(npcID)
    if not IsValid(npc) then
        DarkRP.notify(ply, 1, 4, "Invalid shop NPC.")
        return
    end

    local items = SCPShop.GetNPCItems(npc)
    if not items[itemIdx] then
        DarkRP.notify(ply, 1, 4, "Item not found.")
        return
    end

    items[itemIdx] = {
        classname   = classname,
        displayName = displayName,
        price       = price,
        jobGroup    = jobGroup,
        pickup      = pickup,
    }
    SCPShop.SetNPCItems(npc, items)
    SCPShop.SyncItemsToAll(npc)
    DarkRP.notify(ply, 0, 4, "Item updated.")
end)

-- ─── Net: SCPShop_RemoveItem ─────────────────────────────────────────────────
-- Payload: string npcID, int itemIndex
net.Receive("SCPShop_RemoveItem", function(len, ply)
    if not IsValid(ply) then return end
    if not SCPShop.IsAdmin(ply) then
        DarkRP.notify(ply, 1, 4, "Permission denied.")
        return
    end

    local npcID   = net.ReadString()
    local itemIdx = net.ReadUInt(16)

    local npc = GetNPCByID(npcID)
    if not IsValid(npc) then
        DarkRP.notify(ply, 1, 4, "Invalid shop NPC.")
        return
    end

    local items = SCPShop.GetNPCItems(npc)
    if not items[itemIdx] then
        DarkRP.notify(ply, 1, 4, "Item not found.")
        return
    end

    table.remove(items, itemIdx)
    SCPShop.SetNPCItems(npc, items)
    SCPShop.SyncItemsToAll(npc)
    DarkRP.notify(ply, 0, 4, "Item removed.")
end)

-- ─── Net: SCPShop_SpawnNPC ───────────────────────────────────────────────────
-- Payload: Vector pos, Angle ang, string model, string name
net.Receive("SCPShop_SpawnNPC", function(len, ply)
    if not IsValid(ply) then return end
    if not SCPShop.IsAdmin(ply) then
        DarkRP.notify(ply, 1, 4, "Permission denied.")
        return
    end

    local pos   = net.ReadVector()
    local ang   = net.ReadAngle()
    local model = net.ReadString()
    local name  = net.ReadString()

    model = string.sub(tostring(model), 1, 256)
    name  = string.sub(tostring(name),  1, 64)

    if model == "" then model = SCPShop.Config.DefaultNPCModel end
    if name  == "" then name  = "Shop" end

    local id = tostring(SCPShop.NextNPCID)
    SCPShop.SpawnNPCFromData({
        pos   = pos,
        ang   = ang,
        model = model,
        name  = name,
        id    = id,
        items = {},
    })

    DarkRP.notify(ply, 0, 4, "Shop NPC '" .. name .. "' spawned (ID: " .. id .. ").")
end)

-- ─── Helper: Sync items to all clients ───────────────────────────────────────
function SCPShop.SyncItemsToAll(npc)
    if not IsValid(npc) then return end
    local id    = npc:GetNWString("SCPShop_ID",    "")
    local items = SCPShop.GetNPCItems(npc)

    net.Start("SCPShop_SyncItems")
        net.WriteString(id)
        net.WriteString(util.TableToJSON(items))
    net.Broadcast()
end

-- ─── Use-key interaction: open shop for the player ───────────────────────────
hook.Add("PlayerUse", "SCPShop_UseNPC", function(ply, ent)
    if not IsValid(ent) then return end
    if ent:GetNWString("SCPShop_ID", "") == "" then return end

    local npcID = ent:GetNWString("SCPShop_ID")
    local name  = ent:GetNWString("SCPShop_Name", "Shop")
    local items = SCPShop.GetNPCItems(ent)

    net.Start("SCPShop_OpenShop")
        net.WriteString(npcID)
        net.WriteString(name)
        net.WriteString(util.TableToJSON(items))
    net.Send(ply)

    return true  -- consume the use action
end)
