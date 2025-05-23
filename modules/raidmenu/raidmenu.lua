-- This module creates a menu containing all the raid markers, world pillars and other raid/party commands
--- @TODO: Fully use Secure Handlers to allow for it to be used in combat..

-- ####################################################################################################################
-- ##### Setup and Locals #############################################################################################
-- ####################################################################################################################

---@class LUIAddon
local LUI = select(2, ...)
local L = LUI.L

---@class LUI.RaidMenu
local module = LUI:GetModule("RaidMenu")
local db, dbd

local Panels = LUI:GetModule("Panels", true)
local Micromenu = LUI:GetModule("Micromenu", true) --[[@as LUI.Micromenu]]
local Media = LibStub("LibSharedMedia-3.0")

local GetRaidTargetIndex = _G.GetRaidTargetIndex
local GetNumGroupMembers = _G.GetNumGroupMembers
local SetRaidTargetIcon = _G.SetRaidTargetIcon
local InCombatLockdown = _G.InCombatLockdown
local GetLootThreshold = _G.GetLootThreshold
local SetLootThreshold = _G.SetLootThreshold
local InitiateRolePoll = _G.InitiateRolePoll
local ConvertToParty = _G.ConvertToParty
local ConvertToRaid = _G.ConvertToRaid
local GetLootMethod = _G.GetLootMethod
local SetLootMethod = _G.SetLootMethod
local SetRaidTarget = _G.SetRaidTarget
local DoReadyCheck = _G.DoReadyCheck
local IsInRaid = _G.IsInRaid
local EasyMenu = _G.EasyMenu

-- Frame placeholders
local RaidMenu_Header, RaidMenu_Parent, RaidMenu_Border, RaidMenu_BG, RaidMenu
local SkullRaidIcon, CrossRaidIcon, SquareRaidIcon, MoonRaidIcon, TriangleRaidIcon
local DiamondRaidIcon, CircleRaidIcon, StarRaidIcon, ClearRaidIcon
local BlueWorldMarker, GreenWorldMarker, PurpleWorldMarker, RedWorldMarker, YellowWorldMarker
local OrangeWorldMarker, SilverWorldMarker, WhiteWorldMarker, ClearWorldMarkers
local ConvertRaid, LootMethod, LootThreshold, RoleChecker, ReadyChecker

local RAIDMENU_NORMAL_TEXTURE = "Interface\\AddOns\\LUI\\media\\templates\\v3\\raidmenu"
local RAIDMENU_BG_TEXTURE = "Interface\\AddOns\\LUI\\media\\templates\\v3\\raidmenu_bg"
local RAIDMENU_BORDER_TEXTURE = "Interface\\AddOns\\LUI\\media\\templates\\v3\\raidmenu_border"
LUI.Versions.raidmenu = 2.4

local Y_normal, Y_compact = 107, 101
local X_normal, X_compact = 0, -50
local OverlapPreventionMethods = {"AutoHide", "Offset"}

-- ####################################################################################################################
-- ##### Module Functions #############################################################################################
-- ####################################################################################################################

local function MarkTarget(iconId)
	if db.ToggleRaidIcon then
		SetRaidTargetIcon("target", iconId)
	elseif (GetRaidTargetIndex("target") ~= iconId) then
		SetRaidTarget("target", iconId)
	end
end

function module:OverlapPrevention(frame, action)
	local Y_Position = Y_normal
	local X_Position = X_compact
	if db.Compact then
		Y_Position = Y_compact + (db.Spacing / 2)
		X_Position = X_compact + (db.Spacing / 2)
	end

	local offset, x_offset = 0, 0
	if db.OverlapPrevention == "Offset" and Panels.db.profile.MicroMenu.IsShown then
		offset = db.Offset
		x_offset = db.X_Offset
	end

	if frame == "RM" and db.Enable and not InCombatLockdown() then
		if action == "toggle" then
			if RaidMenu_Parent:IsShown() then
				RaidMenu.AlphaOut:Show()
			else
				if db.OverlapPrevention == "AutoHide" and Panels.db.profile.MicroMenu.IsShown then
					Micromenu.clickerMiddle:Click()
				end
				RaidMenu_Parent:SetPoint("TOPRIGHT", Micromenu.buttonLeft, "BOTTOMRIGHT", (((X_Position + x_offset) / db.Scale) + 17), (((Y_Position + offset) / db.Scale) + 17))
				RaidMenu.AlphaIn:Show()
			end
		elseif action == "slide" then
			if Panels.db.profile.MicroMenu.IsShown then
				RaidMenu.SlideUp:Show()
			else
				RaidMenu.SlideDown:Show()
			end
		elseif action == "position" then
			RaidMenu_Parent:Show()
			RaidMenu_Parent:SetAlpha(db.Opacity / 100)
			if Panels.db.profile.MicroMenu.IsShown then
				if db.OverlapPrevention == "AutoHide" then
					Micromenu.clickerMiddle:Click()
				end
			else
				if db.OverlapPrevention == "Offset" then
					Micromenu.clickerMiddle:Click()
					offset = db.Offset
					x_offset = db.X_Offset
				end
			end
			RaidMenu_Parent:SetPoint("TOPRIGHT", Micromenu.buttonLeft, "BOTTOMRIGHT", (((X_Position + x_offset) / db.Scale) + 17), (((Y_Position + offset) / db.Scale) + 17))
		end
	elseif frame == "MM" then
		if Panels.db.profile.MicroMenu.IsShown then
			if db.OverlapPrevention == "Offset" then
				RaidMenu.SlideUp:Show()
			end
		else
			if db.OverlapPrevention == "AutoHide" then
				if RaidMenu_Parent:IsShown() then
					Micromenu.clickerLeft:Click()
				end
			else
				RaidMenu.SlideDown:Show()
			end
		end
	end
