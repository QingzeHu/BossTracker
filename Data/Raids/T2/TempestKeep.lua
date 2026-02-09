BossTracker = BossTracker or {}
BossTracker.Data = BossTracker.Data or {}
BossTracker.Data.Raids = BossTracker.Data.Raids or {}

-- ==================
-- 风暴要塞 (Tempest Keep: The Eye)
-- instanceMapID = 550
-- detectionMode = "subzone" — 每个Boss有独立子区域，用GetSubZoneText()检测
-- ==================
BossTracker.Data.Raids[550] = {
    raidName = "风暴要塞",
    tier = "T2",
    detectionMode = "subzone",

    -- encounterID → 子区域名映射（用于ENCOUNTER_START事件查找）
    encounterIdMap = {
        [730] = "凤凰大厅",
        [731] = "熔炉",
        [732] = "日晷台",
        [733] = "风暴之桥",
    },

    -- 以子区域名为key的encounter数据
    encounters = {
        -- 1号：奥（凤凰大厅）
        ["凤凰大厅"] = {
            name = "奥",
            targets = {
                { npcId = 19514, name = "奥", isBoss = true },
                { npcId = 19551, name = "奥的灰烬", isBoss = false },
            },
        },
        -- 2号：空灵机甲（熔炉）
        ["熔炉"] = {
            name = "空灵机甲",
            targets = {
                { npcId = 19516, name = "空灵机甲", isBoss = true },
            },
        },
        -- 3号：大星术师索兰莉安（日晷台）
        ["日晷台"] = {
            name = "大星术师索兰莉安",
            targets = {
                { npcId = 18805, name = "大星术师索兰莉安", isBoss = true },
                { npcId = 18925, name = "日晷密探", isBoss = false },
                { npcId = 18806, name = "日晷祭司", isBoss = false },
            },
        },
        -- 4号：凯尔萨斯·逐日者（风暴之桥）
        ["风暴之桥"] = {
            name = "凯尔萨斯·逐日者",
            targets = {
                { npcId = 19622, name = "凯尔萨斯·逐日者", isBoss = true },
                { npcId = 20064, name = "亵渎者萨拉德雷", isBoss = true },
                { npcId = 20060, name = "萨古纳尔男爵", isBoss = true },
                { npcId = 20062, name = "星术师卡波妮娅", isBoss = true },
                { npcId = 20063, name = "首席技师塔隆尼库斯", isBoss = true },
            },
        },
    },
}
