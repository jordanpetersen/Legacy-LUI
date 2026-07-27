-- ####################################################################################################################
-- ##### Setup and Locals #############################################################################################
-- ####################################################################################################################

---@class LUIAddon
local LUI = select(2, ...)

---@class LUI.Artwork : LUIModule
---@field db LUI.Artwork.DB
local module = LUI:NewModule("Artwork", "AceHook-3.0")
local db

-- ####################################################################################################################
-- ##### Default Settings #############################################################################################
-- ####################################################################################################################

---@class LUI.Artwork.DB
module.defaults = {
	profile = {
		LUITextures = {
			NavBar = {
				Enabled = true,
				ShowOrb = true,
				ShowButtons = true,
				TopBackground = true,
				CenterBackground = true,
				ThemedLines = true,
				BlackLines = true,
				LostGalaxy = false,
			},
			Chat = {
				OffsetX = 0,
				OffsetY = 0,
				AlwaysShow = false,
				IsShown = false,
				Direction = "TOPRIGHT",
				Animation = true,
				Width = 429,
				Height = 181
			},
			Tps = {
				OffsetX = 0,
				OffsetY = 0,
				Anchor = "DetailsBaseFrame2",
				Additional = "DetailsRowFrame2",
				AlwaysShow = false,
				IsShown = false,
				Direction = "TOP",
				Animation = true,
				Width = 193,
				Height = 181
			},
			Dps = {
				OffsetX = 0,
				OffsetY = 0,
				Anchor = "DetailsBaseFrame1",
				Additional = "DetailsRowFrame1",
				AlwaysShow = false,
				IsShown = false,
				Direction = "TOP",
				Animation = true,
				Width = 193,
				Height = 181
			},
			Raid = {
				OffsetX = 0,
				OffsetY = 0,
				Anchor = "oUF_LUI_raid",
				Additional = "",
				AlwaysShow = false,
				IsShown = false,
				Direction = "TOPLEFT",
				Animation = false,
				Width = 409,
				Height = 181
			},
			["ActionBarTopTexture"] = {
				Created = true,
				Enabled = true,
				Anchored = true,
				TexMode = 1,
				Texture = "bar_top.tga",
				Point = "BOTTOM",
				Parent = "UIParent",
				RelativePoint = "BOTTOM",
				CustomTexCoords = false,
				HorizontalFlip = false,
				VerticalFlip = false,
				Width = 500,
				Height = 32,
				Order = 3,
				X = 0,
				Y = 110,
				Left = 0,
				Right = 1,
				Up = 0,
				Down = 1,
			},
		},
		SideBars = {
			---@class (exact) SidebarDBOptions
			---@field Side string
			Right1 = {
				Enable = true,
				Side = "Right",
				OpenInstant = false,
				Offset = 0,
				IsOpen = false,
				Anchor = "BT4Bar10",
				Additional = "",
				AutoPosition = false,
				HideEmpty = true,
				X = 15,
				Y = 0,
				Scale = 1,
				Point = "RIGHT",
			},
			Right2 = {
				Enable = false,
				Side = "Right",
				OpenInstant = false,
				Offset = 0,
				IsOpen = false,
				Anchor = "BT4Bar8",
				Additional = "",
				AutoPosition = false,
				HideEmpty = true,
				X = 15,
				Y = 200,
				Scale = 1,
				Point = "RIGHT",
			},
			Left1 = {
				Enable = true,
				Side = "Left",
				OpenInstant = false,
				Offset = 0,
				IsOpen = false,
				Anchor = "BT4Bar9",
				Additional = "",
				AutoPosition = false,
				HideEmpty = true,
				X = 15,
				Y = 0,
				Scale = 1,
				Point = "LEFT",
			},
			Left2 = {
				Enable = false,
				Side = "Left",
				OpenInstant = false,
				Offset = 0,
				IsOpen = false,
				Anchor = "BT4Bar7",
				Additional = "",
				AutoPosition = false,
				HideEmpty = true,
				X = 15,
				Y = 200,
				Scale = 1,
				Point = "LEFT",
			},
		},
		Textures = {
			---@class (exact) PanelDBOptions
			['*'] = {
				Created = false,
				Enabled = false,
				Anchored = true,
				TexMode = 1,
				Texture = "panel_corner.tga",
				Point = "CENTER",
				Parent = "UIParent",
				RelativePoint = "CENTER",
				CustomTexCoords = false,
				HorizontalFlip = false,
				VerticalFlip = false,
				Width = 400,
				Height = 300,
				Order = 100,
				X = 0,
				Y = 0,
				Scale = 1,
				Left = 0,
				Right = 1,
				Up = 0,
				Down = 1,
			},
		},
		Colors = {
			ActionBarTopTexture = { r = 0.12, g = 0.12,  b = 0.12, a = 0.5, t = "Class", },
			SidebarRight = { r = 0.12, g = 0.12,  b = 0.12, a = 1, t = "Class", },
			SidebarLeft = { r = 0.12, g = 0.12,  b = 0.12, a = 1, t = "Class", },
			NavButtons = { r = 0.12, g = 0.12,  b = 0.12, a = 0.75, t = "Class", },
			Chat = { r = 0.12, g = 0.12,  b = 0.12, a = 0.4, t = "Class", },
			Tps = { r = 0.12, g = 0.12,  b = 0.12, a = 0.4, t = "Class", },
			Dps = { r = 0.12, g = 0.12,  b = 0.12, a = 0.4, t = "Class", },
			Raid = { r = 0.12, g = 0.12,  b = 0.12, a = 0.4, t = "Class", },
			ChatBorder = { r = 0.12, g = 0.12,  b = 0.12, a = 0.4, t = "Class", },
			TpsBorder = { r = 0.12, g = 0.12,  b = 0.12, a = 0.4, t = "Class", },
			DpsBorder = { r = 0.12, g = 0.12,  b = 0.12, a = 0.4, t = "Class", },
			RaidBorder = { r = 0.12, g = 0.12,  b = 0.12, a = 0.4, t = "Class", },
			Orb = { r = 0.12, g = 0.12,  b = 0.12, a = 1, t = "Class", },
			TopPanel = { r = 0.12, g = 0.12,  b = 0.12, a = 0.75, t = "Class", },
			LeftBorder = { r = 0, g = 0,  b = 0, a = 1, t = "Individual", },
			RightBorder = { r = 0, g = 0,  b = 0, a = 1, t = "Individual", },
			LeftBorderBack = { r = 0.12, g = 0.12,  b = 0.12, a = 0.75, t = "Class", },
			RightBorderBack = { r = 0.12, g = 0.12,  b = 0.12, a = 0.75, t = "Class", },
			['*'] = { r = 0.12, g = 0.12,  b = 0.12, a = 1, t = "Class", },
		}
	},
}

