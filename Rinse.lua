local _, playerClass = UnitClass("player")
local superwow = SUPERWOW_VERSION
local unitxp = pcall(UnitXP, "nop")
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
local CheckInteractDistance = CheckInteractDistance
local updateInterval = 0.1
local timeElapsed = 0
local noticeSound = "Sound\\Doodad\\BellTollTribal.wav"
local errorSound = "Sound\\Interface\\Error.wav"
local playNoticeSound = true
local errorCooldown = 0
local stopCastCooldown = 0
local prioTimer = 0
local needUpdatePrio = false

-- Bindings
BINDING_HEADER_RINSE_HEADER = "Rinse"
BINDING_NAME_RINSE = "Run Rinse"
BINDING_NAME_RINSE_TOGGLE_OPTIONS = "Toggle Options"
BINDING_NAME_RINSE_TOGGLE_PRIO = "Toggle Prio List"
BINDING_NAME_RINSE_TOGGLE_SKIP = "Toggle Skip List"

local Backdrop = {
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true,
    tileSize = 16,
    edgeSize = 16,
    insets = { left = 5, right = 5, top = 5, bottom = 5 },
}

-- Frames that should scale together
local Frames = {
    "RinseFrame",
    "RinsePrioListFrame",
    "RinseSkipListFrame",
}

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
DebuffColor["none"]    = { r = 0.8, g = 0.0, b = 0.0, hex = "|cffCC0000" }
DebuffColor["Magic"]   = { r = 0.2, g = 0.6, b = 1.0, hex = "|cff3399FF" }
DebuffColor["Curse"]   = { r = 0.6, g = 0.0, b = 1.0, hex = "|cff9900FF" }
DebuffColor["Disease"] = { r = 0.6, g = 0.4, b = 0.0, hex = "|cff996600" }
DebuffColor["Poison"]  = { r = 0.0, g = 0.6, b = 0.0, hex = "|cff009900" }

local BLUE = DebuffColor["Magic"].hex

-- Spells that remove stuff, for each class
local Spells = {}
Spells["PALADIN"] = { Magic = {"Cleanse"}, Poison = {"Cleanse", "Purify"}, Disease = {"Cleanse", "Purify"} }
Spells["DRUID"]   = { Curse = {"Remove Curse"}, Poison = {"Abolish Poison", "Cure Poison"} }
Spells["PRIEST"]  = { Magic = {"Dispel Magic"}, Disease = {"Abolish Disease", "Cure Disease"} }
Spells["SHAMAN"]  = { Poison = {"Cure Poison"}, Disease = {"Cure Disease"} }
Spells["MAGE"]    = { Curse = {"Remove Lesser Curse"} }
Spells["WARLOCK"] = { Magic = {"Devour Magic"} }

-- Spells that we have
-- SpellNameToRemove[debuffType] = "spellName"
local SpellNameToRemove = {}
-- SpellSlotForName[spellName] = spellSlot
local SpellSlotForName = {}

local lastSpellName = nil
local lastButton = nil

-- Number of buttons shown, can be overridden by saved variables
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

--Spells that will prevent a unit from being decursed
local Blocklist = {
    ["Unstable Mana"] = true,
    ["Dread of Outland"] = true,
}

