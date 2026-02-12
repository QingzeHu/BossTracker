BossTracker = BossTracker or {}
local BT = BossTracker

BT.Logic = BT.Logic or {}

local EncounterTracker = {}
BT.Logic.EncounterTracker = EncounterTracker

local UnitExists = UnitExists
local UnitGUID = UnitGUID
local UnitName = UnitName
local UnitIsDead = UnitIsDead
local GetInstanceInfo = GetInstanceInfo
local GetSubZoneText = GetSubZoneText
local InCombatLockdown = InCombatLockdown
local strsplit = strsplit

--------------------------------------------------------------
-- 状态
--------------------------------------------------------------
EncounterTracker.currentRaid = nil           -- 当前副本配置（BT.Data.Raids[mapId]）
EncounterTracker.encounterActive = false     -- 是否处于encounter模式
EncounterTracker.activeEncounter = nil       -- 当前战斗的encounter数据
EncounterTracker.expectedEncounterId = nil   -- SSC模式：下一个预期的encounterID
EncounterTracker.trackedNPCs = {}            -- { [npcId] = targetIndex }
EncounterTracker.frameTargets = {}           -- { [frameIndex] = { name, npcId, unitId } }
EncounterTracker.frameCount = 0             -- 当前encounter的目标数量
EncounterTracker.preshowActive = false       -- 是否处于预显示状态（进入子区域但未开战）
EncounterTracker.preshowEncounter = nil      -- 预显示的encounter数据（用于判断是否同一encounter）

--------------------------------------------------------------
-- GUID解析
--------------------------------------------------------------
-- Cata Classic GUID格式: "unitType-0-serverID-instanceID-zoneUID-npcID-spawnUID"
function EncounterTracker:GetNpcIdFromGUID(guid)
    if not guid or guid == "" then return nil end
    local _, _, _, _, _, npcId = strsplit("-", guid)
    return tonumber(npcId)
end

--------------------------------------------------------------
-- 副本检测
--------------------------------------------------------------
-- 通过GetInstanceInfo()的instanceMapID匹配已注册的副本配置
function EncounterTracker:DetectRaid()
    local _, instanceType, _, _, _, _, _, instanceMapID = GetInstanceInfo()
    if instanceType ~= "raid" then
        self:Reset()
        return
    end

    local raidData = BT.Data.Raids[instanceMapID]
    if raidData then
        self.currentRaid = raidData
        -- SSC模式：设置初始预期encounter
        if raidData.detectionMode == "encounter" and raidData.firstEncounter then
            self.expectedEncounterId = raidData.firstEncounter
        end
        BT.Utils.Debug("检测到副本:", raidData.raidName, "模式:", raidData.detectionMode)
    else
        self:Reset()
    end
end

--------------------------------------------------------------
-- Encounter查找
--------------------------------------------------------------
-- 根据encounterID和副本配置查找encounter数据
function EncounterTracker:FindEncounter(encounterID)
    local raid = self.currentRaid
    if not raid then return nil end

    if raid.detectionMode == "encounter" then
        return raid.encounters[encounterID]
    elseif raid.detectionMode == "subzone" then
        -- subzone模式：先通过encounterIdMap查找子区域名，再查找encounter
        if raid.encounterIdMap then
            local subZone = raid.encounterIdMap[encounterID]
            if subZone and raid.encounters[subZone] then
                return raid.encounters[subZone]
            end
        end
        -- 回退：用当前子区域文本查找
        local subZone = GetSubZoneText()
        if subZone and subZone ~= "" and raid.encounters[subZone] then
            return raid.encounters[subZone]
        end
    end
    return nil
end

