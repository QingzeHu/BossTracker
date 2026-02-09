BossTracker = BossTracker or {}
local BT = BossTracker

BT.UI = BT.UI or {}

local ConfigFrame = {}
BT.UI.ConfigFrame = ConfigFrame

local GetSpellTexture = GetSpellTexture

-- 配置面板尺寸
local FRAME_WIDTH = 260
local ROW_HEIGHT = 22
local ICON_SIZE = 16
local BTN_SIZE = 14
local PADDING = 8
local TITLE_HEIGHT = 24
local BOTTOM_HEIGHT = 34

-- 本地编辑用的数据
local editingOrder = {}
local editingTimerSize = 14

-- 主框体（延迟创建）
local frame = nil
local rows = {}

--------------------------------------------------------------
-- 刷新所有行的显示内容
--------------------------------------------------------------
local function RefreshRows()
    for i, row in ipairs(rows) do
        local dot = editingOrder[i]
        if dot then
            local iconTexture = dot.spellId and GetSpellTexture(dot.spellId)
            if iconTexture then
                row.icon:SetTexture(iconTexture)
            else
                row.icon:SetColorTexture(0.3, 0.3, 0.3, 1)
            end
            row.name:SetText(dot.name)
            row:Show()
            row.upBtn:SetEnabled(i > 1)
            row.downBtn:SetEnabled(i < #editingOrder)
        else
            row:Hide()
        end
    end
    for i = #editingOrder + 1, #rows do
        rows[i]:Hide()
    end
end

--------------------------------------------------------------
local function SwapDots(indexA, indexB)
    if indexA < 1 or indexB < 1 then return end
    if indexA > #editingOrder or indexB > #editingOrder then return end
    editingOrder[indexA], editingOrder[indexB] = editingOrder[indexB], editingOrder[indexA]
    RefreshRows()
end

--------------------------------------------------------------
local function RefreshTimerSizeText()
    if frame and frame.timerSizeText then
        frame.timerSizeText:SetText(tostring(editingTimerSize))
    end
end

--------------------------------------------------------------
-- 创建单行DOT条目
--------------------------------------------------------------
local function CreateRow(parent, index)
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(FRAME_WIDTH - PADDING * 2, ROW_HEIGHT)

    -- 序号
    row.num = row:CreateFontString(nil, "OVERLAY")
    row.num:SetFont("Fonts\\ARKai_T.ttf", 9, "")
    row.num:SetPoint("LEFT", row, "LEFT", 0, 0)
    row.num:SetTextColor(0.45, 0.45, 0.45, 1)
    row.num:SetText(index .. ".")
    row.num:SetWidth(14)

    -- 法术图标
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(ICON_SIZE, ICON_SIZE)
    row.icon:SetPoint("LEFT", row.num, "RIGHT", 2, 0)
    row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    -- DOT名字
    row.name = row:CreateFontString(nil, "OVERLAY")
    row.name:SetFont("Fonts\\ARKai_T.ttf", 11, "")
    row.name:SetPoint("LEFT", row.icon, "RIGHT", 4, 0)
    row.name:SetTextColor(0.9, 0.9, 0.9, 1)
    row.name:SetJustifyH("LEFT")
    row.name:SetWidth(FRAME_WIDTH - PADDING * 2 - 14 - ICON_SIZE - BTN_SIZE * 2 - 18)

    -- ▼按钮
    row.downBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    row.downBtn:SetSize(BTN_SIZE, BTN_SIZE)
    row.downBtn:SetPoint("RIGHT", row, "RIGHT", 0, 0)
    row.downBtn:SetNormalFontObject("GameFontNormalSmall")
    row.downBtn:SetText("▼")
    row.downBtn:GetFontString():SetFont("Fonts\\ARKai_T.ttf", 7, "")
    row.downBtn:SetScript("OnClick", function()
        SwapDots(index, index + 1)
    end)

    -- ▲按钮
    row.upBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    row.upBtn:SetSize(BTN_SIZE, BTN_SIZE)
    row.upBtn:SetPoint("RIGHT", row.downBtn, "LEFT", -1, 0)
    row.upBtn:SetNormalFontObject("GameFontNormalSmall")
    row.upBtn:SetText("▲")
    row.upBtn:GetFontString():SetFont("Fonts\\ARKai_T.ttf", 7, "")
    row.upBtn:SetScript("OnClick", function()
        SwapDots(index, index - 1)
    end)

    return row
end

--------------------------------------------------------------
-- 创建主配置面板
--------------------------------------------------------------
local function CreateConfigFrame()
    if frame then return frame end

    frame = CreateFrame("Frame", "BossTrackerConfigFrame", UIParent, "BackdropTemplate")
    frame:SetSize(FRAME_WIDTH, 100)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    frame:SetBackdropColor(0.06, 0.06, 0.10, 0.95)
    frame:SetBackdropBorderColor(0.24, 0.24, 0.34, 0.90)

    table.insert(UISpecialFrames, "BossTrackerConfigFrame")

    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)

    -- 标题
    frame.title = frame:CreateFontString(nil, "OVERLAY")
    frame.title:SetFont("Fonts\\ARKai_T.ttf", 11, "OUTLINE")
    frame.title:SetPoint("TOP", frame, "TOP", 0, -5)
    frame.title:SetText("DOT顺序配置")
    frame.title:SetTextColor(0.86, 0.78, 0.50, 1)

    -- 关闭按钮
    frame.closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    frame.closeBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -1)
    frame.closeBtn:SetSize(16, 16)

    -- ====== 倒计时字号控制 ======
    local optY = -(TITLE_HEIGHT + 2)

    frame.timerSizeLabel = frame:CreateFontString(nil, "OVERLAY")
    frame.timerSizeLabel:SetFont("Fonts\\ARKai_T.ttf", 10, "")
    frame.timerSizeLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", PADDING, optY)
    frame.timerSizeLabel:SetText("倒计时字号:")
    frame.timerSizeLabel:SetTextColor(0.65, 0.65, 0.65, 1)

    frame.timerSizeMinusBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    frame.timerSizeMinusBtn:SetSize(16, 16)
    frame.timerSizeMinusBtn:SetPoint("LEFT", frame.timerSizeLabel, "RIGHT", 6, 0)
    frame.timerSizeMinusBtn:SetText("-")
    frame.timerSizeMinusBtn:SetScript("OnClick", function()
        if editingTimerSize > 8 then
            editingTimerSize = editingTimerSize - 1
            RefreshTimerSizeText()
        end
    end)

    frame.timerSizeText = frame:CreateFontString(nil, "OVERLAY")
    frame.timerSizeText:SetFont("Fonts\\ARKai_T.ttf", 11, "OUTLINE")
    frame.timerSizeText:SetPoint("LEFT", frame.timerSizeMinusBtn, "RIGHT", 5, 0)
    frame.timerSizeText:SetTextColor(1, 1, 1, 1)
    frame.timerSizeText:SetText("14")

    frame.timerSizePlusBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    frame.timerSizePlusBtn:SetSize(16, 16)
    frame.timerSizePlusBtn:SetPoint("LEFT", frame.timerSizeText, "RIGHT", 5, 0)
    frame.timerSizePlusBtn:SetText("+")
    frame.timerSizePlusBtn:SetScript("OnClick", function()
        if editingTimerSize < 24 then
            editingTimerSize = editingTimerSize + 1
            RefreshTimerSizeText()
        end
    end)

    -- ====== DOT列表 ======
    local listStartY = optY - 22

    for i = 1, 10 do
        local row = CreateRow(frame, i)
        row:SetPoint("TOPLEFT", frame, "TOPLEFT", PADDING, listStartY - (i - 1) * ROW_HEIGHT)
        row:Hide()
        rows[i] = row
    end

    -- ====== 底部按钮 ======
    frame.saveBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    frame.saveBtn:SetSize(66, 20)
    frame.saveBtn:SetText("保存")
    frame.saveBtn:SetScript("OnClick", function()
        local order = {}
        for _, dot in ipairs(editingOrder) do
            table.insert(order, dot.name)
        end
        BT.Config:Set("options", "dotOrder", order)
        BT.Config:Set("ui", "dotTimerSize", editingTimerSize)
        if BT.RefreshAllDotIcons then
            BT.RefreshAllDotIcons()
        end
        print("|cff00ccff[BT]|r DOT配置已保存")
    end)

    frame.resetBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    frame.resetBtn:SetSize(66, 20)
    frame.resetBtn:SetText("重置默认")
    frame.resetBtn:SetScript("OnClick", function()
        BT.Config:Set("options", "dotOrder", nil)
        BT.Config:Set("ui", "dotTimerSize", 14)
        editingTimerSize = 14
        RefreshTimerSizeText()
        local config = BT.Data.ClassRegistry:GetCurrentConfig()
        editingOrder = {}
        if config and config.dots then
            for i, dot in ipairs(config.dots) do
                editingOrder[i] = dot
            end
        end
        RefreshRows()
        if BT.RefreshAllDotIcons then
            BT.RefreshAllDotIcons()
        end
        print("|cff00ccff[BT]|r DOT配置已重置")
    end)

    frame:Hide()
    return frame
