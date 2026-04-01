-- Create a local table for translations
local L = {}
local locale = GetLocale()

-- Default English (enUS/enGB)
L["Cleanse"] = "Cleanse"
L["Purify"] = "Purify"
L["Hand of Freedom"] = "Hand of Freedom"
L["Remove Curse"] = "Remove Curse"
L["Abolish Poison"] = "Abolish Poison"
L["Cure Poison"] = "Cure Poison"
L["Dispel Magic"] = "Dispel Magic"
L["Abolish Disease"] = "Abolish Disease"
L["Cure Disease"] = "Cure Disease"
L["Remove Lesser Curse"] = "Remove Lesser Curse"
L["Devour Magic"] = "Devour Magic"

-- Chinese Translation (zhCN)
if locale == "zhCN" then
    L["Cleanse"] = "清洁术"
    L["Purify"] = "纯净术"
    L["Hand of Freedom"] = "自由祝福"
    L["Remove Curse"] = "移除诅咒"
    L["Abolish Poison"] = "驱毒术"
    L["Cure Poison"] = "解毒术"
    L["Dispel Magic"] = "驱散魔法"
    L["Abolish Disease"] = "祛病术"
    L["Cure Disease"] = "解病术"
    L["Remove Lesser Curse"] = "解除次级诅咒"
    L["Devour Magic"] = "吞噬魔法"
end

-- Export to global or addon namespace so other files can see it
RinseLocalization = L 
