-- cl_npc_3d2d.lua
-- Renders the shop name as 3D2D billboard text above each Shop NPC
-- Client-side only

SCPShop = SCPShop or {}

-- Maximum distance at which the 3D2D text is rendered (performance)
local RENDER_DISTANCE_SQ = 600 * 600  -- 600 units squared

-- Cache of known shop NPC entities (populated via NW variable changes)
SCPShop.KnownNPCs = SCPShop.KnownNPCs or {}

-- Keep the cache updated: add newly seen shop props and remove invalid ones
hook.Add("NetworkEntityCreated", "SCPShop_TrackNPCs", function(ent)
    if not IsValid(ent) then return end
    -- Check NW string after a brief delay so it has been set by the server
    timer.Simple(0.2, function()
        if IsValid(ent) and ent:GetNWString("SCPShop_ID", "") ~= "" then
            SCPShop.KnownNPCs[ent:EntIndex()] = ent
        end
    end)
end)

hook.Add("EntityRemoved", "SCPShop_UntrackNPCs", function(ent)
    SCPShop.KnownNPCs[ent:EntIndex()] = nil
end)

hook.Add("PostDrawOpaqueRenderables", "SCPShop_3D2DNames", function()
    local ply    = LocalPlayer()
    local plyPos = ply:GetShootPos()

    for idx, ent in pairs(SCPShop.KnownNPCs) do
        if not IsValid(ent) then
            SCPShop.KnownNPCs[idx] = nil
            continue
        end

        local npcPos = ent:GetPos()

        -- Distance cull
        if plyPos:DistToSqr(npcPos) > RENDER_DISTANCE_SQ then continue end

        local shopName = ent:GetNWString("SCPShop_Name", "Shop")

        -- Position: slightly above the model's bounding box top
        local mins, maxs = ent:GetModelBounds()
        local heightOffset = (maxs.z - mins.z) + 20
        local drawPos = npcPos + Vector(0, 0, heightOffset)

        -- Angle: face the local player (billboard)
        local billboardAng = (plyPos - drawPos):Angle()
        billboardAng.p = 0  -- keep upright
        billboardAng.r = 0

        cam.Start3D2D(drawPos, billboardAng, 0.12)
            -- Dark semi-transparent background
            local textW, textH = 440, 60
            draw.RoundedBox(6, -textW / 2 - 8, -textH / 2 - 4, textW + 16, textH + 8, Color(0, 0, 0, 170))

            -- Shop name text
            draw.SimpleTextOutlined(
                shopName,
                "DermaLarge",
                0, 0,
                Color(255, 230, 100),
                TEXT_ALIGN_CENTER,
                TEXT_ALIGN_CENTER,
                1,
                Color(0, 0, 0, 200)
            )
        cam.End3D2D()
    end
end)
