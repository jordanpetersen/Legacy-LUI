-- ####################################################################################################################
-- ##### Tabbed Bank Containers (Retail 11.2+) ########################################################################
-- ####################################################################################################################
-- Character: CharacterBankTab_1..6
-- Warband:   AccountBankTab_1..5
-- Pre-11.2 bank bags + separate reagent bank are gone.

---@class LUIAddon
local LUI = select(2, ...)

---@class LUI.Bags
local module = LUI:GetModule("Bags")

local C_Bank = _G.C_Bank
local C_Container = _G.C_Container
local format = string.format
local tContains = _G.tContains
local bit = _G.bit
local GetMoneyString = _G.GetMoneyString
local GetCoinIcon = _G.GetCoinIcon
local GameTooltip = _G.GameTooltip
local BANK_BAG_PURCHASE = _G.BANK_BAG_PURCHASE
local COSTS_LABEL = _G.COSTS_LABEL
local ipairs = _G.ipairs
local pairs = _G.pairs
local CreateFrame = _G.CreateFrame
local UIParent = _G.UIParent
local UIDropDownMenu_CreateInfo = _G.UIDropDownMenu_CreateInfo
local UIDropDownMenu_AddButton = _G.UIDropDownMenu_AddButton
local UIDropDownMenu_Initialize = _G.UIDropDownMenu_Initialize
local C_Timer = _G.C_Timer

local BANK_SLOT_TEMPLATE = "ContainerFrameItemButtonTemplate"
local REAGENT_FLAG = Enum.BagSlotFlags and Enum.BagSlotFlags.ClassReagents or 0x80
local BANK_TYPE_CHARACTER = Enum.BankType and Enum.BankType.Character or 0
local BANK_TYPE_ACCOUNT = Enum.BankType and Enum.BankType.Account or 2

local BagSlotFlags = Enum.BagSlotFlags or {}
local DEPOSIT_FLAG_OPTIONS = {
	{ flag = BagSlotFlags.ClassReagents or 0x80, label = _G.BAG_FILTER_REAGENTS or "Reagents" },
	{ flag = BagSlotFlags.ClassEquipment or 0x2, label = _G.BAG_FILTER_EQUIPMENT or "Equipment" },
	{ flag = BagSlotFlags.ClassConsumables or 0x4, label = _G.BAG_FILTER_CONSUMABLES or "Consumables" },
	{ flag = BagSlotFlags.ClassProfessionGoods or 0x8, label = _G.BAG_FILTER_PROFESSION_GOODS or "Profession Goods" },
	{ flag = BagSlotFlags.ClassJunk or 0x10, label = _G.BAG_FILTER_JUNK or "Junk" },
	{ flag = BagSlotFlags.ClassQuestItems or 0x20, label = _G.BAG_FILTER_QUEST_ITEMS or "Quest Items" },
	{ flag = BagSlotFlags.ExpansionCurrent or 0x100, label = "Current Expansion" },
	{ flag = BagSlotFlags.ExpansionLegacy or 0x200, label = "Legacy Expansion" },
	{ flag = BagSlotFlags.DisableAutoSort or 0x1, label = _G.BAG_FILTER_IGNORE or "Ignore Clean Up" },
}

-- ####################################################################################################################
-- ##### Tab settings helpers #########################################################################################
-- ####################################################################################################################

local tabMenuFrame
local tabMenuBank
local tabMenuTabId

if not _G.StaticPopupDialogs["LUI_BANK_TAB_RENAME"] then
	_G.StaticPopupDialogs["LUI_BANK_TAB_RENAME"] = {
		text = "%s",
		button1 = _G.ACCEPT,
		button2 = _G.CANCEL,
		hasEditBox = true,
		maxLetters = 16,
		OnShow = function(self, data)
			local edit = self.GetEditBox and self:GetEditBox() or self.editBox
			if edit and data and data.name then
				edit:SetText(data.name)
				edit:HighlightText()
			end
		end,
		OnAccept = function(self, data)
			if not data or not data.bank or not C_Bank or not C_Bank.UpdateBankTabSettings then return end
			local edit = self.GetEditBox and self:GetEditBox() or self.editBox
			local newName = edit and edit:GetText()
			if not newName or newName == "" then return end
			local tabData = data.bank:GetPurchasedTabDataByID()[data.tabId]
			if not tabData then return end
			C_Bank.UpdateBankTabSettings(data.bank.bankType, data.tabId, newName, tabData.icon, tabData.depositFlags or 0)
			data.bank:UpdateTabBar()
		end,
		EditBoxOnEnterPressed = function(self)
			local parent = self:GetParent()
			local dialog = _G.StaticPopupDialogs[parent.which]
			if dialog and dialog.OnAccept then
				dialog.OnAccept(parent, parent.data)
			end
			parent:Hide()
		end,
		timeout = 0,
		whileDead = true,
		hideOnEscape = true,
		preferredIndex = 3,
	}
