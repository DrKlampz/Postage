-- Postage menus: a small popup list, the options window, the Postage button on the mailbox,
-- and the minimap button.
local ADDON_NAME, P = ...

---------------------------------------------------------------------------
-- Popup list. entries = { { text=, func=, title=true, color= } ... }
---------------------------------------------------------------------------
local menu
local MENU_W, ROW_H, MAX_ROWS = 190, 16, 30

local function BuildMenu()
    menu = CreateFrame("Frame", "PostagePopupMenu", UIParent, "BackdropTemplate")
    menu:SetFrameStrata("FULLSCREEN_DIALOG")
    menu:SetClampedToScreen(true)
    menu:EnableMouse(true)
    if menu.SetBackdrop then
        menu:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
        menu:SetBackdropColor(0.06, 0.06, 0.08, 0.97)
        menu:SetBackdropBorderColor(0.8, 0.65, 0.1, 0.9)
    end
    menu.rows = {}
    for i = 1, MAX_ROWS do
        local r = CreateFrame("Button", nil, menu)
        r:SetSize(MENU_W - 12, ROW_H)
        r:SetPoint("TOPLEFT", 6, -6 - (i - 1) * ROW_H)
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
    local n = math.min(#entries, MAX_ROWS)
    for i, r in ipairs(menu.rows) do
        local e = entries[i]
        r.entry = e
        if e and i <= n then
            if e.title then
                r.text:SetText("|cffffcc00" .. e.text .. "|r")
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
local opts
local MODULES = {
    { "select", "Select", "Checkboxes on the inbox, with Open and Return buttons." },
    { "openall", "Open All", "An Open All button that skips COD mail and totals the gold." },
    { "express", "Express", "Shift-click a mail to take it, ctrl-click to return it, scroll to page. Alt-click a bag item to attach it." },
    { "blackbook", "BlackBook", "Contact list next to the To: box (alts, recent, friends, guild) with name autocomplete." },
    { "donotwant", "DoNotWant", "Days left on each mail: yellow returns to sender, red is deleted." },
    { "quickattach", "QuickAttach", "Buttons that attach all your cloth, herbs, ore and so on in one click." },
    { "carboncopy", "CarbonCopy", "A Copy button on open mail, to copy its text." },
    { "forward", "Forward", "A Forward button on open mail (text only; attachments aren't forwarded)." },
    { "wire", "Wire", "Fills an empty subject with the amount of gold you're sending." },
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

local function BuildOptions()
    opts = CreateFrame("Frame", "PostageOptionsFrame", UIParent, "BackdropTemplate")
    opts:SetSize(430, 360)
    opts:SetPoint("CENTER")
    opts:SetFrameStrata("DIALOG")
    opts:SetMovable(true)
    opts:EnableMouse(true)
    opts:RegisterForDrag("LeftButton")
    opts:SetScript("OnDragStart", opts.StartMoving)
    opts:SetScript("OnDragStop", opts.StopMovingOrSizing)
    opts:SetClampedToScreen(true)
    if opts.SetBackdrop then
        opts:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
        opts:SetBackdropColor(0.05, 0.05, 0.07, 0.96)
        opts:SetBackdropBorderColor(0.8, 0.65, 0.1, 0.9)
    end
    tinsert(UISpecialFrames, "PostageOptionsFrame")

    local icon = opts:CreateTexture(nil, "ARTWORK")
    icon:SetSize(24, 24)
    icon:SetPoint("TOPLEFT", 12, -10)
    icon:SetTexture(P.ICON)
    local title = opts:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("LEFT", icon, "RIGHT", 6, 0)
    title:SetText("Postage |cff888888v" .. tostring(P.version or "") .. "|r")
    local close = CreateFrame("Button", nil, opts, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", 0, 0)

    local h1 = opts:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    h1:SetPoint("TOPLEFT", 14, -44)
    h1:SetText("Features")
    opts.checks = {}
    for i, m in ipairs(MODULES) do
        local key = m[1]
        local cb = Check(opts, m[2], m[3], function() return P.db.modules[key] ~= false end,
            function(v) P.db.modules[key] = v end)
        cb:SetPoint("TOPLEFT", 14, -60 - (i - 1) * 24)
        opts.checks[#opts.checks + 1] = cb
    end

    local h2 = opts:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    h2:SetPoint("TOPLEFT", 214, -44)
    h2:SetText("Open All takes")
    for i, k in ipairs(KINDS) do
        local key = k[1]
        local cb = Check(opts, k[2], nil, function() return P.db.openAll[key] ~= false end,
            function(v) P.db.openAll[key] = v end)
        cb:SetPoint("TOPLEFT", 214, -60 - (i - 1) * 24)
        opts.checks[#opts.checks + 1] = cb
    end
    local cod = opts:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    cod:SetPoint("TOPLEFT", 216, -60 - #KINDS * 24 - 2)
    cod:SetText("COD mail is always skipped.")

    local mm = Check(opts, "Minimap button", nil, function() return P.db.minimap.show end,
        function(v) P.db.minimap.show = v if P.UpdateMinimap then P.UpdateMinimap() end end)
    mm:SetPoint("TOPLEFT", 214, -60 - (#KINDS + 1) * 24)
    opts.checks[#opts.checks + 1] = mm
    local ac = Check(opts, "Autocomplete names", "Finish names as you type in the To: box.",
        function() return P.db.autocomplete ~= false end, function(v) P.db.autocomplete = v end)
    ac:SetPoint("TOPLEFT", 214, -60 - (#KINDS + 2) * 24)
    opts.checks[#opts.checks + 1] = ac

    local fl = opts:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    fl:SetPoint("BOTTOMLEFT", 16, 22)
    fl:SetText("Keep this many bag slots free when opening mail:")
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

    opts:SetScript("OnShow", function(self)
        for _, cb in ipairs(self.checks) do cb:SetChecked(cb.get() and true or false) end
        self.free:SetText(tostring(P.db.freeBagSlots or 0))
    end)
    opts:Hide()
end

function P.ToggleOptions()
    if not opts then BuildOptions() end
    opts:SetShown(not opts:IsShown())
end

---------------------------------------------------------------------------
-- The Postage button on the mailbox
---------------------------------------------------------------------------
P.AddHook("mailInit", function()
    local mf = _G.MailFrame
    if not mf then return end
    local b = CreateFrame("Button", "PostageMailButton", mf, "UIPanelButtonTemplate")
    b:SetSize(72, 20)
    b:SetText("Postage")
    local closeBtn = mf.CloseButton or _G.MailFrameCloseButton
    if closeBtn then
        b:SetPoint("RIGHT", closeBtn, "LEFT", -2, 0)
    else
        b:SetPoint("TOPRIGHT", mf, "TOPRIGHT", -28, -4)
    end
    b:SetFrameLevel(mf:GetFrameLevel() + 10)
    b:SetScript("OnClick", function() P.ToggleOptions() end)
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetText("Postage options", 1, 1, 1)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
end)

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
