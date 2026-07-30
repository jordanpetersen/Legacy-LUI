--[[
	Module.....: Bags
	Description: Replace the default bags.
]]
-- ####################################################################################################################
-- ##### Setup and Locals #############################################################################################
-- ####################################################################################################################

---@class LUIAddon
local LUI = select(2, ...)

---@class LUI.Bags : LUIModule, AceHook-3.0
local module = LUI:NewModule("Bags", "AceHook-3.0")

module.enableButton = true
-- Bags OnDisable unhooks bag APIs; no ReloadUI required from Control Panel.
module.skipReloadOnToggle = true

-- ####################################################################################################################
-- ##### Default Settings #############################################################################################
-- ####################################################################################################################

module.defaults = {
	profile = {
		Bags = {
			Lock = false,
			RowSize = 16,
			Padding = 8,
			Spacing = 4,
			Scale = 1,
			BagBar = true,
			ItemQuality = true,
			ItemLevel = true,
			BagNewline = false,
			ShowNew = false,
			ShowQuest = true,
			ShowOverlay = true,
			BackgroundTexture = "Blizzard Tooltip",
			BorderTexture = "Stripped_medium",
			BorderSize = 5,
			X = 0,
			Y = 0,
		},
		Bank = {
			Lock = false,
			RowSize = 14,
			Padding = 8,
			Spacing = 4,
			Scale = 1,
			BagBar = true,
			ItemQuality = true,
			ItemLevel = true,
			BagNewline = false,
			ShowNew = false,
			ShowQuest = true,
			ShowOverlay = true,
			BackgroundTexture = "Blizzard Tooltip",
			BorderTexture = "Stripped_medium",
			BorderSize = 5,
			X = 0,
			Y = 0,
			ActiveTab = nil, -- CharacterBankTab bag ID last selected
		},
		Warband = {
			Lock = false,
			RowSize = 14,
			Padding = 8,
			Spacing = 4,
			Scale = 1,
			BagBar = true,
			ItemQuality = true,
			ItemLevel = true,
			BagNewline = false,
			ShowNew = false,
			ShowQuest = true,
			ShowOverlay = true,
			BackgroundTexture = "Blizzard Tooltip",
			BorderTexture = "Stripped_medium",
			BorderSize = 5,
			X = 400,
			Y = 0,
			ActiveTab = nil, -- AccountBankTab bag ID last selected
		},
		-- Reagent bank frame removed in 11.2; reagent-capable character tabs replace it.
		-- Kept empty shell so old profiles migrate without AceDB errors.
		Reagent = {
			Lock = false,
			RowSize = 16,
			Padding = 8,
			Spacing = 4,
			Scale = 1,
		},
		Textures = {
			BackgroundTex = "Blizzard Tooltip",
			BorderTex = "Stripped_medium",
			BorderSize = 5,
		},
		-- Fonts and Colors
		Fonts = {
			Bags = { Name = "NotoSans-SCB", Size = 12, Flag = "OUTLINE", },
			Stack = { Name = "NotoSans-SCB", Size = 12, Flag = "OUTLINE", },
		},
		Colors = {
			Search =         { r = 0.6,  g = 0.6,  b = 1,    a = 1,   t = "Class",      },
			Border =         { r = 0.2,  g = 0.2,  b = 0.2,  a = 1,   t = "Individual", },
			Background =     { r = 0.18, g = 0.18, b = 0.18, a = 0.8, t = "Class",      },
			ItemBackground = { r = 0.18, g = 0.18, b = 0.18, a = 0.8, t = "Individual", },
			Professions = { r = 0.1, g = 0.5, b = 0.2, },
			Bags =        { r = 1,   g = 1,   b = 1,   },
			--TODO: Add support for FrameBorder and FrameBackground
			--FrameBackground = { r = 0.09, g = 0.09, b = 0.09, a = 0.8, t = "Individual", },
		},
	},
}

-- ####################################################################################################################
-- ##### Framework Events #############################################################################################
-- ####################################################################################################################

module.enableButton = true

function module:OnInitialize()
	LUI:RegisterModule(module)
end

function module:OnEnable()
	module:SetBags()

	local origToggleBag = ToggleBag
	module:RawHook("ToggleBag", function(id)
		if module.IsManagedBankBag and module:IsManagedBankBag(id) then
			module:SuppressBlizzardBankUI()
			return
		end
		if id and id > 5 then
			origToggleBag(id)
		else
			module.ToggleBags(id)
		end
	end, true)
	module:RawHook("ToggleBackpack", module.ToggleBags, true)
	module:RawHook("OpenAllBags", module.OpenBags, true)
	module:RawHook("ToggleAllBags", module.ToggleBags, true)
	module:RawHook("OpenBackpack", module.OpenBags, true)
	module:RawHook("OpenBag", function(id)
		if module.IsManagedBankBag and module:IsManagedBankBag(id) then
			module:SuppressBlizzardBankUI()
			return
		end
		module.OpenBags()
	end, true)
	module:SecureHook("CloseBackpack", module.CloseBags, true)
	module:SecureHook("CloseAllBags", module.CloseBags, true)

	module:RegisterEvent("BANKFRAME_OPENED", module.OpenBank)
	module:RegisterEvent("BANKFRAME_CLOSED", module.CloseBank)
	module:RegisterEvent("BANK_TAB_SETTINGS_UPDATED", "OnBankTabSettingsUpdated")
	module:RegisterEvent("PLAYERBANKBAGSLOTS_CHANGED", "OnBankBagSlotsChanged")

	tinsert(UISpecialFrames, "LUIBags")
	tinsert(UISpecialFrames, "LUIBank")
	tinsert(UISpecialFrames, "LUIWarband")

	-- Prevent Blizzard bank UI from fighting LUI while the module is enabled.
	module:SuppressBlizzardBankUI()
	_G.CloseAllBags()
end

function module:OnBankTabSettingsUpdated(event, bankType)
	local characterType = Enum.BankType and Enum.BankType.Character or 0
	local accountType = Enum.BankType and Enum.BankType.Account or 2
	if LUIBank and (bankType == nil or bankType == characterType) then
		LUIBank:BankTabsUpdated()
	end
	if LUIWarband and (bankType == nil or bankType == accountType) then
		LUIWarband:BankTabsUpdated()
	end
end

function module:OnBankBagSlotsChanged()
	if LUIBank and LUIBank:IsShown() then
		LUIBank:BankTabsUpdated()
	end
	if LUIWarband and LUIWarband:IsShown() then
		LUIWarband:BankTabsUpdated()
	end
end

function module:OnDisable()
	_G.CloseAllBags()
	-- Undo ToggleBag / OpenBag hooks so Blizzard bags work without ReloadUI.
	module:UnhookAll()
	module:UnregisterEvent("BANKFRAME_OPENED")
	module:UnregisterEvent("BANKFRAME_CLOSED")
	module:UnregisterEvent("BANK_TAB_SETTINGS_UPDATED")
	module:UnregisterEvent("PLAYERBANKBAGSLOTS_CHANGED")

	if _G.BankFrame then
		_G.BankFrame:RegisterEvent("BANKFRAME_OPENED")
		_G.BankFrame:RegisterEvent("BANKFRAME_CLOSED")
	end
end
