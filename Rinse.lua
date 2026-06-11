local _G = _G or getfenv(0)
local L = Rinse.L
local _, playerClass = UnitClass("player")
local superwow = SUPERWOW_VERSION
local unitxp = pcall(UnitXP, "nop", "nop")
local UnitExists = UnitExists
local UnitIsFriend = UnitIsFriend
local UnitIsVisible = UnitIsVisible
local UnitDebuff = UnitDebuff
local UnitClass = UnitClass
local UnitIsUnit = UnitIsUnit
local UnitIsPlayer = UnitIsPlayer
local UnitIsCharmed = UnitIsCharmed
local UnitName = UnitName
local CheckInteractDistance = CheckInteractDistance
local updateInterval = 0.1
local timeElapsed = 0
local lastDebuffCount = 0
local noticeSound = "Sound\\Doodad\\BellTollTribal.wav"
local errorSound = "Sound\\Interface\\Error.wav"
local playNoticeSound = true
local errorCooldown = 0
local stopCastCooldown = 0
local prioTimer = 0
local needUpdatePrio = false
local shadowform
local autoattack
local selectedClass = "WARRIOR"
local BlacklistArray = {}
local ClassFilterArray = {}
local FilterArray = {}
local OptionsScrollMaxButtons = 8
local AddToList
local AddToPlayerList
local versionsCheckTimer
local AddonVersions
local movingInList
local movingDestID
local movingButtonID

-- Bindings
BINDING_HEADER_RINSE_HEADER = "Rinse"
BINDING_NAME_RINSE = L["Run Rinse"]
BINDING_NAME_RINSE_TOGGLE_OPTIONS = L["Toggle Options"]
BINDING_NAME_RINSE_TOGGLE_PRIO = L["Toggle Prio List"]
BINDING_NAME_RINSE_TOGGLE_SKIP = L["Toggle Skip List"]

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
ClassColors["UNKNOWN"] = "|cff808080"

local DebuffColor = {}
DebuffColor[L["Snare"]]   = { r = 0.8, g = 0.0, b = 0.0, hex = "|cffCC0000" }
DebuffColor[L["Magic"]]   = { r = 0.2, g = 0.6, b = 1.0, hex = "|cff3399FF" }
DebuffColor[L["Curse"]]   = { r = 0.6, g = 0.0, b = 1.0, hex = "|cff9900FF" }
DebuffColor[L["Disease"]] = { r = 0.6, g = 0.4, b = 0.0, hex = "|cff996600" }
DebuffColor[L["Poison"]]  = { r = 0.0, g = 0.6, b = 0.0, hex = "|cff009900" }

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
		shown = false
	}
end

-- Default scan order
local DefaultPrio = {}
DefaultPrio[1] = "player"
DefaultPrio[2] = "party1"
DefaultPrio[3] = "party2"
DefaultPrio[4] = "party3"
DefaultPrio[5] = "party4"
for i = 1, 40 do tinsert(DefaultPrio, "raid"..i) end

-- Scan order
local Prio = {}
Prio[1] = "player"
Prio[2] = "party1"
Prio[3] = "party2"
Prio[4] = "party3"
Prio[5] = "party4"
for i = 1, 40 do tinsert(Prio, "raid"..i) end

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
SnareDebuffs[L["Surge of Mana"]] = true

local function wipe(array)
	if type(array) ~= "table" then return end
	for i = getn(array), 1, -1 do tremove(array, i) end
end

local function wipelist(list)
	if type(list) ~= "table" then return end
	for k in pairs(list) do list[k] = nil end
end

local function arrcontains(array, value)
	for i = 1, getn(array) do
		if type(array[i]) == "table" then
			for k in pairs(array[i]) do
				if array[i][k] == value then return i end
			end
		end
		if array[i] == value then return i end
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

local function playsound(file)
	if RINSE_CONFIG.SOUND then PlaySoundFile(file) end
end

local function NameToUnitID(name)
	if not name then return nil end
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
		return false
	end
	if not UsableSpells[debuffType] then
		return false
	end
	if not (debuffType == L["Poison"] or debuffType == L["Disease"]) then
		return false
	end
	local i = 1
	local buff, icon
	if debuffType == L["Poison"] then
		icon = "Interface\\Icons\\Spell_Nature_NullifyPoison_02"
	elseif debuffType == L["Disease"] then
		icon = "Interface\\Icons\\Spell_Nature_NullifyDisease"
	end
	repeat
		buff = UnitBuff(unit, i)
		if buff == icon then
			return true
		end
		i = i + 1
	until not buff
	return false
end

local function HasShadowform()
	for i = 0, 31 do
		local index = GetPlayerBuff(i, "HELPFUL")
		if index > -1 then
			if GetPlayerBuffTexture(index) == "Interface\\Icons\\Spell_Shadow_Shadowform" then
				return true
			end
		end
	end
	return false