-- Spells to ignore always
local Blacklist = {}
Blacklist["Curse"] = {}
Blacklist["Magic"] = {}
Blacklist["Disease"] = {}
Blacklist["Poison"] = {}
----------------------------------------------------
Blacklist["Curse"]["Curse of Recklessness"] = true
Blacklist["Curse"]["Delusions of Jin'do"] = true
Blacklist["Curse"]["Dread of Outland"] = true
Blacklist["Curse"]["Curse of Legion"] = true
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
Blacklist["Magic"]["Phase Shifted"] = true
Blacklist["Magic"]["Unstable Mana"] = true
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
ClassBlacklist["WARLOCK"] = {}
ClassBlacklist["DRUID"] = {}
ClassBlacklist["PALADIN"] = {}
ClassBlacklist["MAGE"] = {}
ClassBlacklist["PRIEST"] = {}
ClassBlacklist["HUNTER"] = {}
ClassBlacklist["SHAMAN"] = {}
----------------------------------------------------
ClassBlacklist["WARRIOR"]["Ancient Hysteria"] = true
ClassBlacklist["WARRIOR"]["Ignite Mana"] = true
ClassBlacklist["WARRIOR"]["Tainted Mind"] = true
ClassBlacklist["WARRIOR"]["Moroes Curse"] = true
ClassBlacklist["WARRIOR"]["Curse of Manascale"] = true
----------------------------------------------------
ClassBlacklist["ROGUE"]["Silence"] = true
ClassBlacklist["ROGUE"]["Ancient Hysteria"] = true
ClassBlacklist["ROGUE"]["Ignite Mana"] = true
ClassBlacklist["ROGUE"]["Tainted Mind"] = true
ClassBlacklist["ROGUE"]["Smoke Bomb"] = true
ClassBlacklist["ROGUE"]["Screams of the Past"] = true
ClassBlacklist["ROGUE"]["Moroes Curse"] = true
ClassBlacklist["ROGUE"]["Curse of Manascale"] = true
----------------------------------------------------
ClassBlacklist["WARLOCK"]["Rift Entanglement"] = true

local function wipe(array)
    if type(array) ~= "table" then
        return
    end
    for i = getn(array), 1, -1 do
        tremove(array, i)
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

local function ChatMessage(msg)
    if RINSE_CONFIG.PRINT then
        if RINSE_CONFIG.MSBT and MikSBT then
            MikSBT.DisplayMessage(msg, MikSBT.DISPLAYTYPE_NOTIFICATION, false, 255, 255, 255)
        else
            ChatFrame1:AddMessage(BLUE.."[Rinse]|r "..(tostring(msg)))
        end
    end
end

local function debug(msg)
    ChatFrame1:AddMessage(BLUE.."[Rinse]["..format("%.3f",GetTime()).."]|r"..(tostring(msg)))
end

local function playsound(file)
    if RINSE_CONFIG.SOUND then
        PlaySoundFile(file)
    end
end

local function NameToUnitID(name)
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
end

local function HasAbolish(unit, debuffType)
    if not UnitExists(unit) or not debuffType then
        return
    end
    if not SpellNameToRemove[debuffType] then
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

local function InRange(unit, spell)
    if unit and UnitIsFriend(unit, "player") and not UnitCanAttack("player", unit) then
        if spell and IsSpellInRange then
            local result = IsSpellInRange(spell, unit)
            if result == 1 then
                return true
            elseif result == 0 then
                return false
            end
            -- Ignore result == -1
        end
        if unitxp and UnitIsVisible(unit) then
            -- Accounts for true reach. A tauren can dispell a male tauren at 38y!
            return UnitXP("distanceBetween", "player", unit) < 30
        elseif superwow then
            local myX, myY, myZ = UnitPosition("player")
            local uX, uY, uZ = UnitPosition(unit)
            local dx, dy, dz = uX - myX, uY - myY, uZ - myZ
            -- sqrt(1089) == 33, smallest max dispell range not accounting for true melee reach
            return ((dx * dx) + (dy * dy) + (dz * dz)) <= 1089
        else
            -- Not as accurate
            return CheckInteractDistance(unit, 4)
        end
    end
end

local Seen = {}

