RINSE_CONFIG = {}
RINSE_CONFIG.SCALE = 0.85
RINSE_CONFIG.OPACITY = 1.0
RINSE_CONFIG.POSITION = {x = 0, y = 0}
RINSE_CONFIG.SKIP_ARRAY = {}
RINSE_CONFIG.PRIO_ARRAY = {}
RINSE_CONFIG.WEVERN_STING = false
RINSE_CONFIG.MUTATING_INJECTION = false
RINSE_CONFIG.PRINT = true
RINSE_CONFIG.LOCK = false

local _, playerClass = UnitClass("player")
local superwow = SUPERWOW_VERSION
local canRemove = {}

local classColors = {}
classColors["WARRIOR"] = "|cffc79c6e"
classColors["DRUID"]   = "|cffff7d0a"
classColors["PALADIN"] = "|cfff58cba"
classColors["WARLOCK"] = "|cff9482c9"
classColors["MAGE"]    = "|cff69ccf0"
classColors["PRIEST"]  = "|cffffffff"
classColors["ROGUE"]   = "|cfffff569"
classColors["HUNTER"]  = "|cffabd473"
classColors["SHAMAN"]  = "|cff0070de"

local debuffColor = {}
debuffColor["none"]	   = { r = 0.8, g = 0.0, b = 0, hex = "|cffCC0000" }
debuffColor["Magic"]   = { r = 0.2, g = 0.6, b = 1, hex = "|cff3399FF" }
debuffColor["Curse"]   = { r = 0.6, g = 0.0, b = 1, hex = "|cff9900FF" }
debuffColor["Disease"] = { r = 0.6, g = 0.4, b = 0, hex = "|cff996600" }
debuffColor["Poison"]  = { r = 0.0, g = 0.6, b = 0, hex = "|cff009900" }

local RED = debuffColor["none"].hex
local BLUE = debuffColor["Magic"].hex
local PURPLE = debuffColor["Curse"].hex
local BROWN = debuffColor["Disease"].hex
local GREEN = debuffColor["Poison"].hex
local GREY = GRAY_FONT_COLOR_CODE
local WHITE = HIGHLIGHT_FONT_COLOR_CODE
local CLOSE = FONT_COLOR_CODE_CLOSE

local curingSpells = {}
curingSpells["PALADIN"] = { Magic = {"Cleanse"}, Poison = {"Cleanse", "Purify"}, Disease = {"Cleanse", "Purify"} }
curingSpells["DRUID"]   = { Curse = {"Remove Curse"}, Poison = {"Abolish Poison", "Cure Poison"} }
curingSpells["PRIEST"]  = { Magic = {"Dispel Magic"}, Disease = {"Abolish Disease", "Cure Disease"} }
curingSpells["SHAMAN"]  = { Poison = {"Cure Poison"}, Disease = {"Cure Disease"} }
curingSpells["MAGE"]    = { Curse = {"Remove Lesser Curse"} }
curingSpells["WARLOCK"] = { Magic = {"Devour Magic"} }

local debuffs = {}
for i = 1, 16 do
    debuffs[i] = { name = "", type = "", texture = "", stacks = 0, debuffIndex = 0, unit = "", unitName = "", unitClass = "", shown = 0 }
end

local defaultPrio = {}
defaultPrio[1] = "player"
defaultPrio[2] = "party1"
defaultPrio[3] = "party2"
defaultPrio[4] = "party3"
defaultPrio[5] = "party4"
for i = 1, 40 do
    tinsert(defaultPrio, "raid"..i)
end

local prio = {}
prio[1] = "player"
prio[2] = "party1"
prio[3] = "party2"
prio[4] = "party3"
prio[5] = "party4"
for i = 1, 40 do
    tinsert(prio, "raid"..i)
end

local blacklist = {}
blacklist["Curse"] = {}
blacklist["Magic"] = {}
blacklist["Disease"] = {}
blacklist["Poison"] = {}

blacklist["Curse"]["Curse of Recklessness"] = true
blacklist["Curse"]["Delusions of Jin'do"] = true

