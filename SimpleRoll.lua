local ADDON_NAME = "SimpleRoll"

local L = {}
if GetLocale() == "koKR" then
    L.title = "%s의 전리품"
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
    L.hint = "드래그로 이동"
    L.you_rolled = "내 선택: %s"
    L.winner = "%s 획득"
    L.all_passed = "전원 포기"
else
    L.title = "%s's Loot"
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
    L.hint = "Drag to move"
    L.you_rolled = "You: %s"
    L.winner = "%s won"
    L.all_passed = "All passed"
end

local FRAME_WIDTH = 298
local SLOT_HEIGHT = 48
local HEADER_HEIGHT = 24
local FOOTER_HEIGHT = 30
local PADDING = 8
local BUTTON_SIZE = 28
local ICON_SIZE = 25

local EXPIRE_WON = 8
local EXPIRE_LOST = 5
local EXPIRE_ROLLED = 30

local GetItemInfo = C_Item and C_Item.GetItemInfo or _G.GetItemInfo
local GetItemQualityColor = C_Item and C_Item.GetItemQualityColor or _G.GetItemQualityColor

------------------------------------------------------------
-- C_LootHistory defensive wrapper (WotLK 3.3+ only)
------------------------------------------------------------
local HAS_LOOT_HISTORY = C_LootHistory and C_LootHistory.GetItem and true or false

local HistoryGetItem = C_LootHistory and C_LootHistory.GetItem or function() return nil end
local HistoryGetPlayerInfo = C_LootHistory and C_LootHistory.GetPlayerInfo or function() return nil end
local HistoryGetNumItems = C_LootHistory and C_LootHistory.GetNumItems or function() return 0 end

local activeRolls = {}
local pendingRolls = {}
local slotPool = {}
local ReleaseSlot
local InitChatResults, UpdateSlotResultDisplay, FindEntryByName
local FinishSlotWithWinner, FinishSlotAllPassed

local EventFrame = CreateFrame("Frame", ADDON_NAME .. "Events", UIParent)

local function SafeRegisterEvent(frame, event)
    local ok = pcall(function() frame:RegisterEvent(event) end)
    return ok
end

------------------------------------------------------------
-- Main Frame
------------------------------------------------------------
local MainFrame = CreateFrame("Frame", "SimpleRollFrame", UIParent, BackdropTemplateMixin and "BackdropTemplate")
MainFrame:SetSize(FRAME_WIDTH, HEADER_HEIGHT + PADDING * 2)
MainFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 100, -200)
MainFrame:SetFrameStrata("HIGH")
MainFrame:SetClampedToScreen(true)
MainFrame:Hide()

MainFrame:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Gold-Border",
    tile = true, tileSize = 32, edgeSize = 24,
    insets = { left = 6, right = 6, top = 6, bottom = 6 },
})
MainFrame:SetBackdropColor(0.08, 0.08, 0.08, 0.92)

MainFrame:SetMovable(true)
MainFrame:SetResizable(true)
MainFrame:EnableMouse(true)
MainFrame:RegisterForDrag("LeftButton")
if MainFrame.SetResizeBounds then
    MainFrame:SetResizeBounds(200, 1)
elseif MainFrame.SetMinResize then
    MainFrame:SetMinResize(200, 1)
end

MainFrame:SetScript("OnDragStart", function(self) self:StartMoving() end)
MainFrame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local point, _, rel, x, y = self:GetPoint()
    SimpleRollDB = SimpleRollDB or {}
    SimpleRollDB.pos = { point = point, rel = rel, x = x, y = y }
end)

-- Resize grip (bottom-right)
local resizeGrip = CreateFrame("Button", nil, MainFrame)
resizeGrip:SetSize(16, 16)
resizeGrip:SetPoint("BOTTOMRIGHT", -4, 4)
resizeGrip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
resizeGrip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
resizeGrip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
resizeGrip:SetFrameLevel(MainFrame:GetFrameLevel() + 10)

resizeGrip:SetScript("OnMouseDown", function()
    MainFrame:StartSizing("BOTTOMRIGHT")
end)
resizeGrip:SetScript("OnMouseUp", function()
    MainFrame:StopMovingOrSizing()
    SimpleRollDB = SimpleRollDB or {}
    SimpleRollDB.width = math.floor(MainFrame:GetWidth() + 0.5)
    FRAME_WIDTH = SimpleRollDB.width
    MainFrame:UpdateLayout()
end)

local function UpdateHeader() end

-- Need All button
local needAllBtn = CreateFrame("Button", nil, MainFrame, BackdropTemplateMixin and "BackdropTemplate")
needAllBtn:SetSize(80, 22)
needAllBtn:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 10,
    insets = { left = 2, right = 2, top = 2, bottom = 2 },
})
needAllBtn:SetBackdropColor(0.05, 0.15, 0.05, 0.85)
needAllBtn:SetBackdropBorderColor(0.3, 0.8, 0.3, 1)

local needAllIcon = needAllBtn:CreateTexture(nil, "ARTWORK")
needAllIcon:SetSize(14, 14)
needAllIcon:SetPoint("LEFT", 4, 0)
needAllIcon:SetTexture("Interface\\Buttons\\UI-GroupLoot-Dice-Up")

local needAllText = needAllBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
needAllText:SetPoint("LEFT", needAllIcon, "RIGHT", 3, 0)
needAllText:SetText(L.need_all)
needAllText:SetTextColor(0.4, 1, 0.4)

needAllBtn:SetScript("OnEnter", function(self)
    self:SetBackdropBorderColor(0.5, 1, 0.5, 1)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetText(L.need_all_tip, 1, 1, 1)
    GameTooltip:Show()
end)
needAllBtn:SetScript("OnLeave", function(self)
    self:SetBackdropBorderColor(0.3, 0.8, 0.3, 1)
    GameTooltip:Hide()
end)
needAllBtn:SetScript("OnClick", function()
    for rollID, slot in pairs(activeRolls) do
        if slot and not slot.rolled and not slot.timedOut then
            if rollID < 9000 then
                RollOnLoot(rollID, 1)
            end
            slot.rolled = true
            for _, b in pairs(slot.Buttons) do b:Hide() end
            slot.ResultText:SetText(string.format(L.you_rolled, L.need))
            slot.ResultText:SetTextColor(0.4, 1, 0.4)
            slot.ResultText:Show()
            slot.TimerBar:Hide()
        end
    end
    MainFrame:UpdateCloseButton()
end)

