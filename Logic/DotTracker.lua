BossTracker = BossTracker or {}
local BT = BossTracker

BT.Logic = BT.Logic or {}

local DotTracker = {}
BT.Logic.DotTracker = DotTracker

local UnitDebuff = UnitDebuff
local GetTime = GetTime

-- 检测指定单位上玩家施放的某个DOT
-- 返回: { found=bool, remaining=秒, duration=秒, icon=纹理路径 }
function DotTracker:CheckDot(unitId, dotName)
    if not unitId or not UnitExists(unitId) then
        return { found = false }
    end

    for i = 1, 40 do
        local name, icon, count, debuffType, duration, expirationTime, source = UnitDebuff(unitId, i)
        if not name then break end

        if name == dotName and source == "player" then
            local now = GetTime()
            local remaining = expirationTime - now
            if remaining < 0 then remaining = 0 end

            return {
                found     = true,
                remaining = remaining,
                duration  = duration,
                icon      = icon,
                count     = count,
            }
        end
    end

    return { found = false }
end

-- 检测指定单位上所有配置的DOT
-- dotList: classConfig.dots 数组
-- 返回: { [index] = dotInfo }
function DotTracker:CheckAllDots(unitId, dotList)
    local results = {}

    if not unitId or not UnitExists(unitId) or not dotList then
        for i = 1, #(dotList or {}) do
            results[i] = { found = false }
        end
        return results
    end

    -- 先收集单位上的所有debuff，避免重复遍历
    local unitDebuffs = {}
    for i = 1, 40 do
        local name, icon, count, debuffType, duration, expirationTime, source = UnitDebuff(unitId, i)
        if not name then break end
        if source == "player" then
            unitDebuffs[name] = {
                icon           = icon,
                count          = count,
                duration       = duration,
                expirationTime = expirationTime,
            }
        end
    end

    local now = GetTime()
    for i, dotConfig in ipairs(dotList) do
        local debuff = unitDebuffs[dotConfig.name]
        if debuff then
            local remaining = debuff.expirationTime - now
            if remaining < 0 then remaining = 0 end
            results[i] = {
                found     = true,
                remaining = remaining,
                duration  = debuff.duration,
                icon      = debuff.icon,
                count     = debuff.count,
            }
        else
            results[i] = { found = false }
        end
    end

    return results
end
