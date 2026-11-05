_G = _G or getfenv(0)

local L = Rinse.L
local _, playerClass = UnitClass("player")
local unitxp = pcall(UnitXP, "nop", "nop")
local updateInterval = 0.1
local timeElapsed = 0
local lastDebuffCount = 0
local Timers = {
    error = { count = nil },
    stopCast = { count = nil },
    units = { count = nil, callback = nil }, -- callback functions will be filled in later when they are defined
    versionsCheck = { count = nil, callback = nil },
}
local Sounds = {
    error = "Sound\\Interface\\Error.wav",
    notice = "Sound\\Doodad\\BellTollTribal.wav",
}
local playNoticeSound = true
local aurasChanged = true
local autoattack
local selectedClass = "WARRIOR"
local OptionsScrollMaxButtons = 8
local AddonVersions
local DragInfo = { list = nil, sourceID = nil, destID = nil }

-- Bindings
BINDING_HEADER_RINSE_HEADER = "Rinse"
BINDING_NAME_RINSE = L["Run Rinse"]
BINDING_NAME_RINSE_TOGGLE_OPTIONS = L["Toggle Options"]
BINDING_NAME_RINSE_TOGGLE_PRIO = L["Toggle Prio List"]
BINDING_NAME_RINSE_TOGGLE_SKIP = L["Toggle Skip List"]

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
ClassColors["UNKNOWN"] = "|cff808080"

local DebuffColors = {}
DebuffColors[L["Snare"]]   = { r = 0.8, g = 0.0, b = 0.0, hex = "|cffCC0000" }
DebuffColors[L["Magic"]]   = { r = 0.2, g = 0.6, b = 1.0, hex = "|cff3399FF" }
DebuffColors[L["Curse"]]   = { r = 0.6, g = 0.0, b = 1.0, hex = "|cff9900FF" }
DebuffColors[L["Disease"]] = { r = 0.6, g = 0.4, b = 0.0, hex = "|cff996600" }
DebuffColors[L["Poison"]]  = { r = 0.0, g = 0.6, b = 0.0, hex = "|cff009900" }

local BLUE = "|cff3399FF"

-- Spells that remove stuff, for each class
local Spells = {}
Spells["PALADIN"] = {
    [L["Magic"]] = {L["Cleanse"]},
    [L["Poison"]] = {L["Cleanse"], L["Purify"]},
    [L["Disease"]] = {L["Cleanse"], L["Purify"]},
    [L["Snare"]] = {L["Hand of Freedom"]}
}
Spells["DRUID"] = {
    [L["Curse"]] = {L["Remove Curse"]},
    [L["Poison"]] = {L["Abolish Poison"], L["Cure Poison"]}
}
Spells["PRIEST"] = {
    [L["Magic"]] = {L["Dispel Magic"]},
    [L["Disease"]] = {L["Abolish Disease"], L["Cure Disease"]}
}
Spells["SHAMAN"] = {
    [L["Poison"]] = {L["Cure Poison"]},
    [L["Disease"]] = {L["Cure Disease"]}
}
Spells["MAGE"] = {
    [L["Curse"]] = {L["Remove Lesser Curse"]}
}
Spells["WARLOCK"] = {
    [L["Magic"]] = {L["Devour Magic"]}
}
Spells["WARRIOR"] = {}
Spells["ROGUE"]   = {}
Spells["HUNTER"]  = {}

-- Spells that we have
-- ["debuffType"] = "spellName"
local UsableSpells = {}

-- ["spellName"] = spellBookID
local UsableSpellBookIDs = {}

local lastSpellName = nil
local lastButton = nil

-- Number of buttons shown, can be overwritten by saved variables
local BUTTONS_MAX = 5

-- Debuff info
local Debuffs = {}

local Units = {}
Units["target"] = true
Units["player"] = true
Units["pet"] = true
for i = 1, 4 do Units["party"..i] = true end
for i = 1, 40 do Units["raid"..i] = true end
for unit in pairs(Units) do
    if unit ~= "target" and unit ~= "player" and unit ~= "pet" then
        Units[string.gsub(unit, "(%a+)(%d*)", "%1pet%2")] = true
    end
end

local UserUnits = {}

-- Skip list hash for O(1) lookup (rebuilt when SKIP_ARRAY changes)
local SkipNames = {}

-- Spells to ignore always (these will block other debuffs of the same type from showing)
local DefaultBlacklist = {}
DefaultBlacklist[L["Curse of Recklessness"]] = true
DefaultBlacklist[L["Delusions of Jin'do"]] = true
DefaultBlacklist[L["Dread of Outland"]] = true
DefaultBlacklist[L["Curse of Legion"]] = true
DefaultBlacklist[L["Phase Shifted"]] = true
DefaultBlacklist[L["Unstable Mana"]] = true
DefaultBlacklist[L["Seed of Corruption"]] = true -- explodes when dispelled
DefaultBlacklist[L["Mutating Injection"]] = true
DefaultBlacklist[L["Sanctum Mind Decay"]] = true
DefaultBlacklist[L["Wyvern Sting"]] = true
DefaultBlacklist[L["Poison Mushroom"]] = true
DefaultBlacklist[L["Gastronomic Guilt"]] = true

local Blacklist = {}
for k, v in pairs(DefaultBlacklist) do Blacklist[k] = v end

-- Debuffs that should be prioritized over other debuffs of the same type
-- Add more priority debuffs here as needed, it's going to be a tiny list
-- typically, not worth having an entire configuration section for.
local PriorityDebuffs = {}
PriorityDebuffs[L["Tranquilizing Poison"]] = true -- warriors will thank you
PriorityDebuffs[L["Wyrmkins Venom"]] = true
PriorityDebuffs[L["Slowing Poison"]] = true
PriorityDebuffs[L["Mana Buildup"]] = true
PriorityDebuffs[L["Enveloped Flames"]] = true -- prio so it shows up for pets!
PriorityDebuffs[L["Poison Charge"]] = true -- to prio it over curses for druids
PriorityDebuffs[L["Arcane Focus"]] = true -- tank prio for medivh
PriorityDebuffs[L["Freezing Chill"]] = true -- tank prio for medivh

-- Spells that player doesnt want to see (these will NOT block any other debuffs from showing)
-- Can be name of the debuff or a type
local DefaultFilter = {}
DefaultFilter[L["Magic"]] = Spells[playerClass][L["Magic"]] == nil
DefaultFilter[L["Disease"]] = Spells[playerClass][L["Disease"]] == nil
DefaultFilter[L["Poison"]] = Spells[playerClass][L["Poison"]] == nil
DefaultFilter[L["Curse"]] = Spells[playerClass][L["Curse"]] == nil
DefaultFilter[L["Snare"]] = Spells[playerClass][L["Snare"]] == nil
DefaultFilter[L["Icicles"]] = true
DefaultFilter[L["Arcane Overload"]] = true
DefaultFilter[L["Dreamless Sleep"]] = true
DefaultFilter[L["Greater Dreamless Sleep"]] = true
DefaultFilter[L["Songflower Serenade"]] = true
DefaultFilter[L["Mol'dar's Moxie"]] = true
DefaultFilter[L["Fengus' Ferocity"]] = true
DefaultFilter[L["Slip'kik's Savvy"]] = true
DefaultFilter[L["Thunderfury"]] = true
DefaultFilter[L["Magma Shackles"]] = true

local Filter = {}
for k, v in pairs(DefaultFilter) do Filter[k] = v end

-- Debuffs to filter on certain classes (these will NOT block other debuffs from showing)
local DefaultClassFilter = {}
for k in pairs(ClassColors) do DefaultClassFilter[k] = {} end
DefaultClassFilter["WARRIOR"][L["Ancient Hysteria"]] = true
DefaultClassFilter["WARRIOR"][L["Ignite Mana"]] = true
DefaultClassFilter["WARRIOR"][L["Tainted Mind"]] = true
DefaultClassFilter["WARRIOR"][L["Moroes Curse"]] = true
DefaultClassFilter["WARRIOR"][L["Curse of Manascale"]] = true
DefaultClassFilter["ROGUE"][L["Silence"]] = true
DefaultClassFilter["ROGUE"][L["Ancient Hysteria"]] = true
DefaultClassFilter["ROGUE"][L["Ignite Mana"]] = true
DefaultClassFilter["ROGUE"][L["Tainted Mind"]] = true
DefaultClassFilter["ROGUE"][L["Smoke Bomb"]] = true
DefaultClassFilter["ROGUE"][L["Screams of the Past"]] = true
DefaultClassFilter["ROGUE"][L["Moroes Curse"]] = true
DefaultClassFilter["ROGUE"][L["Curse of Manascale"]] = true
DefaultClassFilter["WARLOCK"][L["Rift Entanglement"]] = true

local ClassFilter = {}
for k in pairs(ClassColors) do
    ClassFilter[k] = {}
    for k2, v2 in pairs(DefaultClassFilter[k]) do
        ClassFilter[k][k2] = v2
    end
end

-- Spells that can be removed with paladins freedom
-- Probably do not want AoE slows here like Piercing Howl
local SnareDebuffs = {}
SnareDebuffs[L["Hamstring"]] = true
SnareDebuffs[L["Wing Clip"]] = true
SnareDebuffs[L["Mind Flay"]] = true
SnareDebuffs[L["Web"]] = true
SnareDebuffs[L["Web Explosion"]] = true
SnareDebuffs[L["Enveloping Web"]] = true
SnareDebuffs[L["Encasing Webs"]] = true
SnareDebuffs[L["Surge of Mana"]] = true
SnareDebuffs[L["Hooked Net"]] = true
SnareDebuffs[L["Tendon Rip"]] = true

local function wipe(t)
    if not (t and type(t) == "table") then return end
    for k in pairs(t) do t[k] = nil end
    table.setn(t, 0)
end

