local _, playerClass = UnitClass("player")
local superwow = SUPERWOW_VERSION
local getn = table.getn
local UnitExists = UnitExists
local UnitIsFriend = UnitIsFriend
local UnitIsVisible = UnitIsVisible
local UnitDebuff = UnitDebuff
local UnitClass = UnitClass
local UnitIsUnit = UnitIsUnit
local UnitIsPlayer = UnitIsPlayer
local UnitIsCharmed = UnitIsCharmed
local UnitName = UnitName
local GetTime = GetTime
local GetSpellCooldown = GetSpellCooldown
local CheckInteractDistance = CheckInteractDistance
local updateInterval = 0.1
local timeElapsed = 0
local noticeSound = "Sound\\Doodad\\BellTollTribal.wav"
local errorSound = "Sound\\Interface\\Error.wav"
local playNoticeSound = true
local errorCooldown = 0
local stopCastCooldown = 0

local ClassColors = {}
ClassColors["WARRIOR"] = "|cffc79c6e"
ClassColors["DRUID"]   = "|cffff7d0a"
ClassColors["PALADIN"] = "|cfff58cba"
ClassColors["WARLOCK"] = "|cff9482c9"
ClassColors["MAGE"]    = "|cff69ccf0"
ClassColors["PRIEST"]  = "|cffffffff"
ClassColors["ROGUE"]   = "|cfffff569"
ClassColors["HUNTER"]  = "|cffabd473"
ClassColors["SHAMAN"]  = "|cff0070de"

local DebuffColor = {}
DebuffColor["none"]	   = { r = 0.8, g = 0.0, b = 0.0, hex = "|cffCC0000" }
DebuffColor["Magic"]   = { r = 0.2, g = 0.6, b = 1.0, hex = "|cff3399FF" }
DebuffColor["Curse"]   = { r = 0.6, g = 0.0, b = 1.0, hex = "|cff9900FF" }
DebuffColor["Disease"] = { r = 0.6, g = 0.4, b = 0.0, hex = "|cff996600" }
DebuffColor["Poison"]  = { r = 0.0, g = 0.6, b = 0.0, hex = "|cff009900" }

local RED = DebuffColor["none"].hex
local BLUE = DebuffColor["Magic"].hex
local PURPLE = DebuffColor["Curse"].hex
local BROWN = DebuffColor["Disease"].hex
local GREEN = DebuffColor["Poison"].hex
local GREY = GRAY_FONT_COLOR_CODE
local WHITE = HIGHLIGHT_FONT_COLOR_CODE
local CLOSE = FONT_COLOR_CODE_CLOSE

-- Spells that remove stuff, for each class
local Spells = {}
Spells["PALADIN"] = { Magic = {"Cleanse"}, Poison = {"Cleanse", "Purify"}, Disease = {"Cleanse", "Purify"} }
Spells["DRUID"]   = { Curse = {"Remove Curse"}, Poison = {"Abolish Poison", "Cure Poison"} }
Spells["PRIEST"]  = { Magic = {"Dispel Magic"}, Disease = {"Abolish Disease", "Cure Disease"} }
Spells["SHAMAN"]  = { Poison = {"Cure Poison"}, Disease = {"Cure Disease"} }
Spells["MAGE"]    = { Curse = {"Remove Lesser Curse"} }
Spells["WARLOCK"] = { Magic = {"Devour Magic"} }

-- Spells that we have
-- CanRemove[debuffType] = "spellName"
local CanRemove = {}

-- Number of buttons shown
local BUTTONS_MAX = 5

-- Maximum number of dispellable debuffs that we hold on to
local DEBUFFS_MAX = 42

-- Debuff info
local Debuffs = {}
for i = 1, DEBUFFS_MAX do
    Debuffs[i] = {
        name = "",
        type = "",
        texture = "",
        stacks = 0,
        debuffIndex = 0,
        unit = "",
        unitName = "",
        unitClass = "",
        shown = 0
    }