--------------------------------------------------------------
-- Encounter开始
--------------------------------------------------------------
function EncounterTracker:OnEncounterStart(encounterID)
    if not self.currentRaid then return false end

    local encounterData = self:FindEncounter(encounterID)
    if not encounterData then
        BT.Utils.Debug("未找到encounter数据:", encounterID)
        return false
    end

    -- 如果预显示已激活且是同一个encounter，直接过渡
    if self.preshowActive and self.preshowEncounter == encounterData then
        self.preshowActive = false
        self.preshowEncounter = nil
        self.encounterActive = true
        self.activeEncounter = encounterData
        BT.Utils.Debug("预显示→Encounter过渡:", encounterData.name)
        return true
    end

    -- 退出预显示（如果是不同encounter）
    if self.preshowActive then
        self.preshowActive = false
        self.preshowEncounter = nil
    end

    self.encounterActive = true
    self.activeEncounter = encounterData
    self.trackedNPCs = {}
    self.frameTargets = {}
    self.frameCount = 0

    -- 构建NPC追踪表和框体目标列表
    local targets = encounterData.targets
    if not targets then return false end

    local maxBoss = BT.Config:Get("ui", "maxBoss")
    for i, target in ipairs(targets) do
        if i > maxBoss then break end
        self.trackedNPCs[target.npcId] = i
        self.frameTargets[i] = {
            name = target.name,
            npcId = target.npcId,
            unitId = nil,  -- 还没关联到具体单位
            guid = nil,
            isDead = false,
        }
        self.frameCount = self.frameCount + 1
    end

    BT.Utils.Debug("Encounter开始:", encounterData.name, "追踪", self.frameCount, "个目标")
    return true
end

--------------------------------------------------------------
-- 显示encounter框体
--------------------------------------------------------------
-- 立即显示所有encounter目标的框体（含未关联单位的）
function EncounterTracker:ShowFrames()
    if not self.encounterActive and not self.preshowActive then return end

    local cfg = BT.Config:Get("ui")
    local container = BT.UI.Container:GetFrame()
    local maxBoss = BT.Config:Get("ui", "maxBoss")

    for i = 1, maxBoss do
        local frame = BT.UI.BossFrame:GetFrame(i)
        if not frame then break end

        local target = self.frameTargets[i]
        if target then
            -- 设置框体位置
            local yOffset = -((i - 1) * (cfg.frameHeight + cfg.frameSpacing))
            frame:ClearAllPoints()
            frame:SetPoint("TOPLEFT", container, "TOPLEFT", 0, yOffset)

            -- 先验证已关联单位是否仍有效（会检测GUID变化并标记死亡）
            local assigned = self:IsFrameAssigned(i)

            if assigned then
                -- 已关联且有效：正常显示
                frame:Show()
                frame:UpdateAll()
            elseif target.isDead then
                -- Boss已死亡：保持显示死亡状态
                frame.unitId = nil  -- 清除旧unitId，防止UNIT_HEALTH事件误更新
                frame:Show()
                frame.nameText:SetText(target.name)
                frame.nameText:SetTextColor(0.5, 0.5, 0.5, 1)
                frame.healthBar.bar:SetValue(0)
                frame.healthBar.bar:SetStatusBarColor(0.3, 0.3, 0.3, 1)
                frame.healthBar.text:SetText("死亡")
                frame:ResetDotStates()
                if frame.castBar then frame.castBar:StopCast() end
            else
                -- 未关联单位：显示名字，等待单位出现
                frame.unitId = nil  -- 清除旧unitId，防止UNIT_HEALTH事件误更新
                frame:Show()
                frame.nameText:SetText(target.name)
                frame.nameText:SetTextColor(0.5, 0.5, 0.5, 1)  -- 灰色表示未关联
                -- 清空血量、头像和DOT
                frame.portrait:SetUnit(nil)
                frame.healthBar:Update(nil)
                frame:ResetDotStates()
                if frame.castBar then frame.castBar:StopCast() end
            end
        else
            frame:Hide()
        end
    end

    BT.UI.Container:UpdateSize(self.frameCount)
end

--------------------------------------------------------------
-- 设置宏文本（必须脱战调用）
--------------------------------------------------------------
-- 为encounter目标设置 /targetexact 宏
function EncounterTracker:SetupMacros(encounterData)
    if InCombatLockdown() then return end
    if not encounterData or not encounterData.targets then return end

    local maxBoss = BT.Config:Get("ui", "maxBoss")
    for i, target in ipairs(encounterData.targets) do
        if i > maxBoss then break end
        local frame = BT.UI.BossFrame:GetFrame(i)
        if frame and frame.secureBtn then
            frame.secureBtn:SetAttribute("macrotext1", "/targetexact " .. target.name)
        end
    end
    BT.Utils.Debug("宏设置完成:", encounterData.name)
