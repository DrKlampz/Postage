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

P.WinLook.Setup({
    title = "Postage",
    syncDefault = false,
    media = "Interface\\AddOns\\Postage\\Media\\",
    db = function() return PostageDB end,
    windows = {
        { id = "mail", name = "Mailbox", global = "MailFrame", strip = "template", regions = true,
          hideGlobals = { "MailFrameInset" }, title = function(f) return f.TitleText or _G.MailFrameTitleText end,
          extra = MailExtra, apply = function(f, s, on) if P.ApplyMailLook then P.ApplyMailLook(on) end end },
        { id = "openmail", name = "Open mail", global = "OpenMailFrame", strip = "template", regions = true,
          hideGlobals = { "OpenMailFrameInset" }, title = function(f) return f.TitleText or _G.OpenMailFrameTitleText end,
          extra = PAPER_ONLY, apply = function(f, s, on) if P.ApplyMailLook then P.ApplyMailLook(on) end end },
        { id = "options", name = "Options window", global = "PostageOptionsFrame", strip = "backdrop" },
        { id = "menu", name = "Quick-send menu", global = "PostagePopupMenu", strip = "backdrop" },
    },
})
