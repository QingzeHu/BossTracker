BossTracker = BossTracker or {}
local BT = BossTracker

BT.UI = BT.UI or {}

local Portrait = {}
BT.UI.Portrait = Portrait

-- 创建头像框体（3D方形 + 圆角矩形边框）
function Portrait:Create(parent, size)
    local cfg = BT.Config:Get("ui")

    local frame = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    frame:SetSize(size, size)
    frame:EnableMouse(false)

    -- 圆角矩形边框
    pcall(function()
        frame:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 8,
            insets = { left = 1, right = 1, top = 1, bottom = 1 },
        })
        local pbg = cfg.portraitBg
        frame:SetBackdropColor(pbg[1], pbg[2], pbg[3], pbg[4])
        local r = cfg.portraitRing
        frame:SetBackdropBorderColor(r[1], r[2], r[3], r[4])
    end)

    -- 2D纹理（默认隐藏，3D失败时回退）
    frame.texture = frame:CreateTexture(nil, "ARTWORK")
    frame.texture:SetPoint("TOPLEFT", 2, -2)
    frame.texture:SetPoint("BOTTOMRIGHT", -2, 2)
    frame.texture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    frame.texture:Hide()

    -- 3D模型（内缩2px，留出边框空间）
    local ok, model = pcall(function()
        local m = CreateFrame("PlayerModel", nil, frame)
        m:SetPoint("TOPLEFT", 2, -2)
        m:SetPoint("BOTTOMRIGHT", -2, 2)
        m:EnableMouse(false)
        return m
    end)

    if ok and model then
        frame.model = model
        frame.is3D = true
    else
        frame.is3D = false
    end

    -- 更新单位头像
    function frame:SetUnit(unitId)
        if not unitId or not UnitExists(unitId) then
            if self.model then
                self.model:ClearModel()
                self.model:Hide()
            end
            self.texture:Hide()
            return
        end

        if self.is3D and self.model then
            local ok2 = pcall(function()
                self.model:SetUnit(unitId)
                self.model:SetPortraitZoom(1)
                self.model:SetCamera(0)
                self.model:SetFacing(0)
            end)

            if ok2 then
                self.model:Show()
                self.texture:Hide()
                return
            end
        end

        -- 回退到2D
        if self.model then
            self.model:Hide()
        end
        SetPortraitTexture(self.texture, unitId)
        self.texture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        self.texture:Show()
    end

    return frame
end

return Portrait