end

-- Default scan order
local DefaultPrio = {}
DefaultPrio[1] = "player"
DefaultPrio[2] = "party1"
DefaultPrio[3] = "party2"
DefaultPrio[4] = "party3"
DefaultPrio[5] = "party4"
for i = 1, 40 do
    tinsert(DefaultPrio, "raid"..i)
end

-- Scan order
local Prio = {}
Prio[1] = "player"
Prio[2] = "party1"
Prio[3] = "party2"
Prio[4] = "party3"
Prio[5] = "party4"
for i = 1, 40 do
    tinsert(Prio, "raid"..i)
end

-- Spells to ignore always
local Blacklist = {}
Blacklist["Curse"] = {}
Blacklist["Magic"] = {}
Blacklist["Disease"] = {}
Blacklist["Poison"] = {}
----------------------------------------------------
Blacklist["Curse"]["Curse of Recklessness"] = true
Blacklist["Curse"]["Delusions of Jin'do"] = true
----------------------------------------------------
Blacklist["Magic"]["Dreamless Sleep"] = true
Blacklist["Magic"]["Greater Dreamless Sleep"] = true
Blacklist["Magic"]["Songflower Serenade"] = true
Blacklist["Magic"]["Mol'dar's Moxie"] = true
Blacklist["Magic"]["Fengus' Ferocity"] = true
Blacklist["Magic"]["Slip'kik's Savvy"] = true
Blacklist["Magic"]["Thunderfury"] = true
Blacklist["Magic"]["Magma Shackles"] = true
Blacklist["Magic"]["Icicles"] = true
----------------------------------------------------
Blacklist["Disease"]["Mutating Injection"] = true
Blacklist["Disease"]["Sanctum Mind Decay"] = true
----------------------------------------------------
Blacklist["Poison"]["Wyvern Sting"] = true
Blacklist["Poison"]["Poison Mushroom"] = true
----------------------------------------------------

-- Spells to ignore on certain classes
local ClassBlacklist = {}
ClassBlacklist["WARRIOR"] = {}
ClassBlacklist["ROGUE"] = {}
----------------------------------------------------
ClassBlacklist["WARRIOR"]["Ancient Hysteria"] = true
ClassBlacklist["WARRIOR"]["Ignite Mana"] = true
ClassBlacklist["WARRIOR"]["Tainted Mind"] = true
ClassBlacklist["WARRIOR"]["Moroes Curse"] = true
----------------------------------------------------
ClassBlacklist["ROGUE"]["Silence"] = true
ClassBlacklist["ROGUE"]["Ancient Hysteria"] = true
ClassBlacklist["ROGUE"]["Ignite Mana"] = true
ClassBlacklist["ROGUE"]["Tainted Mind"] = true
ClassBlacklist["ROGUE"]["Smoke Bomb"] = true
ClassBlacklist["ROGUE"]["Screams of the Past"] = true
ClassBlacklist["ROGUE"]["Moroes Curse"] = true
----------------------------------------------------

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
        ChatFrame1:AddMessage(BLUE.."[Rinse] "..WHITE..(msg or "nil")..FONT_COLOR_CODE_CLOSE)
    end
end

local function debug(msg)
    ChatFrame1:AddMessage(BLUE.."[Rinse]["..GetTime().."]"..WHITE..(tostring(msg))..FONT_COLOR_CODE_CLOSE)
end

local function playsound(file)
    if RINSE_CONFIG.SOUND then
        PlaySoundFile(file)
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
        return DefaultPrio[index]
    end
    if UnitName("target") and UnitName("target") == name then
        return "target"
    end
end

