BossTracker = BossTracker or {}
BossTracker.Data = BossTracker.Data or {}
BossTracker.Data.Classes = BossTracker.Data.Classes or {}

BossTracker.Data.Classes["SHAMAN_ELEMENTAL"] = {
    className   = "萨满祭司",
    classNameEN = "SHAMAN",
    specName    = "元素",
    talentTab   = 1,

    dots = {
        {
            name     = "烈焰震击",
            spellId  = 49233,
            priority = 1,
            pandemic = 5,
        },
    },
}
