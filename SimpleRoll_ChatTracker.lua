-- SimpleRoll chat-based roll tracker.
--
-- Parses CHAT_MSG_LOOT messages against Blizzard's localized LOOT_ROLL_* format
-- strings to infer who bid Need/Greed/Pass on each item. Data is exposed via
-- the SimpleRollChat namespace so the main UI (see SimpleRoll.lua) can read
-- counts and render them when the SimpleRollDB.chatTracking option is on.
--
-- Technique ported from LootX (Monitor/events.lua): escape a format string's
-- Lua-pattern metachars, then swap the `%s`/`%d` placeholders for captures.

_G.SimpleRollChat = _G.SimpleRollChat or {}
local M = _G.SimpleRollChat

-- tracked[itemLink] = {
--     need = { playerName, ... }, greed = {...}, pass = {...},
--     counts = { need=N, greed=N, pass=N },
--     winner = playerName, allpass = bool,
-- }
local tracked = {}
M.tracked = tracked

local player = UnitName("player") or "Unknown"
local YOU_STR = _G.YOU

local function IsEnabled()
    return SimpleRollDB and SimpleRollDB.chatTracking and true or false
end

local function EnsureEntry(link)
    local t = tracked[link]
    if not t then
        t = {
            need = {}, greed = {}, pass = {},
            counts = { need = 0, greed = 0, pass = 0 },
        }
        tracked[link] = t
    end
    return t
end

local function AddName(entry, kind, name)
    if not name or name == "" then return end
    -- Same player may appear via both SELF and non-SELF patterns; dedupe.
    local list = entry[kind]
    if not list then return end
    for i = 1, #list do
        if list[i] == name then return end
    end
    list[#list + 1] = name
    entry.counts[kind] = (entry.counts[kind] or 0) + 1
    if M.onUpdate then M.onUpdate(entry, kind, name) end
end

-- Escape Lua-pattern metacharacters. `%` becomes `%%`, so the format tokens
-- `%s`/`%d` in the input survive as `%%s`/`%%d` and we can swap them below.
local function EscapeLuaPattern(s)
    return (s:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1"))
end

local function DeformatPattern(fmt)
    if not fmt then return nil end
    local esc = EscapeLuaPattern(fmt)
    esc = esc:gsub("%%%%s", "(.+)")
    esc = esc:gsub("%%%%d", "(%%d+)")
    return "^" .. esc .. "$"
end

-- Patterns are built on first chat message (locale globals are stable by then).
local patterns
local function BuildPatterns()
    if patterns then return patterns end
    patterns = {}
    local function add(key, kind, selfish)
        local fmt = _G[key]
        local pat = DeformatPattern(fmt)
        if pat then
            patterns[#patterns + 1] = { pat = pat, kind = kind, selfish = selfish }
        end
    end

    -- Selections: "%s has selected Need for: %s" etc. (name, item)
    add("LOOT_ROLL_NEED",              "need")
    add("LOOT_ROLL_GREED",             "greed")
    add("LOOT_ROLL_PASSED",            "pass")
    add("LOOT_ROLL_PASSED_AUTO",       "pass")
    add("LOOT_ROLL_PASSED_AUTO_FEMALE","pass")
    -- SELF variants: "You have selected Need for: %s" (item only, name = player)
    add("LOOT_ROLL_NEED_SELF",         "need",  true)
    add("LOOT_ROLL_GREED_SELF",        "greed", true)
    add("LOOT_ROLL_PASSED_SELF",       "pass",  true)
    add("LOOT_ROLL_PASSED_SELF_AUTO",  "pass",  true)

    -- Outcomes
    add("LOOT_ROLL_WON",               "won")
    add("LOOT_ROLL_YOU_WON",           "won",   true)
    add("LOOT_ROLL_ALL_PASSED",        "allpass")

    return patterns
end

local function Handle(text)
    if not text or text == "" then return end
    local pats = BuildPatterns()
    for i = 1, #pats do
        local p = pats[i]
        if p.kind == "allpass" then
            local item = text:match(p.pat)
            if item then
                local entry = EnsureEntry(item)
                entry.allpass = true
                if M.onUpdate then M.onUpdate(entry, "allpass", nil) end
                return
            end
        elseif p.selfish then
            -- Single capture = item link; actor is the local player.
            local item = text:match(p.pat)
            if item then
                local entry = EnsureEntry(item)
                if p.kind == "won" then
                    entry.winner = player
                    if M.onUpdate then M.onUpdate(entry, "won", player) end
                else
                    AddName(entry, p.kind, player)
                end
                return
            end
        else
            -- Two captures. For selections/won the Blizzard format is
            -- "<name> ... <item>", so positional order gives us (who, item).
            local who, item = text:match(p.pat)
            if who and item then
                if who == YOU_STR then who = player end
                local entry = EnsureEntry(item)
                if p.kind == "won" then
                    entry.winner = who
                    if M.onUpdate then M.onUpdate(entry, "won", who) end
                else
                    AddName(entry, p.kind, who)
                end
                return
            end
        end
    end
end

function M:GetEntry(itemLink)
    return tracked[itemLink]
end

function M:Reset()
    wipe(tracked)
    if M.onUpdate then M.onUpdate(nil, "reset", nil) end
end

function M:Forget(itemLink)
    tracked[itemLink] = nil
end

local f = CreateFrame("Frame", "SimpleRollChatTrackerFrame", UIParent)
f:RegisterEvent("CHAT_MSG_LOOT")
f:SetScript("OnEvent", function(_, _, msg)
    if not IsEnabled() then return end
    Handle(msg)
end)