local function UpdatePrio()
    -- Reset Prio to default
    wipe(Prio)
    for i = 1, getn(DefaultPrio) do
        tinsert(Prio, DefaultPrio[i])
    end
    if RINSE_CONFIG.PRIO_ARRAY[1] then
        -- Copy from user defined PRIO_ARRAY into internal Prio
        for i = 1, getn(RINSE_CONFIG.PRIO_ARRAY) do
            local unit = NameToUnitID(RINSE_CONFIG.PRIO_ARRAY[i].name)
            if unit and Prio[i] ~= unit then
                tinsert(Prio, i, unit)
            end
        end
    end
    -- Get rid of duplicates and UnitIDs that we can't match to names in our raid/party
    wipe(Seen)
    for i = 1, getn(Prio) do
        local name = UnitName(Prio[i])
        if not name or arrcontains(Seen, name) then
            -- Don't delete yet
            Prio[i] = false
        elseif name then
            tinsert(Seen, name)
        end
    end
    for i = getn(Prio), 1, -1 do
        if Prio[i] == false then
            tremove(Prio, i)
        end
    end
    -- Randomize everything that is not in PRIO_ARRAY
    if not RinseFrameDebuff1:IsShown() then
        local startIndex = 2
        local endIndex = getn(Prio)
        if RINSE_CONFIG.PRIO_ARRAY[1] then
            -- PRIO_ARRAY can contain names that are not in our raid/party
            -- I assume the last name in PRIO_ARRAY that we can match to some UnitID is the end of PRIO_ARRAY
            -- since we got rid of "empty" UnitIDs on previous step
            local lastValidInPrio = 0
            for i = getn(RINSE_CONFIG.PRIO_ARRAY), 1, -1 do
                if NameToUnitID(RINSE_CONFIG.PRIO_ARRAY[i].name) then
                    lastValidInPrio = i
                    break
                end
            end
            startIndex = lastValidInPrio + 1
        end
        for a = startIndex, endIndex do
            local temp = Prio[a]
            local b = random(startIndex, endIndex)
            if Prio[a] and Prio[b] then
                Prio[a] = Prio[b]
                Prio[b] = temp
            end
        end
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
                local unit = NameToUnitID(name)
                if name and unit and subgroup == this.value then
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
                local unit = NameToUnitID(name)
                if name and unit and classFileName == this.value then
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
        info.text = ClassColors["WARRIOR"].."Warriors"
        info.value = "WARRIOR"
        UIDropDownMenu_AddButton(info)
        info.text = ClassColors["DRUID"].."Druids"
        info.value = "DRUID"
        UIDropDownMenu_AddButton(info)
        info.text = ClassColors["PALADIN"].."Paladins"
        info.value = "PALADIN"
        UIDropDownMenu_AddButton(info)
        info.text = ClassColors["WARLOCK"].."Warlocks"
        info.value = "WARLOCK"
        UIDropDownMenu_AddButton(info)
        info.text = ClassColors["MAGE"].."Mages"
        info.value = "MAGE"
        UIDropDownMenu_AddButton(info)
        info.text = ClassColors["PRIEST"].."Priests"
        info.value = "PRIEST"
        UIDropDownMenu_AddButton(info)
        info.text = ClassColors["ROGUE"].."Rogues"
        info.value = "ROGUE"
        UIDropDownMenu_AddButton(info)
        info.text = ClassColors["HUNTER"].."Hunters"
        info.value = "HUNTER"
        UIDropDownMenu_AddButton(info)
        info.text = ClassColors["SHAMAN"].."Shamans"
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

function Rinse_ClearButton_OnClick()
    if this:GetParent() == RinseSkipListFrame then
        wipe(RINSE_CONFIG.SKIP_ARRAY)
        RinseSkipListScrollFrame_Update()
    elseif this:GetParent() == RinsePrioListFrame then
        wipe(RINSE_CONFIG.PRIO_ARRAY)
        RinsePrioListScrollFrame_Update()
    end
end

local bookType = BOOKTYPE_SPELL
if playerClass == "WARLOCK" then
    bookType = BOOKTYPE_PET
end

local function UpdateSpells()
    if not Spells[playerClass] then
        return
    end
    local found = false
    for tab = 1, GetNumSpellTabs() do
        local _, _, offset, numSpells = GetSpellTabInfo(tab)
        for s = offset + 1, offset + numSpells do
            local spell = GetSpellName(s, bookType)
            if spell then
                for dispelType, v in pairs(Spells[playerClass]) do
                    if v[1] == spell then
                        SpellNameToRemove[dispelType] = spell
                        SpellSlotForName[spell] = s
                        found = true
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
                        SpellNameToRemove[dispelType] = spell
                        SpellSlotForName[spell] = s
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

