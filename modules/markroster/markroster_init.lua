--[[
	Module.....: MarkRoster
	Description: Prototype — saved name→raid-icon map with a click-to-apply window
	             (SecureActionButton / out of combat). Does not auto-mark.
]]

-- ####################################################################################################################
-- ##### Setup and Locals #############################################################################################
-- ####################################################################################################################

---@class LUIAddon
local LUI = select(2, ...)

---@class LUI.MarkRoster : LUIModule, AceEvent-3.0
local module = LUI:NewModule("MarkRoster", "AceEvent-3.0")

module.enableButton = true

-- ####################################################################################################################
-- ##### Default Settings #############################################################################################
-- ####################################################################################################################

module.defaults = {
	profile = {
		Enable = true,
		-- Show the apply window when group roster changes (still requires a click to mark).
		AutoShow = true,
		Scale = 1,
		X = 0,
		Y = 120,
		-- [ "Name-Realm" ] = raidTargetIndex (1-8)
		Marks = {
			["*"] = false,
		},
	},
}

-- ####################################################################################################################
-- ##### Framework Events #############################################################################################
-- ####################################################################################################################

function module:OnInitialize()
	LUI:RegisterModule(module)
end

function module:OnEnable()
	self:CreateWindow()
	self:RegisterEvent("GROUP_ROSTER_UPDATE", "OnRosterChanged")
	self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnRosterChanged")
	self:RegisterEvent("PLAYER_REGEN_ENABLED", "OnLeaveCombat")
	self:RegisterEvent("PLAYER_REGEN_DISABLED", "OnEnterCombat")
	self:RefreshList()
end

function module:OnDisable()
	self:UnregisterAllEvents()
	if self.window then
		self.window:Hide()
	end
end
