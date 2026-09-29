-- Postage: a Postal-style mailbox addon for WoW: Forever.
-- Core.lua holds settings, the slash command, and two small standalone modules (TradeBlock and
-- Wire). The main event is Inbox.lua, which replaces the default inbox list.
local ADDON_NAME, P = ...
P.name = ADDON_NAME

local function IsSecret(v) return issecretvalue ~= nil and issecretvalue(v) end
P.IsSecret = IsSecret

local function Trim(s) return (tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", "")) end
P.Trim = Trim

P.DEFAULTS = {
    -- Select / Express
    freeBagSlots     = 0,      -- always leave this many bag slots open when opening mail
    confirmOpenAll   = true,
    -- DoNotWant
    warnReturn       = true,   -- flag mail that will be returned to sender soon
    warnDelete       = true,   -- flag mail that will just vanish (no return address) soon
    -- Wire
    wireEnabled      = true,
    -- TradeBlock
    tradeBlock       = true,
    -- window position
    posX = nil, posY = nil,
}

local function ApplyDefaults(t)
    for k, v in pairs(P.DEFAULTS) do
        if t[k] == nil then t[k] = v end
    end
    return t
end

P.db = nil

local function Print(msg) print("|cffffcc00Postage:|r " .. msg) end
P.Print = Print

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

---------------------------------------------------------------------------
-- A tiny event dispatcher other modules attach to.
---------------------------------------------------------------------------
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
-- Mail-related helpers shared by Inbox.lua
---------------------------------------------------------------------------
-- The known system subjects for auction house mail, so "Open All" can filter by type. Every one
-- of these is a stable, decades-old FrameXML global string; the literal English text is only a
-- fallback for the rare client where the global itself is missing.
local function G(name, fallback) return (_G[name]) or fallback end
P.AH_SUBJECTS = {
    sold     = G("AUCTION_SOLD_MAIL_SUBJECT", "Auction successful:"),
    expired  = G("AUCTION_EXPIRED_MAIL_SUBJECT", "Auction expired:"),
    outbid   = G("AUCTION_OUTBID_MAIL_SUBJECT", "Outbid on"),
    won      = G("AUCTION_WON_MAIL_SUBJECT", "Auction won:"),
    cancelled = G("AUCTION_REMOVED_MAIL_SUBJECT", "Auction cancelled:"),
}

function P.IsAuctionMail(subject)
    if type(subject) ~= "string" or IsSecret(subject) then return nil end
    for kind, prefix in pairs(P.AH_SUBJECTS) do
        if subject:find(prefix, 1, true) == 1 then return kind end
    end
    return nil
end

function P.FreeBagSlots()
    local n = 0
    if C_Container and C_Container.GetContainerNumFreeSlots then
        for bag = 0, 4 do
            local free = C_Container.GetContainerNumFreeSlots(bag)
            if type(free) == "number" then n = n + free end
        end
    elseif GetContainerNumFreeSlots then
        for bag = 0, 4 do
            local free = GetContainerNumFreeSlots(bag)
            if type(free) == "number" then n = n + free end
        end
    end
    return n
end

---------------------------------------------------------------------------
-- Wire: if the subject is empty when you send mail with gold attached, fill it in with the
-- amount so "how much did I just send" is never a mystery later.
---------------------------------------------------------------------------
local function HookWire()
    local subjectBox = _G.SendMailSubjectEditBox
    local moneyFrame = _G.SendMailMoney
    local sendButton = _G.SendMailMailButton
    if not (subjectBox and sendButton) then return end
    sendButton:HookScript("OnClick", function()
        if not (P.db and P.db.wireEnabled) then return end
        if Trim(subjectBox:GetText() or "") ~= "" then return end
        local copper = (moneyFrame and moneyFrame.GetAmount and moneyFrame:GetAmount()) or 0
        if type(copper) == "number" and copper > 0 and not IsSecret(copper) then
            -- Plain gold/silver/copper text: SendMail can't use GetCoinTextureString's texture
            -- markup as a subject line.
            local g, s, c = math.floor(copper / 10000), math.floor((copper % 10000) / 100), copper % 100
            local parts = {}
            if g > 0 then parts[#parts + 1] = g .. "g" end
            if s > 0 then parts[#parts + 1] = s .. "s" end
            if c > 0 or #parts == 0 then parts[#parts + 1] = c .. "c" end
            subjectBox:SetText(table.concat(parts, " "))
        end
    end)
end

---------------------------------------------------------------------------
-- TradeBlock: decline trade requests and guild-charter signature invites while the mailbox is
-- open, so a slow-typing mass-mail session doesn't get derailed by a popup.
---------------------------------------------------------------------------
local atMailbox = false
local function OnTradeShow()
    if not (P.db and P.db.tradeBlock and atMailbox) then return end
    if CancelTrade then CancelTrade() end
    Print("Declined a trade while the mailbox was open.")
end

local function OnPetitionShow()
    if not (P.db and P.db.tradeBlock and atMailbox) then return end
    if ClosePetition then ClosePetition() end
    Print("Declined a guild charter signature while the mailbox was open.")
end

---------------------------------------------------------------------------
-- Boot
---------------------------------------------------------------------------
local f = CreateFrame("Frame")
for _, ev in ipairs({ "ADDON_LOADED", "PLAYER_LOGIN", "MAIL_SHOW", "MAIL_CLOSED", "TRADE_SHOW", "PETITION_SHOW" }) do
    pcall(f.RegisterEvent, f, ev)
end

f:SetScript("OnEvent", P.Safe("Postage", function(_, event, addon)
    if event == "ADDON_LOADED" then
        if addon ~= ADDON_NAME then return end
        PostageDB = ApplyDefaults(PostageDB or {})
        P.db = PostageDB
    elseif event == "PLAYER_LOGIN" then
        HookWire()
        P.Fire("login")
    elseif event == "MAIL_SHOW" then
        atMailbox = true
        P.Fire("mailShow")
    elseif event == "MAIL_CLOSED" then
        atMailbox = false
        P.Fire("mailClosed")
    elseif event == "TRADE_SHOW" then
        OnTradeShow()
    elseif event == "PETITION_SHOW" then
        OnPetitionShow()
    end
end))

---------------------------------------------------------------------------
-- Slash command
---------------------------------------------------------------------------
SLASH_POSTAGE1 = "/postage"
SlashCmdList.POSTAGE = P.Safe("Postage command", function(msg)
    local cmd, rest = (msg or ""):match("^(%S*)%s*(.-)$")
    cmd = cmd:lower()
    if cmd == "" or cmd == "help" then
        Print("Commands:")
        Print("/postage tradeblock - toggle blocking trades/charters while at the mailbox")
        Print("/postage wire - toggle auto-filling the subject with the gold amount")
        Print("/postage freeslots <n> - always leave n bag slots open when opening mail")
    elseif cmd == "tradeblock" then
        P.db.tradeBlock = not P.db.tradeBlock
        Print("Trade blocking: " .. (P.db.tradeBlock and "|cff55ff55on|r" or "|cffff5555off|r"))
    elseif cmd == "wire" then
        P.db.wireEnabled = not P.db.wireEnabled
        Print("Auto-fill subject with gold amount: " .. (P.db.wireEnabled and "|cff55ff55on|r" or "|cffff5555off|r"))
    elseif cmd == "freeslots" then
        local n = tonumber(rest)
        if not n or n < 0 then
            Print("Usage: /postage freeslots <number>")
        else
            P.db.freeBagSlots = math.floor(n)
            Print(("Will always leave %d bag slot(s) open when opening mail."):format(P.db.freeBagSlots))
        end
    else
        Print("Unknown command. Type /postage help.")
    end
end)
