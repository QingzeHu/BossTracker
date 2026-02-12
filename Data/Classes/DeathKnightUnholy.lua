BossTracker = BossTracker or {}
BossTracker.Data = BossTracker.Data or {}
BossTracker.Data.Classes = BossTracker.Data.Classes or {}

BossTracker.Data.Classes["DEATHKNIGHT_UNHOLY"] = {
    className   = "死亡骑士",
    classNameEN = "DEATHKNIGHT",
    specName    = "邪恶",
    talentTab   = 3,

    dots = {
        {
            name     = "冰霜热疫",
            spellId  = 55095,
            priority = 1,
            pandemic = 5,
        },
        {
            name     = "血之疫病",
            spellId  = 55078,
            priority = 2,
            pandemic = 5,
        },
    },
}
