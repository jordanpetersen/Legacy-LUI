--[[
	MarkRoster prototype

	Midnight: SetRaidTarget is protected. This module never calls it directly.
	It builds SecureActionButton rows the player clicks out of combat to apply
	saved marks to matching group members.

	Slash: /luimarks  — toggle window
	       /luimarks add <1-8>  — save current target with that icon
	       /luimarks remove     — remove current target from the list
]]

-- ####################################################################################################################
-- ##### Setup and Locals #############################################################################################
-- ####################################################################################################################

---@class LUIAddon
local LUI = select(2, ...)

---@class LUI.MarkRoster
local module = LUI:GetModule("MarkRoster")

local InCombatLockdown = _G.InCombatLockdown
local UnitExists = _G.UnitExists
local UnitIsPlayer = _G.UnitIsPlayer
local UnitFullName = _G.UnitFullName
local UnitName = _G.UnitName
local GetNumGroupMembers = _G.GetNumGroupMembers
local IsInRaid = _G.IsInRaid
local GetNormalizedRealmName = _G.GetNormalizedRealmName
local CreateFrame = _G.CreateFrame
local wipe = _G.wipe
local pairs = _G.pairs
local ipairs = _G.ipairs
local tonumber = _G.tonumber
local format = string.format
local max = math.max
local tinsert = table.insert

local ICON_SIZE = 24
local ROW_HEIGHT = 28
local WINDOW_WIDTH = 280

local RAID_ICON_TEXTURE = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_%d"

-- Prefer /tm via SecureActionButton macrotext — confirmed working post-Midnight.
-- Native type "raidtarget" + marker/unit attributes also exist; swap ATTR_* if preferred.
local ATTR_TYPE = "macro"
-- Alternate native path (uncomment and set type to "raidtarget" if desired):
-- local ATTR_TYPE, ATTR_UNIT, ATTR_MARKER, ATTR_ACTION, ATTR_ACTION_SET =
-- 	"raidtarget", "unit", "marker", "action", "set"

-- ####################################################################################################################
-- ##### Helpers ######################################################################################################
-- ####################################################################################################################

--- Stable key for a unit: Name-Realm
---@param unit string
---@return string|nil
function module:GetUnitNameKey(unit)
	if not unit or not UnitExists(unit) then return end
	local name, realm = UnitFullName(unit)
	if not name then return end
	if not realm or realm == "" then
		realm = GetNormalizedRealmName()
	end
	return name.."-"..realm
end

---@param index number
---@return string
local function IconTexturePath(index)
	return format(RAID_ICON_TEXTURE, index)
end

