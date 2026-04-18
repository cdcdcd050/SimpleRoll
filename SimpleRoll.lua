local ADDON_NAME = "SimpleRoll"

-- ===========================================================
-- Localization
-- ===========================================================
local L = {}
if GetLocale() == "koKR" then
    L.need_all = "모두 입찰"
    L.need_all_tip = "모든 아이템 입찰"
    L.greed_all = "모두 차비"
    L.greed_all_tip = "모든 아이템 차비"
    L.pass_all = "모두 포기"
    L.pass_all_tip = "모든 아이템 포기"
    L.pass_all_confirm = "모든 아이템을 포기하시겠습니까?"
    L.need = "입찰"
    L.greed = "차비"
    L.pass = "포기"
    L.seconds = "%d초"
    L.loaded = "|cFFFFD700SimpleRoll|r 로드됨. /srsr 로 미리보기"
    L.test_spawned = "|cFFFFD700SimpleRoll:|r 미리보기 %d개 생성"
    L.cmd_preview = "미리보기 (랜덤 3~5개)"
    L.cmd_reset = "reset - 위치 초기화"
else
    L.need_all = "Need All"
    L.need_all_tip = "Need on all items"
    L.greed_all = "Greed All"
    L.greed_all_tip = "Greed on all items"
    L.pass_all = "Pass All"
    L.pass_all_tip = "Pass on all items"
    L.pass_all_confirm = "Pass on all items?"
    L.need = "Need"
    L.greed = "Greed"
    L.pass = "Pass"
    L.seconds = "%ds"
    L.loaded = "|cFFFFD700SimpleRoll|r loaded. /srsr to preview"
    L.test_spawned = "|cFFFFD700SimpleRoll:|r Spawned %d preview rolls"
    L.cmd_preview = "Preview (random 3~5 items)"
    L.cmd_reset = "reset - Reset position"
end

-- ===========================================================
-- Constants
-- ===========================================================
local DEFAULT_WIDTH      = 277
local SLOT_HEIGHT        = 40
local HEADER_HEIGHT      = 8
local FOOTER_HEIGHT      = 38
local PADDING            = 14
local LEFT_PADDING       = 4
local BUTTON_SIZE        = 26
local CLOSE_BUTTON_SIZE  = 18
local ICON_SIZE          = 30
local CLOSE_DELAY        = 0.5
local MAX_VISIBLE_SLOTS  = 4
local SLOT_SPACING       = 1
local RIGHT_MARGIN       = 6

local ROLL_NEED, ROLL_GREED, ROLL_PASS = 1, 2, 0
local TEST_ID_BASE = 9000

local COLOR_NEED  = { 0.4, 1, 0.4 }
local COLOR_GREED = { 0.4, 0.6, 1 }
local COLOR_PASS  = { 0.7, 0.7, 0.7 }

local GetItemInfo = C_Item and C_Item.GetItemInfo or _G.GetItemInfo
local GetItemQualityColor = C_Item and C_Item.GetItemQualityColor or _G.GetItemQualityColor

-- ===========================================================
-- State
-- ===========================================================
local activeRolls = {}
local pendingRolls = {}
local slotPool = {}
local nextAddedOrder = 1
local ReleaseSlot  -- forward

local EventFrame = CreateFrame("Frame", ADDON_NAME .. "Events", UIParent)

-- ===========================================================
-- Main Frame
-- ===========================================================
local MainFrame = CreateFrame("Frame", "SimpleRollFrame", UIParent, BackdropTemplateMixin and "BackdropTemplate")
MainFrame:SetSize(DEFAULT_WIDTH, HEADER_HEIGHT + PADDING * 2)
MainFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 100, -200)
MainFrame:SetFrameStrata("DIALOG")
MainFrame:SetClampedToScreen(true)
MainFrame:Hide()
MainFrame:SetBackdrop({
    bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\ChatFrame\\ChatFrameBackground",
    tile = false, edgeSize = 1,
    insets = { left = 0, right = 0, top = 0, bottom = 0 },
})
MainFrame:SetBackdropColor(0, 0, 0, 0.85)
MainFrame:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
MainFrame:SetMovable(true)
MainFrame:EnableMouse(true)
MainFrame:RegisterForDrag("LeftButton")

