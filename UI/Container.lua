BossTracker = BossTracker or {}
local BT = BossTracker

BT.UI = BT.UI or {}

local Container = {}
BT.UI.Container = Container

local containerFrame = nil

-- 创建主容器
function Container:Create()
    if containerFrame then return containerFrame end

    local cfg = BT.Config:Get("ui")

    containerFrame = CreateFrame("Frame", "BossTrackerContainer", UIParent)
    containerFrame:SetSize(cfg.frameWidth, cfg.frameHeight * cfg.maxBoss + cfg.frameSpacing * (cfg.maxBoss - 1))
    containerFrame:SetClampedToScreen(true)
    containerFrame:SetFrameStrata("MEDIUM")
    containerFrame:Hide()  -- 默认隐藏，有Boss时才显示

    -- 恢复位置
    local pos = BT.Config:Get("position")
    containerFrame:SetPoint(pos.point, UIParent, pos.relPoint, pos.x, pos.y)

    -- 容器本身不拦截鼠标，让点击穿透到子BossFrame
    containerFrame:SetMovable(true)
    containerFrame:EnableMouse(false)

    -- 拖拽手柄（左上角半透明按钮）
    local handle = CreateFrame("Frame", "BossTrackerDragHandle", containerFrame)
    handle:SetSize(16, 16)
    handle:SetPoint("BOTTOMLEFT", containerFrame, "TOPLEFT", 0, 2)
    handle:SetFrameStrata("HIGH")
    handle:EnableMouse(true)
    handle:RegisterForDrag("LeftButton")

    -- 半透明背景（暗蓝色调）
    handle.bg = handle:CreateTexture(nil, "BACKGROUND")
    handle.bg:SetAllPoints()
    handle.bg:SetColorTexture(0.08, 0.08, 0.14, 0.70)

    -- 冷灰蓝边框
    local bo = cfg.borderOuter
    handle.borders = BT.Utils.MakeBorder(handle, bo[1], bo[2], bo[3], bo[4])

    -- 三条握把线（冷灰蓝）
    for i = 0, 2 do
        local line = handle:CreateTexture(nil, "ARTWORK")
        line:SetSize(8, 1)
        line:SetPoint("CENTER", handle, "CENTER", 0, (1 - i) * 3)
        line:SetColorTexture(0.35, 0.38, 0.48, 0.70)
    end

    -- 拖拽功能（无需Shift，直接拖动）
    handle:SetScript("OnDragStart", function()
        if not InCombatLockdown() then
            containerFrame:StartMoving()
        end
    end)
    handle:SetScript("OnDragStop", function()
        containerFrame:StopMovingOrSizing()
        local point, _, relPoint, x, y = containerFrame:GetPoint()
        BT.Config:SavePosition(point, relPoint, x, y)
    end)

    -- 悬停高亮（亮蓝色调）
    handle:SetScript("OnEnter", function(self)
        self.bg:SetColorTexture(0.15, 0.18, 0.28, 0.85)
    end)
    handle:SetScript("OnLeave", function(self)
        self.bg:SetColorTexture(0.08, 0.08, 0.14, 0.70)
    end)

    containerFrame.dragHandle = handle

    self.frame = containerFrame
    return containerFrame
end

-- 获取主容器
function Container:GetFrame()
    return containerFrame
end

-- 根据可见Boss数量调整容器高度
function Container:UpdateSize(visibleCount)
    if not containerFrame or visibleCount <= 0 then
        if containerFrame then containerFrame:Hide() end
        return
    end

    local cfg = BT.Config:Get("ui")
    local height = cfg.frameHeight * visibleCount + cfg.frameSpacing * (visibleCount - 1)
    containerFrame:SetSize(cfg.frameWidth, height)
    containerFrame:Show()
end

-- 锁定/解锁
function Container:SetLocked(locked)
    BT.Config:Set("options", "locked", locked)
end

-- 切换锁定状态
function Container:ToggleLock()
    local locked = not BT.Config:Get("options", "locked")
    self:SetLocked(locked)
    if locked then
        print("|cff00ccff[BT]|r 框体已锁定")
    else
        print("|cff00ccff[BT]|r 框体已解锁，Shift+拖动移动")
    end
end

-- 重置位置到屏幕中央
function Container:ResetPosition()
    if not containerFrame then return end
    containerFrame:ClearAllPoints()
    containerFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    BT.Config:SavePosition("CENTER", "CENTER", 0, 0)
    print("|cff00ccff[BT]|r 框体位置已重置")
end

-- 显示/隐藏
function Container:Show()
    if containerFrame then
        containerFrame:Show()
    end
end

function Container:Hide()
    if containerFrame then containerFrame:Hide() end
end