--- Iterate party/raid unit tokens currently in the group.
---@return fun(): string|nil
function module:IterateGroupUnits()
	local units = {}
	if IsInRaid() then
		for i = 1, GetNumGroupMembers() do
			units[#units + 1] = "raid"..i
		end
	else
		units[#units + 1] = "player"
		for i = 1, GetNumGroupMembers() - 1 do
			units[#units + 1] = "party"..i
		end
	end
	local i = 0
	return function()
		i = i + 1
		return units[i]
	end
end

--- Rows to show: saved marks whose player is currently in the group.
---@return { key: string, unit: string, icon: number, displayName: string }[]
function module:GetPendingRows()
	local db = self.db.profile
	local rows = {}
	for unit in self:IterateGroupUnits() do
		local key = self:GetUnitNameKey(unit)
		local icon = key and db.Marks[key]
		if key and type(icon) == "number" and icon >= 1 and icon <= 8 then
			local displayName = UnitName(unit) or key
			rows[#rows + 1] = {
				key = key,
				unit = unit,
				icon = icon,
				displayName = displayName,
			}
		end
	end
	return rows
end

-- ####################################################################################################################
-- ##### Saved list API ###############################################################################################
-- ####################################################################################################################

--- Save unit under the given raid icon (1-8).
---@param unit string
---@param icon number
---@return boolean
function module:SaveUnitMark(unit, icon)
	icon = tonumber(icon)
	if not icon or icon < 1 or icon > 8 then return false end
	if not UnitExists(unit) or not UnitIsPlayer(unit) then return false end
	local key = self:GetUnitNameKey(unit)
	if not key then return false end
	self.db.profile.Marks[key] = icon
	self:RefreshList()
	return true
end

---@param keyOrUnit string
function module:RemoveMark(keyOrUnit)
	local key = keyOrUnit
	if UnitExists(keyOrUnit) then
		key = self:GetUnitNameKey(keyOrUnit)
	end
	if not key then return end
	self.db.profile.Marks[key] = false
	self:RefreshList()
end

-- ####################################################################################################################
-- ##### Window + secure buttons ######################################################################################
-- ####################################################################################################################

function module:CreateWindow()
	if self.window then return self.window end

	local db = self.db.profile
	local frame = CreateFrame("Frame", "LUIMarkRoster", UIParent, "BackdropTemplate")
	frame:SetSize(WINDOW_WIDTH, 120)
	frame:SetPoint("CENTER", UIParent, "CENTER", db.X, db.Y)
	frame:SetScale(db.Scale or 1)
	frame:SetMovable(true)
	frame:EnableMouse(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", frame.StartMoving)
	frame:SetScript("OnDragStop", function(f)
		f:StopMovingOrSizing()
		local _, _, _, x, y = f:GetPoint(1)
		db.X, db.Y = x, y
	end)
	frame:SetBackdrop({
		bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		edgeSize = 12,
		insets = { left = 3, right = 3, top = 3, bottom = 3 },
	})
	frame:SetBackdropColor(0, 0, 0, 0.85)
	frame:Hide()

	local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	title:SetPoint("TOPLEFT", 12, -10)
	title:SetText("Mark Roster (click to apply)")
	frame.title = title

	local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
	close:SetPoint("TOPRIGHT", -2, -2)
	close:SetScript("OnClick", function() frame:Hide() end)

	local hint = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	hint:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
	hint:SetPoint("RIGHT", frame, "RIGHT", -12, 0)
	hint:SetJustifyH("LEFT")
	hint:SetText("Out of combat only. Secure buttons — no auto-mark.")
	frame.hint = hint

	local combatNote = frame:CreateFontString(nil, "OVERLAY", "GameFontRedSmall")
	combatNote:SetPoint("TOPLEFT", hint, "BOTTOMLEFT", 0, -4)
	combatNote:SetPoint("RIGHT", frame, "RIGHT", -12, 0)
	combatNote:SetJustifyH("LEFT")
	combatNote:SetText("In combat — list will refresh when you leave combat.")
	combatNote:Hide()
	frame.combatNote = combatNote

	local list = CreateFrame("Frame", nil, frame)
	list:SetPoint("TOPLEFT", 8, -48)
	list:SetPoint("BOTTOMRIGHT", -8, 36)
	frame.list = list

	local empty = frame:CreateFontString(nil, "OVERLAY", "GameFontDisable")
	empty:SetPoint("CENTER", list, "CENTER")
	empty:SetText("No saved marks in this group.")
	frame.emptyText = empty

	-- Non-secure controls for list management (safe anytime).
	local addRow = CreateFrame("Frame", nil, frame)
	addRow:SetPoint("BOTTOMLEFT", 8, 8)
	addRow:SetPoint("BOTTOMRIGHT", -8, 8)
	addRow:SetHeight(24)

	local addLabel = addRow:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	addLabel:SetPoint("LEFT", 0, 0)
	addLabel:SetText("Save target as:")

	local x = 90
	for icon = 1, 8 do
		local pick = CreateFrame("Button", nil, addRow)
		pick:SetSize(ICON_SIZE, ICON_SIZE)
		pick:SetPoint("LEFT", x, 0)
		x = x + ICON_SIZE + 2
		local tex = pick:CreateTexture(nil, "ARTWORK")
		tex:SetAllPoints()
		tex:SetTexture(IconTexturePath(icon))
		pick:SetScript("OnClick", function()
			if module:SaveUnitMark("target", icon) then
				LUI:Print(format("Mark Roster: saved target as icon %d.", icon))
			else
				LUI:Print("Mark Roster: target a friendly player first.")
			end
		end)
		pick:SetScript("OnEnter", function(selfBtn)
			_G.GameTooltip:SetOwner(selfBtn, "ANCHOR_TOP")
			_G.GameTooltip:SetText(format("Save current target with icon %d", icon), 1, 1, 1)
			_G.GameTooltip:Show()
		end)
		pick:SetScript("OnLeave", function() _G.GameTooltip:Hide() end)
	end

	frame.rows = {}
	self.window = frame
	tinsert(_G.UISpecialFrames, "LUIMarkRoster")
	return frame
end

function module:ClearRows()
	if not self.window then return end
	for _, row in ipairs(self.window.rows) do
		row:Hide()
		row:SetParent(nil)
	end
	wipe(self.window.rows)
end

--- Rebuild secure apply buttons. No-op during combat lockdown.
function module:RefreshList()
	if not self.window then
		self:CreateWindow()
	end
	local frame = self.window
	local db = self.db.profile

	frame:SetScale(db.Scale or 1)

	if InCombatLockdown() then
		frame.combatNote:Show()
		self._pendingRefresh = true
		return
	end

	frame.combatNote:Hide()
	self._pendingRefresh = false
	self:ClearRows()

	local pending = self:GetPendingRows()
	frame.emptyText:SetShown(#pending == 0)

	local y = 0
	for i, info in ipairs(pending) do
		local row = CreateFrame("Button", "LUIMarkRosterRow"..i, frame.list, "SecureActionButtonTemplate")
		row:SetSize(WINDOW_WIDTH - 24, ROW_HEIGHT)
		row:SetPoint("TOPLEFT", 0, y)
		y = y - ROW_HEIGHT
		row:RegisterForClicks("AnyUp", "AnyDown")

		-- Secure apply: hardware click required. Uses /tm unit conditional.
		row:SetAttribute("type", ATTR_TYPE)
		row:SetAttribute("macrotext", format("/tm [@%s] %d", info.unit, info.icon))

		local icon = row:CreateTexture(nil, "ARTWORK")
		icon:SetSize(ICON_SIZE, ICON_SIZE)
		icon:SetPoint("LEFT", 4, 0)
		icon:SetTexture(IconTexturePath(info.icon))

		local label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
		label:SetPoint("LEFT", icon, "RIGHT", 8, 0)
		label:SetPoint("RIGHT", -28, 0)
		label:SetJustifyH("LEFT")
		label:SetText(format("%s  (%s)", info.displayName, info.unit))

		local remove = CreateFrame("Button", nil, row)
		remove:SetSize(18, 18)
		remove:SetPoint("RIGHT", -4, 0)
		remove:SetNormalFontObject("GameFontHighlight")
		remove:SetText("x")
		remove:SetScript("OnClick", function()
			module:RemoveMark(info.key)
		end)

		local hl = row:CreateTexture(nil, "HIGHLIGHT")
		hl:SetAllPoints()
		hl:SetColorTexture(1, 1, 1, 0.12)

		row:SetScript("OnEnter", function(selfBtn)
			_G.GameTooltip:SetOwner(selfBtn, "ANCHOR_RIGHT")
			_G.GameTooltip:SetText("Apply mark", 1, 1, 1)
			_G.GameTooltip:AddLine(format("%s → icon %d via %s", info.displayName, info.icon, info.unit), nil, nil, nil, true)
			_G.GameTooltip:Show()
		end)
		row:SetScript("OnLeave", function() _G.GameTooltip:Hide() end)

		frame.rows[i] = row
	end

	local height = 48 + 36 + max(#pending, 1) * ROW_HEIGHT + 8
	frame:SetHeight(height)
end

function module:ShowWindow()
	self:CreateWindow()
	self:RefreshList()
	self.window:Show()
end

function module:HideWindow()
	if self.window then
		self.window:Hide()
	end
end

function module:ToggleWindow()
	if self.window and self.window:IsShown() then
		self:HideWindow()
	else
		self:ShowWindow()
	end
end

-- ####################################################################################################################
-- ##### Events #######################################################################################################
-- ####################################################################################################################

function module:OnRosterChanged()
	if InCombatLockdown() then
		self._pendingRefresh = true
		return
	end
	self:RefreshList()
	if self.db.profile.AutoShow and #self:GetPendingRows() > 0 then
		self:ShowWindow()
	end
end

function module:OnLeaveCombat()
	if self._pendingRefresh then
		self:RefreshList()
	end
end

function module:OnEnterCombat()
	if self.window then
		self.window.combatNote:Show()
	end
end

-- ####################################################################################################################
-- ##### Slash commands ###############################################################################################
-- ####################################################################################################################

SLASH_LUIMARKROSTER1 = "/luimarks"
SLASH_LUIMARKROSTER2 = "/luimarkroster"
SlashCmdList.LUIMARKROSTER = function(msg)
	local cmd, rest = msg:match("^(%S*)%s*(.-)$")
	cmd = string.lower(cmd or "")
	if cmd == "add" then
		local icon = tonumber(rest)
		if module:SaveUnitMark("target", icon) then
			LUI:Print(format("Mark Roster: saved target as icon %d.", icon))
		else
			LUI:Print("Usage: /luimarks add <1-8>  (with a player targeted)")
		end
	elseif cmd == "remove" then
		module:RemoveMark("target")
		LUI:Print("Mark Roster: removed target from list (if present).")
	elseif cmd == "refresh" then
		module:RefreshList()
		LUI:Print("Mark Roster: refreshed.")
	else
		module:ToggleWindow()
	end
end