end

local function ToggleTabDepositFlag(bank, tabId, flag)
	if not bank or not tabId or not flag or not C_Bank or not C_Bank.UpdateBankTabSettings then return end
	local tabData = bank:GetPurchasedTabDataByID()[tabId]
	if not tabData then return end
	local flags = tabData.depositFlags or 0
	if bit.band(flags, flag) ~= 0 then
		flags = bit.band(flags, bit.bnot(flag))
	else
		flags = bit.bor(flags, flag)
	end
	C_Bank.UpdateBankTabSettings(bank.bankType, tabId, tabData.name, tabData.icon, flags)
	bank:UpdateTabBar()
end

local function ShowBlizzardTabSettings(bank, tabId)
	local panel = (bank.bankType == BANK_TYPE_ACCOUNT) and _G.AccountBankPanel or _G.BankPanel
	local menu = panel and panel.TabSettingsMenu
	if not menu then return false end

	-- TabSettingsMenu can open without leaving the full Blizzard bank visible.
	if menu.SetSelectedTab then
		menu:SetSelectedTab(tabId)
	elseif menu.selectedTabID ~= nil then
		menu.selectedTabID = tabId
	end
	if menu.Update then
		menu:Update()
	end
	menu:ClearAllPoints()
	menu:SetPoint("LEFT", bank, "RIGHT", 12, 0)
	-- Bypass BankPanel OnShow→Hide suppressor for this child if needed.
	menu:SetParent(UIParent)
	menu:Show()
	menu:Raise()
	return true
end

local function InitializeBankTabMenu(frame, level)
	if level ~= 1 then return end
	local bank, tabId = tabMenuBank, tabMenuTabId
	if not bank or not tabId then return end
	local tabData = bank:GetPurchasedTabDataByID()[tabId]
	if not tabData then return end

	local info = UIDropDownMenu_CreateInfo()

	info.text = tabData.name or "Bank Tab"
	info.isTitle = true
	info.notCheckable = true
	UIDropDownMenu_AddButton(info, level)

	info = UIDropDownMenu_CreateInfo()
	info.text = _G.EDIT or "Rename"
	info.notCheckable = true
	info.func = function()
		local header = tabData.tabNameEditBoxHeader or "Rename Bank Tab"
		_G.StaticPopup_Show("LUI_BANK_TAB_RENAME", header, nil, {
			bank = bank,
			tabId = tabId,
			name = tabData.name,
		})
	end
	UIDropDownMenu_AddButton(info, level)

	info = UIDropDownMenu_CreateInfo()
	info.text = "Deposit Filters"
	info.isTitle = true
	info.notCheckable = true
	UIDropDownMenu_AddButton(info, level)

	local flags = tabData.depositFlags or 0
	for i = 1, #DEPOSIT_FLAG_OPTIONS do
		local opt = DEPOSIT_FLAG_OPTIONS[i]
		if opt.flag and opt.flag ~= 0 then
			info = UIDropDownMenu_CreateInfo()
			info.text = opt.label
			info.checked = bit.band(flags, opt.flag) ~= 0
			info.isNotRadio = true
			info.func = function()
				ToggleTabDepositFlag(bank, tabId, opt.flag)
			end
			UIDropDownMenu_AddButton(info, level)
		end
	end

	if (_G.BankPanel and _G.BankPanel.TabSettingsMenu) or (_G.AccountBankPanel and _G.AccountBankPanel.TabSettingsMenu) then
		info = UIDropDownMenu_CreateInfo()
		info.text = " "
		info.disabled = true
		info.notCheckable = true
		UIDropDownMenu_AddButton(info, level)

		info = UIDropDownMenu_CreateInfo()
		info.text = "Blizzard Tab Settings"
		info.notCheckable = true
		info.func = function()
			ShowBlizzardTabSettings(bank, tabId)
		end
		UIDropDownMenu_AddButton(info, level)
	end