end

local function CanCast(unit, spell)
	if not unit then return false end

	local inRange

	if UnitIsFriend("player", unit) and not UnitCanAttack("player", unit) then
		-- https://gitea.com/avitasia/nampower/issues/56
		-- if spell and IsSpellInRange then
		-- 	inRange = IsSpellInRange(spell, unit) == 1
		-- end
		if unitxp then
			-- Accounts for true reach. A tauren can dispell a male tauren at 38y!
			inRange = UnitXP("distanceBetween", "player", unit) < 30
		elseif superwow then
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
        if unitxp then
            return UnitXP("inSight", "player", unit)
        else
            return UnitIsVisible(unit)
        end
	end

	return false
end

local Seen = {}

local function UpdatePrio()
	wipe(Prio)
	-- If there is a user defined prio, add it first
	if RINSE_CONFIG.PRIO_ARRAY[1] then
		for i = 1, getn(RINSE_CONFIG.PRIO_ARRAY) do
			local unit = NameToUnitID(RINSE_CONFIG.PRIO_ARRAY[i].name)
			if unit then
				tinsert(Prio, unit)
			end
		end
	end
	-- Add default prio
	for i = 1, getn(DefaultPrio) do
		tinsert(Prio, DefaultPrio[i])
	end
	-- Always add pets to scan list (filtering happens during save based on RINSE_CONFIG.PETS)
	for i = 1, getn(Prio) do
		tinsert(Prio, (gsub(Prio[i], "(%a+)(%d*)", "%1pet%2")))
	end
	-- Get rid of duplicates and UnitIDs that we can't match to names in our raid/party
	wipelist(Seen)
	for i = 1, getn(Prio) do
		local name = UnitName(Prio[i])
		if not name or Seen[name] then
			-- Don't delete yet, just flag
			Prio[i] = false
		else
			Seen[name] = true
		end
	end
	-- Delete now
	for i = getn(Prio), 1, -1 do
		if Prio[i] == false then
			tremove(Prio, i)
		end
	end
	-- Skip randomization if display is not empty
	if RinseFrameDebuff1:IsShown() then
		return
	end
	-- Randomize everything that is not in PRIO_ARRAY
	local startIndex = 2
	local endIndex = getn(Prio)
	if RINSE_CONFIG.PRIO_ARRAY[1] then
		-- PRIO_ARRAY can contain names that are not in our raid/party
		-- To find index in Prio from where we can start randomization,
		-- find last unitID from PRIO_ARRAY that can be matched to any member of our raid/party,
		-- get index of that unitID in Prio and add 1 to it
		for i = getn(RINSE_CONFIG.PRIO_ARRAY), 1, -1 do
			local unit = NameToUnitID(RINSE_CONFIG.PRIO_ARRAY[i].name)
			if unit then
				for j = 1, endIndex do
					if Prio[j] == unit then
						startIndex = j + 1
						break
					end
				end
				break
			end
		end
	end
	for a = startIndex, endIndex do
		local b = random(startIndex, endIndex)
		if Prio[a] and Prio[b] then
			Prio[a], Prio[b] = Prio[b], Prio[a]
		end
	end
end

local function RebuildSkipNames()
	wipelist(SkipNames)
	local arr = RINSE_CONFIG.SKIP_ARRAY
	for i = 1, getn(arr) do
		if arr[i] and arr[i].name then
			SkipNames[arr[i].name] = true
		end
	end
end

function RinseSkipListScrollFrame_Update()
	RebuildSkipNames()
	local offset = FauxScrollFrame_GetOffset(RinseSkipListScrollFrame)
	local arrayIndex = 1
	local numPlayers = getn(RINSE_CONFIG.SKIP_ARRAY)
	FauxScrollFrame_Update(RinseSkipListScrollFrame, numPlayers, 10, 16)
	for i = 1, 10 do
		local button = _G["RinseSkipListFrameButton"..i]
		local buttonText = _G["RinseSkipListFrameButton"..i.."Text"]
		arrayIndex = i + offset
		if RINSE_CONFIG.SKIP_ARRAY[arrayIndex] then
			buttonText:SetText(arrayIndex.." - "..ClassColors[RINSE_CONFIG.SKIP_ARRAY[arrayIndex].class]..RINSE_CONFIG.SKIP_ARRAY[arrayIndex].name)
			button:SetID(arrayIndex)
			if movingButtonID and movingButtonID == arrayIndex then
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
	local numPlayers = getn(RINSE_CONFIG.PRIO_ARRAY)
	FauxScrollFrame_Update(RinsePrioListScrollFrame, numPlayers, 10, 16)
	for i = 1, 10 do
		local button = _G["RinsePrioListFrameButton"..i]
		local buttonText = _G["RinsePrioListFrameButton"..i.."Text"]
		arrayIndex = i + offset
		if RINSE_CONFIG.PRIO_ARRAY[arrayIndex] then
			buttonText:SetText(arrayIndex.." - "..ClassColors[RINSE_CONFIG.PRIO_ARRAY[arrayIndex].class]..RINSE_CONFIG.PRIO_ARRAY[arrayIndex].name)
			button:SetID(arrayIndex)
			if movingButtonID and movingButtonID == arrayIndex then
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
			tremove(RINSE_CONFIG.SKIP_ARRAY, this:GetID())
			RinseSkipListScrollFrame_Update()
		elseif parent == RinsePrioListFrame then
			tremove(RINSE_CONFIG.PRIO_ARRAY, this:GetID())
			RinsePrioListScrollFrame_Update()
			UpdatePrio()
		end
	end
