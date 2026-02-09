BossTracker = BossTracker or {}
local BT = BossTracker

local GetTime = GetTime
local UnitExists = UnitExists
local UnitGUID = UnitGUID
local UnitName = UnitName
local UnitDebuff = UnitDebuff

-- 检查单位是否有玩家施放的debuff（用于同名去重优先级）
local function UnitHasPlayerDebuffs(unitId)
    if not unitId or not UnitExists(unitId) then return false end
    for i = 1, 40 do
        local name, _, _, _, _, _, source = UnitDebuff(unitId, i)
        if not name then break end
        if source == "player" then return true end
    end
    return false
end

--------------------------------------------------------------
-- 主事件框体
--------------------------------------------------------------
local eventFrame = CreateFrame("Frame", "BossTrackerEventFrame", UIParent)

-- 状态变量
local initialized = false
local inCombat = false
local testMode = false
local updateElapsed = 0
local UPDATE_INTERVAL = 0.05  -- 50ms节流
local swapElapsed = 0
local SWAP_INTERVAL = 0.5     -- 500ms检查一次DOT换位

-- 施法条追踪
local castingFrame = nil  -- 当前正在显示施法条的BossFrame

-- Encounter模式（副本Boss追踪）
local encounterMode = false

-- 训练假人模式
local dummyMode = false
local dummySlots = {}       -- { [slotIndex] = "nameplateN" }
local dummyNameplates = {}  -- { ["nameplateN"] = slotIndex }
local pendingDummyExit = false

--------------------------------------------------------------
-- 初始化
--------------------------------------------------------------
local function Initialize()
    if initialized then return end

    -- 初始化配置
    BT.Config:Init()

    -- 检测职业天赋
    BT.Data.ClassRegistry:Detect()

    -- 创建主容器
    BT.UI.Container:Create()

    -- 预创建Boss框体
    local dotList = BT.Data.ClassRegistry:GetDotList()
    local container = BT.UI.Container:GetFrame()
    local maxBoss = BT.Config:Get("ui", "maxBoss")

    for i = 1, maxBoss do
        BT.UI.BossFrame:Create(i, "boss" .. i, container, dotList)
    end

    -- 检测当前副本
    BT.Logic.EncounterTracker:DetectRaid()

    initialized = true
    BT.Utils.Debug("BossTracker 初始化完成")
    print("|cff00ccff[BossTracker]|r 已加载。输入 /bt 查看帮助")
end

