-- Postage menus: a small popup list, the options window, the Postage button on the mailbox,
-- and the minimap button.
local ADDON_NAME, P = ...

---------------------------------------------------------------------------
-- Look: themes and colors for Postage's own windows (the options window and the popup lists)
---------------------------------------------------------------------------
local PRESETS = {
    gold     = { name = "Dark gold",     bg = { 0.05, 0.05, 0.07 }, edge = { 0.80, 0.65, 0.10 }, accent = { 1.00, 0.80, 0.00 } },
    midnight = { name = "Midnight blue", bg = { 0.04, 0.06, 0.12 }, edge = { 0.35, 0.55, 0.95 }, accent = { 0.55, 0.75, 1.00 } },
    slate    = { name = "Slate",         bg = { 0.10, 0.10, 0.11 }, edge = { 0.60, 0.60, 0.65 }, accent = { 0.85, 0.85, 0.90 } },
    forest   = { name = "Forest",        bg = { 0.04, 0.09, 0.06 }, edge = { 0.45, 0.80, 0.40 }, accent = { 0.60, 0.95, 0.50 } },
    crimson  = { name = "Crimson",       bg = { 0.09, 0.04, 0.05 }, edge = { 0.85, 0.25, 0.30 }, accent = { 1.00, 0.45, 0.45 } },
    light    = { name = "Parchment",     bg = { 0.85, 0.82, 0.75 }, edge = { 0.45, 0.35, 0.20 }, accent = { 0.35, 0.20, 0.05 } },
}
local PRESET_ORDER = { "gold", "midnight", "slate", "forest", "crimson", "light" }
P.PRESETS = PRESETS
local SIZES = {
    small  = { name = "Small",  row = 16, w = 190, font = "GameFontHighlightSmall" },
    normal = { name = "Medium", row = 19, w = 220, font = "GameFontHighlight" },
    large  = { name = "Large",  row = 24, w = 270, font = "GameFontHighlightLarge" },
}
local SIZE_ORDER = { "small", "normal", "large" }

function P.Look()
    local L = (P.db and P.db.look) or {}
    local p = PRESETS[L.preset] or PRESETS.gold
    return {
        bg = L.bg or p.bg, edge = L.edge or p.edge, accent = L.accent or p.accent,
        alpha = tonumber(L.alpha) or 0.96, size = SIZES[L.menuSize] or SIZES.normal,
    }
end
local function Hex(c) return ("|cff%02x%02x%02x"):format(math.floor(c[1] * 255 + 0.5), math.floor(c[2] * 255 + 0.5), math.floor(c[3] * 255 + 0.5)) end
local function Style(frame, look)
    if not (frame and frame.SetBackdrop) then return end
    frame:SetBackdropColor(look.bg[1], look.bg[2], look.bg[3], look.alpha)
    frame:SetBackdropBorderColor(look.edge[1], look.edge[2], look.edge[3], 0.95)
end
local menu, opts
function P.ApplyLook()
    if P.SkinMail then P.SkinMail() end
    local look = P.Look()
    Style(menu, look)
    if opts then
        Style(opts, look)
        for _, fs in ipairs(opts.accents or {}) do fs:SetTextColor(look.accent[1], look.accent[2], look.accent[3]) end
        for _, sw in ipairs(opts.swatches or {}) do local c = sw.get(look) sw.tex:SetColorTexture(c[1], c[2], c[3], 1) end
        if opts.themeBtn then opts.themeBtn:SetText((PRESETS[(P.db.look or {}).preset] or PRESETS.gold).name) end
        if opts.sizeBtn then opts.sizeBtn:SetText(look.size.name) end
        do
            local dark = (look.bg[1] + look.bg[2] + look.bg[3]) / 3 > 0.5
            for _, fs in ipairs(opts.texts or {}) do if dark then fs:SetTextColor(0.1, 0.07, 0.02) else fs:SetTextColor(1, 1, 1) end end
        end
    end
end

---------------------------------------------------------------------------
-- Popup list. entries = { { text=, func=, title=true, note=true } ... }
---------------------------------------------------------------------------
local MAX_ROWS = 30