end

function RinseListButton_OnDragStart()
	movingInList = this:GetParent()
	movingButtonID = this:GetID()
	local text = _G[this:GetName().."Text"]
	RinseMovingButtonText:SetText(text:GetText())
	text:SetText("")
	RinseMovingButton:StartMoving()
	RinseMovingButton:Show()
end

function RinseListButton_OnDragStop()
	if not movingInList then return end
	RinseMovingButton:StopMovingOrSizing()
	RinseMovingButton:Hide()
	local array, update
	if movingInList == RinsePrioListFrame then
		array = RINSE_CONFIG.PRIO_ARRAY
		update = RinsePrioListScrollFrame_Update
	elseif movingInList == RinseSkipListFrame then
		array = RINSE_CONFIG.SKIP_ARRAY
		update = RinseSkipListScrollFrame_Update
	end
	if movingDestID and movingButtonID and array and array[movingButtonID] and array[movingDestID] then
		array[movingButtonID], array[movingDestID] = array[movingDestID], array[movingButtonID]
	end
	movingButtonID = nil
	update()
	movingInList = nil
end

function RinseMovingButton_OnUpdate()
	if not movingInList then return end
	local cursorX, cursorY = GetCursorPosition()
	cursorX = cursorX / UIParent:GetScale()
	cursorY = cursorY / UIParent:GetScale()
	RinseMovingButton:ClearAllPoints()
	RinseMovingButton:SetPoint("LEFT", nil, "BOTTOMLEFT", cursorX - 30, cursorY)
	movingDestID = nil
	for i = 1, 10 do
		_G[movingInList:GetName().."Button"..i.."Highlight"]:Hide()
	end
	for i = 1, 10 do
		local button = _G[movingInList:GetName().."Button"..i]
		local highlight = _G[movingInList:GetName().."Button"..i.."Highlight"]
		if button:IsShown() and MouseIsOver(button) then
			highlight:Show()
			movingDestID = button:GetID()
		end
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
info.notCheckable = 1
info.hasArrow = nil
info.checked = nil
info.func = AddGroupOrClass

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

local function AddNameToPlayerList(name)
	if not name or name == "" then return end
	local array
	if AddToPlayerList == "skip" then
		array = RINSE_CONFIG.SKIP_ARRAY
	elseif AddToPlayerList == "prio" then
		array = RINSE_CONFIG.PRIO_ARRAY
	end
	if not array then return end
	if arrcontains(array, name) then return end
	local class = "UNKNOWN"
	local unit = NameToUnitID(name)
	if unit then
		local _, c = UnitClass(unit)
		if c then class = c end
	end
	tinsert(array, {name = name, class = class})
	if array == RINSE_CONFIG.SKIP_ARRAY then
		RinseSkipListScrollFrame_Update()
	elseif array == RINSE_CONFIG.PRIO_ARRAY then
		RinsePrioListScrollFrame_Update()
		UpdatePrio()
	end
end