blacklist["Magic"]["Dreamless Sleep"] = true
blacklist["Magic"]["Greater Dreamless Sleep"] = true
blacklist["Magic"]["Songflower Serenade"] = true
blacklist["Magic"]["Mol'dar's Moxie"] = true
blacklist["Magic"]["Fengus' Ferocity"] = true
blacklist["Magic"]["Slip'kik's Savvy"] = true
blacklist["Magic"]["Thunderfury"] = true
blacklist["Magic"]["Magma Shackles"] = true
blacklist["Magic"]["Icicles"] = true

blacklist["Disease"]["Mutating Injection"] = true
blacklist["Disease"]["Sanctum Mind Decay"] = true

blacklist["Poison"]["Wyvern Sting"] = true
blacklist["Poison"]["Poison Mushroom"] = true

local classBlacklist = {}
classBlacklist["WARRIOR"] = {}
classBlacklist["ROGUE"] = {}

classBlacklist["WARRIOR"]["Ancient Hysteria"] = true
classBlacklist["WARRIOR"]["Ignite Mana"] = true
classBlacklist["WARRIOR"]["Tainted Mind"] = true

classBlacklist["ROGUE"]["Silence"] = true
classBlacklist["ROGUE"]["Ancient Hysteria"] = true
classBlacklist["ROGUE"]["Ignite Mana"] = true
classBlacklist["ROGUE"]["Tainted Mind"] = true
classBlacklist["ROGUE"]["Smoke Bomb"] = false -- not sure about this one
classBlacklist["ROGUE"]["Screams of the Past"] = true

local function twipe(tbl)
    for k in pairs(tbl) do
        tbl[k] = nil
    end
end

local function arrwipe(tbl)
    for i = getn(tbl), 1, -1 do
        table.remove(tbl, i)
    end
end

local function arrcontains(array, value)
    for i = 1, getn(array) do
        if type(array[i]) == "table" then
            for k in pairs(array[i]) do
                if array[i][k] == value then
                    return i
                end
            end
        end
        if array[i] == value then
            return i
        end
    end
    return nil
end

local function print(msg)
    if RINSE_CONFIG.PRINT then
        ChatFrame1:AddMessage(BLUE.."[Rinse]"..WHITE..(msg or "nil")..FONT_COLOR_CODE_CLOSE)
    end
end

local function tounitid(name, index)
    if not name then
        return nil
    end
    if UnitName("player") == name then
        return "player"
    else
        for i = 1, 4 do
            if UnitName("party"..i) == name then
                return "party"..i
            end
        end
        for i = 1, 40 do
            if UnitName("raid"..i) == name then
                return "raid"..i
            end
        end
    end
    if index then
        return defaultPrio[index]
    end
    if UnitName("target") and UnitName("target") == name then
        return "target"
    end
end

function RinseSkipListFrame_Update()
    local offset = FauxScrollFrame_GetOffset(RinseSkipListScrollFrame)
    local arrayIndex = 1
    local numPlayers = getn(RINSE_CONFIG.SKIP_ARRAY)
    FauxScrollFrame_Update(RinseSkipListScrollFrame, numPlayers, 10, 16)
    for i = 1, 10 do
        local button = getglobal("RinseSkipListFrameButton"..i)
        local buttonText = getglobal("RinseSkipListFrameButton"..i.."Text")
        arrayIndex = i + offset
        if RINSE_CONFIG.SKIP_ARRAY[arrayIndex] then
            buttonText:SetText(arrayIndex.." - "..classColors[RINSE_CONFIG.SKIP_ARRAY[arrayIndex].class]..RINSE_CONFIG.SKIP_ARRAY[arrayIndex].name)
            button:SetID(arrayIndex)
            button:Show()
        else
            button:Hide()
        end
    end
end

