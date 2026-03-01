-- scp_shop_spawner.lua
-- GMod STOOL for spawning Shop NPCs
-- Only admins (configured ULX groups) may use this tool

TOOL.Category    = "SCP Shop System"
TOOL.Name        = "#SCP Shop NPC Spawner"
TOOL.Command     = "scp_shop_spawner"
TOOL.ConfigName  = ""

-- Tool convar defaults
if CLIENT then
    TOOL.Information = {
        { name = "left" },
    }
end

TOOL.ClientConVar = {
    model = "models/breen.mdl",
    name  = "Shop",
}

-- ── Left-click: spawn a shop NPC ────────────────────────────────────────────
function TOOL:LeftClick(trace)
    if CLIENT then return true end

    local ply = self:GetOwner()
    if not IsValid(ply) then return false end

    -- Permission check
    if not SCPShop.IsAdmin(ply) then
        DarkRP.notify(ply, 1, 4, "You do not have permission to use the Shop Spawner tool.")
        return false
    end

    if not trace.Hit then return false end

    local model = self:GetClientInfo("model")
    local name  = self:GetClientInfo("name")

    if model == "" then model = SCPShop.Config.DefaultNPCModel end
    if name  == "" then name  = "Shop" end

    -- Spawn directly server-side (no net round-trip needed)
    local id = tostring(SCPShop.NextNPCID)
    SCPShop.SpawnNPCFromData({
        pos   = trace.HitPos,
        ang   = Angle(0, ply:GetAngles().y + 180, 0),
        model = model,
        name  = name,
        id    = id,
        items = {},
    })

    DarkRP.notify(ply, 0, 4, "Shop NPC '" .. name .. "' spawned (ID: " .. id .. ").")
    return true
end

function TOOL:RightClick(trace) return false end
function TOOL:Reload(trace)     return false end

-- ── Tool menu panel ──────────────────────────────────────────────────────────
if CLIENT then
    function TOOL.BuildCPanel(panel)
        panel:AddControl("Header", {
            Text        = "SCP Shop NPC Spawner",
            Description = "Spawns a persistent Shop NPC.\nLeft-click to place.",
        })

        panel:AddControl("TextBox", {
            Label   = "NPC Model (Playermodel or NPC model path)",
            Command = "scp_shop_spawner_model",
        })

        panel:AddControl("TextBox", {
            Label   = "Shop Name",
            Command = "scp_shop_spawner_name",
        })
    end
end
