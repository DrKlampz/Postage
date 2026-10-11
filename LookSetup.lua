local ADDON_NAME, P = ...
-- Window customization (see Look.lua). Opens with /postagelook.
if not P.WinLook then return end
P.WinLook.Setup({
    title = "Postage",
    slash = "postagelook",
    media = "Interface\\AddOns\\Postage\\Media\\",
    db = function() return PostageDB end,
    windows = {
        { id = "options", name = "Options window", global = "PostageOptionsFrame", strip = "backdrop" },
        { id = "menu", name = "Quick-send menu", global = "PostagePopupMenu", strip = "backdrop" },
    },
})