function RinsePrioListFrame_Update()
    local offset = FauxScrollFrame_GetOffset(RinsePrioListScrollFrame)
    local arrayIndex = 1
    local numPlayers = getn(RINSE_CONFIG.PRIO_ARRAY)
    FauxScrollFrame_Update(RinsePrioListScrollFrame, numPlayers, 10, 16)
    for i = 1, 10 do
        local button = getglobal("RinsePrioListFrameButton"..i)
        local buttonText = getglobal("RinsePrioListFrameButton"..i.."Text")
        arrayIndex = i + offset
        if RINSE_CONFIG.PRIO_ARRAY[arrayIndex] then
            buttonText:SetText(arrayIndex.." - "..classColors[RINSE_CONFIG.PRIO_ARRAY[arrayIndex].class]..RINSE_CONFIG.PRIO_ARRAY[arrayIndex].name)
            button:SetID(arrayIndex)
            button:Show()
        else
            button:Hide()
        end
    end
end

function RinseListButton_OnClick()
    local parent = this:GetParent()
    if parent == RinseSkipListFrame then
        tremove(RINSE_CONFIG.SKIP_ARRAY, this:GetID())
        RinseSkipListFrame_Update()
    elseif parent == RinsePrioListFrame then
        tremove(RINSE_CONFIG.PRIO_ARRAY, this:GetID())
        RinsePrioListFrame_Update()
    end
end

function Rinse_AddUnitToList(array, unit)
    local name = UnitName(unit)
    local _, class = UnitClass(unit)
    if name and UnitIsFriend(unit, "player") and UnitIsPlayer(unit) and not arrcontains(array, name) then
        tinsert(array, {name = name, class = class})
    end
    if array == RINSE_CONFIG.SKIP_ARRAY then
        RinseSkipListFrame_Update()
    elseif array == RINSE_CONFIG.PRIO_ARRAY then
        RinsePrioListFrame_Update()
    end
end

local function AddGroupOrClass()
    local array
    if UIDROPDOWNMENU_MENU_VALUE == "Rinse_SkipList" then
        array = RINSE_CONFIG.SKIP_ARRAY
    elseif UIDROPDOWNMENU_MENU_VALUE == "Rinse_PrioList" then
        array = RINSE_CONFIG.PRIO_ARRAY
    end
    if type(this.value) == "number" then
        if UnitInRaid("player") then
            for i = 1 , 40 do
                local name, rank, subgroup, level, class, classFileName, zone, online, isDead = GetRaidRosterInfo(i)
                local unit = tounitid(name)
                if name and subgroup == this.value then
                    Rinse_AddUnitToList(array, unit)
                end
            end
        elseif UnitInParty("player") then
            if this.value == 1 then
                Rinse_AddUnitToList(array, "player")
                for i = 1, 4 do
                    if UnitName("party"..i) then
                        Rinse_AddUnitToList(array, "party"..i)
                    end
                end
            end
        end
    elseif type(this.value) == "string" then
        if UnitInRaid("player") then
            for i = 1 , 40 do
                local name, rank, subgroup, level, class, classFileName, zone, online, isDead = GetRaidRosterInfo(i)
                local unit = tounitid(name)
                if name and classFileName == this.value then
                    Rinse_AddUnitToList(array, unit)
                end
            end
        elseif UnitInParty("player") then
            if this.value == playerClass then
                Rinse_AddUnitToList(array, "player")
            end
            for i = 1, 4 do
                local _, class = UnitClass("party"..i)
                if UnitName("party"..i) and class == this.value then
                    Rinse_AddUnitToList(array, "party"..i)
                end
            end
        end
    end
end

local info = {}

