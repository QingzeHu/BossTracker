BossTracker = BossTracker or {}
BossTracker.Data = BossTracker.Data or {}
BossTracker.Data.Classes = BossTracker.Data.Classes or {}

BossTracker.Data.Classes["DRUID_BALANCE"] = {
    className   = "德鲁伊",
    classNameEN = "DRUID",
    specName    = "平衡",
    talentTab   = 1,

    dots = {
        {
            name     = "虫群",
            spellId  = 48468,
            priority = 1,
            pandemic = 4,
        },
        {
            name     = "月火术",
            spellId  = 48463,
            priority = 2,
            pandemic = 4,
        },
        {
            name     = "精灵之火",
            spellId  = 770,
            priority = 3,
            pandemic = 0,
        },
    },
}
