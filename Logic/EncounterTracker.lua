BossTracker = BossTracker or {}
local BT = BossTracker

BT.Logic = BT.Logic or {}

local EncounterTracker = {}
BT.Logic.EncounterTracker = EncounterTracker

local UnitExists = UnitExists
local UnitGUID = UnitGUID
local UnitName = UnitName
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
    if not self.encounterActive then return end

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

            if target.unitId and UnitExists(target.unitId) then
                -- 已关联单位：正常显示
                frame:Show()
                frame:UpdateAll()
            else
                -- 未关联单位：显示名字，等待单位出现
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
-- 当新单位出现时（boss事件/姓名牌事件），尝试匹配到已追踪的NPC
function EncounterTracker:TryAssignUnit(unitId)
    if not self.encounterActive then return false end
    if not unitId or not UnitExists(unitId) then return false end

    local guid = UnitGUID(unitId)
    local npcId = self:GetNpcIdFromGUID(guid)
    if not npcId then return false end

    local targetIndex = self.trackedNPCs[npcId]
    if not targetIndex then return false end

    local target = self.frameTargets[targetIndex]
    if not target then return false end

    -- 已经关联过相同单位
    if target.unitId == unitId then return false end

    -- 关联单位到框体
    target.unitId = unitId
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
        BT.Utils.Debug("单位关联:", target.name, "→", unitId)
    end
    return true
end

-- 扫描当前已有的boss单位，尝试关联
function EncounterTracker:ScanBossUnits()
    if not self.encounterActive then return end
    for i = 1, 5 do
        local unit = "boss" .. i
        if UnitExists(unit) then
            self:TryAssignUnit(unit)
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
-- SSC模式：玩家目标检测（乱序拉怪）
--------------------------------------------------------------
function EncounterTracker:CheckPlayerTarget()
    if not self.currentRaid then return end
    if self.currentRaid.detectionMode ~= "encounter" then return end
    if self.encounterActive then return end  -- 战斗中不切换

    local targetGUID = UnitGUID("target")
    if not targetGUID then return end

    local npcId = self:GetNpcIdFromGUID(targetGUID)
    if not npcId then return end

    -- 遍历所有encounter查找这个NPC
    for encId, encData in pairs(self.currentRaid.encounters) do
        for _, target in ipairs(encData.targets) do
            if target.npcId == npcId and target.isBoss then
                if self.expectedEncounterId ~= encId then
                    self.expectedEncounterId = encId
                    BT.Utils.Debug("玩家目标切换encounter:", encId, encData.name)
                    -- 脱战时更新宏
                    if not InCombatLockdown() then
                        self:SetupMacros(encData)
                    end
                end
                return
            end
        end
    end
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

-- 检查指定框体是否已关联单位
function EncounterTracker:IsFrameAssigned(frameIndex)
    local target = self.frameTargets[frameIndex]
    return target and target.unitId and UnitExists(target.unitId)
end

--------------------------------------------------------------
-- 重置
--------------------------------------------------------------
function EncounterTracker:Reset()
    self.currentRaid = nil
    self.encounterActive = false
    self.activeEncounter = nil
    self.expectedEncounterId = nil
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