local function ClassMenu()
    if UIDROPDOWNMENU_MENU_LEVEL == 1 then
        twipe(info)
        info.text = classColors["WARRIOR"] .. "Warriors"
        info.textHeight = 12
        info.notCheckable = true
        info.hasArrow = false
        info.value = "WARRIOR"
        info.func = AddGroupOrClass
        UIDropDownMenu_AddButton(info)
        twipe(info)
        info.text = classColors["DRUID"] .. "Druids"
        info.textHeight = 12
        info.notCheckable = true
        info.hasArrow = false
        info.value = "DRUID"
        info.func = AddGroupOrClass
        UIDropDownMenu_AddButton(info)
        twipe(info)
        info.text = classColors["PALADIN"] .. "Paladins"
        info.textHeight = 12
        info.notCheckable = true
        info.hasArrow = false
        info.value = "PALADIN"
        info.func = AddGroupOrClass
        UIDropDownMenu_AddButton(info)
        twipe(info)
        info.text = classColors["WARLOCK"] .. "Warlocks"
        info.textHeight = 12
        info.notCheckable = true
        info.hasArrow = false
        info.value = "WARLOCK"
        info.func = AddGroupOrClass
        UIDropDownMenu_AddButton(info)
        twipe(info)
        info.text = classColors["MAGE"] .. "Mages"
        info.textHeight = 12
        info.notCheckable = true
        info.hasArrow = false
        info.value = "MAGE"
        info.func = AddGroupOrClass
        UIDropDownMenu_AddButton(info)
        twipe(info)
        info.text = classColors["PRIEST"] .. "Priests"
        info.textHeight = 12
        info.notCheckable = true
        info.hasArrow = false
        info.value = "PRIEST"
        info.func = AddGroupOrClass
        UIDropDownMenu_AddButton(info)
        twipe(info)
        info.text = classColors["ROGUE"] .. "Rogues"
        info.textHeight = 12
        info.notCheckable = true
        info.hasArrow = false
        info.value = "ROGUE"
        info.func = AddGroupOrClass
        UIDropDownMenu_AddButton(info)
        twipe(info)
        info.text = classColors["HUNTER"] .. "Hunters"
        info.textHeight = 12
        info.notCheckable = true
        info.hasArrow = false
        info.value = "HUNTER"
        info.func = AddGroupOrClass
        UIDropDownMenu_AddButton(info)
        twipe(info)
        info.text = classColors["SHAMAN"] .. "Shamans"
        info.textHeight = 12
        info.notCheckable = true
        info.hasArrow = false
        info.value = "SHAMAN"
        info.func = AddGroupOrClass
        UIDropDownMenu_AddButton(info)
    end
end

local function GroupMenu()
    if UIDROPDOWNMENU_MENU_LEVEL == 1 then
        for i = 1, 8 do
            twipe(info)
            info.text = GROUP.." "..i
            info.textHeight = 12
            info.notCheckable = true
            info.hasArrow = false
            info.value = i
            info.func = AddGroupOrClass
            UIDropDownMenu_AddButton(info)
        end
    end
end

function RinseSkipListAddGroup_OnClick()
    UIDropDownMenu_Initialize(RinseGroupsDropDown, GroupMenu, "MENU")
    ToggleDropDownMenu(1, "Rinse_SkipList", RinseGroupsDropDown, this, 0, 0)
end

function RinseSkipListAddClass_OnClick()
    UIDropDownMenu_Initialize(RinseClassesDropDown, ClassMenu, "MENU")
    ToggleDropDownMenu(1, "Rinse_SkipList", RinseClassesDropDown, this, 0, 0)
end

function RinsePrioListAddGroup_OnClick()
    UIDropDownMenu_Initialize(RinseGroupsDropDown, GroupMenu, "MENU")
    ToggleDropDownMenu(1, "Rinse_PrioList", RinseGroupsDropDown, this, 0, 0)
end

function RinsePrioListAddClass_OnClick()
    UIDropDownMenu_Initialize(RinseClassesDropDown, ClassMenu, "MENU")
    ToggleDropDownMenu(1, "Rinse_PrioList", RinseClassesDropDown, this, 0, 0)
end

local spellBookIndex
local bookType = BOOKTYPE_SPELL
if playerClass == "WARLOCK" then
    bookType = BOOKTYPE_PET
end