local function SavePosition()
    local point, _, rel, x, y = MainFrame:GetPoint()
    SimpleRollDB.pos = { point = point, rel = rel, x = x, y = y }
end

MainFrame:SetScript("OnDragStart", function(self) self:StartMoving() end)
MainFrame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    SavePosition()
end)

-- Scroll container
local scrollFrame = CreateFrame("ScrollFrame", "SimpleRollScrollFrame", MainFrame, "UIPanelScrollFrameTemplate")
scrollFrame:SetFrameLevel(MainFrame:GetFrameLevel() + 1)
local scrollContent = CreateFrame("Frame", nil, scrollFrame)
scrollContent:SetSize(1, 1)
scrollFrame:SetScrollChild(scrollContent)
scrollFrame:EnableMouseWheel(true)
scrollFrame:SetScript("OnMouseWheel", function(self, delta)
    local step = 18
    local max = math.max(0, scrollContent:GetHeight() - self:GetHeight())
    local target = self:GetVerticalScroll() - delta * step
    if target < 0 then target = 0 end
    if target > max then target = max end
    self:SetVerticalScroll(target)
end)

do
    local bar = _G["SimpleRollScrollFrameScrollBar"]
    if bar then
        bar:Hide()
        bar:HookScript("OnShow", function(self) self:Hide() end)
    end
end

-- Custom scroll indicators (right thin bar + bottom gold line)
local INDICATOR_WIDTH = 3
local sideBar = CreateFrame("Frame", nil, MainFrame)
sideBar:SetWidth(INDICATOR_WIDTH)
sideBar:SetPoint("TOPRIGHT", scrollFrame, "TOPRIGHT", 4, 0)
sideBar:SetPoint("BOTTOMRIGHT", scrollFrame, "BOTTOMRIGHT", 4, 0)
local sideBarBg = sideBar:CreateTexture(nil, "BACKGROUND")
sideBarBg:SetAllPoints()
sideBarBg:SetColorTexture(0.2, 0.2, 0.2, 0.6)
local sideBarThumb = sideBar:CreateTexture(nil, "OVERLAY")
sideBarThumb:SetColorTexture(0.85, 0.85, 0.85, 0.9)
sideBarThumb:SetWidth(INDICATOR_WIDTH)
sideBarThumb:Hide()

local bottomHL = MainFrame:CreateTexture(nil, "OVERLAY")
bottomHL:SetColorTexture(0.75, 0.6, 0.05, 0.95)
bottomHL:SetPoint("TOPLEFT", scrollFrame, "BOTTOMLEFT", 0, 0)
bottomHL:SetPoint("BOTTOMRIGHT", scrollFrame, "BOTTOMRIGHT", 0, -2)
bottomHL:Hide()

local function UpdateIndicatorThumb()
    local contentH = scrollContent:GetHeight()
    local viewH = scrollFrame:GetHeight()
    if contentH <= viewH or viewH <= 0 then
        sideBarThumb:Hide()
        bottomHL:Hide()
        return
    end
    sideBarThumb:Show()
    local trackH = sideBar:GetHeight()
    local thumbH = math.max(12, math.floor(trackH * viewH / contentH))
    sideBarThumb:SetHeight(thumbH)
    local maxScroll = contentH - viewH
    local offset = scrollFrame:GetVerticalScroll()
    local available = trackH - thumbH
    local y = (maxScroll > 0) and math.floor(available * offset / maxScroll) or 0
    sideBarThumb:ClearAllPoints()
    sideBarThumb:SetPoint("TOP", sideBar, "TOP", 0, -y)
    bottomHL:SetShown(offset < maxScroll - 0.5)
end

scrollFrame:SetScript("OnVerticalScroll", UpdateIndicatorThumb)

