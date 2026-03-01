-- sh_shop_net.lua
-- Defines all net message strings used by the SCP Shop System
-- Must be loaded on both client and server before any net messages are sent/received

if SERVER then
    -- Register all net messages server-side
    util.AddNetworkString("SCPShop_OpenShop")    -- Server → Client: open shop UI with NPC data
    util.AddNetworkString("SCPShop_BuyItem")     -- Client → Server: player buys an item
    util.AddNetworkString("SCPShop_AddItem")     -- Client → Server: admin adds an item
    util.AddNetworkString("SCPShop_EditItem")    -- Client → Server: admin edits an item
    util.AddNetworkString("SCPShop_RemoveItem")  -- Client → Server: admin removes an item
    util.AddNetworkString("SCPShop_SyncItems")   -- Server → Client: sync item list
    util.AddNetworkString("SCPShop_SpawnNPC")    -- Client → Server: spawn NPC (from tool)
end
