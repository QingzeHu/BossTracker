BossTracker = BossTracker or {}
local BT = BossTracker

BT.Utils = {}

-- 血量百分比 → 颜色: >35%绿, 25%~35%黄, <25%红
function BT.Utils.GetHealthColor(pct)
    if pct > 0.35 then
        return 0, 1, 0
    elseif pct > 0.25 then
        return 1, 1, 0
    else
        return 1, 0, 0
    end
end

-- 给框体画1px边框（带偏移量支持，用于多层边框）
function BT.Utils.MakeBorder(parent, r, g, b, a, inset)
    r = r or 0.32
    g = g or 0.34
    b = b or 0.42
    a = a or 0.80
    inset = inset or 0

    local borders = {}

    borders.top = parent:CreateTexture(nil, "BORDER")
    borders.top:SetColorTexture(r, g, b, a)
    borders.top:SetPoint("TOPLEFT", parent, "TOPLEFT", inset, -inset)
    borders.top:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -inset, -inset)
    borders.top:SetHeight(1)

    borders.bottom = parent:CreateTexture(nil, "BORDER")
    borders.bottom:SetColorTexture(r, g, b, a)
    borders.bottom:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", inset, inset)
    borders.bottom:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -inset, inset)
    borders.bottom:SetHeight(1)

    borders.left = parent:CreateTexture(nil, "BORDER")
    borders.left:SetColorTexture(r, g, b, a)
    borders.left:SetPoint("TOPLEFT", parent, "TOPLEFT", inset, -inset)
    borders.left:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", inset, inset)
    borders.left:SetWidth(1)

    borders.right = parent:CreateTexture(nil, "BORDER")
    borders.right:SetColorTexture(r, g, b, a)
    borders.right:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -inset, -inset)
    borders.right:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -inset, inset)
    borders.right:SetWidth(1)

    return borders
end

-- 修改边框颜色
function BT.Utils.ColorBorder(borders, r, g, b, a)
    if not borders then return end
    for _, tex in pairs(borders) do
        tex:SetColorTexture(r, g, b, a)
    end
end

-- 创建双层边框（外层主色+内层阴影，2px总宽）
function BT.Utils.MakeDoubleBorder(parent)
    local cfg = BT.Config:Get("ui")
    local o = cfg.borderOuter
    local i = cfg.borderInner
    return {
        outer = BT.Utils.MakeBorder(parent, o[1], o[2], o[3], o[4], 0),
        inner = BT.Utils.MakeBorder(parent, i[1], i[2], i[3], i[4], 1),
    }
end

-- 创建顶边高光线
function BT.Utils.MakeTopHighlight(parent)
    local cfg = BT.Config:Get("ui")
    local c = cfg.borderHighlight
    local hl = parent:CreateTexture(nil, "BORDER")
    hl:SetColorTexture(c[1], c[2], c[3], c[4])
    hl:SetPoint("TOPLEFT", parent, "TOPLEFT", 2, -2)
    hl:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -2, -2)
    hl:SetHeight(1)
    return hl
end

-- 创建DOT发光纹理
function BT.Utils.MakeGlow(parent, size, layer)
    local cfg = BT.Config:Get("ui")
    local glow = parent:CreateTexture(nil, layer or "OVERLAY")
    glow:SetTexture(cfg.glowTexture)
    glow:SetBlendMode("ADD")
    glow:SetSize(size, size)
    glow:SetPoint("CENTER", parent, "CENTER", 0, 0)
    glow:SetAlpha(0.5)
    glow:Hide()
    return glow
end

-- 格式化血量文字（"85% - 4.3M"）
function BT.Utils.FormatHealth(hp, hpMax)
    local pct = hpMax > 0 and (hp / hpMax * 100) or 0
    local function shortNum(n)
        if n >= 1000000 then
            return string.format("%.1fM", n / 1000000)
        elseif n >= 1000 then
            return string.format("%.0fK", n / 1000)
        else
            return tostring(math.floor(n))
        end
    end
    return string.format("%.0f%% - %s", pct, shortNum(hp))
end

-- 格式化倒计时
function BT.Utils.FormatTime(seconds)
    if not seconds or seconds <= 0 then
        return ""
    elseif seconds < 10 then
        return string.format("%.1f", seconds)
    else
        return string.format("%d", seconds)
    end
end

-- 调试打印
function BT.Utils.Debug(...)
    if not BT.Config or not BT.Config:Get("options", "debugMode") then return end
    local args = { ... }
    local parts = {}
    for i = 1, #args do
        parts[i] = tostring(args[i])
    end
    print("|cff00ccff[BT]|r " .. table.concat(parts, " "))
end