-- Greed All button
local greedAllBtn = CreateFrame("Button", nil, MainFrame, BackdropTemplateMixin and "BackdropTemplate")
greedAllBtn:SetSize(80, 22)
greedAllBtn:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 10,
    insets = { left = 2, right = 2, top = 2, bottom = 2 },
})
greedAllBtn:SetBackdropColor(0.05, 0.05, 0.15, 0.85)
greedAllBtn:SetBackdropBorderColor(0.3, 0.5, 0.8, 1)

local greedAllIcon = greedAllBtn:CreateTexture(nil, "ARTWORK")
greedAllIcon:SetSize(14, 14)
greedAllIcon:SetPoint("LEFT", 4, 0)
greedAllIcon:SetTexture("Interface\\Buttons\\UI-GroupLoot-Coin-Up")

local greedAllText = greedAllBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
greedAllText:SetPoint("LEFT", greedAllIcon, "RIGHT", 3, 0)
greedAllText:SetText(L.greed_all)
greedAllText:SetTextColor(0.4, 0.6, 1)

greedAllBtn:SetScript("OnEnter", function(self)
    self:SetBackdropBorderColor(0.5, 0.7, 1, 1)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetText(L.greed_all_tip, 1, 1, 1)
    GameTooltip:Show()
end)
greedAllBtn:SetScript("OnLeave", function(self)
    self:SetBackdropBorderColor(0.3, 0.5, 0.8, 1)
    GameTooltip:Hide()
end)
greedAllBtn:SetScript("OnClick", function()
    for rollID, slot in pairs(activeRolls) do
        if slot and not slot.rolled then
            if rollID < 9000 then
                RollOnLoot(rollID, 2)
            end
            slot.rolled = true
            for _, b in pairs(slot.Buttons) do b:Hide() end
            slot.ResultText:SetText(string.format(L.you_rolled, L.greed))
            slot.ResultText:SetTextColor(0.4, 0.6, 1)
            slot.ResultText:Show()
            slot.TimerBar:Hide()
        end
    end
    MainFrame:UpdateCloseButton()
end)

-- Pass All button
local passAllBtn = CreateFrame("Button", nil, MainFrame, BackdropTemplateMixin and "BackdropTemplate")
passAllBtn:SetSize(80, 22)
passAllBtn:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 10,
    insets = { left = 2, right = 2, top = 2, bottom = 2 },
})
passAllBtn:SetBackdropColor(0.15, 0.05, 0.05, 0.85)
passAllBtn:SetBackdropBorderColor(0.8, 0.3, 0.3, 1)

local passAllIcon = passAllBtn:CreateTexture(nil, "ARTWORK")
passAllIcon:SetSize(14, 14)
passAllIcon:SetPoint("LEFT", 4, 0)
passAllIcon:SetTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Up")

local passAllText = passAllBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
passAllText:SetPoint("LEFT", passAllIcon, "RIGHT", 3, 0)
passAllText:SetText(L.pass_all)
passAllText:SetTextColor(1, 0.4, 0.4)

passAllBtn:SetScript("OnEnter", function(self)
    self:SetBackdropBorderColor(1, 0.5, 0.5, 1)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetText(L.pass_all_tip, 1, 1, 1)
    GameTooltip:Show()
end)
passAllBtn:SetScript("OnLeave", function(self)
    self:SetBackdropBorderColor(0.8, 0.3, 0.3, 1)
    GameTooltip:Hide()
end)
StaticPopupDialogs["SIMPLEROLL_PASS_ALL"] = {
    text = L.pass_all_confirm,
    button1 = YES,
    button2 = NO,
    OnAccept = function()
        for rollID, slot in pairs(activeRolls) do
            if slot and not slot.rolled and not slot.timedOut then
                if rollID < 9000 then
                    RollOnLoot(rollID, 0)
                end
                slot.rolled = true
                for _, b in pairs(slot.Buttons) do b:Hide() end
                slot.ResultText:SetText(string.format(L.you_rolled, L.pass))
                slot.ResultText:SetTextColor(0.7, 0.7, 0.7)
                slot.ResultText:Show()
                slot.TimerBar:Hide()
            end
        end
        MainFrame:UpdateCloseButton()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
}
passAllBtn:SetScript("OnClick", function()
    StaticPopup_Show("SIMPLEROLL_PASS_ALL")
end)

local function AnchorTooltipAboveSlot(slot)
    GameTooltip:SetOwner(slot, "ANCHOR_TOP", 0, 4)
end

-- Title text
local titleText = MainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
titleText:SetPoint("TOPLEFT", MainFrame, "TOPLEFT", 10, -10)
titleText:SetText("|cFFFFD700SimpleRoll|r")

-- Close button (hidden until all slots resolved)
local closeBtn = CreateFrame("Button", nil, MainFrame, "UIPanelCloseButton")
closeBtn:SetPoint("TOPRIGHT", MainFrame, "TOPRIGHT", -2, -2)
closeBtn:SetSize(30, 30)
closeBtn:Hide()

-- Countdown text (left of close button)
local countdownText = MainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
countdownText:SetPoint("RIGHT", closeBtn, "LEFT", -2, 0)
countdownText:SetTextColor(0.6, 0.6, 0.6)
countdownText:Hide()
closeBtn:SetScript("OnClick", function()
    for rollID, slot in pairs(activeRolls) do
        slot:SetScript("OnUpdate", nil)
        ReleaseSlot(slot)
    end
    wipe(activeRolls)
    MainFrame:UpdateLayout()
end)

function MainFrame:UpdateCloseButton()
    for _, slot in pairs(activeRolls) do
        if slot:IsShown() and not slot.rolled and not slot.timedOut and not slot.over then
            closeBtn:Hide()
            return
        end
    end
    closeBtn:Show()
end

MainFrame:SetScript("OnUpdate", function(self)
    if not closeBtn:IsShown() then
        countdownText:Hide()
        return
    end
    local earliest = nil
    for _, slot in pairs(activeRolls) do
        if slot.expireAt then
            local rem = slot.expireAt - GetTime()
            if not earliest or rem < earliest then
                earliest = rem
            end
        end
    end
    if earliest and earliest > 0 then
        countdownText:SetText(string.format(L.seconds, math.ceil(earliest)))
        countdownText:Show()
    else
        countdownText:Hide()
    end
end)

