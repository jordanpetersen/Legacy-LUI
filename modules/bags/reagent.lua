-- ####################################################################################################################
-- ##### Retired: separate Reagent Bank ###############################################################################
-- ####################################################################################################################
-- Patch 11.2 removed the dedicated Reagent Bank (and Void Storage). Character bank tabs can be flagged for reagents
-- via Enum.BagSlotFlags.ClassReagents. Do not load this file; kept as a marker so old TOC / history is clear.
-- See modules/bags/bank.lua for the CharacterBankTab_* implementation.

---@class LUIAddon
local LUI = select(2, ...)

---@class LUI.Bags
local module = LUI:GetModule("Bags")

-- Intentionally empty. module.BankReagentContainer is no longer created.
module.BankReagentContainer = nil
