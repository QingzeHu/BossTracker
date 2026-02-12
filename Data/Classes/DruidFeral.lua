BossTracker = BossTracker or {}
BossTracker.Data = BossTracker.Data or {}
BossTracker.Data.Classes = BossTracker.Data.Classes or {}

BossTracker.Data.Classes["DRUID_FERAL"] = {
    className   = "德鲁伊",
    classNameEN = "DRUID",
    specName    = "野性",
    talentTab   = 2,

    dots = {
        {
            name     = "裂伤",
            spellId  = 48566,
            priority = 1,
            pandemic = 0,
        },
        {
            name     = "钉刺",
            spellId  = 48574,
            priority = 2,
            pandemic = 3,
        },
        {
            name     = "割裂",
            spellId  = 49800,
            priority = 3,
            pandemic = 4,
        },
    },
}
