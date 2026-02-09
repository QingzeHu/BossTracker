BossTracker = BossTracker or {}
local BT = BossTracker

BT.UI = BT.UI or {}

local DotIcons = {}
BT.UI.DotIcons = DotIcons

local GetTime = GetTime
local GetSpellTexture = GetSpellTexture

-- 创建单个DOT图标（大图标 + 倒计时覆盖 + 法术名）
function DotIcons:CreateIcon(parent, dotConfig, iconSize)
    local cfg = BT.Config:Get("ui")
    local font = cfg.font
    local timerSize = cfg.dotTimerSize or 14

    -- 容器
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetSize(iconSize, iconSize)
    frame:EnableMouse(false)
    frame.dotConfig = dotConfig

    -- 图标区域框架
    frame.iconFrame = CreateFrame("Frame", nil, frame)
    frame.iconFrame:SetSize(iconSize, iconSize)
    frame.iconFrame:SetPoint("TOP", frame, "TOP", 0, 0)

    -- 边框底色（BORDER层，图标内缩后露出1px边框）
    local bi = cfg.borderInner
    frame.iconBorderTex = frame.iconFrame:CreateTexture(nil, "BORDER")
    frame.iconBorderTex:SetAllPoints()
    frame.iconBorderTex:SetColorTexture(bi[1], bi[2], bi[3], bi[4])

    -- 法术图标（内缩1px，ARTWORK层）
    frame.icon = frame.iconFrame:CreateTexture(nil, "ARTWORK")
    frame.icon:SetPoint("TOPLEFT", frame.iconFrame, "TOPLEFT", 1, -1)
    frame.icon:SetPoint("BOTTOMRIGHT", frame.iconFrame, "BOTTOMRIGHT", -1, 1)
    frame.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    local iconTexture = dotConfig.spellId and GetSpellTexture(dotConfig.spellId)
    if iconTexture then
        frame.icon:SetTexture(iconTexture)
    end

    -- 暗色遮罩（expired状态，OVERLAY层）
    frame.darkOverlay = frame.iconFrame:CreateTexture(nil, "OVERLAY")
    frame.darkOverlay:SetPoint("TOPLEFT", frame.iconFrame, "TOPLEFT", 1, -1)
    frame.darkOverlay:SetPoint("BOTTOMRIGHT", frame.iconFrame, "BOTTOMRIGHT", -1, 1)
    frame.darkOverlay:SetColorTexture(0, 0, 0, 0.5)
    frame.darkOverlay:Hide()

    -- 倒计时文字（居中覆盖在图标上）
    frame.timeText = frame.iconFrame:CreateFontString(nil, "OVERLAY")
    frame.timeText:SetFont(font, timerSize, "OUTLINE")
    frame.timeText:SetPoint("CENTER", frame.iconFrame, "CENTER", 0, 0)
    frame.timeText:SetTextColor(1, 1, 1, 1)

    -- 层数文字（右下角）
    frame.stackText = frame.iconFrame:CreateFontString(nil, "OVERLAY")
    frame.stackText:SetFont(font, 10, "OUTLINE")
    frame.stackText:SetPoint("BOTTOMRIGHT", frame.iconFrame, "BOTTOMRIGHT", -2, 2)
    frame.stackText:SetJustifyH("RIGHT")
    frame.stackText:SetTextColor(1, 1, 1, 1)

    -- 刷新提醒：使用WoW原生法术激活高亮（亮晶晶虚线转圈）
    frame.refreshGlowExpire = 0

    -- 状态缓存
    frame.currentState = "hidden"
    frame.hasBeenSeen = false
    frame.lastSlot = nil

    frame:Hide()
    return frame
end