end

local function FormatMarker(frame, x, y, r, g, b, id, t1, t2, t3, t4)
	if not frame then return end
	local width, height
	if db.Compact then
		width, height = 24, 24
	else
		width, height = 32, 32
	end
	frame:SetSize(width, height)
	frame:SetScale(1)
	frame:SetFrameStrata("HIGH")
	frame:SetFrameLevel(4)
	frame:SetPoint("TOPLEFT", RaidMenu_Parent, "TOPLEFT", x, y)
	frame:SetAlpha(0.6)
	frame:RegisterForClicks("AnyUp")

	if string.find(frame:GetName(), "WorldMarker") then
		frame:SetAttribute("type", "worldmarker")
		frame:SetAttribute("marker", id)
		if id == 9 then
			frame:SetAttribute("action", "clear")
		else
			frame:SetAttribute("action1", "set")
			frame:SetAttribute("action2", "clear")
		end

		local texture = _G[frame:GetName().."MarkerTex"]
		if not texture then
			texture = frame:CreateTexture(frame:GetName().."MarkerTex")
		end
		texture:SetPoint("TOPLEFT", frame,"TOPLEFT",0,0)
		texture:SetSize(width, height)
		texture:SetTexture("Interface\\Buttons\\UI-Quickslot")
		texture:SetTexCoord(0.15, 0.85, 0.15, 0.85)
		if frame:GetName() == "ClearWorldMarkers" then
			texture:SetTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Up")
			texture:SetTexCoord(0, 1, 0, 1)
		else
			local textureColor = _G[frame:GetName().."TextureColor"]
			if not textureColor then
				textureColor = frame:CreateTexture(frame:GetName().."TextureColor")
			end
			textureColor:SetPoint("TOPLEFT", frame, "TOPLEFT", 4, -4)
			textureColor:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -4, 4)
			textureColor:SetColorTexture(r, g, b)
		end

	elseif string.find(frame:GetName(), "RaidIcon") then
		frame:SetID(id)
		frame:SetScript("OnClick", function(self)
			if db.AutoHide then
				Micromenu.clickerLeft:Click()
			end
			MarkTarget(frame:GetID())
		end)

		local texture = _G[frame:GetName().."MarkerTex"]
		if not texture then
			texture = frame:CreateTexture(frame:GetName().."MarkerTex")
		end
		texture:SetPoint("TOPLEFT", frame, "TOPLEFT", 2, -2)
		texture:SetSize(width - 4, height - 4)
		if frame:GetName() == "ClearRaidIcon" then
			texture:SetTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Up")
		else
			texture:SetTexture("Interface\\AddOns\\LUI\\media\\textures\\icons\\raidicons.blp")
			--texture:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
		end
		texture:SetTexCoord(t1, t2, t3, t4)

	else
		if db.Compact then
			width = 100 + (db.Spacing * 3)
		else
			width = 120
		end
		frame:SetSize(width, LUI:Scale(20))
		frame:SetAlpha(1)
	end
end

