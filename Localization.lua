Rinse = {}
Rinse.L = {
    -- Dispel types
    ["Snare"] = 1, -- not a real type
    ["Magic"] = 1,
    ["Curse"] = 1,
    ["Disease"] = 1,
    ["Poison"] = 1,

    -- Player dispel abilities
    ["Cleanse"] = 1,
    ["Purify"] = 1,
    ["Hand of Freedom"] = 1,
    ["Remove Curse"] = 1,
    ["Abolish Poison"] = 1,
    ["Dispel Magic"] = 1,
    ["Abolish Disease"] = 1,
    ["Remove Lesser Curse"] = 1,
    ["Devour Magic"] = 1,
    ["Cure Disease"] = 1,
    ["Cure Poison"] = 1,

    -- Debuff names
    ["Curse of Recklessness"] = 1,
    ["Delusions of Jin'do"] = 1,
    ["Dread of Outland"] = 1,
    ["Curse of Legion"] = 1,
    ["Phase Shifted"] = 1,
    ["Unstable Mana"] = 1,
    ["Seed of Corruption"] = 1,
    ["Mutating Injection"] = 1,
    ["Sanctum Mind Decay"] = 1,
    ["Wyvern Sting"] = 1,
    ["Poison Mushroom"] = 1,
    ["Gastronomic Guilt"] = 1,
    ["Tranquilizing Poison"] = 1,
    ["Wyrmkins Venom"] = 1,
    ["Slowing Poison"] = 1,
    ["Mana Buildup"] = 1,
    ["Enveloped Flames"] = 1,
    ["Poison Charge"] = 1,
    ["Arcane Focus"] = 1,
    ["Freezing Chill"] = 1,
    ["Icicles"] = 1,
    ["Arcane Overload"] = 1,
    ["Dreamless Sleep"] = 1,
    ["Greater Dreamless Sleep"] = 1,
    ["Songflower Serenade"] = 1,
    ["Mol'dar's Moxie"] = 1,
    ["Fengus' Ferocity"] = 1,
    ["Slip'kik's Savvy"] = 1,
    ["Thunderfury"] = 1,
    ["Magma Shackles"] = 1,
    ["Silence"] = 1,
    ["Ancient Hysteria"] = 1,
    ["Ignite Mana"] = 1,
    ["Tainted Mind"] = 1,
    ["Smoke Bomb"] = 1,
    ["Screams of the Past"] = 1,
    ["Moroes Curse"] = 1,
    ["Curse of Manascale"] = 1,
    ["Rift Entanglement"] = 1,
    ["Hamstring"] = 1,
    ["Wing Clip"] = 1,
    ["Mind Flay"] = 1,
    ["Web"] = 1,
    ["Web Explosion"] = 1,
    ["Enveloping Web"] = 1,
    ["Encasing Webs"] = 1,
    ["Surge of Mana"] = 1,
    ["Hooked Net"] = 1,
    ["Tendon Rip"] = 1,

    -- UI
    ["Run Rinse"] = 1,
    ["Toggle Options"] = 1,
    ["Toggle Prio List"] = 1,
    ["Toggle Skip List"] = 1,
    ["Warriors"] = 1,
    ["Druids"] = 1,
    ["Paladins"] = 1,
    ["Warlocks"] = 1,
    ["Mages"] = 1,
    ["Priests"] = 1,
    ["Rogues"] = 1,
    ["Hunters"] = 1,
    ["Shamans"] = 1,
    ["Enter player name:"] = 1,
    ["Enter exact name of a debuff (or a type):"] = 1,
    ["Enter exact name of a debuff:"] = 1,
    ["Unknown command. Use /rinse, /rinse options, /rinse skip, /rinse prio or /rinse versions."] = 1,
    ["Not available to your class."] = 1,
    ["Buttons are hidden, to access option and lists use /rinse options, /rinse skip or /rinse prio."] = 1,
    ["MSBT missing."] = 1,
    ["Priority List"] = 1,
    ["Skip List"] = 1,
    ["Options"] = 1,
    ["Add your current target to the list"] = 1,
    ["Add members based on their group"] = 1,
    ["Add members based on their class"] = 1,
    ["Type a player name to add to the list"] = 1,
    ["Cure \"Wyvern Sting\""] = 1,
    ["Cure \"Wyvern Sting\" poison."] = 1,
    ["Cure \"Mutating Injection\""] = 1,
    ["Cure \"Mutating Injection\" disease."] = 1,
    ["Ignore Abolish"] = 1,
    ["Dispel even when an abolish is present."] = 1,
    ["Shadowform Filter"] = 1,
    ["Check to only dispel magic debuffs while in Shadowform."] = 1,
    ["Cure Pets"] = 1,
    ["Scan pets for debuffs."] = 1,
    ["Enable Chat Messages"] = 1,
    ["Enable notification and error chat messages."] = 1,
    ["Use MSBT for Messages"] = 1,
    ["Output messages as Mik's Scrolling Battle text notifications instead of default chat window if MSBT is available."] = 1,
    ["Enable Sounds"] = 1,
    ["Enable notification and error sounds."] = 1,
    ["Show Backdrop"] = 1,
    ["Show or hide backdrop texture."] = 1,
    ["Show Header"] = 1,
    ["Show or hide header."] = 1,
    ["Lock Frame Position"] = 1,
    ["Prevent window from moving."] = 1,
    ["Invert Direction"] = 1,
    ["Check this to invert debuffs growth direction."] = 1,
    ["Cure Magic"] = 1,
    ["Check this to cure magic debuffs."] = 1,
    ["Check this to cure diseases."] = 1,
    ["Check this to cure poisons."] = 1,
    ["Cure Curse"] = 1,
    ["Check this to cure curses."] = 1,
    ["Cure Snare"] = 1,
    ["Check this to cure some slow and root effects with Hand of Freedom."] = 1,
    ["These will be hidden but will NOT block other debuffs of the same type from showing."] = 1,
    ["These will be hidden per-class but will NOT block other debuffs of the same type from showing."] = 1,
    ["These will be hidden and will block other debuffs of the same type from showing. Prevents accidental removal."] = 1,
    ["Hidden Debuffs"] = 1,
    ["Class Hidden"] = 1,
    ["Blacklisted Debuffs"] = 1,
    ["Version check is already in progress."] = 1,
    ["Version check start..."] = 1,
    ["You are not in a raid or party."] = 1,
    ["Version check results:"] = 1,
    ["Clear"] = 1,
    ["Add"] = 1,
    ["Left-click and drag to swap\nRight-click to remove"] = 1,
    FMT_DEBUFFS_SHOWN = "Debuffs shown (%d)",
    FMT_SCALE = "Scale (%.2f)",
    FMT_OPACITY = "Opacity (%.2f)",
}