local function HasAbolish(unit, debuffType)
    if not UnitExists(unit) or not debuffType then
        return
    end
    if not CanRemove[debuffType] then
        return
    end
    if not (debuffType == "Poison" or debuffType == "Disease") then
        return
    end
	local i = 1
    local buff
    local icon
    if debuffType == "Poison" then
        icon = "Interface\\Icons\\Spell_Nature_NullifyPoison_02"
    elseif debuffType == "Disease" then
        icon = "Interface\\Icons\\Spell_Nature_NullifyDisease"
    end
	repeat
		buff = UnitBuff(unit, i)
		if buff == icon then
			return 1
		end
		i = i + 1
	until not buff
end

local function InRange(unit)
    if unit and UnitIsFriend(unit, "player") then
        if superwow then
            local myX, myY, myZ = UnitPosition("player")
            local uX, uY, uZ = UnitPosition(unit)
            -- Not sure why 1089, but seems to be accurate for 30yd range
            -- spell from my testing
            return math.abs((myX - uX)^2 + (myY - uY)^2 + (myZ - uZ)^2) <= 1089
        else
            -- Not as accurate
            return CheckInteractDistance(unit, 4)
        end
    end
end

local function UpdatePrio()
    if RINSE_CONFIG.PRIO_ARRAY[1] then
        -- Copy from user defined prio array into internal Prio
        for i = 1, getn(RINSE_CONFIG.PRIO_ARRAY) do
            tinsert(Prio, i, tounitid(RINSE_CONFIG.PRIO_ARRAY[i].name, i))
        end
        -- Get rid of duplicates
        for i = getn(Prio), getn(RINSE_CONFIG.PRIO_ARRAY) + 1, -1 do
            if arrcontains(RINSE_CONFIG.PRIO_ARRAY, UnitName(Prio[i])) then
                tremove(Prio, i)
            end
        end
    else
        Prio = DefaultPrio
    end
end

function RinseSkipListScrollFrame_Update()
    local offset = FauxScrollFrame_GetOffset(RinseSkipListScrollFrame)
    local arrayIndex = 1
    local numPlayers = getn(RINSE_CONFIG.SKIP_ARRAY)
    FauxScrollFrame_Update(RinseSkipListScrollFrame, numPlayers, 10, 16)
    for i = 1, 10 do
        local button = getglobal("RinseSkipListFrameButton"..i)
        local buttonText = getglobal("RinseSkipListFrameButton"..i.."Text")
        arrayIndex = i + offset
        if RINSE_CONFIG.SKIP_ARRAY[arrayIndex] then
            buttonText:SetText(arrayIndex.." - "..ClassColors[RINSE_CONFIG.SKIP_ARRAY[arrayIndex].class]..RINSE_CONFIG.SKIP_ARRAY[arrayIndex].name)
            button:SetID(arrayIndex)
            button:Show()
        else
            button:Hide()
        end
    end
end

function RinsePrioListScrollFrame_Update()
    local offset = FauxScrollFrame_GetOffset(RinsePrioListScrollFrame)
    local arrayIndex = 1
    local numPlayers = getn(RINSE_CONFIG.PRIO_ARRAY)
    FauxScrollFrame_Update(RinsePrioListScrollFrame, numPlayers, 10, 16)
    for i = 1, 10 do
        local button = getglobal("RinsePrioListFrameButton"..i)
        local buttonText = getglobal("RinsePrioListFrameButton"..i.."Text")
        arrayIndex = i + offset
        if RINSE_CONFIG.PRIO_ARRAY[arrayIndex] then
            buttonText:SetText(arrayIndex.." - "..ClassColors[RINSE_CONFIG.PRIO_ARRAY[arrayIndex].class]..RINSE_CONFIG.PRIO_ARRAY[arrayIndex].name)
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
        RinseSkipListScrollFrame_Update()
    elseif parent == RinsePrioListFrame then
        tremove(RINSE_CONFIG.PRIO_ARRAY, this:GetID())
        RinsePrioListScrollFrame_Update()
        UpdatePrio()
    end
end

