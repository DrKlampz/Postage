local ADDON_NAME, P = ...
-- Window customization (see Look.lua). Opens from the minimap button (Alt-click).
if not P.WinLook then return end
P.WinLook.Setup({
    title = "Postage",
    media = "Interface\\AddOns\\Postage\\Media\\",
    db = function() return PostageDB end,
    windows = {
        { id = "options", name = "Options window", global = "PostageOptionsFrame", strip = "backdrop" },
        { id = "menu", name = "Quick-send menu", global = "PostagePopupMenu", strip = "backdrop" },
    },
})