local locale = GetLocale()
if locale == "zhCN" then
    Rinse.L["Magic"] = "魔法"
    Rinse.L["Curse"] = "诅咒"
    Rinse.L["Disease"] = "疾病"
    Rinse.L["Poison"] = "中毒"
    -- Player dispel abilities
    Rinse.L["Cleanse"] = "清洁术"
    Rinse.L["Purify"] = "纯净术"
    Rinse.L["Hand of Freedom"] = "自由之手"
    Rinse.L["Remove Curse"] = "解除诅咒"
    Rinse.L["Abolish Poison"] = "驱毒术"
    Rinse.L["Cure Poison"] = "解毒术"
    Rinse.L["Dispel Magic"] = "驱散魔法"
    Rinse.L["Abolish Disease"] = "驱除疾病"
    Rinse.L["Cure Disease"] = "祛病术"
    Rinse.L["Remove Lesser Curse"] = "解除次级诅咒"
    Rinse.L["Devour Magic"] = "吞噬魔法"
    -- DefaultBlacklist
    Rinse.L["Curse of Recklessness"] = "鲁莽诅咒"
    Rinse.L["Delusions of Jin'do"] = "金度的欺骗"
    Rinse.L["Dread of Outland"] = "外域的恐惧"
    Rinse.L["Curse of Legion"] = "军团诅咒"
    Rinse.L["Phase Shifted"] = "相位转换"
    Rinse.L["Unstable Mana"] = "不稳定的法力"
    Rinse.L["Seed of Corruption"] = "腐蚀之种"
    Rinse.L["Mutating Injection"] = "变异注射"
    Rinse.L["Sanctum Mind Decay"] = "圣心腐朽"
    Rinse.L["Wyvern Sting"] = "翼龙钉刺"
    Rinse.L["Poison Mushroom"] = "毒蘑菇"
    Rinse.L["Gastronomic Guilt"] = "美食家的负罪"
    -- PriorityDebuffs
    Rinse.L["Tranquilizing Poison"] = "宁神毒药"
    Rinse.L["Wyrmkins Venom"] = "龙族毒液"
    Rinse.L["Slowing Poison"] = "减速毒药"
    Rinse.L["Mana Buildup"] = "魔力积聚"
    Rinse.L["Enveloped Flames"] = "烈焰笼罩"
    Rinse.L["Poison Charge"] = "毒性充能"
    Rinse.L["Arcane Focus"] = "奥术集中"
    Rinse.L["Freezing Chill"] = "冰冻之寒"
    -- Other spells
    Rinse.L["Icicles"] = "冰柱"
    Rinse.L["Arcane Overload"] = "奥术超载"
    Rinse.L["Dreamless Sleep"] = "无梦睡眠"
    Rinse.L["Greater Dreamless Sleep"] = "强效昏睡"
    Rinse.L["Songflower Serenade"] = "风歌夜曲"
    Rinse.L["Mol'dar's Moxie"] = "摩尔达的勇气"
    Rinse.L["Fengus' Ferocity"] = "芬古斯的狂暴"
    Rinse.L["Slip'kik's Savvy"] = "斯里基克的机智"
    Rinse.L["Thunderfury"] = "雷霆之怒"
    Rinse.L["Magma Shackles"] = "熔岩镣铐"
    -- ClassFilter
    Rinse.L["Silence"] = "沉默"
    Rinse.L["Ancient Hysteria"] = "上古狂乱"
    Rinse.L["Ignite Mana"] = "点燃法力"
    Rinse.L["Tainted Mind"] = "污浊之魂"
    Rinse.L["Smoke Bomb"] = "烟雾弹"
    Rinse.L["Screams of the Past"] = "往日的尖啸"
    Rinse.L["Moroes Curse"] = "莫罗斯诅咒"
    Rinse.L["Curse of Manascale"] = "魔鳞诅咒"
    Rinse.L["Rift Entanglement"] = "裂隙纠缠"
    -- SnareDebuffs
    Rinse.L["Hamstring"] = "断筋"
    Rinse.L["Wing Clip"] = "摔绊"
    Rinse.L["Mind Flay"] = "精神鞭笞"
    Rinse.L["Web"] = "蛛网"
    Rinse.L["Surge of Mana"] = "法力涌动"