------------------------------------------------------------
-- Roll Slot
------------------------------------------------------------
local function AcquireSlot()
    local slot = table.remove(slotPool)
    if slot then return slot end

    slot = CreateFrame("Frame", nil, MainFrame, BackdropTemplateMixin and "BackdropTemplate")
    slot:SetHeight(SLOT_HEIGHT)
    slot:EnableMouse(true)
    slot:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    slot:SetBackdropColor(0, 0, 0, 0.5)
    slot:SetBackdropBorderColor(0.6, 0.6, 0.6, 0.6)
    slot:RegisterForDrag("LeftButton")
    slot:SetScript("OnDragStart", function() MainFrame:StartMoving() end)
    slot:SetScript("OnDragStop", function()
        MainFrame:StopMovingOrSizing()
        local point, _, rel, x, y = MainFrame:GetPoint()
        SimpleRollDB = SimpleRollDB or {}
        SimpleRollDB.pos = { point = point, rel = rel, x = x, y = y }
    end)

    -- Icon
    local iconBg = slot:CreateTexture(nil, "BACKGROUND")
    iconBg:SetSize(ICON_SIZE + 4, ICON_SIZE + 4)
    iconBg:SetPoint("LEFT", 6, 4)
    iconBg:SetColorTexture(0, 0, 0, 0.8)
    slot.IconBg = iconBg

    local icon = slot:CreateTexture(nil, "ARTWORK")
    icon:SetSize(ICON_SIZE, ICON_SIZE)
    icon:SetPoint("CENTER", iconBg, "CENTER")
    icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    slot.Icon = icon

    -- Item name
    local itemName = slot:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    itemName:SetPoint("TOPLEFT", iconBg, "TOPRIGHT", 8, -2)
    itemName:SetJustifyH("LEFT")
    itemName:SetWordWrap(false)
    slot.ItemName = itemName

    -- Roll count text (below item name, real-time counters)
    local rollCountText = slot:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    rollCountText:SetPoint("TOPLEFT", iconBg, "RIGHT", 8, -6)
    rollCountText:SetJustifyH("LEFT")
    rollCountText:SetWordWrap(false)
    rollCountText:Hide()
    slot.RollCountText = rollCountText

    -- Status text (shown for final result: winner/all passed)
    local statusText = slot:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    statusText:SetPoint("TOPLEFT", iconBg, "TOPRIGHT", 8, -2)
    statusText:SetJustifyH("LEFT")
    statusText:SetWordWrap(false)
    statusText:Hide()
    slot.StatusText = statusText

    -- Timer bar
    local timerBar = CreateFrame("StatusBar", nil, slot)
    timerBar:SetHeight(8)
    timerBar:SetPoint("BOTTOMLEFT", 6, 4)
    timerBar:SetPoint("BOTTOMRIGHT", -6, 4)
    timerBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    timerBar:SetStatusBarColor(0.2, 0.7, 0.2)
    timerBar:SetMinMaxValues(0, 1)

    local timerBg = timerBar:CreateTexture(nil, "BACKGROUND")
    timerBg:SetAllPoints()
    timerBg:SetColorTexture(0, 0, 0, 0.5)

    local timerText = timerBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    timerText:SetPoint("CENTER")
    timerText:SetFont(timerText:GetFont(), 9, "OUTLINE")
    timerBar.Text = timerText
    slot.TimerBar = timerBar

    -- Roll buttons: Pass (rightmost) → Greed → Need (leftmost)
    local btnDefs = {
        { key = "pass",  type = 0, tex = "Interface\\Buttons\\UI-GroupLoot-Pass-Up", label = L.pass },
        { key = "greed", type = 2, tex = "Interface\\Buttons\\UI-GroupLoot-Coin-Up", label = L.greed },
        { key = "need",  type = 1, tex = "Interface\\Buttons\\UI-GroupLoot-Dice-Up", label = L.need },
    }

    slot.Buttons = {}
    local prevBtn
    for _, def in ipairs(btnDefs) do
        local btn = CreateFrame("Button", nil, slot)
        btn:SetSize(BUTTON_SIZE, BUTTON_SIZE)

        if not prevBtn then
            btn:SetPoint("TOPRIGHT", slot, "TOPRIGHT", -6, -4)
        else
            btn:SetPoint("RIGHT", prevBtn, "LEFT", -2, 0)
        end

        btn:SetNormalTexture(def.tex)
        btn:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")

        if def.key == "pass" then
            btn:GetNormalTexture():SetVertexColor(0.8, 0.7, 0.7)
        end

        local countText = btn:CreateFontString(nil, "OVERLAY")
        countText:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
        countText:SetPoint("BOTTOM", 0, -2)
        btn.CountText = countText

        btn.rollType = def.type

        btn:SetScript("OnEnter", function(self)
            self:GetHighlightTexture():Show()
        end)
        btn:SetScript("OnLeave", function(self)
            self:GetHighlightTexture():Hide()
        end)


        btn:SetScript("OnClick", function()
            if slot.rollID and not slot.rolled then
                slot.rolled = true

                -- Test rolls use fake IDs (9000+), don't call RollOnLoot
                local isTest = slot.rollID >= 9000
                if not isTest then
                    RollOnLoot(slot.rollID, def.type)
                end

                -- Hide buttons, show choice in button area
                for _, b in pairs(slot.Buttons) do b:Hide() end
                slot.ResultText:SetText(string.format(L.you_rolled, def.label))
                slot.ResultText:SetTextColor(0.5, 1, 0.5)
                slot.ResultText:Show()
                slot.TimerBar:Hide()
                MainFrame:UpdateCloseButton()

                -- Test mode: add self to results
                if isTest then
                    InitChatResults(slot)
                    if def.type == 1 then
                        table.insert(slot.chatNeed, { name = UnitName("player") })
                    elseif def.type == 2 then
                        table.insert(slot.chatGreed, { name = UnitName("player") })
                    else
                        table.insert(slot.chatPass, { name = UnitName("player") })
                    end
                    UpdateSlotResultDisplay(slot)
                end
            end
        end)

        slot.Buttons[def.key] = btn
        prevBtn = btn
    end

    -- Result text (shown in button area after rolling)
    local resultText = slot:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    resultText:SetPoint("TOPRIGHT", slot, "TOPRIGHT", -6, -6)
    resultText:SetJustifyH("RIGHT")
    resultText:SetWordWrap(false)
    resultText:Hide()
    slot.ResultText = resultText

    -- Anchor item name right edge to left of leftmost button (need)
    local leftBtn = slot.Buttons.need
    if leftBtn then
        itemName:SetPoint("RIGHT", leftBtn, "LEFT", -6, 0)
        rollCountText:SetPoint("RIGHT", leftBtn, "LEFT", -6, 0)
        statusText:SetPoint("RIGHT", slot, "RIGHT", -6, 0)
        resultText:SetPoint("LEFT", leftBtn, "LEFT", 0, 0)
    else
        itemName:SetPoint("RIGHT", slot, "RIGHT", -10, 0)
        rollCountText:SetPoint("RIGHT", slot, "RIGHT", -10, 0)
        statusText:SetPoint("RIGHT", slot, "RIGHT", -10, 0)
    end

    -- Tooltip on item hover
    slot:SetScript("OnEnter", function(self)
        AnchorTooltipAboveSlot(self)
        local isTest = self.rollID and self.rollID >= 9000
        if not isTest and self.rollID and GetLootRollItemInfo then
            local ok = pcall(GameTooltip.SetLootRollItem, GameTooltip, self.rollID)
            if ok and GameTooltip:NumLines() > 0 then
                GameTooltip:Show()
                return
            end
        end
        if self.itemLink then
            GameTooltip:SetHyperlink(self.itemLink)
        elseif self.ItemName then
            GameTooltip:SetText(self.ItemName:GetText() or "", 1, 1, 1)
        end
        GameTooltip:Show()
    end)
    slot:SetScript("OnLeave", function() GameTooltip:Hide() end)

    return slot
