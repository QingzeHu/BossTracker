BossTracker = BossTracker or {}
BossTracker.Data = BossTracker.Data or {}
BossTracker.Data.Classes = BossTracker.Data.Classes or {}

BossTracker.Data.Classes["HUNTER_SURVIVAL"] = {
    className   = "猎人",
    classNameEN = "HUNTER",
    specName    = "生存",
    talentTab   = 3,

    dots = {
        {
            name     = "毒蛇钉刺",
            spellId  = 49001,
            priority = 1,
            pandemic = 5,
        },
        {
            name     = "猎人印记",
            spellId  = 53338,
            priority = 2,
            pandemic = 0,
        },
        {
            name     = "黑箭",
            spellId  = 63672,
            priority = 3,
            pandemic = 5,
        },
        {
            name     = "爆炸射击",
            spellId  = 60053,
            priority = 4,
            pandemic = 0,
        },
    },
}