StaticPopupDialogs["RINSE_ADD_PLAYER_TO_LIST"] = {
	text = "Enter player name:",
	button1 = OKAY,
	button2 = CANCEL,
	hasEditBox = 1,
	maxLetters = 12,
	OnAccept = function()
		local text = _G[this:GetParent():GetName().."EditBox"]:GetText()
		AddNameToPlayerList(text)
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

function RinseSkipListAddName_OnClick()
	AddToPlayerList = "skip"
	StaticPopup_Show("RINSE_ADD_PLAYER_TO_LIST")
end

function RinsePrioListAddName_OnClick()
	AddToPlayerList = "prio"
	StaticPopup_Show("RINSE_ADD_PLAYER_TO_LIST")
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

local AllSpells = {}

local function UpdateSpells()
	if not Spells[playerClass] then
		return
	end
	-- Gather all spells and their spellBookID
	wipelist(AllSpells)
	for tab = 1, GetNumSpellTabs() do
		local _, _, offset, numSpells = GetSpellTabInfo(tab)
		for spellBookID = offset + 1, offset + numSpells do
			local spell = GetSpellName(spellBookID, bookType)
			if spell then
				AllSpells[spell] = spellBookID
			end
		end
	end
	-- Search AllSpells for cleansing spells
	for dispelType, spells in pairs(Spells[playerClass]) do
		-- Search in reverse order to finish at more powerful spell which should be at index 1 in Spells[playerClass][debuffType]
		for i = getn(spells), 1, -1 do
			local spellToFind = spells[i]
			if spellToFind == L["Cleanse"] and RINSE_CHAR_CONFIG.FILTER[L["Magic"]] then
				-- In this case use Purify
				break
			end
			for spellName, spellSLot in pairs(AllSpells) do
				if spellName == spellToFind then
					UsableSpells[dispelType] = spellName
					UsableSpellBookIDs[spellName] = spellSLot
					break
				end
			end
		end
	end
end

local function ResolvePlayerClasses(array)
	for i = 1, getn(array) do
		if array[i].class == "UNKNOWN" then
			local unit = NameToUnitID(array[i].name)
			if unit then
				local _, c = UnitClass(unit)
				if c then array[i].class = c end
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

local function DisableCheckBox(checkBox)
	if not checkBox then return end
	checkBox:Disable()
	_G[checkBox:GetName().."Text"]:SetTextColor(GRAY_FONT_COLOR.r, GRAY_FONT_COLOR.g, GRAY_FONT_COLOR.b)
	_G[checkBox:GetName().."TooltipPreserve"]:Show()
end

local function EnableCheckBox(checkBox)
	if not checkBox then return end
	checkBox:Enable()
	_G[checkBox:GetName().."Text"]:SetTextColor(NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b)
	_G[checkBox:GetName().."TooltipPreserve"]:Hide()
end

local function UpdateBlacklist()
	for k, v in pairs(RINSE_CHAR_CONFIG.BLACKLIST) do
		Blacklist[k] = v
	end
end

local function UpdateFilter()
	for k, v in pairs(RINSE_CHAR_CONFIG.FILTER) do
		Filter[k] = v
	end
	for k, v in pairs(RINSE_CHAR_CONFIG.FILTER_CLASS) do
		RINSE_CHAR_CONFIG.FILTER_CLASS[k] = RINSE_CHAR_CONFIG.FILTER_CLASS[k] or {}
		for k2, v2 in pairs(RINSE_CHAR_CONFIG.FILTER_CLASS[k]) do
			ClassFilter[k][k2] = v2
		end
	end
	UpdateSpells()
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
	UpdatePrio()
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
		_G[frame]:SetScale(RINSE_CONFIG.SCALE)
	end
end

function RinseOptionsFrameScaleSLider_OnValueChanged()
	local scale = tonumber(format("%.2f", this:GetValue()))
	RINSE_CONFIG.SCALE = scale
	RinseFrame:SetScale(scale)
	RinseDebuffsFrame:SetScale(scale)
	_G[this:GetName().."Text"]:SetText(format(L.FMT_SCALE, scale))
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
	local numButtons = tonumber(format("%d", this:GetValue()))
	RINSE_CONFIG.BUTTONS = numButtons
	UpdateNumButtons()
	_G[this:GetName().."Text"]:SetText(format(L.FMT_DEBUFFS_SHOWN, numButtons))
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
		ChatFrame1:AddMessage(BLUE.."[Rinse]|r "..L["Buttons are hidden, to access option and lists use /rinse options, /rinse skip or /rinse prio."])
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
	if GetNampowerVersion then
		-- Announce queued decurses
		RinseFrame:RegisterEvent("SPELL_QUEUE_EVENT")
	end
	if playerClass == "PRIEST" then
		RinseFrame:RegisterEvent("PLAYER_AURAS_CHANGED")
	end
	if not superwow then
		-- For restoring auto attack
		RinseFrame:RegisterEvent("PLAYER_ENTER_COMBAT")
		RinseFrame:RegisterEvent("PLAYER_LEAVE_COMBAT")
	end
	RinseFrameTitle:SetText("Rinse "..GetAddOnMetadata("Rinse", "Version"))
end

-- Check if unit can be cleansed
local function CanBeCleansed(unit)
	return (UnitCanAssist("player", unit) and not UnitIsCharmed(unit))
	    or (not UnitCanAssist("player", unit) and UnitIsCharmed(unit))
end

local function GoodUnit(unit)
	if not (unit and UnitExists(unit)) then
		return false
	end
	local name = UnitName(unit)
	if not name or SkipNames[name] then
		return false
	end
	return UnitIsVisible(unit) and CanBeCleansed(unit)
end

function RinseFrame_OnEvent()
	if event == "ADDON_LOADED" and arg1 == "Rinse" then
		tinsert(UISpecialFrames, "RinsePrioListFrame")
		tinsert(UISpecialFrames, "RinseSkipListFrame")
		tinsert(UISpecialFrames, "RinseOptionsFrame")
		RinseFrame:UnregisterEvent("ADDON_LOADED")
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
		for k in pairs(DebuffColor) do
			local checkBox = _G["RinseOptionsFrameFilter"..k]
			if checkBox then
				if Spells[playerClass] and Spells[playerClass][k] then
					EnableCheckBox(checkBox)
				else
					DisableCheckBox(checkBox)
					checkBox.tooltipRequirement = L["Not available to your class."]
				end
			end
		end
		if Spells[playerClass] and Spells[playerClass][L["Poison"]] then
			EnableCheckBox(RinseOptionsFrameWyvernSting)
		else
			DisableCheckBox(RinseOptionsFrameWyvernSting)
			RinseOptionsFrameWyvernSting.tooltipRequirement = L["Not available to your class."]
		end
		if Spells[playerClass] and Spells[playerClass][L["Disease"]] then
			EnableCheckBox(RinseOptionsFrameMutatingInjection)
		else
			DisableCheckBox(RinseOptionsFrameMutatingInjection)
			RinseOptionsFrameMutatingInjection.tooltipRequirement = L["Not available to your class."]
		end
		if playerClass == "PRIEST" then
			EnableCheckBox(RinseOptionsFrameShadowform)
		else
			DisableCheckBox(RinseOptionsFrameShadowform)
			RinseOptionsFrameShadowform.tooltipRequirement = L["Not available to your class."]
		end
		if RINSE_CONFIG.PRINT and MikSBT then
			EnableCheckBox(RinseOptionsFrameMSBT)
		else
			DisableCheckBox(RinseOptionsFrameMSBT)
			RinseOptionsFrameMSBT.tooltipRequirement = not MikSBT and L["MSBT missing."] or nil
		end
		UpdateBackdrop()
		UpdateFramesScale()
		UpdateDirection()
		UpdateNumButtons()
		UpdateHeader()
		UpdateSpells()
		UpdatePrio()
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

		local debuff = _G[lastButton:GetName().."Name"]:GetText()
		ChatMessage(DebuffColor[lastButton.type].hex..debuff.."|r - "..ClassColors[lastButton.unitClass]..UnitName(lastButton.unit).."|r")
	elseif event == "RAID_ROSTER_UPDATE" or event == "PARTY_MEMBERS_CHANGED" then
		needUpdatePrio = true
		prioTimer = 2
	elseif event == "SPELLS_CHANGED" then
		UpdateSpells()
	elseif event == "PLAYER_AURAS_CHANGED" then
		shadowform = HasShadowform()
	elseif event == "PLAYER_ENTER_COMBAT" then
		autoattack = UnitName("target")
	elseif event == "PLAYER_LEAVE_COMBAT" then
		autoattack = nil
	elseif event == "CHAT_MSG_ADDON" and arg1 == "Rinse" and arg4 ~= UnitName("player") then
		if arg2 == "REPORT_ADDON_VERSION" then
			SendAddonMessage("Rinse", "V_"..GetAddOnMetadata("Rinse", "Version"), "RAID")
		elseif versionsCheckTimer and strfind(arg2, "^V_") then
			AddonVersions = AddonVersions or {}
			local v = strsub(arg2, 3) or ""
			tinsert(AddonVersions, { name = arg4, vString = format("%s: %s", arg4, v), vValue = tonumber((gsub(v, "%.", "0"))) or 0 })
		end
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
	if debuffName and SnareDebuffs[debuffName] and not debuffType then
		debuffType = L["Snare"]
	end
	return debuffType, debuffName, texture, applications
end

local function SaveDebuffInfo(unit, debuffIndex, i, class, debuffType, debuffName, texture, applications)
	local isPriority = PriorityDebuffs[debuffName]
	local isPet = strfind(unit, "pet") ~= nil

	-- If unit is a pet and PETS is disabled, only save priority debuffs
	if isPet and not RINSE_CONFIG.PETS and not isPriority then
		return false
	end

	-- Check if debuff can be removed and respect abolish setting
	if UsableSpells[debuffType] and (RINSE_CONFIG.IGNORE_ABOLISH or not HasAbolish(unit, debuffType)) then
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
	if versionsCheckTimer then
		versionsCheckTimer = versionsCheckTimer - elapsed
		if versionsCheckTimer <= 0 then
			versionsCheckTimer = nil
			Rinse_OutputVersionsCheckResults()
		end
	end
	if timeElapsed < updateInterval then
		return
	end
	timeElapsed = 0
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
		d.shown = false
		d.debuffIndex = 0
	end
	local debuffIndex = 1
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
	-- Scan units in Prio array (pets are included, filtered in SaveDebuffInfo)
	local prioCount = getn(Prio)
	for index = 1, prioCount do
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
	-- Process debuffs: blacklist, priority, shadowform, and filter logic
	-- Only iterate up to debuffIndex (actual found debuffs), cache table lookups
	local debuffCount = debuffIndex - 1
	if debuffCount < 0 then debuffCount = 0 end
	lastDebuffCount = debuffCount
	for i = 1, debuffCount do
		local d = Debuffs[i]
		local dName, dType, dUnitName, dUnitClass = d.name, d.type, d.unitName, d.unitClass
		-- Check if this debuff is blacklisted
		if Blacklist[dName] then
			-- Hide all debuffs of same type on same unit
			for j = 1, debuffCount do
				local d2 = Debuffs[j]
				if d2.unitName == dUnitName and (d2.type == dType or UsableSpells[dType] == L["Cleanse"]) then
					d2.shown = true
				end
			end
		end
		-- Check if this is a priority debuff
		if PriorityDebuffs[dName] and dType ~= "" then
			-- Hide all non-priority debuffs on same unit
			for j = 1, debuffCount do
				local d2 = Debuffs[j]
				if d2.unitName == dUnitName and not PriorityDebuffs[d2.name] then
					d2.shown = true
				end
			end
		end
		-- Shadowform: hide diseases
		if shadowform and RINSE_CONFIG.SHADOWFORM and dType == L["Disease"] then
			d.shown = true
		end
		-- Player filter (includes class-specific filters)
		local classFilter = ClassFilter[dUnitClass]
		if Filter[dName] or Filter[dType] or (classFilter and classFilter[dName]) then
			d.shown = true
		end
	end
	-- Move priority debuffs to the front of the list
	-- This is CRITICAL so that priority debuffs are removed first raidwide
	local frontIndex = 1
	for i = 1, debuffCount do
		local d = Debuffs[i]
		if not d.shown and PriorityDebuffs[d.name] then
			if i ~= frontIndex then
				-- Swap priority debuff to front
				Debuffs[frontIndex], Debuffs[i] = Debuffs[i], Debuffs[frontIndex]
			end
			frontIndex = frontIndex + 1
		end
	end
	-- Hide all buttons
	for i = 1, BUTTONS_MAX do
		local btn = _G["RinseFrameDebuff"..i]
		btn:Hide()
		btn.unit = nil
	end
	debuffIndex = 1
	for buttonIndex = 1, BUTTONS_MAX do
		-- Find next debuff to show
		while debuffIndex < DEBUFFS_MAX and Debuffs[debuffIndex].shown do
			debuffIndex = debuffIndex + 1
		end
		local name = Debuffs[debuffIndex].name
		local unit = Debuffs[debuffIndex].unit
		local unitName = Debuffs[debuffIndex].unitName
		local class = Debuffs[debuffIndex].unitClass
		local debuffType = Debuffs[debuffIndex].type
		if name ~= "" then
			local button = _G["RinseFrameDebuff"..buttonIndex]
			local icon = _G["RinseFrameDebuff"..buttonIndex.."Icon"]
			local debuffName = _G["RinseFrameDebuff"..buttonIndex.."Name"]
			local playerName = _G["RinseFrameDebuff"..buttonIndex.."Player"]
			local count = _G["RinseFrameDebuff"..buttonIndex.."Count"]
			local border = _G["RinseFrameDebuff"..buttonIndex.."Border"]
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
			Debuffs[debuffIndex].shown = true
			-- Don't show other debuffs from the same unit
			for i in pairs(Debuffs) do
				if Debuffs[i].unitName == unitName then
					Debuffs[i].shown = true
				end
			end
			if not CanCast(unit, UsableSpells[button.type]) then
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
	local debuff = _G[button:GetName().."Name"]:GetText()
	local spellName = UsableSpells[button.type]
	local spellSlot = UsableSpellBookIDs[spellName]
	-- Check if on gcd
	-- If gcd active this will return 1.5 for all the relevant spells
	local _, duration = GetSpellCooldown(spellSlot, bookType)
	local onGcd = duration == 1.5
	-- Allow attempting 1 spell even if gcd active so that it can be queued
	if attemptedCast and onGcd then
		-- Otherwise don't bother trying to cast
		return false
	end
	if not CanCast(button.unit, spellName) then
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

local function RunRinse()
	local attemptedCast = false
	for i = 1, BUTTONS_MAX do
		if Rinse_Cleanse(_G["RinseFrameDebuff"..i], attemptedCast) then
			attemptedCast = true
		end
	end
end

setmetatable(Rinse, { __call = RunRinse })

SLASH_RINSE1 = "/rinse"
SlashCmdList["RINSE"] = function(cmd)
	if cmd == "" then
		RunRinse()
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
		local frame = CreateFrame("Button", "RinseOptionsBlacklistButton"..i, RinseOptionsFrame, "RinseOptionsButtonTemplate")
		frame:SetID(i)
		frame:SetPoint("TOPLEFT", RinseOptionsFrameBlacklistScrollFrame, 0, -16 * (i-1))
	end
	for i = 1, OptionsScrollMaxButtons do
		local frame = CreateFrame("Button", "RinseOptionsClassFilterButton"..i, RinseOptionsFrame, "RinseOptionsButtonTemplate")
		frame:SetID(i)
		frame:SetPoint("TOPLEFT", RinseOptionsFrameClassFilterScrollFrame, 0, -16 * (i-1))
	end
	for i = 1, OptionsScrollMaxButtons do
		local frame = CreateFrame("Button", "RinseOptionsFilterButton"..i, RinseOptionsFrame, "RinseOptionsButtonTemplate")
		frame:SetID(i)
		frame:SetPoint("TOPLEFT", RinseOptionsFrameFilterScrollFrame, 0, -16 * (i-1))
	end
end

function RinseOptionsFrameBlacklistScrollFrame_Update()
	local frame = RinseOptionsFrameBlacklistScrollFrame or this
	local offset = FauxScrollFrame_GetOffset(frame)
	local arrayIndex = 1
	wipe(BlacklistArray)
	for k in pairs(Blacklist) do
		if Blacklist[k] then
			tinsert(BlacklistArray, k)
		end
	end
	sort(BlacklistArray)
	local numEntries = getn(BlacklistArray)
	FauxScrollFrame_Update(frame, numEntries, OptionsScrollMaxButtons, 16)
	for i = 1, OptionsScrollMaxButtons do
		local button = _G["RinseOptionsBlacklistButton"..i]
		local buttonText = _G["RinseOptionsBlacklistButton"..i.."Text"]
		arrayIndex = i + offset
		if BlacklistArray[arrayIndex] then
			buttonText:SetText(BlacklistArray[arrayIndex])
			button:SetID(arrayIndex)
			button:Show()
		else
			button:Hide()
		end
	end
end

function RinseOptionsFrameAddToBlacklist_OnClick()
	AddToList = 1
	StaticPopup_Show("RINSE_ADD_TO_BLACKLIST")
end

function RinseOptionsFrameResetBlacklist_OnClick()
	wipelist(Blacklist)
	wipelist(RINSE_CHAR_CONFIG.BLACKLIST)
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
	wipe(ClassFilterArray)
	for k in pairs(ClassFilter[selectedClass]) do
		if ClassFilter[selectedClass][k] then
			tinsert(ClassFilterArray, k)
		end
	end
	sort(ClassFilterArray)
	local numEntries = getn(ClassFilterArray)
	FauxScrollFrame_Update(frame, numEntries, OptionsScrollMaxButtons, 16)
	for i = 1, OptionsScrollMaxButtons do
		local button = _G["RinseOptionsClassFilterButton"..i]
		local buttonText = _G["RinseOptionsClassFilterButton"..i.."Text"]
		arrayIndex = i + offset
		if ClassFilterArray[arrayIndex] then
			buttonText:SetText(ClassFilterArray[arrayIndex])
			button:SetID(arrayIndex)
			button:Show()
		else
			button:Hide()
		end
	end
end

local function SelectClass()
	selectedClass = this.value
	local text = this:GetText()
	RinseOptionsFrameSelectClassText:SetText(text)
	RinseOptionsFrameClassFilterScrollFrame_Update()
end

local info2 = {}
info2.textHeight = 12
info2.notCheckable = 1
info2.checked = nil
info2.hasArrow = nil
info2.func = SelectClass

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

function RinseOptionsFrameAddToClassFilter_OnClick()
	AddToList = 2
	StaticPopup_Show("RINSE_ADD_TO_BLACKLIST")
end

function RinseOptionsFrameResetClassFilter_OnClick()
	wipelist(RINSE_CHAR_CONFIG.FILTER_CLASS[selectedClass])
	wipelist(ClassFilter[selectedClass])
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
		local text = _G[this:GetParent():GetName().."EditBox"]:GetText()
		if AddToList == 1 then
			RINSE_CHAR_CONFIG.BLACKLIST[text] = true
			RinseOptionsFrameWyvernSting:SetChecked(not RINSE_CHAR_CONFIG.BLACKLIST[L["Wyvern Sting"]])
			RinseOptionsFrameMutatingInjection:SetChecked(not RINSE_CHAR_CONFIG.BLACKLIST[L["Mutating Injection"]])
			UpdateBlacklist()
		elseif AddToList == 2 then
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
	if DebuffColor[text] and Spells[playerClass][text] == nil then
		return
	end
	local buttonType = gsub(gsub(this:GetName(), "^RinseOptions", ""), "Button%d+$", "")
	local scrollFrame = "RinseOptionsFrame"..buttonType.."ScrollFrame"
	if buttonType == "Blacklist" then
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
	elseif buttonType == "ClassFilter" then
		RINSE_CHAR_CONFIG.FILTER_CLASS[selectedClass][text] = false
		UpdateFilter()
	elseif buttonType == "Filter" then
		RINSE_CHAR_CONFIG.FILTER[text] = false
		RinseOptionsFrameFilterMagic:SetChecked(not RINSE_CHAR_CONFIG.FILTER[L["Magic"]])
		RinseOptionsFrameFilterSnare:SetChecked(not RINSE_CHAR_CONFIG.FILTER[L["Snare"]])
		RinseOptionsFrameFilterDisease:SetChecked(not RINSE_CHAR_CONFIG.FILTER[L["Disease"]])
		RinseOptionsFrameFilterPoison:SetChecked(not RINSE_CHAR_CONFIG.FILTER[L["Poison"]])
		RinseOptionsFrameFilterCurse:SetChecked(not RINSE_CHAR_CONFIG.FILTER[L["Curse"]])
		UpdateFilter()
	end
	_G[scrollFrame.."_Update"]()
	PlaySound("igMainMenuOptionCheckBoxOn")
end

function RinseOptionsFrameFilterScrollFrame_Update()
	local frame = RinseOptionsFrameFilterScrollFrame or this
	local offset = FauxScrollFrame_GetOffset(frame)
	local arrayIndex = 1
	wipe(FilterArray)
	for k in pairs(Filter) do
		if Filter[k] then
			if DebuffColor[k] then
				tinsert(FilterArray, 1, k)
			else
				tinsert(FilterArray, k)
			end
		end
	end
	local numEntries = getn(FilterArray)
	FauxScrollFrame_Update(frame, numEntries, OptionsScrollMaxButtons, 16)
	for i = 1, OptionsScrollMaxButtons do
		local button = _G["RinseOptionsFilterButton"..i]
		local buttonText = _G["RinseOptionsFilterButton"..i.."Text"]
		arrayIndex = i + offset
		if FilterArray[arrayIndex] then
			buttonText:SetText(FilterArray[arrayIndex])
			button:SetID(arrayIndex)
			button:Show()
		else
			button:Hide()
		end
	end
end

function RinseOptionsFrameAddToFilter_OnClick()
	StaticPopup_Show("RINSE_ADD_TO_FILTER")
end

function RinseOptionsFrameResetFilter_OnClick()
	wipelist(RINSE_CHAR_CONFIG.FILTER)
	wipelist(Filter)
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
	if versionsCheckTimer then
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
		versionsCheckTimer = 3
	else
		DEFAULT_CHAT_FRAME:AddMessage(BLUE.."[Rinse]|r "..L["You are not in a raid or party."])
	end
end

function Rinse_OutputVersionsCheckResults()
	if not AddonVersions then
		AddonVersions = {}
	end
	local myVersionString = GetAddOnMetadata("Rinse", "Version")
	local myVersionValue = tonumber((gsub(myVersionString, "%.", "0")))
	local myName = UnitName("player")
	tinsert(AddonVersions, { name = myName, vString = format("%s: %s", myName, myVersionString), vValue = myVersionValue })
	if GetNumRaidMembers() > 0 then
		for i = 1, 40 do
			local name = GetRaidRosterInfo(i)
			if name then
				if not arrcontains(AddonVersions, name) then
					tinsert(AddonVersions, { name = name, vString = format("%s: %s", name, "unknown"), vValue = 0 })
				end
			end
		end
	elseif GetNumPartyMembers() > 0 then
		for i = 1, 4 do
			local name = UnitName("party"..i)
			if name then
				if not arrcontains(AddonVersions, name) then
					tinsert(AddonVersions, { name = name, vString = format("%s: %s", name, "unknown"), vValue = 0 })
				end
			end
		end
	end
	sort(AddonVersions, function(a, b)
		return a.vValue > b.vValue
	end)
	local orange = "|cffff7f3f"
	local green = "|cff3fbf3f"
	local grey = "|cffff2020"
	local msg = BLUE.."[Rinse]|r "..L["Version check results:"].."\n"
	local size = getn(AddonVersions)
	for i = 1, size do
		local value = AddonVersions[i].vValue
		if value > myVersionValue then
			AddonVersions[i].vString = orange..AddonVersions[i].vString.."|r"
		elseif value == myVersionValue then
			AddonVersions[i].vString = green..AddonVersions[i].vString.."|r"
		elseif value < myVersionValue then
			AddonVersions[i].vString = grey..AddonVersions[i].vString.."|r"
		end
		msg = msg..AddonVersions[i].vString..(i ~= size and "\n" or "")
	end
	DEFAULT_CHAT_FRAME:AddMessage(msg)
	AddonVersions = nil
end