-- Countdown (shown after all rolls resolved, before auto-close)
local countdownText = MainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
countdownText:SetPoint("TOPRIGHT", MainFrame, "TOPRIGHT", -6, -1)
countdownText:SetTextColor(0.6, 0.6, 0.6)
countdownText:Hide()

-- ===========================================================
-- Roll application (shared by slot buttons and mass buttons)
-- ===========================================================
local function MarkRolled(slot, label, color)
    slot:SetScript("OnUpdate", nil)
    for _, btn in pairs(slot.Buttons) do btn:Hide() end
    slot.ResultText:SetText(label)
    slot.ResultText:SetTextColor(color[1], color[2], color[3])
    slot.ResultText:Show()
    slot.TimerBar:Hide()
end

local function MarkTimedOut(slot)
    slot.timedOut = true
    slot:SetScript("OnUpdate", nil)
    for _, btn in pairs(slot.Buttons) do btn:Hide() end
    slot.ResultText:SetText(L.pass)
    slot.ResultText:SetTextColor(COLOR_PASS[1], COLOR_PASS[2], COLOR_PASS[3])
    slot.ResultText:Show()
    slot.TimerBar:Hide()
end

local function ApplyRoll(slot, rollType, label, color)
    if not slot.rollID or slot.rolled or slot.timedOut then return false end
    slot.rolled = true
    if slot.rollID < TEST_ID_BASE then
        local ok = pcall(RollOnLoot, slot.rollID, rollType)
        if not ok then
            slot.rolled = false
            return false
        end
    end
    MarkRolled(slot, label, color)
    return true
end

-- ===========================================================
-- Mass action buttons
-- ===========================================================
local function MakeTipButton(text, tip)
    local btn = CreateFrame("Button", nil, MainFrame, "UIPanelButtonTemplate")
    btn:SetText(text)
    btn:SetSize(72, 24)
    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(tip, 1, 1, 1)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return btn
end

local function RollAll(rollType, label, color)
    for _, slot in pairs(activeRolls) do
        ApplyRoll(slot, rollType, label, color)
    end
    MainFrame:UpdateCloseButton()
end

local needAllBtn = MakeTipButton(L.need_all, L.need_all_tip)
needAllBtn:SetScript("OnClick", function() RollAll(ROLL_NEED, L.need, COLOR_NEED) end)

local greedAllBtn = MakeTipButton(L.greed_all, L.greed_all_tip)
greedAllBtn:SetScript("OnClick", function() RollAll(ROLL_GREED, L.greed, COLOR_GREED) end)

StaticPopupDialogs["SIMPLEROLL_PASS_ALL"] = {
    text = L.pass_all_confirm,
    button1 = YES,
    button2 = NO,
    OnAccept = function() RollAll(ROLL_PASS, L.pass, COLOR_PASS) end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
}
local passAllBtn = MakeTipButton(L.pass_all, L.pass_all_tip)
passAllBtn:SetScript("OnClick", function() StaticPopup_Show("SIMPLEROLL_PASS_ALL") end)

-- ===========================================================
-- Close / countdown visibility
-- ===========================================================
local function CloseAllSlots()
    for rollID, slot in pairs(activeRolls) do
        ReleaseSlot(slot)
        activeRolls[rollID] = nil
    end
    MainFrame.closeAt = nil
    MainFrame:SetScript("OnUpdate", nil)
    countdownText:Hide()
    MainFrame:UpdateLayout()
end

local function FrameCountdown(self)
    if not self.closeAt then return end
    local rem = self.closeAt - GetTime()
    if rem <= 0 then
        CloseAllSlots()
    else
        countdownText:SetText(string.format(L.seconds, math.ceil(rem)))
        countdownText:Show()
    end
end

