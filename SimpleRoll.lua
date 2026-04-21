local ADDON_NAME = "SimpleRoll"

-- Localization
local PREFIX = "|cFFFFD700SimpleRoll:|r "
local locale = GetLocale()

local L = {
    NEED             = "Need",
    GREED            = "Greed",
    PASS             = "Pass",
    SECONDS_FMT      = "%ds",
    TEST_SPAWNED     = "Spawned %d preview rolls",
    TEST_RESET       = "Reset. Run again to preview.",
    LOADING_CACHE    = "Loading item cache...",
    POS_RESET        = "Position reset.",
    HELP_HEADER      = "Commands:",
    CMD_PREVIEW      = "Preview (random 3~5 items)",
    CMD_PREVIEW_N    = "<N> - Preview N items (e.g. /srsr 1)",
    CMD_RESET        = "reset - Reset position",
    OPTIONS_TITLE    = "SimpleRoll Options",
    OPT_EXPAND       = "Expand all (no scroll)",
    OPT_EXPAND_DESC  = "When checked, every item is shown at once and the frame grows in height",
    OPT_INSTANT      = "Roll instantly (no confirmation)",
    OPT_INSTANT_DESC = "Hide the confirmation popup before rolling.",
    OPT_CLOSE_DELAY  = "Close instantly",
    OPT_CLOSE_DELAY_DESC = "Close the frame immediately when all rolls are resolved. Uncheck to pick a delay in seconds.",
}

if locale == "koKR" then
    L.NEED             = "입찰"
    L.GREED            = "차비"
    L.PASS             = "포기"
    L.SECONDS_FMT      = "%d초"
    L.TEST_SPAWNED     = "미리보기 %d개 생성"
    L.TEST_RESET       = "초기화됨. 다시 실행하여 미리보기."
    L.LOADING_CACHE    = "아이템 캐시 로딩 중..."
    L.POS_RESET        = "위치 초기화됨."
    L.HELP_HEADER      = "명령어:"
    L.CMD_PREVIEW      = "미리보기 (랜덤 3~5개)"
    L.CMD_PREVIEW_N    = "<N> - N개 미리보기 (예: /srsr 1)"
    L.CMD_RESET        = "reset - 위치 초기화"
    L.OPTIONS_TITLE    = "SimpleRoll 옵션"
    L.OPT_EXPAND       = "전체 펼침 (스크롤 끄기)"
    L.OPT_EXPAND_DESC  = "체크하면 모든 아이템을 한꺼번에 표시"
    L.OPT_INSTANT      = "즉시 선택"
    L.OPT_INSTANT_DESC = "주사위 전 확인 팝업을 숨깁니다."
    L.OPT_CLOSE_DELAY  = "즉시 닫기"
    L.OPT_CLOSE_DELAY_DESC = "주사위가 끝나면 즉시 닫거나 지연시간을 설정합니다."
end

if locale == "zhCN" then
    L.NEED             = "需求"
    L.GREED            = "贪婪"
    L.PASS             = "放弃"
    L.SECONDS_FMT      = "%d秒"
    L.TEST_SPAWNED     = "生成 %d 个预览掷骰"
    L.TEST_RESET       = "已重置。再次运行以预览。"
    L.LOADING_CACHE    = "正在加载物品缓存..."
    L.POS_RESET        = "位置已重置。"
    L.HELP_HEADER      = "命令："
    L.CMD_PREVIEW      = "预览 (随机 3~5 个)"
    L.CMD_PREVIEW_N    = "<N> - 预览 N 个 (例: /srsr 1)"
    L.CMD_RESET        = "reset - 重置位置"
    L.OPTIONS_TITLE    = "SimpleRoll 选项"
    L.OPT_EXPAND       = "全部展开（禁用滚动）"
    L.OPT_EXPAND_DESC  = "勾选后同时显示所有物品，框体高度扩展"
    L.OPT_INSTANT      = "立即掷骰（跳过确认）"
    L.OPT_INSTANT_DESC = "掷骰前隐藏确认弹窗。"
    L.OPT_CLOSE_DELAY  = "立即关闭"
    L.OPT_CLOSE_DELAY_DESC = "所有掷骰结束后立即关闭。取消勾选则选择等待秒数。"
end