local function UpdateSpells()
    if not curingSpells[playerClass] then
        return
    end
    local found = false
    spellBookIndex = nil
    for tab = 1, GetNumSpellTabs() do
        local _, _, offset, numSpells = GetSpellTabInfo(tab)
        for s = offset + 1, offset + numSpells do
            local spell = GetSpellName(s, bookType)
            if spell then
                for dispellType, v in pairs(curingSpells[playerClass]) do
                    if v[1] == spell then
                        canRemove[dispellType] = spell
                        found = true
                        spellBookIndex = s
                    end
                end
            end
        end
    end
    if found then
        return
    end
    for tab = 1, GetNumSpellTabs() do
        local _, _, offset, numSpells = GetSpellTabInfo(tab)
        for s = offset + 1, offset + numSpells do
            local spell = GetSpellName(s, bookType)
            if spell then
                for dispellType, v in pairs(curingSpells[playerClass]) do
                    if v[2] and v[2] == spell then
                        canRemove[dispellType] = spell
                        spellBookIndex = s
                    end
                end
            end
        end
    end
end

function Rinse_Cleanse(button)
    local button = button or this
    if not button.unit or button.unit == "" then
        return
    end

    if not CheckInteractDistance(button.unit, 4) then
        print(classColors[button.unitClass].." "..UnitName(button.unit)..CLOSE.." is out of range.")
        -- PlaySoundFile("Sound\\Interface\\Error.wav")
        return
    end

    local debuff = getglobal(button:GetName().."Name"):GetText()
    if superwow then
        print(" Trying To Remove "..debuffColor[button.type].hex..debuff..CLOSE.." from "..classColors[button.unitClass]..UnitName(button.unit)..CLOSE)
        CastSpellByName(canRemove[button.type], button.unit)
    else
        local selfcast = false
        if GetCVar("autoselfcast") == "1" then
            selfcast = true
        end
        SetCVar("autoselfcast", 0)
        TargetByName(button.unitName)
        CastSpellByName(canRemove[button.type])
        TargetLastTarget()
        if selfcast then
            SetCVar("autoselfcast", 1)
        end
    end
end

SLASH_RINSE1 = "/rinse"
SlashCmdList["RINSE"] = function()
    for i = 1, 5 do
       Rinse_Cleanse(getglobal("RinseFrameDebuff"..i))
    end
end

function RinseFrame_OnLoad()
    RinseFrame:RegisterEvent("ADDON_LOADED")
    RinseFrame:RegisterEvent("RAID_ROSTER_UPDATE")
    RinseFrame:RegisterEvent("PARTY_MEMBERS_CHANGED")
    RinseFrame:RegisterEvent("SPELLS_CHANGED")
    RinseFrame:SetBackdropBorderColor(1, 1, 1)
    RinseFrame:SetBackdropColor(0, 0, 0, 0.5)
end

function RinseFrame_OnEvent()
    if event == "ADDON_LOADED" and arg1 == "Rinse" then
        RinseFrame:UnregisterEvent("ADDON_LOADED")
        RinseFrame:ClearAllPoints()
        RinseFrame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", RINSE_CONFIG.POSITION.x, RINSE_CONFIG.POSITION.y)
        RinseFrame:SetScale(RINSE_CONFIG.SCALE)
        RinseFrame:SetAlpha(RINSE_CONFIG.OPACITY)
        UpdateSpells()
    elseif event == "RAID_ROSTER_UPDATE" or event == "PARTY_MEMBERS_CHANGED" then
        if RINSE_CONFIG.PRIO_ARRAY[1] then
            for i = 1, getn(RINSE_CONFIG.PRIO_ARRAY) do
                tinsert(prio, i, tounitid(RINSE_CONFIG.PRIO_ARRAY[i], i))
            end
            for i = getn(prio), getn(RINSE_CONFIG.PRIO_ARRAY) + 1, -1 do
                if arrcontains(RINSE_CONFIG.PRIO_ARRAY, UnitName(prio[i])) then
                    tremove(prio, i)
                end
            end
        else
            prio = defaultPrio
        end
    elseif event == "SPELLS_CHANGED" then
        UpdateSpells()
    end
end