function MainFrame:UpdateCloseButton()
    local anyPending = false
    for _, slot in pairs(activeRolls) do
        if slot:IsShown() and not slot.rolled and not slot.timedOut then
            anyPending = true
            break
        end
    end
    needAllBtn:SetShown(anyPending)
    greedAllBtn:SetShown(anyPending)
    passAllBtn:SetShown(anyPending)
    if anyPending then
        self.closeAt = nil
        self:SetScript("OnUpdate", nil)
        countdownText:Hide()
    else
        if not self.closeAt then
            self.closeAt = GetTime() + CLOSE_DELAY
        end
        self:SetScript("OnUpdate", FrameCountdown)
    end
end

-- ===========================================================
-- Slot construction
-- ===========================================================
local BUTTON_DEFS = {
    { key = "pass",  size = CLOSE_BUTTON_SIZE, rollType = ROLL_PASS,  label = L.pass,  color = COLOR_PASS,
      normal = "Interface\\Buttons\\UI-Panel-MinimizeButton-Up",
      pushed = "Interface\\Buttons\\UI-Panel-MinimizeButton-Down",
      highlight = "Interface\\Buttons\\UI-Panel-MinimizeButton-Highlight" },
    { key = "greed", size = BUTTON_SIZE,       rollType = ROLL_GREED, label = L.greed, color = COLOR_GREED,
      normal = "Interface\\Buttons\\UI-GroupLoot-Coin-Up",
      pushed = "Interface\\Buttons\\UI-GroupLoot-Coin-Down",
      highlight = "Interface\\Buttons\\UI-GroupLoot-Coin-Highlight" },
    { key = "need",  size = BUTTON_SIZE,       rollType = ROLL_NEED,  label = L.need,  color = COLOR_NEED,
      normal = "Interface\\Buttons\\UI-GroupLoot-Dice-Up",
      pushed = "Interface\\Buttons\\UI-GroupLoot-Dice-Down",
      highlight = "Interface\\Buttons\\UI-GroupLoot-Dice-Highlight" },
}

local function ShowSlotTooltip(slot)
    GameTooltip:SetOwner(slot, "ANCHOR_TOP", 0, 4)
    local isTest = slot.rollID and slot.rollID >= TEST_ID_BASE
    if not isTest and slot.rollID and GetLootRollItemInfo then
        local ok = pcall(GameTooltip.SetLootRollItem, GameTooltip, slot.rollID)
        if ok and GameTooltip:NumLines() > 0 then
            if IsShiftKeyDown() and GameTooltip_ShowCompareItem then
                GameTooltip_ShowCompareItem()
            end
            GameTooltip:Show()
            return
        end
    end
    if slot.itemLink then
        GameTooltip:SetHyperlink(slot.itemLink)
        if IsShiftKeyDown() and GameTooltip_ShowCompareItem then
            GameTooltip_ShowCompareItem()
        end
    elseif slot.ItemName then
        GameTooltip:SetText(slot.ItemName:GetText() or "", 1, 1, 1)
    end
    GameTooltip:Show()
end