if locale == "deDE" then
    L.NEED             = "Bedarf"
    L.GREED            = "Gier"
    L.PASS             = "Passen"
    L.SECONDS_FMT      = "%ds"
    L.TEST_SPAWNED     = "%d Vorschau-Würfe erzeugt"
    L.TEST_RESET       = "Zurückgesetzt. Erneut ausführen für Vorschau."
    L.LOADING_CACHE    = "Lade Item-Cache..."
    L.POS_RESET        = "Position zurückgesetzt."
    L.HELP_HEADER      = "Befehle:"
    L.CMD_PREVIEW      = "Vorschau (zufällig 3~5 Gegenstände)"
    L.CMD_PREVIEW_N    = "<N> - Vorschau N Gegenstände (z.B. /srsr 1)"
    L.CMD_RESET        = "reset - Position zurücksetzen"
    L.OPTIONS_TITLE    = "SimpleRoll Optionen"
    L.OPT_EXPAND       = "Alle anzeigen (kein Scrollen)"
    L.OPT_EXPAND_DESC  = "Wenn aktiviert: alle Gegenstände gleichzeitig (Frame wächst)"
    L.OPT_INSTANT      = "Sofort würfeln (ohne Bestätigung)"
    L.OPT_INSTANT_DESC = "Bestätigungsdialog vor dem Würfeln ausblenden."
    L.OPT_CLOSE_DELAY  = "Sofort schließen"
    L.OPT_CLOSE_DELAY_DESC = "Nach Ende aller Würfe sofort schließen. Deaktivieren, um eine Verzögerung in Sekunden zu wählen."
end

-- Constants
local DEFAULT_WIDTH      = 277
local SLOT_HEIGHT        = 40
local HEADER_HEIGHT      = 8
local FOOTER_HEIGHT      = 12
local PADDING            = 14
local LEFT_PADDING       = 4
local BUTTON_SIZE        = 26
local CLOSE_BUTTON_SIZE  = 18
local ICON_SIZE          = 30
local DEFAULT_CLOSE_DELAY = 3
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
local GetAddOnMetadata = (C_AddOns and C_AddOns.GetAddOnMetadata) or _G.GetAddOnMetadata
local VERSION = (GetAddOnMetadata and GetAddOnMetadata(ADDON_NAME, "Version")) or ""

-- State
local activeRolls = {}
local pendingRolls = {}
local slotPool = {}
local nextAddedOrder = 1
local ReleaseSlot  -- forward

local EventFrame = CreateFrame("Frame", ADDON_NAME .. "Events", UIParent)

-- Main Frame
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

-- Roll application
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
    slot.ResultText:SetText(L.PASS)
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

-- Close / countdown visibility
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
        countdownText:SetText(string.format(L.SECONDS_FMT, math.ceil(rem)))
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
    if anyPending then
        self.closeAt = nil
        self:SetScript("OnUpdate", nil)
        countdownText:Hide()
    else
        if not self.closeAt then
            local delay
            if SimpleRollDB and SimpleRollDB.instantClose then
                delay = 0
            else
                delay = (SimpleRollDB and SimpleRollDB.closeDelay) or DEFAULT_CLOSE_DELAY
            end
            self.closeAt = GetTime() + delay
        end
        self:SetScript("OnUpdate", FrameCountdown)
    end
end

-- Options Frame
local OptionsFrame = CreateFrame("Frame", "SimpleRollOptionsFrame", UIParent, BackdropTemplateMixin and "BackdropTemplate")
OptionsFrame:SetSize(340, 370)
OptionsFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
OptionsFrame:SetFrameStrata("DIALOG")
OptionsFrame:SetClampedToScreen(true)
OptionsFrame:Hide()
OptionsFrame:SetBackdrop({
    bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\ChatFrame\\ChatFrameBackground",
    tile = false, edgeSize = 1,
    insets = { left = 0, right = 0, top = 0, bottom = 0 },
})
OptionsFrame:SetBackdropColor(0, 0, 0, 0.9)
OptionsFrame:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
OptionsFrame:SetMovable(true)
OptionsFrame:EnableMouse(true)
OptionsFrame:RegisterForDrag("LeftButton")
OptionsFrame:SetScript("OnDragStart", function(self) self:StartMoving() end)
OptionsFrame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local point, _, rel, x, y = self:GetPoint()
    SimpleRollDB.optionsPos = { point = point, rel = rel, x = x, y = y }