local function BuildMenu()
    menu = CreateFrame("Frame", "PostagePopupMenu", UIParent, "BackdropTemplate")
    menu:SetFrameStrata("FULLSCREEN_DIALOG")
    menu:SetClampedToScreen(true)
    menu:EnableMouse(true)
    if menu.SetBackdrop then
        menu:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    end
    menu.rows = {}
    for i = 1, MAX_ROWS do
        local r = CreateFrame("Button", nil, menu)
        r:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
        r.text = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        r.text:SetPoint("LEFT", 4, 0)
        r.text:SetPoint("RIGHT", -4, 0)
        r.text:SetJustifyH("LEFT")
        r:SetScript("OnClick", function(self)
            local e = self.entry
            menu:Hide()
            if e and e.func then e.func() end
        end)
        menu.rows[i] = r
    end
    tinsert(UISpecialFrames, "PostagePopupMenu")
end

function P.ShowMenu(anchor, entries)
    if not menu then BuildMenu() end
    if menu:IsShown() and menu.anchor == anchor then menu:Hide() return end
    local look = P.Look()
    local ROW_H, MENU_W = look.size.row, look.size.w
    P.ApplyLook()
    local n = math.min(#entries, MAX_ROWS)
    for i, r in ipairs(menu.rows) do
        local e = entries[i]
        r.entry = e
        r:SetSize(MENU_W - 12, ROW_H)
        r:ClearAllPoints()
        r:SetPoint("TOPLEFT", 6, -6 - (i - 1) * ROW_H)
        r.text:SetFontObject(look.size.font)
        if e and i <= n then
            if e.title then
                r.text:SetText(Hex(look.accent) .. e.text .. "|r")
                r:EnableMouse(false)
            elseif e.note then
                r.text:SetText("|cff888888" .. e.text .. "|r")
                r:EnableMouse(false)
            else
                r.text:SetText(e.text)
                r:EnableMouse(true)
            end
            r:Show()
        else
            r:Hide()
        end
    end
    menu:SetSize(MENU_W, n * ROW_H + 12)
    menu:ClearAllPoints()
    menu:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -2)
    menu.anchor = anchor
    menu:Show()
end

function P.HideMenu() if menu then menu:Hide() end end

---------------------------------------------------------------------------
-- Options window
---------------------------------------------------------------------------
-- Only the few things that change behavior are switches; every other feature is always on.
local MODULES = {
    { "express", "Express", "Shift-click a mail to take it, ctrl-click to return it, scroll to page. Alt-click a bag item to attach it." },
    { "tradeblock", "TradeBlock", "Declines trades and guild charters while the mailbox is open." },
}
local KINDS = {
    { "ahSold", "Auction sold (gold)" }, { "ahWon", "Auction won (items)" }, { "ahExpired", "Auction expired" },
    { "ahCancelled", "Auction cancelled" }, { "ahOutbid", "Outbid (gold back)" },
    { "npc", "Postmaster / NPC mail" }, { "player", "Mail from players" },
}

local function Check(parent, label, tip, get, set)
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetSize(22, 22)
    if cb.text then cb.text:SetText("") end
    if cb.Text then cb.Text:SetText("") end
    local fs = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    fs:SetPoint("LEFT", cb, "RIGHT", 2, 0)
    fs:SetText(label)
    cb.label = fs
    cb:SetHitRectInsets(0, -120, 0, 0)
    cb.get = get
    cb:SetScript("OnClick", function(self) set(self:GetChecked() and true or false) P.Fire("options") end)
    if tip then
        cb:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(label, 1, 1, 1)
            GameTooltip:AddLine(tip, 0.85, 0.85, 0.85, true)
            GameTooltip:Show()
        end)
        cb:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end
    return cb
end