function Rinse_AddUnitToList(array, unit)
    local name = UnitName(unit)
    local _, class = UnitClass(unit)
    if name and UnitIsFriend(unit, "player") and UnitIsPlayer(unit) and not arrcontains(array, name) then
        tinsert(array, {name = name, class = class})
    end
    if array == RINSE_CONFIG.SKIP_ARRAY then
        RinseSkipListScrollFrame_Update()
    elseif array == RINSE_CONFIG.PRIO_ARRAY then
        RinsePrioListScrollFrame_Update()
        UpdatePrio()
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
        -- This is group number
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
        -- This is class
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
info.textHeight = 12
info.notCheckable = true
info.hasArrow = false
info.func = AddGroupOrClass

local function ClassMenu()
    if UIDROPDOWNMENU_MENU_LEVEL == 1 then
        info.text = ClassColors["WARRIOR"] .. "Warriors"
        info.value = "WARRIOR"
        UIDropDownMenu_AddButton(info)

        info.text = ClassColors["DRUID"] .. "Druids"
        info.value = "DRUID"
        UIDropDownMenu_AddButton(info)

        info.text = ClassColors["PALADIN"] .. "Paladins"
        info.value = "PALADIN"
        UIDropDownMenu_AddButton(info)

        info.text = ClassColors["WARLOCK"] .. "Warlocks"
        info.value = "WARLOCK"
        UIDropDownMenu_AddButton(info)

        info.text = ClassColors["MAGE"] .. "Mages"
        info.value = "MAGE"
        UIDropDownMenu_AddButton(info)

        info.text = ClassColors["PRIEST"] .. "Priests"
        info.value = "PRIEST"
        UIDropDownMenu_AddButton(info)

        info.text = ClassColors["ROGUE"] .. "Rogues"
        info.value = "ROGUE"
        UIDropDownMenu_AddButton(info)

        info.text = ClassColors["HUNTER"] .. "Hunters"
        info.value = "HUNTER"
        UIDropDownMenu_AddButton(info)

        info.text = ClassColors["SHAMAN"] .. "Shamans"
        info.value = "SHAMAN"
        UIDropDownMenu_AddButton(info)
    end
end

local function GroupMenu()
    if UIDROPDOWNMENU_MENU_LEVEL == 1 then
        for i = 1, 8 do
            info.text = GROUP.." "..i
            info.value = i
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
    if not Spells[playerClass] then
        return
    end
    local found = false
    spellBookIndex = nil
    for tab = 1, GetNumSpellTabs() do
        local _, _, offset, numSpells = GetSpellTabInfo(tab)
        for s = offset + 1, offset + numSpells do
            local spell = GetSpellName(s, bookType)
            if spell then
                for dispelType, v in pairs(Spells[playerClass]) do
                    if v[1] == spell then
                        CanRemove[dispelType] = spell
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
                for dispelType, v in pairs(Spells[playerClass]) do
                    if v[2] and v[2] == spell then
                        CanRemove[dispelType] = spell
                        spellBookIndex = s
                    end
                end
            end
        end
    end
end

function RinseFramePrioList_OnClick()
    if RinsePrioListFrame:IsShown() then
        RinsePrioListFrame:Hide()
    else
        RinsePrioListFrame:Show()
        RinsePrioListScrollFrame_Update()
    end
end

function RinseFrameSkipList_OnClick()
    if RinseSkipListFrame:IsShown() then
        RinseSkipListFrame:Hide()
    else
        RinseSkipListFrame:Show()
        RinseSkipListScrollFrame_Update()
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
    Blacklist["Poison"]["Wyvern Sting"] = not RINSE_CONFIG.WYVERN_STING
end

function Rinse_ToggleMutatingInjection()
    RINSE_CONFIG.MUTATING_INJECTION = not RINSE_CONFIG.MUTATING_INJECTION
    Blacklist["Disease"]["Mutating Injection"] = not RINSE_CONFIG.MUTATING_INJECTION
end

function Rinse_TogglePrint()
    RINSE_CONFIG.PRINT = not RINSE_CONFIG.PRINT
