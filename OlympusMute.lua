-- OlympusMute: hides chat from players whose guild name contains any saved keyword.
-- Purely client-side. Nothing is added to the ignore list; senders aren't notified.
--
-- Chat events don't carry the sender's guild, so the addon learns guilds by
-- watching players it can see (target, mouseover, nameplates, group) and from
-- any /who results you run. Learned players are kept only for the current session.

local DEFAULT_KEYWORDS = { "olympus" }   -- case-insensitive parts of guild names
local MIN_KEYWORD_LEN = 3                 -- avoids accidental 1-2 letter matches
local PREFIX = "|cff66ccffOlympusMute:|r "

local db
local playerGUID
local panel, category, CreatePanel   -- options panel, built at login
local pendingInvite                 -- normalized name of an unidentified group inviter
local OnChatLine                    -- set below; runs on every line added to chat
local scanStep = 0
local scanQueries
local WhoScan

local CHAT_EVENTS = {
    "CHAT_MSG_SAY", "CHAT_MSG_YELL", "CHAT_MSG_EMOTE", "CHAT_MSG_TEXT_EMOTE",
    "CHAT_MSG_WHISPER", "CHAT_MSG_CHANNEL",
    "CHAT_MSG_GUILD", "CHAT_MSG_OFFICER",
    "CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER",
    "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER", "CHAT_MSG_RAID_WARNING",
    "CHAT_MSG_INSTANCE_CHAT", "CHAT_MSG_INSTANCE_CHAT_LEADER",
    "CHAT_MSG_AFK", "CHAT_MSG_DND",
}

local function Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage(PREFIX .. msg)
end

local function IsSecret(v)
    return issecretvalue and issecretvalue(v)
end

-- True if the guild name contains any configured keyword.
local function IsOlympus(guild)
    if type(guild) ~= "string" or guild == "" or not db then return false end
    local g = guild:lower()
    for _, kw in ipairs(db.keywords or {}) do
        if g:find(kw, 1, true) then return true end
    end
    return false
end

-- "Name" or "Name-Realm" -> "name-realm"
local function Normalize(name)
    if type(name) ~= "string" or name == "" then return nil end
    if not name:find("-", 1, true) then
        local realm = GetNormalizedRealmName and GetNormalizedRealmName()
        if realm then name = name .. "-" .. realm end
    end
    return name:lower()
end

-- Remove lines already printed by a newly identified player.
local function PurgeHistory(name)
    local short = type(name) == "string" and name:match("^[^-]+")
    if not short then return end
    local a, b = "|Hplayer:" .. short .. "-", "|Hplayer:" .. short .. ":"
    local function predicate(msg)
        if type(msg) == "table" then msg = msg.message end
        if type(msg) ~= "string" or IsSecret(msg) then return false end
        return msg:find(a, 1, true) ~= nil or msg:find(b, 1, true) ~= nil
    end
    for i = 1, (NUM_CHAT_WINDOWS or 10) do
        local frame = _G["ChatFrame" .. i]
        if frame and frame.RemoveMessagesByPredicate then
            pcall(frame.RemoveMessagesByPredicate, frame, predicate)
        end
    end
end

local function DeclinePartyInvite(name, guild)
    pendingInvite = nil
    DeclineGroup()
    if StaticPopup_Hide then StaticPopup_Hide("PARTY_INVITE") end
    Print(("declined a group invite from %s <%s>."):format(tostring(name), tostring(guild)))
end

-- Highest level seen on a matching guild member. The /who scan rotation
-- can then avoid searching above the highest level we've actually observed.
local function NoteLevel(level)
    level = tonumber(level)
    if not level or level < 1 or level > 200 then return end
    if level > (db.maxSeenLevel or 0) then
        db.maxSeenLevel = level
        scanQueries = nil
    end
end

local function Block(guid, name, guild)
    local key = Normalize(name)
    if not key then return end
    local isNew = false
    if not db.names[key] then db.names[key] = guild; isNew = true end
    if guid and db.guids[guid] ~= key then db.guids[guid] = key; isNew = true end
    if pendingInvite == key and db.declineGroup then
        DeclinePartyInvite(name, guild)   -- identified while their invite was still open
    end
    if isNew then
        if db.debug then Print(("debug: muted %s <%s>"):format(tostring(name), tostring(guild))) end
        PurgeHistory(name)
        if panel and panel:IsShown() then panel:Refresh() end
    end
