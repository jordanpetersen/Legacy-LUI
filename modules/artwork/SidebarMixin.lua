---@class LUIAddon
local LUI = select(2, ...)

local module = LUI:GetModule("Artwork")

local pairs, ipairs = pairs, ipairs
local strfind, strsub, strsplit = string.find, string.sub, string.split
local format = string.format
local InCombatLockdown = _G.InCombatLockdown
local CreateFrame = _G.CreateFrame
local Mixin = _G.Mixin
local SecureHandlerWrapScript = _G.SecureHandlerWrapScript
local UIParent = _G.UIParent
local C_AddOns = _G.C_AddOns
local Bartender4 = _G.Bartender4

---@class SidebarMixin : Frame
---@field db SidebarDBOptions # The options
---@field name string # The name of the sidebar (e.g. Right1)
---@field side string # "Right" or "Left"
---@field OpenAnim SimpleAnimGroup
---@field CloseAnim SimpleAnimGroup
---@field Sbar SimpleTexture
---@field BtnAnchor Button
---@field BtnAnchorOpen Button
---@field Drawer SimpleTexture
---@field DrawerButton SimpleTexture
---@field DrawerButtonOpen SimpleTexture
local SidebarMixin = {}

-- Sidebar Registry
---@type table<string, SidebarMixin>
local _sidebars = {}

local BUTTON_OFFSET = 85
local ANIM_DURATION = 0.5

-- ####################################################################################################################
-- ##### Mixin Functions ##############################################################################################
-- ####################################################################################################################

function SidebarMixin:Open()
	if not self.OpenAnim:IsPlaying() then
		-- Open instantly if the option is set or we are in combat.
		-- Additionally, if called while already open, force it without playing the animation.
		if self.db.OpenInstant or InCombatLockdown() or self:IsOpen() then
			self.Drawer:SetAlpha(1)
			-- Protected Bartender/action-bar frames are toggled by the secure
			-- PostClick wrapper while in combat.
			if not InCombatLockdown() then
				self.BtnAnchorOpen:Show()
				self.BtnAnchor:Hide()
				local anchoredFrame = _G[self.db.Anchor]
				if anchoredFrame then anchoredFrame:Show() end
			end
		else
			self.OpenAnim:Play()
		end
		self.db.IsOpen = true
	end
end

function SidebarMixin:Close()
	if not self.CloseAnim:IsPlaying() then
		if self.db.OpenInstant or InCombatLockdown() or not self:IsOpen() then
			self.Drawer:SetAlpha(0)
			-- Protected Bartender/action-bar frames are toggled by the secure
			-- PostClick wrapper while in combat.
			if not InCombatLockdown() then
				self.BtnAnchorOpen:Hide()
				self.BtnAnchor:Show()
				local anchoredFrame = _G[self.db.Anchor]
				if anchoredFrame then anchoredFrame:Hide() end
			end
		else
			self.CloseAnim:Play()
		end
		self.db.IsOpen = false
	end
end

function SidebarMixin:IsOpen()
	return self.db.IsOpen
end

function SidebarMixin:Toggle()
	if self:IsOpen() then
		self:Close()
	else
		self:Open()
	end
end

function SidebarMixin:SecureToggle(showAnchor)
	return "local showAnchor = "..tostring(showAnchor)..[=[
		local anchoredFrame = self:GetFrameRef("anchor")
		local otherFrame = self:GetFrameRef("otherFrame")
		if not PlayerInCombat() then return end

		if showAnchor then
			anchoredFrame:Show()
		else
			anchoredFrame:Hide()
		end

		otherFrame:Show()
		self:Hide()
	]=]
end

--- Refresh the sidebar's settings and position
function SidebarMixin:Refresh()
	-- All sidebars on a screen edge share that edge's color key.
	local colorKey = "Sidebar"..(self.side or "Right")
	local r, g, b = module:RGBA(colorKey)

	LUI:RegisterConfig(self, self.db)
	LUI:RestorePosition(self)
	self:SetScale(self.db.Scale or 1)
	self:Show()

	self.Sbar:SetVertexColor(r, g, b, 1)
	self.Drawer:SetVertexColor(r, g, b, 1)
	self.DrawerButton:SetVertexColor(r, g, b, 1)
	self.DrawerButtonOpen:SetVertexColor(r, g, b, 1)

	if self.db.Enable then
		self:Show()
		if self:IsOpen() then
			self:Open()
		else
			self:Close()
		end
	else
		self:Hide()
	end

	if not InCombatLockdown() and _G[self.db.Anchor] then
		self.BtnAnchor:SetFrameRef("anchor", _G[self.db.Anchor])
		self.BtnAnchorOpen:SetFrameRef("anchor", _G[self.db.Anchor])
	end

	if self.db.AutoPosition then
		self:AutoAdjust()
	end