-- 更新DOT图标状态
function DotIcons:UpdateIcon(iconFrame, dotInfo)
    if not iconFrame then return end

    if dotInfo and dotInfo.found then
        iconFrame.hasBeenSeen = true
        iconFrame:Show()

        local remaining = dotInfo.remaining or 0
        local isWarning = remaining > 0 and remaining < 5

        -- 倒计时文字
        iconFrame.timeText:SetText(BT.Utils.FormatTime(remaining))

        -- 层数
        if iconFrame.dotConfig and iconFrame.dotConfig.maxStacks and dotInfo.count and dotInfo.count > 1 then
            iconFrame.stackText:SetText(dotInfo.count)
        else
            iconFrame.stackText:SetText("")
        end

        -- 显示正常图标
        iconFrame.darkOverlay:Hide()
        iconFrame.icon:SetDesaturated(false)
        iconFrame.icon:SetAlpha(1)

        if isWarning then
            iconFrame.currentState = "warning"
            iconFrame.timeText:SetTextColor(1, 0.3, 0.3, 1)
        else
            iconFrame.currentState = "active"
            iconFrame.timeText:SetTextColor(1, 1, 1, 1)
        end
    else
        if iconFrame.hasBeenSeen then
            iconFrame:Show()
            if iconFrame.currentState ~= "expired" then
                iconFrame.currentState = "expired"
                iconFrame.icon:SetDesaturated(true)
                iconFrame.icon:SetAlpha(0.4)
                iconFrame.darkOverlay:Show()
                iconFrame.timeText:SetText("")
                iconFrame.stackText:SetText("")
            end
        else
            iconFrame:Hide()
            iconFrame.currentState = "hidden"
        end
    end
end

-- 重置图标状态
function DotIcons:ResetIcon(iconFrame)
    if not iconFrame then return end
    iconFrame.hasBeenSeen = false
    iconFrame.currentState = "hidden"
    iconFrame:Hide()
    iconFrame.icon:SetDesaturated(false)
    iconFrame.icon:SetAlpha(1)
    iconFrame.darkOverlay:Hide()
    iconFrame.timeText:SetText("")
    iconFrame.stackText:SetText("")
    iconFrame.lastSlot = nil
    self:HideRefreshGlow(iconFrame)
end

-- 重新分配图标的DOT配置（动态换位时使用）
function DotIcons:AssignDot(iconFrame, dotConfig)
    if not iconFrame then return end
    iconFrame.dotConfig = dotConfig
    local iconTexture = dotConfig.spellId and GetSpellTexture(dotConfig.spellId)
    if iconTexture then
        iconFrame.icon:SetTexture(iconTexture)
    end
end

-- 创建DOT图标列表（水平排列）
function DotIcons:CreateIconRow(parent, dotList, iconSize)
    local cfg = BT.Config:Get("ui")
    local maxSlots = cfg.maxDotSlots or 5
    local icons = {}

    local count = math.min(#dotList, maxSlots)
    for i = 1, count do
        local icon = self:CreateIcon(parent, dotList[i], iconSize)
        icon.assignedDotIndex = i
        icons[i] = icon
    end

    return icons
end

-- 水平重排（左对齐）
function DotIcons:RepositionIcons(icons, parent)
    if not icons or #icons == 0 then return end

    local cfg = BT.Config:Get("ui")
    local iconSize = cfg.dotIconSize or 40
    local spacing = cfg.dotSpacing or 4

    local slot = 0
    for _, icon in ipairs(icons) do
        if icon.hasBeenSeen then
            if icon.lastSlot ~= slot then
                icon:ClearAllPoints()
                icon:SetPoint("TOPLEFT", parent, "TOPLEFT", slot * (iconSize + spacing), 0)
                icon.lastSlot = slot
            end
            slot = slot + 1
        end
    end
end

-- 显示刷新提醒（WoW原生法术激活高亮：亮晶晶虚线转圈）
function DotIcons:ShowRefreshGlow(iconFrame, duration)
    if not iconFrame or not iconFrame.iconFrame then return end
    if ActionButton_ShowOverlayGlow then
        ActionButton_ShowOverlayGlow(iconFrame.iconFrame)
    end
    iconFrame.refreshGlowExpire = GetTime() + duration
end

-- 隐藏刷新提醒
function DotIcons:HideRefreshGlow(iconFrame)
    if not iconFrame then return end
    if ActionButton_HideOverlayGlow and iconFrame.iconFrame then
        ActionButton_HideOverlayGlow(iconFrame.iconFrame)
    end
    iconFrame.refreshGlowExpire = 0
end

-- 检查刷新提醒是否过期，过期则自动隐藏
function DotIcons:UpdateRefreshGlow(iconFrame)
    if not iconFrame then return end
    if iconFrame.refreshGlowExpire > 0 and GetTime() >= iconFrame.refreshGlowExpire then
        self:HideRefreshGlow(iconFrame)
    end
end

-- 批量清除一个frame所有DOT图标的刷新提醒
function DotIcons:ClearAllRefreshGlows(icons)
    if not icons then return end
    for _, iconFrame in ipairs(icons) do
        self:HideRefreshGlow(iconFrame)
    end
end

return DotIcons