end)

local optTitleBar = OptionsFrame:CreateTexture(nil, "ARTWORK")
optTitleBar:SetColorTexture(0.75, 0.6, 0.05, 0.9)
optTitleBar:SetPoint("TOPLEFT", 0, 0)
optTitleBar:SetPoint("TOPRIGHT", 0, 0)
optTitleBar:SetHeight(22)

local optTitle = OptionsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
optTitle:SetPoint("TOP", OptionsFrame, "TOP", 0, -4)
optTitle:SetText(L.OPTIONS_TITLE)
optTitle:SetTextColor(1, 1, 1)

local optClose = CreateFrame("Button", nil, OptionsFrame, "UIPanelCloseButton")
optClose:SetSize(24, 24)
optClose:SetPoint("TOPRIGHT", OptionsFrame, "TOPRIGHT", 2, 2)

local optVersion = OptionsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
optVersion:SetPoint("BOTTOMRIGHT", OptionsFrame, "BOTTOMRIGHT", -8, 6)
optVersion:SetTextColor(0.45, 0.45, 0.45)
if VERSION ~= "" then
    optVersion:SetText("v" .. VERSION)
end

-- Content area: reserved for future options. Anchor children to OptionsFrame.Content.
local optContent = CreateFrame("Frame", nil, OptionsFrame)
optContent:SetPoint("TOPLEFT", OptionsFrame, "TOPLEFT", 12, -32)
optContent:SetPoint("BOTTOMRIGHT", OptionsFrame, "BOTTOMRIGHT", -12, 12)
OptionsFrame.Content = optContent

-- Option: expand-all (stacked) view vs scroll view. Default expandAll = true
-- (stacked); legacy `useScroll` key is migrated in ADDON_LOADED.
local optExpandCheck = CreateFrame("CheckButton", "SimpleRollOptExpandCheck", optContent, "UICheckButtonTemplate")
optExpandCheck:SetSize(24, 24)
optExpandCheck:SetPoint("TOPLEFT", optContent, "TOPLEFT", 0, 0)

local optExpandLabel = optContent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
optExpandLabel:SetPoint("LEFT", optExpandCheck, "RIGHT", 4, 0)
optExpandLabel:SetText(L.OPT_EXPAND)

local optExpandDesc = optContent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
optExpandDesc:SetPoint("TOPLEFT", optExpandCheck, "BOTTOMLEFT", 2, -2)
optExpandDesc:SetPoint("RIGHT", optContent, "RIGHT", 0, 0)
optExpandDesc:SetJustifyH("LEFT")
optExpandDesc:SetText(L.OPT_EXPAND_DESC)
optExpandDesc:SetTextColor(0.7, 0.7, 0.7)

optExpandCheck:SetScript("OnShow", function(self)
    self:SetChecked(not (SimpleRollDB and SimpleRollDB.expandAll == false))
end)
optExpandCheck:SetScript("OnClick", function(self)
    SimpleRollDB = SimpleRollDB or {}
    SimpleRollDB.expandAll = self:GetChecked() and true or false
    if MainFrame:IsShown() then
        MainFrame:UpdateLayout()
    end
end)

-- Option: when checked, BoP CONFIRM_LOOT_ROLL is auto-confirmed; when unchecked,
-- Blizzard's default popup is shown. Legacy `confirmIndividual` key is migrated
-- in ADDON_LOADED.
local optInstantCheck = CreateFrame("CheckButton", "SimpleRollOptInstantCheck", optContent, "UICheckButtonTemplate")
optInstantCheck:SetSize(24, 24)
optInstantCheck:SetPoint("TOPLEFT", optExpandDesc, "BOTTOMLEFT", -2, -12)

local optInstantLabel = optContent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
optInstantLabel:SetPoint("LEFT", optInstantCheck, "RIGHT", 4, 0)
optInstantLabel:SetText(L.OPT_INSTANT)

local optInstantDesc = optContent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
optInstantDesc:SetPoint("TOPLEFT", optInstantCheck, "BOTTOMLEFT", 2, -2)
optInstantDesc:SetPoint("RIGHT", optContent, "RIGHT", 0, 0)
optInstantDesc:SetJustifyH("LEFT")
optInstantDesc:SetText(L.OPT_INSTANT_DESC)
optInstantDesc:SetTextColor(0.7, 0.7, 0.7)

