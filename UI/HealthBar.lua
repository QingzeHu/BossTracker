BossTracker = BossTracker or {}
local BT = BossTracker

BT.UI = BT.UI or {}

local HealthBar = {}
BT.UI.HealthBar = HealthBar

local UnitHealth = UnitHealth
local UnitHealthMax = UnitHealthMax

-- 创建血条（带血量文字覆盖）
function HealthBar:Create(parent, width, height)
    height = height or 20

    local frame = CreateFrame("Frame", nil, parent)
    frame:SetSize(width, height)

    -- 血条背景
    local bgColor = BT.Config:Get("ui", "healthBarBg")
    frame.bg = frame:CreateTexture(nil, "BACKGROUND")
    frame.bg:SetAllPoints()
    frame.bg:SetColorTexture(bgColor[1], bgColor[2], bgColor[3], bgColor[4])

    -- StatusBar
    local barTexture = BT.Config:Get("ui", "barTexture") or "Interface\\TargetingFrame\\UI-StatusBar"
    frame.bar = CreateFrame("StatusBar", nil, frame)
    frame.bar:SetAllPoints()
    frame.bar:SetStatusBarTexture(barTexture)
    frame.bar:SetMinMaxValues(0, 1)
    frame.bar:SetValue(1)
    frame.bar:SetStatusBarColor(0, 1, 0, 1)

    -- 内阴影边框
    local bi = BT.Config:Get("ui", "borderInner")
    frame.borders = BT.Utils.MakeBorder(frame, bi[1], bi[2], bi[3], bi[4])

    -- 血量文字（居中，"85% - 4.3M"）
    local font = BT.Config:Get("ui", "font")
    local textSize = BT.Config:Get("ui", "healthTextSize") or 11
    frame.text = frame.bar:CreateFontString(nil, "OVERLAY")
    frame.text:SetFont(font, textSize, "OUTLINE")
    frame.text:SetPoint("CENTER", frame, "CENTER", 0, 0)
    frame.text:SetTextColor(1, 1, 1, 1)
    frame.text:SetText("")

    frame:EnableMouse(false)
    frame.bar:EnableMouse(false)

    -- 更新血量
    function frame:Update(unitId)
        if not unitId or not UnitExists(unitId) then
            self.bar:SetValue(0)
            self.text:SetText("")
            return 0
        end

        local hp = UnitHealth(unitId)
        local hpMax = UnitHealthMax(unitId)
        local pct = 1
        if hpMax > 0 then
            pct = hp / hpMax
        end

        self.bar:SetValue(pct)
        local r, g, b = BT.Utils.GetHealthColor(pct)
        self.bar:SetStatusBarColor(r, g, b, 1)

        self.text:SetText(BT.Utils.FormatHealth(hp, hpMax))

        return pct
    end

    return frame
end

return HealthBar