end

-- 为预期的encounter设置宏（进副本时/脱战后调用）
function EncounterTracker:SetupExpectedMacros()
    if InCombatLockdown() then return end
    if not self.currentRaid then return end

    local encounterData = nil
    if self.currentRaid.detectionMode == "encounter" then
        if self.expectedEncounterId then
            encounterData = self.currentRaid.encounters[self.expectedEncounterId]
        end
    elseif self.currentRaid.detectionMode == "subzone" then
        local subZone = GetSubZoneText()
        if subZone and subZone ~= "" then
            encounterData = self.currentRaid.encounters[subZone]
        end
    end

    if encounterData then
        self:SetupMacros(encounterData)
    end
end

--------------------------------------------------------------
-- 尝试关联单位
--------------------------------------------------------------
-- 当新单位出现时（boss事件/姓名牌事件/玩家目标），尝试匹配到已追踪的NPC
-- 支持不稳定单位引用（"target"/"focus"/"mouseover"），会自动尝试查找对应姓名牌
function EncounterTracker:TryAssignUnit(unitId)
    if not self.encounterActive and not self.preshowActive then return false end
    if not unitId or not UnitExists(unitId) then return false end

    local guid = UnitGUID(unitId)
    local npcId = self:GetNpcIdFromGUID(guid)
    if not npcId then return false end

    local targetIndex = self.trackedNPCs[npcId]
    if not targetIndex then return false end

    local target = self.frameTargets[targetIndex]
    if not target then return false end

    -- 判断是否为不稳定单位引用（玩家切换目标后会指向不同单位）
    local isVolatile = (unitId == "target" or unitId == "focus" or unitId == "mouseover")

    -- 对于不稳定单位，尝试找到对应的姓名牌（稳定引用）
    if isVolatile then
        for i = 1, 40 do
            local npUnit = "nameplate" .. i
            if UnitExists(npUnit) and UnitGUID(npUnit) == guid then
                unitId = npUnit
                isVolatile = false
                break
            end
        end
    end

    -- 已经关联过相同单位
    if target.unitId == unitId then return false end

    -- 不要用不稳定引用覆盖已有的稳定引用
    if isVolatile and target.unitId and not target.isVolatile then return false end

    -- 关联单位到框体
    target.unitId = unitId
    target.guid = guid
    target.isDead = false
    target.deathShown = false
    target.isVolatile = isVolatile
    local frame = BT.UI.BossFrame:GetFrame(targetIndex)
    if frame then
        -- 更新unitId（SetUnitId会处理战斗锁定）
        if not InCombatLockdown() then
            frame:SetUnitId(unitId)
        else
            frame.unitId = unitId
        end
        -- 恢复名字颜色为正常
        local cfg = BT.Config:Get("ui")
        frame.nameText:SetTextColor(cfg.nameColor[1], cfg.nameColor[2], cfg.nameColor[3], cfg.nameColor[4])
        frame:UpdateAll()
        BT.Utils.Debug("单位关联:", target.name, "→", unitId, isVolatile and "(不稳定)" or "")
    end
    return true
end

-- 扫描当前已有的boss单位，尝试关联
-- 返回 true 表示有新单位被关联
function EncounterTracker:ScanBossUnits()
    if not self.encounterActive and not self.preshowActive then return false end
    local changed = false
    for i = 1, 5 do
        local unit = "boss" .. i
        if UnitExists(unit) then
            if self:TryAssignUnit(unit) then
                changed = true
            end
        end
    end
    return changed
end

-- 扫描当前已有的姓名牌，尝试关联（预显示启动时Boss可能已在附近）
-- 返回 true 表示有新单位被关联
function EncounterTracker:ScanNameplates()
    if not self.encounterActive and not self.preshowActive then return false end
    local changed = false
    for i = 1, 40 do
        local unit = "nameplate" .. i
        if UnitExists(unit) then
            if self:TryAssignUnit(unit) then
                changed = true
            end
        end
    end
    return changed
end

