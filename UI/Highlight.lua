BossTracker = BossTracker or {}
local BT = BossTracker

BT.UI = BT.UI or {}

local Highlight = {}
BT.UI.Highlight = Highlight

-- 创建目标高亮（冷蓝光 + 内阴影）
function Highlight:Create(parent)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetAllPoints(parent)
    frame:SetFrameLevel(parent:GetFrameLevel() + 5)
    frame:Hide()
    frame:EnableMouse(false)

    local cfg = BT.Config:Get("ui")
    local c = cfg.targetHighlight
    local glow = cfg.targetGlow

    -- 外圈高亮边框（2px，冷蓝色）
    frame.borders = {}

    frame.borders.top = frame:CreateTexture(nil, "OVERLAY")
    frame.borders.top:SetColorTexture(c[1], c[2], c[3], c[4])
    frame.borders.top:SetPoint("TOPLEFT", -1, 1)
    frame.borders.top:SetPoint("TOPRIGHT", 1, 1)
    frame.borders.top:SetHeight(2)

    frame.borders.bottom = frame:CreateTexture(nil, "OVERLAY")
    frame.borders.bottom:SetColorTexture(c[1], c[2], c[3], c[4])
    frame.borders.bottom:SetPoint("BOTTOMLEFT", -1, -1)
    frame.borders.bottom:SetPoint("BOTTOMRIGHT", 1, -1)
    frame.borders.bottom:SetHeight(2)

    frame.borders.left = frame:CreateTexture(nil, "OVERLAY")
    frame.borders.left:SetColorTexture(c[1], c[2], c[3], c[4])
    frame.borders.left:SetPoint("TOPLEFT", -1, 1)
    frame.borders.left:SetPoint("BOTTOMLEFT", -1, -1)
    frame.borders.left:SetWidth(2)

    frame.borders.right = frame:CreateTexture(nil, "OVERLAY")
    frame.borders.right:SetColorTexture(c[1], c[2], c[3], c[4])
    frame.borders.right:SetPoint("TOPRIGHT", 1, 1)
    frame.borders.right:SetPoint("BOTTOMRIGHT", 1, -1)
    frame.borders.right:SetWidth(2)

    -- 柔和蓝色发光填充
    frame.glow = frame:CreateTexture(nil, "BACKGROUND")
    frame.glow:SetPoint("TOPLEFT", -2, 2)
    frame.glow:SetPoint("BOTTOMRIGHT", 2, -2)
    frame.glow:SetColorTexture(glow[1], glow[2], glow[3], glow[4])

    return frame
end

-- 更新高亮状态
function Highlight:Update(highlightFrame, unitId)
    if not highlightFrame then return end
    if unitId and UnitExists(unitId) and UnitIsUnit(unitId, "target") then
        highlightFrame:Show()
    else
        highlightFrame:Hide()
    end
end

return Highlight