optInstantCheck:SetScript("OnShow", function(self)
    self:SetChecked(not (SimpleRollDB and SimpleRollDB.instantRoll == false))
end)
optInstantCheck:SetScript("OnClick", function(self)
    SimpleRollDB = SimpleRollDB or {}
    SimpleRollDB.instantRoll = self:GetChecked() and true or false
end)

-- Close-instantly checkbox + 1~5 second buttons (shown dimmed when instant is checked)
local optInstantCloseCheck = CreateFrame("CheckButton", "SimpleRollOptInstantCloseCheck", optContent, "UICheckButtonTemplate")
optInstantCloseCheck:SetSize(24, 24)
optInstantCloseCheck:SetPoint("TOPLEFT", optInstantDesc, "BOTTOMLEFT", -2, -12)

local optInstantCloseLabel = optContent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
optInstantCloseLabel:SetPoint("LEFT", optInstantCloseCheck, "RIGHT", 4, 0)
optInstantCloseLabel:SetText(L.OPT_CLOSE_DELAY)

local optInstantCloseDesc = optContent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
optInstantCloseDesc:SetPoint("TOPLEFT", optInstantCloseCheck, "BOTTOMLEFT", 2, -2)
optInstantCloseDesc:SetPoint("RIGHT", optContent, "RIGHT", 0, 0)
optInstantCloseDesc:SetJustifyH("LEFT")
optInstantCloseDesc:SetText(L.OPT_CLOSE_DELAY_DESC)
optInstantCloseDesc:SetTextColor(0.7, 0.7, 0.7)

local delayButtons = {}
local function RefreshDelayButtons()
    local instant = SimpleRollDB and SimpleRollDB.instantClose
    local current = (SimpleRollDB and SimpleRollDB.closeDelay) or DEFAULT_CLOSE_DELAY
    for v, btn in pairs(delayButtons) do
        if instant then
            btn:Disable()
            btn:SetAlpha(0.25)
        else
            btn:Enable()
            if v == current then
                btn:SetAlpha(1)
            else
                btn:SetAlpha(0.4)
            end
        end
    end
end

local DELAY_BTN_W = 48
local DELAY_BTN_GAP = 2
for i = 1, 5 do
    local btn = CreateFrame("Button", nil, optContent, "UIPanelButtonTemplate")
    btn:SetSize(DELAY_BTN_W, 22)
    if i == 1 then
        btn:SetPoint("TOPLEFT", optInstantCloseDesc, "BOTTOMLEFT", 2, -10)
    else
        btn:SetPoint("LEFT", delayButtons[i - 1], "RIGHT", DELAY_BTN_GAP, 0)
    end
    btn:SetText(string.format(L.SECONDS_FMT, i))
    btn:SetScript("OnClick", function()
        SimpleRollDB = SimpleRollDB or {}
        SimpleRollDB.closeDelay = i
        RefreshDelayButtons()
    end)
    delayButtons[i] = btn
end

optInstantCloseCheck:SetScript("OnClick", function(self)
    SimpleRollDB = SimpleRollDB or {}
    SimpleRollDB.instantClose = self:GetChecked() and true or false
    RefreshDelayButtons()
end)

OptionsFrame:HookScript("OnShow", function()
    optInstantCloseCheck:SetChecked(SimpleRollDB and SimpleRollDB.instantClose and true or false)
    RefreshDelayButtons()
end)