local UnitExists = UnitExists
local UnitIsFriend = UnitIsFriend
local UnitIsVisible = UnitIsVisible
local UnitDebuff = UnitDebuff
local UnitClass = UnitClass
local UnitIsUnit = UnitIsUnit
local UnitName = UnitName
local GetTime = GetTime
local GetSpellCooldown = GetSpellCooldown
local CheckInteractDistance = CheckInteractDistance
local skipArray = RINSE_CONFIG.SKIP_ARRAY
local updateInterval = 0.15
local tick = updateInterval

function RinseFrame_OnUpdate()
    if tick > GetTime() then
        return
    else
        tick = GetTime() + updateInterval
    end
    for i = 1, 16 do
        debuffs[i].name = ""
        debuffs[i].type = ""
        debuffs[i].texture = ""
        debuffs[i].stacks = 0
        debuffs[i].unit = ""
        debuffs[i].unitName = ""
        debuffs[i].unitClass = ""
        debuffs[i].shown = 0
        debuffs[i].debuffIndex = 0
    end
    local debuffIndex = 1
    if UnitExists("target") and UnitIsFriend("target", "player") and not arrcontains(skipArray, UnitName("target")) and UnitIsVisible("target") then
        local i = 1
        while debuffIndex < 16 and UnitDebuff("target", i) do
            RinseScanTooltipTextLeft1:SetText("")
            RinseScanTooltipTextRight1:SetText("")
            RinseScanTooltip:SetUnitDebuff("target", i)
            local debuffName = RinseScanTooltipTextLeft1:GetText() or ""
            local debuffType = RinseScanTooltipTextRight1:GetText() or ""
            local texture, applications = UnitDebuff("target", i)
            local _, class = UnitClass("target")
            if debuffType and debuffName and class then
                if canRemove[debuffType] and not (blacklist[debuffType] and blacklist[debuffType][debuffName]) and
                        not (classBlacklist[class] and classBlacklist[class][debuffName]) then
                    debuffs[debuffIndex].name = debuffName or ""
                    debuffs[debuffIndex].type = debuffType or ""
                    debuffs[debuffIndex].texture = texture or ""
                    debuffs[debuffIndex].stacks = applications or 0
                    debuffs[debuffIndex].unit = "target"
                    debuffs[debuffIndex].unitName = UnitName("target") or ""
                    debuffs[debuffIndex].unitClass = class or ""
                    debuffs[debuffIndex].debuffIndex = i
                    debuffIndex = debuffIndex + 1
                end
            end
            i = i + 1
        end
    end
    for index = 1, getn(prio) do
        local unit = prio[index]
        if UnitExists(unit) and UnitIsFriend(unit, "player") and not (UnitExists("target") and UnitIsUnit("target", unit))
                and not arrcontains(skipArray, UnitName(unit)) and UnitIsVisible(unit) then
            local i = 1
            while debuffIndex < 16 and UnitDebuff(unit, i) do
                RinseScanTooltipTextLeft1:SetText("")
                RinseScanTooltipTextRight1:SetText("")
                RinseScanTooltip:SetUnitDebuff(unit, i)
                local debuffName = RinseScanTooltipTextLeft1:GetText() or ""
                local debuffType = RinseScanTooltipTextRight1:GetText() or ""
                local texture, applications = UnitDebuff(unit, i)
                local _, class = UnitClass(unit)
                if debuffType and debuffName and class then
                    if canRemove[debuffType] and not (blacklist[debuffType] and blacklist[debuffType][debuffName]) and
                            not (classBlacklist[class] and classBlacklist[class][debuffName]) then
                        debuffs[debuffIndex].name = debuffName or ""
                        debuffs[debuffIndex].type = debuffType or ""
                        debuffs[debuffIndex].texture = texture or ""
                        debuffs[debuffIndex].stacks = applications or 0
                        debuffs[debuffIndex].unit = unit or ""
                        debuffs[debuffIndex].unitName = UnitName(unit) or ""
                        debuffs[debuffIndex].unitClass = class or ""
                        debuffs[debuffIndex].debuffIndex = i
                        debuffIndex = debuffIndex + 1
                    end
                end
                i = i + 1
            end
        end
    end
    for i = 1, 5 do
        local btn = getglobal("RinseFrameDebuff"..i)
        btn:Hide()
        btn.unit = nil
    end
    debuffIndex = 1
    for buttonIndex = 1, 5 do
        while debuffIndex < 16 and debuffs[debuffIndex].shown ~= 0 do
            debuffIndex = debuffIndex + 1
        end
        if debuffs[debuffIndex].name ~= "" then
            local button = getglobal("RinseFrameDebuff"..buttonIndex)
            local icon = getglobal("RinseFrameDebuff"..buttonIndex.."Icon")
            local debuffName = getglobal("RinseFrameDebuff"..buttonIndex.."Name")
            local playerName = getglobal("RinseFrameDebuff"..buttonIndex.."Player")
            local count = getglobal("RinseFrameDebuff"..buttonIndex.."Count")
            local border = getglobal("RinseFrameDebuff"..buttonIndex.."Border")
            local outOfRange = getglobal("RinseFrameDebuff"..buttonIndex.."OutOfRange")
            local onCooldown = getglobal("RinseFrameDebuff"..buttonIndex.."OnCooldown")
            icon:SetTexture(debuffs[debuffIndex].texture)
            debuffName:SetText(debuffs[debuffIndex].name)
            playerName:SetText(classColors[debuffs[debuffIndex].unitClass]..debuffs[debuffIndex].unitName)
            count:SetText(debuffs[debuffIndex].stacks)
            border:SetVertexColor(debuffColor[debuffs[debuffIndex].type].r, debuffColor[debuffs[debuffIndex].type].g, debuffColor[debuffs[debuffIndex].type].b)
            button.unit = debuffs[debuffIndex].unit
            button.unitName = debuffs[debuffIndex].unitName
            button.unitClass = debuffs[debuffIndex].unitClass
            button.type = debuffs[debuffIndex].type
            button.debuffIndex = debuffs[debuffIndex].debuffIndex
            button:Show()
            debuffs[debuffIndex].shown = 1
            for i = debuffIndex, 16 do
                if  debuffs[i].unitName == debuffs[debuffIndex].unitName then
                    debuffs[i].shown = 1
                end
            end
            onCooldown:Hide()
            outOfRange:Hide()
            if spellBookIndex and GetSpellCooldown(spellBookIndex, bookType) ~= 0 then
                onCooldown:Show()
            end
            if not CheckInteractDistance(debuffs[debuffIndex].unit, 4) then
                outOfRange:Show()
            end
        end
    end