end

local function Unblock(guid, name, force)
    local key = Normalize(name)
    if key and db.manual[key] and not force then return end   -- added by hand; keep
    if key then db.names[key] = nil; db.manual[key] = nil end
    if guid then db.guids[guid] = nil end
    if key then
        for g, k in pairs(db.guids) do
            if k == key then db.guids[g] = nil end
        end
    end
end

local function UnblockFormer(name, newGuild)
    local key = Normalize(name)
    if not key or not db.names[key] or db.manual[key] then return end
    Unblock(nil, name, true)
    if db.debug then
        Print(("debug: unmuted %s, now %s"):format(
            name, (newGuild and newGuild ~= "") and ("<" .. newGuild .. ">") or "unguilded"))
    end
    if panel and panel:IsShown() then panel:Refresh() end
end

---------------------------------------------------------------------------
-- Learning guilds
---------------------------------------------------------------------------
local function ScanUnit(unit)
    if not UnitExists(unit) or not UnitIsPlayer(unit) or UnitIsUnit(unit, "player") then return end
    local guid = UnitGUID(unit)
    local name, realm
    if UnitFullName then name, realm = UnitFullName(unit) else name, realm = UnitName(unit) end
    if IsSecret(guid) or IsSecret(name) or not name then return end
    if realm and realm ~= "" then name = name .. "-" .. realm end

    local guild = GetGuildInfo(unit)
    if IsOlympus(guild) then
        NoteLevel(UnitLevel(unit))
        Block(guid, name, guild)
    elseif guild then
        Unblock(guid, name)      -- they're now in a different guild
    elseif unit == "target" then
        Unblock(guid, name)      -- targeted and confirmed unguilded
    end
end

local function SafeScan(unit) pcall(ScanUnit, unit) end

local function ScanGroup()
    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do SafeScan("raid" .. i) end
    else
        for i = 1, 4 do SafeScan("party" .. i) end
    end
end

local function ScanWho()
    if not (C_FriendList and C_FriendList.GetNumWhoResults and C_FriendList.GetWhoInfo) then return end
    for i = 1, C_FriendList.GetNumWhoResults() do
        local info = C_FriendList.GetWhoInfo(i)
        if info and IsOlympus(info.fullGuildName) then
            NoteLevel(info.level)
            Block(nil, info.fullName, info.fullGuildName)
        elseif info and info.fullName then
            UnblockFormer(info.fullName, info.fullGuildName)
        end
    end
end

-- Shift-clicking a name in chat runs /who on that player. When the result is
-- small, the game prints it as a system line instead of opening the Who window:
--   [Name]: Level 20 Human Warrior <Guild Name> - Zone
-- Read the player link and <guild> straight from that line (works in any language).
-- On this client the result line is written straight to the chat window
-- (no CHAT_MSG_SYSTEM event, which is why it has no timestamp), so we also
-- watch what gets added to the chat frames. A /who line starts with a bare
-- player link followed by "|h: "; normal chat links carry ":lineID:CHANNEL"
-- and never match, so players can't get muted by typing text that looks similar.
local function ParseWhoLine(msg)
    if type(msg) ~= "string" or IsSecret(msg) then return end
    msg = msg:gsub("^|c%x%x%x%x%x%x%x%x", "")
    local name, rest = msg:match("^|Hplayer:([^:|]+)|h%[[^%]]*%]|h: (.*)$")
    if not name then return end
    local guild = rest:match("<([^<>]+)>")
    if IsOlympus(guild) then
        NoteLevel(rest:match("(%d+)"))
        Block(nil, name, guild)
    else
        UnblockFormer(name, guild)
    end
end

local function HookChatFrames()
    for i = 1, (NUM_CHAT_WINDOWS or 10) do
        local frame = _G["ChatFrame" .. i]
        if frame and frame.AddMessage then
            hooksecurefunc(frame, "AddMessage", function(_, msg) OnChatLine(msg) end)
        end
    end
end

-- Show errors instead of failing silently, so problems can be reported.
local function ReportError(err)
    Print("|cffff4444error:|r " .. tostring(err))
end

-- Auto-decline guild invites from Olympus guilds, and mute the inviter.
local lastGuildDecline = 0