-- the game's color picker, new and old style
local function PickColor(key, done)
    local look = P.Look()
    local cur = look[key]
    local r, g, b = cur[1], cur[2], cur[3]
    local CP = _G.ColorPickerFrame
    if not CP then return end
    local function Changed()
        local nr, ng, nb = CP:GetColorRGB()
        P.db.look[key] = { nr, ng, nb }
        done()
    end
    local function Cancel() P.db.look[key] = { r, g, b } done() end
    if CP.SetupColorPickerAndShow then
        CP:SetupColorPickerAndShow({ r = r, g = g, b = b, hasOpacity = false, swatchFunc = Changed, cancelFunc = Cancel })
    else
        CP.hasOpacity = false
        CP.opacityFunc = nil
        CP.func = Changed
        CP.cancelFunc = Cancel
        CP.previousValues = { r = r, g = g, b = b }
        CP:SetColorRGB(r, g, b)
        CP:Hide() CP:Show()
    end
end

local function BuildOptions()
    opts = CreateFrame("Frame", "PostageOptionsFrame", UIParent, "BackdropTemplate")
    opts:SetSize(410, 470)
    opts:SetPoint("CENTER")
    opts:SetFrameStrata("DIALOG")
    opts:SetToplevel(true)
    opts:SetMovable(true)
    opts:EnableMouse(true)
    opts:RegisterForDrag("LeftButton")
    opts:SetScript("OnDragStart", opts.StartMoving)
    opts:SetScript("OnDragStop", opts.StopMovingOrSizing)
    opts:SetClampedToScreen(true)
    if opts.SetBackdrop then
        opts:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    end
    tinsert(UISpecialFrames, "PostageOptionsFrame")
    opts.accents, opts.swatches, opts.checks, opts.texts = {}, {}, {}, {}

    local icon = opts:CreateTexture(nil, "ARTWORK")
    icon:SetSize(24, 24)
    icon:SetPoint("TOPLEFT", 12, -10)
    icon:SetTexture(P.ICON)
    local title = opts:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("LEFT", icon, "RIGHT", 6, 0)
    local ver = tostring(P.version or "")
    title:SetText("Postage" .. ((ver ~= "" and not ver:find("@")) and (" |cff888888v" .. ver .. "|r") or ""))
    local close = CreateFrame("Button", nil, opts, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", 0, 0)

    local function Header(text, y)
        local h = opts:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        h:SetPoint("TOPLEFT", 14, y)
        h:SetText(text)
        opts.accents[#opts.accents + 1] = h
        return h
    end
    local function AddCheck(cb, x, y)
        cb:SetPoint("TOPLEFT", x, y)
        opts.checks[#opts.checks + 1] = cb
        opts.texts[#opts.texts + 1] = cb.label
    end

    -- Open All takes: two columns
    Header("Open All takes", -44)
    for i, k in ipairs(KINDS) do
        local key = k[1]
        local cb = Check(opts, k[2], nil, function() return P.db.openAll[key] ~= false end,
            function(v) P.db.openAll[key] = v end)
        AddCheck(cb, i <= 4 and 14 or 210, -62 - ((i <= 4) and (i - 1) or (i - 5)) * 24)
    end
    local cod = opts:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    cod:SetPoint("TOPLEFT", 212, -62 - 3 * 24 - 4)
    cod:SetText("COD mail is always skipped.")

    -- General
    Header("General", -170)
    local mm = Check(opts, "Minimap button", nil, function() return P.db.minimap.show end,
        function(v) P.db.minimap.show = v if P.UpdateMinimap then P.UpdateMinimap() end end)
    AddCheck(mm, 14, -188)
    local ac = Check(opts, "Autocomplete names", "Finish names as you type in the To: box.",
        function() return P.db.autocomplete ~= false end, function(v) P.db.autocomplete = v end)
    AddCheck(ac, 14, -212)
    for i, m in ipairs(MODULES) do
        local key = m[1]
        local cb = Check(opts, m[2], m[3], function() return P.db.modules[key] ~= false end,
            function(v) P.db.modules[key] = v end)
        AddCheck(cb, 210, -188 - (i - 1) * 24)
    end
    local sk = Check(opts, "Apply the theme to the mailbox", "Paints the game's inbox, send mail and open mail windows with the theme below.",
        function() return P.db.skinMail ~= false end, function(v) P.db.skinMail = v P.SkinMail() end)
    AddCheck(sk, 210, -236)
    local fl = opts:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    fl:SetPoint("TOPLEFT", 16, -262)
    fl:SetText("Keep this many bag slots free when opening mail:")
    opts.texts[#opts.texts + 1] = fl
    local eb = CreateFrame("EditBox", nil, opts, "InputBoxTemplate")
    eb:SetSize(36, 20)
    eb:SetPoint("LEFT", fl, "RIGHT", 10, 0)
    eb:SetAutoFocus(false)
    eb:SetNumeric(true)
    eb:SetMaxLetters(2)
    local function save(self)
        P.db.freeBagSlots = tonumber(self:GetText()) or 0
        self:ClearFocus()
    end
    eb:SetScript("OnEnterPressed", save)
    eb:SetScript("OnEditFocusLost", save)
    eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    opts.free = eb

    -- Appearance
    Header("Appearance", -292)
    local function DropButton(x, y, w, label, makeEntries)
        local fs = opts:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        fs:SetPoint("TOPLEFT", x, y - 5)
        fs:SetText(label)
        opts.texts[#opts.texts + 1] = fs
        local b = CreateFrame("Button", nil, opts, "UIPanelButtonTemplate")
        b:SetSize(w, 22)
        b:SetPoint("TOPLEFT", x + 52, y)
        b:SetScript("OnClick", function(self) P.ShowMenu(self, makeEntries()) end)
        return b
    end
    opts.themeBtn = DropButton(14, -312, 120, "Theme", function()
        local e = {}
        for _, id in ipairs(PRESET_ORDER) do
            e[#e + 1] = { text = PRESETS[id].name, func = function()
                local L = P.db.look
                L.preset, L.bg, L.edge, L.accent = id, nil, nil, nil
                P.ApplyLook()
            end }
        end
        return e
    end)
    opts.sizeBtn = DropButton(210, -312, 100, "Lists", function()
        local e = {}
        for _, id in ipairs(SIZE_ORDER) do
            e[#e + 1] = { text = SIZES[id].name .. " text", func = function() P.db.look.menuSize = id P.ApplyLook() end }
        end
        return e
    end)
    local function Swatch(x, y, label, key)
        local sw = CreateFrame("Button", nil, opts)
        sw:SetSize(18, 18)
        sw:SetPoint("TOPLEFT", x, y)
        local edge = sw:CreateTexture(nil, "BACKGROUND")
        edge:SetAllPoints()
        edge:SetColorTexture(0, 0, 0, 1)
        sw.tex = sw:CreateTexture(nil, "ARTWORK")
        sw.tex:SetPoint("TOPLEFT", 1, -1) sw.tex:SetPoint("BOTTOMRIGHT", -1, 1)
        sw.get = function(look) return look[key] end
        local fs = opts:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        fs:SetPoint("LEFT", sw, "RIGHT", 6, 0)
        fs:SetText(label)
        opts.texts[#opts.texts + 1] = fs
        sw:SetScript("OnClick", function() PickColor(key, P.ApplyLook) end)
        opts.swatches[#opts.swatches + 1] = sw
    end
    Swatch(16, -346, "Background", "bg")
    Swatch(150, -346, "Border", "edge")
    Swatch(270, -346, "Headings", "accent")

    local sl = CreateFrame("Slider", "PostageOpacitySlider", opts, "OptionsSliderTemplate")
    sl:SetPoint("TOPLEFT", 16, -388)
    sl:SetWidth(200)
    sl:SetMinMaxValues(0.3, 1)
    sl:SetValueStep(0.05)
    if sl.SetObeyStepOnDrag then sl:SetObeyStepOnDrag(true) end
    local sltext = _G["PostageOpacitySliderText"]
    local lo, hi = _G["PostageOpacitySliderLow"], _G["PostageOpacitySliderHigh"]
    if lo then lo:SetText("") end
    if hi then hi:SetText("") end
    local function SlLabel(v) if sltext then sltext:SetText(("Window opacity  %d%%"):format(math.floor(v * 100 + 0.5))) end end
    sl:SetScript("OnValueChanged", function(self, v)
        if opts.syncing then return end
        P.db.look.alpha = v
        SlLabel(v)
        P.ApplyLook()
    end)
    opts.slider, opts.slLabel = sl, SlLabel

    local reset = CreateFrame("Button", nil, opts, "UIPanelButtonTemplate")
    reset:SetSize(120, 22)
    reset:SetText("Reset look")
    reset:SetPoint("BOTTOMRIGHT", -14, 14)
    reset:SetScript("OnClick", function()
        P.db.look = { preset = "gold", alpha = 0.96, menuSize = "normal" }
        opts.syncing = true sl:SetValue(0.96) opts.syncing = false SlLabel(0.96)
        P.ApplyLook()
    end)

    opts:SetScript("OnShow", function(self)
        for _, cb in ipairs(self.checks) do cb:SetChecked(cb.get() and true or false) end
        self.free:SetText(tostring(P.db.freeBagSlots or 0))
        local a = P.Look().alpha
        self.syncing = true self.slider:SetValue(a) self.syncing = false self.slLabel(a)
        P.ApplyLook()
    end)
    opts:Hide()
end

function P.ToggleOptions()
    if not opts then BuildOptions() end
    opts:SetShown(not opts:IsShown())
end

---------------------------------------------------------------------------
-- Mailbox skin: the theme also paints the game's mailbox windows (inbox, send mail, open mail)
---------------------------------------------------------------------------
local stripped = setmetatable({}, { __mode = "k" })
local STRIP_KEYS = { "Bg", "NineSlice", "Inset", "InsetBg", "TopTileStreaks", "TitleBg", "PortraitContainer", "TopBorder",
    "BottomBorder", "LeftBorder", "RightBorder", "Background" }
local function StripOne(region, on)
    if not (region and region.SetAlpha) then return end
    if on then
        if stripped[region] == nil then stripped[region] = region:GetAlpha() end
        region:SetAlpha(0)
    elseif stripped[region] ~= nil then
        region:SetAlpha(stripped[region])
        stripped[region] = nil
    end
end
local function StripFrame(f, on)
    pcall(function()
        for _, r in ipairs({ f:GetRegions() }) do
            if r.IsObjectType and r:IsObjectType("Texture") then StripOne(r, on) end
        end
        for _, k in ipairs(STRIP_KEYS) do
            local o = f[k]
            if o and o.SetAlpha then StripOne(o, on) end
        end
        local gi = _G[(f:GetName() or "") .. "Inset"]
        if gi then StripOne(gi, on) end
    end)
end

local function SkinFrame(f, key)
    if not f then return end
    local on = P.db.skinMail ~= false
    local skin = P[key]
    if on and not skin then
        skin = CreateFrame("Frame", nil, f, "BackdropTemplate")
        skin:SetAllPoints(f)
        skin:SetFrameLevel(math.max(0, (f:GetFrameLevel() or 1)))
        if skin.SetBackdrop then
            skin:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
        end
        P[key] = skin
    end
    if not skin then return end
    skin:SetShown(on)
    StripFrame(f, on)
    if on then
        local look = P.Look()
        Style(skin, look)
        local t = f.TitleText or _G[(f:GetName() or "") .. "TitleText"]
        if t and t.SetTextColor then t:SetTextColor(look.accent[1], look.accent[2], look.accent[3]) end
    end
end

function P.SkinMail()
    pcall(SkinFrame, _G.MailFrame, "mailSkin")
    pcall(SkinFrame, _G.OpenMailFrame, "openSkin")
end
P.AddHook("mailInit", P.SkinMail)
P.AddHook("mailShow", P.SkinMail)

-- Settings panel in the game's Options > AddOns, and the addon compartment, so the options
-- window is reachable without a button on the mailbox.
P.AddHook("login", function()
    local panel = CreateFrame("Frame")
    panel.name = "Postage"
    local t = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    t:SetPoint("TOPLEFT", 16, -16)
    t:SetText("Postage")
    local b = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    b:SetSize(180, 24)
    b:SetPoint("TOPLEFT", 16, -52)
    b:SetText("Open Postage options")
    b:SetScript("OnClick", function() P.ToggleOptions() end)
    pcall(function()
        if Settings and Settings.RegisterCanvasLayoutCategory then
            local cat = Settings.RegisterCanvasLayoutCategory(panel, "Postage")
            Settings.RegisterAddOnCategory(cat)
        elseif InterfaceOptions_AddCategory then
            InterfaceOptions_AddCategory(panel)
        end
    end)
end)
function Postage_OnAddonCompartmentClick() P.ToggleOptions() end

---------------------------------------------------------------------------
-- Minimap button
---------------------------------------------------------------------------
local mini

-- Right-click menu on the minimap button: flip any feature on or off in one click.
local function QuickMenu(anchor)
    local entries = { { text = "Postage settings", title = true } }
    for _, m in ipairs(MODULES) do
        local key, label = m[1], m[2]
        local on = P.db.modules[key] ~= false
        entries[#entries + 1] = {
            text = (on and "|cff55ff55On |r  " or "|cffff5555Off|r  ") .. label,
            func = function()
                P.db.modules[key] = not on
                P.Fire("options")
                P.Print(label .. (on and " off." or " on."))
                QuickMenu(anchor)
            end,
        }
    end
    entries[#entries + 1] = { text = "More options...", func = function() P.ToggleOptions() end }
    entries[#entries + 1] = { text = "Hide minimap button", func = function()
        P.db.minimap.show = false
        P.UpdateMinimap()
        P.Print("Minimap button hidden. /postage minimap brings it back.")
    end }
    P.ShowMenu(anchor, entries)
end
P.QuickMenu = QuickMenu

local function PlaceMini()
    local a = math.rad(P.db.minimap.angle or 215)
    local r = ((Minimap and Minimap:GetWidth() or 140) / 2) + 6
    mini:ClearAllPoints()
    mini:SetPoint("CENTER", Minimap, "CENTER", math.cos(a) * r, math.sin(a) * r)
end

local function BuildMini()
    if not Minimap then return end
    mini = CreateFrame("Button", "PostageMinimapButton", Minimap)
    mini:SetSize(31, 31)
    mini:SetFrameStrata("MEDIUM")
    mini:SetFrameLevel(8)
    mini:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    mini:RegisterForDrag("LeftButton")
    mini:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    local icon = mini:CreateTexture(nil, "BACKGROUND")
    icon:SetSize(20, 20)
    icon:SetPoint("CENTER", 0, 1)
    icon:SetTexture(P.ICON)
    icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    local border = mini:CreateTexture(nil, "OVERLAY")
    border:SetSize(53, 53)
    border:SetPoint("TOPLEFT")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    mini:SetScript("OnClick", function(self, btn)
        if btn == "RightButton" then QuickMenu(self) else P.ToggleOptions() end
    end)
    mini:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", function()
            local mx, my = Minimap:GetCenter()
            local cx, cy = GetCursorPosition()
            local scale = Minimap:GetEffectiveScale()
            P.db.minimap.angle = math.deg(math.atan2(cy / scale - my, cx / scale - mx))
            PlaceMini()
        end)
    end)
    mini:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
    mini:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText("Postage", 1, 0.8, 0)
        GameTooltip:AddLine("Left-click: settings window.", 0.85, 0.85, 0.85)
        GameTooltip:AddLine("Right-click: turn features on or off.", 0.85, 0.85, 0.85)
        GameTooltip:AddLine("Drag: move this button.", 0.85, 0.85, 0.85)
        GameTooltip:AddLine("/postage minimap hides this button.", 0.6, 0.6, 0.6)
        GameTooltip:Show()
    end)
    mini:SetScript("OnLeave", function() GameTooltip:Hide() end)
    PlaceMini()
end

function P.UpdateMinimap()
    if not mini then BuildMini() end
    if mini then mini:SetShown(P.db.minimap.show and true or false) end
end

P.AddHook("login", P.UpdateMinimap)