end

--------------------------------------------------------------
function ConfigFrame:Show()
    local f = CreateConfigFrame()

    local dotList = BT.Data.ClassRegistry:GetDotList()
    editingOrder = {}
    for i, dot in ipairs(dotList) do
        editingOrder[i] = dot
    end

    editingTimerSize = BT.Config:Get("ui", "dotTimerSize") or 14
    RefreshTimerSizeText()

    local numDots = #editingOrder
    local listStartOffset = TITLE_HEIGHT + 2 + 22
    local contentHeight = listStartOffset + numDots * ROW_HEIGHT + BOTTOM_HEIGHT
    f:SetHeight(contentHeight)

    f.saveBtn:ClearAllPoints()
    f.saveBtn:SetPoint("BOTTOMRIGHT", f, "BOTTOM", -3, PADDING)
    f.resetBtn:ClearAllPoints()
    f.resetBtn:SetPoint("BOTTOMLEFT", f, "BOTTOM", 3, PADDING)

    RefreshRows()
    f:Show()
end

--------------------------------------------------------------
function ConfigFrame:Hide()
    if frame then frame:Hide() end
end

--------------------------------------------------------------
function ConfigFrame:Toggle()
    if frame and frame:IsShown() then
        self:Hide()
    else
        self:Show()
    end
end