local function contains(t, value)
    if not (t and type(t) == "table") then return end
    for i = 1, table.getn(t) do
        if type(t[i]) == "table" then
            for k in pairs(t[i]) do
                if t[i][k] == value then return i end
            end
        end
        if t[i] == value then return i end
    end
    return nil
end

local function ChatMessage(msg)
    if not RINSE_CONFIG.PRINT then return end
    if RINSE_CONFIG.MSBT and MikSBT then
        MikSBT.DisplayMessage(msg, MikSBT.DISPLAYTYPE_NOTIFICATION, false, 255, 255, 255)
    else
        DEFAULT_CHAT_FRAME:AddMessage(BLUE.."[Rinse]|r "..(tostring(msg)))
    end
end

local function NameToUnitID(name)
    if not name then return nil end
    if UnitName("player") == name then return "player" end
    for i = 1, 4 do
        if UnitName("party"..i) == name then return "party"..i end
    end
    for i = 1, 40 do
        if UnitName("raid"..i) == name then return "raid"..i end
    end
end

local function HasAbolish(unit, debuffType)
    if not (UnitExists(unit) and debuffType and UsableSpells[debuffType] and (debuffType == L["Poison"] or debuffType == L["Disease"])) then
        return false
    end
    local icon
    if debuffType == L["Poison"] then
        icon = "Interface\\Icons\\Spell_Nature_NullifyPoison_02"
    elseif debuffType == L["Disease"] then
        icon = "Interface\\Icons\\Spell_Nature_NullifyDisease"
    end
    for i = 1, 32 do
        local buff = UnitBuff(unit, i)
        if not buff then break end
        if buff == icon then return true end
    end
    return false
end

local function HasShadowform()
    for i = 0, 31 do
        local index = GetPlayerBuff(i, "HELPFUL")
        if index > -1 then
            if GetPlayerBuffTexture(index) == "Interface\\Icons\\Spell_Shadow_Shadowform" then return true end
        end
    end
    return false
end

local function CanCast(unit, spell)
    if not unit then return false end

    local inRange

    if UnitIsFriend("player", unit) and not UnitCanAttack("player", unit) then
        if C_Spell and spell then
            inRange = C_Spell.IsSpellInRange(spell, unit)
        elseif IsSpellInRange and spell then
            inRange = IsSpellInRange(spell, unit) == 1
        elseif unitxp then
            -- Accounts for true reach. A tauren can dispell a male tauren at 38y!
            inRange = UnitXP("distanceBetween", "player", unit) < 30
        elseif SUPERWOW_VERSION then
            local myX, myY, myZ = UnitPosition("player")
            local uX, uY, uZ = UnitPosition(unit)
            if uX then
                local dx, dy, dz = uX - myX, uY - myY, uZ - myZ
                -- sqrt(1089) == 33, smallest max dispell range not accounting for true melee reach
                inRange = ((dx * dx) + (dy * dy) + (dz * dz)) <= 1089
            end
        else
            -- Not as accurate
            inRange = CheckInteractDistance(unit, 4)
        end
    else
        -- The above can't check mc'd players, this is the backup
        inRange = CheckInteractDistance(unit, 4)
    end

    if inRange then
        if UnitInLineOfSight then
            return UnitInLineOfSight(unit)
        elseif unitxp then
            return UnitXP("inSight", "player", unit)
        else
            return UnitIsVisible(unit)
        end
    end

    return false
end

local function RebuildUserUnits()
    wipe(UserUnits)
    local prio = 1
    for i = 1, table.getn(RINSE_CONFIG.PRIO_ARRAY) do
        local unit = NameToUnitID(RINSE_CONFIG.PRIO_ARRAY[i].name)
        if unit then UserUnits[unit] = prio; prio = prio + 1 end
    end
    aurasChanged = true
end

Timers.units.callback = RebuildUserUnits

local function RebuildSkipNames()
    wipe(SkipNames)
    for _, value in ipairs(RINSE_CONFIG.SKIP_ARRAY) do
        if value.name then SkipNames[value.name] = true end
    end
end

function RinseSkipListScrollFrame_Update()
    RebuildSkipNames()
    local offset = FauxScrollFrame_GetOffset(RinseSkipListScrollFrame)
    local arrayIndex = 1
    local numPlayers = table.getn(RINSE_CONFIG.SKIP_ARRAY)
    FauxScrollFrame_Update(RinseSkipListScrollFrame, numPlayers, 10, 16)
    for i = 1, 10 do
        local button = _G["RinseSkipListFrameButton"..i]
        local buttonText = _G["RinseSkipListFrameButton"..i.."Text"]
        arrayIndex = i + offset
        if RINSE_CONFIG.SKIP_ARRAY[arrayIndex] then
            buttonText:SetText(arrayIndex.." - "..ClassColors[RINSE_CONFIG.SKIP_ARRAY[arrayIndex].class]..RINSE_CONFIG.SKIP_ARRAY[arrayIndex].name)
            button:SetID(arrayIndex)
            if DragInfo.sourceID and DragInfo.sourceID == arrayIndex then
                buttonText:SetText("")
            end
            button:Show()
        else
            button:Hide()
        end
    end
end

function RinsePrioListScrollFrame_Update()
    local offset = FauxScrollFrame_GetOffset(RinsePrioListScrollFrame)
    local arrayIndex = 1
    local numPlayers = table.getn(RINSE_CONFIG.PRIO_ARRAY)
    FauxScrollFrame_Update(RinsePrioListScrollFrame, numPlayers, 10, 16)
    for i = 1, 10 do
        local button = _G["RinsePrioListFrameButton"..i]
        local buttonText = _G["RinsePrioListFrameButton"..i.."Text"]
        arrayIndex = i + offset
        if RINSE_CONFIG.PRIO_ARRAY[arrayIndex] then
            buttonText:SetText(arrayIndex.." - "..ClassColors[RINSE_CONFIG.PRIO_ARRAY[arrayIndex].class]..RINSE_CONFIG.PRIO_ARRAY[arrayIndex].name)
            button:SetID(arrayIndex)
            if DragInfo.sourceID and DragInfo.sourceID == arrayIndex then
                buttonText:SetText("")
            end
            button:Show()
        else
            button:Hide()
        end
    end
end

function RinseListButton_OnClick()
    if arg1 == "RightButton" then
        local parent = this:GetParent()
        if parent == RinseSkipListFrame then
            table.remove(RINSE_CONFIG.SKIP_ARRAY, this:GetID())
            RinseSkipListScrollFrame_Update()
        elseif parent == RinsePrioListFrame then
            table.remove(RINSE_CONFIG.PRIO_ARRAY, this:GetID())
            RinsePrioListScrollFrame_Update()
            RebuildUserUnits()
        end
        aurasChanged = true
    end
end

function RinseListButton_OnDragStart()
    DragInfo.list = this:GetParent()
    DragInfo.sourceID = this:GetID()
    local text = _G[this:GetName().."Text"]
    RinseMovingButtonText:SetText(text:GetText())
    text:SetText("")
    RinseMovingButton:StartMoving()
    RinseMovingButton:Show()
end

function RinseListButton_OnDragStop()
    if not DragInfo.list then return end
    RinseMovingButton:StopMovingOrSizing()
    RinseMovingButton:Hide()
    local array, update
    if DragInfo.list == RinsePrioListFrame then
        array = RINSE_CONFIG.PRIO_ARRAY
        update = RinsePrioListScrollFrame_Update
    elseif DragInfo.list == RinseSkipListFrame then
        array = RINSE_CONFIG.SKIP_ARRAY
        update = RinseSkipListScrollFrame_Update
    end
    if DragInfo.destID and DragInfo.sourceID and array and array[DragInfo.sourceID] and array[DragInfo.destID] then
        array[DragInfo.sourceID], array[DragInfo.destID] = array[DragInfo.destID], array[DragInfo.sourceID]
    end
    DragInfo.sourceID = nil
    update()
    RebuildUserUnits()
    DragInfo.list = nil
end

function RinseMovingButton_OnUpdate()
    if not DragInfo.list then return end
    local cursorX, cursorY = GetCursorPosition()
    cursorX = cursorX / UIParent:GetScale()
    cursorY = cursorY / UIParent:GetScale()
    RinseMovingButton:ClearAllPoints()
    RinseMovingButton:SetPoint("LEFT", nil, "BOTTOMLEFT", cursorX - 30, cursorY)
    DragInfo.destID = nil
    for i = 1, 10 do
        _G[DragInfo.list:GetName().."Button"..i.."Highlight"]:Hide()
    end
    for i = 1, 10 do
        local button = _G[DragInfo.list:GetName().."Button"..i]
        local highlight = _G[DragInfo.list:GetName().."Button"..i.."Highlight"]
        if button:IsShown() and MouseIsOver(button) then
            highlight:Show()
            DragInfo.destID = button:GetID()
        end
    end
end

function Rinse_AddUnitToList(array, unit)
    local name = UnitName(unit)
    local _, class = UnitClass(unit)
    if name and UnitIsFriend(unit, "player") and UnitIsPlayer(unit) and not contains(array, name) then
        table.insert(array, { name = name, class = class })
    end
    if array == RINSE_CONFIG.SKIP_ARRAY then
        RinseSkipListScrollFrame_Update()
    elseif array == RINSE_CONFIG.PRIO_ARRAY then
        RinsePrioListScrollFrame_Update()
        RebuildUserUnits()
    end
    aurasChanged = true
end