local function DisableCheckBox(checkBox)
    OptionsFrame_DisableCheckBox(checkBox)
    getglobal(checkBox:GetName().."TooltipPreserve"):Show()
end

local function EnableCheckBox(checkBox)
    OptionsFrame_EnableCheckBox(checkBox)
    getglobal(checkBox:GetName().."TooltipPreserve"):Hide()
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
        RinseFrame:SetBackdrop(Backdrop)
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
    for _, frame in pairs(Frames) do
        getglobal(frame):SetScale(RINSE_CONFIG.SCALE)
    end
end

function RinseOptionsFrameScaleSLider_OnValueChanged()
    local scale = tonumber(format("%.2f", this:GetValue()))
    RINSE_CONFIG.SCALE = scale
    RinseFrame:SetScale(scale)
    RinseDebuffsFrame:SetScale(scale)
    getglobal(this:GetName().."Text"):SetText("Scale ("..scale..")")
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
            local frame = getglobal("RinseFrameDebuff"..i)
            if i == 1 then
                frame:ClearAllPoints()
                frame:SetPoint("TOP", RinseDebuffsFrame, "TOP", 0, 0)
            else
                local prevFrame = getglobal("RinseFrameDebuff"..(i - 1))
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
            local frame = getglobal("RinseFrameDebuff"..i)
            if i == 1 then
                frame:ClearAllPoints()
                frame:SetPoint("BOTTOM", RinseDebuffsFrame, "BOTTOM", 0, 0)
            else
                local prevFrame = getglobal("RinseFrameDebuff"..(i - 1))
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
            btn = getglobal("RinseFrameDebuff"..i)
            if not btn then
                btn = CreateFrame("Button", "RinseFrameDebuff"..i, RinseDebuffsFrame, "RinseDebuffButtonTemplate")
            end
            prevBtn = getglobal("RinseFrameDebuff"..(i - 1))
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
            getglobal("RinseFrameDebuff"..i):Hide()
        end
    end
    BUTTONS_MAX = num
end

function RinseOptionsFrameButtonsSlider_OnValueChanged()
    local numButtons = tonumber(format("%d", this:GetValue()))
    RINSE_CONFIG.BUTTONS = numButtons
    UpdateNumButtons()
    getglobal(this:GetName().."Text"):SetText("Debuffs shown ("..numButtons..")")
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
    if GetNampowerVersion then
        -- Announce queued decurses
        RinseFrame:RegisterEvent("SPELL_QUEUE_EVENT")
    end
end

local function GoodUnit(unit)
    if not (unit and UnitExists(unit) and UnitName(unit)) then
        return false
    end
    if UnitIsFriend(unit, "player") and UnitIsVisible(unit) and not UnitIsCharmed(unit) and not UnitCanAttack("player", unit) then
        if not arrcontains(RINSE_CONFIG.SKIP_ARRAY, UnitName(unit)) and (arrcontains(Prio, unit) or (unit == "target")) then
            return true
        end
    end
    return false
end

