local ADDON_NAME, P = ...
-- Window customization (see Look.lua). Opens from the minimap button (Alt-click).
if not P.WinLook then return end

local PAPER_NAMES = { original = "Original yellow paper", tint = "Plain, in your color", dark = "Dark paper", hidden = "No paper" }
local PAPER_ORDER = { "original", "tint", "dark", "hidden" }

-- the extra mailbox options: the letter paper, and the quick-attach tray
local function MailExtra()
    local defaults = {
        paper = "original", paperColor = { 0.10, 0.10, 0.13 }, paperAlpha = 1,
        tray = true, traySide = "right", trayCols = 3, traySize = 28, trayGap = 4,
        trayPanel = true, trayTitle = true, trayCounts = true, trayHideEmpty = false, trayAlpha = 0.96,
    }
    local quickRows = {}
    for i, q in ipairs(P.QUICK or {}) do
        defaults["q" .. i] = true
        quickRows[#quickRows + 1] = { key = "q" .. i, kind = "check", label = (q[1]:match("^([^:]+)") or q[1]) }
    end
    return {
        defaults = defaults,
        sections = {
            { id = "paper", title = "Letter paper", rows = {
                { key = "paper", kind = "cycle", label = "Paper", values = PAPER_ORDER, names = PAPER_NAMES },
                { key = "paperColor", kind = "color", label = "Paper color (for the plain paper)" },
                { key = "paperAlpha", kind = "slider", label = "Paper opacity", min = 0, max = 1, step = 0.05, fmt = "%.2f" },
            } },
            { id = "tray", title = "Quick-attach tray", rows = {
                { key = "tray", kind = "check", label = "Show the tray next to the Send Mail window" },
                { key = "traySide", kind = "cycle", label = "Where", values = { "right", "left", "below" },
                  names = { right = "Right of the window", left = "Left of the window", below = "Under the window" } },
                { key = "trayCols", kind = "slider", label = "Buttons per row (beside the window)", min = 1, max = 6, step = 1 },
                { key = "traySize", kind = "slider", label = "Button size", min = 20, max = 44, step = 1 },
                { key = "trayGap", kind = "slider", label = "Space between buttons", min = 0, max = 10, step = 1 },
                { key = "trayPanel", kind = "check", label = "Panel behind the buttons" },
                { key = "trayTitle", kind = "check", label = "Show the tray title" },
                { key = "trayCounts", kind = "check", label = "Show how many stacks each button will attach" },
                { key = "trayHideEmpty", kind = "check", label = "Hide buttons when you have nothing of that kind" },
                { key = "trayAlpha", kind = "slider", label = "Panel opacity", min = 0, max = 1, step = 0.05, fmt = "%.2f" },
            } },
            { id = "quick", title = "Which quick buttons to show", rows = quickRows },
        },
    }
end

local PAPER_ONLY = function()
    return {
        defaults = { paper = "original", paperColor = { 0.10, 0.10, 0.13 }, paperAlpha = 1 },
        sections = { MailExtra().sections[1] },
    }
end


-- every Postage setting, in the one options window
local function Options()
    local db = function() return P.db end
    local function bool(tbl, key, default)
        return function() local t = tbl() if default == false then return t[key] == true end return t[key] ~= false end,
               function(v) tbl()[key] = v end
    end
    local function chk(label, tbl, key, after, default)
        local g, st = bool(tbl, key, default)
        return { kind = "check", label = label, get = g, set = function(v) st(v) if after then after(v) end end }
    end
    local openAll = function() return P.db.openAll end
    local modules = function() return P.db.modules end
    local sizes = { "small", "normal", "large" }
    local sizeNames = { small = "Small", normal = "Medium", large = "Large" }
    return {
        sections = {
            { id = "openall", title = "Open All takes", open = true, rows = {
                chk("Auction sold (gold)", openAll, "ahSold"), chk("Auction won (items)", openAll, "ahWon"),
                chk("Auction expired", openAll, "ahExpired"), chk("Auction cancelled", openAll, "ahCancelled"),
                chk("Outbid (gold back)", openAll, "ahOutbid"), chk("Postmaster / NPC mail", openAll, "npc"),
                chk("Mail from players", openAll, "player"),
                { kind = "note", label = "COD mail is always skipped." },
            } },
            { id = "general", title = "General", open = true, rows = {
                { kind = "check", label = "Show the minimap button",
                  get = function() return P.db.minimap.show end,
                  set = function(v) P.db.minimap.show = v if P.UpdateMinimap then P.UpdateMinimap() end end },
                chk("Autocomplete names in the To: box", db, "autocomplete"),
                chk("Express: shift-click takes, ctrl-click returns, scroll pages, alt-click attaches", modules, "express"),
                chk("TradeBlock: decline trades and guild charters while the mailbox is open", modules, "tradeblock"),
                { kind = "slider", label = "Keep this many bag slots free when opening mail", min = 0, max = 20, step = 1,
                  get = function() return P.db.freeBagSlots or 0 end, set = function(v) P.db.freeBagSlots = v end },
                { kind = "cycle", label = "Size of the popup lists", values = sizes, names = sizeNames,
                  get = function() return P.db.look.menuSize or "normal" end,
                  set = function(v) P.db.look.menuSize = v if P.ApplyLook then P.ApplyLook() end end },
                chk("Dark Postage theme on the mailbox windows (a custom look in the Mailbox tab replaces it)", db, "skinMail",
                    function() if P.SkinMail then P.SkinMail() end end),
            } },
            { id = "send", title = "Send Mail", open = true, rows = {
                chk("Keep the recipient after sending (for several mails in a row)", db, "keepRecipient", function(v)
                    if P.Fire then P.Fire("options") end end, false),
                chk("Show the quick-attach tray beside the Send Mail window",
                    function() return P.WinLook.Get("mail") end, "tray", function() if P.LayoutTray then P.LayoutTray() end end),
                { kind = "note", label = "The tray's position, size, panel and which profession buttons it shows are in the Mailbox tab." },
            } },
        },
    }
end

P.WinLook.Setup({
    title = "Postage",
    syncDefault = false,
    options = Options,
    media = "Interface\\AddOns\\Postage\\Media\\",
    db = function() return PostageDB end,
    windows = {
        { id = "mail", name = "Mailbox", global = "MailFrame", strip = "template", regions = true,
          hideGlobals = { "MailFrameInset" }, title = function(f) return f.TitleText or _G.MailFrameTitleText end,
          extra = MailExtra, apply = function(f, s, on) if P.ApplyMailLook then P.ApplyMailLook(on) end end },
        { id = "openmail", name = "Open mail", global = "OpenMailFrame", strip = "template", regions = true,
          hideGlobals = { "OpenMailFrameInset" }, title = function(f) return f.TitleText or _G.OpenMailFrameTitleText end,
          extra = PAPER_ONLY, apply = function(f, s, on) if P.ApplyMailLook then P.ApplyMailLook(on) end end },
        { id = "menu", name = "Quick-send menu", global = "PostagePopupMenu", strip = "backdrop" },
    },
})