-- 尝试将不稳定引用（target等）升级为稳定的姓名牌引用
function EncounterTracker:UpgradeVolatileUnits()
    for i = 1, self.frameCount do
        local t = self.frameTargets[i]
        if t and t.isVolatile and t.guid then
            for j = 1, 40 do
                local npUnit = "nameplate" .. j
                if UnitExists(npUnit) and UnitGUID(npUnit) == t.guid then
                    -- TryAssignUnit会用稳定的姓名牌替换不稳定引用
                    self:TryAssignUnit(npUnit)
                    break
                end
            end
        end
    end
end

--------------------------------------------------------------
-- Encounter结束
--------------------------------------------------------------
function EncounterTracker:OnEncounterEnd(encounterID, success)
    if not self.encounterActive then return end

    -- SSC模式：击杀成功时推进到下一个encounter
    if success == 1 and self.currentRaid and self.currentRaid.detectionMode == "encounter" then
        local encounterData = self.currentRaid.encounters[encounterID]
        if encounterData and encounterData.nextEncounter then
            self.expectedEncounterId = encounterData.nextEncounter
            BT.Utils.Debug("下一个encounter:", self.expectedEncounterId)
        end
    end

    self.encounterActive = false
    self.activeEncounter = nil
    self.trackedNPCs = {}
    self.frameTargets = {}
    self.frameCount = 0

    BT.Utils.Debug("Encounter结束")
end

--------------------------------------------------------------
-- SSC模式：玩家目标检测（乱序拉怪/点击切换encounter）
-- 返回 true 表示encounter已切换
--------------------------------------------------------------
function EncounterTracker:CheckPlayerTarget()
    if not self.currentRaid then return false end
    if self.currentRaid.detectionMode ~= "encounter" then return false end
    if self.encounterActive then return false end  -- 战斗中不切换

    local targetGUID = UnitGUID("target")
    if not targetGUID then return false end

    local npcId = self:GetNpcIdFromGUID(targetGUID)
    if not npcId then return false end

    -- 遍历所有encounter查找这个NPC（包括Boss和小怪）
    for encId, encData in pairs(self.currentRaid.encounters) do
        for _, target in ipairs(encData.targets) do
            if target.npcId == npcId then
                if self.expectedEncounterId ~= encId then
                    self.expectedEncounterId = encId
                    BT.Utils.Debug("玩家目标切换encounter:", encId, encData.name)
                    -- 脱战时更新宏
                    if not InCombatLockdown() then
                        self:SetupMacros(encData)
                    end
                    return true  -- encounter已切换
                end
                return false  -- 同一个encounter，无变化
            end
        end
    end
    return false
end

--------------------------------------------------------------
-- 预显示：进入子区域时提前显示框体（开战前可点击选目标）
--------------------------------------------------------------
function EncounterTracker:StartPreshow()
    if not self.currentRaid then return false end
    if self.encounterActive then return false end  -- 已在战斗中，不需要preshow
    if InCombatLockdown() then return false end

    -- 根据检测模式查找encounter数据
    local encounterData = nil
    if self.currentRaid.detectionMode == "subzone" then
        local subZone = GetSubZoneText()
        if subZone and subZone ~= "" then
            encounterData = self.currentRaid.encounters[subZone]
        end
    elseif self.currentRaid.detectionMode == "encounter" then
        if self.expectedEncounterId then
            encounterData = self.currentRaid.encounters[self.expectedEncounterId]
        end
    end

    if not encounterData then
        -- 当前位置没有对应的encounter，退出已有preshow
        if self.preshowActive then
            self:ExitPreshow()
        end
        return false
    end

    -- 如果已经在预显示同一个encounter，不重复设置
    if self.preshowActive and self.preshowEncounter == encounterData then
        return true
    end

    -- 退出旧的preshow（如果有）
    if self.preshowActive then
        self:ExitPreshow()
    end

    -- 设置预显示数据（复用OnEncounterStart的逻辑）
    self.trackedNPCs = {}
    self.frameTargets = {}
    self.frameCount = 0

    local targets = encounterData.targets
    if not targets then return false end

    local maxBoss = BT.Config:Get("ui", "maxBoss")
    for i, target in ipairs(targets) do
        if i > maxBoss then break end
        self.trackedNPCs[target.npcId] = i
        self.frameTargets[i] = {
            name = target.name,
            npcId = target.npcId,
            unitId = nil,
            guid = nil,
            isDead = false,
        }
        self.frameCount = self.frameCount + 1
    end

    self.preshowActive = true
    self.preshowEncounter = encounterData

    -- 设置点击宏
    self:SetupMacros(encounterData)

    -- 扫描已有的boss单位和姓名牌（玩家可能已站在Boss附近）
    self:ScanBossUnits()
    self:ScanNameplates()

    -- 显示框体（已关联的显示血量，未关联的灰色占位）
    self:ShowFrames()

    BT.Utils.Debug("预显示开始:", encounterData.name, self.frameCount, "个目标")
    return true