function RinseFrame_OnEvent()
    if event == "ADDON_LOADED" and arg1 == "Rinse" then
        RinseFrame:UnregisterEvent("ADDON_LOADED")
        RINSE_CONFIG = RINSE_CONFIG or {}
        RINSE_CONFIG.SKIP_ARRAY = RINSE_CONFIG.SKIP_ARRAY or {}
        RINSE_CONFIG.PRIO_ARRAY = RINSE_CONFIG.PRIO_ARRAY or {}
        RINSE_CONFIG.POSITION = RINSE_CONFIG.POSITION or {x = 0, y = 0}
        RINSE_CONFIG.SCALE = RINSE_CONFIG.SCALE or 0.85
        RINSE_CONFIG.OPACITY = RINSE_CONFIG.OPACITY or 1.0
        RINSE_CONFIG.WYVERN_STING = RINSE_CONFIG.WYVERN_STING == nil and false or RINSE_CONFIG.WYVERN_STING
        RINSE_CONFIG.MUTATING_INJECTION = RINSE_CONFIG.MUTATING_INJECTION == nil and false or RINSE_CONFIG.MUTATING_INJECTION
        RINSE_CONFIG.PRINT = RINSE_CONFIG.PRINT == nil and true or RINSE_CONFIG.PRINT
        RINSE_CONFIG.MSBT = RINSE_CONFIG.MSBT == nil and true or RINSE_CONFIG.MSBT
        RINSE_CONFIG.SOUND = RINSE_CONFIG.SOUND == nil and true or RINSE_CONFIG.SOUND
        RINSE_CONFIG.LOCK = RINSE_CONFIG.LOCK == nil and false or RINSE_CONFIG.LOCK
        RINSE_CONFIG.BACKDROP = RINSE_CONFIG.BACKDROP == nil and true or RINSE_CONFIG.BACKDROP
        RINSE_CONFIG.FLIP = RINSE_CONFIG.FLIP == nil and false or RINSE_CONFIG.FLIP
        RINSE_CONFIG.BUTTONS = RINSE_CONFIG.BUTTONS == nil and BUTTONS_MAX or RINSE_CONFIG.BUTTONS
        RINSE_CONFIG.SHOW_HEADER = RINSE_CONFIG.SHOW_HEADER == nil and true or RINSE_CONFIG.SHOW_HEADER
        Blacklist["Poison"]["Wyvern Sting"] = not RINSE_CONFIG.WYVERN_STING
        Blacklist["Disease"]["Mutating Injection"] = not RINSE_CONFIG.MUTATING_INJECTION
        RinseFrame:ClearAllPoints()
        RinseFrame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", RINSE_CONFIG.POSITION.x, RINSE_CONFIG.POSITION.y)
        RinseFrame:SetScale(RINSE_CONFIG.SCALE)
        RinseDebuffsFrame:SetScale(RINSE_CONFIG.SCALE)
        RinseFrame:SetAlpha(RINSE_CONFIG.OPACITY)
        RinseFrame:SetMovable(not RINSE_CONFIG.LOCK)
        RinseFrame:EnableMouse(not RINSE_CONFIG.LOCK)
        RinseOptionsFrameScaleSlider:SetValue(RINSE_CONFIG.SCALE)
        RinseOptionsFrameOpacitySlider:SetValue(RINSE_CONFIG.OPACITY)
        RinseOptionsFrameWyvernSting:SetChecked(RINSE_CONFIG.WYVERN_STING)
        RinseOptionsFrameMutatingInjection:SetChecked(RINSE_CONFIG.MUTATING_INJECTION)
        RinseOptionsFramePrint:SetChecked(RINSE_CONFIG.PRINT)
        RinseOptionsFrameMSBT:SetChecked(RINSE_CONFIG.MSBT)
        RinseOptionsFrameSound:SetChecked(RINSE_CONFIG.SOUND)
        RinseOptionsFrameLock:SetChecked(RINSE_CONFIG.LOCK)
        RinseOptionsFrameBackdrop:SetChecked(RINSE_CONFIG.BACKDROP)
        RinseOptionsFrameShowHeader:SetChecked(RINSE_CONFIG.SHOW_HEADER)
        RinseOptionsFrameFlip:SetChecked(RINSE_CONFIG.FLIP)
        RinseOptionsFrameButtonsSlider:SetValue(RINSE_CONFIG.BUTTONS)
        if Spells[playerClass] and Spells[playerClass].Poison then
            EnableCheckBox(RinseOptionsFrameWyvernSting)
        else
            DisableCheckBox(RinseOptionsFrameWyvernSting)
        end
        if Spells[playerClass] and Spells[playerClass].Disease then
            EnableCheckBox(RinseOptionsFrameMutatingInjection)
        else
            DisableCheckBox(RinseOptionsFrameMutatingInjection)
        end
        if RINSE_CONFIG.PRINT and MikSBT then
            EnableCheckBox(RinseOptionsFrameMSBT)
        else
            DisableCheckBox(RinseOptionsFrameMSBT)
        end
        UpdateBackdrop()
        UpdateFramesScale()
        UpdateDirection()
        UpdateNumButtons()
        UpdateHeader()
        UpdateSpells()
        UpdatePrio()
    elseif event == "SPELL_QUEUE_EVENT" then
        if RINSE_CONFIG.PRINT then
            -- arg1 is eventCode, arg2 is spellId
            -- NORMAL_QUEUE_POPPED = 3
            if arg1 == 3 then
                local spellName = GetSpellNameAndRankForId(arg2)
                if lastSpellName and lastButton and lastSpellName == spellName then
                    -- If button unit no longer set, don't print
                    if not lastButton.unit or lastButton.unit == "" then
                        return
                    end
                    local debuff = getglobal(lastButton:GetName().."Name"):GetText()
                    ChatMessage(DebuffColor[lastButton.type].hex..debuff.."|r - "..ClassColors[lastButton.unitClass]..UnitName(lastButton.unit).."|r")
                end
            end
        end
    elseif event == "RAID_ROSTER_UPDATE" or event == "PARTY_MEMBERS_CHANGED" then
        needUpdatePrio = true
        prioTimer = 2
    elseif event == "SPELLS_CHANGED" then
        UpdateSpells()
    end
