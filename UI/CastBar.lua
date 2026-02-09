BossTracker = BossTracker or {}
local BT = BossTracker

BT.UI = BT.UI or {}

local CastBar = {}
BT.UI.CastBar = CastBar

local GetTime = GetTime

-- 创建施法条（法术图标 + 进度条 + 剩余时间）
function CastBar:Create(parent, width, height)
    local cfg = BT.Config:Get("ui")
    height = height or 6

    local frame = CreateFrame("Frame", nil, parent)
    frame:SetSize(width, height)
    frame:EnableMouse(false)
    frame:Hide()

    -- ====== 法术图标（左侧） ======
    local iconSize = cfg.castBarIconSize or 10
    frame.spellIcon = frame:CreateTexture(nil, "ARTWORK")
    frame.spellIcon:SetSize(iconSize, height)
    frame.spellIcon:SetPoint("LEFT", frame, "LEFT", 0, 0)
    frame.spellIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    -- ====== 进度条区域（图标右侧） ======
    local barLeft = iconSize + 2

    -- 背景
    local bgColor = cfg.healthBarBg
    frame.barBg = frame:CreateTexture(nil, "BACKGROUND")
    frame.barBg:SetPoint("TOPLEFT", frame, "TOPLEFT", barLeft, 0)
    frame.barBg:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    frame.barBg:SetColorTexture(bgColor[1], bgColor[2], bgColor[3], bgColor[4])

    -- StatusBar
    local barTexture = cfg.barTexture or "Interface\\TargetingFrame\\UI-StatusBar"
    frame.bar = CreateFrame("StatusBar", nil, frame)
    frame.bar:SetPoint("TOPLEFT", frame, "TOPLEFT", barLeft, 0)
    frame.bar:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    frame.bar:SetStatusBarTexture(barTexture)
    frame.bar:SetMinMaxValues(0, 1)
    frame.bar:SetValue(0)
    frame.bar:EnableMouse(false)

    -- 内边框
    local bi = cfg.borderInner
    frame.borders = BT.Utils.MakeBorder(frame.bar, bi[1], bi[2], bi[3], bi[4])

    -- 时间文字（右对齐）
    local font = cfg.font
    local textSize = cfg.castBarTextSize or 7
    frame.timeText = frame.bar:CreateFontString(nil, "OVERLAY")
    frame.timeText:SetFont(font, textSize, "OUTLINE")
    frame.timeText:SetPoint("RIGHT", frame.bar, "RIGHT", -1, 0)
    frame.timeText:SetTextColor(1, 1, 1, 1)

    -- ====== 状态 ======
    frame.isCasting = false
    frame.isChanneling = false
    frame.castStartTime = 0
    frame.castEndTime = 0
    frame.castDuration = 0

    local castColor = cfg.castBarColor or { 1.00, 0.70, 0.00, 1.00 }
    local channelColor = cfg.castBarChannelColor or { 0.00, 0.80, 0.00, 1.00 }

    -- 开始普通施法
    function frame:StartCast(spellName, spellTexture, startMS, endMS)
        self.isCasting = true
        self.isChanneling = false
        self.castStartTime = startMS / 1000
        self.castEndTime = endMS / 1000
        self.castDuration = self.castEndTime - self.castStartTime

        self.spellIcon:SetTexture(spellTexture)
        self.bar:SetStatusBarColor(castColor[1], castColor[2], castColor[3], castColor[4])
        self:Show()
    end

    -- 开始引导法术
    function frame:StartChannel(spellName, spellTexture, startMS, endMS)
        self.isCasting = false
        self.isChanneling = true
        self.castStartTime = startMS / 1000
        self.castEndTime = endMS / 1000
        self.castDuration = self.castEndTime - self.castStartTime

        self.spellIcon:SetTexture(spellTexture)
        self.bar:SetStatusBarColor(channelColor[1], channelColor[2], channelColor[3], channelColor[4])
        self:Show()
    end

    -- 停止施法条
    function frame:StopCast()
        self.isCasting = false
        self.isChanneling = false
        self:Hide()
    end

    -- 更新进度（OnUpdate调用）
    function frame:UpdateProgress()
        if not self.isCasting and not self.isChanneling then return end

        local now = GetTime()

        if now >= self.castEndTime then
            self:StopCast()
            return
        end

        local remaining = self.castEndTime - now

        if self.isCasting then
            -- 普通施法：从左到右填充
            local elapsed = now - self.castStartTime
            self.bar:SetValue(elapsed / self.castDuration)
        else
            -- 引导法术：从满到空消耗
            self.bar:SetValue(remaining / self.castDuration)
        end

        self.timeText:SetText(BT.Utils.FormatTime(remaining))
    end

    return frame
end

return CastBar