local function GuildInviteVisible()
    if GuildInviteFrame and GuildInviteFrame:IsShown() then return true end
    return StaticPopup_Visible and StaticPopup_Visible("GUILD_INVITE") and true or false
end

local function DeclineGuildInvite()
    -- Press the invite window's own Decline button when it exists, so the game
    -- does exactly what a manual click does; fall back to the API call.
    local btn = _G.GuildInviteFrameDeclineButton
    if btn and btn:IsVisible() then
        btn:Click()
    elseif DeclineGuild then
        DeclineGuild()
    elseif C_GuildInfo and C_GuildInfo.DeclineGuild then
        C_GuildInfo.DeclineGuild()
    end
    if StaticPopup_Hide then StaticPopup_Hide("GUILD_INVITE") end
    if GuildInviteFrame and GuildInviteFrame:IsShown() then GuildInviteFrame:Hide() end
end

local function HandleGuildInvite(inviter, guildName)
    if db.debug then Print(("debug: guild invite from %s <%s>"):format(tostring(inviter), tostring(guildName))) end
    if not db.declineGuild or IsSecret(guildName) or not IsOlympus(guildName) then return end
    DeclineGuildInvite()
    -- The invite window can open a moment after the event; check again shortly.
    if C_Timer and C_Timer.After then
        C_Timer.After(0.2, function()
            if GuildInviteVisible() then xpcall(DeclineGuildInvite, ReportError) end
        end)
    end
    if type(inviter) == "string" and not IsSecret(inviter) then
        Block(nil, inviter, guildName)
    end
    if GetTime() - lastGuildDecline > 2 then
        Print(("declined a guild invite from <%s>."):format(guildName))
    end
    lastGuildDecline = GetTime()
end

-- Backup trigger: the "[Name] invites you to join Guild." line printed to chat.
-- Only acted on while an invite window is actually open, and only for bare
-- player links (player chat lines carry ":lineID:CHANNEL" and never match).
local function ParseInviteLine(msg)
    if type(msg) ~= "string" or IsSecret(msg) then return end
    if GetTime() - lastGuildDecline < 2 or not GuildInviteVisible() then return end
    msg = msg:gsub("^|c%x%x%x%x%x%x%x%x", "")
    local name, rest = msg:match("^|Hplayer:([^:|]+)|h%[[^%]]*%]|h (.*)$")
    if not name or not IsOlympus(rest) then return end
    local guild = rest:gsub("|r$", ""):match("join (.-)%.?$") or rest
    HandleGuildInvite(name, guild)
end

OnChatLine = function(msg)
    pcall(ParseWhoLine, msg)
    if db and db.declineGuild then xpcall(function() ParseInviteLine(msg) end, ReportError) end
end

-- Group invites don't say which guild the inviter is in, so decline right away
-- if they're already on the mute list. Otherwise remember them: if they get
-- identified while the invite is still open (mouseover, target, shift-click),
-- the invite is declined at that point.
local function HandlePartyInvite(inviter, ...)
    if not db.declineGroup or type(inviter) ~= "string" or IsSecret(inviter) then return end
    local guid = select(6, ...)
    local key = Normalize(inviter)
    local guild = key and db.names[key]
    if not guild and guid and not IsSecret(guid) and db.guids[guid] then
        guild = db.names[db.guids[guid]]
    end
    if guild then
        DeclinePartyInvite(inviter, guild)
    else
        pendingInvite = key
    end
end

-- Shift-clicking a name can fire the same /who several times in a row
-- (you get the result repeated, or a "You must wait" message). Let identical
-- /who searches through once, and drop repeats sent within 3 seconds.
local WHO_REPEAT_WINDOW = 3
local lastWhoFilter, lastWhoTime = nil, 0

local function WhoAllowed(filter)
    local now = GetTime()
    if filter == lastWhoFilter and now - lastWhoTime < WHO_REPEAT_WINDOW then
        if db and db.debug then Print("debug: skipped repeat /who " .. tostring(filter)) end
        return false
    end
    lastWhoFilter, lastWhoTime = filter, now
    if db and db.debug then Print("debug: /who " .. tostring(filter)) end
    return true
end

local function InstallWhoDebounce()
    if C_FriendList and C_FriendList.SendWho then
        local orig = C_FriendList.SendWho
        C_FriendList.SendWho = function(filter, ...)
            if WhoAllowed(filter) then return orig(filter, ...) end
        end
    end
    if type(SendWho) == "function" then
        local orig = SendWho
        SendWho = function(filter, ...)
            if WhoAllowed(filter) then return orig(filter, ...) end
        end
    end