end

function Rinse_ToggleSound()
    RINSE_CONFIG.SOUND = not RINSE_CONFIG.SOUND
end

function Rinse_ToggleLock()
    RINSE_CONFIG.LOCK = not RINSE_CONFIG.LOCK
    RinseFrame:SetMovable(not RINSE_CONFIG.LOCK)
end

function RinseFrame_OnLoad()
    RinseFrame:RegisterEvent("ADDON_LOADED")
    RinseFrame:RegisterEvent("RAID_ROSTER_UPDATE")
    RinseFrame:RegisterEvent("PARTY_MEMBERS_CHANGED")
    RinseFrame:RegisterEvent("SPELLS_CHANGED")
    RinseFrame:SetBackdropBorderColor(1, 1, 1)
    RinseFrame:SetBackdropColor(0, 0, 0, 0.5)
end

local function GoodUnit(unit)
    if not (unit and UnitExists(unit) and UnitName(unit)) then
        return nil
    end
    if UnitIsFriend(unit, "player") and UnitIsVisible(unit) and not UnitIsCharmed(unit) then
        if not arrcontains(RINSE_CONFIG.SKIP_ARRAY, UnitName(unit)) and (arrcontains(Prio, unit) or (unit == "target")) then
            return 1
        end
    end
    return nil
end

function RinseFrame_OnEvent()
    if event == "ADDON_LOADED" and arg1 == "Rinse" then
        RinseFrame:UnregisterEvent("ADDON_LOADED")
        if not RINSE_CONFIG then
            RINSE_CONFIG = {}
            RINSE_CONFIG.SKIP_ARRAY = {}
            RINSE_CONFIG.PRIO_ARRAY = {}
            RINSE_CONFIG.POSITION = {x = 0, y = 0}
            RINSE_CONFIG.SCALE = 0.85
            RINSE_CONFIG.OPACITY = 1.0
            RINSE_CONFIG.WEVERN_STING = false
            RINSE_CONFIG.MUTATING_INJECTION = false
            RINSE_CONFIG.PRINT = true
            RINSE_CONFIG.SOUND = true
            RINSE_CONFIG.LOCK = false
        end
        RinseFrame:ClearAllPoints()
        RinseFrame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", RINSE_CONFIG.POSITION.x, RINSE_CONFIG.POSITION.y)
        RinseFrame:SetScale(RINSE_CONFIG.SCALE)
        RinseFrame:SetAlpha(RINSE_CONFIG.OPACITY)
        RinseFrame:SetMovable(not RINSE_CONFIG.LOCK)
        RinseOptionsFrameScaleSlider:SetValue(RINSE_CONFIG.SCALE)
        RinseOptionsFrameOpacitySlider:SetValue(RINSE_CONFIG.OPACITY)
        RinseOptionsFrameWyvernSting:SetChecked(RINSE_CONFIG.WYVERN_STING)
        RinseOptionsFrameMutatingInjection:SetChecked(RINSE_CONFIG.MUTATING_INJECTION)
        RinseOptionsFramePrint:SetChecked(RINSE_CONFIG.PRINT)
        RinseOptionsFrameSound:SetChecked(RINSE_CONFIG.SOUND)
        RinseOptionsFrameLock:SetChecked(RINSE_CONFIG.LOCK)
        UpdateSpells()
    elseif event == "RAID_ROSTER_UPDATE" or event == "PARTY_MEMBERS_CHANGED" then
        UpdatePrio()
    elseif event == "SPELLS_CHANGED" then
        UpdateSpells()
    end
end

