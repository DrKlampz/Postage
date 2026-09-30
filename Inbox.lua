-- Postage inbox: everything here is attached to Blizzard's own inbox rows (MailItem1..7).
--   Select     - a checkbox on every row, plus Open and Return buttons for the checked mail
--   Open All   - opens everything of the kinds you pick, skipping COD, and totals the gold
--   Express    - shift-click a row to take it, ctrl-click to return it, mouse wheel to page
--   DoNotWant  - how long each mail has left, red if it will be deleted, yellow if it returns
local ADDON_NAME, P = ...
local ROWS = 7
local checked = {}        -- mail id -> true (ids survive page changes and index shifts)
local lastClicked = nil   -- mail index of the last checkbox click, for shift ranges
local rows = {}
local buttons = {}

local function Btn(i) return _G["MailItem" .. i .. "Button"] end

-- the mail index a row is showing right now
local function RowIndex(i)
    local b = Btn(i)
    if b and type(b.index) == "number" then return b.index end
    local page = (InboxFrame and InboxFrame.pageNum) or 1
    return (page - 1) * ROWS + i
end

local function AllHeaders()
    local out = {}
    for i = 1, P.NumMail() do
        local h = P.Header(i)
        if h then out[#out + 1] = h end
    end
    return out
end

---------------------------------------------------------------------------
-- The work queue: one mail at a time. Taking or returning a mail is asynchronous and shifts
-- every index after it, so each step looks its mail up again by id and waits for the inbox
-- to change before moving on.
---------------------------------------------------------------------------
local Q = { running = false }
P.Queue = Q

local function Finish(msg)
    Q.running = false
    local gained = (GetMoney and Q.money0) and (GetMoney() - Q.money0) or 0
    local parts = { msg }
    if gained > 0 then parts[#parts + 1] = "Collected " .. P.MoneyText(gained) .. "." end
    if Q.skippedCOD > 0 then parts[#parts + 1] = Q.skippedCOD .. " COD mail skipped (open those yourself)." end
    if Q.skippedOther > 0 then parts[#parts + 1] = Q.skippedOther .. " couldn't be returned (NPC, auction or already-returned mail)." end
    P.Print(table.concat(parts, " "))
    P.Fire("queueDone")
    if P.RefreshInbox then P.RefreshInbox() end
end

local function FindById(id)
    for i = 1, P.NumMail() do
        local h = P.Header(i)
        if h and h.id == id then return h end
    end
end

local Step
local function WaitFor(id, count, tries)
    if not Q.running then return end
    local gone = not FindById(id)
    if gone or P.NumMail() ~= count or tries >= 20 then
        C_Timer.After(0.1, Step)
    else
        C_Timer.After(0.1, function() WaitFor(id, count, tries + 1) end)
    end
end

Step = function()
    if not Q.running then return end
    local id = table.remove(Q.ids, 1)
    if not id then
        Finish(Q.kind == "return" and "Done returning mail." or "Done opening mail.")
        return
    end
    local h = FindById(id)
    if not h then Step() return end                  -- already gone
    checked[id] = nil
    if Q.kind == "open" then
        if h.cod > 0 then Q.skippedCOD = Q.skippedCOD + 1 Step() return end
        if h.money == 0 and h.itemCount == 0 then Step() return end
        if h.itemCount > 0 and P.FreeBagSlots() - h.itemCount < (P.db.freeBagSlots or 0) then
            Q.ids = {}
            Finish(("Stopped: your bags are full (keeping %d slot(s) free)."):format(P.db.freeBagSlots or 0))
            return
        end
        local count = P.NumMail()
        if AutoLootMailItem then AutoLootMailItem(h.index) end
        WaitFor(id, count, 0)
    else
        if not h.returnable then Q.skippedOther = Q.skippedOther + 1 Step() return end
        local count = P.NumMail()
        if ReturnInboxItem then ReturnInboxItem(h.index) end
        WaitFor(id, count, 0)
    end
end

function Q.Start(kind, ids)
    if Q.running then P.Print("Already working on it.") return end
    if #ids == 0 then P.Print("Nothing to do.") return end
    Q.kind, Q.ids, Q.running = kind, ids, true
    Q.skippedCOD, Q.skippedOther = 0, 0
    Q.money0 = GetMoney and GetMoney() or 0
    Step()
end

function Q.Stop()
    if Q.running then Q.ids = {} Q.running = false end
end

---------------------------------------------------------------------------
-- Open All
---------------------------------------------------------------------------
function P.OpenAllIDs()
    local ids, want = {}, P.db.openAll
    for _, h in ipairs(AllHeaders()) do
        -- COD mail goes in too: the queue skips it and says how many it skipped
        if (h.money > 0 or h.itemCount > 0) and want[h.kind] ~= false then
            ids[#ids + 1] = h.id
        end
    end
    return ids
end

function P.OpenAll() Q.Start("open", P.OpenAllIDs()) end

local function CheckedIDs()
    local ids = {}
    for _, h in ipairs(AllHeaders()) do
        if checked[h.id] then ids[#ids + 1] = h.id end
    end
    return ids
end

---------------------------------------------------------------------------
-- Drawing the rows
---------------------------------------------------------------------------
local function CountChecked()
    local n = 0
    for _ in pairs(checked) do n = n + 1 end
    return n
end

local function UpdateButtons()
    local n = CountChecked()
    if buttons.open then
        buttons.open:SetText(n > 0 and ("Open (" .. n .. ")") or "Open")
        buttons.open:SetShown(P.On("select"))
        buttons.ret:SetText(n > 0 and ("Return (" .. n .. ")") or "Return")
        buttons.ret:SetShown(P.On("select"))
    end
    if buttons.all then buttons.all:SetShown(P.On("openall")) end
    if _G.OpenAllMail and P.On("openall") then pcall(_G.OpenAllMail.Hide, _G.OpenAllMail) end
end

function P.RefreshInbox()
    -- forget checks for mail that is gone
    local live = {}
    for _, h in ipairs(AllHeaders()) do live[h.id] = true end
    for id in pairs(checked) do if not live[id] then checked[id] = nil end end

    for i = 1, ROWS do
        local r = rows[i]
        if r then
            local b = Btn(i)
            local h = P.Header(RowIndex(i))
            local visible = h and (not b or b:IsShown())
            r.check:SetShown(visible and P.On("select") and true or false)
            if visible then
                r.check:SetChecked(checked[h.id] and true or false)
                r.check.mailID = h.id
                r.check.mailIndex = h.index
            end
            if visible and P.On("donotwant") and type(h.daysLeft) == "number" then
                local d = h.daysLeft
                local txt = d < 1 and ("%dh"):format(math.max(0, math.floor(d * 24))) or ("%dd"):format(math.floor(d))
                r.expiry:SetText((h.returnable and "|cffffd100" or "|cffff5555") .. txt .. "|r")
                r.expiry:Show()
            else
                r.expiry:Hide()
            end
        end
    end
    UpdateButtons()
end

local function CheckClick(self)
    local id, index = self.mailID, self.mailIndex
    if not id then return end
    local all = AllHeaders()
    if IsShiftKeyDown() and lastClicked then
        local a, b = math.min(lastClicked, index), math.max(lastClicked, index)
        for _, h in ipairs(all) do if h.index >= a and h.index <= b then checked[h.id] = true end end
    elseif IsControlKeyDown() then
        local sender
        for _, h in ipairs(all) do if h.id == id then sender = h.sender end end
        for _, h in ipairs(all) do if h.sender == sender then checked[h.id] = true end end
    else
        checked[id] = self:GetChecked() and true or nil
    end
    lastClicked = index
    P.RefreshInbox()
end

---------------------------------------------------------------------------
-- Express: modified clicks on the inbox rows
---------------------------------------------------------------------------
local handledAt = -1
local function Express(index)
    if not P.On("express") then return false end
    local h = P.Header(index)
    if not h then return false end
    if IsShiftKeyDown() then
        if h.cod > 0 then P.Print("That mail is COD. Open it to pay.") return true end
        if h.itemCount > 0 and P.FreeBagSlots() < h.itemCount then P.Print("Not enough bag space.") return true end
        if AutoLootMailItem then AutoLootMailItem(index) end
        return true
    elseif IsControlKeyDown() then
        if not h.returnable then P.Print("That mail can't be returned.") return true end
        if ReturnInboxItem then ReturnInboxItem(index) end
        P.Print("Returned mail to " .. h.sender .. ".")
        return true
    end
    return false
end

local function HookExpress()
    -- Blizzard's rows call InboxFrame_OnModifiedClick for modified clicks. Wrap it so shift/ctrl
    -- take or return the mail, and everything else falls through to Blizzard.
    if type(InboxFrame_OnModifiedClick) == "function" then
        local orig = InboxFrame_OnModifiedClick
        InboxFrame_OnModifiedClick = function(self, index, ...)
            index = index or (self and self.index)
            if index and Express(index) then handledAt = GetTime() return end
            return orig(self, index, ...)
        end
    end
    -- If the rows bound the original function directly, catch the click here instead.
    for i = 1, ROWS do
        local b = Btn(i)
        if b then
            b:HookScript("OnClick", function(self)
                if GetTime() == handledAt then return end
                if IsShiftKeyDown() or IsControlKeyDown() then
                    if Express(self.index or RowIndex(i)) then handledAt = GetTime() end
                end
            end)
        end
    end
    -- mouse wheel pages through the inbox
    local inbox = _G.InboxFrame
    if inbox then
        inbox:EnableMouseWheel(true)
        inbox:HookScript("OnMouseWheel", function(_, delta)
            if not P.On("express") then return end
            local btn = delta > 0 and _G.InboxPrevPageButton or _G.InboxNextPageButton
            if btn and btn:IsEnabled() then
                btn:Click()
            elseif delta > 0 and InboxPrevPage then pcall(InboxPrevPage)
            elseif delta < 0 and InboxNextPage then pcall(InboxNextPage) end
        end)
    end
end

---------------------------------------------------------------------------
-- Building it into the Blizzard inbox (once, the first time the mailbox opens)
---------------------------------------------------------------------------
local function MakeButton(parent, text, width, onClick, tip)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(width, 22)
    b:SetText(text)
    b:SetScript("OnClick", onClick)
    if tip then
        b:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(tip, 1, 1, 1, 1, true)
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end
    return b
end

local function Build()
    local inbox = _G.InboxFrame
    if not inbox then P.Print("Couldn't find the inbox on this client, so inbox features are off. /postage probe shows details.") return end

    for i = 1, ROWS do
        local b = Btn(i)
        local holder = _G["MailItem" .. i] or (b and b:GetParent())
        if b and holder then
            local r = {}
            r.check = CreateFrame("CheckButton", "PostageSelect" .. i, holder, "UICheckButtonTemplate")
            r.check:SetSize(22, 22)
            r.check:SetPoint("RIGHT", b, "LEFT", -1, 0)
            if r.check.text then r.check.text:SetText("") end
            if r.check.Text then r.check.Text:SetText("") end
            r.check:SetScript("OnClick", CheckClick)
            r.check:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_LEFT")
                GameTooltip:SetText("Select", 1, 1, 1)
                GameTooltip:AddLine("Shift-click: select a range.  Ctrl-click: select everything from this sender.", 0.8, 0.8, 0.8, true)
                GameTooltip:Show()
            end)
            r.check:SetScript("OnLeave", function() GameTooltip:Hide() end)
            r.expiry = b:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
            r.expiry:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -1, 2)
            rows[i] = r
        end
    end

    local prev, nxt = _G.InboxPrevPageButton, _G.InboxNextPageButton
    buttons.open = MakeButton(inbox, "Open", 76, function() Q.Start("open", CheckedIDs()) end,
        "Take everything from the checked mail. COD mail is skipped.")
    buttons.ret = MakeButton(inbox, "Return", 76, function() Q.Start("return", CheckedIDs()) end,
        "Send the checked mail back to whoever sent it.")
    buttons.all = MakeButton(inbox, "Open All", 80, function(self, btn)
        if btn == "RightButton" then
            if P.ToggleOptions then P.ToggleOptions(self) end
        elseif IsShiftKeyDown() then
            Q.Stop() P.Print("Stopped.")
        else
            P.OpenAll()
        end
    end, "Open every mail with gold or items attached, of the kinds ticked in the options. COD is always skipped.\nRight-click: choose which kinds.  Shift-click: stop.")
    buttons.all:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    if prev and nxt then
        buttons.open:SetPoint("LEFT", prev, "RIGHT", 4, 0)
        buttons.ret:SetPoint("RIGHT", nxt, "LEFT", -4, 0)
    else
        buttons.open:SetPoint("BOTTOMLEFT", inbox, "BOTTOMLEFT", 40, 90)
        buttons.ret:SetPoint("LEFT", buttons.open, "RIGHT", 4, 0)
    end
    local blizzAll = _G.OpenAllMail
    if blizzAll then
        buttons.all:SetPoint("CENTER", blizzAll, "CENTER", 0, 0)
    elseif prev and nxt then
        buttons.all:SetPoint("LEFT", buttons.open, "RIGHT", 4, 0)
    else
        buttons.all:SetPoint("LEFT", buttons.ret, "RIGHT", 4, 0)
    end

    HookExpress()
    if type(InboxFrame_Update) == "function" then hooksecurefunc("InboxFrame_Update", P.RefreshInbox) end
    P.RefreshInbox()
end

P.AddHook("mailInit", Build)
P.AddHook("mailShow", function() P.RefreshInbox() end)
P.AddHook("inboxUpdate", function() P.RefreshInbox() end)
P.AddHook("options", function() P.RefreshInbox() end)
P.AddHook("mailClosed", function()
    Q.Stop()
    checked = {}
    lastClicked = nil
end)