end

---------------------------------------------------------------------------
-- Chat filter
---------------------------------------------------------------------------
local function IsBlocked(author, guid)
    if guid and guid ~= playerGUID and db.guids[guid] and db.names[db.guids[guid]] then return true end
    local key = Normalize(author)
    return key ~= nil and db.names[key] ~= nil
end

local function Filter(_, _, _, author, ...)
    if not db or not db.enabled then return false end
    local guid = select(10, ...)  -- arg12
    if IsSecret(author) or IsSecret(guid) then return false end
    local ok, hit = pcall(IsBlocked, author, guid)
    return ok and hit or false
end

for _, event in ipairs(CHAT_EVENTS) do
    ChatFrame_AddMessageEventFilter(event, Filter)
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function(self, event, arg1, ...)
    if event == "ADDON_LOADED" then
        if arg1 ~= "OlympusMute" then return end
        OlympusMuteDB = OlympusMuteDB or {}
        db = OlympusMuteDB
        db.guids = db.guids or {}
        db.names = db.names or {}
        db.manual = db.manual or {}

        -- v1.2 uses "keywords" instead of the older "guildMatches" name.
        -- Merge both tables during upgrade so existing custom filters are kept.
        local migratedKeywords = {}
        local seenKeywords = {}
        local function addKeywordValue(value)
            if type(value) ~= "string" then return end
            value = strtrim(value):lower():gsub('"', "")
            if #value < MIN_KEYWORD_LEN or seenKeywords[value] then return end
            seenKeywords[value] = true
            migratedKeywords[#migratedKeywords + 1] = value
        end

        if type(db.keywords) == "table" then
            for _, kw in ipairs(db.keywords) do addKeywordValue(kw) end
        end
        if type(db.guildMatches) == "table" then
            for _, kw in ipairs(db.guildMatches) do addKeywordValue(kw) end
        end
        if #migratedKeywords == 0 then
            for _, kw in ipairs(DEFAULT_KEYWORDS) do addKeywordValue(kw) end
        end
        db.keywords = migratedKeywords
        db.guildMatches = nil
        db.maxSeenLevel = tonumber(db.maxSeenLevel) or 0
        if db.enabled == nil then db.enabled = true end
        -- 1.0.5 split the single invite setting into guild and group
        local old = db.declineInvites
        if old == nil then old = true end
        if db.declineGuild == nil then db.declineGuild = old end
        if db.declineGroup == nil then db.declineGroup = old end
        db.declineInvites = nil
        self:UnregisterEvent("ADDON_LOADED")
    elseif event == "PLAYER_LOGIN" then
        playerGUID = UnitGUID("player")

        -- The learned player cache is intentionally session-based. Keep the
        -- saved guild filters, but clear every player entry at login so the
        -- SavedVariables file cannot grow forever.
        wipe(db.guids)
        wipe(db.names)
        wipe(db.manual)
        scanQueries = nil
        scanStep = 0

        self:RegisterEvent("PLAYER_TARGET_CHANGED")
        self:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
        self:RegisterEvent("NAME_PLATE_UNIT_ADDED")
        self:RegisterEvent("GROUP_ROSTER_UPDATE")
        self:RegisterEvent("WHO_LIST_UPDATE")
        self:RegisterEvent("CHAT_MSG_SYSTEM")
        self:RegisterEvent("GUILD_INVITE_REQUEST")
        self:RegisterEvent("PARTY_INVITE_REQUEST")
        self:RegisterEvent("PARTY_INVITE_CANCEL")
        ScanGroup()
        HookChatFrames()
        InstallWhoDebounce()
        CreatePanel()

        -- C_FriendList.SendWho() requires a hardware event. Automatic
        -- timer-based /who scans are blocked by WoW, so scans are initiated
        -- only by the in-game Scan button or /omute scan command.
    elseif event == "PLAYER_TARGET_CHANGED" then
        SafeScan("target")
    elseif event == "UPDATE_MOUSEOVER_UNIT" then
        SafeScan("mouseover")
    elseif event == "NAME_PLATE_UNIT_ADDED" then
        SafeScan(arg1)
    elseif event == "GROUP_ROSTER_UPDATE" then
        pendingInvite = nil
        ScanGroup()
    elseif event == "PARTY_INVITE_REQUEST" then
        pcall(HandlePartyInvite, arg1, ...)
    elseif event == "PARTY_INVITE_CANCEL" then
        pendingInvite = nil
    elseif event == "WHO_LIST_UPDATE" then
        pcall(ScanWho)
    elseif event == "CHAT_MSG_SYSTEM" then
        pcall(ParseWhoLine, arg1)
    elseif event == "GUILD_INVITE_REQUEST" then
        local inviter, guildName = arg1, ...
        xpcall(function() HandleGuildInvite(inviter, guildName) end, ReportError)
    end
end)