-- Slot construction
local BUTTON_DEFS = {
    { key = "pass",  size = CLOSE_BUTTON_SIZE, rollType = ROLL_PASS,  label = L.PASS,  color = COLOR_PASS,
      normal = "Interface\\Buttons\\UI-Panel-MinimizeButton-Up",
      pushed = "Interface\\Buttons\\UI-Panel-MinimizeButton-Down",
      highlight = "Interface\\Buttons\\UI-Panel-MinimizeButton-Highlight" },
    { key = "greed", size = BUTTON_SIZE,       rollType = ROLL_GREED, label = L.GREED, color = COLOR_GREED,
      normal = "Interface\\Buttons\\UI-GroupLoot-Coin-Up",
      pushed = "Interface\\Buttons\\UI-GroupLoot-Coin-Down",
      highlight = "Interface\\Buttons\\UI-GroupLoot-Coin-Highlight" },
    { key = "need",  size = BUTTON_SIZE,       rollType = ROLL_NEED,  label = L.NEED,  color = COLOR_NEED,
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

-- Layout
function MainFrame:UpdateLayout()
    local visible = {}
    for _, slot in pairs(activeRolls) do
        if slot:IsShown() then visible[#visible + 1] = slot end
    end
    if #visible == 0 then
        self:Hide()
        self._growUp = nil  -- recompute direction next time the frame opens
        return
    end
    table.sort(visible, function(a, b) return (a.addedOrder or 0) < (b.addedOrder or 0) end)

    local n = #visible
    local scrollMode = SimpleRollDB and SimpleRollDB.expandAll == false
    local visibleCount = scrollMode and MAX_VISIBLE_SLOTS or n
    local row = SLOT_HEIGHT + SLOT_SPACING
    local visibleH = visibleCount * row - SLOT_SPACING
    local contentH = n * row - SLOT_SPACING

    self:SetWidth(DEFAULT_WIDTH)

    -- In expand mode, anchor and grow toward the screen edge with more room so
    -- existing slots don't shift under the cursor (SetClampedToScreen would
    -- otherwise push the whole frame up when it overflows the bottom). Direction
    -- is decided once per show session to avoid flipping mid-session if growth
    -- pushes the frame's center past the screen midpoint. Scroll mode keeps a
    -- fixed height, so this logic is skipped there.
    local growUp = false
    if not scrollMode then
        if self._growUp == nil then
            local _, cy = self:GetCenter()
            local screenH = UIParent:GetHeight()
            self._growUp = (cy and screenH and screenH > 0 and cy < screenH / 2) and true or false

            local desiredPoint = self._growUp and "BOTTOMLEFT" or "TOPLEFT"
            if self:GetPoint() ~= desiredPoint then
                local left = self:GetLeft()
                local edgeY = self._growUp and self:GetBottom() or self:GetTop()
                if left and edgeY then
                    self:ClearAllPoints()
                    self:SetPoint(desiredPoint, UIParent, "BOTTOMLEFT", left, edgeY)
                    SavePosition()
                end
            end
        end
        growUp = self._growUp
    end

    -- Reserve fixed right margin for the custom scroll indicator
    local scrollRight = RIGHT_MARGIN
    scrollFrame:ClearAllPoints()
    if growUp then
        -- Pin scrollFrame's bottom edge so the oldest item (placed at the bottom
        -- of the list in growUp mode) stays put as the frame grows upward.
        scrollFrame:SetPoint("BOTTOMLEFT", self, "BOTTOMLEFT", LEFT_PADDING, FOOTER_HEIGHT + PADDING)
        scrollFrame:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", -scrollRight, FOOTER_HEIGHT + PADDING)
    else
        scrollFrame:SetPoint("TOPLEFT", self, "TOPLEFT", LEFT_PADDING, -(HEADER_HEIGHT + 4))
        scrollFrame:SetPoint("TOPRIGHT", self, "TOPRIGHT", -scrollRight, -(HEADER_HEIGHT + 4))
    end
    scrollFrame:SetHeight(visibleH)

    local scrollW = DEFAULT_WIDTH - LEFT_PADDING - scrollRight
    scrollContent:SetSize(scrollW, contentH)

    -- In growUp mode, reverse the visible list order: newest at top, oldest at
    -- bottom. Combined with the bottom-pinned scrollFrame, this keeps already-
    -- shown items visually stationary while new arrivals push upward.
    for i, slot in ipairs(visible) do
        slot:ClearAllPoints()
        local listPos = growUp and (n - i + 1) or i
        local yOff = -((listPos - 1) * row)
        slot:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", 0, yOff)
        slot:SetPoint("TOPRIGHT", scrollContent, "TOPRIGHT", 0, yOff)
    end

    local maxScroll = math.max(0, contentH - visibleH)
    UpdateIndicatorThumb()

    self:SetHeight(HEADER_HEIGHT + 4 + visibleH + FOOTER_HEIGHT + PADDING)

    -- Preserve user's current scroll position; only clamp if it exceeds new max
    -- (avoids hijacking the view and reducing click misses on items the user is looking at)
    local current = scrollFrame:GetVerticalScroll()
    if current > maxScroll then current = maxScroll end
    scrollFrame:SetVerticalScroll(current)

    self:Show()
end

-- Per-slot update (timeout detection + auto-close)
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

-- Add roll
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

-- Blizzard loot frame suppression
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

-- Resolve roll data (handles item cache delay)
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

-- Test rolls (/srsr preview)
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
        print(PREFIX .. L.TEST_RESET)
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
            print(PREFIX .. L.LOADING_CACHE)
        end
        return
    end

    testNextIndex = testNextIndex + target
    print(PREFIX .. string.format(L.TEST_SPAWNED, added))
end

-- Events
EventFrame:RegisterEvent("ADDON_LOADED")
EventFrame:RegisterEvent("PLAYER_LOGIN")
EventFrame:RegisterEvent("START_LOOT_ROLL")
EventFrame:RegisterEvent("CANCEL_LOOT_ROLL")
EventFrame:RegisterEvent("CONFIRM_LOOT_ROLL")
EventFrame:RegisterEvent("GET_ITEM_INFO_RECEIVED")

EventFrame:SetScript("OnEvent", function(_, event, arg1, arg2)
    if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
        SimpleRollDB = SimpleRollDB or {}
        -- Migrate legacy option keys (v1.3.x → v1.4): semantics inverted.
        if SimpleRollDB.useScroll ~= nil and SimpleRollDB.expandAll == nil then
            SimpleRollDB.expandAll = not SimpleRollDB.useScroll
        end
        SimpleRollDB.useScroll = nil
        if SimpleRollDB.confirmIndividual ~= nil and SimpleRollDB.instantRoll == nil then
            SimpleRollDB.instantRoll = not SimpleRollDB.confirmIndividual
        end
        SimpleRollDB.confirmIndividual = nil
        if SimpleRollDB.closeDelay == nil then
            SimpleRollDB.closeDelay = DEFAULT_CLOSE_DELAY
        end
        if SimpleRollDB.instantClose == nil then
            SimpleRollDB.instantClose = true
        end
        local pos = SimpleRollDB.pos
        if pos then
            MainFrame:ClearAllPoints()
            MainFrame:SetPoint(pos.point or "TOPLEFT", UIParent, pos.rel or "TOPLEFT", pos.x or 100, pos.y or -200)
        end
        local opos = SimpleRollDB.optionsPos
        if opos then
            OptionsFrame:ClearAllPoints()
            OptionsFrame:SetPoint(opos.point or "CENTER", UIParent, opos.rel or "CENTER", opos.x or 0, opos.y or 0)
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

    elseif event == "CONFIRM_LOOT_ROLL" then
        -- BoP items require a second server round-trip. When instantRoll is on,
        -- auto-confirm silently; when off, defer to Blizzard's default popup.
        local rollID, rollType = arg1, arg2
        if SimpleRollDB and SimpleRollDB.instantRoll == false then
            local slot = activeRolls[rollID]
            local itemName = (slot and slot.ItemName and slot.ItemName:GetText()) or ""
            local typeLabel = _G["LOOT_ROLL_TYPE" .. rollType] or ""
            local dialog = StaticPopup_Show("CONFIRM_LOOT_ROLL", typeLabel, itemName)
            if dialog then
                dialog.data = rollID
                dialog.data2 = rollType
            end
        else
            ConfirmLootRoll(rollID, rollType)
        end
    end
end)

-- Slash command
SLASH_SIMPLEROLL1 = "/srsr"
SLASH_SIMPLEROLL2 = "/simpleroll"
SlashCmdList["SIMPLEROLL"] = function(msg)
    local cmd = (msg or ""):lower():match("^(%S*)")
    local num = tonumber(cmd)
    if cmd == "" then
        TestRolls(math.random(3, 5))
        OptionsFrame:Show()
    elseif num and num > 0 then
        TestRolls(math.floor(num))
        OptionsFrame:Show()
    elseif cmd == "reset" then
        wipe(SimpleRollDB)
        MainFrame:ClearAllPoints()
        MainFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 100, -200)
        OptionsFrame:ClearAllPoints()
        OptionsFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        print(PREFIX .. L.POS_RESET)
    else
        print(PREFIX .. L.HELP_HEADER)
        print("  /srsr - " .. L.CMD_PREVIEW)
        print("  /srsr " .. L.CMD_PREVIEW_N)
        print("  /srsr " .. L.CMD_RESET)
    end
end