end

function EncounterTracker:ExitPreshow()
    if not self.preshowActive then return end
    self.preshowActive = false
    self.preshowEncounter = nil
    self.trackedNPCs = {}
    self.frameTargets = {}
    self.frameCount = 0

    -- 隐藏框体
    local maxBoss = BT.Config:Get("ui", "maxBoss")
    for i = 1, maxBoss do
        local frame = BT.UI.BossFrame:GetFrame(i)
        if frame then frame:Hide() end
    end
    BT.UI.Container:Hide()

    BT.Utils.Debug("预显示退出")
end

function EncounterTracker:IsPreshowActive()
    return self.preshowActive
end

--------------------------------------------------------------
-- 状态查询
--------------------------------------------------------------
function EncounterTracker:IsActive()
    return self.encounterActive
end

function EncounterTracker:IsInConfiguredRaid()
    return self.currentRaid ~= nil
end

function EncounterTracker:GetFrameCount()
    return self.frameCount
end

-- 检查指定框体是否已关联有效单位
-- 同时验证GUID匹配，防止Boss死亡后WoW重分配bossN单位给其他实体
-- 对于不稳定引用（target/focus），GUID变化时清除关联而非标记死亡
function EncounterTracker:IsFrameAssigned(frameIndex)
    local target = self.frameTargets[frameIndex]
    if not target or not target.unitId then return false end
    if target.isDead then return false end

    -- 不稳定引用特殊处理：玩家切换目标后引用失效，但Boss未死亡
    if target.isVolatile then
        if not UnitExists(target.unitId) or (target.guid and UnitGUID(target.unitId) ~= target.guid) then
            -- 玩家已切换目标，清除关联（不标记死亡）
            target.unitId = nil
            target.isVolatile = false
            return false
        end
        if UnitIsDead(target.unitId) then
            target.isDead = true
            BT.Utils.Debug("Boss已死亡:", target.name)
            return false
        end
        return true
    end

    if not UnitExists(target.unitId) then
        -- 曾关联过单位（有GUID）但现在不存在 → 标记为死亡
        if target.guid then
            target.isDead = true
        end
        return false
    end
    -- 验证GUID匹配（Boss死亡后WoW可能将bossN重分配给小怪）
    if target.guid and UnitGUID(target.unitId) ~= target.guid then
        target.isDead = true
        BT.Utils.Debug("Boss单位已重分配:", target.name, "标记为死亡")
        return false
    end
    -- 检查单位是否已死亡（Boss死了但单位仍然存在、GUID未变的情况）
    if UnitIsDead(target.unitId) then
        target.isDead = true
        BT.Utils.Debug("Boss已死亡:", target.name)
        return false
    end
    return true
end

--------------------------------------------------------------
-- 重置
--------------------------------------------------------------
function EncounterTracker:Reset()
    self.currentRaid = nil
    self.encounterActive = false
    self.activeEncounter = nil
    self.expectedEncounterId = nil
    self.preshowActive = false
    self.preshowEncounter = nil
    self.trackedNPCs = {}
    self.frameTargets = {}
    self.frameCount = 0
end

--------------------------------------------------------------
-- 测试模式：在主城模拟encounter
--------------------------------------------------------------
-- 强制设置副本和encounter（不依赖GetInstanceInfo）
function EncounterTracker:ForceRaid(instanceMapID)
    local raidData = BT.Data.Raids[instanceMapID]
    if not raidData then return false end
    self:Reset()
    self.currentRaid = raidData
    if raidData.detectionMode == "encounter" and raidData.firstEncounter then
        self.expectedEncounterId = raidData.firstEncounter
    end
    return true
end

