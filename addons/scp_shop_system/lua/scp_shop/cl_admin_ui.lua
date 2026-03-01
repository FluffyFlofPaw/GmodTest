-- cl_admin_ui.lua
-- Admin management panel for shop NPCs
-- Client-side only; server performs all permission checks independently

SCPShop = SCPShop or {}

-- Opens the admin UI for a specific shop NPC
function SCPShop.OpenAdminUI(npcID, shopName)
    -- Client-side permission check (server also validates)
    if not SCPShop.IsAdmin(LocalPlayer()) then
        chat.AddText(Color(255, 60, 60), "[SCPShop] You do not have permission to access the admin menu.")
        return
    end

    -- Close existing admin panel
    if IsValid(SCPShop.AdminPanel) then
        SCPShop.AdminPanel:Remove()
    end

    -- ── Main frame ──────────────────────────────────────────────────────────
    local frame = vgui.Create("DFrame")
    frame:SetTitle("Shop Admin: " .. (shopName or npcID))
    frame:SetSize(560, 600)
    frame:Center()
    frame:MakePopup()
    frame:SetDraggable(true)
    frame:SetDeleteOnClose(true)
    SCPShop.AdminPanel = frame

    frame.Paint = function(self, w, h)
        draw.RoundedBox(6, 0, 0, w, h, Color(20, 20, 30, 245))
        draw.RoundedBox(6, 0, 0, w, 24, Color(50, 30, 80, 255))
    end

    -- ── Tabs ────────────────────────────────────────────────────────────────
    local tabs = vgui.Create("DPropertySheet", frame)
    tabs:Dock(FILL)
    tabs:DockMargin(6, 6, 6, 6)

    -- ── Tab 1: Add item ──────────────────────────────────────────────────────
    local addPanel = vgui.Create("DPanel")
    addPanel.Paint = function(self, w, h)
        draw.RoundedBox(4, 0, 0, w, h, Color(25, 25, 38, 220))
    end

    local function MakeLabel(parent, text, y)
        local lbl = vgui.Create("DLabel", parent)
        lbl:SetText(text)
        lbl:SetTextColor(Color(200, 200, 200))
        lbl:SetPos(10, y)
        lbl:SizeToContents()
        return lbl
    end

    local function MakeTextEntry(parent, y, default)
        local te = vgui.Create("DTextEntry", parent)
        te:SetSize(320, 24)
        te:SetPos(160, y)
        te:SetValue(default or "")
        return te
    end

    -- Classname
    MakeLabel(addPanel, "Entity Classname:", 16)
    local teClassname = MakeTextEntry(addPanel, 12, "weapon_ak47")

    -- Display name
    MakeLabel(addPanel, "Anzeigename:", 50)
    local teDisplayName = MakeTextEntry(addPanel, 46, "")

    -- Price
    MakeLabel(addPanel, "Preis:", 84)
    local tePrice = MakeTextEntry(addPanel, 80, "100")

    -- Job group dropdown
    MakeLabel(addPanel, "Job-Kategorie:", 118)
    local ddJobGroup = vgui.Create("DComboBox", addPanel)
    ddJobGroup:SetSize(320, 24)
    ddJobGroup:SetPos(160, 114)
    ddJobGroup:AddChoice("Keine Einschränkung", "")
    for groupName, _ in pairs(SCPShop.Config.JobGroups) do
        ddJobGroup:AddChoice(groupName, groupName)
    end
    ddJobGroup:ChooseOption("Keine Einschränkung")

    -- Pickup checkbox
    MakeLabel(addPanel, "Spieler nimmt Item auf:", 156)
    local cbPickup = vgui.Create("DCheckBox", addPanel)
    cbPickup:SetPos(160, 154)
    cbPickup:SetValue(true)

    -- Add button
    local btnAdd = vgui.Create("DButton", addPanel)
    btnAdd:SetText("Hinzufügen")
    btnAdd:SetSize(140, 32)
    btnAdd:SetPos(160, 194)
    btnAdd:SetTextColor(Color(80, 220, 80))
    btnAdd.DoClick = function()
        local classname   = teClassname:GetValue()
        local displayName = teDisplayName:GetValue()
        local price       = tonumber(tePrice:GetValue()) or 0
        local _, _, jobGroup = ddJobGroup:GetSelected()
        local pickup      = cbPickup:GetChecked()

        if classname == "" then
            chat.AddText(Color(255, 60, 60), "[SCPShop] Classname darf nicht leer sein.")
            return
        end

        net.Start("SCPShop_AddItem")
            net.WriteString(npcID)
            net.WriteString(classname)
            net.WriteString(displayName)
            net.WriteFloat(price)
            net.WriteString(jobGroup or "")
            net.WriteBool(pickup)
        net.SendToServer()
    end

    tabs:AddSheet("Item hinzufügen", addPanel, "icon16/add.png")

    -- ── Tab 2: Edit / remove items ───────────────────────────────────────────
    local editPanel = vgui.Create("DPanel")
    editPanel.Paint = function(self, w, h)
        draw.RoundedBox(4, 0, 0, w, h, Color(25, 25, 38, 220))
    end

    local editScroll = vgui.Create("DScrollPanel", editPanel)
    editScroll:Dock(FILL)
    editScroll:DockMargin(4, 4, 4, 4)

    local editList = vgui.Create("DListLayout", editScroll)
    editList:Dock(TOP)

    local function BuildEditList()
        editList:Clear()
        local items = SCPShop.CurrentShopItems or {}
        for idx, item in ipairs(items) do
            local row = vgui.Create("DPanel", editList)
            row:SetTall(130)
            row:Dock(TOP)
            row:DockMargin(2, 4, 2, 4)
            row.Paint = function(self, w, h)
                draw.RoundedBox(4, 0, 0, w, h, Color(35, 35, 50, 220))
            end

            -- Labels and entries for editing
            local function RowLabel(text, y)
                local lbl = vgui.Create("DLabel", row)
                lbl:SetText(text)
                lbl:SetTextColor(Color(180, 180, 180))
                lbl:SetPos(6, y)
                lbl:SizeToContents()
            end
            local function RowEntry(y, val)
                local te = vgui.Create("DTextEntry", row)
                te:SetSize(180, 22)
                te:SetPos(130, y)
                te:SetValue(tostring(val or ""))
                return te
            end

            RowLabel("Classname:", 8)
            local rClassname = RowEntry(6, item.classname)

            RowLabel("Anzeigename:", 34)
            local rDisplayName = RowEntry(32, item.displayName)

            RowLabel("Preis:", 60)
            local rPrice = RowEntry(58, item.price)

            RowLabel("Job-Gruppe:", 86)
            local rJobGroup = RowEntry(84, item.jobGroup)

            -- Pickup checkbox
            RowLabel("Aufnehmen:", 110)  -- positioned below if row height allows
            local rPickup = vgui.Create("DCheckBox", row)
            rPickup:SetPos(130, 109)
            rPickup:SetValue(item.pickup and true or false)

            -- Save button
            local btnSave = vgui.Create("DButton", row)
            btnSave:SetText("Speichern")
            btnSave:SetSize(80, 22)
            btnSave:SetPos(320, 6)
            btnSave:SetTextColor(Color(80, 180, 255))
            btnSave.DoClick = function()
                net.Start("SCPShop_EditItem")
                    net.WriteString(npcID)
                    net.WriteUInt(idx, 16)
                    net.WriteString(rClassname:GetValue())
                    net.WriteString(rDisplayName:GetValue())
                    net.WriteFloat(tonumber(rPrice:GetValue()) or 0)
                    net.WriteString(rJobGroup:GetValue())
                    net.WriteBool(rPickup:GetChecked())
                net.SendToServer()
            end

            -- Delete button
            local btnDel = vgui.Create("DButton", row)
            btnDel:SetText("Löschen")
            btnDel:SetSize(80, 22)
            btnDel:SetPos(320, 34)
            btnDel:SetTextColor(Color(255, 80, 80))
            btnDel.DoClick = function()
                net.Start("SCPShop_RemoveItem")
                    net.WriteString(npcID)
                    net.WriteUInt(idx, 16)
                net.SendToServer()
            end
        end
    end

    BuildEditList()

    -- Refresh edit list when items are synced for this NPC
    local callbackKey = "AdminUI_" .. npcID
    SCPShop.ItemSyncCallbacks = SCPShop.ItemSyncCallbacks or {}
    SCPShop.ItemSyncCallbacks[callbackKey] = function(syncedNPCID, syncedItems)
        if syncedNPCID == npcID then
            BuildEditList()
        end
    end
    -- Remove callback when the panel is closed
    frame.OnClose = function()
        SCPShop.ItemSyncCallbacks[callbackKey] = nil
    end

    tabs:AddSheet("Items bearbeiten", editPanel, "icon16/pencil.png")
end