end

function RinseFramePrioList_OnClick()
    if RinsePrioListFrame:IsShown() then
        RinsePrioListFrame:Hide()
    else
        RinsePrioListFrame:Show()
        RinsePrioListFrame_Update()
    end
end

function RinseFrameSkipList_OnClick()
    if RinseSkipListFrame:IsShown() then
        RinseSkipListFrame:Hide()
    else
        RinseSkipListFrame:Show()
        RinseSkipListFrame_Update()
    end
end

function RinseFrameOptions_OnClick()
    if not RinseOptionsFrame:IsShown() then
        RinseOptionsFrame:Show()
    else
        RinseOptionsFrame:Hide()
    end
end

function Rinse_ToggleWyvernSting()
    RINSE_CONFIG.WYVERN_STING = not RINSE_CONFIG.WYVERN_STING
    blacklist["Poison"]["Wyvern Sting"] = RINSE_CONFIG.WYVERN_STING
end

function Rinse_ToggleMutatingInjection()
    RINSE_CONFIG.MUTATING_INJECTION = not RINSE_CONFIG.MUTATING_INJECTION
    blacklist["Disease"]["Mutating Injection"] = RINSE_CONFIG.MUTATING_INJECTION
end

function Rinse_TogglePrint()
    RINSE_CONFIG.PRINT = not RINSE_CONFIG.PRINT
end

function Rinse_ToggleLock()
    RINSE_CONFIG.LOCK = not RINSE_CONFIG.LOCK
    RinseFrame:SetMovable(not RinseFrame:IsMovable())
end