end

local function OpenBankTabMenu(bank, tabId, anchor)
	if not bank:IsTabPurchased(tabId) then return end
	tabMenuBank = bank
	tabMenuTabId = tabId
	if not tabMenuFrame then
		tabMenuFrame = CreateFrame("Frame", "LUIBankTabDropDown", UIParent, "UIDropDownMenuTemplate")
	end
	UIDropDownMenu_Initialize(tabMenuFrame, InitializeBankTabMenu, "MENU")
	_G.ToggleDropDownMenu(1, nil, tabMenuFrame, anchor, 0, 0)
end

-- ####################################################################################################################
-- ##### Shared tabbed-bank factory ###################################################################################
-- ####################################################################################################################

---@class TabbedBankConfig
---@field name string # AceDB / frame name key ("Bank" or "Warband")
---@field bankType number # Enum.BankType
---@field bagIds number[] # Enum.BagIndex tab IDs
---@field slotNameFormat string
---@field tabButtonFormat string
---@field cleanupButtonName string
---@field tabLabel string # Tooltip label prefix
---@field windowTitle string # Title shown on the container

local BagIndex = Enum.BagIndex or {}

--- Prefer enum fields; fall back to documented retail indices (6-11 / 12-16).
local CHARACTER_TAB_IDS = {
	BagIndex.CharacterBankTab_1 or 6,
	BagIndex.CharacterBankTab_2 or 7,
	BagIndex.CharacterBankTab_3 or 8,
	BagIndex.CharacterBankTab_4 or 9,
	BagIndex.CharacterBankTab_5 or 10,
	BagIndex.CharacterBankTab_6 or 11,
}

local ACCOUNT_TAB_IDS = {
	BagIndex.AccountBankTab_1 or 12,
	BagIndex.AccountBankTab_2 or 13,
	BagIndex.AccountBankTab_3 or 14,
	BagIndex.AccountBankTab_4 or 15,
	BagIndex.AccountBankTab_5 or 16,
}

-- Blizzard "tab bag" containers (hold DNT bank-tab bag items) — hide these; LUI owns tabs.
local BLIZZARD_TAB_BAG_IDS = {
	BagIndex.Characterbanktab or BagIndex.CharacterBankTab or -2,
	BagIndex.Accountbanktab or BagIndex.AccountBankTab or -3,
}

