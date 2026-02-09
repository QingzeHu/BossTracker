BossTracker = BossTracker or {}
local BT = BossTracker

BT.UI = BT.UI or {}

local BossFrame = {}
BT.UI.BossFrame = BossFrame

local UnitName = UnitName
local UnitHealth = UnitHealth
local UnitHealthMax = UnitHealthMax
local UnitExists = UnitExists
local UnitGUID = UnitGUID
local GetTime = GetTime

-- 已创建的Boss框体缓存
BossFrame.frames = {}

-- 创建单个Boss条
-- 布局：[圆头像左侧] [血条+名字中间] [DOT图标右侧]
function BossFrame:Create(index, unitId, parentContainer, dotList)
    local cfg = BT.Config:Get("ui")

    local frame = CreateFrame("Frame", "BossTrackerFrame" .. index, parentContainer, "BackdropTemplate")
    frame:SetSize(cfg.frameWidth, cfg.frameHeight)

    -- 定位：从上到下依次排列
    local yOffset = -((index - 1) * (cfg.frameHeight + cfg.frameSpacing))
    frame:SetPoint("TOPLEFT", parentContainer, "TOPLEFT", 0, yOffset)

    frame.unitId = unitId
    frame.index = index

    -- ====== 背景+圆角边框 ======
    pcall(function()
        frame:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true,
            tileSize = 16,
            edgeSize = 14,
            insets = { left = 3, right = 3, top = 3, bottom = 3 },
        })
        frame:SetBackdropColor(cfg.bgColor[1], cfg.bgColor[2], cfg.bgColor[3], cfg.bgColor[4])
        frame:SetBackdropBorderColor(cfg.borderOuter[1], cfg.borderOuter[2], cfg.borderOuter[3], cfg.borderOuter[4])
    end)

    -- ====== 布局参数 ======
    -- 布局：[圆头像左侧] [血条+名字中间] [DOT图标右侧]
    local portraitLeft = 8
    local portraitPadY = math.floor((cfg.frameHeight - cfg.portraitSize) / 2)
    local contentLeft = portraitLeft + cfg.portraitSize + 4
    local dotAreaWidth = cfg.dotAreaWidth or 118
    local iconSize = cfg.dotIconSize or 22
    local rightMargin = 4
    local barDotGap = 4
    local healthBarWidth = cfg.frameWidth - contentLeft - barDotGap - dotAreaWidth - rightMargin

    -- 血条+名字+施法条 垂直居中于头像区域
    local barHeight = cfg.healthBarHeight
    local nameHeight = cfg.nameFontSize
    local vertGap = 4
    local castBarH = cfg.castBarHeight or 10
    local castBarGap = cfg.castBarGap or 3
    local groupH = barHeight + vertGap + nameHeight + castBarGap + castBarH
    local groupTopFromFrame = portraitPadY + math.floor((cfg.portraitSize - groupH) / 2)

    -- ====== 头像（左侧，圆形） ======
    frame.portrait = BT.UI.Portrait:Create(frame, cfg.portraitSize)
    frame.portrait:SetPoint("TOPLEFT", frame, "TOPLEFT", portraitLeft, -portraitPadY)

    -- ====== 血条（头像右侧，上行） ======
    frame.healthBar = BT.UI.HealthBar:Create(frame, healthBarWidth, barHeight)
    frame.healthBar:SetPoint("TOPLEFT", frame, "TOPLEFT", contentLeft, -groupTopFromFrame)

    -- ====== Boss名字（血条下方） ======
    frame.nameText = frame:CreateFontString(nil, "OVERLAY")
    frame.nameText:SetFont(cfg.font, cfg.nameFontSize, "OUTLINE")
    frame.nameText:SetPoint("TOPLEFT", frame, "TOPLEFT", contentLeft, -(groupTopFromFrame + barHeight + vertGap))
    frame.nameText:SetTextColor(cfg.nameColor[1], cfg.nameColor[2], cfg.nameColor[3], cfg.nameColor[4])
    frame.nameText:SetJustifyH("LEFT")
    frame.nameText:SetWidth(healthBarWidth)
    frame.nameText:SetWordWrap(false)

    -- ====== 施法条（名字下方） ======
    local castBarY = -(groupTopFromFrame + barHeight + vertGap + nameHeight + castBarGap)
    frame.castBar = BT.UI.CastBar:Create(frame, healthBarWidth, castBarH)
    frame.castBar:SetPoint("TOPLEFT", frame, "TOPLEFT", contentLeft, castBarY)

    -- ====== DOT区域（右侧，头像垂直居中） ======
    local dotTotalH = iconSize
    local portraitCenterY = portraitPadY + cfg.portraitSize / 2
    local dotPadY = portraitCenterY - iconSize / 2
    frame.dotArea = CreateFrame("Frame", nil, frame)
    frame.dotArea:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -rightMargin, -dotPadY)
    frame.dotArea:SetSize(dotAreaWidth, dotTotalH)
    frame.dotArea:EnableMouse(false)

    -- DOT图标列表
    frame.dotIcons = {}
    if dotList and #dotList > 0 then
        frame.dotIcons = BT.UI.DotIcons:CreateIconRow(frame.dotArea, dotList, iconSize)
    end

    -- ====== 目标高亮 ======
    frame.highlight = BT.UI.Highlight:Create(frame)

    -- ====== 透明点击覆盖层 ======
    frame.secureBtn = CreateFrame("Button", "BossTrackerClick" .. index, frame, "SecureActionButtonTemplate")
    frame.secureBtn:SetAllPoints()
    frame.secureBtn:SetFrameLevel(frame:GetFrameLevel() + 50)
    frame.secureBtn:RegisterForClicks("AnyUp")
    frame.secureBtn:SetAttribute("type1", "macro")
    frame.secureBtn:SetAttribute("macrotext1", "")

    -- ====== 方法 ======

    function frame:UpdateAll()
        self:UpdateInfo()
        self:UpdateHealth()
        self:UpdateDots()
        self:UpdateHighlight()
    end

    frame.lastGUID = nil

    function frame:ResetDotStates()
        for _, iconFrame in ipairs(self.dotIcons) do
            BT.UI.DotIcons:ResetIcon(iconFrame)
            iconFrame.assignedDotIndex = nil
        end
        self.dotSeenState = {}
    end

    function frame:UpdateInfo()
        local uid = self.unitId
        if not UnitExists(uid) then
            self.nameText:SetText("")
            self.lastGUID = nil
            return
        end

        local guid = UnitGUID(uid)
        if guid ~= self.lastGUID then
            self.lastGUID = guid
            self:ResetDotStates()
            if self.castBar then self.castBar:StopCast() end
            if not InCombatLockdown() and self.secureBtn then
                local uname = UnitName(uid)
                if uname then
                    self.secureBtn:SetAttribute("macrotext1", "/targetexact " .. uname)
                end
            end
        end

        local name = UnitName(uid)
        self.nameText:SetText(name or "")
        self.portrait:SetUnit(uid)
    end

    function frame:UpdateHealth()
        self.healthBar:Update(self.unitId)
    end

    function frame:UpdateDots()
        local uid = self.unitId
        local fullDotList = BT.Data.ClassRegistry:GetDotList()
        if not fullDotList or #fullDotList == 0 then return end
        local maxSlots = #self.dotIcons
        if maxSlots == 0 then return end

        -- 检查所有DOT状态（不仅是前maxSlots个）
        local results = BT.Logic.DotTracker:CheckAllDots(uid, fullDotList)

        -- 按DOT索引跟踪是否释放过（切换目标时重置）
        if not self.dotSeenState then self.dotSeenState = {} end

        local activeList = {}   -- 活跃的DOT索引（按优先级顺序）
        local expiredList = {}  -- 过期的DOT索引（按优先级顺序）

        for i, result in ipairs(results) do
            if result and result.found then
                self.dotSeenState[i] = true
                activeList[#activeList + 1] = i
            elseif self.dotSeenState[i] then
                expiredList[#expiredList + 1] = i
            end
        end

        -- 构建显示列表：活跃优先，然后过期，最多maxSlots个
        local displayList = {}
        for _, idx in ipairs(activeList) do
            displayList[#displayList + 1] = idx
            if #displayList >= maxSlots then break end
        end
        if #displayList < maxSlots then
            for _, idx in ipairs(expiredList) do
                displayList[#displayList + 1] = idx
                if #displayList >= maxSlots then break end
            end
        end

        -- 按优先级排序显示列表（保持过期DOT的位置稳定）
        table.sort(displayList)

        -- 分配到图标槽位
        for slot = 1, maxSlots do
            local dotIdx = displayList[slot]
            local iconFrame = self.dotIcons[slot]
            if dotIdx then
                -- 如果分配的DOT变了，更新图标纹理
                if iconFrame.assignedDotIndex ~= dotIdx then
                    BT.UI.DotIcons:AssignDot(iconFrame, fullDotList[dotIdx])
                    iconFrame.assignedDotIndex = dotIdx
                end
                iconFrame.hasBeenSeen = true
                BT.UI.DotIcons:UpdateIcon(iconFrame, results[dotIdx])
            else
                -- 无DOT分配到此槽位
                iconFrame.assignedDotIndex = nil
                iconFrame.hasBeenSeen = false
                iconFrame.currentState = "hidden"
                iconFrame:Hide()
            end
        end

        BT.UI.DotIcons:RepositionIcons(self.dotIcons, self.dotArea)
    end

    function frame:UpdateHighlight()
        BT.UI.Highlight:Update(self.highlight, self.unitId)
    end

    function frame:RecreateDotIcons()
        for _, icon in ipairs(self.dotIcons) do
            icon:Hide()
            icon:ClearAllPoints()
        end
        local newDotList = BT.Data.ClassRegistry:GetDotList()
        local uiCfg = BT.Config:Get("ui")
        local iconSz = uiCfg.dotIconSize or 40
        self.dotIcons = {}
        self.dotSeenState = {}
        if newDotList and #newDotList > 0 then
            self.dotIcons = BT.UI.DotIcons:CreateIconRow(self.dotArea, newDotList, iconSz)
        end
        if self:IsShown() then
            self:UpdateDots()
        end
    end

    function frame:SetUnitId(newUnitId)
        self.unitId = newUnitId
        if not InCombatLockdown() and self.secureBtn then
            if newUnitId and UnitExists(newUnitId) then
                local uname = UnitName(newUnitId)
                if uname then
                    self.secureBtn:SetAttribute("macrotext1", "/targetexact " .. uname)
                end
            end
        end
    end

    frame:Hide()
    self.frames[index] = frame
    return frame
end

-- 获取指定索引的Boss框体
function BossFrame:GetFrame(index)
    return self.frames[index]
end

-- 获取所有Boss框体
function BossFrame:GetAllFrames()
    return self.frames
end

-- 销毁所有Boss框体（隐藏）
function BossFrame:HideAll()
    for _, f in pairs(self.frames) do
        f:Hide()
    end
end

return BossFrame