local info = {}
info.textHeight = 12
info.notCheckable = 1
info.hasArrow = nil
info.checked = nil
info.func = function()
    local array
    if UIDROPDOWNMENU_MENU_VALUE == "Rinse_SkipList" then
        array = RINSE_CONFIG.SKIP_ARRAY
    elseif UIDROPDOWNMENU_MENU_VALUE == "Rinse_PrioList" then
        array = RINSE_CONFIG.PRIO_ARRAY
    end
    if type(this.value) == "number" then
        -- This is group number
        if GetNumRaidMembers() > 0 then
            for i = 1 , 40 do
                local name, rank, subgroup, level, class, classFileName, zone, online, isDead = GetRaidRosterInfo(i)
                if name and subgroup == this.value then Rinse_AddUnitToList(array, "raid"..i) end
            end
        elseif GetNumPartyMembers() > 0 then
            if this.value == 1 then
                Rinse_AddUnitToList(array, "player")
                for i = 1, 4 do
                    if UnitName("party"..i) then Rinse_AddUnitToList(array, "party"..i) end
                end
            end
        end
    elseif type(this.value) == "string" then
        -- This is class
        if GetNumRaidMembers() > 0 then
            for i = 1 , 40 do
                local name, rank, subgroup, level, class, classFileName, zone, online, isDead = GetRaidRosterInfo(i)
                if name and classFileName == this.value then Rinse_AddUnitToList(array, "raid"..i) end
            end
        elseif GetNumPartyMembers() > 0 then
            if this.value == playerClass then Rinse_AddUnitToList(array, "player") end
            for i = 1, 4 do
                local _, class = UnitClass("party"..i)
                if UnitName("party"..i) and class == this.value then Rinse_AddUnitToList(array, "party"..i) end
            end
        end
    end
end

local function ClassMenu()
    if UIDROPDOWNMENU_MENU_LEVEL == 1 then
        info.text = ClassColors["WARRIOR"]..L["Warriors"]
        info.value = "WARRIOR"
        UIDropDownMenu_AddButton(info)
        info.text = ClassColors["DRUID"]..L["Druids"]
        info.value = "DRUID"
        UIDropDownMenu_AddButton(info)
        info.text = ClassColors["PALADIN"]..L["Paladins"]
        info.value = "PALADIN"
        UIDropDownMenu_AddButton(info)
        info.text = ClassColors["WARLOCK"]..L["Warlocks"]
        info.value = "WARLOCK"
        UIDropDownMenu_AddButton(info)
        info.text = ClassColors["MAGE"]..L["Mages"]
        info.value = "MAGE"
        UIDropDownMenu_AddButton(info)
        info.text = ClassColors["PRIEST"]..L["Priests"]
        info.value = "PRIEST"
        UIDropDownMenu_AddButton(info)
        info.text = ClassColors["ROGUE"]..L["Rogues"]
        info.value = "ROGUE"
        UIDropDownMenu_AddButton(info)
        info.text = ClassColors["HUNTER"]..L["Hunters"]
        info.value = "HUNTER"
        UIDropDownMenu_AddButton(info)
        info.text = ClassColors["SHAMAN"]..L["Shamans"]
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

StaticPopupDialogs["RINSE_ADD_PLAYER_TO_LIST"] = {
    text = L["Enter player name:"],
    button1 = OKAY,
    button2 = CANCEL,
    hasEditBox = 1,
    maxLetters = 12,
    OnAccept = function()
        local dialog = this:GetParent()
        local name = _G[dialog:GetName().."EditBox"]:GetText()
        if not name or name == "" then return end
        local array
        if dialog.data == "skip" then
            array = RINSE_CONFIG.SKIP_ARRAY
        elseif dialog.data == "prio" then
            array = RINSE_CONFIG.PRIO_ARRAY
        end
        if not array then return end
        if contains(array, name) then return end
        local class = "UNKNOWN"
        local unit = NameToUnitID(name)
        if unit then
            local _, c = UnitClass(unit)
            if c then class = c end
        end
        table.insert(array, { name = name, class = class })
        if array == RINSE_CONFIG.SKIP_ARRAY then
            RinseSkipListScrollFrame_Update()
        elseif array == RINSE_CONFIG.PRIO_ARRAY then
            RinsePrioListScrollFrame_Update()
            RebuildUserUnits()
        end
    end,
    EditBoxOnEnterPressed = function()
        StaticPopupDialogs[this:GetParent().which].OnAccept()
        this:GetParent():Hide()
    end,
    EditBoxOnEscapePressed = function()
        this:GetParent():Hide()
    end,
    OnShow = function()
        _G[this:GetName().."EditBox"]:SetFocus()
    end,
    OnHide = function()
        _G[this:GetName().."EditBox"]:SetText("")
    end,
    timeout = 0,
    exclusive = 1,
    hideOnEscape = 1
}

function Rinse_ClearButton_OnClick()
    if this:GetParent() == RinseSkipListFrame then
        wipe(RINSE_CONFIG.SKIP_ARRAY)
        RinseSkipListScrollFrame_Update()
    elseif this:GetParent() == RinsePrioListFrame then
        wipe(RINSE_CONFIG.PRIO_ARRAY)
        RinsePrioListScrollFrame_Update()
    end
    RebuildUserUnits()
end

local bookType = BOOKTYPE_SPELL
if playerClass == "WARLOCK" then
    bookType = BOOKTYPE_PET
end

local AllSpells = {}

local function UpdateSpells()
    if next(Spells[playerClass]) == nil then return end
    -- Gather all spells and their spellBookID
    wipe(AllSpells)
    for tab = 1, GetNumSpellTabs() do
        local _, _, offset, numSpells = GetSpellTabInfo(tab)
        for spellSlot = offset + 1, offset + numSpells do
            local spellName = GetSpellName(spellSlot, bookType)
            if spellName then AllSpells[spellName] = spellSlot end
        end
    end
    -- Search AllSpells for cleansing spells
    for dispelType, spells in pairs(Spells[playerClass]) do
        -- Search in reverse order to finish at more powerful spell which should be at index 1 in Spells[playerClass][debuffType]
        for i = table.getn(spells), 1, -1 do
            local spellName = spells[i]
            if spellName == L["Cleanse"] and RINSE_CHAR_CONFIG.FILTER[L["Magic"]] then break end -- In this case use Purify
            if AllSpells[spellName] then
                UsableSpells[dispelType] = spellName
                UsableSpellBookIDs[spellName] = AllSpells[spellName]
            end
        end
    end
end

local function ResolvePlayerClasses(array)
    for i, value in ipairs(array) do
        if value.class == "UNKNOWN" then
            local unit = NameToUnitID(value.name)
            if unit then
                local _, c = UnitClass(unit)
                if c then value.class = c end
            end
        end
    end
end

function RinseFramePrioList_OnClick()
    if RinsePrioListFrame:IsShown() then
        RinsePrioListFrame:Hide()
    else
        ResolvePlayerClasses(RINSE_CONFIG.PRIO_ARRAY)
        RinsePrioListFrame:Show()
        RinsePrioListScrollFrame_Update()
    end
end

function RinseFrameSkipList_OnClick()
    if RinseSkipListFrame:IsShown() then
        RinseSkipListFrame:Hide()
    else
        ResolvePlayerClasses(RINSE_CONFIG.SKIP_ARRAY)
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

local function DisableCheckBox(checkBox, requirement)
    if not checkBox then return end
    checkBox:Disable()
    _G[checkBox:GetName().."Text"]:SetTextColor(GRAY_FONT_COLOR.r, GRAY_FONT_COLOR.g, GRAY_FONT_COLOR.b)
    _G[checkBox:GetName().."TooltipPreserve"]:Show()
    if requirement then checkBox.tooltipRequirement = requirement end
end

local function EnableCheckBox(checkBox)
    if not checkBox then return end
    checkBox:Enable()
    _G[checkBox:GetName().."Text"]:SetTextColor(NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b)
    _G[checkBox:GetName().."TooltipPreserve"]:Hide()
end

local function UpdateBlacklist()
    for k, v in pairs(RINSE_CHAR_CONFIG.BLACKLIST) do Blacklist[k] = v end
    aurasChanged = true
end

local function UpdateFilter()
    for k, v in pairs(RINSE_CHAR_CONFIG.FILTER) do Filter[k] = v end
    for k, v in pairs(RINSE_CHAR_CONFIG.FILTER_CLASS) do
        RINSE_CHAR_CONFIG.FILTER_CLASS[k] = RINSE_CHAR_CONFIG.FILTER_CLASS[k] or {}
        for k2, v2 in pairs(RINSE_CHAR_CONFIG.FILTER_CLASS[k]) do ClassFilter[k][k2] = v2 end
    end
    UpdateSpells()
    aurasChanged = true
end

function Rinse_ToggleFilter(filter)
    RINSE_CHAR_CONFIG.FILTER[filter] = not RINSE_CHAR_CONFIG.FILTER[filter]
    RinseOptionsFrameFilterMagic:SetChecked(not RINSE_CHAR_CONFIG.FILTER[L["Magic"]])
    RinseOptionsFrameFilterSnare:SetChecked(not RINSE_CHAR_CONFIG.FILTER[L["Snare"]])
    RinseOptionsFrameFilterDisease:SetChecked(not RINSE_CHAR_CONFIG.FILTER[L["Disease"]])
    RinseOptionsFrameFilterPoison:SetChecked(not RINSE_CHAR_CONFIG.FILTER[L["Poison"]])
    RinseOptionsFrameFilterCurse:SetChecked(not RINSE_CHAR_CONFIG.FILTER[L["Curse"]])
    UpdateFilter()
    RinseOptionsFrameFilterScrollFrame_Update()
end

function Rinse_ToggleWyvernSting()
    RINSE_CHAR_CONFIG.BLACKLIST[L["Wyvern Sting"]] = not RINSE_CHAR_CONFIG.BLACKLIST[L["Wyvern Sting"]]
    RinseOptionsFrameWyvernSting:SetChecked(not RINSE_CHAR_CONFIG.BLACKLIST[L["Wyvern Sting"]])
    UpdateBlacklist()
    RinseOptionsFrameBlacklistScrollFrame_Update()
end

