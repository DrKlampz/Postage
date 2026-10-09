-- Postage open-mail side:
--   CarbonCopy - a Copy button that shows the mail's text in a box you can copy from
--   Forward    - a Forward button that starts a new mail with the same subject and text
--                (attachments aren't forwarded)
local ADDON_NAME, P = ...
local ui = {}

local function OpenIndex()
    local inbox = _G.InboxFrame
    local of = _G.OpenMailFrame
    return (inbox and inbox.openMailID) or (of and of.openMailID)
end

local function MailText(i)
    if not GetInboxText then return "" end
    local body = GetInboxText(i)
    if type(body) ~= "string" or P.IsSecret(body) then return "" end
    return body
end

local copyFrame
local function ShowCopy(text)
    if not copyFrame then
        copyFrame = CreateFrame("Frame", "PostageCopyFrame", UIParent, "BackdropTemplate")
        copyFrame:SetSize(420, 260)
        copyFrame:SetPoint("CENTER")
        copyFrame:SetFrameStrata("DIALOG")
        copyFrame:SetToplevel(true)
        copyFrame:EnableMouse(true)
        copyFrame:SetMovable(true)
        copyFrame:RegisterForDrag("LeftButton")
        copyFrame:SetScript("OnDragStart", copyFrame.StartMoving)
        copyFrame:SetScript("OnDragStop", copyFrame.StopMovingOrSizing)
        if copyFrame.SetBackdrop then
            copyFrame:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
            copyFrame:SetBackdropColor(0.05, 0.05, 0.07, 0.97)
            copyFrame:SetBackdropBorderColor(0.8, 0.65, 0.1, 0.9)
        end
        tinsert(UISpecialFrames, "PostageCopyFrame")
        local t = copyFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        t:SetPoint("TOPLEFT", 12, -10)
        t:SetText("Mail text  |cff888888(Ctrl+C to copy, Esc to close)|r")
        local close = CreateFrame("Button", nil, copyFrame, "UIPanelCloseButton")
        close:SetPoint("TOPRIGHT", 0, 0)
        local sc = CreateFrame("ScrollFrame", nil, copyFrame, "UIPanelScrollFrameTemplate")
        sc:SetPoint("TOPLEFT", 12, -34)
        sc:SetPoint("BOTTOMRIGHT", -32, 12)
        local eb = CreateFrame("EditBox", nil, sc)
        eb:SetMultiLine(true)
        eb:SetFontObject(ChatFontNormal or GameFontHighlight)
        eb:SetWidth(360)
        eb:SetAutoFocus(false)
        eb:SetScript("OnEscapePressed", function() copyFrame:Hide() end)
        sc:SetScrollChild(eb)
        copyFrame.edit = eb
    end
    copyFrame.edit:SetText(text ~= "" and text or "(this mail has no text)")
    copyFrame:Show()
    copyFrame.edit:SetFocus()
    copyFrame.edit:HighlightText()
end

function P.CopyOpenMail()
    local i = OpenIndex()
    if not i then return end
    ShowCopy(MailText(i))
end

function P.ForwardOpenMail()
    local i = OpenIndex()
    if not i then return end
    local h = P.Header(i)
    local body = MailText(i)
    if MailFrameTab_OnClick then pcall(MailFrameTab_OnClick, nil, 2) end
    local subj, bodyBox, to = _G.SendMailSubjectEditBox, _G.SendMailBodyEditBox, _G.SendMailNameEditBox
    if subj and h then subj:SetText("FW: " .. (h.subject or "")) end
    if bodyBox then
        local header = h and ("-- Forwarded mail from " .. h.sender .. " --\n") or ""
        bodyBox:SetText(header .. body)
    end
    if to then to:SetText("") to:SetFocus() end
    if h and h.itemCount > 0 then P.Print("Attachments aren't forwarded. Take them and attach them yourself.") end
end

local function Build()
    local of = _G.OpenMailFrame
    if not of then return end
    local function Btn(text, onClick)
        local b = CreateFrame("Button", nil, of, "UIPanelButtonTemplate")
        b:SetSize(70, 22)
        b:SetText(text)
        b:SetScript("OnClick", onClick)
        return b
    end
    ui.forward = Btn("Forward", P.ForwardOpenMail)
    ui.copy = Btn("Copy", P.CopyOpenMail)
    -- Tucked under the Report Player button, in the header: always visible, never over the
    -- attachments or the Reply/Return/Close row.
    local anchor = _G.OpenMailReportSpamButton
    for _, b in pairs({ui.forward, ui.copy}) do
        b:SetSize(58, 20)
        b:SetFrameLevel((of:GetFrameLevel() or 1) + 10)
    end
    if anchor and anchor.GetObjectType then
        ui.forward:SetPoint("TOPRIGHT", anchor, "BOTTOMRIGHT", 0, -4)
    else
        ui.forward:SetPoint("TOPRIGHT", of, "TOPRIGHT", -16, -66)
    end
    ui.copy:SetPoint("RIGHT", ui.forward, "LEFT", -2, 0)
end

local function Refresh()
    if ui.forward then ui.forward:SetShown(P.On("forward")) end
    if ui.copy then ui.copy:SetShown(P.On("carboncopy")) end
end

P.AddHook("mailInit", Build)
P.AddHook("mailShow", Refresh)
P.AddHook("options", Refresh)
