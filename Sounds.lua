local ADDON_NAME, P = ...
-- A sound when new mail arrives. Off until you switch it on; pick the sound in the options (Alt-click the minimap
-- button). Your own sound: save it as Media\mysound.ogg (or .mp3) in the Postage folder and pick "Your own sound".
local S = {}
P.Sounds = S
local MEDIA = "Interface\\AddOns\\Postage\\Media\\"

-- files made for Postage, then the game's own sounds
S.LIST = {
    { key = "mail_chime",      name = "Mail chime",            file = "mailsnd_mail_chime.ogg" },
    { key = "doorbell",        name = "Doorbell",              file = "mailsnd_doorbell.ogg" },
    { key = "typewriter_bell", name = "Typewriter bell",       file = "mailsnd_typewriter_bell.ogg" },
    { key = "letter_swish",    name = "Letter swish and ding", file = "mailsnd_letter_swish.ogg" },
    { key = "glass",           name = "Glass ting",            file = "mailsnd_glass.ogg" },
    { key = "arpeggio_up",     name = "Marimba, going up",     file = "mailsnd_arpeggio_up.ogg" },
    { key = "arpeggio_down",   name = "Marimba, going down",   file = "mailsnd_arpeggio_down.ogg" },
    { key = "xylophone",       name = "Xylophone",             file = "mailsnd_xylophone.ogg" },
    { key = "harp",            name = "Harp sweep",            file = "mailsnd_harp.ogg" },
    { key = "sparkle",         name = "Sparkle",               file = "mailsnd_sparkle.ogg" },
    { key = "fanfare",         name = "Little fanfare",        file = "mailsnd_fanfare.ogg" },
    { key = "coins",           name = "Coins",                 file = "mailsnd_coins.ogg" },
    { key = "double_blip",     name = "Two blips",             file = "mailsnd_double_blip.ogg" },
    { key = "pop",             name = "Pop",                   file = "mailsnd_pop.ogg" },
    { key = "soft_gong",       name = "Soft gong",             file = "mailsnd_soft_gong.ogg" },
    { key = "tell",            name = "Game: whisper",         kit = "TELL_MESSAGE", id = 3081 },
    { key = "coin_sell",       name = "Game: vendor coins",    kit = "LOOT_WINDOW_COIN_SELL", id = 891 },
    { key = "quest_done",      name = "Game: quest complete",  kit = "IG_QUEST_LIST_COMPLETE", id = 878 },
    { key = "levelup",         name = "Game: level up",        kit = "LEVELUP", id = 888 },
    { key = "ready",           name = "Game: ready check",     kit = "READY_CHECK", id = 8960 },
    { key = "raidwarn",        name = "Game: raid warning",    kit = "RAID_WARNING", id = 8959 },
    { key = "ah_open",         name = "Game: auction house bell", kit = "AUCTION_WINDOW_OPEN", id = 5274 },
    { key = "ah_close",        name = "Game: auction house close", kit = "AUCTION_WINDOW_CLOSE", id = 5275 },
    { key = "ping",            name = "Game: map ping",        kit = "MAP_PING", id = 3175 },
    { key = "check_on",        name = "Game: checkbox click",  kit = "IG_MAINMENU_OPTION_CHECKBOX_ON", id = 856 },
    { key = "mine",            name = "Your own sound (Media\\mysound.ogg or .mp3)", files = { "mysound.ogg", "mysound.mp3" } },
}

local NAMES, ORDER = {}, {}
for _, e in ipairs(S.LIST) do NAMES[e.key] = e.name ORDER[#ORDER + 1] = e.key end
S.NAMES, S.ORDER = NAMES, ORDER

local function Find(key) for _, e in ipairs(S.LIST) do if e.key == key then return e end end return S.LIST[1] end
function S.Current() return Find(P.db and P.db.mailSoundKey or "mail_chime") end

-- extra sounds added by another file (PersonalSounds.lua keeps the ones you copied in yourself)
function S.Add(key, name, file)
    if NAMES[key] then return end
    local e = { key = key, name = name, file = file, dir = "personal\\" }
    table.insert(S.LIST, #S.LIST, e)      -- before "Your own sound", which stays last
    NAMES[key] = name
    table.insert(ORDER, #ORDER, key)
end

function S.PlayEntry(e)
    local files = e.files or (e.file and { e.file })
    if files then
        for _, f in ipairs(files) do
            local ok, will = pcall(PlaySoundFile, MEDIA .. (e.dir or "") .. f, "Master")
            if ok and will then return true end
        end
        return false
    end
    local id = (SOUNDKIT and SOUNDKIT[e.kit]) or e.id
    local ok = id and pcall(PlaySound, id, "Master")
    return ok and true or false
end

function S.Play(key)
    local e = key and Find(key) or S.Current()
    if not S.PlayEntry(e) then
        S.PlayEntry(Find("tell"))
        if e.key == "mine" and P.Print then P.Print("no sound found: save yours as Media\\mysound.ogg or mysound.mp3 in the Postage folder") end
    end
end

local last = 0
local f = CreateFrame("Frame")
f:RegisterEvent("UPDATE_PENDING_MAIL")
f:SetScript("OnEvent", function()
    if not (P.db and P.db.mailSound) then return end
    if HasNewMail and not HasNewMail() then return end
    if MailFrame and MailFrame:IsShown() then return end         -- you are at the mailbox already
    local now = GetTime()
    if now - last < 3 then return end
    last = now
    pcall(S.Play)
end)