function Rinse_ToggleMutatingInjection()
    RINSE_CHAR_CONFIG.BLACKLIST[L["Mutating Injection"]] = not RINSE_CHAR_CONFIG.BLACKLIST[L["Mutating Injection"]]
    RinseOptionsFrameMutatingInjection:SetChecked(not RINSE_CHAR_CONFIG.BLACKLIST[L["Mutating Injection"]])
    UpdateBlacklist()
    RinseOptionsFrameBlacklistScrollFrame_Update()
end

function Rinse_ToggleIgnoreAbolish()
    RINSE_CONFIG.IGNORE_ABOLISH = not RINSE_CONFIG.IGNORE_ABOLISH
end

function Rinse_ToggleShadowform()
    RINSE_CONFIG.SHADOWFORM = not RINSE_CONFIG.SHADOWFORM
end

function Rinse_TogglePets()
    RINSE_CONFIG.PETS = not RINSE_CONFIG.PETS
    RebuildUserUnits()
end

function Rinse_TogglePrint()
    RINSE_CONFIG.PRINT = not RINSE_CONFIG.PRINT
    if RINSE_CONFIG.PRINT and MikSBT then
        EnableCheckBox(RinseOptionsFrameMSBT)
    else
        DisableCheckBox(RinseOptionsFrameMSBT)
    end
end

function Rinse_ToggleMSBT()
    RINSE_CONFIG.MSBT = not RINSE_CONFIG.MSBT
end

function Rinse_ToggleSound()
    RINSE_CONFIG.SOUND = not RINSE_CONFIG.SOUND
end

function Rinse_ToggleLock()
    RINSE_CONFIG.LOCK = not RINSE_CONFIG.LOCK
    RinseFrame:SetMovable(not RINSE_CONFIG.LOCK)
    RinseFrame:EnableMouse(not RINSE_CONFIG.LOCK)
end

local function UpdateBackdrop()
    if RINSE_CONFIG.BACKDROP then
        RinseFrame:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true,
            tileSize = 16,
            edgeSize = 16,
            insets = { left = 5, right = 5, top = 5, bottom = 5 },
        })
        RinseFrame:SetBackdropBorderColor(1, 1, 1)
        RinseFrame:SetBackdropColor(0, 0, 0, 0.5)
    else
        RinseFrame:SetBackdrop(nil)
    end
end

function Rinse_ToggleBackdrop()
    RINSE_CONFIG.BACKDROP = not RINSE_CONFIG.BACKDROP
    UpdateBackdrop()
end

local function UpdateFramesScale()
    local scale = RINSE_CONFIG.SCALE
    RinseFrame:SetScale(scale)
    RinsePrioListFrame:SetScale(scale)
    RinseSkipListFrame:SetScale(scale)
end

function RinseOptionsFrameScaleSLider_OnValueChanged()
    local scale = tonumber(string.format("%.2f", this:GetValue()))
    RINSE_CONFIG.SCALE = scale
    RinseFrame:SetScale(scale)
    RinseDebuffsFrame:SetScale(scale)
    _G[this:GetName().."Text"]:SetText(string.format(L.FMT_SCALE, scale))
    UpdateFramesScale()
end

local function UpdateDirection()
    if not RINSE_CONFIG.FLIP then
        -- Normal direction (from top to bottom)
        RinseFrameBackground:ClearAllPoints()
        RinseFrameBackground:SetPoint("TOP", 0, -5)
        RinseFrameTitle:ClearAllPoints()
        RinseFrameTitle:SetPoint("TOPLEFT", 12, -12)
        if RINSE_CONFIG.SHOW_HEADER then
            RinseDebuffsFrame:SetPoint("TOP", RinseFrame, "TOP", 0, -35)
        else
            RinseDebuffsFrame:SetPoint("TOP", RinseFrame, "TOP", 0, -5)
        end
        for i = 1, BUTTONS_MAX do
            local frame = _G["RinseFrameDebuff"..i]
            if i == 1 then
                frame:ClearAllPoints()
                frame:SetPoint("TOP", RinseDebuffsFrame, "TOP", 0, 0)
            else
                local prevFrame = _G["RinseFrameDebuff"..(i - 1)]
                frame:ClearAllPoints()
                frame:SetPoint("TOP", prevFrame, "BOTTOM", 0, 0)
            end
        end
    else
        -- Inverted (from bottom to top)
        RinseFrameBackground:ClearAllPoints()
        RinseFrameBackground:SetPoint("BOTTOM", 0, 5)
        RinseFrameTitle:ClearAllPoints()
        RinseFrameTitle:SetPoint("BOTTOMLEFT", 12, 12)
        RinseDebuffsFrame:SetPoint("TOP", RinseFrame, "TOP", 0, -5)
        for i = 1, BUTTONS_MAX do
            local frame = _G["RinseFrameDebuff"..i]
            if i == 1 then
                frame:ClearAllPoints()
                frame:SetPoint("BOTTOM", RinseDebuffsFrame, "BOTTOM", 0, 0)
            else
                local prevFrame = _G["RinseFrameDebuff"..(i - 1)]
                frame:ClearAllPoints()
                frame:SetPoint("BOTTOM", prevFrame, "TOP", 0, 0)
            end
        end
    end
end

function Rinse_ToggleDirection()
    RINSE_CONFIG.FLIP = not RINSE_CONFIG.FLIP
    UpdateDirection()
end

local function UpdateNumButtons()
    local num = RINSE_CONFIG.BUTTONS
    RinseDebuffsFrame:SetHeight(num * 42)
    if num > BUTTONS_MAX then
        -- Adding buttons
        RinseFrame:SetHeight(RinseFrame:GetHeight() + (num - BUTTONS_MAX) * 42)
        local btn, prevBtn
        for i = BUTTONS_MAX + 1, num do
            btn = _G["RinseFrameDebuff"..i]
            if not btn then
                btn = CreateFrame("Button", "RinseFrameDebuff"..i, RinseDebuffsFrame, "RinseDebuffButtonTemplate")
            end
            prevBtn = _G["RinseFrameDebuff"..(i - 1)]
            btn:ClearAllPoints()
            if not RINSE_CONFIG.FLIP then
                btn:SetPoint("TOP", prevBtn, "BOTTOM", 0, 0)
            else
                btn:SetPoint("BOTTOM", prevBtn, "TOP", 0, 0)
            end
        end
    elseif num < BUTTONS_MAX then
        -- Removing buttons
        RinseFrame:SetHeight(RinseFrame:GetHeight() - (BUTTONS_MAX - num) * 42)
        for i = num + 1, BUTTONS_MAX do
            _G["RinseFrameDebuff"..i]:Hide()
        end
    end
    BUTTONS_MAX = num
end

function RinseOptionsFrameButtonsSlider_OnValueChanged()
    local numButtons = tonumber(string.format("%d", this:GetValue()))
    RINSE_CONFIG.BUTTONS = numButtons
    UpdateNumButtons()
    _G[this:GetName().."Text"]:SetText(string.format(L.FMT_DEBUFFS_SHOWN, numButtons))
end

local function UpdateHeader()
    if RINSE_CONFIG.SHOW_HEADER then
        RinseFrameHitRect:Show()
        RinseFrameBackground:Show()
        RinseFrameTitle:Show()
        RinseFrame:SetHeight(BUTTONS_MAX * 42 + 40)
        if RINSE_CONFIG.FLIP then
            RinseDebuffsFrame:SetPoint("TOP", RinseFrame, "TOP", 0, -5)
        else
            RinseDebuffsFrame:SetPoint("TOP", RinseFrame, "TOP", 0, -35)
        end
    else
        RinseFrameHitRect:Hide()
        RinseFrameBackground:Hide()
        RinseFrameTitle:Hide()
        RinseFrame:SetHeight(BUTTONS_MAX * 42 + 10)
        RinseDebuffsFrame:SetPoint("TOP", RinseFrame, "TOP", 0, -5)
        DEFAULT_CHAT_FRAME:AddMessage(BLUE.."[Rinse]|r "..L["Buttons are hidden, to access option and lists use /rinse options, /rinse skip or /rinse prio."])
    end
end

function Rinse_ToggleHeader()
    RINSE_CONFIG.SHOW_HEADER = not RINSE_CONFIG.SHOW_HEADER
    UpdateHeader()
end

function RinseFrame_OnLoad()
    RinseFrame:RegisterEvent("ADDON_LOADED")
    RinseFrame:RegisterEvent("RAID_ROSTER_UPDATE")
    RinseFrame:RegisterEvent("PARTY_MEMBERS_CHANGED")
    RinseFrame:RegisterEvent("SPELLS_CHANGED")
    RinseFrame:RegisterEvent("CHAT_MSG_ADDON")
    RinseFrame:RegisterEvent("UNIT_AURA")
    RinseFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
    if GetNampowerVersion then
        -- Announce queued decurses
        RinseFrame:RegisterEvent("SPELL_QUEUE_EVENT")
    end
    if not SUPERWOW_VERSION and not C_Spell then
        -- For restoring auto attack
        RinseFrame:RegisterEvent("PLAYER_ENTER_COMBAT")
        RinseFrame:RegisterEvent("PLAYER_LEAVE_COMBAT")
    end
    RinseFrameTitle:SetText("Rinse "..GetAddOnMetadata("Rinse", "Version"))
end