end

ReleaseSlot = function(slot)
    slot:Hide()
    slot:ClearAllPoints()
    slot:SetScript("OnUpdate", nil)
    slot.rollID = nil
    slot.rolled = nil
    slot.itemLink = nil
    slot.timeLeft = nil
    slot.totalTime = nil
    slot.over = nil
    slot.expireAt = nil
    slot.timedOut = nil
    slot.chatNeed = nil
    slot.chatGreed = nil
    slot.chatPass = nil
    if slot.ResultText then slot.ResultText:SetText(""); slot.ResultText:Hide() end
    if slot.RollCountText then slot.RollCountText:SetText(""); slot.RollCountText:Hide() end
    if slot.Icon then slot.Icon:SetTexture(nil) end
    if slot.ItemName then slot.ItemName:SetText(""); slot.ItemName:Show() end
    if slot.StatusText then slot.StatusText:SetText(""); slot.StatusText:Hide() end
    if slot.TimerBar then slot.TimerBar:SetValue(0); slot.TimerBar:Show() end
    if slot.TimerBar and slot.TimerBar.Text then slot.TimerBar.Text:SetText("") end
    if slot.Buttons then
        for _, btn in pairs(slot.Buttons) do
            btn:Show()
            btn:Enable()
            btn:SetAlpha(1)
            if btn.CountText then btn.CountText:SetText("") end
        end
    end
    table.insert(slotPool, slot)
end

------------------------------------------------------------
-- Layout
------------------------------------------------------------
local function GrowsUpward()
    local point = select(1, MainFrame:GetPoint())
    if point then
        point = point:upper()
        if point:find("BOTTOM") then return true end
    end
    return false
end