local function CreateSlot()
    local slot = CreateFrame("Frame", nil, scrollContent, BackdropTemplateMixin and "BackdropTemplate")
    slot:SetHeight(SLOT_HEIGHT)
    slot:EnableMouse(true)
    slot:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\ChatFrame\\ChatFrameBackground",
        tile = false, edgeSize = 1,
        insets = { left = 0, right = 0, top = 0, bottom = 0 },
    })
    slot:SetBackdropColor(0.08, 0.08, 0.08, 0.7)
    slot:SetBackdropBorderColor(0.25, 0.25, 0.25, 1)
    slot:RegisterForDrag("LeftButton")
    slot:SetScript("OnDragStart", function() MainFrame:StartMoving() end)
    slot:SetScript("OnDragStop", function()
        MainFrame:StopMovingOrSizing()
        SavePosition()
    end)

    -- Icon
    local iconFrame = CreateFrame("Button", nil, slot)
    iconFrame:SetSize(ICON_SIZE + 6, ICON_SIZE + 6)
    iconFrame:SetPoint("LEFT", 5, 0)

    local icon = iconFrame:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", 3, -3)
    icon:SetPoint("BOTTOMRIGHT", -3, 3)
    slot.Icon = icon

    iconFrame:SetScript("OnEnter", function(self) ShowSlotTooltip(self:GetParent()) end)
    iconFrame:SetScript("OnLeave", function()
        GameTooltip:Hide()
        if ShoppingTooltip1 then ShoppingTooltip1:Hide() end
        if ShoppingTooltip2 then ShoppingTooltip2:Hide() end
    end)

    -- Timer bar: manual texture (StatusBar pixel-snaps fill width at thin heights)
    local timerBar = CreateFrame("Frame", nil, slot)
    timerBar:SetHeight(2)
    timerBar:SetPoint("BOTTOMLEFT", slot, "BOTTOMLEFT", 55, 5)
    timerBar:SetPoint("BOTTOMRIGHT", slot, "BOTTOMRIGHT", -6, 5)
    local timerBg = timerBar:CreateTexture(nil, "BACKGROUND")
    timerBg:SetAllPoints()
    timerBg:SetColorTexture(0, 0, 0, 0.4)
    local timerFill = timerBar:CreateTexture(nil, "ARTWORK")
    timerFill:SetColorTexture(0.1, 0.5, 0.15)
    timerFill:SetPoint("TOPLEFT", timerBar, "TOPLEFT", 0, 0)
    timerFill:SetPoint("BOTTOMLEFT", timerBar, "BOTTOMLEFT", 0, 0)
    timerFill:SetWidth(0.01)
    slot.TimerBar = timerBar
    slot.TimerFill = timerFill

    -- Item name (1-line, offset up to clear timer bar)
    local itemName = slot:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    itemName:SetPoint("LEFT", iconFrame, "RIGHT", 6, 3)
    itemName:SetJustifyH("LEFT")
    itemName:SetJustifyV("MIDDLE")
    itemName:SetWordWrap(false)
    itemName:SetHeight(16)
    if itemName.SetMaxLines then itemName:SetMaxLines(1) end
    slot.ItemName = itemName

    -- Roll buttons: need / greed / pass in a horizontal row, anchored from the right
    slot.Buttons = {}
    for _, def in ipairs(BUTTON_DEFS) do
        local btn = CreateFrame("Button", nil, slot)
        btn:SetSize(def.size, def.size)
        btn:SetNormalTexture(def.normal)
        btn:SetPushedTexture(def.pushed)
        btn:SetHighlightTexture(def.highlight, "ADD")
        btn:SetScript("OnClick", function()
            if ApplyRoll(slot, def.rollType, def.label, def.color) then
                MainFrame:UpdateCloseButton()
            end
        end)
        slot.Buttons[def.key] = btn
    end
    slot.Buttons.pass:SetPoint("TOPRIGHT", slot, "TOPRIGHT", 0, 0)
    slot.Buttons.greed:SetPoint("RIGHT", slot, "RIGHT", -6 - CLOSE_BUTTON_SIZE, 3)
    slot.Buttons.need:SetPoint("RIGHT", slot.Buttons.greed, "LEFT", -2, 0)

    -- Result text (occupies button strip after rolling)
    local resultText = slot:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    resultText:SetJustifyH("RIGHT")
    resultText:SetWordWrap(false)
    resultText:Hide()
    slot.ResultText = resultText

    local leftBtn = slot.Buttons.need
    itemName:SetPoint("RIGHT", leftBtn, "LEFT", -6, 0)
    resultText:SetPoint("LEFT", leftBtn, "LEFT", 0, 0)
    resultText:SetPoint("RIGHT", slot, "RIGHT", -6, 3)

    return slot
end

local function AcquireSlot()
    return table.remove(slotPool) or CreateSlot()
end