end

local function GetDebuffInfo(unit, i)
    local debuffName
    local debuffType
    local texture
    local applications
    if superwow then
        local spellId
        texture, applications, debuffType, spellId = UnitDebuff(unit, i)
        if spellId then
            debuffName = SpellInfo(spellId)
        end
    else
        RinseScanTooltipTextLeft1:SetText("")
        RinseScanTooltipTextRight1:SetText("")
        RinseScanTooltip:SetUnitDebuff(unit, i)
        debuffName = RinseScanTooltipTextLeft1:GetText() or ""
        debuffType = RinseScanTooltipTextRight1:GetText() or ""
        texture, applications, debuffType = UnitDebuff(unit, i)
    end
    return debuffType, debuffName, texture, applications
end

local blockedUnits = {}

local function SaveDebuffInfo(unit, debuffIndex, i, class, debuffType, debuffName, texture, applications)
    if  SpellNameToRemove[debuffType] and Blocklist[debuffName] then --if blocked debuff of type we can dispell is found, unit goes on the block list
        blockedUnits[UnitName(unit)] = true
    end
    if SpellNameToRemove[debuffType] and not (Blacklist[debuffType] and Blacklist[debuffType][debuffName]) and
        not (ClassBlacklist[class] and ClassBlacklist[class][debuffName]) and not HasAbolish(unit, debuffType) then
        Debuffs[debuffIndex].name = debuffName or ""
        Debuffs[debuffIndex].type = debuffType or ""
        Debuffs[debuffIndex].texture = texture or ""
        Debuffs[debuffIndex].stacks = applications or 0
        Debuffs[debuffIndex].unit = unit
        Debuffs[debuffIndex].unitName = UnitName(unit) or ""
        Debuffs[debuffIndex].unitClass = class or ""
        Debuffs[debuffIndex].debuffIndex = i
        return true
    end
    return false
end

