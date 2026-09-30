-- Postage: a mailbox addon for WoW: Forever.
-- Everything Postage adds lives inside Blizzard's own mailbox: checkboxes
-- on the inbox rows, Open/Return/Open All buttons, a contact book on the To: box, and so on.
-- Core.lua holds settings, events, the slash command and shared helpers.
local ADDON_NAME, P = ...
P.name = ADDON_NAME

local function IsSecret(v) return issecretvalue ~= nil and issecretvalue(v) end
P.IsSecret = IsSecret
local function Trim(s) return (tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", "")) end
P.Trim = Trim

P.ICON = "Interface\\Icons\\INV_Letter_15"

local function Meta(field)
    local f = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
    if not f then return nil end
    local ok, v = pcall(f, ADDON_NAME, field)
    if ok then return v end
end

P.DEFAULTS = {
    modules = {
        select = true, openall = true, express = true, blackbook = true, donotwant = true,
        carboncopy = true, forward = true, quickattach = true, wire = true, tradeblock = true,
    },
    openAll = {
        ahSold = true, ahExpired = true, ahOutbid = true, ahWon = true, ahCancelled = true,
        npc = true, player = true,
    },
    freeBagSlots = 0,
    minimap = { show = true, angle = 215 },
    autocomplete = true,
    keepRecipient = false,  -- keep the To: name after sending, for sending several mails
    recent = {},     -- recently mailed names, newest first
    alts = {},       -- ["Name-Realm"] = { name, realm, faction, class }
}

local function Merge(dst, src)
    for k, v in pairs(src) do
        if type(v) == "table" then
            if type(dst[k]) ~= "table" then dst[k] = {} end
            if next(v) ~= nil and #v == 0 then Merge(dst[k], v) end
        elseif dst[k] == nil then
            dst[k] = v
        end
    end
    return dst
end

function P.Print(msg) print("|cffffcc00Postage:|r " .. tostring(msg)) end
local Print = P.Print

local reported = {}
function P.ReportError(what, err)
    if reported[what] then return end
    reported[what] = true
    Print(("|cffff5555Something went wrong in %s:|r %s"):format(what, tostring(err)))
end

function P.Safe(what, fn)
    return function(...)
        local ok, err = pcall(fn, ...)
        if not ok then P.ReportError(what, err) end
    end
end

function P.On(mod) return P.db ~= nil and P.db.modules[mod] ~= false end

-- tiny event bus between the modules
local hooks = {}
function P.AddHook(name, fn)
    hooks[name] = hooks[name] or {}
    table.insert(hooks[name], fn)
end
function P.Fire(name, ...)
    for _, fn in ipairs(hooks[name] or {}) do
        local ok, err = pcall(fn, ...)
        if not ok then P.ReportError(name, err) end
    end
end

---------------------------------------------------------------------------
-- Shared helpers
---------------------------------------------------------------------------
function P.MoneyText(copper)
    copper = tonumber(copper) or 0
    local g, s, c = math.floor(copper / 10000), math.floor((copper % 10000) / 100), copper % 100
    local parts = {}
    if g > 0 then parts[#parts + 1] = "|cffffd700" .. g .. "g|r" end
    if s > 0 then parts[#parts + 1] = "|cffc7c7cf" .. s .. "s|r" end
    if c > 0 or #parts == 0 then parts[#parts + 1] = "|cffeda55f" .. c .. "c|r" end
    return table.concat(parts, " ")
end

-- Auction house mail subjects. These are long-standing FrameXML strings; the English text is
-- only a fallback if a global is missing.
local function G(name, fallback)
    local v = _G[name]
    if type(v) == "string" then return (v:gsub("%%s.*$", "")) end
    return fallback
end
P.AH = {
    ahSold      = G("AUCTION_SOLD_MAIL_SUBJECT", "Auction successful: "),
    ahExpired   = G("AUCTION_EXPIRED_MAIL_SUBJECT", "Auction expired: "),
    ahOutbid    = G("AUCTION_OUTBID_MAIL_SUBJECT", "Outbid on "),
    ahWon       = G("AUCTION_WON_MAIL_SUBJECT", "Auction won: "),
    ahCancelled = G("AUCTION_REMOVED_MAIL_SUBJECT", "Auction cancelled: "),
}

-- Everything about one mail. Returns nil if the index is empty or unreadable.
function P.Header(i)
    if not GetInboxHeaderInfo then return nil end
    local _, _, sender, subject, money, cod, daysLeft, itemCount, wasRead, wasReturned,
          textCreated, canReply, isGM = GetInboxHeaderInfo(i)
    if sender == nil and subject == nil then return nil end
    if IsSecret(sender) or IsSecret(subject) then return nil end
    local h = {
        index = i, sender = sender or "", subject = subject or "", money = money or 0, cod = cod or 0,
        daysLeft = daysLeft, itemCount = itemCount or 0, wasRead = wasRead, wasReturned = wasReturned,
        textCreated = textCreated, canReply = canReply, isGM = isGM,
    }
    h.id = table.concat({ tostring(h.sender), tostring(h.subject), tostring(h.money), tostring(h.cod),
        tostring(h.itemCount), tostring(h.textCreated) }, "\1")
    for kind, prefix in pairs(P.AH) do
        if prefix ~= "" and h.subject:sub(1, #prefix) == prefix then h.auction = kind end
    end
    -- player mail can be replied to; the Postmaster and other NPC mail can't
    h.kind = h.auction or ((canReply and not isGM) and "player" or "npc")
    -- mail you can send back to its sender, versus mail that simply disappears when it expires
    h.returnable = (canReply and not wasReturned and not isGM and not h.auction) and true or false
    return h
end

function P.NumMail()
    if not GetInboxNumItems then return 0 end
    return GetInboxNumItems() or 0
end

function P.FreeBagSlots()
    local n = 0
    local getFree = (C_Container and C_Container.GetContainerNumFreeSlots) or GetContainerNumFreeSlots
    if not getFree then return 99 end
    for bag = 0, 4 do
        local free = getFree(bag)
        if type(free) == "number" then n = n + free end
    end
    return n
end

-- Your character's full name. On Forever, UnitName("player") returns a two-part name as two
-- values ("Busta", "Knute") in the slot retail uses for the realm, so join them back up.
-- Anything that is actually the realm is ignored.
function P.PlayerName()
    local first, second = UnitName("player")
    if type(first) ~= "string" or IsSecret(first) then return nil end
    if type(second) == "string" and second ~= "" and not IsSecret(second) and not first:find(" ", 1, true) then
        local realm = GetRealmName and GetRealmName()
        local nrealm = GetNormalizedRealmName and GetNormalizedRealmName()
        if second ~= realm and second ~= nrealm then return first .. " " .. second end
    end
    return first
end

function P.CharKey()
    local name = P.PlayerName()
    local realm = (GetNormalizedRealmName and GetNormalizedRealmName()) or (GetRealmName and GetRealmName()) or ""
    return (name or "?") .. "-" .. (realm or ""), name, realm
end

-- which Blizzard mailbox pieces exist on this client (used by /postage probe)
P.PROBE = {
    "MailFrame", "InboxFrame", "MailItem1", "MailItem1Button", "InboxPrevPageButton",
    "InboxNextPageButton", "OpenAllMail", "SendMailFrame", "SendMailNameEditBox",
    "SendMailSubjectEditBox", "SendMailBodyEditBox", "SendMailMoney", "SendMailMailButton",
    "OpenMailFrame", "OpenMailReplyButton",
}

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
local mailReady = false
local function MailOpened()
    if not mailReady then
        mailReady = true
        P.Fire("mailInit")      -- modules attach themselves to the Blizzard mail frames once
    end
    P.Fire("mailShow")
end
P.MailOpened = MailOpened

local atMailbox = false
function P.AtMailbox() return atMailbox end

local f = CreateFrame("Frame")
for _, ev in ipairs({ "ADDON_LOADED", "PLAYER_LOGIN", "MAIL_SHOW", "MAIL_CLOSED", "MAIL_INBOX_UPDATE",
                      "MAIL_SEND_SUCCESS", "TRADE_SHOW", "PETITION_SHOW" }) do
    pcall(f.RegisterEvent, f, ev)
end

f:SetScript("OnEvent", P.Safe("Postage", function(_, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 ~= ADDON_NAME then return end
        PostageDB = Merge(PostageDB or {}, P.DEFAULTS)
        P.db = PostageDB
    elseif event == "PLAYER_LOGIN" then
        P.version = Meta("Version") or "dev"
        local key, name, realm = P.CharKey()
        local _, class = UnitClass("player")
        -- earlier versions saved this character under its first name only; drop that entry
        local first = UnitName("player")
        if type(first) == "string" and first ~= name then P.db.alts[first .. "-" .. (realm or "")] = nil end
        P.db.alts[key] = { name = name, realm = realm, faction = UnitFactionGroup and UnitFactionGroup("player"), class = class }
        P.Fire("login")
        Print(("v%s loaded. Open a mailbox, or type /postage for options."):format(tostring(P.version)))
    elseif event == "MAIL_SHOW" then
        atMailbox = true
        MailOpened()
    elseif event == "MAIL_CLOSED" then
        atMailbox = false
        P.Fire("mailClosed")
    elseif event == "MAIL_INBOX_UPDATE" then
        P.Fire("inboxUpdate")
    elseif event == "MAIL_SEND_SUCCESS" then
        P.Fire("sendSuccess")
    elseif event == "TRADE_SHOW" then
        if atMailbox and P.On("tradeblock") then
            if CancelTrade then CancelTrade() end
            Print("Declined a trade while the mailbox was open.")
        end
    elseif event == "PETITION_SHOW" then
        if atMailbox and P.On("tradeblock") then
            if ClosePetition then ClosePetition() end
            Print("Declined a guild charter while the mailbox was open.")
        end
    end
end))

---------------------------------------------------------------------------
-- Slash command
---------------------------------------------------------------------------
SLASH_POSTAGE1 = "/postage"
SlashCmdList.POSTAGE = P.Safe("Postage command", function(msg)
    local cmd, rest = (msg or ""):match("^(%S*)%s*(.-)$")
    cmd = (cmd or ""):lower()
    if cmd == "" or cmd == "options" or cmd == "config" then
        if P.ToggleOptions then P.ToggleOptions() end
    elseif cmd == "help" then
        Print("/postage - options window")
        Print("/postage minimap - show or hide the minimap button")
        Print("/postage freeslots <n> - keep n bag slots free when opening mail")
        Print("/postage probe - check which mailbox parts Postage found on this client")
        Print("In the inbox: shift-click a mail to take it, ctrl-click to return it, scroll to change pages.")
        Print("In your bags (with Send Mail open): alt-click an item to attach it, shift-alt-click to attach all of it.")
    elseif cmd == "minimap" then
        P.db.minimap.show = not P.db.minimap.show
        if P.UpdateMinimap then P.UpdateMinimap() end
        Print("Minimap button " .. (P.db.minimap.show and "shown." or "hidden."))
    elseif cmd == "freeslots" then
        local n = tonumber(rest)
        if not n or n < 0 then
            Print("Usage: /postage freeslots <number>")
        else
            P.db.freeBagSlots = math.floor(n)
            Print(("Will keep %d bag slot(s) free when opening mail."):format(P.db.freeBagSlots))
        end
    elseif cmd == "probe" then
        local found, missing = {}, {}
        for _, n in ipairs(P.PROBE) do
            if _G[n] then found[#found + 1] = n else missing[#missing + 1] = n end
        end
        Print(("Found %d of %d mailbox parts."):format(#found, #P.PROBE))
        if #missing > 0 then Print("|cffff8844Missing:|r " .. table.concat(missing, ", ")) end
        Print(("Mail in inbox: %d   free bag slots: %d"):format(P.NumMail(), P.FreeBagSlots()))
        if P.PendingSales then
            local total, list = P.PendingSales()
            Print(("Pending auction sales: %d (%s)"):format(#list, P.MoneyText(total)))
        end
        if P.PageButtons then
            local prev, nxt = P.PageButtons()
            Print(("Page buttons: %s   InboxFrame_Update: %s   row index: %s   page number: %s"):format(
                P.PageButtonsFound(), type(InboxFrame_Update) == "function" and "yes" or "no",
                (_G.MailItem1Button and type(_G.MailItem1Button.index) == "number") and "yes" or "no",
                (_G.InboxFrame and type(_G.InboxFrame.pageNum) == "number") and "yes" or "no"))
        end
    else
        Print("Unknown command. Type /postage help.")
    end
end)
