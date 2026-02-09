BossTracker = BossTracker or {}
BossTracker.Data = BossTracker.Data or {}
BossTracker.Data.Classes = BossTracker.Data.Classes or {}

BossTracker.Data.Classes["WARLOCK_AFFLICTION"] = {
    className   = "术士",
    classNameEN = "WARLOCK",
    specName    = "痛苦",
    talentTab   = 1,

    dots = {
        {
            name      = "暗影之拥",
            spellId   = 32394,
            priority  = 1,
            pandemic  = 0,
            maxStacks = 3,
        },
        {
            name     = "腐蚀术",
            spellId  = 47813,
            priority = 2,
            pandemic = 5,
        },
        {
            name     = "鬼影缠身",
            spellId  = 59164,
            priority = 3,
            pandemic = 4,
        },
        {
            name     = "痛苦无常",
            spellId  = 47843,
            priority = 4,
            pandemic = 5,
        },
        {
            name     = "痛苦诅咒",
            spellId  = 47864,
            priority = 5,
            pandemic = 4,
        },
        {
            name     = "厄运诅咒",
            spellId  = 47867,
            priority = 6,
            pandemic = 0,
        },
        {
            name     = "元素诅咒",
            spellId  = 47865,
            priority = 7,
            pandemic = 0,
        },
    },

    clickCast = {
        rightClick = "鬼影缠身",
        shiftRight = "腐蚀术",
    },
}
