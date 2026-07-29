-- ####################################################################################################################
-- ##### Setup and Locals #############################################################################################
-- ####################################################################################################################

---@class Opt
local Opt = select(2, ...)

---@type AceLocale.Localizations, LUI.MarkRoster, AceDB-3.0
local L, module, db = Opt:GetLUIModule("MarkRoster")
if not module or not module.registered then return end

local MarkRoster = Opt:CreateModuleOptions("MarkRoster", module)

-- ####################################################################################################################
-- ##### Options Table ################################################################################################
-- ####################################################################################################################

MarkRoster.args = {
	Header = Opt:Header({name = "Mark Roster"}),
	Desc = Opt:Desc({name = "Prototype: save a name→raid-icon list and click secure buttons out of combat to apply marks. Does not auto-mark (Midnight protected SetRaidTarget)."}),
	AutoShow = Opt:Toggle({
		name = "Auto-Show Window",
		desc = "When the group roster changes, show the apply window if any saved players are present.",
		width = "full",
	}),
	Scale = Opt:Slider({name = "Scale", min = 0.5, max = 2, step = 0.05}),
	Spacer = Opt:Spacer({}),
	ToggleWindow = Opt:Execute({
		name = "Toggle Window",
		func = function() module:ToggleWindow() end,
	}),
	Refresh = Opt:Execute({
		name = "Refresh List",
		func = function() module:RefreshList() end,
	}),
}