---@param cfg TabbedBankConfig
local function CreateTabbedBankContainer(cfg)
	local bankType = cfg.bankType
	local bagIds = cfg.bagIds

	local Bank = {
		NUM_BAG_IDS = #bagIds,
		BAG_ID_LIST = bagIds,
		name = cfg.name,
		bankType = bankType,
		windowTitle = cfg.windowTitle or cfg.tabLabel or cfg.name,
		activeTabId = nil,
		tabButtons = nil,
	}

	function Bank:OnShow()
	end

	function Bank:OnHide()
		module:MaybeCloseBankInteraction()
	end

	function Bank:GetPurchasedTabIDs()
		if not C_Bank or not C_Bank.FetchPurchasedBankTabIDs then
			return {}
		end
		return C_Bank.FetchPurchasedBankTabIDs(bankType) or {}
	end

	function Bank:GetPurchasedTabDataByID()
		local byID = {}
		if not C_Bank or not C_Bank.FetchPurchasedBankTabData then
			return byID
		end
		local data = C_Bank.FetchPurchasedBankTabData(bankType)
		if not data then
			return byID
		end
		for _, tab in ipairs(data) do
			if tab.ID then
				byID[tab.ID] = tab
			end
		end
		return byID
	end

	function Bank:IsTabPurchased(tabId)
		return tContains(self:GetPurchasedTabIDs(), tabId)
	end

	function Bank:CanView()
		if C_Bank and C_Bank.CanViewBank then
			return C_Bank.CanViewBank(bankType)
		end
		-- Fallback: purchased list non-nil/non-empty while at bank
		local ids = self:GetPurchasedTabIDs()
		return ids and #ids > 0
	end

	function Bank:GetActiveTabId()
		if self.activeTabId and self:IsTabPurchased(self.activeTabId) then
			return self.activeTabId
		end
		local purchased = self:GetPurchasedTabIDs()
		self.activeTabId = purchased[1] or self.BAG_ID_LIST[1]
		return self.activeTabId
	end

	function Bank:SetActiveTab(tabId)
		if not tabId or not self:IsTabPurchased(tabId) then
			return
		end
		self.activeTabId = tabId
		if self.db then
			self.db.ActiveTab = tabId
		end
		self:Layout()
		self:UpdateTabBar()
	end

	function Bank:Layout()
		local activeId = self:GetActiveTabId()

		for i = 1, self.NUM_BAG_IDS do
			local id = self.BAG_ID_LIST[i]
			local itemList = self.itemList[id]
			local bagFrame = self.bagList[id]
			if not itemList or not bagFrame then
				-- skip
			elseif id ~= activeId or not self:IsTabPurchased(id) then
				bagFrame:Hide()
				for j = 1, #itemList do
					if itemList[j] then
						itemList[j]:Hide()
					end
				end
			else
				local bagCount = C_Container.GetContainerNumSlots(id) or 0
				bagFrame:Show()
				for j = 1, bagCount do
					itemList[j] = self:NewItemSlot(id, j)
					self:SlotUpdate(itemList[j])
					itemList[j]:Show()
				end
				for j = bagCount + 1, #itemList do
					if itemList[j] then
						itemList[j]:Hide()
					end
				end
			end
		end

		self:SetAnchors()
		self:UpdateTabBar()

		if self.utilBar then
			self.utilBar:SetAnchors()
		end

		if self.editbox and self.editbox:IsShown() then
			self:SearchUpdate()
		end
	end

	function Bank:NewItemSlot(id, slot)
		if self.itemList[id] and self.itemList[id][slot] then
			return self.itemList[id][slot]
		end

		local name = format(cfg.slotNameFormat, id, slot)
		local itemSlot = module:CreateSlot(name, self.bagList[id], BANK_SLOT_TEMPLATE)
		itemSlot.id = id
		itemSlot.slot = slot
		itemSlot:SetID(slot)
		itemSlot:Show()
		self:SetItemSlotProperties(itemSlot)
		return itemSlot
	end

	function Bank:CreateBagBar()
		self.tabButtons = {}
		for i = 1, self.NUM_BAG_IDS do
			local tabId = self.BAG_ID_LIST[i]
			local name = format(cfg.tabButtonFormat, i)
			-- Empty template string is truthy; omit template so CreateSlot uses the default ItemButton template.
			local button = module:CreateSlot(name, self.bagsBar)
			button.tabId = tabId
			button.tabIndex = i
			button.container = self
			-- Keep ItemButton.icon; do not replace with a missing named global.
			button.icon = button.icon or button.Icon or _G[name.."IconTexture"]
			if module.itemBackdrop then
				button:SetBackdrop(module.itemBackdrop)
				button:SetBackdropColor(module:RGBA("ItemBackground"))
				button:SetBackdropBorderColor(module:RGBA("Border"))
			end
			button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
			button:SetScript("OnClick", function(btn, mouseButton)
				local bank = btn.container
				if mouseButton == "RightButton" then
					if bank:IsTabPurchased(btn.tabId) then
						OpenBankTabMenu(bank, btn.tabId, btn)
					end
					return
				end
				if bank:IsTabPurchased(btn.tabId) then
					bank:SetActiveTab(btn.tabId)
				elseif C_Bank and C_Bank.CanPurchaseBankTab and C_Bank.CanPurchaseBankTab(bankType) then
					C_Bank.PurchaseBankTab(bankType)
				end
			end)
			button:SetScript("OnEnter", function(btn)
				GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
				local tabData = btn.container:GetPurchasedTabDataByID()[btn.tabId]
				if tabData then
					GameTooltip:SetText(tabData.name or format("%s %d", cfg.tabLabel, btn.tabIndex))
					if tabData.depositFlags and bit.band(tabData.depositFlags, REAGENT_FLAG) ~= 0 then
						GameTooltip:AddLine("Reagents", 0.2, 0.8, 0.2)
					end
					GameTooltip:AddLine("Right-click to manage tab", 0.6, 0.6, 0.6)
				elseif C_Bank and C_Bank.CanPurchaseBankTab and C_Bank.CanPurchaseBankTab(bankType) then
					GameTooltip:SetText(BANK_BAG_PURCHASE or "Purchase Bank Tab")
					if C_Bank.FetchNextPurchasableBankTabCost then
						local cost = C_Bank.FetchNextPurchasableBankTabCost(bankType)
						if cost and GetMoneyString then
							GameTooltip:AddLine((COSTS_LABEL or "Cost:").." "..GetMoneyString(cost), 1, 1, 1)
						end
					end
				else
					GameTooltip:SetText(format("%s %d", cfg.tabLabel, btn.tabIndex))
					GameTooltip:AddLine("Locked", 0.6, 0.6, 0.6)
				end
				GameTooltip:Show()
			end)
			button:SetScript("OnLeave", _G.GameTooltip_Hide)

			self.bagsBar:AddNewButton(button)
			self.tabButtons[i] = button
		end
		self:UpdateTabBar()
	end

	function Bank:UpdateTabBar()
		if not self.tabButtons then return end

		local tabDataByID = self:GetPurchasedTabDataByID()
		local activeId = self:GetActiveTabId()
		local canPurchase = C_Bank and C_Bank.CanPurchaseBankTab and C_Bank.CanPurchaseBankTab(bankType)

		for i = 1, self.NUM_BAG_IDS do
			local button = self.tabButtons[i]
			local tabId = self.BAG_ID_LIST[i]
			local purchased = self:IsTabPurchased(tabId)
			local tabData = tabDataByID[tabId]
			local icon = button.icon

			if tabData and tabData.icon and icon then
				icon:SetTexture(tabData.icon)
			elseif icon then
				icon:SetTexture("Interface\\Icons\\INV_Misc_Bag_10")
			end

			if purchased then
				button:SetAlpha(tabId == activeId and 1 or 0.75)
				if tabData and tabData.depositFlags and bit.band(tabData.depositFlags, REAGENT_FLAG) ~= 0 then
					button:SetBackdropBorderColor(0.2, 0.8, 0.2, 1)
				else
					button:SetBackdropBorderColor(module:RGBA("Border"))
				end
			elseif canPurchase then
				local firstLocked = true
				for j = 1, i - 1 do
					if not self:IsTabPurchased(self.BAG_ID_LIST[j]) then
						firstLocked = false
						break
					end
				end
				button:SetAlpha(firstLocked and 1 or 0.25)
				if icon then
					if firstLocked and GetCoinIcon then
						icon:SetTexture(GetCoinIcon(1))
					elseif firstLocked then
						icon:SetTexture("Interface\\Icons\\INV_Misc_Coin_01")
					else
						icon:SetTexture("")
					end
				end
			else
				button:SetAlpha(0.2)
			end
		end

		if self.bagsBar and self.bagsBar.SetAnchors then
			self.bagsBar:SetAnchors()
		end
	end

	function Bank:CreateUtilBar()
		local utilBar = self.utilBar
		local sortFunc = function()
			if C_Container.SortBank then
				C_Container.SortBank(bankType)
			elseif bankType == BANK_TYPE_CHARACTER and C_Container.SortBankBags then
				C_Container.SortBankBags()
			end
		end
		local cleanUp = module:CreateCleanUpButton(cfg.cleanupButtonName, utilBar, sortFunc)
		utilBar:AddNewButton(cleanUp)

		local depositName = (cfg.name == "Warband") and "LUIWarband_Deposit" or "LUIBank_Deposit"
		local deposit = module:CreateBankDepositButton(depositName, utilBar, bankType)
		utilBar:AddNewButton(deposit)
	end

	function Bank:BankTabsUpdated()
		if self.db and self.db.ActiveTab and self:IsTabPurchased(self.db.ActiveTab) then
			self.activeTabId = self.db.ActiveTab
		end
		self:Layout()
	end

	return Bank