local function SizeRaidMenu(compact)
	if not compact then compact = db.Compact end
	if compact then
		local x_spacing = db.Spacing
		local y_spacing = -db.Spacing
		local frameWidth =  190 + db.Spacing * 6
		local frameHeight = 210 + db.Spacing * 6
		RaidMenu_Parent:SetSize(frameWidth, frameHeight)
		RaidMenu_BG:SetSize(frameWidth, frameHeight)
		RaidMenu:SetSize(frameWidth, frameHeight)
		RaidMenu_Border:SetSize(frameWidth, frameHeight)
		RaidMenu_Header:Hide()

	--	FormatMarker(frame,             x,                    y,                     r,   g,   b,  id, t1,   t2,   t3,   t4)
		-- Raid Icons
		FormatMarker(SkullRaidIcon,     15,                   -75  + y_spacing * 2,  0,   0,   0,   8, 0.75, 1,    0.25, 0.5)
		FormatMarker(CrossRaidIcon,     15,                   -100 + y_spacing * 3,  0,   0,   0,   7, 0.5,  0.75, 0.25, 0.5)
		FormatMarker(SquareRaidIcon,    15,                   -125 + y_spacing * 4,  0,   0,   0,   6, 0.25, 0.5,  0.25, 0.5)
		FormatMarker(MoonRaidIcon,      15,                   -150 + y_spacing * 5,  0,   0,   0,   5, 0,    0.25, 0.25, 0.5)
		FormatMarker(TriangleRaidIcon,  40   + x_spacing,     -75  + y_spacing * 2,  0,   0,   0,   4, 0.75, 1,    0,    0.25)
		FormatMarker(DiamondRaidIcon,   40   + x_spacing,     -100 + y_spacing * 3,  0,   0,   0,   3, 0.5,  0.75, 0,    0.25)
		FormatMarker(CircleRaidIcon,    40   + x_spacing,     -125 + y_spacing * 4,  0,   0,   0,   2, 0.25, 0.5,  0,    0.25)
		FormatMarker(StarRaidIcon,      40   + x_spacing,     -150 + y_spacing * 5,  0,   0,   0,   1, 0,    0.25, 0,    0.25)
		FormatMarker(ClearRaidIcon,     27.5 + x_spacing / 2, -175 + y_spacing * 6,  0,   0,   0,   0, 0,    1,    0,    1)
		-- Markers
		FormatMarker(BlueWorldMarker,   30,                   -25,                   0,   0.4, 0.9, 1) -- 0.00, 0.44, 0.87
		FormatMarker(GreenWorldMarker,  55  + x_spacing,      -25,                   0.1, 1,   0,   2) -- 0.12, 1.00, 0.00
		FormatMarker(PurpleWorldMarker, 80  + x_spacing * 2,  -25,                   0.6, 0.2, 0.9, 3) -- 0.64, 0.21, 0.93
		FormatMarker(RedWorldMarker,    105 + x_spacing * 3,  -25,                   1,   0.1, 0.1, 4) -- 1.00, 0.13, 0.13
		FormatMarker(YellowWorldMarker, 30,                   -50   + y_spacing,     1,   1,   0,   5) -- 1.00, 1.00, 0.00
		FormatMarker(OrangeWorldMarker, 55  + x_spacing,      -50   + y_spacing,     1,   0.5, 0.2, 6) -- 1.00, 0.50, 0.25
		FormatMarker(SilverWorldMarker, 80  + x_spacing * 2,  -50   + y_spacing,     0.7, 0.7, 0.7, 7) -- 0.67, 0.67, 0.67
		FormatMarker(WhiteWorldMarker,  105 + x_spacing * 3,  -50   + y_spacing,     1,   1,   1,   8) -- 1.00, 1.00, 1.00
		FormatMarker(ClearWorldMarkers, 130 + x_spacing * 4,  -37.5 + y_spacing / 2, 0,   0,   0,   9)
		-- Buttons
		FormatMarker(ReadyChecker,      65 + x_spacing * 2,   -75   + y_spacing * 2)
		FormatMarker(RoleChecker,       65 + x_spacing * 2,   -100  + y_spacing * 3)
		FormatMarker(ConvertRaid,       65 + x_spacing * 2,   -125  + y_spacing * 4)
		FormatMarker(LootMethod,        65 + x_spacing * 2,   -150  + y_spacing * 5)
		FormatMarker(LootThreshold,     65 + x_spacing * 2,   -175  + y_spacing * 6)

	else
		local frameWidth = 256
		local frameHeight = 291
		RaidMenu_Parent:SetSize(frameWidth, frameHeight)
		RaidMenu_BG:SetSize(frameWidth, frameHeight)
		RaidMenu:SetSize(frameWidth, frameHeight)
		RaidMenu_Border:SetSize(frameWidth, frameHeight)
		RaidMenu_Header:Show()
	--	FormatMarker(frame,             x,   y,    r,   g,   b,  id, t1,   t2,   t3,   t4)
		FormatMarker(SkullRaidIcon,     20,  -50,  0,   0,   0,   8, 0.75, 1,    0.25, 0.5)
		FormatMarker(CrossRaidIcon,     20,  -90,  0,   0,   0,   7, 0.5,  0.75, 0.25, 0.5)
		FormatMarker(SquareRaidIcon,    20,  -130, 0,   0,   0,   6, 0.25, 0.5,  0.25, 0.5)
		FormatMarker(MoonRaidIcon,      20,  -170, 0,   0,   0,   5, 0,    0.25, 0.25, 0.5)
		FormatMarker(TriangleRaidIcon,  60,  -50,  0,   0,   0,   4, 0.75, 1,    0,    0.25)
		FormatMarker(DiamondRaidIcon,   60,  -90,  0,   0,   0,   3, 0.5,  0.75, 0,    0.25)
		FormatMarker(CircleRaidIcon,    60,  -130, 0,   0,   0,   2, 0.25, 0.5,  0,    0.25)
		FormatMarker(StarRaidIcon,      60,  -170, 0,   0,   0,   1, 0,    0.25, 0,    0.25)
		FormatMarker(ClearRaidIcon,     40,  -210, 0,   0,   0,   0, 0,    1,    0,    1)
		FormatMarker(BlueWorldMarker,   110, -175, 0,   0.4, 0.9, 1)
		FormatMarker(GreenWorldMarker,  145, -175, 0.1, 1,   0,   2)
		FormatMarker(PurpleWorldMarker, 180, -175, 0.6, 0.2, 0.9, 3)
		FormatMarker(RedWorldMarker,    110, -210, 1,   0.1, 0.1, 4)
		FormatMarker(YellowWorldMarker, 145, -210, 1,   1,   0,   5)
		FormatMarker(OrangeWorldMarker, 180, -210, 1,   0.5, 0.2, 6)
		FormatMarker(SilverWorldMarker, 110, -245, 0.7, 0.7, 0.7, 7)
		FormatMarker(WhiteWorldMarker,  145, -245, 1,   1,   1,   8)
		FormatMarker(ClearWorldMarkers, 180, -245, 0,   0,   0,   9)
		FormatMarker(ReadyChecker,      105, -50)
		FormatMarker(RoleChecker,       105, -75)
		FormatMarker(ConvertRaid,       105, -100)
		FormatMarker(LootMethod,        105, -125)
		FormatMarker(LootThreshold,     105, -150)
	end
