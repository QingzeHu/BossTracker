BossTracker = BossTracker or {}
BossTracker.Data = BossTracker.Data or {}
BossTracker.Data.Classes = BossTracker.Data.Classes or {}

BossTracker.Data.Classes["HUNTER_MARKSMANSHIP"] = {
    className   = "猎人",
    classNameEN = "HUNTER",
    specName    = "射击",
    talentTab   = 2,

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
    },
}
