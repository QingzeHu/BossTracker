BossTracker = BossTracker or {}
BossTracker.Data = BossTracker.Data or {}
BossTracker.Data.Classes = BossTracker.Data.Classes or {}

BossTracker.Data.Classes["WARLOCK_DESTRUCTION"] = {
    className   = "术士",
    classNameEN = "WARLOCK",
    specName    = "毁灭",
    talentTab   = 3,

    dots = {
        {
            name     = "献祭",
            spellId  = 47811,
            priority = 1,
            pandemic = 5,
        },
        {
            name     = "腐蚀术",
            spellId  = 47813,
            priority = 2,
            pandemic = 5,
        },
        {
            name     = "厄运诅咒",
            spellId  = 47867,
            priority = 3,
            pandemic = 0,
        },
        {
            name     = "元素诅咒",
            spellId  = 47865,
            priority = 4,
            pandemic = 0,
        },
    },
}
