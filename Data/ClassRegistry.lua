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

    -- Cata Classic: 使用 GetPrimaryTalentTree 获取主天赋树索引（最可靠）
    local primaryTab
    if GetPrimaryTalentTree then
        local ok, tab = pcall(GetPrimaryTalentTree)
        if ok and tab then primaryTab = tab end
    end

    -- 回退: 使用 GetTalentTabInfo 比较天赋点数
    -- Cata API 返回: id, name, description, icon, pointsSpent, ...
    -- WotLK API 返回: name, icon, pointsSpent, ...
    local function GetTabPoints(tabIndex)
        if not GetTalentTabInfo then return 0 end
        local results = {pcall(GetTalentTabInfo, tabIndex)}
        if not results[1] then return 0 end
        -- 尝试Cata格式（第6个值）和WotLK格式（第4个值）
        return tonumber(results[6]) or tonumber(results[4]) or 0
    end

    local bestMatch = nil
    local bestPoints = 0
    local fallbackMatch = nil

    for key, config in pairs(BT.Data.Classes) do
        if config.classNameEN == classEN then
            -- 优先: GetPrimaryTalentTree 精确匹配
            if primaryTab and config.talentTab == primaryTab then
                bestMatch = config
                break
            end
            -- 次选: 天赋点数比较（GetPrimaryTalentTree不可用时）
            if not primaryTab then
                local points = GetTabPoints(config.talentTab)
                if points > bestPoints then
                    bestPoints = points
                    bestMatch = config
                end
            end
            -- 回退: 第一个匹配的职业配置
            if not fallbackMatch then
                fallbackMatch = config
            end
        end
    end

    if not bestMatch then
        bestMatch = fallbackMatch
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