function RinseFrame_OnEvent(event, arg1, arg2)
    if event == "ADDON_LOADED" then
        if arg1 ~= "Rinse" then return end
        RinseFrame:UnregisterEvent(event)
        table.insert(UISpecialFrames, "RinsePrioListFrame")
        table.insert(UISpecialFrames, "RinseSkipListFrame")
        table.insert(UISpecialFrames, "RinseOptionsFrame")
        RINSE_CONFIG = RINSE_CONFIG or {}
        RINSE_CHAR_CONFIG = RINSE_CHAR_CONFIG or {}
        RINSE_CONFIG.SKIP_ARRAY = RINSE_CONFIG.SKIP_ARRAY or {}
        RINSE_CONFIG.PRIO_ARRAY = RINSE_CONFIG.PRIO_ARRAY or {}
        RebuildSkipNames()
        RINSE_CONFIG.POSITION = RINSE_CONFIG.POSITION or {x = 0, y = 0}
        RINSE_CONFIG.SCALE = RINSE_CONFIG.SCALE or 0.85
        RINSE_CONFIG.OPACITY = RINSE_CONFIG.OPACITY or 1.0
        RINSE_CONFIG.PRINT = RINSE_CONFIG.PRINT == nil and true or RINSE_CONFIG.PRINT
        RINSE_CONFIG.MSBT = RINSE_CONFIG.MSBT == nil and true or RINSE_CONFIG.MSBT
        RINSE_CONFIG.SOUND = RINSE_CONFIG.SOUND == nil and true or RINSE_CONFIG.SOUND
        RINSE_CONFIG.LOCK = RINSE_CONFIG.LOCK == nil and false or RINSE_CONFIG.LOCK
        RINSE_CONFIG.BACKDROP = RINSE_CONFIG.BACKDROP == nil and true or RINSE_CONFIG.BACKDROP
        RINSE_CONFIG.FLIP = RINSE_CONFIG.FLIP == nil and false or RINSE_CONFIG.FLIP
        RINSE_CONFIG.BUTTONS = RINSE_CONFIG.BUTTONS == nil and BUTTONS_MAX or RINSE_CONFIG.BUTTONS
        RINSE_CONFIG.SHOW_HEADER = RINSE_CONFIG.SHOW_HEADER == nil and true or RINSE_CONFIG.SHOW_HEADER
        RINSE_CONFIG.SHADOWFORM = RINSE_CONFIG.SHADOWFORM == nil and true or RINSE_CONFIG.SHADOWFORM
        RINSE_CONFIG.IGNORE_ABOLISH = RINSE_CONFIG.IGNORE_ABOLISH == nil and true or RINSE_CONFIG.IGNORE_ABOLISH
        RINSE_CONFIG.PETS = RINSE_CONFIG.PETS == nil and false or RINSE_CONFIG.PETS
        RINSE_CHAR_CONFIG.BLACKLIST = RINSE_CHAR_CONFIG.BLACKLIST or {}
        RINSE_CHAR_CONFIG.FILTER = RINSE_CHAR_CONFIG.FILTER or {
            [L["Magic"]] = Spells[playerClass][L["Magic"]] == nil,
            [L["Disease"]] = Spells[playerClass][L["Disease"]] == nil,
            [L["Poison"]] = Spells[playerClass][L["Poison"]] == nil,
            [L["Snare"]] = Spells[playerClass][L["Snare"]] == nil,
            [L["Curse"]] = Spells[playerClass][L["Curse"]] == nil,
        }
        RINSE_CHAR_CONFIG.FILTER_CLASS = RINSE_CHAR_CONFIG.FILTER_CLASS or {
            WARRIOR = {},
            DRUID   = {},
            PALADIN = {},
            WARLOCK = {},
            MAGE    = {},
            PRIEST  = {},
            ROGUE   = {},
            HUNTER  = {},
            SHAMAN  = {},
        }
        RinseFrame:ClearAllPoints()
        RinseFrame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", RINSE_CONFIG.POSITION.x, RINSE_CONFIG.POSITION.y)
        RinseFrame:SetScale(RINSE_CONFIG.SCALE)
        RinseDebuffsFrame:SetScale(RINSE_CONFIG.SCALE)
        RinseFrame:SetAlpha(RINSE_CONFIG.OPACITY)
        RinseFrame:SetMovable(not RINSE_CONFIG.LOCK)
        RinseFrame:EnableMouse(not RINSE_CONFIG.LOCK)
        RinseOptionsFrameScaleSlider:SetValue(RINSE_CONFIG.SCALE)
        RinseOptionsFrameOpacitySlider:SetValue(RINSE_CONFIG.OPACITY)
        RinseOptionsFrameIgnoreAbolish:SetChecked(RINSE_CONFIG.IGNORE_ABOLISH)
        RinseOptionsFrameShadowform:SetChecked(RINSE_CONFIG.SHADOWFORM)
        RinseOptionsFramePets:SetChecked(RINSE_CONFIG.PETS)
        RinseOptionsFramePrint:SetChecked(RINSE_CONFIG.PRINT)
        RinseOptionsFrameMSBT:SetChecked(RINSE_CONFIG.MSBT)
        RinseOptionsFrameSound:SetChecked(RINSE_CONFIG.SOUND)
        RinseOptionsFrameLock:SetChecked(RINSE_CONFIG.LOCK)
        RinseOptionsFrameBackdrop:SetChecked(RINSE_CONFIG.BACKDROP)
        RinseOptionsFrameShowHeader:SetChecked(RINSE_CONFIG.SHOW_HEADER)
        RinseOptionsFrameFlip:SetChecked(RINSE_CONFIG.FLIP)
        RinseOptionsFrameButtonsSlider:SetValue(RINSE_CONFIG.BUTTONS)
        UpdateBlacklist()
        RinseOptionsFrameWyvernSting:SetChecked(not Blacklist[L["Wyvern Sting"]])
        RinseOptionsFrameMutatingInjection:SetChecked(not Blacklist[L["Mutating Injection"]])
        UpdateFilter()
        RinseOptionsFrameFilterMagic:SetChecked(not Filter[L["Magic"]])
        RinseOptionsFrameFilterDisease:SetChecked(not Filter[L["Disease"]])
        RinseOptionsFrameFilterPoison:SetChecked(not Filter[L["Poison"]])
        RinseOptionsFrameFilterSnare:SetChecked(not Filter[L["Snare"]])
        RinseOptionsFrameFilterCurse:SetChecked(not Filter[L["Curse"]])
        for k in pairs(DebuffColors) do
            local checkBox = _G["RinseOptionsFrameFilter"..k]
            if checkBox then
                if Spells[playerClass] and Spells[playerClass][k] then
                    EnableCheckBox(checkBox)
                else
                    DisableCheckBox(checkBox, L["Not available to your class."])
                end
            end
        end
        if Spells[playerClass] and Spells[playerClass][L["Poison"]] then
            EnableCheckBox(RinseOptionsFrameWyvernSting)
        else
            DisableCheckBox(RinseOptionsFrameWyvernSting, L["Not available to your class."])
        end
        if Spells[playerClass] and Spells[playerClass][L["Disease"]] then
            EnableCheckBox(RinseOptionsFrameMutatingInjection)
        else
            DisableCheckBox(RinseOptionsFrameMutatingInjection, L["Not available to your class."])
        end
        if playerClass == "PRIEST" then
            EnableCheckBox(RinseOptionsFrameShadowform)
        else
            DisableCheckBox(RinseOptionsFrameShadowform, L["Not available to your class."])
        end
        if RINSE_CONFIG.PRINT and MikSBT then
            EnableCheckBox(RinseOptionsFrameMSBT)
        else
            DisableCheckBox(RinseOptionsFrameMSBT, not MikSBT and L["MSBT missing."] or nil)
        end
        UpdateBackdrop()
        UpdateFramesScale()
        UpdateDirection()
        UpdateNumButtons()
        UpdateHeader()
        UpdateSpells()
        RebuildUserUnits()
        RinseSkipListFrameTitle:SetText(L["Skip List"])
        RinseSkipListFrameClear:SetText(L["Clear"])
        RinsePrioListFrameTitle:SetText(L["Priority List"])
        RinsePrioListFrameClear:SetText(L["Clear"])
        RinseOptionsFrameTitle:SetText("Rinse".." "..L["Options"])
        RinseOptionsFrameFilterText:SetText(L["Hidden Debuffs"])
        RinseOptionsFrameClassFilterText:SetText(L["Class Hidden"])
        RinseOptionsFrameHiddenDebuffsText:SetText(L["Blacklisted Debuffs"])
        RinseOptionsFrameAddToFilter:SetText(L["Add"])
        RinseOptionsFrameAddToBlacklist:SetText(L["Add"])
        RinseOptionsFrameAddToClassFilter:SetText(L["Add"])
        RinseOptionsFrameSelectClassText:SetText(ClassColors["WARRIOR"]..L["Warriors"])
    elseif event == "SPELL_QUEUE_EVENT" then
        if not RINSE_CONFIG.PRINT then return end

        -- arg1 is eventCode, arg2 is spellId
        -- NORMAL_QUEUE_POPPED = 3
        if arg1 ~= 3 then return end

        local spellName = GetSpellNameAndRankForId(arg2)
        if not (lastSpellName and lastButton and lastSpellName == spellName) then return end

        -- If button unit no longer set, don't print
        if not lastButton.unit or lastButton.unit == "" then return end

        ChatMessage(DebuffColors[lastButton.type].hex..lastButton.DebuffName:GetText().."|r - "..ClassColors[lastButton.unitClass]..UnitName(lastButton.unit).."|r")
    elseif event == "RAID_ROSTER_UPDATE" or event == "PARTY_MEMBERS_CHANGED" then
        -- print(event)
        Timers.units.count = 0.2
    elseif event == "SPELLS_CHANGED" then
        -- print(event)
        UpdateSpells()
    elseif event == "PLAYER_ENTER_COMBAT" then
        -- print(event)
        autoattack = UnitName("target")
    elseif event == "PLAYER_LEAVE_COMBAT" then
        -- print(event)
        autoattack = nil
    elseif event == "CHAT_MSG_ADDON" then
        if arg1 ~= "Rinse" or arg4 == UnitName("player") then return end
        -- print(event, arg4, arg2)
        if arg2 == "REPORT_ADDON_VERSION" then
            SendAddonMessage("Rinse", "V_"..GetAddOnMetadata("Rinse", "Version"), "RAID")
        elseif Timers.versionsCheck.count and string.find(arg2, "^V_") then
            AddonVersions = AddonVersions or {}
            local v = string.sub(arg2, 3) or ""
            table.insert(AddonVersions, { name = arg4, vString = string.format("%s(%s)", arg4, v), vValue = tonumber((string.gsub(v, "%.", "0"))) or 0 })
        end
    elseif event == "UNIT_AURA" then
        if Units[arg1] then
            -- print(event, arg1)
            aurasChanged = true
        end
    elseif event == "PLAYER_TARGET_CHANGED" then
        -- print(event)
        aurasChanged = true
    end
