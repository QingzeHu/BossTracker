BossTracker = BossTracker or {}
local BT = BossTracker

BT.Data = BT.Data or {}
BT.Data.Classes = BT.Data.Classes or {}
BT.Data.Raids = BT.Data.Raids or {}

local ClassRegistry = {}
BT.Data.ClassRegistry = ClassRegistry

-- 当前职业配置缓存
ClassRegistry.currentConfig = nil

-- 检测当前职业和天赋，返回匹配的配置
function ClassRegistry:Detect()
    local _, classEN = UnitClass("player")
    if not classEN then return nil end

    -- 遍历所有注册的职业配置，找到匹配的
    local bestMatch = nil
    local bestPoints = 0

    for key, config in pairs(BT.Data.Classes) do
        if config.classNameEN == classEN then
            -- 检查天赋点数（防御性处理，兼容不同客户端版本）
            local tab = config.talentTab
            if tab and GetNumTalentTabs and GetTalentTabInfo then
                local ok, numTabs = pcall(GetNumTalentTabs)
                if ok and numTabs and tab <= numTabs then
                    local ok2, _, _, pointsSpent = pcall(GetTalentTabInfo, tab)
                    pointsSpent = tonumber(pointsSpent) or 0
                    if ok2 and pointsSpent > bestPoints then
                        bestPoints = pointsSpent
                        bestMatch = config
                    end
                end
            end
            -- 如果天赋API不可用或没匹配到，作为默认匹配
            if not bestMatch then
                bestMatch = config
            end
        end
    end

    self.currentConfig = bestMatch
    if bestMatch then
        BT.Utils.Debug("职业检测:", bestMatch.className, bestMatch.specName)
    else
        BT.Utils.Debug("职业检测: 未找到匹配配置, class =", classEN)
    end

    return bestMatch
end

-- 获取当前职业配置
function ClassRegistry:GetCurrentConfig()
    if not self.currentConfig then
        self:Detect()
    end
    return self.currentConfig
end

-- 获取当前职业的DOT列表（支持自定义排序）
function ClassRegistry:GetDotList()
    local config = self:GetCurrentConfig()
    if not config or not config.dots then return {} end

    local dotOrder = BT.Config:Get("options", "dotOrder")
    if not dotOrder then return config.dots end

    -- 按名字建索引
    local byName = {}
    for _, dot in ipairs(config.dots) do
        byName[dot.name] = dot
    end

    -- 按自定义顺序输出
    local ordered = {}
    for _, name in ipairs(dotOrder) do
        if byName[name] then
            table.insert(ordered, byName[name])
            byName[name] = nil
        end
    end

    -- 追加未在自定义列表中的DOT（防止遗漏）
    for _, dot in ipairs(config.dots) do
        if byName[dot.name] then
            table.insert(ordered, dot)
        end
    end

    return ordered
end

-- 获取当前职业的点击施法配置
function ClassRegistry:GetClickCast()
    local config = self:GetCurrentConfig()
    if config and config.clickCast then
        return config.clickCast
    end
    return {}
end