function RinseFrame_OnUpdate(elapsed)
    timeElapsed = timeElapsed + elapsed
    errorCooldown = (errorCooldown > 0) and (errorCooldown - elapsed) or 0
    stopCastCooldown = (stopCastCooldown > 0) and (stopCastCooldown - elapsed) or 0
    if timeElapsed < updateInterval then
        return
    end
    timeElapsed = 0
    -- Clear debuffs info
    for i = 1, DEBUFFS_MAX do
        Debuffs[i].name = ""
        Debuffs[i].type = ""
        Debuffs[i].texture = ""
        Debuffs[i].stacks = 0
        Debuffs[i].unit = ""
        Debuffs[i].unitName = ""
        Debuffs[i].unitClass = ""
        Debuffs[i].shown = 0
        Debuffs[i].debuffIndex = 0
    end
    local debuffIndex = 1
    -- Get new info
    -- Target is highest prio
    if GoodUnit("target") then
        local i = 1
        while debuffIndex < DEBUFFS_MAX and UnitDebuff("target", i) do
            RinseScanTooltipTextLeft1:SetText("")
            RinseScanTooltipTextRight1:SetText("")
            RinseScanTooltip:SetUnitDebuff("target", i)
            local debuffName = RinseScanTooltipTextLeft1:GetText() or ""
            local debuffType = RinseScanTooltipTextRight1:GetText() or ""
            local texture, applications = UnitDebuff("target", i)
            local _, class = UnitClass("target")
            if debuffType and debuffName and class then
                if CanRemove[debuffType] and not (Blacklist[debuffType] and Blacklist[debuffType][debuffName]) and
                        not (ClassBlacklist[class] and ClassBlacklist[class][debuffName]) and not HasAbolish("target", debuffType) then
                    Debuffs[debuffIndex].name = debuffName or ""
                    Debuffs[debuffIndex].type = debuffType or ""
                    Debuffs[debuffIndex].texture = texture or ""
                    Debuffs[debuffIndex].stacks = applications or 0
                    Debuffs[debuffIndex].unit = "target"
                    Debuffs[debuffIndex].unitName = UnitName("target") or ""
                    Debuffs[debuffIndex].unitClass = class or ""
                    Debuffs[debuffIndex].debuffIndex = i
                    debuffIndex = debuffIndex + 1
                end
            end
            i = i + 1
        end
    end
    -- Scan units in Prio array
    for index = 1, getn(Prio) do
        local unit = Prio[index]
        if GoodUnit(unit) and not UnitIsUnit("target", unit) then
            local i = 1
            while debuffIndex < DEBUFFS_MAX and UnitDebuff(unit, i) do
                RinseScanTooltipTextLeft1:SetText("")
                RinseScanTooltipTextRight1:SetText("")
                RinseScanTooltip:SetUnitDebuff(unit, i)
                local debuffName = RinseScanTooltipTextLeft1:GetText() or ""
                local debuffType = RinseScanTooltipTextRight1:GetText() or ""
                local texture, applications = UnitDebuff(unit, i)
                local _, class = UnitClass(unit)
                if debuffType and debuffName and class then
                    if CanRemove[debuffType] and not (Blacklist[debuffType] and Blacklist[debuffType][debuffName]) and
                            not (ClassBlacklist[class] and ClassBlacklist[class][debuffName]) and not HasAbolish(unit, debuffType) then
                        Debuffs[debuffIndex].name = debuffName or ""
                        Debuffs[debuffIndex].type = debuffType or ""
                        Debuffs[debuffIndex].texture = texture or ""
                        Debuffs[debuffIndex].stacks = applications or 0
                        Debuffs[debuffIndex].unit = unit or ""
                        Debuffs[debuffIndex].unitName = UnitName(unit) or ""
                        Debuffs[debuffIndex].unitClass = class or ""
                        Debuffs[debuffIndex].debuffIndex = i
                        debuffIndex = debuffIndex + 1
                    end
                end
                i = i + 1
            end
        end
    end
    -- Hide all buttons
    for i = 1, BUTTONS_MAX do
        local btn = getglobal("RinseFrameDebuff"..i)
        btn:Hide()
        btn.unit = nil
    end
    debuffIndex = 1
    for buttonIndex = 1, BUTTONS_MAX do
        -- Find next debuff to show
        while debuffIndex < DEBUFFS_MAX and Debuffs[debuffIndex].shown ~= 0 do
            debuffIndex = debuffIndex + 1
        end
        local name = Debuffs[debuffIndex].name
        local unit = Debuffs[debuffIndex].unit
        local unitName = Debuffs[debuffIndex].unitName
        local class = Debuffs[debuffIndex].unitClass
        local debuffType = Debuffs[debuffIndex].type
        if name ~= "" then
            local button = getglobal("RinseFrameDebuff"..buttonIndex)
            local icon = getglobal("RinseFrameDebuff"..buttonIndex.."Icon")
            local debuffName = getglobal("RinseFrameDebuff"..buttonIndex.."Name")
            local playerName = getglobal("RinseFrameDebuff"..buttonIndex.."Player")
            local count = getglobal("RinseFrameDebuff"..buttonIndex.."Count")
            local border = getglobal("RinseFrameDebuff"..buttonIndex.."Border")
            local outOfRange = getglobal("RinseFrameDebuff"..buttonIndex.."OutOfRange")
            -- local onCooldown = getglobal("RinseFrameDebuff"..buttonIndex.."OnCooldown")
            icon:SetTexture(Debuffs[debuffIndex].texture)
            debuffName:SetText(name)
            playerName:SetText(ClassColors[class]..unitName)
            count:SetText(Debuffs[debuffIndex].stacks)
            border:SetVertexColor(DebuffColor[debuffType].r, DebuffColor[debuffType].g, DebuffColor[debuffType].b)
            button.unit = unit
            button.unitName = unitName
            button.unitClass = class
            button.type = debuffType
            button.debuffIndex = Debuffs[debuffIndex].debuffIndex
            button:Show()
            if buttonIndex == 1 and playNoticeSound then
                playsound(noticeSound)
                playNoticeSound = false
            end
            Debuffs[debuffIndex].shown = 1
            for i = debuffIndex, DEBUFFS_MAX do
                if Debuffs[i].unitName == unitName then
                    Debuffs[i].shown = 1
                end
            end
            -- onCooldown:Hide()
            -- if spellBookIndex and GetSpellCooldown(spellBookIndex, bookType) ~= 0 then
            --     onCooldown:Show()
            -- end
            if not InRange(unit) then
                outOfRange:Show()
            else
                outOfRange:Hide()
            end
        end
        if not RinseFrameDebuff1:IsShown() then
            playNoticeSound = true
        end
    end
