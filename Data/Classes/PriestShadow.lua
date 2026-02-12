BossTracker = BossTracker or {}
BossTracker.Data = BossTracker.Data or {}
BossTracker.Data.Classes = BossTracker.Data.Classes or {}

BossTracker.Data.Classes["PRIEST_SHADOW"] = {
    className   = "牧师",
    classNameEN = "PRIEST",
    specName    = "暗影",
    talentTab   = 3,

    dots = {
        {
            name     = "吸血鬼之触",
            spellId  = 48160,
            priority = 1,
            pandemic = 5,
        },
        {
            name     = "暗言术：痛",
            spellId  = 48125,
            priority = 2,
            pandemic = 5,
        },
        {
            name     = "噬灵疫病",
            spellId  = 48300,
            priority = 3,
            pandemic = 7,
        },
    },
}