end

function module:SetColors()
	if not db.Enable or not Micromenu then return end
	RaidMenu_Parent:SetBackdropColor(Micromenu:RGB("Background"))
	RaidMenu:SetBackdropColor(Micromenu:RGB("Background"))
	RaidMenu_Border:SetBackdropColor(Micromenu:RGB("Micromenu"))
end

function module:SetRaidMenu()
	db, dbd = module.db.profile, module.db.defaults.profile

	if not db.Enable or not Micromenu or not Panels then return end

	-- Create frames for Raid Menu
	RaidMenu_Parent = LUI:CreateMeAFrame("Frame", "RaidMenu_Parent", Micromenu.buttonLeft, 256, 256, 1, "HIGH", 0, "TOPRIGHT", Micromenu.buttonLeft, "BOTTOMRIGHT", X_normal, ((Y_normal / db.Scale) + 17), 1)
	if Panels.db.profile.MicroMenu.IsShown and db.OverlapPrevention == "Offset" then
		RaidMenu_Parent:SetPoint("TOPRIGHT", Micromenu.buttonLeft, "BOTTOMRIGHT", X_normal, (((Y_normal + db.Offset) / db.Scale) + 17))
	else
		RaidMenu_Parent:SetPoint("TOPRIGHT", Micromenu.buttonLeft, "BOTTOMRIGHT", X_normal, ((Y_normal / db.Scale) + 17))
	end
	RaidMenu_Parent:SetScale(db.Scale)
	RaidMenu_Parent:Hide()

	RaidMenu_BG = LUI:CreateMeAFrame("Frame", "RaidMenu_BG", RaidMenu_Parent, 256, 256, 1, "HIGH", 1, "TOPRIGHT", RaidMenu_Parent, "TOPRIGHT", 0, 0, 1)
	RaidMenu_BG:SetBackdrop({
		bgFile = RAIDMENU_BG_TEXTURE,
		edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",
		tile=false, tileSize = 0, edgeSize = 1,
		insets = {left = 0, right = 0, top = 0, bottom = 0}
	})
	RaidMenu_BG:SetBackdropColor(Micromenu:RGB("Background"))
	RaidMenu_BG:SetBackdropBorderColor(0, 0, 0, 0)

	RaidMenu = LUI:CreateMeAFrame("Frame", "RaidMenu", RaidMenu_Parent, 256, 256, 1, "HIGH", 2, "TOPRIGHT", RaidMenu_Parent, "TOPRIGHT", 0, 0, 1)
	RaidMenu:SetBackdrop({
		bgFile = RAIDMENU_NORMAL_TEXTURE,
		edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",
		tile=false, tileSize = 0, edgeSize = 1,
		insets = {left = 0, right = 0, top = 0, bottom = 0}
	})
	RaidMenu:SetBackdropColor(Micromenu:RGB("Background"))
	RaidMenu:SetBackdropBorderColor(0, 0, 0, 0)

	local micro_r, micro_g, micro_b = Micromenu:RGB("Micromenu")
	RaidMenu_Border = LUI:CreateMeAFrame("Frame", "RaidMenu_Border", RaidMenu_Parent, 256, 256, 1, "HIGH", 3, "TOPRIGHT", RaidMenu_Parent, "TOPRIGHT", 2, 1, 1)
	RaidMenu_Border:SetBackdrop({
		bgFile = RAIDMENU_BORDER_TEXTURE,
		edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",
		tile=false, tileSize = 0, edgeSize = 1,
		insets = {left = 0, right = 0, top = 0, bottom = 0}
	})
	RaidMenu_Border:SetBackdropColor(micro_r, micro_g, micro_b, 1)
	RaidMenu_Border:SetBackdropBorderColor(0, 0, 0, 0)

	local Infotext = LUI:GetModule("Infotext", true)
	local font = Infotext and Infotext.db.profile.Clock.Font or "vibroceb"
	local color = Infotext and Infotext.db.profile.Clock.Color or {r = 1, g = 1, b = 1, a = 1}
	RaidMenu_Header = RaidMenu:CreateFontString("RaidMenu_Header", "OVERLAY")
	RaidMenu_Header:SetFont(Media:Fetch("font", font), LUI:Scale(20), "THICKOUTLINE")
	RaidMenu_Header:SetPoint("TOP", RaidMenu, "TOP", -5, -25)
	RaidMenu_Header:SetTextColor(color.r, color.g, color.b, color.a)
	RaidMenu_Header:SetText("LUI Raid Menu")

	-- Create frame for dropdown lists to access
	local LootMenuFrame = CreateFrame("Frame", "LootDropDownMenu", RaidMenu_Parent, "UIDropDownMenuTemplate")

	-- Create buttons for Raid Menu
	SkullRaidIcon = CreateFrame("Button", "SkullRaidIcon", RaidMenu, "MarkerTemplate")
	CrossRaidIcon = CreateFrame("Button", "CrossRaidIcon", RaidMenu, "MarkerTemplate")
	SquareRaidIcon = CreateFrame("Button", "SquareRaidIcon", RaidMenu, "MarkerTemplate")
	MoonRaidIcon = CreateFrame("Button", "MoonRaidIcon", RaidMenu, "MarkerTemplate")
	TriangleRaidIcon = CreateFrame("Button", "TriangleRaidIcon", RaidMenu, "MarkerTemplate")
	DiamondRaidIcon = CreateFrame("Button", "DiamondRaidIcon", RaidMenu, "MarkerTemplate")
	CircleRaidIcon = CreateFrame("Button", "CircleRaidIcon", RaidMenu, "MarkerTemplate")
	StarRaidIcon = CreateFrame("Button", "StarRaidIcon", RaidMenu, "MarkerTemplate")
	ClearRaidIcon = CreateFrame("Button", "ClearRaidIcon", RaidMenu, "MarkerTemplate")
	BlueWorldMarker = CreateFrame("Button", "BlueWorldMarker", RaidMenu, "SecureMarkerTemplate")
	GreenWorldMarker = CreateFrame("Button", "GreenWorldMarker", RaidMenu, "SecureMarkerTemplate")
	PurpleWorldMarker = CreateFrame("Button", "PurpleWorldMarker", RaidMenu, "SecureMarkerTemplate")
	RedWorldMarker = CreateFrame("Button", "RedWorldMarker", RaidMenu, "SecureMarkerTemplate")
	YellowWorldMarker = CreateFrame("Button", "YellowWorldMarker", RaidMenu, "SecureMarkerTemplate")
	WhiteWorldMarker = CreateFrame("Button", "WhiteWorldMarker", RaidMenu, "SecureMarkerTemplate")
	OrangeWorldMarker = CreateFrame("Button", "OrangeWorldMarker", RaidMenu, "SecureMarkerTemplate")
	SilverWorldMarker = CreateFrame("Button", "SilverWorldMarker", RaidMenu, "SecureMarkerTemplate")
	ClearWorldMarkers = CreateFrame("Button", "ClearWorldMarkers", RaidMenu, "SecureMarkerTemplate")

	ConvertRaid = CreateFrame("Button", "ConvertRaid", RaidMenu, "UIPanelButtonTemplate")
	if GetNumGroupMembers() > 0 then
		ConvertRaid:SetText("Convert to Party")
	else
		ConvertRaid:SetText("Convert to Raid")
	end
	local monitoredEvents = {"GROUP_ROSTER_UPDATE", "PARTY_LEADER_CHANGED"}
	-- "PARTY_CONVERTED_TO_RAID",
	for i = 1, #monitoredEvents do
		ConvertRaid:RegisterEvent(monitoredEvents[i])
	end
	ConvertRaid:SetScript("OnEvent", function(self, event)
		if GetNumGroupMembers() > 0 then
			ConvertRaid:SetText("Convert to Party")
		else
			ConvertRaid:SetText("Convert to Raid")
		end
	end)

	ConvertRaid:SetScript("OnEnter", function(self)
		if db.ShowToolTips then
			GameTooltip:SetOwner(ConvertRaid, "ANCHOR_BOTTOMLEFT")
			GameTooltip:SetClampedToScreen(true)
			GameTooltip:ClearLines()
			if GetNumGroupMembers() > 0 then
				GameTooltip:SetText("Convert to Party")
				GameTooltip:AddLine("Convert your Raid Group into a 5 man party", 204/255,204/255, 204/255, 1)
				GameTooltip:AddLine("Only works with raid groups of 5 or less members!", 204/255, 204/255, 204/255, 1)
			else
				GameTooltip:SetText("Convert to Raid")
				GameTooltip:AddLine("Convert your party into a Raid Group", 204/255, 204/255, 204/255, 1)
			end
			GameTooltip:Show()
		end
	end)
	ConvertRaid:SetScript("OnLeave", function(self)
		GameTooltip:Hide()
	end)
	ConvertRaid:SetScript("OnClick", function(self)
		if GetNumGroupMembers() > 0 and not IsInRaid() then
			ConvertToParty()
		else
			ConvertToRaid()
		end
		if db.AutoHide then
			Micromenu.clickerLeft:Click()
		end
	end)

	if not LUI.IsRetail then
		LootMethod = CreateFrame("Button", "LootMethod", RaidMenu, "UIPanelButtonTemplate")
		LootMethod:SetText("Loot Method")
		LootMethod:SetScript("OnEnter", function(self)
			if db.ShowToolTips then
				GameTooltip:SetOwner(LootMethod,"ANCHOR_BOTTOMLEFT")
				GameTooltip:SetClampedToScreen(true)
				GameTooltip:ClearLines()
				GameTooltip:SetText("Loot Method")
				GameTooltip:AddLine("Change the Loot Method for your group", 204/255, 204/255, 204/255, 1)
				GameTooltip:Show()
			end
		end)
		LootMethod:SetScript("OnLeave", function(self)
			GameTooltip:Hide()
		end)
		LootMethod:SetScript("OnClick", function(self)
			local LootMethodList = {
				{text = "Group Loot",
				checked = (GetLootMethod() == "group"),
				func = function() SetLootMethod("group") if db.AutoHide then Micromenu.clickerLeft:Click() end end},
				{text = "Free-For-All",
				checked = (GetLootMethod() == "freeforall"),
				func = function() SetLootMethod("freeforall") if db.AutoHide then Micromenu.clickerLeft:Click() end end},
				{text = "Master Looter",
				checked = (GetLootMethod() == "master"),
				func = function() SetLootMethod("master", "player") if db.AutoHide then Micromenu.clickerLeft:Click() end end},
				{text = "Need Before Greed",
				checked = (GetLootMethod() == "needbeforegreed"),
				func = function() SetLootMethod("needbeforegreed") if db.AutoHide then Micromenu.clickerLeft:Click() end end},
				{text = "Round Robin",
				checked = (GetLootMethod() == "roundrobin"),
				func = function() SetLootMethod("roundrobin") if db.AutoHide then Micromenu.clickerLeft:Click() end end}
			}
			EasyMenu(LootMethodList, LootMenuFrame, "cursor", 0, 0, "MENU", 1)
		end)

		LootThreshold = CreateFrame("Button", "LootThreshold", RaidMenu, "UIPanelButtonTemplate")
		LootThreshold:SetText("Loot Threshold")
		LootThreshold:SetScript("OnEnter", function(self)
			if db.ShowToolTips then
				GameTooltip:SetOwner(LootThreshold, "ANCHOR_BOTTOMLEFT")
				GameTooltip:SetClampedToScreen(true)
				GameTooltip:ClearLines()
				GameTooltip:SetText("Loot Threshold")
				GameTooltip:AddLine("Change the Loot Threshold for your group", 204/255, 204/255, 204/255, 1)
				GameTooltip:Show()
			end
		end)
		LootThreshold:SetScript("OnLeave", function(self)
			GameTooltip:Hide()
		end)
		LootThreshold:SetScript("OnClick", function(self)
			local LootThresholdList = {
				{text = "|cff1EFF00Uncommon|r",
				checked = (GetLootThreshold() == 2),
				func = function() SetLootThreshold("2") if db.AutoHide then Micromenu.clickerLeft:Click() end end},
				{text = "|cff0070FFRare|r",
				checked = (GetLootThreshold() == 3),
				func = function() SetLootThreshold("3") if db.AutoHide then Micromenu.clickerLeft:Click() end end},
				{text = "|cffA335EEEpic|r",
				checked = (GetLootThreshold() == 4),
				func = function() SetLootThreshold("4") if db.AutoHide then Micromenu.clickerLeft:Click() end end},
				{text = "|cffFF8000Legendary|r",
				checked = (GetLootThreshold() == 5),
				func = function() SetLootThreshold("5") if db.AutoHide then Micromenu.clickerLeft:Click() end end}
			}
			EasyMenu(LootThresholdList, LootMenuFrame, "cursor", 0, 0, "MENU", 1)
		end)
	end

	RoleChecker = CreateFrame("BUTTON", "RoleChecker", RaidMenu, "UIPanelButtonTemplate")
	RoleChecker:SetText("Role Check")
	RoleChecker:SetScript("OnEnter", function(self)
		if db.ShowToolTips then
			GameTooltip:SetOwner(RoleChecker, "ANCHOR_BOTTOMLEFT")
			GameTooltip:SetClampedToScreen(true)
			GameTooltip:ClearLines()
			GameTooltip:SetText("Role Check")
			GameTooltip:AddLine("Perform a Role Check", 204/255, 204/255, 204/255, 1)
			GameTooltip:Show()
		end
	end)
	RoleChecker:SetScript("OnLeave", function(self)
		GameTooltip:Hide()
	end)
	RoleChecker:SetScript("OnClick", function(self)
		InitiateRolePoll()
		if db.AutoHide then
			Micromenu.clickerLeft:Click()
		end
	end)

	ReadyChecker = CreateFrame("Button", "ReadyChecker", RaidMenu, "UIPanelButtonTemplate")
	ReadyChecker:SetText("Ready Check")
	ReadyChecker:SetScript("OnEnter", function(self)
		if db.ShowToolTips then
			GameTooltip:SetOwner(ReadyChecker, "ANCHOR_BOTTOMLEFT")
			GameTooltip:SetClampedToScreen(true)
			GameTooltip:ClearLines()
			GameTooltip:SetText("Ready Check")
			GameTooltip:AddLine("Perform a Ready Check", 204/255, 204/255, 204/255, 1)
			GameTooltip:Show()
		end
	end)
	ReadyChecker:SetScript("OnLeave", function(self)
		GameTooltip:Hide()
	end)
	ReadyChecker:SetScript("OnClick", function(self)
		DoReadyCheck()
		if db.AutoHide then
			Micromenu.clickerLeft:Click()
		end
	end)

	-- Create fader frames
	RaidMenu.AlphaOut = CreateFrame("Frame", nil, UIParent)
	RaidMenu.AlphaOut.timer = 0
	RaidMenu.AlphaOut:Hide()

	RaidMenu.AlphaOut:SetScript("OnUpdate", function(self,elapsed)
		self.timer = self.timer + elapsed
		if self.timer < .5 then
			RaidMenu_Parent:SetAlpha((1 - self.timer / .5) * (db.Opacity / 100))
		else
			RaidMenu_Parent:SetAlpha(0)
			RaidMenu_Parent:Hide()
			self.timer = 0
			self:Hide()
		end
	end)

	RaidMenu.AlphaIn = CreateFrame("Frame", nil, UIParent)
	RaidMenu.AlphaIn.timer = 0
	RaidMenu.AlphaIn:Hide()

	RaidMenu.AlphaIn:SetScript("OnUpdate", function(self,elapsed)
		RaidMenu_Parent:Show()
		self.timer = self.timer + elapsed
		if self.timer < .5 then
			RaidMenu_Parent:SetAlpha((self.timer / .5)*(db.Opacity / 100))
		else
			RaidMenu_Parent:SetAlpha(db.Opacity / 100)
			self.timer = 0
			self:Hide()
		end
	end)

	RaidMenu.SlideUp = CreateFrame("Frame", nil, UIParent)
	RaidMenu.SlideUp.timer = 0
	RaidMenu.SlideUp:Hide()

	RaidMenu.SlideUp:SetScript("OnUpdate", function(self,elapsed)
		local X_Position, Y_Position
		if db.Compact then
			Y_Position = Y_compact + (db.Spacing / 2)
			X_Position = X_compact + (db.Spacing / 2)
		else
			Y_Position = Y_normal
			X_Position = X_normal
		end
		self.timer = self.timer + elapsed
		if self.timer < .5 then
			local offset = (1 - self.timer / .5) * db.Offset
			RaidMenu_Parent:SetPoint("TOPRIGHT", Micromenu.buttonLeft, "BOTTOMRIGHT", (X_Position + db.X_Offset), (((Y_Position + offset) / db.Scale) + 17))
		else
			RaidMenu_Parent:SetPoint("TOPRIGHT", Micromenu.buttonLeft, "BOTTOMRIGHT", (X_Position + db.X_Offset), ((Y_Position / db.Scale) + 17))
			self.timer = 0
			self:Hide()
		end
	end)

	RaidMenu.SlideDown = CreateFrame("Frame", nil, UIParent)
	RaidMenu.SlideDown.timer = 0
	RaidMenu.SlideDown:Hide()

	RaidMenu.SlideDown:SetScript("OnUpdate", function(self,elapsed)
		local X_Position, Y_Position
		if db.Compact then
			Y_Position = Y_compact + (db.Spacing / 2)
			X_Position = X_compact + (db.Spacing / 2)
		else
			Y_Position = Y_normal
			X_Position = X_normal
		end
		self.timer = self.timer + elapsed
		if self.timer < .5 then
			local offset = (self.timer / .5) * db.Offset
			RaidMenu_Parent:SetPoint("TOPRIGHT", Micromenu.buttonLeft, "BOTTOMRIGHT", (X_Position + db.X_Offset), (((Y_Position + offset) / db.Scale) + 17))
		else
			RaidMenu_Parent:SetPoint("TOPRIGHT", Micromenu.buttonLeft, "BOTTOMRIGHT", (X_Position + db.X_Offset), (((Y_Position + db.Offset) / db.Scale) + 17))
			self.timer = 0
			self:Hide()
		end
	end)

	SizeRaidMenu()