end

-- ####################################################################################################################
-- ##### Sidebar Adjust Logics ########################################################################################
-- ####################################################################################################################

--- Compute a drawer-aligned position for the anchored bar (UIParent coords).
---@return number|nil barX
---@return number|nil barY
---@return string|nil point
---@return number|nil scale
function SidebarMixin:GetRecommendedBarPosition()
	local _, _, _, x, y = self:GetPoint()
	local texLeft, texBottom, texWidth, texHeight = self:GetRect()
	local drawLeft, drawBottom, drawWidth, drawHeight = self.Drawer:GetRect()
	if not x or not texWidth or not drawWidth then return end

	local barScale = self:GetEffectiveScale()
	local uiScale = UIParent:GetScale()
	if not uiScale or uiScale == 0 then return end

	-- X is relative to the sidebar artwork; drawer width needs a 62.5% inset into the panel.
	local texOffset = (self.side == "Right") and texWidth or 0
	local barX = (x - texOffset - drawWidth * 0.625) / uiScale * barScale
	local barY = (y + drawHeight * 0.41) / uiScale * barScale
	local point = (self.side == "Right") and "RIGHT" or "LEFT"
	return barX, barY, point, barScale
end

--- Session-only: move the live anchor frame into the drawer. Does not write SavedVariables.
function SidebarMixin:AlignAnchorFrame()
	if InCombatLockdown() then return end
	local bar = _G[self.db.Anchor]
	if not bar then return end

	local barX, barY, point, scale = self:GetRecommendedBarPosition()
	if not barX then return end

	bar:ClearAllPoints()
	bar:SetPoint(point, UIParent, point, barX, barY)
	if scale and bar.SetScale then
		bar:SetScale(scale)
	end
end

--- Align the live frame only (no Bartender profile mutation). Works for any Anchor frame.
function SidebarMixin:AutoAdjust()
	self:AlignAnchorFrame()
end

--- One-shot: persist drawer layout into the current Bartender4 profile (user-initiated).
function SidebarMixin:ApplyToBartender()
	if not C_AddOns.IsAddOnLoaded("Bartender4") or not (strsub(self.db.Anchor, 1, 3) == "BT4") then return end
	local _, num = strsplit("r", self.db.Anchor)
	num = tonumber(num)
	if not num or not Bartender4 or not Bartender4.db then return end

	local barOpt = Bartender4.db:GetNamespace("ActionBars").profile.actionbars[num]
	if not barOpt then return end

	local barX, barY, point, scale = self:GetRecommendedBarPosition()
	if not barX then return end

	
	-- Update Bartender settings.
	barOpt.enabled = self.db.Enable
	barOpt.buttons = 12
	barOpt.rows = 6
	barOpt.alpha = 1
	if not barOpt.position then
		barOpt.position = {}
	end
	barOpt.position.x = barX
	barOpt.position.y = barY
	barOpt.position.point = point
	barOpt.position.scale = scale
	Bartender4:UpdateModuleConfigs()
end

-- Bartender rebuilds secure action-button state from UpdateModuleConfigs.
-- Never invoke it during combat; apply the latest sidebar values on leaving.
SidebarMixin.BT4Adjust = LUI.OutOfCombatWrapper(ApplyBT4Adjust)

module.SidebarMixin = SidebarMixin

-- ####################################################################################################################
-- ##### Helpers ######################################################################################################
-- ####################################################################################################################

local function ApplySideTexCoords(texture, atlasName, flipHorizontal)
	local l, r, t, b = LUI:GetCoordAtlas(atlasName)
	if flipHorizontal then
		texture:SetTexCoord(r, l, t, b)
	else
		texture:SetTexCoord(l, r, t, b)
	end
end

--- Ensure Side/Point fields exist; fold any short-lived Right1/Left1 keys back into Right/Left.
function module:MigrateSideBars()
	local sb = module.db.profile.SideBars
	if not sb then return end

	-- If a profile briefly used Right1/Left1, merge back into the stable primary keys.
	if sb.Right1 then
		if not sb.Right then
			sb.Right = sb.Right1
		end
		sb.Right1 = nil
	end
	if sb.Left1 then
		if not sb.Left then
			sb.Left = sb.Left1
		end
		sb.Left1 = nil
	end

	for name, cfg in pairs(sb) do
		if type(cfg) == "table" then
			if not cfg.Side then
				if name == "Right" or strfind(name, "^Right") then
					cfg.Side = "Right"
				elseif name == "Left" or strfind(name, "^Left") then
					cfg.Side = "Left"
				end
			end
			if cfg.Side and not cfg.Point then
				cfg.Point = (cfg.Side == "Right") and "RIGHT" or "LEFT"
			end
		end
	end