---------------------------------------------------------------------------
-- Shared actions (used by both /omute and the options panel)
---------------------------------------------------------------------------
local function CountMuted()
    local n = 0
    for _ in pairs(db.names) do n = n + 1 end
    return n
end

local function SetEnabled(on)
    db.enabled = on and true or false
    Print("filtering " .. (db.enabled and "|cff00ff00ON|r" or "|cffff0000OFF|r"))
    if panel and panel:IsShown() then panel:Refresh() end
end

local function OnOff(v) return v and "|cff00ff00ON|r" or "|cffff0000OFF|r" end

local function SetDeclineGuild(on)
    db.declineGuild = on and true or false
    Print("auto-decline invites from muted guilds " .. OnOff(db.declineGuild))
    if panel and panel:IsShown() then panel:Refresh() end
end

local function SetDeclineGroup(on)
    db.declineGroup = on and true or false
    if not db.declineGroup then pendingInvite = nil end
    Print("auto-decline group invites from muted players " .. OnOff(db.declineGroup))
    if panel and panel:IsShown() then panel:Refresh() end
end

local MANUAL_TAG = "added manually"

local function AddPlayer(name)
    if not name or name == "" then return end
    local key = Normalize(name)
    if not key then return end
    if db.names[key] then
        Print(name .. " is already muted.")
    else
        db.manual[key] = true
        Block(nil, name, MANUAL_TAG)
        Print("muted " .. name .. ".")
    end
    if panel and panel:IsShown() then panel:Refresh() end
end

local function RemovePlayer(name)
    if not name or name == "" then return end
    local key = Normalize(name)
    if key and db.names[key] then
        Unblock(nil, name, true)
        Print("unmuted " .. name .. ".")
    else
        Print(name .. " isn't on the mute list. Use Name-Realm if they're from another realm.")
    end
    if panel and panel:IsShown() then panel:Refresh() end
end

local function ClearAll()
    wipe(db.guids); wipe(db.names); wipe(db.manual)
    Print("cleared all muted players.")
    if panel and panel:IsShown() then panel:Refresh() end
end