end

-- ####################################################################################################################
-- ##### Character Bank ###############################################################################################
-- ####################################################################################################################

module.BankContainer = CreateTabbedBankContainer({
	name = "Bank",
	bankType = BANK_TYPE_CHARACTER,
	bagIds = CHARACTER_TAB_IDS,
	slotNameFormat = "LUIBank_Item%d_%d",
	tabButtonFormat = "LUIBank_Tab%d",
	cleanupButtonName = "LUIBank_CleanUp",
	tabLabel = "Bank Tab",
	windowTitle = "Character Bank",
})

-- ####################################################################################################################
-- ##### Warband Bank (Account) #######################################################################################
-- ####################################################################################################################

module.WarbandContainer = CreateTabbedBankContainer({
	name = "Warband",
	bankType = BANK_TYPE_ACCOUNT,
	bagIds = ACCOUNT_TAB_IDS,
	slotNameFormat = "LUIWarband_Item%d_%d",
	tabButtonFormat = "LUIWarband_Tab%d",
	cleanupButtonName = "LUIWarband_CleanUp",
	tabLabel = "Warband Tab",
	windowTitle = "Warband Bank",
})

-- ####################################################################################################################
-- ##### Module open / close ##########################################################################################
-- ####################################################################################################################

local hasBankOpenBags = false

