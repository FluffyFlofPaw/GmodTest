-- cl_shop_ui.lua
-- Main shop UI panel shown when the player presses E on a Shop NPC
-- Client-side only

SCPShop = SCPShop or {}

-- Store current shop data so the admin UI can reference it
SCPShop.CurrentShopNPCID = nil
SCPShop.CurrentShopItems = {}

-- Opens the shop UI for a specific NPC
function SCPShop.OpenShopUI(npcID, shopName, items)
    SCPShop.CurrentShopNPCID = npcID
    SCPShop.CurrentShopItems = items or {}

    -- Close existing panel if already open
    if IsValid(SCPShop.ShopPanel) then
        SCPShop.ShopPanel:Remove()
    end

    local playerJob = LocalPlayer():getDarkRPVar("job") or ""

    -- ── Main frame ──────────────────────────────────────────────────────────
    local frame = vgui.Create("DFrame")
    frame:SetTitle(shopName or "Shop")
    frame:SetSize(420, 520)
    frame:Center()
    frame:MakePopup()
    frame:SetDraggable(true)
    frame:SetDeleteOnClose(true)
    SCPShop.ShopPanel = frame

    -- Background colour
    frame.Paint = function(self, w, h)
        draw.RoundedBox(6, 0, 0, w, h, Color(25, 25, 35, 240))
        draw.RoundedBox(6, 0, 0, w, 24, Color(40, 40, 60, 255))
    end

    -- ── Scroll panel for items ───────────────────────────────────────────────
    local scroll = vgui.Create("DScrollPanel", frame)
    scroll:Dock(FILL)
    scroll:DockMargin(8, 8, 8, 8)

    local itemList = vgui.Create("DListLayout", scroll)
    itemList:Dock(TOP)
    itemList:DockMargin(0, 0, 0, 0)

    local function BuildItemList()
        itemList:Clear()
        for idx, item in ipairs(SCPShop.CurrentShopItems) do
            -- Determine if the player can buy this item
            local allowed = true
            if item.jobGroup and item.jobGroup ~= "" then
                local jobJobs = SCPShop.Config.JobGroups[item.jobGroup]
                if jobJobs then
                    local found = false
                    for _, j in ipairs(jobJobs) do
                        if string.lower(j) == string.lower(playerJob) then
                            found = true
                            break
                        end
                    end
                    allowed = found
                end
            end

            -- Row panel
            local row = vgui.Create("DPanel", itemList)
            row:SetTall(48)
            row:Dock(TOP)
            row:DockMargin(2, 2, 2, 2)

            row.Paint = function(self, w, h)
                local bg = allowed and Color(45, 55, 70, 220) or Color(35, 35, 40, 180)
                draw.RoundedBox(4, 0, 0, w, h, bg)
            end

            -- Item name label
            local nameLabel = vgui.Create("DLabel", row)
            nameLabel:SetText((item.displayName ~= "" and item.displayName) or item.classname)
            nameLabel:SetFont("DermaDefault")
            nameLabel:SetTextColor(allowed and Color(220, 220, 220) or Color(120, 120, 120))
            nameLabel:SetPos(8, 8)
            nameLabel:SizeToContents()

            -- Price label
            local priceLabel = vgui.Create("DLabel", row)
            priceLabel:SetText(SCPShop.Config.Currency .. (item.price or 0))
            priceLabel:SetFont("DermaDefault")
            priceLabel:SetTextColor(allowed and Color(100, 220, 100) or Color(100, 100, 100))
            priceLabel:SetPos(8, 26)
            priceLabel:SizeToContents()

            -- Job restriction label
            if item.jobGroup and item.jobGroup ~= "" then
                local jLabel = vgui.Create("DLabel", row)
                jLabel:SetText("[" .. item.jobGroup .. "]")
                jLabel:SetFont("DermaDefault")
                jLabel:SetTextColor(Color(160, 160, 80))
                jLabel:SetPos(150, 8)
                jLabel:SizeToContents()
            end

            -- Buy button
            if allowed then
                local buyBtn = vgui.Create("DButton", row)
                buyBtn:SetText("Kaufen")
                buyBtn:SetSize(80, 32)
                buyBtn:SetPos(row:GetWide() - 96, 8)
                buyBtn.DoClick = function()
                    net.Start("SCPShop_BuyItem")
                        net.WriteString(npcID)
                        net.WriteUInt(idx, 16)
                    net.SendToServer()
                end
                row:InvalidateLayout(true)
                -- Reposition button after layout
                timer.Simple(0, function()
                    if IsValid(buyBtn) and IsValid(row) then
                        buyBtn:SetPos(row:GetWide() - 96, 8)
                    end
                end)
            end
        end
    end

    BuildItemList()

    -- ── Bottom bar ───────────────────────────────────────────────────────────
    local bottomBar = vgui.Create("DPanel", frame)
    bottomBar:SetTall(40)
    bottomBar:Dock(BOTTOM)
    bottomBar:DockMargin(8, 4, 8, 8)
    bottomBar.Paint = function(self, w, h)
        draw.RoundedBox(4, 0, 0, w, h, Color(30, 30, 45, 200))
    end

    -- Admin button (only for admins)
    if SCPShop.IsAdmin(LocalPlayer()) then
        local adminBtn = vgui.Create("DButton", bottomBar)
        adminBtn:SetText("⚙ Admin")
        adminBtn:SetSize(100, 28)
        adminBtn:SetPos(8, 6)
        adminBtn:SetTextColor(Color(255, 200, 50))
        adminBtn.DoClick = function()
            SCPShop.OpenAdminUI(npcID, shopName)
        end
    end

    -- Receive synced items and refresh list
    local callbackKey = "ShopUI_" .. npcID
    SCPShop.ItemSyncCallbacks = SCPShop.ItemSyncCallbacks or {}
    SCPShop.ItemSyncCallbacks[callbackKey] = function(syncedNPCID, syncedItems)
        if syncedNPCID == npcID then
            SCPShop.CurrentShopItems = syncedItems
            BuildItemList()
        end
    end
    frame.OnClose = function()
        SCPShop.ItemSyncCallbacks[callbackKey] = nil
    end
end

-- ── Net: receive open-shop message from server ────────────────────────────────
net.Receive("SCPShop_OpenShop", function()
    local npcID    = net.ReadString()
    local shopName = net.ReadString()
    local itemsJSON = net.ReadString()
    local items    = util.JSONToTable(itemsJSON) or {}
    SCPShop.OpenShopUI(npcID, shopName, items)
end)

-- ── Net: receive item sync ────────────────────────────────────────────────────
net.Receive("SCPShop_SyncItems", function()
    local npcID    = net.ReadString()
    local itemsJSON = net.ReadString()
    local items    = util.JSONToTable(itemsJSON) or {}

    SCPShop.CurrentShopItems = items

    SCPShop.ItemSyncCallbacks = SCPShop.ItemSyncCallbacks or {}
    for _, cb in pairs(SCPShop.ItemSyncCallbacks) do
        cb(npcID, items)
    end
end)