-- ####################################################################################################################
-- ##### Framework Events #############################################################################################
-- ####################################################################################################################

function module:OnInitialize()
	LUI:RegisterModule(module)
end

function module:OnEnable()
	module:setPanels()
	module:setMainPanels()
	module:CreateConfiguredSideBars()
	module:CreateOrb()
	module:CreateNavBar()
end

function module:OnDisable()
	for _, sidebar in module:IterateSidebars() do
		if sidebar.OpenAnim and sidebar.OpenAnim:IsPlaying() then
			sidebar.OpenAnim:Stop()
		end
		if sidebar.CloseAnim and sidebar.CloseAnim:IsPlaying() then
			sidebar.CloseAnim:Stop()
		end
		local anchoredFrame = sidebar.db and sidebar.db.Anchor and _G[sidebar.db.Anchor]
		if anchoredFrame and anchoredFrame.Hide then
			-- Leave the external bar visible; only hide LUI chrome.
		end
		sidebar:Hide()
	end
end

--- Apply Artwork color changes to live sidebars / chrome.
function module:SetColors()
	for _, sidebar in module:IterateSidebars() do
		sidebar:Refresh()
	end
	if module.RefreshMainPanels then
		module:RefreshMainPanels()
	end
	if module.RefreshNavBar then
		module:RefreshNavBar()
	end
	if module.RefreshOrb then
		module:RefreshOrb()
	end
end