--------------------------------------------------------------
-- Boss框体显示/隐藏管理
--------------------------------------------------------------
local function UpdateBossFrameVisibility()
    -- Encounter模式：由EncounterTracker管理框体显示
    if encounterMode then
        local ET = BT.Logic.EncounterTracker
        ET:ScanBossUnits()
        ET:ShowFrames()
        return
    end

    local maxBoss = testMode and 1 or BT.Config:Get("ui", "maxBoss")
    local cfg = BT.Config:Get("ui")
    local seenNames = {}   -- { name = true } 简单去重
    local visibleFrames = {}  -- 按顺序收集要显示的frame

    for i = 1, maxBoss do
        local frame = BT.UI.BossFrame:GetFrame(i)
        if frame then
            local uid = frame.unitId
            if UnitExists(uid) then
                local uname = UnitName(uid)
                if uname and seenNames[uname] then
                    -- 同名重复 → 隐藏
                    frame:Hide()
                else
                    if uname then seenNames[uname] = true end
                    visibleFrames[#visibleFrames + 1] = frame
                end
            else
                frame:Hide()
            end
        end
    end

    -- 隐藏超出范围的框体
    local totalMax = BT.Config:Get("ui", "maxBoss")
    for i = maxBoss + 1, totalMax do
        local frame = BT.UI.BossFrame:GetFrame(i)
        if frame then frame:Hide() end
    end

    -- 动态重排位置：可见框体紧凑排列，消除间隙
    local container = BT.UI.Container:GetFrame()
    for idx, frame in ipairs(visibleFrames) do
        local yOffset = -((idx - 1) * (cfg.frameHeight + cfg.frameSpacing))
        frame:ClearAllPoints()
        frame:SetPoint("TOPLEFT", container, "TOPLEFT", 0, yOffset)
        frame:Show()
        frame:UpdateAll()
    end

    BT.UI.Container:UpdateSize(#visibleFrames)
end

--------------------------------------------------------------
-- 训练假人自动检测
--------------------------------------------------------------

-- 判断单位是否是训练假人（名字包含"假人"）
local function IsDummy(unitId)
    if not UnitExists(unitId) then return false end
    local name = UnitName(unitId)
    return name and name:find("\229\129\135\228\186\186") ~= nil  -- "假人" UTF-8
end

-- 分配一个姓名牌到空闲的Boss框体槽位
local function AssignDummySlot(nameplateUnit)
    if dummyNameplates[nameplateUnit] then return end

    -- 同名去重：如果已有同名单位占据了某个槽位，不再分配新槽
    local newName = UnitName(nameplateUnit)
    if newName then
        for slot, existingUnit in pairs(dummySlots) do
            if UnitExists(existingUnit) and UnitName(existingUnit) == newName then
                BT.Utils.Debug("假人同名跳过", nameplateUnit, "=", existingUnit)
                return
            end
        end
    end

    local maxBoss = BT.Config:Get("ui", "maxBoss")
    for i = 1, maxBoss do
        if not dummySlots[i] then
            dummySlots[i] = nameplateUnit
            dummyNameplates[nameplateUnit] = i
            local frame = BT.UI.BossFrame:GetFrame(i)
            if frame and not InCombatLockdown() then
                frame:SetUnitId(nameplateUnit)
            end
            BT.Utils.Debug("假人分配槽位", i, "→", nameplateUnit)
            return
        end
    end
end

-- 释放假人槽位
local function ReleaseDummySlot(nameplateUnit)
    local slot = dummyNameplates[nameplateUnit]
    if not slot then return end
    dummySlots[slot] = nil
    dummyNameplates[nameplateUnit] = nil
    local frame = BT.UI.BossFrame:GetFrame(slot)
    if frame then
        frame:ResetDotStates()
        frame:Hide()
    end
    BT.Utils.Debug("假人释放槽位", slot)
end

-- 退出假人模式，恢复boss单位ID
local function ExitDummyMode()
    if not dummyMode then return end
    dummyMode = false
    dummySlots = {}
    dummyNameplates = {}

    if InCombatLockdown() then
        pendingDummyExit = true
        return
    end

    local maxBoss = BT.Config:Get("ui", "maxBoss")
    for i = 1, maxBoss do
        local frame = BT.UI.BossFrame:GetFrame(i)
        if frame then
            frame:SetUnitId("boss" .. i)
            frame:Hide()
        end
    end
    BT.UI.Container:Hide()
    BT.Utils.Debug("退出假人模式")
end

-- 执行延迟的假人模式退出（脱战后调用）
local function ProcessPendingDummyExit()
    if not pendingDummyExit then return end
    pendingDummyExit = false

    local maxBoss = BT.Config:Get("ui", "maxBoss")
    for i = 1, maxBoss do
        local frame = BT.UI.BossFrame:GetFrame(i)
        if frame then
            frame:SetUnitId("boss" .. i)
            frame:Hide()
        end
    end
    BT.UI.Container:Hide()
    BT.Utils.Debug("延迟退出假人模式完成")
end

-- 尝试将某个假人槽位切换到有玩家DOT的同名姓名牌
-- 解决问题：去重后显示的那个nameplate可能不是有DOT的那个
local function TrySwapDummyUnit(slot)
    local currentUnit = dummySlots[slot]
    if not currentUnit or not UnitExists(currentUnit) then return end

    -- 如果当前单位已有DOT，不需要换
    if UnitHasPlayerDebuffs(currentUnit) then return end

    local targetName = UnitName(currentUnit)
    if not targetName then return end

    -- 扫描所有姓名牌，找同名且有玩家DOT的
    for i = 1, 40 do
        local npUnit = "nameplate" .. i
        if npUnit ~= currentUnit and UnitExists(npUnit) then
            local npName = UnitName(npUnit)
            if npName == targetName and UnitHasPlayerDebuffs(npUnit) then
                -- 找到了！换过去
                BT.Utils.Debug("假人DOT换位", slot, ":", currentUnit, "→", npUnit)
                -- 更新映射
                dummyNameplates[currentUnit] = nil
                dummySlots[slot] = npUnit
                dummyNameplates[npUnit] = slot
                -- 更新框体的unitId（SetUnitId和UpdateAll内部已处理战斗锁定）
                local frame = BT.UI.BossFrame:GetFrame(slot)
                if frame then
                    frame:SetUnitId(npUnit)
                    frame:UpdateAll()
                end
                return
            end
        end
    end
end

-- 扫描已有的姓名牌（插件加载时可能已有姓名牌）
local function ScanExistingNameplates()
    if testMode then return end
    for i = 1, 40 do
        local unit = "nameplate" .. i
        if UnitExists(unit) and IsDummy(unit) then
            dummyMode = true
            AssignDummySlot(unit)
        end
    end
    if dummyMode then
        UpdateBossFrameVisibility()
    end
end

--------------------------------------------------------------
-- 施法条辅助
--------------------------------------------------------------

-- 根据玩家当前目标，找到对应的BossFrame
local function FindBossFrameForTarget()
    local targetGUID = UnitGUID("target")
    if not targetGUID then return nil end

    local maxBoss = testMode and 1 or BT.Config:Get("ui", "maxBoss")
    for i = 1, maxBoss do
        local frame = BT.UI.BossFrame:GetFrame(i)
        if frame and frame:IsShown() then
            local frameGUID = UnitGUID(frame.unitId)
            if frameGUID == targetGUID then
                return frame
            end
        end
    end
    return nil
end

-- 停止当前施法条显示
local function StopActiveCastBar()
    if castingFrame then
        castingFrame.castBar:StopCast()
        castingFrame = nil
    end
end

--------------------------------------------------------------
-- DOT刷新提醒：施法时预测哪些DOT需要在读条结束后刷新
--------------------------------------------------------------
local REFRESH_GLOW_DURATION = 3  -- 高亮持续秒数

local function CheckRefreshReminders(castEndTime, castSpellName)
    if not BT.Config:Get("options", "refreshReminder") then return end
    local fullDotList = BT.Data.ClassRegistry:GetDotList()
    if not fullDotList or #fullDotList == 0 then return end

    local now = GetTime()
    local castTimeLeft = castEndTime - now
    if castTimeLeft <= 0 then return end

    local maxBoss = testMode and 1 or BT.Config:Get("ui", "maxBoss")
    for i = 1, maxBoss do
        local frame = BT.UI.BossFrame:GetFrame(i)
        if frame and frame:IsShown() and frame.unitId and UnitExists(frame.unitId) then
            local results = BT.Logic.DotTracker:CheckAllDots(frame.unitId, fullDotList)
            for slot, iconFrame in ipairs(frame.dotIcons) do
                local dotIdx = iconFrame.assignedDotIndex
                if dotIdx then
                    local dotCfg = fullDotList[dotIdx]
                    local result = results[dotIdx]
                    if result and result.found
                       and dotCfg.pandemic and dotCfg.pandemic > 0
                       and dotCfg.name ~= castSpellName
                       and result.remaining < castTimeLeft then
                        BT.UI.DotIcons:ShowRefreshGlow(iconFrame, REFRESH_GLOW_DURATION)
                    end
                end
            end
        end
    end
end

local function ClearAllRefreshGlows()
    local maxBoss = testMode and 1 or BT.Config:Get("ui", "maxBoss")
    for i = 1, maxBoss do
        local frame = BT.UI.BossFrame:GetFrame(i)
        if frame then
            BT.UI.DotIcons:ClearAllRefreshGlows(frame.dotIcons)
        end
    end
end

--------------------------------------------------------------
-- 测试模式
--------------------------------------------------------------
local function ToggleTestMode()
    testMode = not testMode
    BT.Config:Set("options", "testMode", testMode)

    -- 进入测试模式时退出假人模式
    if testMode and dummyMode then
        ExitDummyMode()
    end

    local frame1 = BT.UI.BossFrame:GetFrame(1)

    if testMode then
        print("|cff00ccff[BT]|r 测试模式 |cff00ff00开启|r - 选中目标即可预览")
        -- 切换第一个框体为target
        if frame1 and not InCombatLockdown() then
            frame1:SetUnitId("target")
        end
        -- 立即刷新显示（用户可能已经选中了目标）
        UpdateBossFrameVisibility()
    else
        print("|cff00ccff[BT]|r 测试模式 |cffff0000关闭|r")
        -- 恢复为boss1
        if frame1 and not InCombatLockdown() then
            frame1:SetUnitId("boss1")
        end
        -- 隐藏所有框体
        BT.UI.BossFrame:HideAll()
        BT.UI.Container:Hide()
        -- 重新扫描假人
        ScanExistingNameplates()
    end
end

--------------------------------------------------------------
-- 事件处理
--------------------------------------------------------------
local function SafeInitialize()
    if initialized then return end
    local ok, err = pcall(Initialize)
    if not ok then
        print("|cffff0000[BossTracker] 初始化失败:|r " .. tostring(err))
    end
end

local function OnEvent(self, event, ...)
    if event == "ADDON_LOADED" then
        local addonName = ...
        if addonName == "BossTracker" then
            SafeInitialize()
        end

    elseif event == "PLAYER_LOGIN" then
        SafeInitialize()

    elseif event == "PLAYER_ENTERING_WORLD" then
        SafeInitialize()
        -- 检测副本
        BT.Logic.EncounterTracker:DetectRaid()
        -- 脱战时为预期encounter设置宏
        if not InCombatLockdown() then
            BT.Logic.EncounterTracker:SetupExpectedMacros()
        end
        if testMode then
            UpdateBossFrameVisibility()
        else
            -- 进入新区域时扫描已有姓名牌
            ScanExistingNameplates()
        end

    elseif event == "INSTANCE_ENCOUNTER_ENGAGE_UNIT" then
        -- Boss单位出现/变化 → 退出假人模式
        if dummyMode then
            ExitDummyMode()
        end
        -- Encounter模式：尝试关联新出现的boss单位
        if encounterMode then
            BT.Logic.EncounterTracker:ScanBossUnits()
            BT.Logic.EncounterTracker:ShowFrames()
        end
        UpdateBossFrameVisibility()

    elseif event == "ENCOUNTER_START" then
        -- Boss战开始 → 退出假人模式
        if dummyMode then
            ExitDummyMode()
        end
        local encounterID, encounterName = ...
        BT.Utils.Debug("ENCOUNTER_START:", encounterID, encounterName)
        -- 尝试进入encounter模式
        local ET = BT.Logic.EncounterTracker
        if not testMode and ET:IsInConfiguredRaid() then
            if ET:OnEncounterStart(encounterID) then
                encounterMode = true
                BT.Utils.Debug("进入Encounter模式:", encounterName)
            end
        end
        UpdateBossFrameVisibility()

    elseif event == "ENCOUNTER_END" then
        -- Boss战结束
        local encounterID, encounterName, _, _, success = ...
        BT.Utils.Debug("ENCOUNTER_END:", encounterID, encounterName, success == 1 and "胜利" or "失败")
        StopActiveCastBar()
        -- 退出encounter模式
        if encounterMode then
            BT.Logic.EncounterTracker:OnEncounterEnd(encounterID, success)
            encounterMode = false
        end
        if not testMode then
            BT.UI.BossFrame:HideAll()
            BT.UI.Container:Hide()
        end

    elseif event == "UNIT_HEALTH" then
        -- 只更新对应unit的血条
        local unit = ...
        for i = 1, BT.Config:Get("ui", "maxBoss") do
            local frame = BT.UI.BossFrame:GetFrame(i)
            if frame and frame:IsShown() and frame.unitId == unit then
                frame:UpdateHealth()
                break
            end
        end

    elseif event == "UNIT_AURA" then
        -- 只更新对应unit的DOT状态
        local unit = ...
        for i = 1, BT.Config:Get("ui", "maxBoss") do
            local frame = BT.UI.BossFrame:GetFrame(i)
            if frame and frame:IsShown() and frame.unitId == unit then
                frame:UpdateDots()
                break
            end
        end

    elseif event == "PLAYER_TARGET_CHANGED" then
        -- 更新所有框体的高亮
        for i = 1, BT.Config:Get("ui", "maxBoss") do
            local frame = BT.UI.BossFrame:GetFrame(i)
            if frame and frame:IsShown() then
                frame:UpdateHighlight()
            end
        end
        -- Encounter模式：检测玩家目标是否属于其他encounter（乱序拉怪）
        if not encounterMode and BT.Logic.EncounterTracker:IsInConfiguredRaid() then
            BT.Logic.EncounterTracker:CheckPlayerTarget()
        end
        -- 测试模式下，切换目标时刷新
        if testMode then
            UpdateBossFrameVisibility()
        end

    elseif event == "PLAYER_REGEN_DISABLED" then
        -- 进入战斗
        inCombat = true
        BT.Utils.Debug("进入战斗")

    elseif event == "PLAYER_REGEN_ENABLED" then
        -- 脱离战斗
        inCombat = false
        BT.Utils.Debug("脱离战斗")
        -- 处理延迟的假人模式退出
        ProcessPendingDummyExit()
        -- Encounter模式：脱战后更新预期encounter的宏
        if BT.Logic.EncounterTracker:IsInConfiguredRaid() then
            BT.Logic.EncounterTracker:SetupExpectedMacros()
        end

    elseif event == "NAME_PLATE_UNIT_ADDED" then
        local unit = ...
        -- Encounter模式：尝试将新姓名牌匹配到追踪目标
        if encounterMode then
            if BT.Logic.EncounterTracker:TryAssignUnit(unit) then
                BT.Logic.EncounterTracker:ShowFrames()
            end
        elseif not testMode and IsDummy(unit) then
            -- 姓名牌出现 → 检测训练假人
            dummyMode = true
            AssignDummySlot(unit)
            UpdateBossFrameVisibility()
        end

    elseif event == "NAME_PLATE_UNIT_REMOVED" then
        -- 姓名牌消失 → 释放假人槽位
        local unit = ...
        if dummyNameplates[unit] then
            ReleaseDummySlot(unit)
            if not next(dummyNameplates) then
                ExitDummyMode()
            else
                UpdateBossFrameVisibility()
            end
        end

    elseif event == "ZONE_CHANGED_NEW_AREA" then
        -- 区域变化 → 重新检测副本
        BT.Logic.EncounterTracker:DetectRaid()
        if not InCombatLockdown() then
            BT.Logic.EncounterTracker:SetupExpectedMacros()
        end

    -- ====== 施法条事件 ======

    elseif event == "UNIT_SPELLCAST_START" then
        local unit = ...
        if unit == "player" then
            StopActiveCastBar()
            local name, _, texture, startMS, endMS = UnitCastingInfo("player")
            if name then
                local frame = FindBossFrameForTarget()
                if frame then
                    castingFrame = frame
                    frame.castBar:StartCast(name, texture, startMS, endMS)
                end
                -- 刷新提醒：检查读条结束时哪些DOT需要刷新
                ClearAllRefreshGlows()
                CheckRefreshReminders(endMS / 1000, name)
            end
        end

    elseif event == "UNIT_SPELLCAST_STOP"
        or event == "UNIT_SPELLCAST_INTERRUPTED" then
        local unit = ...
        if unit == "player" then
            -- 施法被打断/取消 → 清除刷新提醒
            ClearAllRefreshGlows()
            if not UnitCastingInfo("player") and not UnitChannelInfo("player") then
                StopActiveCastBar()
            end
        end

    elseif event == "UNIT_SPELLCAST_FAILED"
        or event == "UNIT_SPELLCAST_SUCCEEDED" then
        local unit = ...
        if unit == "player" then
            -- SUCCEEDED/FAILED不清除刷新提醒（保留到3秒自然过期）
            -- FAILED常因排队法术触发，SUCCEEDED表示读条完成→提醒仍有效
            if not UnitCastingInfo("player") and not UnitChannelInfo("player") then
                StopActiveCastBar()
            end
        end

    elseif event == "UNIT_SPELLCAST_CHANNEL_START" then
        local unit = ...
        if unit == "player" then
            StopActiveCastBar()
            local name, _, texture, startMS, endMS = UnitChannelInfo("player")
            if name then
                local frame = FindBossFrameForTarget()
                if frame then
                    castingFrame = frame
                    frame.castBar:StartChannel(name, texture, startMS, endMS)
                end
            end
        end

    elseif event == "UNIT_SPELLCAST_CHANNEL_STOP" then
        local unit = ...
        if unit == "player" then
            StopActiveCastBar()
        end

    elseif event == "UNIT_SPELLCAST_CHANNEL_UPDATE" then
        local unit = ...
        if unit == "player" and castingFrame then
            local name, _, texture, startMS, endMS = UnitChannelInfo("player")
            if name then
                castingFrame.castBar.castStartTime = startMS / 1000
                castingFrame.castBar.castEndTime = endMS / 1000
                castingFrame.castBar.castDuration = (endMS - startMS) / 1000
            end
        end
    end
end

--------------------------------------------------------------
-- OnUpdate：DOT倒计时平滑更新
--------------------------------------------------------------
local function OnUpdate(self, elapsed)
    updateElapsed = updateElapsed + elapsed
    if updateElapsed < UPDATE_INTERVAL then return end
    updateElapsed = 0

    -- 假人模式：定期检查DOT换位
    if dummyMode then
        swapElapsed = swapElapsed + UPDATE_INTERVAL
        if swapElapsed >= SWAP_INTERVAL then
            swapElapsed = 0
            for slot, _ in pairs(dummySlots) do
                TrySwapDummyUnit(slot)
            end
        end
    end

    -- 只更新可见框体
    local maxBoss = testMode and 1 or BT.Config:Get("ui", "maxBoss")
    local ET = BT.Logic.EncounterTracker
    for i = 1, maxBoss do
        local frame = BT.UI.BossFrame:GetFrame(i)
        if frame and frame:IsShown() then
            if dummyMode then
                -- 假人模式：轮询血量、DOT和高亮（姓名牌单位的事件可能不触发）
                frame:UpdateHealth()
                frame:UpdateDots()
                frame:UpdateHighlight()
            elseif encounterMode then
                -- Encounter模式：只更新已关联单位的框体
                if ET:IsFrameAssigned(i) then
                    frame:UpdateHealth()
                    frame:UpdateDots()
                    frame:UpdateHighlight()
                end
            else
                -- 正常/测试模式：只更新DOT倒计时数字
                local dotList = BT.Data.ClassRegistry:GetDotList()
                for j, iconFrame in ipairs(frame.dotIcons) do
                    if iconFrame.currentState == "active" or iconFrame.currentState == "warning" then
                        local dotIdx = iconFrame.assignedDotIndex
                        if dotIdx and dotList[dotIdx] then
                            local dotInfo = BT.Logic.DotTracker:CheckDot(frame.unitId, dotList[dotIdx].name)
                            BT.UI.DotIcons:UpdateIcon(iconFrame, dotInfo)
                        end
                    end
                end
            end
        end
    end

    -- 施法条进度更新 + 引导法术轮询回退
    if castingFrame and castingFrame:IsShown() then
        -- 验证施法/引导仍在进行
        if UnitCastingInfo("player") or UnitChannelInfo("player") then
            castingFrame.castBar:UpdateProgress()
        else
            StopActiveCastBar()
        end
    elseif not castingFrame then
        -- 回退检测：某些Cata Classic版本的引导事件可能不触发
        local name, _, texture, startMS, endMS = UnitChannelInfo("player")
        if name then
            local frame = FindBossFrameForTarget()
            if frame then
                castingFrame = frame
                frame.castBar:StartChannel(name, texture, startMS, endMS)
            end
        end
    end

    -- DOT刷新提醒：检查金色边框过期
    for i = 1, maxBoss do
        local frame = BT.UI.BossFrame:GetFrame(i)
        if frame and frame:IsShown() then
            for _, iconFrame in ipairs(frame.dotIcons) do
                if iconFrame.refreshGlowExpire and iconFrame.refreshGlowExpire > 0 then
                    BT.UI.DotIcons:UpdateRefreshGlow(iconFrame)
                end
            end
        end
    end
end

--------------------------------------------------------------
-- 全局刷新DOT图标（配置面板保存后调用）
--------------------------------------------------------------
function BT.RefreshAllDotIcons()
    for i = 1, BT.Config:Get("ui", "maxBoss") do
        local frame = BT.UI.BossFrame:GetFrame(i)
        if frame then
            frame:RecreateDotIcons()
        end
    end
end

--------------------------------------------------------------
-- 注册事件
--------------------------------------------------------------
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("INSTANCE_ENCOUNTER_ENGAGE_UNIT")
eventFrame:RegisterEvent("ENCOUNTER_START")
eventFrame:RegisterEvent("ENCOUNTER_END")
eventFrame:RegisterEvent("UNIT_HEALTH")
eventFrame:RegisterEvent("UNIT_AURA")
eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
eventFrame:RegisterEvent("NAME_PLATE_UNIT_ADDED")
eventFrame:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
eventFrame:RegisterEvent("UNIT_SPELLCAST_START")
eventFrame:RegisterEvent("UNIT_SPELLCAST_STOP")
eventFrame:RegisterEvent("UNIT_SPELLCAST_FAILED")
eventFrame:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
eventFrame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
eventFrame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START")
eventFrame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP")
eventFrame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_UPDATE")

eventFrame:SetScript("OnEvent", OnEvent)
eventFrame:SetScript("OnUpdate", OnUpdate)

--------------------------------------------------------------
-- 斜杠命令
--------------------------------------------------------------
SLASH_BOSSTRACKER1 = "/bt"
SLASH_BOSSTRACKER2 = "/bosstracker"

SlashCmdList["BOSSTRACKER"] = function(msg)
    -- 兜底：如果事件没触发初始化，在第一次用命令时初始化
    SafeInitialize()
    msg = (msg or ""):trim():lower()

    if msg == "" or msg == "help" then
        print("|cff00ccff[BossTracker] 命令列表:|r")
        print("  /bt test   - 切换测试模式")
        print("  /bt config - DOT顺序配置")
        print("  /bt lock   - 切换锁定/解锁")
        print("  /bt reset  - 重置框体位置")
        print("  /bt debug  - 切换调试模式")
        print("  /bt class  - 显示职业天赋检测结果")
        print("  /bt enc    - 显示Encounter模式状态")
        print("  /bt enctest - Encounter测试（主城可用）")

    elseif msg == "config" then
        BT.UI.ConfigFrame:Toggle()

    elseif msg == "test" then
        ToggleTestMode()

    elseif msg == "lock" then
        BT.UI.Container:ToggleLock()

    elseif msg == "reset" then
        BT.UI.Container:ResetPosition()

    elseif msg == "debug" then
        local current = BT.Config:Get("options", "debugMode")
        BT.Config:Set("options", "debugMode", not current)
        if not current then
            print("|cff00ccff[BT]|r 调试模式 |cff00ff00开启|r")
        else
            print("|cff00ccff[BT]|r 调试模式 |cffff0000关闭|r")
        end

    elseif msg == "class" then
        local config = BT.Data.ClassRegistry:GetCurrentConfig()
        if config then
            print("|cff00ccff[BT]|r 当前职业: " .. config.className .. " - " .. config.specName)
            print("|cff00ccff[BT]|r DOT数量: " .. #(config.dots or {}))
            for i, dot in ipairs(config.dots or {}) do
                print("  " .. i .. ". " .. dot.name .. " (优先级: " .. dot.priority .. ")")
            end
        else
            print("|cff00ccff[BT]|r 未检测到匹配的职业配置")
        end

    elseif msg == "enc" or msg == "encounter" then
        BT.Logic.EncounterTracker:PrintStatus()

    elseif msg:sub(1, 7) == "enctest" then
        local args = msg:sub(9):trim()  -- "enctest "之后的参数
        local ET = BT.Logic.EncounterTracker

        if args == "" or args == "help" then
            print("|cff00ccff[BT] Encounter测试命令:|r")
            print("  /bt enctest ssc       - 模拟进入毒蛇神殿")
            print("  /bt enctest tk        - 模拟进入风暴要塞")
            print("  /bt enctest list      - 列出当前副本的encounter")
            print("  /bt enctest start <id> - 模拟开始encounter")
            print("    SSC示例: /bt enctest start 623")
            print("    TK示例: /bt enctest start 凤凰大厅")
            print("  /bt enctest end       - 模拟结束encounter")
            print("  /bt enctest off       - 关闭encounter测试")

        elseif args == "ssc" then
            if ET:ForceRaid(548) then
                print("|cff00ccff[BT]|r 模拟进入 |cff00ff00毒蛇神殿|r")
                ET:ListEncounters()
            end

        elseif args == "tk" then
            if ET:ForceRaid(550) then
                print("|cff00ccff[BT]|r 模拟进入 |cff00ff00风暴要塞|r")
                ET:ListEncounters()
            end

        elseif args == "list" then
            ET:ListEncounters()

        elseif args:sub(1, 5) == "start" then
            local key = args:sub(7):trim()
            if key == "" then
                print("|cff00ccff[BT]|r 用法: /bt enctest start <encounterID或子区域名>")
                return
            end
            -- 尝试作为数字（SSC encounterID）
            local numKey = tonumber(key)
            local ok = false
            if numKey then
                ok = ET:ForceEncounterStart(numKey)
            else
                -- 作为字符串（TK子区域名）— 这里需要原始大小写
                -- 从原始msg中提取（msg已被lower，中文不受影响）
                ok = ET:ForceEncounterStart(key)
            end
            if ok then
                encounterMode = true
                ET:ShowFrames()
                print("|cff00ccff[BT]|r Encounter测试: |cff00ff00" .. ET.activeEncounter.name .. "|r (" .. ET.frameCount .. "个目标)")
            else
                print("|cff00ccff[BT]|r 未找到encounter: " .. key)
                ET:ListEncounters()
            end

        elseif args == "end" then
            if encounterMode then
                ET:OnEncounterEnd(0, 0)
                encounterMode = false
                BT.UI.BossFrame:HideAll()
                BT.UI.Container:Hide()
                print("|cff00ccff[BT]|r Encounter测试结束")
            else
                print("|cff00ccff[BT]|r 当前没有活跃的encounter")
            end

        elseif args == "off" then
            encounterMode = false
            ET:Reset()
            BT.UI.BossFrame:HideAll()
            BT.UI.Container:Hide()
            -- 恢复框体的默认unitId
            if not InCombatLockdown() then
                local maxBoss = BT.Config:Get("ui", "maxBoss")
                for i = 1, maxBoss do
                    local frame = BT.UI.BossFrame:GetFrame(i)
                    if frame then
                        frame:SetUnitId("boss" .. i)
                    end
                end
            end
            print("|cff00ccff[BT]|r Encounter测试已关闭")

        else
            print("|cff00ccff[BT]|r 未知enctest子命令: " .. args .. "。输入 /bt enctest 查看帮助")
        end

    else
        print("|cff00ccff[BT]|r 未知命令: " .. msg .. "。输入 /bt 查看帮助")
    end
end