function MainFrame:UpdateLayout()
    local visible = {}
    for rollID, slot in pairs(activeRolls) do
        if slot:IsShown() then
            table.insert(visible, slot)
        end
    end

    if #visible == 0 then
        self:Hide()
        return
    end

    table.sort(visible, function(a, b) return a.rollID < b.rollID end)

    local upward = GrowsUpward()
    if upward then
        local n = #visible
        for i = 1, math.floor(n / 2) do
            visible[i], visible[n - i + 1] = visible[n - i + 1], visible[i]
        end
    end

    self:SetWidth(FRAME_WIDTH)
    for i, slot in ipairs(visible) do
        slot:ClearAllPoints()
        if i == 1 then
            slot:SetPoint("TOPLEFT", self, "TOPLEFT", PADDING, -(HEADER_HEIGHT + 4))
            slot:SetPoint("TOPRIGHT", self, "TOPRIGHT", -PADDING, -(HEADER_HEIGHT + 4))
        else
            slot:SetPoint("TOPLEFT", visible[i - 1], "BOTTOMLEFT", 0, -3)
            slot:SetPoint("TOPRIGHT", visible[i - 1], "BOTTOMRIGHT", 0, -3)
        end
    end

    local totalH = HEADER_HEIGHT + 4 + (#visible * (SLOT_HEIGHT + 3)) + FOOTER_HEIGHT + PADDING
    self:SetHeight(totalH)

    needAllBtn:ClearAllPoints()
    needAllBtn:SetPoint("BOTTOMLEFT", self, "BOTTOMLEFT", 10, 8)
    greedAllBtn:ClearAllPoints()
    greedAllBtn:SetPoint("CENTER", self, "BOTTOM", 0, 19)
    passAllBtn:ClearAllPoints()
    passAllBtn:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", -10, 8)

    self:Show()
end

------------------------------------------------------------
-- Add / Remove rolls
------------------------------------------------------------
local function AddRoll(rollID, texture, name, quality, timeLeft, canNeed, canGreed, itemLink)
    if activeRolls[rollID] then return end

    local slot = AcquireSlot()
    slot.rollID = rollID
    slot.rolled = false
    slot.over = false
    slot.itemLink = itemLink
    slot.timeLeft = timeLeft or 60
    slot.totalTime = slot.timeLeft

    if texture then
        slot.Icon:SetTexture(texture)
    end

    slot.ItemName:SetText(name or "???")
    if quality then
        local r, g, b = GetItemQualityColor(quality)
        slot.ItemName:SetTextColor(r, g, b)
        slot:SetBackdropBorderColor(r, g, b, 1)
        slot.IconBg:SetColorTexture(r, g, b, 0.6)
    else
        slot.ItemName:SetTextColor(1, 1, 1)
        slot:SetBackdropBorderColor(0.6, 0.6, 0.6, 0.6)
        slot.IconBg:SetColorTexture(0, 0, 0, 0.8)
    end

    slot.TimerBar:SetMinMaxValues(0, slot.totalTime)
    slot.TimerBar:SetValue(slot.timeLeft)
    slot.TimerBar.Text:SetText("")

    -- Button enable/disable
    if slot.Buttons.need then
        if canNeed then
            slot.Buttons.need:Enable()
            slot.Buttons.need:SetAlpha(1)
        else
            slot.Buttons.need:Disable()
            slot.Buttons.need:SetAlpha(0.3)
        end
    end
    if slot.Buttons.greed then
        if canGreed then
            slot.Buttons.greed:Enable()
            slot.Buttons.greed:SetAlpha(1)
        else
            slot.Buttons.greed:Disable()
            slot.Buttons.greed:SetAlpha(0.3)
        end
    end
    if slot.Buttons.pass then
        slot.Buttons.pass:Enable()
        slot.Buttons.pass:SetAlpha(1)
    end

    -- Timer OnUpdate
    slot:SetScript("OnUpdate", function(self, elapsed)
        -- Expiration countdown (30s after result received)
        if self.expireAt then
            local remaining = self.expireAt - GetTime()
            if remaining <= 0 then
                self:SetScript("OnUpdate", nil)
                activeRolls[self.rollID] = nil
                ReleaseSlot(self)
                MainFrame:UpdateLayout()
                return
            end
            return
        end

        self.timeLeft = self.timeLeft - elapsed
        if self.timeLeft <= 0 then
            self.timeLeft = 0
            if not self.rolled and not self.timedOut then
                self.timedOut = true
                for _, b in pairs(self.Buttons) do b:Hide() end
                self.ResultText:SetText(L.pass)
                self.ResultText:SetTextColor(0.7, 0.7, 0.7)
                self.ResultText:Show()
                self.TimerBar:Hide()
                if self.rollID and self.rollID >= 9000 then
                    InitChatResults(self)
                    local pn = UnitName("player")
                    if not FindEntryByName(self.chatPass, pn) then
                        table.insert(self.chatPass, { name = pn })
                        UpdateSlotResultDisplay(self)
                    end
                end
                MainFrame:UpdateCloseButton()
            end
        end
        self.TimerBar:SetValue(self.timeLeft)
        self.TimerBar.Text:SetText("")

        local pct = self.timeLeft / self.totalTime
        if pct > 0.5 then
            self.TimerBar:SetStatusBarColor(0.2, 0.7, 0.2)
        elseif pct > 0.25 then
            self.TimerBar:SetStatusBarColor(0.9, 0.7, 0.1)
        else
            self.TimerBar:SetStatusBarColor(0.9, 0.2, 0.1)
        end
    end)

    slot:Show()
    activeRolls[rollID] = slot
    MainFrame:UpdateLayout()
    MainFrame:UpdateCloseButton()
end

local function RemoveRoll(rollID)
    local slot = activeRolls[rollID]
    if slot then
        slot:SetScript("OnUpdate", nil)
        activeRolls[rollID] = nil
        ReleaseSlot(slot)
        MainFrame:UpdateLayout()
    end
end

------------------------------------------------------------
-- C_LootHistory event handlers (only if API exists)
------------------------------------------------------------
local function OnRollChanged(hid, pid)
    if not HAS_LOOT_HISTORY then return end

    local rollID, _, players = HistoryGetItem(hid)
    local slot = activeRolls[rollID]
    if not slot or not slot:IsShown() then return end

    local name, class, rtypeid, roll, winner, is_me = HistoryGetPlayerInfo(hid, pid)

    -- Update button counters
    if not slot.rolled then
        local needCount, greedCount, passCount = 0, 0, 0
        players = players or 0
        for i = 1, players do
            local _, _, rt = HistoryGetPlayerInfo(hid, i)
            if rt == 1 then needCount = needCount + 1
            elseif rt == 2 or rt == 3 then greedCount = greedCount + 1
            elseif rt == 0 then passCount = passCount + 1
            end
        end
        if slot.Buttons.need and slot.Buttons.need.CountText then
            slot.Buttons.need.CountText:SetText(needCount > 0 and needCount or "")
        end
        if slot.Buttons.greed and slot.Buttons.greed.CountText then
            slot.Buttons.greed.CountText:SetText(greedCount > 0 and greedCount or "")
        end
        if slot.Buttons.pass and slot.Buttons.pass.CountText then
            slot.Buttons.pass.CountText:SetText(passCount > 0 and passCount or "")
        end
    else
        -- Already rolled: update status with leading type count
        players = players or 0
        local needCount, greedCount, passCount = 0, 0, 0
        for i = 1, players do
            local _, _, rt = HistoryGetPlayerInfo(hid, i)
            if rt == 1 then needCount = needCount + 1
            elseif rt == 2 or rt == 3 then greedCount = greedCount + 1
            elseif rt == 0 then passCount = passCount + 1
            end
        end
        local statusParts = {}
        if needCount > 0 then table.insert(statusParts, string.format("|cFF44FF22%s:%d|r", L.need, needCount)) end
        if greedCount > 0 then table.insert(statusParts, string.format("|cFF4488FF%s:%d|r", L.greed, greedCount)) end
        if passCount > 0 then table.insert(statusParts, string.format("|cFF999999%s:%d|r", L.pass, passCount)) end
        if #statusParts > 0 then
            slot.StatusText:SetText(table.concat(statusParts, "  "))
            slot.StatusText:SetTextColor(1, 1, 1)
        end
    end
end

local function OnRollComplete()
    if not HAS_LOOT_HISTORY then return end

    local hid = 1
    while true do
        local rollID, _, players, done = HistoryGetItem(hid)
        if not rollID then return end

        local slot = activeRolls[rollID]
        if done and slot and not slot.over then
            slot.over = true
            players = players or 0

            -- Find winner
            local winnerName, winnerClass, winnerIsMe
            for j = 1, players do
                local pName, pClass, _, _, isWinner, isMe = HistoryGetPlayerInfo(hid, j)
                if isWinner then
                    winnerName = pName
                    winnerClass = pClass
                    winnerIsMe = isMe
                    break
                end
            end

            -- Show result
            for _, b in pairs(slot.Buttons) do b:Hide() end
            slot.ResultText:Hide()

            if winnerName then
                slot.RollCountText:SetText("|cFFFFD700" .. string.format(L.winner, winnerName) .. "|r")
                slot.RollCountText:Show()
                slot.expireAt = GetTime() + (winnerIsMe and EXPIRE_WON or EXPIRE_LOST)
            else
                slot.RollCountText:SetText("|cFF999999" .. L.all_passed .. "|r")
                slot.RollCountText:Show()
                slot.expireAt = GetTime() + EXPIRE_LOST
            end

            slot.TimerBar:SetValue(0)
            slot.TimerBar.Text:SetText("")
            return
        end
        hid = hid + 1
    end
end

------------------------------------------------------------
-- CHAT_MSG_LOOT parsing (TBC fallback when no C_LootHistory)
------------------------------------------------------------
local function GlobalStringToPattern(fmt)
    if not fmt then return nil end
    local p = fmt
    p = p:gsub("%%s", "\001")
    p = p:gsub("%%d", "\002")
    p = p:gsub("|1(.-)%;(.-)%;", "\003")
    p = p:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1")
    p = p:gsub("\001", "(.+)")
    p = p:gsub("\002", "(%%d+)")
    p = p:gsub("\003", ".+")
    return "^" .. p .. "$"
end

-- "selected" patterns: fired when a player makes their choice (real-time)
local PAT_SEL_NEED      = GlobalStringToPattern(LOOT_ROLL_NEED)
local PAT_SEL_GREED     = GlobalStringToPattern(LOOT_ROLL_GREED)
local PAT_SEL_PASS      = GlobalStringToPattern(LOOT_ROLL_PASSED)
local PAT_SEL_NEED_SELF  = GlobalStringToPattern(LOOT_ROLL_NEED_SELF)
local PAT_SEL_GREED_SELF = GlobalStringToPattern(LOOT_ROLL_GREED_SELF)
local PAT_SEL_PASS_SELF  = GlobalStringToPattern(LOOT_ROLL_PASSED_SELF)
local PAT_SEL_PASS_AUTO  = GlobalStringToPattern(LOOT_ROLL_PASSED_AUTO)
local PAT_SEL_PASS_SELF_AUTO = GlobalStringToPattern(LOOT_ROLL_PASSED_SELF_AUTO)

-- "rolled" patterns: fired with actual dice numbers (after all choices made)
local PAT_ROLLED_NEED  = GlobalStringToPattern(LOOT_ROLL_ROLLED_NEED)
local PAT_ROLLED_GREED = GlobalStringToPattern(LOOT_ROLL_ROLLED_GREED)
local PAT_ROLLED_DE    = GlobalStringToPattern(LOOT_ROLL_ROLLED_DE)

-- final result patterns
local PAT_ROLL_WON       = GlobalStringToPattern(LOOT_ROLL_WON)
local PAT_ROLL_YOU_WON   = GlobalStringToPattern(LOOT_ROLL_YOU_WON)
local PAT_ROLL_ALL_PASS  = GlobalStringToPattern(LOOT_ROLL_ALL_PASSED)

local function FindSlotByItemID(itemID)
    for rollID, slot in pairs(activeRolls) do
        if not slot.over and slot.itemLink then
            if slot.itemLink:match("item:(%d+)") == itemID then
                return rollID, slot
            end
        end
    end
    return nil, nil
end

local function TryMatch(msg, pat)
    if not pat then return nil end
    return msg:match(pat)
end

InitChatResults = function(slot)
    if not slot.chatNeed then
        slot.chatNeed = {}
        slot.chatGreed = {}
        slot.chatPass = {}
    end
end

local ICON_NEED  = "|TInterface\\Buttons\\UI-GroupLoot-Dice-Up:14|t"
local ICON_GREED = "|TInterface\\Buttons\\UI-GroupLoot-Coin-Up:14|t"
local ICON_PASS  = "|TInterface\\Buttons\\UI-GroupLoot-Pass-Up:14|t"

UpdateSlotResultDisplay = function(slot)
    if not slot.chatNeed then return end
    local parts = {}
    if #slot.chatNeed > 0 then
        table.insert(parts, string.format("|cFF44FF22%s%d|r", ICON_NEED, #slot.chatNeed))
    end
    if #slot.chatGreed > 0 then
        table.insert(parts, string.format("|cFF4488FF%s%d|r", ICON_GREED, #slot.chatGreed))
    end
    if #slot.chatPass > 0 then
        table.insert(parts, string.format("|cFF999999%s%d|r", ICON_PASS, #slot.chatPass))
    end
    if #parts > 0 then
        slot.RollCountText:SetText(table.concat(parts, " "))
        slot.RollCountText:Show()
    end
end

FindEntryByName = function(list, name)
    for _, entry in ipairs(list) do
        if entry.name == name then return entry end
    end
    return nil
end

FinishSlotWithWinner = function(slot, winnerName)
    slot.over = true
    for _, b in pairs(slot.Buttons) do b:Hide() end
    slot.ResultText:Hide()
    local typeIcon = ""
    if slot.chatNeed and FindEntryByName(slot.chatNeed, winnerName) then
        typeIcon = ICON_NEED
    elseif slot.chatGreed and FindEntryByName(slot.chatGreed, winnerName) then
        typeIcon = ICON_GREED
    end
    slot.RollCountText:SetText("|cFFFFD700" .. typeIcon .. winnerName .. "|r")
    slot.RollCountText:Show()
    local expiry = GetTime() + EXPIRE_ROLLED
    slot.expireAt = expiry
    -- Sync all finished slots to the same expiry so they close together
    for _, s in pairs(activeRolls) do
        if s.over and s.expireAt and s.expireAt < expiry then
            s.expireAt = expiry
        end
    end
end

FinishSlotAllPassed = function(slot)
    slot.over = true
    for _, b in pairs(slot.Buttons) do b:Hide() end
    slot.ResultText:Hide()
    slot.RollCountText:SetText("|cFF999999" .. L.all_passed .. "|r")
    slot.RollCountText:Show()
    local expiry = GetTime() + EXPIRE_ROLLED
    slot.expireAt = expiry
    for _, s in pairs(activeRolls) do
        if s.over and s.expireAt and s.expireAt < expiry then
            s.expireAt = expiry
        end
    end
end

local function OnChatMsgLoot(msg)
    if HAS_LOOT_HISTORY then return end

    local itemID = msg:match("|Hitem:(%d+)")
    if not itemID then return end

    local _, slot = FindSlotByItemID(itemID)
    if not slot then return end

    -- Won
    if TryMatch(msg, PAT_ROLL_YOU_WON) then
        FinishSlotWithWinner(slot, UnitName("player"))
        return
    end
    local wonName = TryMatch(msg, PAT_ROLL_WON)
    if wonName then
        FinishSlotWithWinner(slot, wonName)
        return
    end

    -- All passed
    if TryMatch(msg, PAT_ROLL_ALL_PASS) then
        FinishSlotAllPassed(slot)
        return
    end

    InitChatResults(slot)
    local player = UnitName("player")

    -- "rolled" messages: dice number, itemLink, playerName
    local r1, _, rn1 = TryMatch(msg, PAT_ROLLED_NEED)
    if r1 and rn1 then
        local entry = FindEntryByName(slot.chatNeed, rn1) or FindEntryByName(slot.chatNeed, player)
        if entry then
            entry.roll = tonumber(r1)
        else
            table.insert(slot.chatNeed, { name = rn1, roll = tonumber(r1) })
        end
        UpdateSlotResultDisplay(slot)
        return
    end
    local r2, _, rn2 = TryMatch(msg, PAT_ROLLED_GREED)
    if r2 and rn2 then
        local entry = FindEntryByName(slot.chatGreed, rn2) or FindEntryByName(slot.chatGreed, player)
        if entry then
            entry.roll = tonumber(r2)
        else
            table.insert(slot.chatGreed, { name = rn2, roll = tonumber(r2) })
        end
        UpdateSlotResultDisplay(slot)
        return
    end
    if PAT_ROLLED_DE then
        local r3, _, rn3 = TryMatch(msg, PAT_ROLLED_DE)
        if r3 and rn3 then
            local entry = FindEntryByName(slot.chatGreed, rn3)
            if entry then
                entry.roll = tonumber(r3)
            else
                table.insert(slot.chatGreed, { name = rn3, roll = tonumber(r3) })
            end
            UpdateSlotResultDisplay(slot)
            return
        end
    end

    -- "selected" messages: player chose need/greed/pass (real-time, no dice yet)
    local sn1 = TryMatch(msg, PAT_SEL_NEED)
    if sn1 then
        if not FindEntryByName(slot.chatNeed, sn1) then
            table.insert(slot.chatNeed, { name = sn1 })
        end
        UpdateSlotResultDisplay(slot)
        return
    end
    if TryMatch(msg, PAT_SEL_NEED_SELF) then
        if not FindEntryByName(slot.chatNeed, player) then
            table.insert(slot.chatNeed, { name = player })
        end
        UpdateSlotResultDisplay(slot)
        return
    end

    local sn2 = TryMatch(msg, PAT_SEL_GREED)
    if sn2 then
        if not FindEntryByName(slot.chatGreed, sn2) then
            table.insert(slot.chatGreed, { name = sn2 })
        end
        UpdateSlotResultDisplay(slot)
        return
    end
    if TryMatch(msg, PAT_SEL_GREED_SELF) then
        if not FindEntryByName(slot.chatGreed, player) then
            table.insert(slot.chatGreed, { name = player })
        end
        UpdateSlotResultDisplay(slot)
        return
    end

    local sn3 = TryMatch(msg, PAT_SEL_PASS)
    if sn3 then
        if not FindEntryByName(slot.chatPass, sn3) then
            table.insert(slot.chatPass, { name = sn3 })
        end
        UpdateSlotResultDisplay(slot)
        return
    end
    if TryMatch(msg, PAT_SEL_PASS_SELF) or TryMatch(msg, PAT_SEL_PASS_SELF_AUTO) then
        if not FindEntryByName(slot.chatPass, player) then
            table.insert(slot.chatPass, { name = player })
        end
        UpdateSlotResultDisplay(slot)
        return
    end
    local sn4 = TryMatch(msg, PAT_SEL_PASS_AUTO)
    if sn4 then
        if not FindEntryByName(slot.chatPass, sn4) then
            table.insert(slot.chatPass, { name = sn4 })
        end
        UpdateSlotResultDisplay(slot)
        return
    end
end

------------------------------------------------------------
-- Hide Blizzard roll frames
------------------------------------------------------------
local function HideBlizzardRollFrames()
    local max = NUM_GROUP_LOOT_FRAMES or 4
    for i = 1, max do
        local f = _G["GroupLootFrame" .. i]
        if f and not f._SR_Hooked then
            f:HookScript("OnShow", function(self) self:Hide() end)
            f._SR_Hooked = true
        end
    end
end

------------------------------------------------------------
-- Resolve roll data (handles item cache delay)
------------------------------------------------------------
local function ResolveRoll(rollID)
    local texture, name, count, quality, bop, canNeed, canGreed = GetLootRollItemInfo(rollID)
    local timeLeft = GetLootRollTimeLeft(rollID)
    local itemLink = GetLootRollItemLink and GetLootRollItemLink(rollID)

    if texture and texture ~= 0 and name then
        if timeLeft and type(timeLeft) == "number" then
            timeLeft = timeLeft / 1000
        else
            timeLeft = 60
        end
        AddRoll(rollID, texture, name, quality, timeLeft, canNeed, canGreed, itemLink)
        pendingRolls[rollID] = nil
        return
    end

    if itemLink then
        local iName, _, iQuality, _, _, _, _, _, _, iTexture = GetItemInfo(itemLink)
        if iTexture then
            if timeLeft and type(timeLeft) == "number" then
                timeLeft = timeLeft / 1000
            else
                timeLeft = 60
            end
            AddRoll(rollID, iTexture, iName or name, iQuality or quality, timeLeft, canNeed, canGreed, itemLink)
            pendingRolls[rollID] = nil
            return
        end
    end

    pendingRolls[rollID] = { name = name, quality = quality, canNeed = canNeed, canGreed = canGreed, itemLink = itemLink }
end

------------------------------------------------------------
-- Test (simulates C_LootHistory behavior with fake data)
------------------------------------------------------------
local testItemIDs = { 19019, 18348, 18816, 17063, 18203, 17182, 28579, 23572 }
local testNextIndex = 1

local function TestRolls(count, retryNum)
    count = count or 3
    retryNum = retryNum or 0

    if testNextIndex > #testItemIDs then
        for rollID, slot in pairs(activeRolls) do
            slot:SetScript("OnUpdate", nil)
            ReleaseSlot(slot)
        end
        wipe(activeRolls)
        testNextIndex = 1
        MainFrame:UpdateLayout()
        print("|cFFFFD700SimpleRoll:|r Reset. Run again to preview.")
        return
    end

    UpdateHeader()

    local target = math.min(count, #testItemIDs - testNextIndex + 1)
    for i = testNextIndex, testNextIndex + target - 1 do
        GetItemInfo(testItemIDs[i])
    end

    local fakeNames = { "Thrall", "Jaina", "Sylvanas", "Varian" }
    local added = 0
    for i = testNextIndex, testNextIndex + target - 1 do
        local name, link, quality, _, _, _, _, _, _, icon = GetItemInfo(testItemIDs[i])
        if name and icon then
            added = added + 1
            local sid = 9000 + i
            AddRoll(sid, icon, name, quality, 30, true, true, link)

            -- Simulate other players selecting (before user clicks)
            local s = activeRolls[sid]
            if s then
                InitChatResults(s)
                local delay = math.random(10, 30) / 10
                local otherCount = math.random(2, 3)
                for j = 1, otherCount do
                    local fn = fakeNames[j]
                    local rtype = math.random(0, 2)
                    C_Timer.After(delay, function()
                        local sl = activeRolls[sid]
                        if not sl or sl.over then return end
                        if rtype == 1 then
                            if not FindEntryByName(sl.chatNeed, fn) then
                                table.insert(sl.chatNeed, { name = fn })
                            end
                        elseif rtype == 2 then
                            if not FindEntryByName(sl.chatGreed, fn) then
                                table.insert(sl.chatGreed, { name = fn })
                            end
                        else
                            if not FindEntryByName(sl.chatPass, fn) then
                                table.insert(sl.chatPass, { name = fn })
                            end
                        end
                        UpdateSlotResultDisplay(sl)
                    end)
                    delay = delay + math.random(5, 15) / 10
                end

                -- Winner: poll until user has chosen or timed out
                local function TryFinishSlot()
                    local sl = activeRolls[sid]
                    if not sl or sl.over then return end
                    if not sl.rolled and not sl.timedOut then
                        C_Timer.After(1.0, TryFinishSlot)
                        return
                    end
                    C_Timer.After(1.0, function()
                        local sl2 = activeRolls[sid]
                        if not sl2 or sl2.over then return end
                        local winner
                        if #sl2.chatNeed > 0 then
                            winner = sl2.chatNeed[math.random(#sl2.chatNeed)].name
                        elseif #sl2.chatGreed > 0 then
                            winner = sl2.chatGreed[math.random(#sl2.chatGreed)].name
                        end
                        if winner then
                            FinishSlotWithWinner(sl2, winner)
                        else
                            FinishSlotAllPassed(sl2)
                        end
                    end)
                end
                C_Timer.After(delay + 1.0, TryFinishSlot)
            end
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

    -- Auto-add second wave after 3 seconds
    if testNextIndex <= #testItemIDs then
        C_Timer.After(3, function()
            TestRolls(math.random(2, 3))
        end)
    end
end

------------------------------------------------------------
-- Events
------------------------------------------------------------
EventFrame:RegisterEvent("ADDON_LOADED")
EventFrame:RegisterEvent("PLAYER_LOGIN")
EventFrame:RegisterEvent("START_LOOT_ROLL")
EventFrame:RegisterEvent("CANCEL_LOOT_ROLL")
EventFrame:RegisterEvent("GET_ITEM_INFO_RECEIVED")

if not HAS_LOOT_HISTORY then
    EventFrame:RegisterEvent("CHAT_MSG_LOOT")
end

if HAS_LOOT_HISTORY then
    SafeRegisterEvent(EventFrame, "LOOT_HISTORY_ROLL_CHANGED")
    SafeRegisterEvent(EventFrame, "LOOT_HISTORY_ROLL_COMPLETE")
    SafeRegisterEvent(EventFrame, "LOOT_ROLLS_COMPLETE")
end

EventFrame:SetScript("OnEvent", function(_, event, arg1, arg2)
    if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
        SimpleRollDB = SimpleRollDB or {}
        local pos = SimpleRollDB.pos
        if pos then
            MainFrame:ClearAllPoints()
            MainFrame:SetPoint(pos.point or "TOPLEFT", UIParent, pos.rel or "TOPLEFT", pos.x or 100, pos.y or -200)
        end
        if SimpleRollDB.width then
            FRAME_WIDTH = SimpleRollDB.width
        end
        print(L.loaded)

    elseif event == "PLAYER_LOGIN" then
        UpdateHeader()
        C_Timer.After(0.5, HideBlizzardRollFrames)

    elseif event == "START_LOOT_ROLL" then
        HideBlizzardRollFrames()
        local rollID = arg1
        C_Timer.After(0.05, function() ResolveRoll(rollID) end)

    elseif event == "GET_ITEM_INFO_RECEIVED" then
        if next(pendingRolls) then
            for rollID in pairs(pendingRolls) do
                ResolveRoll(rollID)
            end
        end

    elseif event == "CANCEL_LOOT_ROLL" then
        pendingRolls[arg1] = nil
        local slot = activeRolls[arg1]
        if slot and not HAS_LOOT_HISTORY then
            if not slot.expireAt then
                if not slot.rolled and not slot.timedOut then
                    slot.timedOut = true
                    for _, b in pairs(slot.Buttons) do b:Hide() end
                    slot.ResultText:SetText(L.pass)
                    slot.ResultText:SetTextColor(0.7, 0.7, 0.7)
                    slot.ResultText:Show()
                    slot.TimerBar:Hide()
                end
                slot.expireAt = GetTime() + EXPIRE_ROLLED
                MainFrame:UpdateCloseButton()
            end
        elseif slot then
            RemoveRoll(arg1)
        end

    elseif event == "CHAT_MSG_LOOT" then
        OnChatMsgLoot(arg1)

    elseif event == "LOOT_HISTORY_ROLL_CHANGED" then
        OnRollChanged(arg1, arg2)

    elseif event == "LOOT_HISTORY_ROLL_COMPLETE" or event == "LOOT_ROLLS_COMPLETE" then
        OnRollComplete()
    end
end)

------------------------------------------------------------
-- Slash command
------------------------------------------------------------
SLASH_SIMPLEROLL1 = "/srsr"
SLASH_SIMPLEROLL2 = "/simpleroll"
SlashCmdList["SIMPLEROLL"] = function(msg)
    local cmd = (msg or ""):lower():match("^(%S*)")
    if cmd == "" or cmd == nil then
        TestRolls(math.random(3, 5))
    elseif cmd == "reset" then
        SimpleRollDB = {}
        FRAME_WIDTH = 298
        MainFrame:ClearAllPoints()
        MainFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 100, -200)
        MainFrame:SetWidth(FRAME_WIDTH)
        print("|cFFFFD700SimpleRoll:|r Position & size reset.")
    else
        print("|cFFFFD700SimpleRoll:|r")
        print("  /srsr - " .. L.cmd_preview)
        print("  /srsr " .. L.cmd_reset)
    end
end