end

local function order(a, b)
    if a.weight == b.weight then
        if a.userPrio == b.userPrio then
            if a.debuffIndex == b.debuffIndex then
                return a.unitName < b.unitName
            end
            return a.debuffIndex < b.debuffIndex
        end
        return a.userPrio < b.userPrio
    end
    return a.weight > b.weight
end

function RinseFrame_OnUpdate(elapsed)
    for _, timer in pairs(Timers) do
        if timer.count then
            timer.count = timer.count - elapsed
            if timer.count <= 0 then
                timer.count = nil
                if timer.callback then timer.callback() end
            end
        end
    end

    timeElapsed = timeElapsed + elapsed
    if timeElapsed < updateInterval then return end
    timeElapsed = 0

    if aurasChanged then
        aurasChanged = false
        -- Clear only entries that were used last tick
        for i = 1, lastDebuffCount do
            local d = Debuffs[i]
            d.name = ""
            d.type = ""
            d.texture = ""
            d.stacks = 0
            d.unit = ""
            d.unitName = ""
            d.unitClass = ""
            d.hidden = false
            d.debuffIndex = 0
            d.weight = 0
            d.userPrio = 99
        end
        local debuffCount = 0
        -- Get new debuffs info
        for unit in pairs(Units) do
            local unitName = UnitName(unit)
            if ( UnitExists(unit) and UnitIsVisible(unit) and unitName and not SkipNames[unitName]
                and ((UnitCanAssist("player", unit) and not UnitIsCharmed(unit)) or (not UnitCanAssist("player", unit) and UnitIsCharmed(unit))) )
            then
                for i = 1, 16 do
                    local debuffName, debuffType, texture, applications, spellID
                    if C_UnitAuras then
                        debuffName, texture, applications, debuffType = C_UnitAuras.UnitAura(unit, i, "HARMFUL")
                    else
                        texture, applications, debuffType, spellID = UnitDebuff(unit, i)
                    end
                    if not texture then break end
                    if spellID then
                        if SpellInfo then
                            debuffName = SpellInfo(spellID)
                        elseif GetSpellNameAndRankForId then
                            debuffName = GetSpellNameAndRankForId(spellID)
                        end
                    end
                    if not debuffName then
                        RinseScanTooltipTextLeft1:SetText("")
                        RinseScanTooltip:SetUnitDebuff(unit, i)
                        debuffName = RinseScanTooltipTextLeft1:GetText() or ""
                    end
                    if debuffName and SnareDebuffs[debuffName] then
                        debuffType = L["Snare"]
                    end
                    -- If unit is a pet and PETS is disabled, only save priority debuffs
                    -- Check if debuff can be removed and respect abolish setting
                    if ( not (string.find(unit, "pet", 1, true) and not RINSE_CONFIG.PETS and not PriorityDebuffs[debuffName])
                        and UsableSpells[debuffType] and (RINSE_CONFIG.IGNORE_ABOLISH or not HasAbolish(unit, debuffType)) )
                    then
                        debuffCount = debuffCount + 1
                        if not Debuffs[debuffCount] then Debuffs[debuffCount] = {} end
                        local _, class = UnitClass(unit)
                        local d = Debuffs[debuffCount]
                        d.name = debuffName or ""
                        d.type = debuffType or ""
                        d.texture = texture or ""
                        d.stacks = applications or 0
                        d.unit = unit
                        d.unitName = unitName
                        d.unitClass = class or ""
                        d.debuffIndex = i
                        d.weight = 1
                        if PriorityDebuffs[debuffName] then d.weight = d.weight + 1 end
                        d.userPrio = 99
                        if UnitIsUnit(unit, "target") then
                            d.userPrio = 0
                        else
                            for userUnit, prio in pairs(UserUnits) do
                                if UnitIsUnit(userUnit, unit) then d.userPrio = prio; break end
                            end
                        end
                    end
                end
            end
        end
        lastDebuffCount = debuffCount

        table.sort(Debuffs, order)

        for i = 1, BUTTONS_MAX do
            local button = _G["RinseFrameDebuff"..i]
            button:Hide()
            button.unit = nil
        end

        -- Process debuffs: blacklist, priority, shadowform, and filter logic
        -- Only iterate up to debuffIndex (actual found debuffs), cache table lookups
        local buttonIndex = 1
        for i = 1, debuffCount do
            local d = Debuffs[i]
            local dName, dType, dUnit, dUnitClass = d.name, d.type, d.unit, d.unitClass
            -- Check if this debuff is blacklisted
            if Blacklist[dName] then
                -- Hide all debuffs of same type on same unit
                for j = 1, debuffCount do
                    local d2 = Debuffs[j]
                    if UnitIsUnit(d2.unit, dUnit) and (d2.type == dType or UsableSpells[dType] == L["Cleanse"]) then
                        d2.hidden = true
                    end
                end
            end
            -- Shadowform: hide diseases
            if RINSE_CONFIG.SHADOWFORM and dType == L["Disease"] and HasShadowform() then
                d.hidden = true
            end
            -- Player filter (includes class-specific filters)
            local classFilter = ClassFilter[dUnitClass]
            if Filter[dName] or Filter[dType] or (classFilter and classFilter[dName]) then
                d.hidden = true
            end
            if not d.hidden then
                -- Don't show other debuffs from the same unit
                for _, d2 in pairs(Debuffs) do
                    if UnitIsUnit(d2.unit, dUnit) and d ~= d2 then d2.hidden = true end
                end
                if d.weight > 0 and buttonIndex <= BUTTONS_MAX then
                    local dUnitName = d.unitName
                    local button = _G["RinseFrameDebuff"..buttonIndex]
                    button.Icon:SetTexture(d.texture)
                    button.DebuffName:SetText(dName)
                    button.PlayerName:SetText(ClassColors[dUnitClass]..dUnitName.."|r")
                    button.Count:SetText(d.stacks)
                    local color = DebuffColors[dType]
                    button.Border:SetVertexColor(color.r, color.g, color.b)
                    button.unit = dUnit
                    button.unitName = dUnitName
                    button.unitClass = dUnitClass
                    button.type = dType
                    button.debuffIndex = d.debuffIndex
                    button:Show()
                    if buttonIndex == 1 and playNoticeSound then
                        if RINSE_CONFIG.SOUND then PlaySoundFile(Sounds.notice) end
                        playNoticeSound = false
                    end
                    if PriorityDebuffs[dName] then
                        button.Priority:Show()
                    else
                        button.Priority:Hide()
                    end
                    button:SetAlpha(CanCast(dUnit, UsableSpells[dType]) and 1 or 0.5)
                    buttonIndex = buttonIndex + 1
                end
            end
        end
        if not RinseFrameDebuff1:IsShown() then
            playNoticeSound = true
        end
    else
        -- Auras ddint change, just update range/los indication
        for i = 1, BUTTONS_MAX do
            local button = _G["RinseFrameDebuff"..i]
            if not button:IsShown() then break end
            button:SetAlpha(CanCast(button.unit, UsableSpells[button.type]) and 1 or 0.5)
        end
    end
end

function Rinse_Cleanse(button, attemptedCast)
    button = button or this
    if not button.unit or button.unit == "" then
        return false
    end
    local spellName = UsableSpells[button.type]
    local spellSlot = UsableSpellBookIDs[spellName]
    -- Check if on gcd
    -- If gcd active this will return 1.5 for all the relevant spells
    local _, duration = GetSpellCooldown(spellSlot, bookType)
    local onGcd = duration > 0
    -- Allow attempting 1 spell even if gcd active so that it can be queued
    if attemptedCast and onGcd then
        -- Otherwise don't bother trying to cast
        return false
    end
    if not CanCast(button.unit, spellName) then
        if not Timers.error.count then
            if RINSE_CONFIG.SOUND then PlaySoundFile(Sounds.error) end
            Timers.error.count = 0.1
        end
        return false
    end
    local castingInterruptableSpell = true
    -- If nampower available, check if we are actually casting something
    -- to avoid needlessly calling SpellStopCasting and wiping spell queue
    if GetCurrentCastingInfo then
        local _, _, _, casting, channeling = GetCurrentCastingInfo()
        if casting == 0 and channeling == 0 then
            castingInterruptableSpell = false
        end
    elseif C_Spell then
        local cast, _, _, _, _, _, _, notInterruptibleCast = C_Spell.CastingInfo()
        local channel, _, _, _, _, _, notInterruptibleChannel = C_Spell.ChannelInfo()
        castingInterruptableSpell = (cast and not notInterruptibleCast) or (channel and not notInterruptibleChannel)
    end
    if castingInterruptableSpell and not Timers.stopCast.count then
        SpellStopCasting()
        Timers.stopCast.count = 0.2
    end
    if not onGcd then
        ChatMessage(DebuffColors[button.type].hex..button.DebuffName:GetText().."|r - "..ClassColors[button.unitClass]..UnitName(button.unit).."|r")
    else
        -- Save spellId, spellName and target so we can output chat message if it was queued
        lastSpellName = spellName
        lastButton = button
    end
    if SUPERWOW_VERSION or GetNampowerVersion then
        CastSpellByName(spellName, button.unit)
    elseif C_Spell then
        C_Spell.CastAtUnit(spellName, button.unit)
    else
        local selfcast = GetCVar("autoselfcast")
        local assist = GetCVar("assistattack")
        local lastTarget = UnitName("target")
        local restore = lastTarget and autoattack and autoattack == lastTarget
        SetCVar("autoselfcast", 0)
        SetCVar("assistattack", 1)
        TargetUnit(button.unit)
        if UnitExists("target") and UnitIsUnit("target", button.unit) then
            CastSpellByName(spellName)
            if lastTarget ~= UnitName("target") then
                -- If we didnt have target or it was someone else
                TargetLastTarget()
            end
        end
        if restore and lastTarget and UnitExists("target") and UnitName("target") == lastTarget then
            AssistUnit("player")
        end
        SetCVar("autoselfcast", selfcast)
        SetCVar("assistattack", assist)
    end
    return true