local function IsBlizzardTabBag(id)
	if id == nil then return false end
	for i = 1, #BLIZZARD_TAB_BAG_IDS do
		if BLIZZARD_TAB_BAG_IDS[i] == id then
			return true
		end
	end
	return false
end

--- Hide Blizzard bank chrome + the Characterbanktab / Accountbanktab "main bag" containers.
function module:SuppressBlizzardBankUI()
	local frames = {
		_G.BankFrame,
		_G.BankPanel,
		_G.AccountBankPanel,
	}
	for i = 1, #frames do
		local frame = frames[i]
		if frame then
			frame:UnregisterAllEvents()
			frame:Hide()
			if frame.SetScript then
				frame:SetScript("OnShow", function(f) f:Hide() end)
			end
		end
	end

	-- Close Blizzard's tab-bag containers if something opened them.
	for i = 1, #BLIZZARD_TAB_BAG_IDS do
		local bagId = BLIZZARD_TAB_BAG_IDS[i]
		if bagId and _G.CloseBag then
			_G.CloseBag(bagId)
		end
	end
end

local function RefreshBankContainer(frame)
	if not frame then return end
	if frame.db and frame.db.ActiveTab then
		frame.activeTabId = frame.db.ActiveTab
	end
	frame:Open()
	frame:BankTabsUpdated()
end

function module:MaybeCloseBankInteraction()
	local bankOpen = LUIBank and LUIBank:IsShown()
	local warbandOpen = LUIWarband and LUIWarband:IsShown()
	if not bankOpen and not warbandOpen and _G.CloseBankFrame then
		_G.CloseBankFrame()
	end
end

function module.OpenBank()
	module:SuppressBlizzardBankUI()

	if LUIBags and not LUIBags:IsShown() then
		hasBankOpenBags = true
		LUIBags:Open()
	end

	local showCharacter = not C_Bank or not C_Bank.CanViewBank or C_Bank.CanViewBank(BANK_TYPE_CHARACTER)
	local showWarband = C_Bank and C_Bank.CanViewBank and C_Bank.CanViewBank(BANK_TYPE_ACCOUNT)

	if showCharacter and LUIBank then
		RefreshBankContainer(LUIBank)
	elseif LUIBank then
		LUIBank:Hide()
	end

	if showWarband and LUIWarband then
		RefreshBankContainer(LUIWarband)
	elseif LUIWarband then
		LUIWarband:Hide()
	end

	-- Second pass after Blizzard finishes opening its frames.
	C_Timer.After(0, function()
		if module:IsEnabled() then
			module:SuppressBlizzardBankUI()
		end
	end)
end

function module.CloseBank()
	if hasBankOpenBags and LUIBags then
		LUIBags:Close()
		hasBankOpenBags = false
	end
	if LUIBank then
		LUIBank:Hide()
	end
	if LUIWarband then
		LUIWarband:Hide()
	end
end

-- Export helper for OpenBag / ToggleBag hook filtering.
function module:IsManagedBankBag(id)
	if id == nil then return false end
	if IsBlizzardTabBag(id) then return true end
	for i = 1, #CHARACTER_TAB_IDS do
		if CHARACTER_TAB_IDS[i] == id then return true end
	end
	for i = 1, #ACCOUNT_TAB_IDS do
		if ACCOUNT_TAB_IDS[i] == id then return true end
	end
	return false
end

module.IsBlizzardTabBag = IsBlizzardTabBag
