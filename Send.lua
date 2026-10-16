-- Postage send-mail side:
--   BlackBook   - a contact button on the To: box (your alts, recently mailed, friends, guild),
--                 plus name autocomplete as you type
--   Wire        - fills an empty subject with the gold you're sending, as soon as you type the gold
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
    local seen = { [(MyName() or ""):lower()] = true }     -- a name shows once, in the first section that has it
    local function fresh(list, limit)
        local out = {}
        for _, n in ipairs(list) do
            local k = Short(n):lower()
            if not seen[k] then
                seen[k] = true
                out[#out + 1] = n
                if limit and #out >= limit then break end
            end
        end
        return out
    end
    local function section(title, list)
        if #list == 0 then return end
        entries[#entries + 1] = { text = title, title = true }
        for _, n in ipairs(list) do
            entries[#entries + 1] = { text = n, func = function() SetRecipient(n) end }
        end
    end
    -- Alts: always shown, so it's clear where they'll appear
    local alts = fresh(Alts())
    entries[#entries + 1] = { text = "Alts", title = true }
    if #alts == 0 then
        entries[#entries + 1] = { text = "Log in on each alt once to list it here", note = true }
    end
    for _, n in ipairs(alts) do
        entries[#entries + 1] = { text = n, func = function() SetRecipient(n) end }
    end
    section("Recently mailed", fresh(P.db.recent, 8))
    section("Friends", fresh(Friends()))
    section("Guild", fresh(Guild(), 10))
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
-- Each button: { label, icon, test(id, class, subclass, lowercase name) }

local function ClassOf(itemID)
    if C_Item and C_Item.GetItemInfoInstant then
        local _, _, _, _, _, classID, subID = C_Item.GetItemInfoInstant(itemID)
        return classID, subID
    end
end

local function NameOf(id)
    local name = (C_Item and C_Item.GetItemInfo and C_Item.GetItemInfo(id)) or (GetItemInfo and GetItemInfo(id))
    return type(name) == "string" and name:lower() or ""
end

local function Any(name, words)
    for _, w in ipairs(words) do if name:find(w, 1, true) then return true end end
    return false
end

-- words that make a Trade Goods "meat" item a fish (fish are filed together with meat on this client)
local FISH_WORDS = { "fish", "mackerel", "catfish", "salmon", "snapper", "eel", "squid", "lobster", "trout", "bass",
    "tuna", "sturgeon", "mightfish", "blackmouth", "clam", "crab", "whisker", "oyster", "shrimp", "pike",
    "stonescale", "firefin", "nightfin", "angler", "herring", "sardine", "minnow", "flounder", "grouper" }
local function IsFish(id) return Any(NameOf(id), FISH_WORDS) end

-- skinned (raw) leather and scales; everything else filed as leather is made by leatherworkers
local SKIN_WORDS = { "hide", "scrap", "scale", "devilsaur leather", "core leather", "chimera leather", "warbear leather",
    "knothide", "wolfhide", "blackened", "lava core", "worn dragon" }
-- raw stone, as opposed to bars and sharpening stones
local RAW_STONE = { "rough stone", "coarse stone", "heavy stone", "solid stone", "dense stone" }
-- things alchemists make that are filed as trade goods rather than potions
local ALCHEMY_MADE = { "acid", "ink", "vial", "stonescale oil", "blackmouth oil", "firefin oil", "philosopher", "mageblood" }

local QUICK = {
    { "Tailoring: cloth", "Interface\\Icons\\INV_Fabric_Linen_01", function(id, c, s) return c == 7 and s == 5 end },
    { "Skinning: raw leather, hides and scales", "Interface\\Icons\\INV_Misc_Pelt_Wolf_01",
      function(id, c, s, n) return c == 7 and s == 6 and Any(n, SKIN_WORDS) end },
    { "Leatherworking: cured and crafted leather", "Interface\\Icons\\INV_Misc_LeatherScrap_03",
      function(id, c, s, n) return c == 7 and s == 6 and not Any(n, SKIN_WORDS) end },
    { "Mining: ore and raw stone", "Interface\\Icons\\INV_Ore_Copper_01",
      function(id, c, s, n) return c == 7 and s == 7 and (n:find("ore", 1, true) and not n:find("core", 1, true) or Any(n, RAW_STONE)) and not Any(n, { "bar" }) end },
    { "Blacksmithing: bars, sharpening and weight stones", "Interface\\Icons\\INV_Ingot_03",
      function(id, c, s, n)
          if c == 7 and s == 7 then
              if Any(n, RAW_STONE) then return false end
              if n:find("ore", 1, true) and not n:find("core", 1, true) and not n:find("bar", 1, true) then return false end
              return true
          end
          return (c == 0 or c == 7) and Any(n, { "sharpening stone", "weightstone", "grinding stone", "whetstone" })
      end },
    { "Fishing: fish and shellfish", "Interface\\Icons\\INV_Misc_Fish_02", function(id, c, s, n) return c == 7 and s == 8 and IsFish(id) and not Any(n, ALCHEMY_MADE) end },
    { "Cooking: meat and fish", "Interface\\Icons\\INV_Misc_Food_15", function(id, c, s, n) return c == 7 and s == 8 and not Any(n, ALCHEMY_MADE) end },
    { "Herbalism: herbs", "Interface\\Icons\\INV_Misc_Herb_07", function(id, c, s) return c == 7 and s == 9 end },
    { "Alchemy: potions, elixirs, flasks and what alchemists make", "Interface\\Icons\\INV_Potion_54",
      function(id, c, s, n)
          if c == 0 and (s == 1 or s == 2 or s == 3) then return true end
          return c == 7 and s ~= 9 and Any(n, ALCHEMY_MADE)
      end },
    { "Elemental: motes, essences, primals", "Interface\\Icons\\INV_Elemental_Primal_Fire", function(id, c, s) return c == 7 and s == 10 end },
    { "Enchanting: dust, essences, shards", "Interface\\Icons\\INV_Enchant_DustStrange", function(id, c, s) return c == 7 and s == 12 end },
    { "Engineering: parts, explosives, devices", "Interface\\Icons\\INV_Misc_Gear_01",
      function(id, c, s) return c == 7 and (s == 1 or s == 2 or s == 3) end },
    { "First Aid: bandages", "Interface\\Icons\\INV_Misc_Bandage_15", function(id, c, s) return c == 0 and s == 7 end },
    { "Other trade goods", "Interface\\Icons\\INV_Misc_Rune_01", function(id, c, s) return c == 7 and s == 11 end },
    { "All trade goods", "Interface\\Icons\\INV_Misc_Bag_10", function(id, c) return c == 7 end },
}

function P.QuickAttach(test)
    if not EnsureSendTab() then P.Print("Open the Send Mail tab first.") return 0 end
    local n = P.AttachWhere(function(id)
        local c, s = ClassOf(id)
        if not c then return false end
        return test(id, c, s, NameOf(id)) and true or false
    end)
    P.Print(n > 0 and ("Attached %d stack(s)."):format(n) or "Nothing of that kind in your bags.")
    return n
end

---------------------------------------------------------------------------
-- The quick-attach tray: one tidy panel attached to the Send Mail window
---------------------------------------------------------------------------
P.QUICK = QUICK
local ui = {}

local TRAY_DEFAULTS = { tray = true, traySide = "right", trayCols = 3, traySize = 28, trayGap = 4, trayPanel = true,
    trayTitle = true, trayCounts = true, trayHideEmpty = false, trayAlpha = 0.96 }
local function MS()
    local s = P.WinLook and P.WinLook.Get and P.WinLook.Get("mail")
    return s or TRAY_DEFAULTS
end

-- how many unsoulbound stacks in your bags a button would attach
function P.QuickCount(test)
    local n = 0
    local nslots = (C_Container and C_Container.GetContainerNumSlots) or GetContainerNumSlots
    for bag = 0, 4 do
        for slot = 1, (nslots and nslots(bag) or 0) do
            local info = ItemInfo(bag, slot)
            if info and info.itemID and not info.isBound then
                local c, sub = ClassOf(info.itemID)
                if c and test(info.itemID, c, sub, NameOf(info.itemID)) then n = n + 1 end
            end
        end
    end
    return n
end

local function TrayColors()
    local look = P.Look()
    local bg, edge, accent = look.bg, look.edge, look.accent
    if P.WinLook and P.WinLook.On and P.WinLook.On("mail") then
        local e = P.WinLook.Effective("mail")
        if e then bg, edge, accent = e.bgColor, e.edgeColor, e.titleColor end
    end
    return bg, edge, accent
end

function P.BuildTray()
    if ui.tray then return ui.tray end
    local sf = _G.SendMailFrame
    if not sf then return end
    local t = CreateFrame("Frame", "PostageQuickTray", sf, "BackdropTemplate")
    t:SetFrameLevel((sf:GetFrameLevel() or 1) + 3)
    t:SetClampedToScreen(true)
    t.title = t:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    t.title:SetText("Quick attach")
    t.line = t:CreateTexture(nil, "ARTWORK")
    t.line:SetTexture("Interface\\Buttons\\WHITE8X8")
    t.buttons = {}
    for i, q in ipairs(QUICK) do
        local b = CreateFrame("Button", nil, t)
        b.q = q
        b.edge = b:CreateTexture(nil, "BACKGROUND")
        b.edge:SetTexture("Interface\\Buttons\\WHITE8X8")
        b.edge:SetAllPoints(b)
        b.icon = b:CreateTexture(nil, "ARTWORK")
        b.icon:SetPoint("TOPLEFT", 1, -1) b.icon:SetPoint("BOTTOMRIGHT", -1, 1)
        b.icon:SetTexture(q[2])
        b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
        b.count = b:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
        b.count:SetPoint("BOTTOMRIGHT", -2, 2)
        b:SetScript("OnClick", function() P.QuickAttach(q[3]) P.RefreshTray() end)
        b:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(q[1], 1, 1, 1)
            local n = self.n or 0
            if n > 0 then
                GameTooltip:AddLine(("Click to attach %d stack%s from your bags."):format(n, n == 1 and "" or "s"), 0.5, 1, 0.5, true)
            else
                GameTooltip:AddLine("Nothing of that kind in your bags right now.", 0.7, 0.7, 0.7, true)
            end
            GameTooltip:AddLine("Soulbound items are skipped. Up to 12 per mail.", 0.6, 0.6, 0.6, true)
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
        t.buttons[i] = b
    end
    ui.tray = t
    -- keep the counts current while the Send Mail tab is open
    local ev = CreateFrame("Frame")
    ev:RegisterEvent("BAG_UPDATE_DELAYED")
    ev:SetScript("OnEvent", function()
        if t:IsVisible() and not ev.pending then
            ev.pending = true
            C_Timer.After(0.25, function() ev.pending = false P.RefreshTray() end)
        end
    end)
    t:SetScript("OnShow", function() P.RefreshTray() end)
    return t
end

function P.LayoutTray()
    local t = ui.tray
    if not t then return end
    local s = MS()
    if not (P.On("quickattach") and s.tray ~= false) then t:Hide() return end
    local anchor = _G.MailFrame or _G.SendMailFrame
    local size = math.max(20, math.min(44, tonumber(s.traySize) or 28))
    local gap = math.max(0, math.min(10, tonumber(s.trayGap) or 4))
    local pad = 7
    local list = {}
    for i, b in ipairs(t.buttons) do
        local shown = s["q" .. i] ~= false
        if shown and s.trayHideEmpty and (b.n or 0) == 0 then shown = false end
        if shown then list[#list + 1] = b else b:Hide() end
    end
    if #list == 0 then t:Hide() return end
    local side = s.traySide or "right"
    local cols
    if side == "below" then
        local w = (anchor and anchor:GetWidth() or 360) - pad * 2
        cols = math.max(1, math.floor((w + gap) / (size + gap)))
    else
        cols = math.max(1, math.min(6, tonumber(s.trayCols) or 3))
    end
    cols = math.min(cols, #list)
    local rows = math.ceil(#list / cols)
    local titleH = s.trayTitle ~= false and 18 or 0
    t:SetSize(pad * 2 + cols * size + (cols - 1) * gap, pad * 2 + titleH + rows * size + (rows - 1) * gap)
    t:ClearAllPoints()
    if side == "left" then t:SetPoint("TOPRIGHT", anchor, "TOPLEFT", -2, -8)
    elseif side == "below" then t:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, 2)
    else t:SetPoint("TOPLEFT", anchor, "TOPRIGHT", 2, -8) end
    local bg, edge, accent = TrayColors()
    if t.SetBackdrop then
        if s.trayPanel ~= false then
            t:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
            t:SetBackdropColor(bg[1], bg[2], bg[3], tonumber(s.trayAlpha) or 0.96)
            t:SetBackdropBorderColor(edge[1], edge[2], edge[3], 0.95)
        else
            t:SetBackdrop(nil)
        end
    end
    t.title:ClearAllPoints()
    t.title:SetPoint("TOPLEFT", pad, -6)
    t.title:SetTextColor(accent[1], accent[2], accent[3])
    t.title:SetShown(s.trayTitle ~= false)
    t.line:ClearAllPoints()
    t.line:SetPoint("TOPLEFT", pad, -(6 + 12))
    t.line:SetPoint("TOPRIGHT", -pad, -(6 + 12))
    t.line:SetHeight(1)
    t.line:SetVertexColor(edge[1], edge[2], edge[3], 0.6)
    t.line:SetShown(s.trayTitle ~= false)
    for idx, b in ipairs(list) do
        local col, row = (idx - 1) % cols, math.floor((idx - 1) / cols)
        b:SetSize(size, size)
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", t, "TOPLEFT", pad + col * (size + gap), -(pad + titleH + row * (size + gap)))
        b.edge:SetVertexColor(edge[1], edge[2], edge[3], (b.n or 0) > 0 and 0.9 or 0.35)
        local have = (b.n or 0) > 0
        b.icon:SetDesaturated(not have)
        b.icon:SetAlpha(have and 1 or 0.4)
        b.count:SetText((s.trayCounts ~= false and have) and b.n or "")
        b:Show()
    end
    t:Show()
end

function P.RefreshTray()
    local t = ui.tray
    if not t then return end
    for _, b in ipairs(t.buttons) do b.n = P.QuickCount(b.q[3]) end
    P.LayoutTray()
end

-- letter paper of the Send Mail and Open Mail windows
local PAPER_PIECES = {
    mail = { "SendStationeryBackgroundLeft", "SendStationeryBackgroundRight" },
    openmail = { "OpenStationeryBackgroundLeft", "OpenStationeryBackgroundRight" },
}
local function PaperPieces(id)
    local out = {}
    for _, name in ipairs(PAPER_PIECES[id]) do if _G[name] then out[#out + 1] = _G[name] end end
    if id == "mail" then   -- the inbox's own paper: any large picture on the inbox page
        if _G.InboxFrameBg then out[#out + 1] = _G.InboxFrameBg end
        local ib = _G.InboxFrame
        if ib and ib.GetRegions then
            for _, r in ipairs({ ib:GetRegions() }) do
                if r.GetObjectType and r:GetObjectType() == "Texture" and r ~= _G.InboxFrameBg then
                    local w, h = r:GetWidth() or 0, r:GetHeight() or 0
                    if w >= 150 and h >= 100 then out[#out + 1] = r end
                end
            end
        end
    end
    return out
end
local function ApplyPaper(id)
    local s = P.WinLook and P.WinLook.Get and P.WinLook.Get(id)
    if not s then return end
    -- GreedUI's page for Postage can choose the paper too; with GreedUI's look on, the default paper is dark
    local GU = _G.GreedUI
    local gt = GU and GU.GetTheme and GU.GetTheme("Postage")
    local mode, pcol, palpha = s.paper or "original", s.paperColor, s.paperAlpha
    if gt then mode, pcol, palpha = gt.paper or (mode == "original" and "dark" or mode), gt.paperColor or pcol, gt.paperAlpha or palpha end
    for _, tex in ipairs(PaperPieces(id)) do
        if tex.SetVertexColor then
            if not tex.pgOrig then
                local r, g, b = tex:GetVertexColor()
                tex.pgOrig = { r or 1, g or 1, b or 1, tex:GetAlpha() or 1 }
            end
            local o = tex.pgOrig
            if mode == "hidden" then
                tex:SetAlpha(0)
            elseif mode == "tint" or mode == "dark" then
                local c = mode == "dark" and { 0.16, 0.14, 0.12 } or (pcol or { 0.1, 0.1, 0.13 })
                if tex.SetDesaturated then tex:SetDesaturated(true) end
                tex:SetVertexColor(c[1] * 1.6, c[2] * 1.6, c[3] * 1.6)
                tex:SetAlpha((tonumber(palpha) or 1) * o[4])
            else
                if tex.SetDesaturated then tex:SetDesaturated(false) end
                tex:SetVertexColor(o[1], o[2], o[3])
                tex:SetAlpha((tonumber(palpha) or 1) * o[4])
            end
        end
    end
end

local function ApplySlots()
    local s = P.WinLook and P.WinLook.Get and P.WinLook.Get("mail")
    local sc = s and tonumber(s.slotScale) or 1
    for i = 1, 12 do
        local b = _G["SendMailAttachment" .. i]
        if b and b.SetScale then b:SetScale(sc) end
    end
end

function P.ApplyMailLook()
    pcall(ApplySlots)
    pcall(ApplyPaper, "mail")
    pcall(ApplyPaper, "openmail")
    if P.SkinMail then P.SkinMail() end
    P.LayoutTray()
end

---------------------------------------------------------------------------
-- Building into the Send Mail frame
---------------------------------------------------------------------------

local function Build()
    local sf, box = _G.SendMailFrame, _G.SendMailNameEditBox

    -- BlackBook button and autocomplete
    if box then
        local b = CreateFrame("Button", "PostageBlackBookButton", box)
        -- inside the To: box (its right edge), so it never covers the Postage: cost label beside it
        b:SetSize(18, 18)
        b:SetPoint("RIGHT", box, "RIGHT", -2, 0)
        b:SetFrameLevel(box:GetFrameLevel() + 3)
        if box.SetTextInsets then box:SetTextInsets(0, 20, 0, 0) end
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

    -- Wire: Blizzard keeps Send disabled while the subject is empty, so a click hook is too late.
    -- Fill the subject as soon as gold is entered (and take it back out if the gold is removed).
    local lastAuto
    local filling = false
    local function GoldText()
        local money = _G.SendMailMoney
        local copper = 0
        if money and money.GetAmount then copper = money:GetAmount() or 0
        elseif MoneyInputFrame_GetCopper and money then copper = MoneyInputFrame_GetCopper(money) or 0 end
        if type(copper) ~= "number" or P.IsSecret(copper) or copper <= 0 then return nil end
        local g, s, c = math.floor(copper / 10000), math.floor((copper % 10000) / 100), copper % 100
        local parts = {}
        if g > 0 then parts[#parts + 1] = g .. "g" end
        if s > 0 then parts[#parts + 1] = s .. "s" end
        if c > 0 then parts[#parts + 1] = c .. "c" end
        return table.concat(parts, " ")
    end
    local function AutoSubject()
        if filling or not P.On("wire") then return end
        local subj = _G.SendMailSubjectEditBox
        if not subj then return end
        local cur = P.Trim(subj:GetText() or "")
        local want = GoldText()
        filling = true
        if want and (cur == "" or cur == lastAuto) then
            if cur ~= want then subj:SetText(want) end
            lastAuto = want
        elseif not want and lastAuto and cur == lastAuto then
            subj:SetText("")
            lastAuto = nil
        end
        filling = false
        if cur == "" and want and _G.SendMailFrame_CanSend then pcall(_G.SendMailFrame_CanSend) end
    end
    P.AutoSubject = AutoSubject
    local money = _G.SendMailMoney
    if money then
        for _, k in ipairs({ "gold", "silver", "copper" }) do
            local box = money[k]
            if box and box.HookScript then box:HookScript("OnTextChanged", AutoSubject) end
        end
    end
    if _G.SendMailFrame_CanSend then hooksecurefunc("SendMailFrame_CanSend", AutoSubject) end
    local send = _G.SendMailMailButton
    if send then send:HookScript("PreClick", AutoSubject) end
    if _G.SendMailFrame then _G.SendMailFrame:HookScript("OnShow", function() lastAuto = nil end) end

    -- the quick-attach tray beside the Send Mail window
    if sf then P.BuildTray() end
    if P.WinLook then
        if _G.MailFrame then P.WinLook.Attach("mail", _G.MailFrame) end
        if _G.OpenMailFrame then P.WinLook.Attach("openmail", _G.OpenMailFrame) end
    end
end

local function Refresh()
    if ui.keep then ui.keep:SetChecked(P.db.keepRecipient and true or false) end
    if ui.blackbook then ui.blackbook:SetShown(P.On("blackbook")) end
    if P.RefreshTray then P.RefreshTray() end
    if P.ApplyMailLook then P.ApplyMailLook() end
end

P.AddHook("mailInit", Build)
P.AddHook("mailShow", Refresh)
P.AddHook("options", Refresh)