-- 强制开始一个encounter（用于测试）
-- key: encounterID(数字) 或 子区域名(字符串)
function EncounterTracker:ForceEncounterStart(key)
    if not self.currentRaid then return false end

    local encounterData = nil
    if self.currentRaid.detectionMode == "encounter" then
        local encId = tonumber(key)
        if encId then
            encounterData = self.currentRaid.encounters[encId]
        end
    elseif self.currentRaid.detectionMode == "subzone" then
        encounterData = self.currentRaid.encounters[key]
    end

    if not encounterData then return false end

    -- 复用 OnEncounterStart 的逻辑，但这里直接设置数据
    self.encounterActive = true
    self.activeEncounter = encounterData
    self.trackedNPCs = {}
    self.frameTargets = {}
    self.frameCount = 0

    local maxBoss = BT.Config:Get("ui", "maxBoss")
    for i, target in ipairs(encounterData.targets) do
        if i > maxBoss then break end
        self.trackedNPCs[target.npcId] = i
        self.frameTargets[i] = {
            name = target.name,
            npcId = target.npcId,
            unitId = nil,
            guid = nil,
            isDead = false,
        }
        self.frameCount = self.frameCount + 1
    end

    -- 脱战时设置宏
    if not InCombatLockdown() then
        self:SetupMacros(encounterData)
    end

    return true
end

-- 列出副本内所有encounter（帮助命令）
function EncounterTracker:ListEncounters()
    if not self.currentRaid then
        print("|cff00ccff[BT]|r 未设置副本。用法: /bt enctest ssc 或 /bt enctest tk")
        return
    end
    local raid = self.currentRaid
    print("|cff00ccff[BT]|r " .. raid.raidName .. " 的Encounter列表:")
    if raid.detectionMode == "encounter" then
        -- 按nextEncounter链顺序输出
        local encId = raid.firstEncounter
        local idx = 1
        while encId do
            local enc = raid.encounters[encId]
            if not enc then break end
            local targetNames = {}
            for _, t in ipairs(enc.targets) do
                targetNames[#targetNames + 1] = t.name
            end
            print(string.format("  %d. [%d] %s (%d目标: %s)",
                idx, encId, enc.name, #enc.targets, table.concat(targetNames, ", ")))
            encId = enc.nextEncounter
            idx = idx + 1
        end
        print("|cff00ccff[BT]|r 用法: /bt enctest start <encounterID>")
    elseif raid.detectionMode == "subzone" then
        local idx = 1
        for subZone, enc in pairs(raid.encounters) do
            local targetNames = {}
            for _, t in ipairs(enc.targets) do
                targetNames[#targetNames + 1] = t.name
            end
            print(string.format("  %d. [%s] %s (%d目标: %s)",
                idx, subZone, enc.name, #enc.targets, table.concat(targetNames, ", ")))
            idx = idx + 1
        end
        print("|cff00ccff[BT]|r 用法: /bt enctest start <子区域名>")
    end
end

--------------------------------------------------------------
-- 调试信息
--------------------------------------------------------------
function EncounterTracker:PrintStatus()
    if self.encounterActive then
        local enc = self.activeEncounter
        print("|cff00ccff[BT]|r Encounter模式: |cff00ff00激活|r")
        print("  副本:", self.currentRaid and self.currentRaid.raidName or "无")
        print("  Encounter:", enc and enc.name or "无")
        print("  追踪目标:", self.frameCount)
        for i = 1, self.frameCount do
            local t = self.frameTargets[i]
            if t then
                local status = t.unitId and ("|cff00ff00" .. t.unitId .. "|r") or "|cffff0000未关联|r"
                print("    " .. i .. ". " .. t.name .. " (NPC " .. t.npcId .. ") → " .. status)
            end
        end
    else
        print("|cff00ccff[BT]|r Encounter模式: |cffff0000未激活|r")
        if self.currentRaid then
            print("  副本:", self.currentRaid.raidName, "(" .. self.currentRaid.detectionMode .. ")")
            if self.expectedEncounterId then
                local enc = self.currentRaid.encounters[self.expectedEncounterId]
                print("  预期Encounter:", self.expectedEncounterId, enc and enc.name or "")
            end
        else
            print("  未在已配置的副本中")
        end
    end
end