end

-- ####################################################################################################################
-- ##### Sidebar Factory ##############################################################################################
-- ####################################################################################################################

--- Create a new Sidebar
---@param name string # Registry / DB key (e.g. "Right1")
---@param side string # "Right" or "Left"
---@return SidebarMixin
function module:CreateNewSideBar(name, side)
	if _sidebars[name] then return _sidebars[name] end

	local sidedb = module.db.profile.SideBars[name]
	if not sidedb then
		error("LUI Artwork: missing SideBars."..tostring(name).." defaults")
	end
	side = sidedb.Side or side
	sidedb.Side = side
	sidedb.Point = sidedb.Point or ((side == "Right") and "RIGHT" or "LEFT")

	---@type SidebarMixin
	local sidebar = CreateFrame("Frame", "LUISidebar"..name, UIParent)

	local isRight = (side == "Right")
	local inner = isRight and "LEFT" or "RIGHT" -- edge facing screen center
	local openDir = isRight and -1 or 1 -- translation toward center when opening
	local flip = not isRight

	local sbarName = "LUISidebar"..name

	sidebar:SetSize(57, 365)
	sidebar:SetScale(sidedb.Scale or 1)
	sidebar:Show()

	local sbar = sidebar:CreateTexture(sbarName.."Sbar", "BACKGROUND")
	sbar:SetSize(57, 365)
	sbar:SetPoint(inner, sidebar, inner, 0, 0)
	sbar:SetTexture("Interface\\AddOns\\LUI\\media\\templates\\v4\\sidebar_base")
	ApplySideTexCoords(sbar, "sidebar_base", flip)
	sbar:Show()

	local btnAnchor = CreateFrame("Button", sbarName.."ButtonAnchor", sidebar, "SecureHandlerClickTemplate")
	btnAnchor:SetSize(22, 245)
	btnAnchor:SetPoint(inner, sidebar, inner, openDir * 10, 0)
	btnAnchor:Show()

	local btnAnchorOpen = CreateFrame("Button", sbarName.."ButtonAnchorOpen", sidebar, "SecureHandlerClickTemplate")
	btnAnchorOpen:SetSize(22, 245)
	btnAnchorOpen:SetPoint(inner, sidebar, inner, openDir * (10 + BUTTON_OFFSET), 0)
	btnAnchorOpen:Hide()

	local drawer = sidebar:CreateTexture(sbarName.."Drawer", "BACKGROUND")
	drawer:SetSize(100, 247)
	drawer:SetTexture("Interface\\AddOns\\LUI\\media\\templates\\v4\\sidebar_drawer")
	ApplySideTexCoords(drawer, "sidebar_drawer", flip)
	drawer:SetPoint(inner, btnAnchorOpen, inner, openDir * -10, 0)
	drawer:SetAlpha(0)

	local drawerButton = btnAnchor:CreateTexture(sbarName.."DrawerButton", "BACKGROUND")
	drawerButton:SetTexture("Interface\\AddOns\\LUI\\media\\templates\\v4\\sidebar_button")
	ApplySideTexCoords(drawerButton, "sidebar_button", flip)
	drawerButton:SetAllPoints(btnAnchor)
	drawerButton:Show()

	local drawerButtonOpen = btnAnchorOpen:CreateTexture(sbarName.."DrawerButtonOpen", "BACKGROUND")
	drawerButtonOpen:SetTexture("Interface\\AddOns\\LUI\\media\\templates\\v4\\sidebar_button")
	ApplySideTexCoords(drawerButtonOpen, "sidebar_button", flip)
	drawerButtonOpen:SetAllPoints(btnAnchorOpen)
	drawerButtonOpen:Show()

	local function SetButtonHover(tex, hovered)
		if hovered then
			tex:SetTexture("Interface\\AddOns\\LUI\\media\\templates\\v4\\sidebar_button_hover")
			ApplySideTexCoords(tex, "sidebar_button_hover", flip)
		else
			tex:SetTexture("Interface\\AddOns\\LUI\\media\\templates\\v4\\sidebar_button")
			ApplySideTexCoords(tex, "sidebar_button", flip)
		end
	end

	btnAnchor:SetScript("OnEnter", function() SetButtonHover(drawerButton, true) end)
	btnAnchor:SetScript("OnLeave", function() SetButtonHover(drawerButton, false) end)
	btnAnchorOpen:SetScript("OnEnter", function() SetButtonHover(drawerButtonOpen, true) end)
	btnAnchorOpen:SetScript("OnLeave", function() SetButtonHover(drawerButtonOpen, false) end)

	-- Animations (direction depends on side)
	local drawerAlphaIn = drawer:CreateAnimationGroup()
	local a1 = drawerAlphaIn:CreateAnimation("Alpha")
	a1:SetFromAlpha(0)
	a1:SetToAlpha(1)
	a1:SetDuration(ANIM_DURATION / 2)
	a1:SetStartDelay(ANIM_DURATION / 2)
	drawerAlphaIn:SetScript("OnFinished", function() drawer:SetAlpha(1) end)

	local drawOpen = btnAnchor:CreateAnimationGroup()
	local a3 = drawOpen:CreateAnimation("Translation")
	a3:SetOffset(openDir * BUTTON_OFFSET, 0)
	a3:SetDuration(ANIM_DURATION)
	drawOpen:SetScript("OnPlay", function() drawerAlphaIn:Play() end)
	drawOpen:SetScript("OnFinished", function()
		if not InCombatLockdown() then
			btnAnchorOpen:Show()
			btnAnchor:Hide()
			local anchoredFrame = _G[sidebar.db.Anchor]
			if anchoredFrame then
				anchoredFrame:Show()
			end
		end
	end)

	local drawerAlphaOut = drawer:CreateAnimationGroup()
	local a2 = drawerAlphaOut:CreateAnimation("Alpha")
	a2:SetFromAlpha(1)
	a2:SetToAlpha(0)
	a2:SetDuration(ANIM_DURATION)
	drawerAlphaOut:SetScript("OnFinished", function() drawer:SetAlpha(0) end)

	local drawClose = btnAnchorOpen:CreateAnimationGroup()
	local a4 = drawClose:CreateAnimation("Translation")
	a4:SetOffset(-openDir * BUTTON_OFFSET, 0)
	a4:SetDuration(ANIM_DURATION)
	a4:SetStartDelay(ANIM_DURATION / 4)
	drawClose:SetScript("OnPlay", function()
		drawerAlphaOut:Play()
		if not InCombatLockdown() then
			local anchoredFrame = _G[sidebar.db.Anchor]
			if anchoredFrame then
				anchoredFrame:Hide()
			end
		end
	end)
	drawClose:SetScript("OnFinished", function()
		if not InCombatLockdown() then
			btnAnchorOpen:Hide()
			btnAnchor:Show()
		end
	end)

	sidebar.OpenAnim = drawOpen
	sidebar.CloseAnim = drawClose

	sidebar:EnableMouse(true)
	Mixin(sidebar, module.SidebarMixin)

	btnAnchor:SetScript("OnClick", function() sidebar:Toggle() end)
	SecureHandlerWrapScript(btnAnchor, "PostClick", btnAnchor, sidebar:SecureToggle(true))
	btnAnchor:RegisterForClicks("AnyUp")
	btnAnchor:SetFrameRef("otherFrame", btnAnchorOpen)

	btnAnchorOpen:SetScript("OnClick", function() sidebar:Toggle() end)
	SecureHandlerWrapScript(btnAnchorOpen, "PostClick", btnAnchorOpen, sidebar:SecureToggle(false))
	btnAnchorOpen:RegisterForClicks("AnyUp")
	btnAnchorOpen:SetFrameRef("otherFrame", btnAnchor)

	sidebar.name = name
	sidebar.db = sidedb
	sidebar.side = side

	sidebar.Sbar = sbar
	sidebar.Drawer = drawer
	sidebar.BtnAnchor = btnAnchor
	sidebar.BtnAnchorOpen = btnAnchorOpen
	sidebar.DrawerButton = drawerButton
	sidebar.DrawerButtonOpen = drawerButtonOpen

	_sidebars[name] = sidebar
	sidebar:Refresh()

	return sidebar
end

--- Create every SideBars profile entry that has a Side field.
function module:CreateConfiguredSideBars()
	module:MigrateSideBars()
	local order = { "Right", "Right2", "Left", "Left2" }
	local created = {}
	for _, name in ipairs(order) do
		local cfg = module.db.profile.SideBars[name]
		if cfg and cfg.Side then
			module:CreateNewSideBar(name, cfg.Side)
			created[name] = true
		end
	end
	-- Any extra custom keys (e.g. Right3) still get created
	for name, cfg in pairs(module.db.profile.SideBars) do
		if type(cfg) == "table" and cfg.Side and not created[name] then
			module:CreateNewSideBar(name, cfg.Side)
		end
	end
end

--- Iterate over all sidebars
---@return fun(table: table<K, V>, index?: K):K, V
function module:IterateSidebars()
	return pairs(_sidebars)
end
