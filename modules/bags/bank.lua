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

local BANK_SLOT_TEMPLATE = "ContainerFrameItemButtonTemplate"
local REAGENT_FLAG = Enum.BagSlotFlags and Enum.BagSlotFlags.ClassReagents or 0x80
local BANK_TYPE_CHARACTER = Enum.BankType and Enum.BankType.Character or 0
local BANK_TYPE_ACCOUNT = Enum.BankType and Enum.BankType.Account or 2

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

---@param cfg TabbedBankConfig
local function CreateTabbedBankContainer(cfg)
	local bankType = cfg.bankType
	local bagIds = cfg.bagIds

	local Bank = {
		NUM_BAG_IDS = #bagIds,
		BAG_ID_LIST = bagIds,
		name = cfg.name,
		bankType = bankType,
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
			local button = module:CreateSlot(name, self.bagsBar, "")
			button.tabId = tabId
			button.tabIndex = i
			button.container = self
			button.icon = _G[name.."IconTexture"]
			button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
			button:SetScript("OnClick", function(btn)
				local bank = btn.container
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
		local button = module:CreateCleanUpButton(cfg.cleanupButtonName, utilBar, sortFunc)
		utilBar:AddNewButton(button)
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
	bagIds = {
		Enum.BagIndex.CharacterBankTab_1,
		Enum.BagIndex.CharacterBankTab_2,
		Enum.BagIndex.CharacterBankTab_3,
		Enum.BagIndex.CharacterBankTab_4,
		Enum.BagIndex.CharacterBankTab_5,
		Enum.BagIndex.CharacterBankTab_6,
	},
	slotNameFormat = "LUIBank_Item%d_%d",
	tabButtonFormat = "LUIBank_Tab%d",
	cleanupButtonName = "LUIBank_CleanUp",
	tabLabel = "Bank Tab",
})

-- ####################################################################################################################
-- ##### Warband Bank (Account) #######################################################################################
-- ####################################################################################################################

module.WarbandContainer = CreateTabbedBankContainer({
	name = "Warband",
	bankType = BANK_TYPE_ACCOUNT,
	bagIds = {
		Enum.BagIndex.AccountBankTab_1,
		Enum.BagIndex.AccountBankTab_2,
		Enum.BagIndex.AccountBankTab_3,
		Enum.BagIndex.AccountBankTab_4,
		Enum.BagIndex.AccountBankTab_5,
	},
	slotNameFormat = "LUIWarband_Item%d_%d",
	tabButtonFormat = "LUIWarband_Tab%d",
	cleanupButtonName = "LUIWarband_CleanUp",
	tabLabel = "Warband Tab",
})

-- ####################################################################################################################
-- ##### Module open / close ##########################################################################################
-- ####################################################################################################################

local hasBankOpenBags = false

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