end

function Rinse_Cleanse(button)
    local button = button or this
    if not button.unit or button.unit == "" then
        return
    end
    local debuff = getglobal(button:GetName().."Name"):GetText()
    print("Trying To Remove "..DebuffColor[button.type].hex..debuff..CLOSE.." from "..ClassColors[button.unitClass]..UnitName(button.unit)..CLOSE)
    if not InRange(button.unit) then
        print(ClassColors[button.unitClass]..UnitName(button.unit)..CLOSE.." is out of range.")
        if errorCooldown <= 0 then
            playsound(errorSound)
            errorCooldown = 0.1
        end
        return
    end
    if stopCastCooldown == 0 then
        SpellStopCasting()
        stopCastCooldown = 1
    end
    if superwow then
        CastSpellByName(CanRemove[button.type], button.unit)
    else
        local selfcast = false
        if GetCVar("autoselfcast") == "1" then
            selfcast = true
        end
        SetCVar("autoselfcast", 0)
        TargetByName(button.unitName, 1)
        CastSpellByName(CanRemove[button.type])
        TargetLastTarget()
        if selfcast then
            SetCVar("autoselfcast", 1)
        end
    end
end

SLASH_RINSE1 = "/rinse"
SlashCmdList["RINSE"] = function()
    for i = 1, BUTTONS_MAX do
        Rinse_Cleanse(getglobal("RinseFrameDebuff"..i))
    end
end
