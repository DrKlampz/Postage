-- Postage's inbox: replaces Blizzard's default 7-row paged inbox list with one scrollable list
-- showing every mail at once, with checkboxes and the shift/ctrl/alt-click shortcuts Postal is
-- known for.
--
-- Frame names for the default inbox buttons (InboxFrame, MailItem1Button..MailItem7Button, and
-- their scrollbar) have been stable across every version of WoW for about twenty years, so this
-- hides them outright; every hide is pcall-wrapped, so if a name is ever missing on this client
-- Postage's own list still works, just with Blizzard's small list still visible underneath it.
local ADDON_NAME, P = ...
local IsSecret, Trim = P.IsSecret, P.Trim

local ROWS, ROW_H = 12, 34
local rows = {}
local checked = {}          -- index -> true, keyed by a stable id (sender.."/"..subject.."/"..money.."/"..itemCount) since indices shift as mail is taken
local lastClickedRow = nil   -- for shift-click range select
local frame

---------------------------------------------------------------------------
-- Reading the inbox
---------------------------------------------------------------------------
local function StableID(h)
    return table.concat({ tostring(h.sender), tostring(h.subject), tostring(h.money), tostring(h.itemCount), tostring(h.textCreated) }, "\1")
end

-- One entry per mail: everything GetInboxHeaderInfo/GetInboxItem give us, indices included so
-- clicking a row can still act on it (indices are only valid until the next inbox update).
local function ReadInbox()
    local out = {}
    local n = GetInboxNumItems and GetInboxNumItems() or 0
    for i = 1, n do
        local packageIcon, stationeryIcon, sender, subject, money, CODAmount, daysLeft, itemCount,
              wasRead, wasReturned, textCreated, canReply, isGM = GetInboxHeaderInfo(i)
        if sender ~= nil and not IsSecret(sender) then
            local h = {
                index = i, sender = sender, subject = subject, money = money or 0,
                cod = CODAmount or 0, daysLeft = daysLeft, itemCount = itemCount or 0,
                wasRead = wasRead, isGM = isGM, textCreated = textCreated, canReply = canReply,
            }
            h.id = StableID(h)
            h.auction = P.IsAuctionMail(subject)
            out[#out + 1] = h
        end
    end
    return out
end
P.ReadInbox = ReadInbox

---------------------------------------------------------------------------
-- Hiding Blizzard's own list
---------------------------------------------------------------------------
local function HideBlizzardInbox()
    for i = 1, 7 do
        local b = _G["MailItem" .. i .. "Button"]
        if b then pcall(b.Hide, b) pcall(b.SetScript, b, "OnShow", b.Hide) end
    end
    local scroll = _G.InboxScrollFrameScrollBar or (_G.InboxScrollFrame and _G.InboxScrollFrame.ScrollBar)
    if scroll then pcall(scroll.Hide, scroll) end
    if _G.OpenAllMail then pcall(_G.OpenAllMail.Hide, _G.OpenAllMail) end
end

---------------------------------------------------------------------------
-- Acting on mail
---------------------------------------------------------------------------
local function Loot(index)
    if AutoLootMailItem then AutoLootMailItem(index) end
end

local function Return(index)
    if ReturnInboxItem then ReturnInboxItem(index) end
end

---------------------------------------------------------------------------
-- Queued batch actions (Open Selected / Open All / Return Selected): only one AutoLootMailItem
-- can be in flight at a time, indices shift after each one resolves, and the bag can fill up
-- partway through, so this works off stable ids and re-reads the inbox between steps.
---------------------------------------------------------------------------
local queue = { kind = nil, ids = nil, running = false }

local function ById(id)
    for _, h in ipairs(ReadInbox()) do if h.id == id then return h end end
end

local function QueueStep()
    if not queue.running then return end
    local id = table.remove(queue.ids, 1)
    if not id then
        queue.running = false
        P.Print(queue.kind == "return" and "Done returning selected mail." or "Done opening mail.")
        P.Fire("refresh")
        return
    end
    local h = ById(id)
    if not h then
        C_Timer.After(0.15, QueueStep)   -- already gone (taken elsewhere, expired); move on
        return
    end
    if queue.kind == "open" then
        local free = P.FreeBagSlots()
        local reserve = P.db.freeBagSlots or 0
        -- a conservative one-slot check per mail; mail with several attachments may need more
        if h.itemCount > 0 and (free - 1) < reserve then
            queue.running = false
            P.Print(("Stopped: only %d bag slot(s) free. Make room and run it again."):format(free))
            P.Fire("refresh")
            return
        end
        Loot(h.index)
    else
        Return(h.index)
    end
    C_Timer.After(0.2, QueueStep)
end

local function StartQueue(kind, ids)
    if #ids == 0 then P.Print("Nothing to do.") return end
    queue.kind, queue.ids, queue.running = kind, ids, true
    QueueStep()
end

local function SelectedIDs()
    local ids = {}
    for id in pairs(checked) do ids[#ids + 1] = id end
    return ids
end

---------------------------------------------------------------------------
-- The window
---------------------------------------------------------------------------
local function Label(parent, font, text)
    local fs = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlightSmall")
    if text then fs:SetText(text) end
    return fs
end

local function Money(copper)
    if not copper or copper == 0 then return "" end
    local g, s, c = math.floor(copper / 10000), math.floor((copper % 10000) / 100), copper % 100
    local parts = {}
    if g > 0 then parts[#parts + 1] = "|cffffd700" .. g .. "g|r" end
    if s > 0 then parts[#parts + 1] = "|cffc7c7cf" .. s .. "s|r" end
    if c > 0 and g == 0 then parts[#parts + 1] = "|cffeda55f" .. c .. "c|r" end
    return table.concat(parts, " ")
end

local entries = {}
local function Rebuild()
    entries = ReadInbox()
    -- forget checkboxes for mail that's no longer there
    local live = {}
    for _, h in ipairs(entries) do live[h.id] = true end
    for id in pairs(checked) do if not live[id] then checked[id] = nil end end
end

local function RowClick(self, button)
    local h = self.entry
    if not h then return end
    if IsShiftKeyDown() then
        Loot(h.index)
        P.Print("Took " .. (h.subject or "") .. ".")
    elseif IsControlKeyDown() then
        Return(h.index)
        P.Print("Returned mail to " .. tostring(h.sender) .. ".")
    else
        checked[h.id] = not checked[h.id] or nil
        frame.Refresh()
    end
end

local function CheckClick(self)
    local h = self:GetParent().entry
    if not h then return end
    if IsShiftKeyDown() and lastClickedRow then
        local a, b = lastClickedRow, h.index
        if a > b then a, b = b, a end
        for _, e in ipairs(entries) do
            if e.index >= a and e.index <= b then checked[e.id] = true end
        end
    elseif IsControlKeyDown() then
        for _, e in ipairs(entries) do
            if e.sender == h.sender then checked[e.id] = true end
        end
    else
        checked[h.id] = self:GetChecked() or nil
    end
    lastClickedRow = h.index
    frame.Refresh()
end

local function BuildWindow()
    local f = CreateFrame("Frame", "PostageInboxFrame", UIParent, "BackdropTemplate")
    f:SetSize(560, 470)
    f:SetPoint("TOPLEFT", MailFrame or UIParent, "TOPLEFT", 24, -60)
    f:SetFrameStrata("HIGH")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local _, _, _, x, y = self:GetPoint()
        P.db.posX, P.db.posY = x, y
    end)
    if f.SetBackdrop then
        f:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
        f:SetBackdropColor(0.05, 0.05, 0.07, 0.96)
        f:SetBackdropBorderColor(0.7, 0.55, 0, 0.8)
    end

    f.title = Label(f, "GameFontNormalLarge", "|cffffcc00Postage|r")
    f.title:SetPoint("TOPLEFT", 12, -10)
    f.count = Label(f, "GameFontHighlightSmall")
    f.count:SetPoint("TOPLEFT", 12, -32)

    local function Btn(text, width, onClick)
        local b = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        b:SetSize(width, 22)
        b:SetText(text)
        b:SetScript("OnClick", onClick)
        return b
    end

    f.openSel = Btn("Open selected", 110, function()
        StartQueue("open", SelectedIDs())
    end)
    f.openSel:SetPoint("TOPLEFT", 12, -404)
    f.returnSel = Btn("Return selected", 118, function()
        StartQueue("return", SelectedIDs())
    end)
    f.returnSel:SetPoint("LEFT", f.openSel, "RIGHT", 4, 0)
    f.openAll = Btn("Open all", 90, function()
        local ids = {}
        for _, h in ipairs(entries) do if h.itemCount > 0 or h.money > 0 then ids[#ids + 1] = h.id end end
        if P.db.confirmOpenAll and not IsShiftKeyDown() then
            StaticPopup_Show("POSTAGE_OPEN_ALL", tostring(#ids))
        else
            StartQueue("open", ids)
        end
    end)
    f.openAll:SetPoint("LEFT", f.returnSel, "RIGHT", 4, 0)
    local hint = Label(f, "GameFontDisableSmall", "Shift-click a row: take.  Ctrl-click: return.  Shift-click Open All: skip the confirm.")
    hint:SetPoint("TOPLEFT", 12, -428)
    hint:SetWidth(536)
    hint:SetJustifyH("LEFT")

    -- header
    local header = CreateFrame("Frame", nil, f)
    header:SetPoint("TOPLEFT", 12, -52)
    header:SetSize(536, 16)
    local hbg = header:CreateTexture(nil, "BACKGROUND")
    hbg:SetAllPoints()
    hbg:SetColorTexture(1, 0.8, 0, 0.08)

    f.rows = {}
    for i = 1, ROWS do
        local r = CreateFrame("Button", nil, f)
        r:SetSize(536, ROW_H)
        r:SetPoint("TOPLEFT", 12, -70 - (i - 1) * ROW_H)
        r:RegisterForClicks("LeftButtonUp")
        r:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
        r.warn = r:CreateTexture(nil, "OVERLAY")
        r.warn:SetSize(14, 14)
        r.warn:SetPoint("LEFT", 2, 0)
        r.warn:SetColorTexture(1, 0.4, 0, 0.9)
        r.warn:Hide()

        r.check = CreateFrame("CheckButton", nil, r, "UICheckButtonTemplate")
        r.check:SetSize(22, 22)
        r.check:SetPoint("LEFT", 18, 0)
        if r.check.text then r.check.text:SetText("") end
        r.check:SetScript("OnClick", CheckClick)

        r.sender = Label(r, "GameFontHighlightSmall")
        r.sender:SetPoint("TOPLEFT", 44, -2)
        r.sender:SetWidth(200)
        r.sender:SetJustifyH("LEFT")

        r.subject = Label(r, "GameFontNormalSmall")
        r.subject:SetPoint("TOPLEFT", 44, -16)
        r.subject:SetWidth(300)
        r.subject:SetJustifyH("LEFT")

        r.money = Label(r, "GameFontHighlightSmall")
        r.money:SetPoint("TOPRIGHT", -60, -2)
        r.money:SetJustifyH("RIGHT")

        r.meta = Label(r, "GameFontDisableSmall")
        r.meta:SetPoint("TOPRIGHT", -4, -16)
        r.meta:SetJustifyH("RIGHT")

        r:SetScript("OnClick", RowClick)
        r:SetScript("OnEnter", function(self)
            local h = self.entry
            if not h then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(h.subject or "", 1, 1, 1)
            GameTooltip:AddLine("From " .. tostring(h.sender), 0.8, 0.8, 0.8)
            if h.daysLeft then GameTooltip:AddLine(("Expires in about %.1f day(s)"):format(h.daysLeft), 0.8, 0.8, 0.8) end
            if h.cod and h.cod > 0 then GameTooltip:AddLine("COD: " .. Money(h.cod), 1, 0.5, 0.5) end
            GameTooltip:Show()
        end)
        r:SetScript("OnLeave", function() GameTooltip:Hide() end)
        r:Hide()
        f.rows[i] = r
    end

    function f.Refresh()
        Rebuild()
        local n = 0
        for _ in pairs(checked) do n = n + 1 end
        f.count:SetText(("%d mail   |cff888888%d selected|r"):format(#entries, n))
        for i, r in ipairs(f.rows) do
            local h = entries[i]
            r.entry = h
            if h then
                r.sender:SetText(h.sender)
                local subj = h.subject or ""
                if h.auction then subj = "|cff33ccff[AH]|r " .. subj end
                r.subject:SetText(subj)
                r.money:SetText(Money(h.money))
                local bits = {}
                if h.itemCount > 0 then bits[#bits + 1] = h.itemCount .. " item" .. (h.itemCount > 1 and "s" or "") end
                if h.cod > 0 then bits[#bits + 1] = "COD " .. Money(h.cod) end
                r.meta:SetText(table.concat(bits, "  "))
                r.check:SetChecked(checked[h.id] and true or false)
                local soon = type(h.daysLeft) == "number" and h.daysLeft <= 1 and (h.money > 0 or h.itemCount > 0)
                r.warn:SetShown(soon and true or false)
                r:Show()
            else
                r:Hide()
            end
        end
    end

    return f
end

StaticPopupDialogs["POSTAGE_OPEN_ALL"] = {
    text = "Open all %s mail with money or items attached?",
    button1 = YES, button2 = NO,
    OnAccept = function(_, data)
        local ids = {}
        for _, h in ipairs(entries) do if h.itemCount > 0 or h.money > 0 then ids[#ids + 1] = h.id end end
        StartQueue("open", ids)
    end,
    timeout = 0, whileDead = true, hideOnEscape = true,
}

P.AddHook("mailShow", function()
    if not frame then
        frame = BuildWindow()
        if P.db.posX then frame:ClearAllPoints() frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", P.db.posX, P.db.posY) end
    end
    HideBlizzardInbox()
    frame:Show()
    frame.Refresh()
end)

P.AddHook("mailClosed", function()
    if frame then frame:Hide() end
    checked = {}
    queue.running = false
end)

P.AddHook("refresh", function() if frame then frame.Refresh() end end)

local ev = CreateFrame("Frame")
pcall(ev.RegisterEvent, ev, "MAIL_INBOX_UPDATE")
ev:SetScript("OnEvent", P.Safe("Postage inbox", function()
    if frame and frame:IsShown() then frame.Refresh() end
end))
