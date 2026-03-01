-- sv_scp_shop.lua
-- Server-side autorun entry point for the SCP Shop System
-- Includes all server files and registers client files for download

-- ── Register client files ────────────────────────────────────────────────────
AddCSLuaFile("autorun/client/cl_scp_shop.lua")
AddCSLuaFile("scp_shop/cl_shop_ui.lua")
AddCSLuaFile("scp_shop/cl_admin_ui.lua")
AddCSLuaFile("scp_shop/cl_npc_3d2d.lua")
AddCSLuaFile("scp_shop/sh_shop_net.lua")

-- ── Include shared files ─────────────────────────────────────────────────────
-- (autorun/sh_scp_shop_config.lua is automatically executed on both realms by GMod)

-- ── Include server files ─────────────────────────────────────────────────────
include("scp_shop/sh_shop_net.lua")      -- registers net strings (server-side)
include("scp_shop/sv_shop_npc.lua")      -- NPC spawning and persistence
include("scp_shop/sv_shop_logic.lua")    -- purchase logic and net handlers