end

setmetatable(Rinse, { __call = function()
    local attemptedCast = false
    for i = 1, BUTTONS_MAX do
        if Rinse_Cleanse(_G["RinseFrameDebuff"..i], attemptedCast) then
            attemptedCast = true
        end
    end
end })

SLASH_RINSE1 = "/rinse"
SlashCmdList["RINSE"] = function(cmd)
    if cmd == "" then
        Rinse()
    elseif cmd == "options" then
        RinseFrameOptions_OnClick()
    elseif cmd == "skip" then
        RinseFrameSkipList_OnClick()
    elseif cmd == "prio" then
        RinseFramePrioList_OnClick()
    elseif cmd == "versions" then
        Rinse_StartVersionsCheck()
    else
        DEFAULT_CHAT_FRAME:AddMessage(BLUE.."[Rinse]|r "..L["Unknown command. Use /rinse, /rinse options, /rinse skip, /rinse prio or /rinse versions."])
    end
end

function RinseOptionsFrame_OnLoad()
    for i = 1, OptionsScrollMaxButtons do
        local button = CreateFrame("Button", "RinseOptionsBlacklistButton"..i, RinseOptionsFrame, "RinseOptionsButtonTemplate")
        button:SetID(i)
        button:SetPoint("TOPLEFT", RinseOptionsFrameBlacklistScrollFrame, 0, -16 * (i-1))
        button.scrollFrame = RinseOptionsFrameBlacklistScrollFrame
    end
    for i = 1, OptionsScrollMaxButtons do
        local button = CreateFrame("Button", "RinseOptionsClassFilterButton"..i, RinseOptionsFrame, "RinseOptionsButtonTemplate")
        button:SetID(i)
        button:SetPoint("TOPLEFT", RinseOptionsFrameClassFilterScrollFrame, 0, -16 * (i-1))
        button.scrollFrame = RinseOptionsFrameClassFilterScrollFrame
    end
    for i = 1, OptionsScrollMaxButtons do
        local button = CreateFrame("Button", "RinseOptionsFilterButton"..i, RinseOptionsFrame, "RinseOptionsButtonTemplate")
        button:SetID(i)
        button:SetPoint("TOPLEFT", RinseOptionsFrameFilterScrollFrame, 0, -16 * (i-1))
        button.scrollFrame = RinseOptionsFrameFilterScrollFrame
    end
end

function RinseOptionsFrameBlacklistScrollFrame_Update()
    local frame = RinseOptionsFrameBlacklistScrollFrame or this
    local offset = FauxScrollFrame_GetOffset(frame)
    local arrayIndex = 1
    if not frame.array then frame.array = {} end
    wipe(frame.array)
    for spellName in pairs(Blacklist) do
        if spellName ~= "" and Blacklist[spellName] then table.insert(frame.array, spellName) end
    end
    table.sort(frame.array)
    local numEntries = table.getn(frame.array)
    FauxScrollFrame_Update(frame, numEntries, OptionsScrollMaxButtons, 16)
    for i = 1, OptionsScrollMaxButtons do
        local button = _G["RinseOptionsBlacklistButton"..i]
        local buttonText = _G["RinseOptionsBlacklistButton"..i.."Text"]
        arrayIndex = i + offset
        if frame.array[arrayIndex] then
            buttonText:SetText(frame.array[arrayIndex])
            button:SetID(arrayIndex)
            button:Show()
        else
            button:Hide()
        end
    end
end

function RinseOptionsFrameResetBlacklist_OnClick()
    wipe(Blacklist)
    wipe(RINSE_CHAR_CONFIG.BLACKLIST)
    for k, v in pairs(DefaultBlacklist) do
        Blacklist[k] = v
        if k == L["Wyvern Sting"] then
            RINSE_CHAR_CONFIG.BLACKLIST[k] = true
            RinseOptionsFrameWyvernSting:SetChecked(false)
        end
        if k == L["Mutating Injection"] then
            RINSE_CHAR_CONFIG.BLACKLIST[k] = true
            RinseOptionsFrameMutatingInjection:SetChecked(false)
        end
    end
    RinseOptionsFrameBlacklistScrollFrame:SetVerticalScroll(0)
    RinseOptionsFrameBlacklistScrollFrame_Update()
end

function RinseOptionsFrameClassFilterScrollFrame_Update()
    local frame = RinseOptionsFrameClassFilterScrollFrame or this
    local offset = FauxScrollFrame_GetOffset(frame)
    local arrayIndex = 1
    if not frame.array then frame.array = {} end
    wipe(frame.array)
    for spellName in pairs(ClassFilter[selectedClass]) do
        if spellName ~= "" and ClassFilter[selectedClass][spellName] then table.insert(frame.array, spellName) end
    end
    table.sort(frame.array)
    local numEntries = table.getn(frame.array)
    FauxScrollFrame_Update(frame, numEntries, OptionsScrollMaxButtons, 16)
    for i = 1, OptionsScrollMaxButtons do
        local button = _G["RinseOptionsClassFilterButton"..i]
        local buttonText = _G["RinseOptionsClassFilterButton"..i.."Text"]
        arrayIndex = i + offset
        if frame.array[arrayIndex] then
            buttonText:SetText(frame.array[arrayIndex])
            button:SetID(arrayIndex)
            button:Show()
        else
            button:Hide()
        end
    end
end

local info2 = {}
info2.textHeight = 12
info2.notCheckable = 1
info2.checked = nil
info2.hasArrow = nil
info2.func = function()
    selectedClass = this.value
    local text = this:GetText()
    RinseOptionsFrameSelectClassText:SetText(text)
    RinseOptionsFrameClassFilterScrollFrame_Update()
end

local function BlacklistClassMenu()
    if UIDROPDOWNMENU_MENU_LEVEL == 1 then
        info2.text = ClassColors["WARRIOR"]..L["Warriors"]
        info2.value = "WARRIOR"
        UIDropDownMenu_AddButton(info2)
        info2.text = ClassColors["DRUID"]..L["Druids"]
        info2.value = "DRUID"
        UIDropDownMenu_AddButton(info2)
        info2.text = ClassColors["PALADIN"]..L["Paladins"]
        info2.value = "PALADIN"
        UIDropDownMenu_AddButton(info2)
        info2.text = ClassColors["WARLOCK"]..L["Warlocks"]
        info2.value = "WARLOCK"
        UIDropDownMenu_AddButton(info2)
        info2.text = ClassColors["MAGE"]..L["Mages"]
        info2.value = "MAGE"
        UIDropDownMenu_AddButton(info2)
        info2.text = ClassColors["PRIEST"]..L["Priests"]
        info2.value = "PRIEST"
        UIDropDownMenu_AddButton(info2)
        info2.text = ClassColors["ROGUE"]..L["Rogues"]
        info2.value = "ROGUE"
        UIDropDownMenu_AddButton(info2)
        info2.text = ClassColors["HUNTER"]..L["Hunters"]
        info2.value = "HUNTER"
        UIDropDownMenu_AddButton(info2)
        info2.text = ClassColors["SHAMAN"]..L["Shamans"]
        info2.value = "SHAMAN"
        UIDropDownMenu_AddButton(info2)
    end
end

function RinseOptionsFrameSelectClass_OnClick()
    UIDropDownMenu_Initialize(RinseClassesDropDown, BlacklistClassMenu, "MENU")
    ToggleDropDownMenu(1, "RinseOptions", RinseClassesDropDown, this, 0, 0)
    PlaySound("igMainMenuOptionCheckBoxOn")
end

function RinseOptionsFrameResetClassFilter_OnClick()
    wipe(RINSE_CHAR_CONFIG.FILTER_CLASS[selectedClass])
    wipe(ClassFilter[selectedClass])
    for k, v in pairs(DefaultClassFilter[selectedClass]) do
        ClassFilter[selectedClass][k] = v
    end
    RinseOptionsFrameClassFilterScrollFrame:SetVerticalScroll(0)
    RinseOptionsFrameClassFilterScrollFrame_Update()
end

StaticPopupDialogs["RINSE_ADD_TO_BLACKLIST"] = {
    text = L["Enter exact name of a debuff:"],
    button1 = OKAY,
    button2 = CANCEL,
    hasEditBox = 1,
    maxLetters = 90,
    OnAccept = function()
        local dialog = this:GetParent()
        local text = _G[dialog:GetName().."EditBox"]:GetText()
        if dialog.data == 1 then
            RINSE_CHAR_CONFIG.BLACKLIST[text] = true
            RinseOptionsFrameWyvernSting:SetChecked(not RINSE_CHAR_CONFIG.BLACKLIST[L["Wyvern Sting"]])
            RinseOptionsFrameMutatingInjection:SetChecked(not RINSE_CHAR_CONFIG.BLACKLIST[L["Mutating Injection"]])
            UpdateBlacklist()
        elseif dialog.data == 2 then
            RINSE_CHAR_CONFIG.FILTER_CLASS[selectedClass][text] = true
            UpdateFilter()
        end
        RinseOptionsFrameBlacklistScrollFrame_Update()
        RinseOptionsFrameClassFilterScrollFrame_Update()
    end,
    EditBoxOnEnterPressed = function()
        StaticPopupDialogs[this:GetParent().which].OnAccept()
        this:GetParent():Hide()
    end,
    EditBoxOnEscapePressed = function()
        this:GetParent():Hide()
    end,
    OnShow = function()
        _G[this:GetName().."EditBox"]:SetFocus()
    end,
    OnHide = function()
        _G[this:GetName().."EditBox"]:SetText("")
    end,
    timeout = 0,
    exclusive = 1,
    hideOnEscape = 1
}

