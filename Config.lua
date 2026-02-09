BossTracker = BossTracker or {}
local BT = BossTracker

BT.Config = {}

-- 默认配置
BT.Config.Defaults = {
    ui = {
        -- ====== 布局尺寸 ======
        frameWidth      = 326,
        frameHeight     = 62,
        frameSpacing    = 3,
        portraitSize    = 46,
        healthBarHeight = 10,
        maxBoss         = 5,
        maxDotSlots     = 5,

        -- DOT图标
        dotIconSize     = 29,
        dotSpacing      = 3,
        dotAreaWidth    = 160,
        dotTimerSize    = 10,

        -- WoW原生纹理
        barTexture    = "Interface\\TargetingFrame\\UI-StatusBar",
        bgTexture     = "Interface\\Tooltips\\UI-Tooltip-Background",
        portraitMask  = "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask",

        -- ====== 暗色调配色 ======

        -- 主框体
        bgColor          = { 0.10, 0.10, 0.12, 0.94 },
        bgGradientTop    = { 0.14, 0.13, 0.16, 0.94 },
        bgGradientBottom = { 0.06, 0.06, 0.08, 0.94 },

        -- 边框
        borderOuter      = { 0.18, 0.18, 0.22, 0.70 },
        borderInner      = { 0.04, 0.04, 0.06, 1.00 },
        borderHighlight  = { 0.40, 0.40, 0.45, 0.12 },

        -- 血条
        healthBarBg      = { 0.04, 0.04, 0.06, 1.00 },

        -- 文字
        nameColor        = { 1.00, 1.00, 1.00, 0.95 },

        -- 头像
        portraitBg       = { 0.03, 0.03, 0.05, 1.00 },
        portraitRing     = { 0.30, 0.30, 0.35, 1.00 },
        portraitShadow   = { 0.04, 0.04, 0.06, 1.00 },

        -- DOT文字颜色
        dotTextColor     = { 0.90, 0.90, 0.90, 1.00 },
        dotWarningColor  = { 1.00, 0.30, 0.30, 1.00 },
        dotMissingColor  = { 0.45, 0.45, 0.45, 0.60 },

        -- 目标高亮
        targetHighlight  = { 0.30, 0.70, 1.00, 0.80 },
        targetGlow       = { 0.20, 0.50, 0.85, 0.08 },

        -- 施法条
        castBarHeight       = 10,
        castBarIconSize     = 10,
        castBarTextSize     = 8,
        castBarGap          = 3,
        castBarColor        = { 1.00, 0.70, 0.00, 1.00 },
        castBarChannelColor = { 0.00, 0.80, 0.00, 1.00 },

        -- 字体
        font           = "Fonts\\ARKai_T.ttf",
        nameFontSize   = 12,
        healthTextSize = 9,
        dotTextSize    = 8,
    },
    options = {
        locked       = false,
        testMode     = false,
        debugMode    = false,
        dotSort      = "priority",
        bossSort     = "default",
        pandemicShow = true,
        refreshReminder = true, -- 施法时DOT刷新提醒（读条时高亮即将进入pandemic窗口的DOT）
        dotOrder     = nil,     -- nil=使用class config默认顺序，自定义后存为DOT名称数组
    },
    position = {
        point    = "CENTER",
        relPoint = "CENTER",
        x        = 0,
        y        = 0,
    },
}

-- 深拷贝工具
local function DeepCopy(src)
    if type(src) ~= "table" then return src end
    local copy = {}
    for k, v in pairs(src) do
        copy[k] = DeepCopy(v)
    end
    return copy
end

-- 深合并：将src中存在的键覆盖到dst，保留dst中src没有的键
local function DeepMerge(dst, src)
    for k, v in pairs(src) do
        if type(v) == "table" and type(dst[k]) == "table" then
            DeepMerge(dst[k], v)
        else
            dst[k] = DeepCopy(v)
        end
    end
end

-- 初始化配置（在PLAYER_LOGIN时调用）
function BT.Config:Init()
    -- 确保SavedVariables存在
    BossTrackerDB = BossTrackerDB or {}
    BossTrackerCharDB = BossTrackerCharDB or {}

    -- 从默认值开始，合并已保存的数据
    self.data = DeepCopy(self.Defaults)
    DeepMerge(self.data, BossTrackerDB)
    DeepMerge(self.data, BossTrackerCharDB)
end

-- 获取配置值
function BT.Config:Get(category, key)
    if not self.data then self:Init() end
    if category and key then
        return self.data[category] and self.data[category][key]
    elseif category then
        return self.data[category]
    end
    return self.data
end

-- 设置配置值并保存
function BT.Config:Set(category, key, value)
    if not self.data then self:Init() end
    if not self.data[category] then
        self.data[category] = {}
    end
    self.data[category][key] = value

    -- 同步到SavedVariables
    BossTrackerDB[category] = BossTrackerDB[category] or {}
    BossTrackerDB[category][key] = value
end

-- 保存位置到角色SavedVariables
function BT.Config:SavePosition(point, relPoint, x, y)
    self.data.position = {
        point    = point,
        relPoint = relPoint,
        x        = x,
        y        = y,
    }
    BossTrackerCharDB.position = DeepCopy(self.data.position)
end
