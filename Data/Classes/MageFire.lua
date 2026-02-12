BossTracker = BossTracker or {}
BossTracker.Data = BossTracker.Data or {}
BossTracker.Data.Classes = BossTracker.Data.Classes or {}

BossTracker.Data.Classes["MAGE_FIRE"] = {
    className   = "法师",
    classNameEN = "MAGE",
    specName    = "火焰",
    talentTab   = 2,

    dots = {
        {
            name     = "活体炸弹",
            spellId  = 44457,
            priority = 1,
            pandemic = 4,
        },
        {
            name     = "炎爆术",
            spellId  = 11366,
            priority = 2,
            pandemic = 4,
        },
    },
}
