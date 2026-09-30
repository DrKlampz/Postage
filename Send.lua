-- Postage send-mail side:
--   BlackBook   - a contact button on the To: box (your alts, recently mailed, friends, guild),
--                 plus name autocomplete as you type
--   Wire        - fills an empty subject with the gold you're sending
--   Express     - alt-click a bag item to attach it; shift-alt-click attaches every stack of it
--   QuickAttach - one-click buttons that attach all your cloth, herbs, ore, and so on
local ADDON_NAME, P = ...
local MAX_ATTACH = 12

local function Short(n) return (tostring(n or ""):gsub("%-.*$", "")) end
local function MyName() return P.PlayerName() end

---------------------------------------------------------------------------
-- Contacts
---------------------------------------------------------------------------
-- Alts saved by older versions under a first name only ("Busta"): if exactly one contact you
-- know has that first name ("Busta Knute"), fill in the rest.
local function FullName(first, candidates)
    local want, found = first:lower() .. " ", nil
    for _, n in ipairs(candidates) do
        local s = Short(n)
        if s:lower():sub(1, #want) == want then
            if found and found ~= s then return nil end
            found = s
        end
    end
    return found
end

local Friends, Guild
local function UpgradeAlts()
    local candidates, changes
    for key, c in pairs(P.db.alts) do
        if c.name and not c.name:find(" ", 1, true) then
            candidates = candidates or (function()
                local all = {}
                for _, n in ipairs(P.db.recent) do all[#all + 1] = n end
                for _, n in ipairs(Friends()) do all[#all + 1] = n end
                for _, n in ipairs(Guild()) do all[#all + 1] = n end
                return all
            end)()
            local full = FullName(c.name, candidates)
            if full then
                changes = changes or {}
                changes[#changes + 1] = { key, full, c }
            end
        end
    end
    -- apply after the loop: changing a table while walking it isn't allowed
    for _, ch in ipairs(changes or {}) do
        local key, full, c = ch[1], ch[2], ch[3]
        P.db.alts[key] = nil
        c.name = full
        P.db.alts[full .. "-" .. (c.realm or "")] = c
    end
end

local function Alts()
    UpgradeAlts()
    local out = {}
    local _, _, myRealm = P.CharKey()
    local faction = UnitFactionGroup and UnitFactionGroup("player")
    for _, c in pairs(P.db.alts) do
        if c.name ~= MyName() and (not faction or not c.faction or c.faction == faction) then
            local n = c.name
            if c.realm and myRealm and c.realm ~= myRealm then n = n .. "-" .. c.realm end
            out[#out + 1] = n
        end
    end
    table.sort(out)
    return out
end

Friends = function()
    local out = {}
    if C_FriendList and C_FriendList.GetNumFriends and C_FriendList.GetFriendInfoByIndex then
        for i = 1, C_FriendList.GetNumFriends() or 0 do
            local info = C_FriendList.GetFriendInfoByIndex(i)
            if info and info.name and not P.IsSecret(info.name) then out[#out + 1] = info.name end
        end
    end
    table.sort(out)
    return out
end

Guild = function(limit)
    local out = {}
    if not (IsInGuild and IsInGuild() and GetNumGuildMembers) then return out end
    local online, offline = {}, {}
    for i = 1, GetNumGuildMembers() or 0 do
        local name, _, _, _, _, _, _, _, isOnline = GetGuildRosterInfo(i)
        if name and not P.IsSecret(name) then
            local s = Ambiguate and Ambiguate(name, "mail") or name
            if Short(s) ~= MyName() then
                if isOnline then online[#online + 1] = s else offline[#offline + 1] = s end
            end
        end
    end
    table.sort(online) table.sort(offline)
    for _, n in ipairs(online) do out[#out + 1] = n end
    for _, n in ipairs(offline) do out[#out + 1] = n end
    if limit then while #out > limit do table.remove(out) end end
    return out
end

function P.Contacts()
    local all, seen = {}, {}
    local function add(list) for _, n in ipairs(list) do local k = n:lower() if not seen[k] then seen[k] = true all[#all + 1] = n end end end
    add(Alts()) add(P.db.recent) add(Friends()) add(Guild())
    return all
end

-- first contact that starts with what's typed, or nil
function P.Complete(text)
    if not text or text == "" then return nil end
    local t = text:lower()
    for _, n in ipairs(P.Contacts()) do
        if n:lower():sub(1, #t) == t and #n > #text then return n end
    end
end

local function SetRecipient(name)
    local box = _G.SendMailNameEditBox
    if box then
        box:SetText(name)
        local subj = _G.SendMailSubjectEditBox
        if subj then subj:SetFocus() end
    end
end

local function BlackBookMenu(anchor)
    local entries = {}
    local function section(title, list)
        if #list == 0 then return end
        entries[#entries + 1] = { text = title, title = true }
        for _, n in ipairs(list) do
            entries[#entries + 1] = { text = n, func = function() SetRecipient(n) end }
        end
    end
    -- Alts: always shown, so it's clear where they'll appear
    local alts = Alts()
    entries[#entries + 1] = { text = "Alts", title = true }
    if #alts == 0 then
        entries[#entries + 1] = { text = "Log in on each alt once to list it here", note = true }
    end
    for _, n in ipairs(alts) do
        entries[#entries + 1] = { text = n, func = function() SetRecipient(n) end }
    end
    local recent = {}
    for i = 1, math.min(8, #P.db.recent) do recent[i] = P.db.recent[i] end
    section("Recently mailed", recent)
    section("Friends", Friends())
    section("Guild", Guild(10))
    -- add or remove the name in the To: box as one of your alts
    local box = _G.SendMailNameEditBox
    local typed = box and P.Trim(box:GetText() or "") or ""
    if typed ~= "" and typed:lower() ~= (MyName() or ""):lower() then
        local key = P.FindAlt(typed)
        entries[#entries + 1] = key
            and { text = "Remove " .. typed .. " from Alts", func = function() P.db.alts[key] = nil P.Print(typed .. " removed from your alts.") end }
            or { text = "Add " .. typed .. " to Alts", func = function() P.AddAlt(typed) P.Print(typed .. " added to your alts.") end }
    end
    P.ShowMenu(anchor, entries)
end

-- alts added by hand (for characters that haven't logged in with Postage yet)
function P.FindAlt(name)
    local want = Short(name):lower()
    for key, c in pairs(P.db.alts) do
        if c.name and c.name:lower() == want then return key end
    end
end

function P.AddAlt(name)
    local _, _, realm = P.CharKey()
    local n = Short(name)
    n = n:sub(1, 1):upper() .. n:sub(2)
    P.db.alts[n .. "-" .. (realm or "")] = {
        name = n, realm = realm, faction = UnitFactionGroup and UnitFactionGroup("player"), manual = true,
    }
end

-- remember who you mail
local pendingTo
if type(SendMail) == "function" then
    hooksecurefunc("SendMail", function(to) pendingTo = to end)
end
P.AddHook("sendSuccess", function()
    if not pendingTo or pendingTo == "" then return end
    local name = pendingTo
    pendingTo = nil
    -- Keep recipient: Blizzard clears the form after a send; put the name back afterwards
    if P.db.keepRecipient then
        local function restore()
            local box = _G.SendMailNameEditBox
            if box and P.Trim(box:GetText() or "") == "" then box:SetText(name) end
        end
        restore()
        C_Timer.After(0, restore)
        C_Timer.After(0.2, restore)
    end
    local recent = P.db.recent
    for i = #recent, 1, -1 do if recent[i]:lower() == name:lower() then table.remove(recent, i) end end
    table.insert(recent, 1, name)
    while #recent > 20 do table.remove(recent) end
end)

---------------------------------------------------------------------------
-- Attaching
---------------------------------------------------------------------------
local function FreeAttachSlot()
    if not GetSendMailItem then return 1 end
    local max = tonumber(_G.ATTACHMENTS_MAX_SEND) or MAX_ATTACH
    for i = 1, max do
        if not GetSendMailItem(i) then return i end
    end
end

local function EnsureSendTab()
    local sf = _G.SendMailFrame
    if sf and not sf:IsVisible() and _G.MailFrame and _G.MailFrame:IsVisible() and MailFrameTab_OnClick then
        pcall(MailFrameTab_OnClick, nil, 2)
    end
    return sf and sf:IsVisible()
end

local function ItemInfo(bag, slot)
    if C_Container and C_Container.GetContainerItemInfo then
        return C_Container.GetContainerItemInfo(bag, slot)
    end
end

-- attach one bag slot; returns true if it went on
function P.AttachBagItem(bag, slot)
    local info = ItemInfo(bag, slot)
    if not info or info.isLocked then return false end
    if info.isBound then return false end
    local i = FreeAttachSlot()
    if not i then P.Print("All attachment slots are full.") return false end
    if CursorHasItem and CursorHasItem() then ClearCursor() end
    local pick = (C_Container and C_Container.PickupContainerItem) or PickupContainerItem
    pick(bag, slot)
    ClickSendMailItemButton(i)
    return true
end

-- attach every unbound stack in your bags that matches test(itemID); returns how many
function P.AttachWhere(test)
    local n = 0
    local nslots = (C_Container and C_Container.GetContainerNumSlots) or GetContainerNumSlots
    for bag = 0, 4 do
        for slot = 1, (nslots and nslots(bag) or 0) do
            local info = ItemInfo(bag, slot)
            if info and info.itemID and not info.isBound and not info.isLocked and test(info.itemID) then
                if not FreeAttachSlot() then return n end
                if P.AttachBagItem(bag, slot) then n = n + 1 end
            end
        end
    end
    return n
end

-- Alt-click in your bags. Bag clicks go through HandleModifiedItemClick(link, itemLocation).
if type(HandleModifiedItemClick) == "function" then
    hooksecurefunc("HandleModifiedItemClick", function(link, loc)
        if not (P.On("express") and IsAltKeyDown() and P.AtMailbox()) then return end
        if not (loc and loc.GetBagAndSlot) then return end
        local ok, bag, slot = pcall(loc.GetBagAndSlot, loc)
        if not ok or not bag then return end
        if not EnsureSendTab() then return end
        if IsShiftKeyDown() then
            local info = ItemInfo(bag, slot)
            local id = info and info.itemID
            if id then
                local n = P.AttachWhere(function(x) return x == id end)
                P.Print(("Attached %d stack(s)."):format(n))
            end
        else
            P.AttachBagItem(bag, slot)
        end
    end)
end

---------------------------------------------------------------------------
-- QuickAttach. Trade Goods is item class 7 on this client; the subclass numbers below are the
-- standard ones and haven't been checked against a Forever client yet, so "All trade goods"
-- is there as a catch-all.
---------------------------------------------------------------------------
local QUICK = {
    { "Cloth", 5, "Interface\\Icons\\INV_Fabric_Linen_01" },
    { "Leather", 6, "Interface\\Icons\\INV_Misc_LeatherScrap_03" },
    { "Metal & Stone", 7, "Interface\\Icons\\INV_Ore_Copper_01" },
    { "Cooking", 8, "Interface\\Icons\\INV_Misc_Food_15" },
    { "Herbs", 9, "Interface\\Icons\\INV_Misc_Herb_07" },
    { "Elemental", 10, "Interface\\Icons\\INV_Elemental_Primal_Fire" },
    { "Enchanting", 12, "Interface\\Icons\\INV_Enchant_DustStrange" },
    { "All trade goods", nil, "Interface\\Icons\\INV_Misc_Bag_10" },
}

local function ClassOf(itemID)
    if C_Item and C_Item.GetItemInfoInstant then
        local _, _, _, _, _, classID, subID = C_Item.GetItemInfoInstant(itemID)
        return classID, subID
    end
end

function P.QuickAttach(sub)
    if not EnsureSendTab() then P.Print("Open the Send Mail tab first.") return 0 end
    local n = P.AttachWhere(function(id)
        local c, s = ClassOf(id)
        return c == 7 and (sub == nil or s == sub)
    end)
    P.Print(n > 0 and ("Attached %d stack(s)."):format(n) or "Nothing of that kind in your bags.")
    return n
end

---------------------------------------------------------------------------
-- Building into the Send Mail frame
---------------------------------------------------------------------------
local ui = {}

local function Build()
    local sf, box = _G.SendMailFrame, _G.SendMailNameEditBox

    -- BlackBook button and autocomplete
    if box then
        local b = CreateFrame("Button", "PostageBlackBookButton", box)
        b:SetSize(24, 24)
        b:SetPoint("LEFT", box, "RIGHT", 2, 0)
        b:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up")
        b:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Down")
        b:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
        b:SetScript("OnClick", function(self) BlackBookMenu(self) end)
        b:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText("Contacts", 1, 1, 1)
            GameTooltip:AddLine("Your alts, people you've mailed, friends and guild.", 0.85, 0.85, 0.85, true)
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
        ui.blackbook = b

        -- only complete on typed characters, so backspace still deletes normally
        box:HookScript("OnChar", function(self)
            if not (P.On("blackbook") and P.db.autocomplete ~= false) then return end
            local text = self:GetText()
            local match = P.Complete(text)
            if match then
                self:SetText(match)
                self:HighlightText(#text, #match)
                if self.SetCursorPosition then self:SetCursorPosition(#text) end
            end
        end)
    end

    -- Keep recipient checkbox, above the Send Money / C.O.D. choice
    if sf then
        local cb = CreateFrame("CheckButton", "PostageKeepRecipient", sf, "UICheckButtonTemplate")
        cb:SetSize(20, 20)
        if cb.text then cb.text:SetText("") end
        if cb.Text then cb.Text:SetText("") end
        local radio = _G.SendMailSendMoneyButton
        if radio then
            cb:SetPoint("BOTTOMLEFT", radio, "TOPLEFT", -2, 2)
        elseif _G.SendMailMoney then
            cb:SetPoint("BOTTOMLEFT", _G.SendMailMoney, "TOPRIGHT", 34, 4)
        else
            cb:SetPoint("BOTTOMRIGHT", sf, "BOTTOMRIGHT", -110, 100)
        end
        local label = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        label:SetPoint("LEFT", cb, "RIGHT", 1, 0)
        label:SetText("Keep recipient")
        cb:SetHitRectInsets(0, -80, 0, 0)
        cb:SetScript("OnClick", function(self) P.db.keepRecipient = self:GetChecked() and true or false end)
        cb:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText("Keep recipient", 1, 1, 1)
            GameTooltip:AddLine("Keep the name in the To: box after sending, so you can send several mails to the same person.", 0.85, 0.85, 0.85, true)
            GameTooltip:Show()
        end)
        cb:SetScript("OnLeave", function() GameTooltip:Hide() end)
        ui.keep = cb
    end

    -- Wire
    local send = _G.SendMailMailButton
    if send then
        send:HookScript("PreClick", function()
            if not P.On("wire") then return end
            local subj, money = _G.SendMailSubjectEditBox, _G.SendMailMoney
            if not subj or P.Trim(subj:GetText() or "") ~= "" then return end
            local copper = 0
            if money and money.GetAmount then copper = money:GetAmount() or 0
            elseif MoneyInputFrame_GetCopper and money then copper = MoneyInputFrame_GetCopper(money) or 0 end
            if type(copper) == "number" and copper > 0 and not P.IsSecret(copper) then
                local g, s, c = math.floor(copper / 10000), math.floor((copper % 10000) / 100), copper % 100
                local parts = {}
                if g > 0 then parts[#parts + 1] = g .. "g" end
                if s > 0 then parts[#parts + 1] = s .. "s" end
                if c > 0 or #parts == 0 then parts[#parts + 1] = c .. "c" end
                subj:SetText(table.concat(parts, " "))
            end
        end)
    end

    -- QuickAttach column down the right edge of the Send Mail frame
    if sf then
        ui.quick = {}
        for i, q in ipairs(QUICK) do
            local b = CreateFrame("Button", nil, sf)
            b:SetSize(26, 26)
            b:SetPoint("TOPLEFT", sf, "TOPRIGHT", 2, -60 - (i - 1) * 30)
            b:SetNormalTexture(q[3])
            b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
            b:SetScript("OnClick", function() P.QuickAttach(q[2]) end)
            b:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText("Attach all: " .. q[1], 1, 1, 1)
                GameTooltip:AddLine("Soulbound items are skipped. Up to 12 per mail.", 0.8, 0.8, 0.8, true)
                GameTooltip:Show()
            end)
            b:SetScript("OnLeave", function() GameTooltip:Hide() end)
            ui.quick[i] = b
        end
    end
end

local function Refresh()
    if ui.keep then ui.keep:SetChecked(P.db.keepRecipient and true or false) end
    if ui.blackbook then ui.blackbook:SetShown(P.On("blackbook")) end
    if ui.quick then for _, b in ipairs(ui.quick) do b:SetShown(P.On("quickattach")) end end
end

P.AddHook("mailInit", Build)
P.AddHook("mailShow", Refresh)
P.AddHook("options", Refresh)