ReleaseSlot = function(slot)
    slot:Hide()
    slot:ClearAllPoints()
    slot:SetScript("OnUpdate", nil)
    slot.rollID = nil
    slot.rolled = nil
    slot.itemLink = nil
    slot.addedOrder = nil
    slot.timeLeft = nil
    slot.totalTime = nil
    slot.expireAt = nil
    slot.timedOut = nil
    slot.ResultText:SetText("")
    slot.ResultText:Hide()
    slot.Icon:SetTexture(nil)
    slot:SetBackdropBorderColor(0.25, 0.25, 0.25, 1)
    slot.ItemName:SetText("")
    slot.ItemName:Show()
    slot.TimerFill:SetWidth(0.01)
    slot.TimerBar:Show()
    for _, btn in pairs(slot.Buttons) do
        btn:Show()
        btn:Enable()
        btn:SetAlpha(1)
    end
    table.insert(slotPool, slot)
end

-- ===========================================================
-- Layout
-- ===========================================================
function MainFrame:UpdateLayout()
    local visible = {}
    for _, slot in pairs(activeRolls) do
        if slot:IsShown() then visible[#visible + 1] = slot end
    end
    if #visible == 0 then
        self:Hide()
        return
    end
    table.sort(visible, function(a, b) return (a.addedOrder or 0) < (b.addedOrder or 0) end)

    local n = #visible
    local visibleCount = MAX_VISIBLE_SLOTS
    local row = SLOT_HEIGHT + SLOT_SPACING
    local visibleH = visibleCount * row - SLOT_SPACING
    local contentH = n * row - SLOT_SPACING
    local needsScroll = n > MAX_VISIBLE_SLOTS

    self:SetWidth(DEFAULT_WIDTH)

    -- Reserve fixed right margin for the custom scroll indicator
    local scrollRight = RIGHT_MARGIN
    scrollFrame:ClearAllPoints()
    scrollFrame:SetPoint("TOPLEFT", self, "TOPLEFT", LEFT_PADDING, -(HEADER_HEIGHT + 4))
    scrollFrame:SetPoint("TOPRIGHT", self, "TOPRIGHT", -scrollRight, -(HEADER_HEIGHT + 4))
    scrollFrame:SetHeight(visibleH)

    local scrollW = DEFAULT_WIDTH - LEFT_PADDING - scrollRight
    scrollContent:SetSize(scrollW, contentH)

    for i, slot in ipairs(visible) do
        slot:ClearAllPoints()
        local yOff = -((i - 1) * row)
        slot:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", 0, yOff)
        slot:SetPoint("TOPRIGHT", scrollContent, "TOPRIGHT", 0, yOff)
    end

    local maxScroll = math.max(0, contentH - visibleH)
    UpdateIndicatorThumb()

    self:SetHeight(HEADER_HEIGHT + 4 + visibleH + FOOTER_HEIGHT + PADDING)

    needAllBtn:ClearAllPoints()
    needAllBtn:SetPoint("BOTTOMLEFT", self, "BOTTOMLEFT", LEFT_PADDING, 16)
    greedAllBtn:ClearAllPoints()
    greedAllBtn:SetPoint("LEFT", needAllBtn, "RIGHT", 4, 0)
    passAllBtn:ClearAllPoints()
    passAllBtn:SetPoint("LEFT", greedAllBtn, "RIGHT", 4, 0)

    -- Preserve user's current scroll position; only clamp if it exceeds new max
    -- (avoids hijacking the view and reducing click misses on items the user is looking at)
    local current = scrollFrame:GetVerticalScroll()
    if current > maxScroll then current = maxScroll end
    scrollFrame:SetVerticalScroll(current)

    self:Show()
end

-- ===========================================================
-- Per-slot update (timeout detection + auto-close)
-- ===========================================================
local function SlotOnUpdate(self, elapsed)
    self.timeLeft = self.timeLeft - elapsed
    if self.timeLeft <= 0 then
        self.timeLeft = 0
        MarkTimedOut(self)
        MainFrame:UpdateCloseButton()
        return
    end
    local w = self.TimerBar:GetWidth()
    if w > 0 then
        self.TimerFill:SetWidth(math.max(0.01, w * (self.timeLeft / self.totalTime)))
    end
end

-- ===========================================================
-- Add roll
-- ===========================================================
local function SetButtonEnabled(btn, enabled)
    if not btn then return end
    if enabled then
        btn:Enable(); btn:SetAlpha(1)
    else
        btn:Disable(); btn:SetAlpha(0.3)
    end
end

local function AddRoll(rollID, texture, name, quality, timeLeft, canNeed, canGreed, itemLink)
    if activeRolls[rollID] then return end

    local slot = AcquireSlot()
    slot.rollID = rollID
    slot.rolled = false
    slot.itemLink = itemLink
    slot.addedOrder = nextAddedOrder
    nextAddedOrder = nextAddedOrder + 1
    slot.timeLeft = timeLeft or 60
    slot.totalTime = math.max(slot.timeLeft, 60)

    if texture then slot.Icon:SetTexture(texture) end
    slot.ItemName:SetText(name or "???")
    if quality then
        local r, g, b = GetItemQualityColor(quality)
        slot.ItemName:SetTextColor(r, g, b)
    else
        slot.ItemName:SetTextColor(1, 1, 1)
    end

    local w = slot.TimerBar:GetWidth()
    if w > 0 then
        slot.TimerFill:SetWidth(math.max(0.01, w * (slot.timeLeft / slot.totalTime)))
    end

    SetButtonEnabled(slot.Buttons.need, canNeed)
    SetButtonEnabled(slot.Buttons.greed, canGreed)
    SetButtonEnabled(slot.Buttons.pass, true)

    slot:SetScript("OnUpdate", SlotOnUpdate)
    slot:Show()
    activeRolls[rollID] = slot
    MainFrame:UpdateLayout()
    MainFrame:UpdateCloseButton()
end

-- ===========================================================
-- Blizzard loot frame suppression
-- ===========================================================
local function HideBlizzardRollFrames()
    UIParent:UnregisterEvent("START_LOOT_ROLL")
    UIParent:UnregisterEvent("CANCEL_LOOT_ROLL")
    local max = NUM_GROUP_LOOT_FRAMES or 4
    for i = 1, max do
        local f = _G["GroupLootFrame" .. i]
        if f and not f._SR_Hooked then
            f:HookScript("OnShow", function(self) self:Hide() end)
            f._SR_Hooked = true
        end
    end
end

-- ===========================================================
-- Resolve roll data (handles item cache delay)
-- ===========================================================
local function NormalizeTime(t)
    if type(t) == "number" then return t / 1000 end
    return 60
end

local function ResolveRoll(rollID)
    local texture, name, _, quality, _, canNeed, canGreed = GetLootRollItemInfo(rollID)
    local timeLeft = GetLootRollTimeLeft(rollID)
    local itemLink = GetLootRollItemLink and GetLootRollItemLink(rollID)

    if texture and texture ~= 0 and name then
        AddRoll(rollID, texture, name, quality, NormalizeTime(timeLeft), canNeed, canGreed, itemLink)
        pendingRolls[rollID] = nil
        return
    end
    if itemLink then
        local iName, _, iQuality, _, _, _, _, _, _, iTexture = GetItemInfo(itemLink)
        if iTexture then
            AddRoll(rollID, iTexture, iName or name, iQuality or quality, NormalizeTime(timeLeft), canNeed, canGreed, itemLink)
            pendingRolls[rollID] = nil
            return
        end
    end
    pendingRolls[rollID] = { name = name, quality = quality, canNeed = canNeed, canGreed = canGreed, itemLink = itemLink }
end

-- ===========================================================
-- Test rolls (/srsr preview)
-- ===========================================================
local testItemIDs = {
    2589,    -- Linen Cloth (common)
    21877,   -- Netherweave Cloth (common)
    2033,    -- Silver-thread Gloves (uncommon)
    15196,   -- Forest Leather Bracers (uncommon)
    28186,   -- Pauldrons of the Unrelenting (rare)
    23572,   -- Primal Nether (rare)
    18816,   -- Felstriker (epic)
    18348,   -- Benediction (epic)
    19019,   -- Thunderfury (legendary)
}
local testNextIndex = 1

local function TestRolls(count, retryNum)
    count = count or 3
    retryNum = retryNum or 0

    if testNextIndex > #testItemIDs then
        for _, slot in pairs(activeRolls) do
            ReleaseSlot(slot)
        end
        wipe(activeRolls)
        testNextIndex = 1
        MainFrame:UpdateLayout()
        print("|cFFFFD700SimpleRoll:|r Reset. Run again to preview.")
        return
    end

    local target = math.min(count, #testItemIDs - testNextIndex + 1)
    for i = testNextIndex, testNextIndex + target - 1 do
        GetItemInfo(testItemIDs[i])
    end

    local added = 0
    for i = testNextIndex, testNextIndex + target - 1 do
        local name, link, quality, _, _, _, _, _, _, icon = GetItemInfo(testItemIDs[i])
        if name and icon then
            added = added + 1
            AddRoll(TEST_ID_BASE + i, icon, name, quality, 30, true, true, link)
        end
    end

    if added < target and retryNum < 3 then
        C_Timer.After(0.5, function() TestRolls(count, retryNum + 1) end)
        if retryNum == 0 then
            print("|cFFFFD700SimpleRoll:|r Loading item cache...")
        end
        return
    end

    testNextIndex = testNextIndex + target
    print(string.format(L.test_spawned, added))
end

-- ===========================================================
-- Events
-- ===========================================================
EventFrame:RegisterEvent("ADDON_LOADED")
EventFrame:RegisterEvent("PLAYER_LOGIN")
EventFrame:RegisterEvent("START_LOOT_ROLL")
EventFrame:RegisterEvent("CANCEL_LOOT_ROLL")
EventFrame:RegisterEvent("GET_ITEM_INFO_RECEIVED")

EventFrame:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
        SimpleRollDB = SimpleRollDB or {}
        local pos = SimpleRollDB.pos
        if pos then
            MainFrame:ClearAllPoints()
            MainFrame:SetPoint(pos.point or "TOPLEFT", UIParent, pos.rel or "TOPLEFT", pos.x or 100, pos.y or -200)
        end

    elseif event == "PLAYER_LOGIN" then
        C_Timer.After(0.5, HideBlizzardRollFrames)
        C_Timer.After(1.0, function()
            for i = 1, 300 do
                local ok, time = pcall(GetLootRollTimeLeft, i)
                if ok and time and time > 0 and time < 300000 then
                    ResolveRoll(i)
                end
            end
        end)

    elseif event == "START_LOOT_ROLL" then
        local rollID = arg1
        C_Timer.After(0.05, function() ResolveRoll(rollID) end)

    elseif event == "GET_ITEM_INFO_RECEIVED" then
        local itemID = arg1
        if itemID then
            for rollID, info in pairs(pendingRolls) do
                local link = info.itemLink
                if link and tonumber(link:match("item:(%d+)")) == itemID then
                    ResolveRoll(rollID)
                end
            end
        end

    elseif event == "CANCEL_LOOT_ROLL" then
        pendingRolls[arg1] = nil
        local slot = activeRolls[arg1]
        if slot then
            if not slot.rolled and not slot.timedOut then
                MarkTimedOut(slot)
            end
            MainFrame:UpdateCloseButton()
        end
    end
end)

-- ===========================================================
-- Slash command
-- ===========================================================
SLASH_SIMPLEROLL1 = "/srsr"
SLASH_SIMPLEROLL2 = "/simpleroll"
SlashCmdList["SIMPLEROLL"] = function(msg)
    local cmd = (msg or ""):lower():match("^(%S*)")
    if cmd == "" then
        TestRolls(math.random(3, 5))
    elseif cmd == "reset" then
        wipe(SimpleRollDB)
        MainFrame:ClearAllPoints()
        MainFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 100, -200)
        print("|cFFFFD700SimpleRoll:|r Position reset.")
    else
        print("|cFFFFD700SimpleRoll:|r")
        print("  /srsr - " .. L.cmd_preview)
        print("  /srsr " .. L.cmd_reset)
    end
end