function RinseOptionsScrollFrameButton_OnClick()
    local text = this:GetText()
    if not text or text == "" or (DebuffColors[text] and Spells[playerClass][text] == nil) then
        return
    end
    local scrollFrame = this.scrollFrame
    if scrollFrame == RinseOptionsFrameBlacklistScrollFrame then
        if text == L["Wyvern Sting"] then
            if RinseOptionsFrameWyvernSting:IsEnabled() == 1 then
                RinseOptionsFrameWyvernSting:Click()
                return
            end
        end
        if text == L["Mutating Injection"] then
            if RinseOptionsFrameMutatingInjection:IsEnabled() == 1 then
                RinseOptionsFrameMutatingInjection:Click()
                return
            end
        end
        RINSE_CHAR_CONFIG.BLACKLIST[text] = false
        UpdateBlacklist()
    elseif scrollFrame == RinseOptionsFrameClassFilterScrollFrame then
        RINSE_CHAR_CONFIG.FILTER_CLASS[selectedClass][text] = false
        UpdateFilter()
    elseif scrollFrame == RinseOptionsFrameFilterScrollFrame then
        RINSE_CHAR_CONFIG.FILTER[text] = false
        RinseOptionsFrameFilterMagic:SetChecked(not RINSE_CHAR_CONFIG.FILTER[L["Magic"]])
        RinseOptionsFrameFilterSnare:SetChecked(not RINSE_CHAR_CONFIG.FILTER[L["Snare"]])
        RinseOptionsFrameFilterDisease:SetChecked(not RINSE_CHAR_CONFIG.FILTER[L["Disease"]])
        RinseOptionsFrameFilterPoison:SetChecked(not RINSE_CHAR_CONFIG.FILTER[L["Poison"]])
        RinseOptionsFrameFilterCurse:SetChecked(not RINSE_CHAR_CONFIG.FILTER[L["Curse"]])
        UpdateFilter()
    end
    scrollFrame.Update()
    PlaySound("igMainMenuOptionCheckBoxOn")
end

function RinseOptionsFrameFilterScrollFrame_Update()
    local frame = RinseOptionsFrameFilterScrollFrame or this
    local offset = FauxScrollFrame_GetOffset(frame)
    local arrayIndex = 1
    if not frame.array then frame.array = {} end
    wipe(frame.array)
    for spellName in pairs(Filter) do
        if spellName ~= "" and Filter[spellName] then
            if DebuffColors[spellName] then
                table.insert(frame.array, 1, spellName)
            else
                table.insert(frame.array, spellName)
            end
        end
    end
    local numEntries = table.getn(frame.array)
    FauxScrollFrame_Update(frame, numEntries, OptionsScrollMaxButtons, 16)
    for i = 1, OptionsScrollMaxButtons do
        local button = _G["RinseOptionsFilterButton"..i]
        local buttonText = _G["RinseOptionsFilterButton"..i.."Text"]
        arrayIndex = i + offset
        if frame.array[arrayIndex] then
            buttonText:SetText(frame.array[arrayIndex])
            button:SetID(arrayIndex)
            button:Show()
        else
            button:Hide()
        end
    end
end

function RinseOptionsFrameResetFilter_OnClick()
    wipe(RINSE_CHAR_CONFIG.FILTER)
    wipe(Filter)
    for k, v in pairs(DefaultFilter) do
        Filter[k] = v
        RINSE_CHAR_CONFIG.FILTER[k] = v
    end
    RinseOptionsFrameFilterMagic:SetChecked(not RINSE_CHAR_CONFIG.FILTER[L["Magic"]])
    RinseOptionsFrameFilterSnare:SetChecked(not RINSE_CHAR_CONFIG.FILTER[L["Snare"]])
    RinseOptionsFrameFilterDisease:SetChecked(not RINSE_CHAR_CONFIG.FILTER[L["Disease"]])
    RinseOptionsFrameFilterPoison:SetChecked(not RINSE_CHAR_CONFIG.FILTER[L["Poison"]])
    RinseOptionsFrameFilterCurse:SetChecked(not RINSE_CHAR_CONFIG.FILTER[L["Curse"]])
    UpdateSpells()
    RinseOptionsFrameFilterScrollFrame:SetVerticalScroll(0)
    RinseOptionsFrameFilterScrollFrame_Update()
end

StaticPopupDialogs["RINSE_ADD_TO_FILTER"] = {
    text = L["Enter exact name of a debuff (or a type):"],
    button1 = OKAY,
    button2 = CANCEL,
    hasEditBox = 1,
    maxLetters = 90,
    OnAccept = function()
        local text = _G[this:GetParent():GetName().."EditBox"]:GetText()
        RINSE_CHAR_CONFIG.FILTER[text] = true
        RinseOptionsFrameFilterMagic:SetChecked(not RINSE_CHAR_CONFIG.FILTER[L["Magic"]])
        RinseOptionsFrameFilterSnare:SetChecked(not RINSE_CHAR_CONFIG.FILTER[L["Snare"]])
        RinseOptionsFrameFilterDisease:SetChecked(not RINSE_CHAR_CONFIG.FILTER[L["Disease"]])
        RinseOptionsFrameFilterPoison:SetChecked(not RINSE_CHAR_CONFIG.FILTER[L["Poison"]])
        RinseOptionsFrameFilterCurse:SetChecked(not RINSE_CHAR_CONFIG.FILTER[L["Curse"]])
        UpdateFilter()
        RinseOptionsFrameFilterScrollFrame_Update()
    end,
    EditBoxOnEnterPressed = function()
        StaticPopupDialogs[this:GetParent().which].OnAccept()
        this:GetParent():Hide()
    end,
    EditBoxOnEscapePressed = function()
        this:GetParent():Hide()
    end,
    OnShow = function()
        _G[this:GetName().."EditBox"]:SetFocus()
    end,
    OnHide = function()
        _G[this:GetName().."EditBox"]:SetText("")
    end,
    timeout = 0,
    exclusive = 1,
    hideOnEscape = 1
}

function Rinse_StartVersionsCheck()
    if Timers.versionsCheck.count then
        DEFAULT_CHAT_FRAME:AddMessage(BLUE.."[Rinse]|r "..L["Version check is already in progress."])
        return
    end
    local channel
    if GetNumRaidMembers() > 0 then
        channel = "RAID"
    elseif GetNumPartyMembers() > 0 then
        channel = "PARTY"
    end
    if channel then
        SendAddonMessage("Rinse", "REPORT_ADDON_VERSION", channel)
        DEFAULT_CHAT_FRAME:AddMessage(BLUE.."[Rinse]|r "..L["Version check start..."])
        Timers.versionsCheck.count = 3
    else
        DEFAULT_CHAT_FRAME:AddMessage(BLUE.."[Rinse]|r "..L["You are not in a raid or party."])
    end
end

local function OutputVersionsCheckResults()
    local printf = function(fmt, ...)
        DEFAULT_CHAT_FRAME:AddMessage(string.format(tostring(fmt), unpack(arg)))
    end
    if not AddonVersions then AddonVersions = {} end
    local myVersionString = GetAddOnMetadata("Rinse", "Version")
    local myVersionValue = tonumber((string.gsub(myVersionString, "%.", "0")))
    local myName = UnitName("player")
    table.insert(AddonVersions, { name = myName, vString = string.format("%s(%s)", myName, myVersionString), vValue = myVersionValue })
    if GetNumRaidMembers() > 0 then
        for i = 1, 40 do
            local name = UnitName("raid"..i)
            if name and not contains(AddonVersions, name) then
                table.insert(AddonVersions, { name = name, vString = name, vValue = 0 })
            end
        end
    elseif GetNumPartyMembers() > 0 then
        for i = 1, 4 do
            local name = UnitName("party"..i)
            if name and not contains(AddonVersions, name) then
                table.insert(AddonVersions, { name = name, vString = name, vValue = 0 })
            end
        end
    end
    table.sort(AddonVersions, function(a, b) return a.vValue > b.vValue end)
    local size = table.getn(AddonVersions)
    local higher = {}
    local same = {}
    local older = {}
    local nothing = {}
    for i = 1, size do
        local value = AddonVersions[i].vValue
        local str = AddonVersions[i].vString
        if value > myVersionValue then
            table.insert(higher, str)
        elseif value == myVersionValue then
            table.insert(same, str)
        elseif value == 0 then
            table.insert(nothing, str)
        elseif value < myVersionValue then
            table.insert(older, str)
        end
    end
    printf(BLUE.."[Rinse]|r "..L["Version check results:"])
    if next(higher) then printf("Higher version: %s", table.concat(higher,", ")) end
    if next(same) then printf("Same version: %s", table.concat(same,", ")) end
    if next(older) then printf("Older version: %s", table.concat(older,", ")) end
    if next(nothing) then printf("No addon: %s", table.concat(nothing,", ")) end
    AddonVersions = nil
end

Timers.versionsCheck.callback = OutputVersionsCheckResults

function Rinse_DebuffButton_OnLoad(self)
    self:RegisterForClicks("LeftButtonDown")
    local name = self:GetName()
    self.Icon = _G[name.."Icon"]
    self.DebuffName = _G[name.."Name"]
    self.PlayerName = _G[name.."Player"]
    self.Count = _G[name.."Count"]
    self.Border = _G[name.."Border"]
    self.Priority = _G[name.."Priority"]
end