function RinseFrame_OnUpdate(elapsed)
    timeElapsed = timeElapsed + elapsed
    errorCooldown = (errorCooldown > 0) and (errorCooldown - elapsed) or 0
    stopCastCooldown = (stopCastCooldown > 0) and (stopCastCooldown - elapsed) or 0
    prioTimer = (prioTimer > 0) and (prioTimer - elapsed) or 0
    if needUpdatePrio and prioTimer <= 0 then
        UpdatePrio()
        needUpdatePrio = false
    end
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
    --clear blockedUnits
    blockedUnits = {}
    -- Get new info
    -- Target is highest prio
    if GoodUnit("target") then
        local _, class = UnitClass("target")
        local i = 1
        while debuffIndex < DEBUFFS_MAX do
            local debuffType, debuffName, texture, applications = GetDebuffInfo("target", i)
            if not texture then
                break
            end
            if debuffType and debuffName and class then
                if SaveDebuffInfo("target", debuffIndex, i, class, debuffType, debuffName, texture, applications) then
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
            local _, class = UnitClass(unit)
            local i = 1
            while debuffIndex < DEBUFFS_MAX do
                local debuffType, debuffName, texture, applications = GetDebuffInfo(unit, i)
                if not texture then
                    break
                end
                if debuffType and debuffName and class then
                    if SaveDebuffInfo(unit, debuffIndex, i, class, debuffType, debuffName, texture, applications) then
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
            if blockedUnits[unitName] then --if unit is on unit blocklist, do not add
                break
            end
            local button = getglobal("RinseFrameDebuff"..buttonIndex)
            local icon = getglobal("RinseFrameDebuff"..buttonIndex.."Icon")
            local debuffName = getglobal("RinseFrameDebuff"..buttonIndex.."Name")
            local playerName = getglobal("RinseFrameDebuff"..buttonIndex.."Player")
            local count = getglobal("RinseFrameDebuff"..buttonIndex.."Count")
            local border = getglobal("RinseFrameDebuff"..buttonIndex.."Border")
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
            if not InRange(unit, SpellNameToRemove[button.type]) then
                button:SetAlpha(0.5)
            else
                button:SetAlpha(1)
            end
        end
        if not RinseFrameDebuff1:IsShown() then
            playNoticeSound = true
        end
    end
end

function Rinse_Cleanse(button, attemptedCast)
    local button = button or this
    if not button.unit or button.unit == "" then
        return false
    end
    local debuff = getglobal(button:GetName().."Name"):GetText()
    local spellName = SpellNameToRemove[button.type]
    local spellSlot = SpellSlotForName[spellName]
    local onGcd = false
    -- Check if on gcd
    local _, duration = GetSpellCooldown(spellSlot, bookType)
    -- If gcd active this will return 1.5 for all the relevant spells
    if duration == 1.5 then
        onGcd = true
    end
    -- Allow attempting 1 spell even if gcd active so that it can be queued
    if attemptedCast and onGcd then
        -- Otherwise don't bother trying to cast
        return false
    end
    if not InRange(button.unit, spellName) then
        if errorCooldown <= 0 then
            playsound(errorSound)
            errorCooldown = 0.1
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
    end
    if castingInterruptableSpell and stopCastCooldown <= 0 then
        SpellStopCasting()
        stopCastCooldown = 0.2
    end
    if not onGcd then
        ChatMessage(DebuffColor[button.type].hex..debuff.."|r - "..ClassColors[button.unitClass]..UnitName(button.unit).."|r")
    else
        -- Save spellId, spellName and target so we can output chat message if it was queued
        lastSpellName = spellName
        lastButton = button
    end
    if superwow then
        CastSpellByName(spellName, button.unit)
    else
        local selfcast = false
        if GetCVar("autoselfcast") == "1" then
            selfcast = true
        end
        SetCVar("autoselfcast", 0)
        TargetByName(button.unitName, 1)
        CastSpellByName(spellName)
        TargetLastTarget()
        if selfcast then
            SetCVar("autoselfcast", 1)
        end
    end
    return true
end

function Rinse()
    local attemptedCast = false
    for i = 1, BUTTONS_MAX do
        if Rinse_Cleanse(getglobal("RinseFrameDebuff"..i), attemptedCast) then
            attemptedCast = true
        end
    end
end

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
    else
        ChatFrame1:AddMessage(BLUE.."[Rinse]|r Unknown command. Use /rinse, /rinse options, /rinse skip or /rinse prio.")
    end
end