end

function module:Refresh()
	module:OverlapPrevention("RM", "position")
	SizeRaidMenu()
	RaidMenu_Parent:SetAlpha(db.Opacity/100)
end

-- ####################################################################################################################
-- ##### Legacy Frame Options #########################################################################################
-- ####################################################################################################################

function module:LoadFrameOptions()
	local options = {
		name = "Raid Menu",
		type = "group",
		order = 10,
		args = {
			Title = {
				type = "header",
				order = 1,
				name = "Raid Menu",
			},
			Enable = {
				name = "Enable",
				desc = "Wether you want the RaidMenu enabled or not.",
				type = "toggle",
				disabled = function() return not Micromenu end,
				get = function() return db.Enable end,
				set = function(self,Enable)
					db.Enable = Enable
					if Enable then
						module:SetRaidMenu()
--					else
--						StaticPopup_Show("RELOAD_UI")
					end
				end,
				order = 2,
			},
			Settings = {
				name = "Settings",
				type = "group",
				order = 3,
				disabled = function() return not (Micromenu and db.Enable) end,
				guiInline = true,
				args = {
					Compact = {
						name = "Compact Raid Menu",
						desc = "Use compact version of the Raid Menu",
						type = "toggle",
						get = function() return db.Compact end,
						set = function(self)
							db.Compact = not db.Compact
							module:OverlapPrevention("RM", "position")
							SizeRaidMenu()
						end,
						order = 1,
					},
					Spacing = {
						name = "Spacing",
						desc = "Spacing between buttons of Raid Menu",
						disabled = function() return not db.Compact end,
						type = "range",
						step = 1,
						min = 0,
						max = 10,
						get = function() return db.Spacing end,
						set = function(self, value)
							db.Spacing = value
							module:OverlapPrevention("RM", "position")
							SizeRaidMenu()
						end,
						order = 2,
					},
					OverlapPrevention = {
						name = "Micromenu Overlap Prevention",
						desc = "\nAutoHide: The MicroMenu or Raid Menu should hide when the other is opened\n\nOffset: The Raid Menu should offset itself when the MicroMenu is open",
						type = "select",
						values = OverlapPreventionMethods,
						get = function()
							for k, v in pairs(OverlapPreventionMethods) do
								if db.OverlapPrevention == v then
									return k
								end
							end
						end,
						set = function(self, value)
							db.OverlapPrevention = OverlapPreventionMethods[value]
							module:OverlapPrevention("RM", "position")
						end,
						order = 3,
					},
					Scale = {
						name = "Scale",
						desc = "The Scale of the Raid Menu",
						type = "range",
						step = 0.05,
						min = 0.5,
						max = 2.0,
						get = function() return db.Scale end,
						set = function(self, value)
							db.Scale = value
							RaidMenu_Parent:SetScale(db.Scale)
							module:OverlapPrevention("RM", "position")
						end,
						order = 4,
					},
					X_Offset = {
						name = "X Offset",
						desc = "How far to horizontally offset when the MicroMenu is open\n\nDefault: "..dbd.X_Offset,
						disabled = function() return db.OverlapPrevention == "AutoHide" end,
						type = "range",
						step = 1,
						min = -200,
						max = 200,
						get = function() return db.X_Offset end,
						set = function(self, value)
							db.X_Offset = value
							module:OverlapPrevention("RM", "position")
						end,
						order = 5,
					},
					Offset = {
						name = "Y Offset",
						desc = "How far to vertically offset when the MicroMenu is open\n\nDefault: "..dbd.Offset,
						disabled = function() return db.OverlapPrevention == "AutoHide" end,
						type = "range",
						step = 1,
						min = -200,
						max = 0,
						get = function() return db.Offset end,
						set = function(self, value)
							db.Offset = value
							module:OverlapPrevention("RM", "position")
						end,
						order = 6,
					},
					Opacity = {
						name = "Opacity",
						desc = "The Opacity of the Raid Menu\n100% is fully visable",
						type = "range",
						step = 10,
						min = 20,
						max = 100,
						get = function() return db.Opacity end,
						set = function(self, value)
							db.Opacity = value
							RaidMenu_Parent:SetAlpha(db.Opacity/100)
						end,
						order = 7,
					},
					AutoHide = {
						name = "AutoHide Raid Menu",
						desc = "Weather or not the Raid Menu should hide itself after clicking on a function",
						type = "toggle",
						get = function() return db.AutoHide end,
						set = function(self) db.AutoHide = not db.AutoHide end,
						order = 8,
					},
					ShowToolTips = {
						name = "Show Tooltips",
						desc = "Weather or not to show tooltips for the Raid Menu tools",
						type = "toggle",
						get = function() return db.ShowToolTips end,
						set = function(self) db.ShowToolTips = not db.ShowToolTips end,
						order = 9,
					},
					ToggleRaidIcon = {
						name = "Toggle Raid Icon",
						desc = "Weather of not Raid Target Icons can be removed by applying the icon the target already has",
						type = "toggle",
						width = "full",
						get = function() return db.ToggleRaidIcon end,
						set = function(self) db.ToggleRaidIcon = not db.ToggleRaidIcon end,
						order = 10,
					},
				},
			},
		},
	}

	return options
end