elseif locale == "esES" then
    Rinse.L["Magic"] = "Mágico"
    Rinse.L["Curse"] = "Maldición"
    Rinse.L["Disease"] = "Enfermedad"
    Rinse.L["Poison"] = "Veneno"
elseif locale == "ptBR" then
    Rinse.L["Magic"] = "Magia"
    Rinse.L["Curse"] = "Maldição"
    Rinse.L["Disease"] = "Doença"
    Rinse.L["Poison"] = "Veneno"
end

for str in pairs(Rinse.L) do
    if Rinse.L[str] == 1 then Rinse.L[str] = str end
end

if C_Spell or SpellInfo or GetSpellNameAndRankForId then
    local function GetSpellName(spellID)
        if C_Spell then return (C_Spell.GetSpellName(spellID)) end
        if SpellInfo then return (SpellInfo(spellID)) end
        if GetSpellNameAndRankForId then return (GetSpellNameAndRankForId(spellID)) end
    end
    -- vanilla spells
    Rinse.L["Cleanse"] = GetSpellName(4987)
    Rinse.L["Purify"] = GetSpellName(1152)
    Rinse.L["Hand of Freedom"] = GetSpellName(1044)
    Rinse.L["Remove Curse"] = GetSpellName(2782)
    Rinse.L["Remove Lesser Curse"] = GetSpellName(475)
    Rinse.L["Dispel Magic"] = GetSpellName(527)
    Rinse.L["Devour Magic"] = GetSpellName(19505)
    Rinse.L["Abolish Poison"] = GetSpellName(2893)
    Rinse.L["Abolish Disease"] = GetSpellName(552)
    Rinse.L["Cure Poison"] = GetSpellName(526)
    Rinse.L["Cure Disease"] = GetSpellName(528)
    Rinse.L["Curse of Recklessness"] = GetSpellName(704)
    Rinse.L["Delusions of Jin'do"] = GetSpellName(24306)
    Rinse.L["Mutating Injection"] = GetSpellName(28169)
    Rinse.L["Wyvern Sting"] = GetSpellName(19386)
    Rinse.L["Poison Mushroom"] = GetSpellName(6727)
    Rinse.L["Tranquilizing Poison"] = GetSpellName(24002)
    Rinse.L["Slowing Poison"] = GetSpellName(7992)
    Rinse.L["Poison Charge"] = GetSpellName(28431)
    Rinse.L["Dreamless Sleep"] = GetSpellName(15822)
    Rinse.L["Greater Dreamless Sleep"] = GetSpellName(24360)
    Rinse.L["Songflower Serenade"] = GetSpellName(15366)
    Rinse.L["Mol'dar's Moxie"] = GetSpellName(22818)
    Rinse.L["Fengus' Ferocity"] = GetSpellName(22817)
    Rinse.L["Slip'kik's Savvy"] = GetSpellName(22820)
    Rinse.L["Thunderfury"] = GetSpellName(21992)
    Rinse.L["Magma Shackles"] = GetSpellName(19496)
    Rinse.L["Silence"] = GetSpellName(15487)
    Rinse.L["Ancient Hysteria"] = GetSpellName(19372)
    Rinse.L["Ignite Mana"] = GetSpellName(19659)
    Rinse.L["Tainted Mind"] = GetSpellName(16567)
    Rinse.L["Hamstring"] = GetSpellName(1715)
    Rinse.L["Wing Clip"] = GetSpellName(2974)
    Rinse.L["Mind Flay"] = GetSpellName(17311)
    Rinse.L["Web"] = GetSpellName(745)
    Rinse.L["Web Explosion"] = GetSpellName(15474)
    Rinse.L["Enveloping Web"] = GetSpellName(15471)
    Rinse.L["Encasing Webs"] = GetSpellName(4962)
    Rinse.L["Screams of the Past"] = GetSpellName(7074)
    Rinse.L["Hooked Net"] = GetSpellName(13608)
    Rinse.L["Tendon Rip"] = GetSpellName(3604)
    -- twow spells
    Rinse.L["Smoke Bomb"] = GetSpellName(57096)
    Rinse.L["Moroes Curse"] = GetSpellName(57100)
    Rinse.L["Sanctum Mind Decay"] = GetSpellName(56512)
    Rinse.L["Gastronomic Guilt"] = GetSpellName(52730)
    Rinse.L["Wyrmkins Venom"] = GetSpellName(56503)
    Rinse.L["Mana Buildup"] = GetSpellName(57648)
    Rinse.L["Enveloped Flames"] = GetSpellName(58004)
    Rinse.L["Dread of Outland"] = GetSpellName(51913)
    Rinse.L["Curse of Legion"] = GetSpellName(58010)
    Rinse.L["Phase Shifted"] = GetSpellName(51197)
    Rinse.L["Unstable Mana"] = GetSpellName(57647)
    Rinse.L["Seed of Corruption"] = GetSpellName(33046)
    Rinse.L["Arcane Focus"] = GetSpellName(51115)
    Rinse.L["Surge of Mana"] = GetSpellName(51175)
    Rinse.L["Freezing Chill"] = GetSpellName(51117)
    Rinse.L["Icicles"] = GetSpellName(51991)
    Rinse.L["Arcane Overload"] = GetSpellName(51100)
    Rinse.L["Curse of Manascale"] = GetSpellName(51186)
    Rinse.L["Rift Entanglement"] = GetSpellName(51194)
end

setmetatable(Rinse.L, { __index = function(t, k) return "" end })
