BossTracker = BossTracker or {}
BossTracker.Data = BossTracker.Data or {}
BossTracker.Data.Raids = BossTracker.Data.Raids or {}

-- ==================
-- 毒蛇神殿 (Serpentshrine Cavern)
-- instanceMapID = 548
-- detectionMode = "encounter" — 所有Boss共享同一子区域，用encounterID检测
-- ==================
BossTracker.Data.Raids[548] = {
    raidName = "毒蛇神殿",
    tier = "T2",
    detectionMode = "encounter",
    firstEncounter = 623,

    encounters = {
        -- 1号：不稳定的海度斯
        [623] = {
            name = "不稳定的海度斯",
            nextEncounter = 624,
            targets = {{
                npcId = 21216,
                name = "不稳定的海度斯",
                isBoss = true
            }, {
                npcId = 22036,
                name = "污染的海度斯爪牙",
                isBoss = false
            }}
        },
        -- 2号：鱼斯拉
        [624] = {
            name = "鱼斯拉",
            nextEncounter = 625,
            targets = {{
                npcId = 21217,
                name = "鱼斯拉",
                isBoss = true
            }, {
                npcId = 21865,
                name = "盘牙伏击者",
                isBoss = false
            }, {
                npcId = 21873,
                name = "盘牙守护者",
                isBoss = false
            }}
        },
        -- 3号：盲眼者莱欧瑟拉斯
        [625] = {
            name = "盲眼者莱欧瑟拉斯",
            nextEncounter = 626,
            targets = {{
                npcId = 21215,
                name = "盲眼者莱欧瑟拉斯",
                isBoss = true
            }, {
                npcId = 21875,
                name = "莱欧瑟拉斯之影",
                isBoss = false
            }, {
                npcId = 21857,
                name = "内心之魔",
                isBoss = false
            }}
        },
        -- 4号：深水领主卡拉瑟雷斯
        [626] = {
            name = "深水领主卡拉瑟雷斯",
            nextEncounter = 627,
            targets = {{
                npcId = 21214,
                name = "深水领主卡拉瑟雷斯",
                isBoss = true
            }, {
                npcId = 21966,
                name = "深水卫士沙克基斯",
                isBoss = true
            }, {
                npcId = 21965,
                name = "深水卫士泰达维斯",
                isBoss = true
            }, {
                npcId = 21964,
                name = "深水卫士卡莉蒂丝",
                isBoss = true
            }}
        },
        -- 5号：莫洛格里·踏潮者
        [627] = {
            name = "莫洛格里·踏潮者",
            nextEncounter = 628,
            targets = {{
                npcId = 21213,
                name = "莫洛格里·踏潮者",
                isBoss = true
            }}
        },
        -- 6号：瓦丝琪
        [628] = {
            name = "瓦丝琪",
            nextEncounter = nil,
            targets = {{
                npcId = 21212,
                name = "瓦丝琪",
                isBoss = true
            }, {
                npcId = 22056,
                name = "盘牙巡逻者",
                isBoss = false
            }, {
                npcId = 22055,
                name = "盘牙精英",
                isBoss = false
            }}
        }
    }
}