-- /who only returns the first 50 matches, so one search can't cover every
-- matching guild. Each user-initiated scan runs the next search in a rotation.
-- We include a broad guild search plus level ranges up to the highest matching
-- member level we've seen, rather than always scanning the full level cap.
local function BuildScanQueries()
    local cap = (GetMaxPlayerLevel and GetMaxPlayerLevel()) or 60
    local playerLevel = tonumber(UnitLevel("player")) or 1
    local maxLevel = math.min(cap, math.max(db.maxSeenLevel or 0, playerLevel))
    local q = {}

    for _, kw in ipairs(db.keywords or {}) do
        local base = 'g-"' .. kw .. '"'
        q[#q + 1] = base
        local lo = 1
        while lo <= maxLevel - 4 do
            q[#q + 1] = ("%s %d-%d"):format(base, lo, lo + 3)
            lo = lo + 4
        end
        for lvl = lo, maxLevel do
            q[#q + 1] = ("%s %d-%d"):format(base, lvl, lvl)
        end
    end
    return q
end

WhoScan = function()
    scanQueries = scanQueries or BuildScanQueries()
    if #scanQueries == 0 then
        Print("the guild list is empty, nothing to scan.")
        return
    end
    scanStep = scanStep % #scanQueries + 1
    local query = scanQueries[scanStep]
    if C_FriendList and C_FriendList.SendWho then
        C_FriendList.SendWho(query)
    elseif SendWho then
        SendWho(query)
    end
    Print(("scan %d/%d: /who %s"):format(scanStep, #scanQueries, query))
    if panel and panel.UpdateScanButton then panel:UpdateScanButton() end
end

local function CheckPlayer(name)
    local key = Normalize(name)
    if key and db.names[key] then
        Print(("%s is muted <%s>."):format(name, tostring(db.names[key])))
    else
        Print(name .. " is not on the mute list.")
    end
end

local function OpenOptions()
    if Settings and Settings.OpenToCategory and category then
        Settings.OpenToCategory(category.GetID and category:GetID() or category.ID)
    elseif InterfaceOptionsFrame_OpenToCategory and panel then
        InterfaceOptionsFrame_OpenToCategory(panel)
        InterfaceOptionsFrame_OpenToCategory(panel) -- old client quirk: needs two calls
    end
end

StaticPopupDialogs["OLYMPUSMUTE_CLEAR"] = {
    text = "Unmute everyone OlympusMute has learned so far?",
    button1 = YES, button2 = NO,
    OnAccept = ClearAll,
    timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
}

---------------------------------------------------------------------------
-- Saved guild-name keywords
---------------------------------------------------------------------------
local function KeywordList()
    return #(db.keywords or {}) > 0 and table.concat(db.keywords, ", ") or "(none)"
end

local function NormalizeKeyword(value)
    if type(value) ~= "string" then return nil end
    value = strtrim(value):lower():gsub('"', "")
    if #value < MIN_KEYWORD_LEN then return nil end
    return value
end

local function AddKeyword(text)
    local kw = NormalizeKeyword(text)
    if not kw then
        Print(("guild names need at least %d letters."):format(MIN_KEYWORD_LEN))
        return false
    end
    for _, k in ipairs(db.keywords) do
        if k == kw then
            Print('"' .. kw .. '" is already on the guild list.')
            return false
        end
    end
    db.keywords[#db.keywords + 1] = kw
    scanQueries = nil
    Print(('now muting guilds containing "%s". Guild list: %s'):format(kw, KeywordList()))
    if panel and panel:IsShown() then panel:Refresh() end
    return true
end

local function RemoveKeyword(text)
    local kw = NormalizeKeyword(text)
    if not kw then
        Print(("guild names need at least %d letters."):format(MIN_KEYWORD_LEN))
        return false
    end

    for i, k in ipairs(db.keywords) do
        if k == kw then
            table.remove(db.keywords, i)
            scanQueries = nil

            -- Remove learned players who no longer match any remaining keyword.
            -- Manually added players are preserved.
            local toUnblock = {}
            for name, guild in pairs(db.names) do
                if not db.manual[name] and not IsOlympus(guild) then
                    toUnblock[#toUnblock + 1] = name
                end
            end
            for _, name in ipairs(toUnblock) do
                Unblock(nil, name, true)
            end

            Print(('removed "%s" (%d players unmuted). Guild list: %s'):format(kw, #toUnblock, KeywordList()))
            if panel and panel:IsShown() then panel:Refresh() end
            return true
        end
    end

    Print('"' .. kw .. '" isn\'t on the guild list. Current list: ' .. KeywordList())
    return false
end

local function ListKeywords()
    Print("guild keywords: " .. KeywordList())
end

---------------------------------------------------------------------------
-- Options > AddOns panel
---------------------------------------------------------------------------
CreatePanel = function()
    panel = CreateFrame("Frame")
    panel.name = "OlympusMute"

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("OlympusMute")

    local desc = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    desc:SetPoint("RIGHT", panel, "RIGHT", -16, 0)
    desc:SetJustifyH("LEFT")
    desc:SetText("Hides chat from players whose guild name contains any keyword on your guild list "
        .. "(Olympus by default). Only affects your screen and doesn't use your ignore list. Players are learned "
        .. "when you target, mouse over, group with, or see their nameplate, from /who results, "
        .. "or when you shift-click their name in chat.")

    local enable = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    enable:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", -2, -12)
    local enableLabel = enable.Text or enable.text or enable:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    enableLabel:ClearAllPoints()
    enableLabel:SetPoint("LEFT", enable, "RIGHT", 2, 1)
    enableLabel:SetText("Enable filtering")
    enable:SetScript("OnClick", function(self) SetEnabled(self:GetChecked()) end)

    local function MakeCheck(text, anchor, onClick)
        local c = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
        c:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -2)
        local label = c.Text or c.text or c:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        label:ClearAllPoints()
        label:SetPoint("LEFT", c, "RIGHT", 2, 1)
        label:SetText(text)
        c:SetScript("OnClick", function(self) onClick(self:GetChecked()) end)
        return c
    end

    local declineGuild = MakeCheck("Auto-decline guild invites from muted guilds", enable, SetDeclineGuild)
    local declineGroup = MakeCheck("Auto-decline group invites from muted players", declineGuild, SetDeclineGroup)

    local function MakeButton(text, width, onClick, anchor, x, y)
        local b = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
        b:SetSize(width, 24)
        b:SetText(text)
        b:SetPoint("TOPLEFT", anchor, x and "TOPRIGHT" or "BOTTOMLEFT", x or 0, y or 0)
        b:SetScript("OnClick", onClick)
        return b
    end

    -- Guild keyword list.
    local kwLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    kwLabel:SetPoint("TOPLEFT", declineGroup, "BOTTOMLEFT", 2, -10)
    kwLabel:SetText("Muted guild names (matches any part of the name):")

    local kwBox = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
    kwBox:SetSize(180, 20)
    kwBox:SetPoint("TOPLEFT", kwLabel, "BOTTOMLEFT", 6, -6)
    kwBox:SetAutoFocus(false)

    local function KwAction(fn)
        return function()
            fn(kwBox:GetText() or "")
            kwBox:SetText("")
            kwBox:ClearFocus()
        end
    end

    kwBox:SetScript("OnEnterPressed", KwAction(AddKeyword))
    kwBox:SetScript("OnEscapePressed", kwBox.ClearFocus)
    local kwAdd = MakeButton("Add guild", 90, KwAction(AddKeyword), kwBox, 8, 2)
    MakeButton("Remove guild", 110, KwAction(RemoveKeyword), kwAdd, 8, 0)

    local kwText = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    kwText:SetPoint("TOPLEFT", kwBox, "BOTTOMLEFT", -6, -8)
    kwText:SetPoint("RIGHT", panel, "RIGHT", -16, 0)
    kwText:SetJustifyH("LEFT")

    -- User-initiated /who scan. Blizzard protects SendWho(), so this must be
    -- triggered by an actual button click or slash command.
    local whoBtn = MakeButton("Scan /who", 200, WhoScan, kwText, nil, -10)
    function panel:UpdateScanButton()
        local total = (scanQueries and #scanQueries) or #BuildScanQueries()
        if total == 0 then
            whoBtn:SetText("Scan /who (no guilds)")
        else
            whoBtn:SetText(("Scan /who (%d/%d)"):format(scanStep % total + 1, total))
        end
    end
    MakeButton("Clear list", 110, function() StaticPopup_Show("OLYMPUSMUTE_CLEAR") end, whoBtn, 8, 0)

    -- Manually mute one player.
    local addLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    addLabel:SetPoint("TOPLEFT", whoBtn, "BOTTOMLEFT", 0, -16)
    addLabel:SetText("Mute a player (Name or Name-Realm):")

    local addBox = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
    addBox:SetSize(180, 20)
    addBox:SetPoint("TOPLEFT", addLabel, "BOTTOMLEFT", 6, -6)
    addBox:SetAutoFocus(false)
    local function DoAdd()
        AddPlayer(strtrim(addBox:GetText() or ""))
        addBox:SetText("")
        addBox:ClearFocus()
    end
    addBox:SetScript("OnEnterPressed", DoAdd)
    addBox:SetScript("OnEscapePressed", addBox.ClearFocus)
    MakeButton("Add to list", 90, DoAdd, addBox, 8, 2)

    local removeLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    removeLabel:SetPoint("TOPLEFT", addBox, "BOTTOMLEFT", -6, -12)
    removeLabel:SetText("Unmute a player (Name or Name-Realm):")

    local box = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
    box:SetSize(180, 20)
    box:SetPoint("TOPLEFT", removeLabel, "BOTTOMLEFT", 6, -6)
    box:SetAutoFocus(false)
    local function DoRemove()
        RemovePlayer(strtrim(box:GetText() or ""))
        box:SetText("")
        box:ClearFocus()
    end
    box:SetScript("OnEnterPressed", DoRemove)
    box:SetScript("OnEscapePressed", box.ClearFocus)
    MakeButton("Unmute", 90, DoRemove, box, 8, 2)

    local countText = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    countText:SetPoint("TOPLEFT", box, "BOTTOMLEFT", -6, -16)

    local scroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", countText, "BOTTOMLEFT", 0, -6)
    scroll:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -36, 16)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(1, 1)
    scroll:SetScrollChild(content)
    local listText = content:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    listText:SetPoint("TOPLEFT")
    listText:SetJustifyH("LEFT")
    listText:SetSpacing(2)

    function panel:Refresh()
        enable:SetChecked(db.enabled)
        kwText:SetText("Current list: |cffffffff" .. KeywordList() .. "|r")
        self:UpdateScanButton()
        declineGuild:SetChecked(db.declineGuild)
        declineGroup:SetChecked(db.declineGroup)

        local names = {}
        for name, guild in pairs(db.names) do
            names[#names + 1] = name .. "  |cff999999<" .. tostring(guild) .. ">|r"
        end
        table.sort(names)
        countText:SetText(("Muted players: %d"):format(#names))
        listText:SetWidth(math.max(scroll:GetWidth() - 10, 200))
        listText:SetText(#names > 0 and table.concat(names, "
") or "|cff999999None yet.|r")
        content:SetSize(listText:GetWidth(), listText:GetStringHeight() + 4)
    end

    panel:SetScript("OnShow", panel.Refresh)

    if Settings and Settings.RegisterCanvasLayoutCategory then
        category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
        Settings.RegisterAddOnCategory(category)
    elseif InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(panel)
    end
end

---------------------------------------------------------------------------
-- /omute
---------------------------------------------------------------------------
SLASH_OLYMPUSMUTE1 = "/omute"
SlashCmdList.OLYMPUSMUTE = function(input)
    if not db then return end
    local cmd, rest = (input or ""):match("^%s*(%S*)%s*(.-)%s*$")
    cmd = cmd:lower()

    if cmd == "on" or cmd == "off" then
        SetEnabled(cmd == "on")
    elseif cmd == "list" then
        local n = 0
        for name, guild in pairs(db.names) do
            n = n + 1
            Print(name .. " <" .. tostring(guild) .. ">")
        end
        if n == 0 then Print("no players muted yet.") end
    elseif cmd == "debug" then
        db.debug = not db.debug
        Print("debug " .. (db.debug and "ON" or "OFF"))
    elseif cmd == "check" and rest ~= "" then
        CheckPlayer(rest)
    elseif cmd == "add" and rest ~= "" then
        AddPlayer(rest)
    elseif cmd == "remove" and rest ~= "" then
        RemovePlayer(rest)
    elseif cmd == "clear" then
        ClearAll()
    elseif cmd == "guild" then
        local sub, arg = rest:match("^(%S*)%s*(.-)$")
        sub = (sub or ""):lower()
        if sub == "add" and arg ~= "" then
            AddKeyword(arg)
        elseif sub == "remove" and arg ~= "" then
            RemoveKeyword(arg)
        elseif sub == "list" or sub == "" then
            ListKeywords()
        else
            Print("usage: /omute guild add|remove|list Name")
        end
    elseif cmd == "addguild" and rest ~= "" then
        AddKeyword(rest) -- compatibility alias
    elseif cmd == "removeguild" and rest ~= "" then
        RemoveKeyword(rest) -- compatibility alias
    elseif cmd == "guilds" or cmd == "guildlist" then
        ListKeywords() -- compatibility alias
    elseif cmd == "invites" and (rest == "on" or rest == "off") then
        SetDeclineGuild(rest == "on"); SetDeclineGroup(rest == "on")
    elseif cmd == "guildinvites" and (rest == "on" or rest == "off") then
        SetDeclineGuild(rest == "on")
    elseif cmd == "groupinvites" and (rest == "on" or rest == "off") then
        SetDeclineGroup(rest == "on")
    elseif cmd == "scan" then
        WhoScan()
    elseif cmd == "" or cmd == "config" or cmd == "options" then
        OpenOptions()
    else
        Print(("filtering %s, %d players muted."):format(
            db.enabled and "|cff00ff00ON|r" or "|cffff0000OFF|r", CountMuted()))
        Print("/omute (opens options) | on | off | guildinvites on|off | groupinvites on|off | guild add|remove|list Name | list | scan | check Name | add Name | remove Name | clear")
    end
end
