----------------------------------------------------------------------------------------------------
-- Variables, references, etc.
----------------------------------------------------------------------------------------------------
local ruleList = {} -- the table holding all the loot rules
local ShowGroup     -- forward declaration for function

----------------------------------------------------------------------------------------------------
-- helper functions
----------------------------------------------------------------------------------------------------
-- go through all group lists to set up the looting rules
local function UpdateRules()
	ruleList.fullName    = {}  -- [full item name] = group name
	ruleList.patternName = {}  -- [lua pattern] = group name
	ruleList.properties  = {}  -- [type and subtype combined][quality] = {min ilvl, max ilvl, group name}

	-- to convert the quality name to its number seen when getting an item's information
	local qualityList = {
		["all"] = -1,
		["poor"] = 0,
		["common"] = 1,
		["uncommon"] = 2,
		["rare"] = 3,
		["epic"] = 4,
		["legendary"] = 5,
	}

	for i=1,#AutoLootSave.groups do
		local groupName = AutoLootSave.groups[i].name
		for line in AutoLootSave.groups[i].list:gmatch("[^\r\n]+") do
			line = line:match("^%s*(.-)%s*$") -- remove spaces at beginning and end

			if line:find("[%[%%^$]") or line:find("%.[%*%?%-%+]") then
				ruleList.patternName[line] = groupName
			elseif line:find("^type=") then
				local mainType, subType, quality, min, max = line:match("^type=([^:]+):(%S+) quality=(%a+) ilvl=(%d+)%-(%d+)")
				if max then
					local fullType = mainType .. subType
					local qualityIndex = qualityList[quality:lower()]

					ruleList.properties[fullType] = ruleList.properties[fullType] or {}
					ruleList.properties[fullType][qualityIndex] = ruleList.properties[fullType][qualityIndex] or {}
					table.insert(ruleList.properties[fullType][qualityIndex], {tonumber(min), tonumber(max), groupName})
				end
			elseif line ~= "" then
				ruleList.fullName[line:lower()] = groupName
			end
		end
	end
end

-- return true if the player is in any type of group
local function IsInGroup()
	return (GetNumPartyMembers() > 0 or GetNumRaidMembers() > 0)
end

-- return a group's settings table, or nil if the group wasn't found
local function GetGroupSettings(name)
	for i=1,#AutoLootSave.groups do
		if AutoLootSave.groups[i].name:lower() == name:lower() then
			return AutoLootSave.groups[i]
		end
	end
end

local editboxInput -- forward declaration
local function InsertEditboxText(text)
	if editboxInput:IsVisible() then
		local original = editboxInput:GetText()
		if original == "" or original:sub(-1) == "\n" then
			editboxInput:SetText(original .. text .. "\n")
		else
			editboxInput:SetText(original .. "\n" .. text .. "\n")
		end
		editboxInput:SetFocus()
		CloseDropDownMenus()
	end
end

----------------------------------------------------------------------------------------------------
-- GUI - most widget scripts set up after the layout
----------------------------------------------------------------------------------------------------
local guiFrame
local function CreateGUI()
	if guiFrame then
		return
	end

	--------------------------------------------------
	-- main window
	--------------------------------------------------
	guiFrame = CreateFrame("frame", "AutoLootFrame", UIParent)
	table.insert(UISpecialFrames, guiFrame:GetName()) -- make it closable with escape key
	guiFrame:SetFrameStrata("HIGH")
	guiFrame:SetBackdrop({
		bgFile="Interface/Tooltips/UI-Tooltip-Background",
		edgeFile="Interface/DialogFrame/UI-DialogBox-Border",
		tile=1, tileSize=32, edgeSize=32,
		insets={left=11, right=12, top=12, bottom=11}
	})
	guiFrame:SetBackdropColor(0,0,0,1)
	guiFrame:SetPoint("CENTER")
	guiFrame:SetWidth(450)
	guiFrame:SetHeight(580)
	guiFrame:SetMovable(true)
	guiFrame:EnableMouse(true)
	guiFrame:RegisterForDrag("LeftButton")
	guiFrame:SetScript("OnDragStart", guiFrame.StartMoving)
	guiFrame:SetScript("OnDragStop", guiFrame.StopMovingOrSizing)
	guiFrame:SetScript("OnMouseDown", function(self, button)
		if button == "LeftButton" and not self.isMoving then
			self:StartMoving()
			self.isMoving = true
		end
	end)
	guiFrame:SetScript("OnMouseUp", function(self, button)
		if button == "LeftButton" and self.isMoving then
			self:StopMovingOrSizing()
			self.isMoving = false
		end
	end)
	guiFrame:SetScript("OnHide", function(self)
		if self.isMoving then
			self:StopMovingOrSizing()
			self.isMoving = false
		end
	end)

	--------------------------------------------------
	-- header title
	--------------------------------------------------
	local textureHeader = guiFrame:CreateTexture(nil, "ARTWORK")
	textureHeader:SetTexture("Interface/DialogFrame/UI-DialogBox-Header")
	textureHeader:SetWidth(315)
	textureHeader:SetHeight(64)
	textureHeader:SetPoint("TOP", 0, 12)
	local textHeader = guiFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	textHeader:SetPoint("TOP", textureHeader, "TOP", 0, -14)
	textHeader:SetText("AutoLoot 2.1")

	--------------------------------------------------
	-- checkbox options
	--------------------------------------------------
	local checkboxAutoloot = CreateFrame("CheckButton", "AutoLootCheckboxAutoloot", guiFrame, "UICheckButtonTemplate")
	checkboxAutoloot:SetPoint("TOPLEFT", guiFrame, "TOPLEFT", 16, -24)
	_G[checkboxAutoloot:GetName().."Text"]:SetText("Enable auto-looting")
	checkboxAutoloot:SetScript("OnClick", function() AutoLootSave.autoloot = this:GetChecked() or false end)

	local checkboxAutoroll = CreateFrame("CheckButton", "AutoLootCheckboxAutoroll", guiFrame, "UICheckButtonTemplate")
	checkboxAutoroll:SetPoint("TOPLEFT", checkboxAutoloot, "BOTTOMLEFT", 0, 8)
	_G[checkboxAutoroll:GetName().."Text"]:SetText("Enable auto-rolling")
	checkboxAutoroll:SetScript("OnClick", function() AutoLootSave.autoroll = this:GetChecked() or false end)

	local checkboxAutopass = CreateFrame("CheckButton", "AutoLootCheckboxAutopass", guiFrame, "UICheckButtonTemplate")
	checkboxAutopass:SetPoint("TOPLEFT", checkboxAutoroll, "BOTTOMLEFT", 0, 8)
	_G[checkboxAutopass:GetName().."Text"]:SetText("Enable auto-passing on everything")
	checkboxAutopass:SetScript("OnClick", function() AutoLootSave.autopass = this:GetChecked() or false end)

	local checkboxSkinningMode = CreateFrame("CheckButton", "AutoLootCheckboxSkinningMode", guiFrame, "UICheckButtonTemplate")
	checkboxSkinningMode:SetPoint("TOPLEFT", checkboxAutopass, "BOTTOMLEFT", 0, 8)
	_G[checkboxSkinningMode:GetName().."Text"]:SetText("Enable skinning mode (take and destroy unwanted items)")
	checkboxSkinningMode:SetScript("OnClick", function() AutoLootSave.skinningMode = this:GetChecked() or false end)

	--------------------------------------------------
	-- first separator line
	--------------------------------------------------
	local lineSeparator1 = guiFrame:CreateTexture()
	lineSeparator1:SetTexture(.4, .4, .4)
	lineSeparator1:SetPoint("TOP", guiFrame, "TOP", 0, 0-(guiFrame:GetTop()-checkboxSkinningMode:GetBottom())-8)
	lineSeparator1:SetWidth(guiFrame:GetWidth()-32)
	lineSeparator1:SetHeight(3)

	--------------------------------------------------
	-- group dropdown and buttons [new] [dropdown] [rename] [delete]
	--------------------------------------------------
	local buttonNew = CreateFrame("Button", "AutoLootButtonNew", guiFrame, "UIPanelButtonTemplate")
	buttonNew:SetWidth(80)
	buttonNew:SetHeight(26)
	buttonNew:SetPoint("TOP", lineSeparator1, "BOTTOM", 0, -12)
	buttonNew:SetPoint("LEFT", checkboxAutoloot, "LEFT", 0, 0)
	_G[buttonNew:GetName().."Text"]:SetText("New Group")

	local dropdownGroup = CreateFrame("frame", "AutoLootDropdownGroup", guiFrame, "UIDropDownMenuTemplate")
	dropdownGroup:SetPoint("TOPLEFT", buttonNew, "TOPRIGHT", -12, 0)
	UIDropDownMenu_SetWidth(180, dropdownGroup)

	local buttonRename = CreateFrame("Button", "AutoLootButtonRename", guiFrame, "UIPanelButtonTemplate")
	buttonRename:SetWidth(64)
	buttonRename:SetHeight(26)
	buttonRename:SetPoint("TOPLEFT", dropdownGroup, "TOPRIGHT", -10, 0)
	_G[buttonRename:GetName().."Text"]:SetText("Rename")

	local buttonDelete = CreateFrame("Button", "AutoLootButtonDelete", guiFrame, "UIPanelButtonTemplate")
	buttonDelete:SetWidth(64)
	buttonDelete:SetHeight(26)
	buttonDelete:SetPoint("TOPLEFT", buttonRename, "TOPRIGHT", 2, 0)
	_G[buttonDelete:GetName().."Text"]:SetText("Delete")

	--------------------------------------------------
	-- second separator line
	--------------------------------------------------
	local lineSeparator2 = guiFrame:CreateTexture()
	lineSeparator2:SetTexture(.4, .4, .4)
	lineSeparator2:SetPoint("TOP", guiFrame, "TOP", 0, 0-(guiFrame:GetTop()-buttonNew:GetBottom())-12)
	lineSeparator2:SetWidth(guiFrame:GetWidth()-32)
	lineSeparator2:SetHeight(3)

	--------------------------------------------------
	-- group options
	-- Solo    [dropdown]  Instance [dropdown]
	-- Outside [dropdown]  Raid     [dropdown]
	--------------------------------------------------
	local textSolo = guiFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	textSolo:SetPoint("TOP", lineSeparator2, "TOP", 0, -20)
	textSolo:SetPoint("LEFT", buttonNew, "LEFT", 0, 0)
	textSolo:SetText("Solo:")

	local dropdownSolo = CreateFrame("frame", "AutoLootDropdownSolo", guiFrame, "UIDropDownMenuTemplate")
	dropdownSolo:SetPoint("LEFT", textSolo, "LEFT", 40, 0)
	dropdownSolo.groupType = "solo"
	UIDropDownMenu_SetWidth(100, dropdownSolo)

	local textOutside = guiFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	textOutside:SetPoint("TOPLEFT", textSolo, "BOTTOMLEFT", 0, -18)
	textOutside:SetText("Outside:")

	local dropdownOutside = CreateFrame("frame", "AutoLootDropdownOutside", guiFrame, "UIDropDownMenuTemplate")
	dropdownOutside:SetPoint("LEFT", textOutside, "LEFT", 40, 0)
	dropdownOutside.groupType = "outside"
	UIDropDownMenu_SetWidth(100, dropdownOutside)

	local textInstance = guiFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	textInstance:SetPoint("LEFT", textSolo, "LEFT", 190, 0)
	textInstance:SetText("Instance:")

	local dropdownInstance = CreateFrame("frame", "AutoLootDropdownInstance", guiFrame, "UIDropDownMenuTemplate")
	dropdownInstance:SetPoint("LEFT", textInstance, "LEFT", 40, 0)
	dropdownInstance.groupType = "instance"
	UIDropDownMenu_SetWidth(100, dropdownInstance)

	local textRaid = guiFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	textRaid:SetPoint("LEFT", textOutside, "LEFT", 190, 0)
	textRaid:SetText("Raid:")

	local dropdownRaid = CreateFrame("frame", "AutoLootDropdownRaid", guiFrame, "UIDropDownMenuTemplate")
	dropdownRaid:SetPoint("LEFT", textRaid, "LEFT", 40, 0)
	dropdownRaid.groupType = "raid"
	UIDropDownMenu_SetWidth(100, dropdownRaid)

	--------------------------------------------------
	-- editbox
	--------------------------------------------------
	local editbox = CreateFrame("Frame", "AutoLootEdit", guiFrame)
	editboxInput = CreateFrame("EditBox", "AutoLootEditInput", editbox) -- local not used here because of previous forward declaration
	local editboxScroll = CreateFrame("ScrollFrame", "AutoLootEditScroll", editbox, "UIPanelScrollFrameTemplate")

	-- editbox - main container
	editbox:SetPoint("TOPLEFT", textOutside, "BOTTOMLEFT", 0, -8)
	editbox:SetPoint("BOTTOM", guiFrame, "BOTTOM", 0, 12)
	editbox:SetWidth(lineSeparator1:GetWidth() - 18)
	editbox:SetBackdrop({
		bgFile = "Interface/Tooltips/UI-Tooltip-Background",
		edgeFile = "Interface/DialogFrame/UI-DialogBox-Border",
		tile=1, tileSize=32, edgeSize=16,
		insets={left=5, right=5, top=5, bottom=5}})
	editbox:SetBackdropColor(0,0,0,1)

	-- editboxInput
	editboxInput:SetMultiLine(true)
	editboxInput:SetAutoFocus(false)
	editboxInput:EnableMouse(true)
	editboxInput:SetFont("Fonts/ARIALN.ttf", 15)
	editboxInput:SetWidth(editbox:GetWidth()-20)
	editboxInput:SetHeight(editbox:GetHeight()-8)
	editboxInput:SetScript("OnEscapePressed", function() editboxInput:ClearFocus() end)

	-- editboxScroll
	editboxScroll:SetPoint("TOPLEFT", editbox, "TOPLEFT", 8, -8)
	editboxScroll:SetPoint("BOTTOMRIGHT", editbox, "BOTTOMRIGHT", -6, 8)
	editboxScroll:EnableMouse(true)
	editboxScroll:SetScript("OnMouseDown", function() editboxInput:SetFocus() end)
	editboxScroll:SetScrollChild(editboxInput)

	-- taken from Blizzard's macro UI XML to handle scrolling
	editbox:SetScript("OnMouseDown", function() editboxInput:SetFocus() end)
	editboxInput:SetScript("OnTextChanged", function()
		local scrollbar = _G[editboxScroll:GetName() .. "ScrollBar"]
		local min, max = scrollbar:GetMinMaxValues()
		if max > 0 and this.max ~= max then
		this.max = max
		scrollbar:SetValue(max)
		end
	end)
	editboxInput:SetScript("OnUpdate", function(this)
		ScrollingEdit_OnUpdate(editboxScroll)
	end)
	editboxInput:SetScript("OnCursorChanged", function()
		ScrollingEdit_OnCursorChanged(arg1, arg2, arg3, arg4)
	end)

	--------------------------------------------------
	-- help button
	--------------------------------------------------
	local buttonHelp = CreateFrame("Button", "AutoLootButtonHelp", guiFrame, "UIPanelButtonTemplate2")
	buttonHelp:SetWidth(22)
	buttonHelp:SetHeight(22)
	buttonHelp:SetPoint("BOTTOMRIGHT", editbox, "TOPRIGHT", 0, 3)
	_G[buttonHelp:GetName().."Text"]:SetText("?")

	-- help menu item clicked - insert it at the end of the current group's list
	local function InsertHelpText()
		InsertEditboxText(this.value)
	end

	-- the help menu - value is the inserted text when an item is clicked
	local helpMenu = {
		{notCheckable=1, text="Help", isTitle=true},
		{notCheckable=1, notClickable=1, hasArrow=1, text="Item Types", menuList={
			{notCheckable=1, text="Main Types", isTitle=true},
			{notCheckable=1, notClickable=1, hasArrow=1, text="Armor", menuList={
				{notCheckable=1, text="Subtypes", isTitle=true},
				{notCheckable=1, func=InsertHelpText, text="All",           value="type=Armor:All quality=All ilvl=0-999"},
				{notCheckable=1, func=InsertHelpText, text="Cloth",         value="type=Armor:Cloth quality=All ilvl=0-999"},
				{notCheckable=1, func=InsertHelpText, text="Idols",         value="type=Armor:Idols quality=All ilvl=0-999"},
				{notCheckable=1, func=InsertHelpText, text="Leather",       value="type=Armor:Leather quality=All ilvl=0-999"},
				{notCheckable=1, func=InsertHelpText, text="Librams",       value="type=Armor:Librams quality=All ilvl=0-999"},
				{notCheckable=1, func=InsertHelpText, text="Mail",          value="type=Armor:Mail quality=All ilvl=0-999"},
				{notCheckable=1, func=InsertHelpText, text="Miscellaneous", value="type=Armor:Miscellaneous quality=All ilvl=0-999"},
				{notCheckable=1, func=InsertHelpText, text="Plate",         value="type=Armor:Plate quality=All ilvl=0-999"},
				{notCheckable=1, func=InsertHelpText, text="Shields",       value="type=Armor:Shields quality=All ilvl=0-999"},
				{notCheckable=1, func=InsertHelpText, text="Sigils",        value="type=Armor:Sigils quality=All ilvl=0-999"},
				{notCheckable=1, func=InsertHelpText, text="Totems",        value="type=Armor:Totems quality=All ilvl=0-999"},
			}},
			{notCheckable=1, notClickable=1, hasArrow=1, text="Consumable", menuList={
				{notCheckable=1, text="Subtypes", isTitle=true},
				{notCheckable=1, func=InsertHelpText, text="All",              value="type=Consumable:All quality=All ilvl=0-999"},
				{notCheckable=1, func=InsertHelpText, text="Bandage",          value="type=Consumable:Bandage quality=All ilvl=0-999"},
				{notCheckable=1, func=InsertHelpText, text="Consumable",       value="type=Consumable:Consumable quality=All ilvl=0-999"},
				{notCheckable=1, func=InsertHelpText, text="Elixir",           value="type=Consumable:Elixir quality=All ilvl=0-999"},
				{notCheckable=1, func=InsertHelpText, text="Flask",            value="type=Consumable:Flask quality=All ilvl=0-999"},
				{notCheckable=1, func=InsertHelpText, text="Food & Drink",     value="type=Consumable:Food & Drink quality=All ilvl=0-999"},
				{notCheckable=1, func=InsertHelpText, text="Item Enhancement", value="type=Consumable:Item Enhancement quality=All ilvl=0-999"},
				{notCheckable=1, func=InsertHelpText, text="Other",            value="type=Consumable:Other quality=All ilvl=0-999"},
				{notCheckable=1, func=InsertHelpText, text="Potion",           value="type=Consumable:Potion quality=All ilvl=0-999"},
				{notCheckable=1, func=InsertHelpText, text="Scroll",           value="type=Consumable:Scroll quality=All ilvl=0-999"},
			}},
			{notCheckable=1, notClickable=1, hasArrow=1, text="Container", menuList={
				{notCheckable=1, text="Subtypes", isTitle=true},
				{notCheckable=1, func=InsertHelpText, text="All",                value="type=Container:All quality=All ilvl=0-999"},
				{notCheckable=1, func=InsertHelpText, text="Bag",                value="type=Container:Bag quality=All ilvl=0-999"},
				{notCheckable=1, func=InsertHelpText, text="Enchanting Bag",     value="type=Container:Enchanting Bag quality=All ilvl=0-999"},
				{notCheckable=1, func=InsertHelpText, text="Engineering Bag",    value="type=Container:Engineering Bag quality=All ilvl=0-999"},
				{notCheckable=1, func=InsertHelpText, text="Gem Bag",            value="type=Container:Gem Bag quality=All ilvl=0-999"},
				{notCheckable=1, func=InsertHelpText, text="Herb Bag",           value="type=Container:Herb Bag quality=All ilvl=0-999"},
				{notCheckable=1, func=InsertHelpText, text="Leatherworking Bag", value="type=Container:Leatherworking Bag quality=All ilvl=0-999"},
				{notCheckable=1, func=InsertHelpText, text="Mining Bag",         value="type=Container:Mining Bag quality=All ilvl=0-999"},
				{notCheckable=1, func=InsertHelpText, text="Soul Bag",           value="type=Container:Soul Bag quality=All ilvl=0-999"},
			}},
			{notCheckable=1, notClickable=1, hasArrow=1, text="Gem", menuList={
				{notCheckable=1, text="Subtypes", isTitle=true},
				{notCheckable=1, func=InsertHelpText, text="All",       value="type=Gem:All quality=All ilvl=0-999"},
				{notCheckable=1, func=InsertHelpText, text="Blue",      value="type=Gem:Blue quality=All ilvl=0-999"},
				{notCheckable=1, func=InsertHelpText, text="Green",     value="type=Gem:Green quality=All ilvl=0-999"},
				{notCheckable=1, func=InsertHelpText, text="Orange",    value="type=Gem:Orange quality=All ilvl=0-999"},
				{notCheckable=1, func=InsertHelpText, text="Meta",      value="type=Gem:Meta quality=All ilvl=0-999"},
				{notCheckable=1, func=InsertHelpText, text="Prismatic", value="type=Gem:Prismatic quality=All ilvl=0-999"},
				{notCheckable=1, func=InsertHelpText, text="Purple",    value="type=Gem:Purple quality=All ilvl=0-999"},
				{notCheckable=1, func=InsertHelpText, text="Red",       value="type=Gem:Red quality=All ilvl=0-999"},
				{notCheckable=1, func=InsertHelpText, text="Simple",    value="type=Gem:Simple quality=All ilvl=0-999"},
			}},
			{notCheckable=1, notClickable=1, hasArrow=1, text="Key", menuList={
				{notCheckable=1, text="Subtypes", isTitle=true},
				{notCheckable=1, func=InsertHelpText, text="All", value="type=Key:All quality=All ilvl=0-999"},
			}},
			{notCheckable=1, notClickable=1, hasArrow=1, text="Miscellaneous", menuList={
				{notCheckable=1, text="Subtypes", isTitle=true},
				{notCheckable=1, func=InsertHelpText, text="All",     value="type=Miscellaneous:All quality=All ilvl=0-999"},
				{notCheckable=1, func=InsertHelpText, text="Holiday", value="type=Miscellaneous:Holiday quality=All ilvl=0-999"},
				{notCheckable=1, func=InsertHelpText, text="Junk",    value="type=Miscellaneous:Junk quality=All ilvl=0-999"},
				{notCheckable=1, func=InsertHelpText, text="Mount",   value="type=Miscellaneous:Mount quality=All ilvl=0-999"},
				{notCheckable=1, func=InsertHelpText, text="Other",   value="type=Miscellaneous:Other quality=All ilvl=0-999"},
				{notCheckable=1, func=InsertHelpText, text="Pet",     value="type=Miscellaneous:Pet quality=All ilvl=0-999"},
				{notCheckable=1, func=InsertHelpText, text="Reagent", value="type=Miscellaneous:Reagent quality=All ilvl=0-999"},
			}},
			{notCheckable=1, notClickable=1, hasArrow=1, text="Money", menuList={
				{notCheckable=1, text="Subtypes", isTitle=true},
				{notCheckable=1, func=InsertHelpText, text="All", value="type=Money:All quality=All ilvl=0-999"},
			}},
			{notCheckable=1, notClickable=1, hasArrow=1, text="Reagent", menuList={
				{notCheckable=1, text="Subtypes", isTitle=true},
				{notCheckable=1, func=InsertHelpText, text="All", value="type=Reagent:All quality=All ilvl=0-999"},
			}},
			{notCheckable=1, notClickable=1, hasArrow=1, text="Recipe", menuList={
				{notCheckable=1, text="Subtypes", isTitle=true},
				{notCheckable=1, func=InsertHelpText, text="All",            value="type=Recipe:All quality=All ilvl=0-999"},
				{notCheckable=1, func=InsertHelpText, text="Alchemy",        value="type=Recipe:Alchemy quality=All ilvl=0-999"},
				{notCheckable=1, func=InsertHelpText, text="Blacksmithing",  value="type=Recipe:Blacksmithing quality=All ilvl=0-999"},
				{notCheckable=1, func=InsertHelpText, text="Book",           value="type=Recipe:Book quality=All ilvl=0-999"},
				{notCheckable=1, func=InsertHelpText, text="Cooking",        value="type=Recipe:Cooking quality=All ilvl=0-999"},
				{notCheckable=1, func=InsertHelpText, text="Enchanting",     value="type=Recipe:Enchanting quality=All ilvl=0-999"},
				{notCheckable=1, func=InsertHelpText, text="Engineering",    value="type=Recipe:Engineering quality=All ilvl=0-999"},
				{notCheckable=1, func=InsertHelpText, text="First Aid",      value="type=Recipe:First Aid quality=All ilvl=0-999"},
				{notCheckable=1, func=InsertHelpText, text="Leatherworking", value="type=Recipe:All quality=All ilvl=0-999"},
				{notCheckable=1, func=InsertHelpText, text="Tailoring",      value="type=Recipe:Tailoring quality=All ilvl=0-999"},
			}},
			{notCheckable=1, notClickable=1, hasArrow=1, text="Projectile", menuList={
				{notCheckable=1, text="Subtypes", isTitle=true},
				{notCheckable=1, func=InsertHelpText, text="All",    value="type=Projectile:All quality=All ilvl=0-999"},
				{notCheckable=1, func=InsertHelpText, text="Arrow",  value="type=Projectile:Arrow quality=All ilvl=0-999"},
				{notCheckable=1, func=InsertHelpText, text="Bullet", value="type=Projectile:Bullet quality=All ilvl=0-999"},
			}},
			{notCheckable=1, notClickable=1, hasArrow=1, text="Quest", menuList={
				{notCheckable=1, text="Subtypes", isTitle=true},
				{notCheckable=1, func=InsertHelpText, text="All", value="type=Quest:All quality=All ilvl=0-999"},
			}},
			{notCheckable=1, notClickable=1, hasArrow=1, text="Quiver", menuList={
				{notCheckable=1, text="Subtypes", isTitle=true},
				{notCheckable=1, func=InsertHelpText, text="All",        value="type=Quiver:All quality=All ilvl=0-999"},
				{notCheckable=1, func=InsertHelpText, text="Ammo Pouch", value="type=Quiver:Ammo Pouch quality=All ilvl=0-999"},
				{notCheckable=1, func=InsertHelpText, text="Quiver",     value="type=Quiver:Quiver quality=All ilvl=0-999"},
			}},
			{notCheckable=1, notClickable=1, hasArrow=1, text="Trade Goods", menuList={
				{notCheckable=1, text="Subtypes", isTitle=true},
				{notCheckable=1, func=InsertHelpText, text="All",                value="type=Trade Goods:All quality=All ilvl=0-999"},
				{notCheckable=1, func=InsertHelpText, text="Armor Enchantment",  value="type=Trade Goods:Armor Enchantment quality=All ilvl=0-999"},
				{notCheckable=1, func=InsertHelpText, text="Cloth",              value="type=Trade Goods:Cloth quality=All ilvl=0-999"},
				{notCheckable=1, func=InsertHelpText, text="Devices",            value="type=Trade Goods:Devices quality=All ilvl=0-999"},
				{notCheckable=1, func=InsertHelpText, text="Elemental",          value="type=Trade Goods:Elemental quality=All ilvl=0-999"},
				{notCheckable=1, func=InsertHelpText, text="Enchanting",         value="type=Trade Goods:Enchanting quality=All ilvl=0-999"},
				{notCheckable=1, func=InsertHelpText, text="Explosives",         value="type=Trade Goods:Explosives quality=All ilvl=0-999"},
				{notCheckable=1, func=InsertHelpText, text="Herb",               value="type=Trade Goods:Herb quality=All ilvl=0-999"},
				{notCheckable=1, func=InsertHelpText, text="Jewelcrafting",      value="type=Trade Goods:Jewelcrafting quality=All ilvl=0-999"},
				{notCheckable=1, func=InsertHelpText, text="Leather",            value="type=Trade Goods:Leather quality=All ilvl=0-999"},
				{notCheckable=1, func=InsertHelpText, text="Materials",          value="type=Trade Goods:Materials quality=All ilvl=0-999"},
				{notCheckable=1, func=InsertHelpText, text="Meat",               value="type=Trade Goods:Meat quality=All ilvl=0-999"},
				{notCheckable=1, func=InsertHelpText, text="Metal & Stone",      value="type=Trade Goods:Metal & Stone quality=All ilvl=0-999"},
				{notCheckable=1, func=InsertHelpText, text="Other",              value="type=Trade Goods:Other quality=All ilvl=0-999"},
				{notCheckable=1, func=InsertHelpText, text="Parts",              value="type=Trade Goods:Parts quality=All ilvl=0-999"},
				{notCheckable=1, func=InsertHelpText, text="Trade Goods",        value="type=Trade Goods:Trade Goods quality=All ilvl=0-999"},
				{notCheckable=1, func=InsertHelpText, text="Weapon Enchantment", value="type=Trade Goods:Weapon Enchantment quality=All ilvl=0-999"},
			}},
			{notCheckable=1, notClickable=1, hasArrow=1, text="Weapon", menuList={
				{notCheckable=1, text="Subtypes", isTitle=true},
				{notCheckable=1, func=InsertHelpText, text="All",               value="type=Weapon:All quality=All ilvl=0-999"},
				{notCheckable=1, func=InsertHelpText, text="Bows",              value="type=Weapon:Bows quality=All ilvl=0-999"},
				{notCheckable=1, func=InsertHelpText, text="Crossbows",         value="type=Weapon:Crossbows quality=All ilvl=0-999"},
				{notCheckable=1, func=InsertHelpText, text="Daggers",           value="type=Weapon:Daggers quality=All ilvl=0-999"},
				{notCheckable=1, func=InsertHelpText, text="Fishing Poles",     value="type=Weapon:Fishing Poles quality=All ilvl=0-999"},
				{notCheckable=1, func=InsertHelpText, text="Fist Weapons",      value="type=Weapon:Fist Weapons quality=All ilvl=0-999"},
				{notCheckable=1, func=InsertHelpText, text="Guns",              value="type=Weapon:Guns quality=All ilvl=0-999"},
				{notCheckable=1, func=InsertHelpText, text="Miscellaneous",     value="type=Weapon:Miscellaneous quality=All ilvl=0-999"},
				{notCheckable=1, func=InsertHelpText, text="One-Handed Axes",   value="type=Weapon:One-Handed Axes quality=All ilvl=0-999"},
				{notCheckable=1, func=InsertHelpText, text="One-Handed Maces",  value="type=Weapon:One-Handed Maces quality=All ilvl=0-999"},
				{notCheckable=1, func=InsertHelpText, text="One-Handed Swords", value="type=Weapon:One-Handed Swords quality=All ilvl=0-999"},
				{notCheckable=1, func=InsertHelpText, text="Polearms",          value="type=Weapon:Polearms quality=All ilvl=0-999"},
				{notCheckable=1, func=InsertHelpText, text="Staves",            value="type=Weapon:Staves quality=All ilvl=0-999"},
				{notCheckable=1, func=InsertHelpText, text="Thrown",            value="type=Weapon:Thrown quality=All ilvl=0-999"},
				{notCheckable=1, func=InsertHelpText, text="Two-Handed Axes",   value="type=Weapon:Two-Handed Axes quality=All ilvl=0-999"},
				{notCheckable=1, func=InsertHelpText, text="Two-Handed Maces",  value="type=Weapon:Two-Handed Maces quality=All ilvl=0-999"},
				{notCheckable=1, func=InsertHelpText, text="Two-Handed Swords", value="type=Weapon:Two-Handed Swords quality=All ilvl=0-999"},
				{notCheckable=1, func=InsertHelpText, text="Wands",             value="type=Weapon:Wands quality=All ilvl=0-999"},
			}},
		}},
		{notCheckable=1, notClickable=1, hasArrow=1, text="Qualities", menuList={
			{notCheckable=1, text="Qualities", isTitle=true},
			{notCheckable=1, func=InsertHelpText, text="Poor",      value="type=All:All quality=Poor ilvl=0-999"},
			{notCheckable=1, func=InsertHelpText, text="Common",    value="type=All:All quality=Common ilvl=0-999"},
			{notCheckable=1, func=InsertHelpText, text="Uncommon",  value="type=All:All quality=Uncommon ilvl=0-999"},
			{notCheckable=1, func=InsertHelpText, text="Rare",      value="type=All:All quality=Rare ilvl=0-999"},
			{notCheckable=1, func=InsertHelpText, text="Epic",      value="type=All:All quality=Epic ilvl=0-999"},
			{notCheckable=1, func=InsertHelpText, text="Legendary", value="type=All:All quality=Legendary ilvl=0-999"},
		}},
		{notCheckable=1, text="Close"},
	}

	-- opening the help menu
	local menuFrame = CreateFrame("Frame", "AutoLootmenuFrame", guiFrame, "UIDropDownMenuTemplate")
	buttonHelp:SetScript("OnClick", function()
		CloseDropDownMenus()
		menuFrame:SetPoint("BOTTOMLEFT", buttonHelp, "BOTTOMLEFT")
		EasyMenu(helpMenu, menuFrame, buttonHelp, 0, 0, "MENU")
	end)

	--------------------------------------------------
	-- close button
	--------------------------------------------------
	local buttonClose = CreateFrame("Button", "AutoLootButtonClose", guiFrame, "UIPanelCloseButton")
	buttonClose:SetPoint("TOPRIGHT", guiFrame, "TOPRIGHT", -8, -8)
	buttonClose:SetScript("OnClick", function()
		editboxInput:ClearFocus()
		guiFrame:Hide()
	end)

	--------------------------------------------------
	-- GUI scripts - group dropdown
	--------------------------------------------------
	-- a dropdown menu item was selected
	local function DropdownGroup_OnClick()
		if GetCurrentKeyBoardFocus() then GetCurrentKeyBoardFocus():ClearFocus() end
		UIDropDownMenu_SetSelectedValue(dropdownGroup, this.value)
		ShowGroup(this.value)
	end

	-- set up the dropdown choices
	local dropdownGroupItem = {}
	local function DropdownGroup_Initialize()
		for i=1,#AutoLootSave.groups do
			dropdownGroupItem.func    = DropdownGroup_OnClick
			dropdownGroupItem.checked = nil
			dropdownGroupItem.value   = AutoLootSave.groups[i].name
			dropdownGroupItem.text    = AutoLootSave.groups[i].name
			UIDropDownMenu_AddButton(dropdownGroupItem)
		end
	end

	--------------------------------------------------
	-- GUI scripts - group options dropdowns
	--------------------------------------------------
	local lootDropdownOptions = {"Leave", "Take"}
	local rollDropdownOptions = {"No action", "Need", "Greed", "Pass"}

	-- a dropdown menu item was selected
	local function dropdownOptions_OnClick()
		if GetCurrentKeyBoardFocus() then GetCurrentKeyBoardFocus():ClearFocus() end
		local dropdown = _G[UIDROPDOWNMENU_OPEN_MENU]
		UIDropDownMenu_SetSelectedValue(dropdown, this.value)
		local group = GetGroupSettings(AutoLootSave.lastGroupShown)
		if group then
			group[dropdown.groupType] = this.value
		end
	end

	-- set up the dropdown choices
	local dropdownOptionsItem = {}
	local function dropdownOptions_Initialize()
		local dropdown = _G[UIDROPDOWNMENU_INIT_MENU]
		local list = dropdown.groupType == "solo" and lootDropdownOptions or rollDropdownOptions
		for i=1,#list do
			dropdownOptionsItem.func    = dropdownOptions_OnClick
			dropdownOptionsItem.checked = nil
			dropdownOptionsItem.value   = list[i]
			dropdownOptionsItem.text    = list[i]
			UIDropDownMenu_AddButton(dropdownOptionsItem)
		end
	end

	--------------------------------------------------
	-- GUI scripts - helper functions
	--------------------------------------------------
	-- show a group's settings, or disable widgets if that group doesn't exist
	ShowGroup = function(name)
		editboxInput:ClearFocus()

		local group = GetGroupSettings(name)
		if not group then
			buttonRename:Hide()
			buttonDelete:Hide()
			textSolo:Hide()
			textOutside:Hide()
			textInstance:Hide()
			textRaid:Hide()
			dropdownGroup:Hide()
			dropdownSolo:Hide()
			dropdownOutside:Hide()
			dropdownInstance:Hide()
			dropdownRaid:Hide()
			editbox:Hide()
			buttonHelp:Hide()
		else
			AutoLootSave.lastGroupShown = name
			buttonRename:Show()
			buttonDelete:Show()
			textSolo:Show()
			textOutside:Show()
			textInstance:Show()
			textRaid:Show()
			dropdownGroup:Show()
			dropdownSolo:Show()
			dropdownOutside:Show()
			dropdownInstance:Show()
			dropdownRaid:Show()
			editbox:Show()
			buttonHelp:Show()
			UIDropDownMenu_Initialize(dropdownGroup, DropdownGroup_Initialize)
			UIDropDownMenu_SetSelectedValue(dropdownGroup, group.name)
			UIDropDownMenu_Initialize(dropdownSolo, dropdownOptions_Initialize)
			UIDropDownMenu_SetSelectedValue(dropdownSolo, group.solo)
			UIDropDownMenu_Initialize(dropdownOutside, dropdownOptions_Initialize)
			UIDropDownMenu_SetSelectedValue(dropdownOutside, group.outside)
			UIDropDownMenu_Initialize(dropdownInstance, dropdownOptions_Initialize)
			UIDropDownMenu_SetSelectedValue(dropdownInstance, group.instance)
			UIDropDownMenu_Initialize(dropdownRaid, dropdownOptions_Initialize)
			UIDropDownMenu_SetSelectedValue(dropdownRaid, group.raid)
			editboxInput:SetText(group.list or "")
		end
	end

	-- create a new group and add it in alphabetical order - return true if successful
	local function AddGroup(name)
		if not name or name == "" or GetGroupSettings(name) then
			return false
		end
		local insertAt = 1
		for i=1,#AutoLootSave.groups do
			if AutoLootSave.groups[i].name:lower() > name:lower() then
				break
			end
			insertAt = insertAt + 1
		end
		table.insert(AutoLootSave.groups, insertAt, {
			["name"]=name,
			["list"]="",
			["solo"]="Leave",
			["outside"]="No action",
			["instance"]="No action",
			["raid"]="No action",
		})
		return true
	end

	-- remove a group - doesn't update the rules list - return true if successful
	local function RemoveGroup(name)
		for i=1,#AutoLootSave.groups do
			if AutoLootSave.groups[i].name:lower() == name:lower() then
				table.remove(AutoLootSave.groups, i)
				return true
			end
		end
		return false
	end

	-- rename a group - return true if successful
	local function RenameGroup(oldName, newName)
		local oldGroup = GetGroupSettings(oldName)
		if not oldGroup or not newName or newName == "" or GetGroupSettings(newName) then
			return false
		end
		RemoveGroup(oldName)
		AddGroup(newName)
		oldGroup.name = newName
		local newGroup = GetGroupSettings(newName)
		for k,v in pairs(oldGroup) do
			newGroup[k] = v
		end
		return true
	end

	--------------------------------------------------
	-- GUI scripts - editbox
	--------------------------------------------------
	editboxInput:SetScript("OnEditFocusLost", function()
		local group = GetGroupSettings(AutoLootSave.lastGroupShown)
		if group then
			group.list = this:GetText()
			UpdateRules()
		end
	end)

	-- dragging an item onto the editbox - has to affect the scroll box and input
	local function InputReceiveItem()
		local cursorType, _, cursorLink = GetCursorInfo()
		if cursorType == "item" then
			InsertEditboxText(cursorLink:match("%[(.+)]"))
			ClearCursor()
		end
	end

	editboxScroll:SetScript("OnReceiveDrag", InputReceiveItem)
	local editboxScroll_OnMouseDown = editboxScroll:GetScript("OnMouseDown")
	editboxScroll:SetScript("OnMouseDown", function(self, button)
		if button == "LeftButton" then InputReceiveItem() end
		editboxScroll_OnMouseDown(self, button)
	end)

	editboxInput:SetScript("OnReceiveDrag", InputReceiveItem)
	editboxInput:SetScript("OnMouseDown", function(self, button)
		if button == "LeftButton" then InputReceiveItem() end
	end)

	--------------------------------------------------
	-- GUI scripts - buttons
	--------------------------------------------------
	-- new group button - show a popup to name and create a new group
	buttonNew:SetScript("OnClick", function()
		-- create the dialog if it doesn't exist yet
		if not StaticPopupDialogs["AUTOLOOT_POPUP_NAME"] then
			StaticPopupDialogs["AUTOLOOT_POPUP_NAME"] = {
				text = "Enter a name for the new group:",
				button1 = ACCEPT,
				button2 = CANCEL,
				timeout = 0,
				whileDead = true,
				hideOnEscape = true,
				hasEditBox = true,
				preferredIndex = 3, -- to avoid interferring with Blizzard UI popups
				OnShow = function()
					_G[this:GetName().."EditBox"]:SetText("")
				end,
				OnAccept = function()
					local name = _G[this:GetParent():GetName().."EditBox"]:GetText()
					if AddGroup(name) then
						ShowGroup(name)
					end
				end,
				EditBoxOnEnterPressed = function()
					StaticPopupDialogs["AUTOLOOT_POPUP_NAME"]:OnAccept()
					this:GetParent():Hide()
				end,
				EditBoxOnEscapePressed = function()
					this:GetParent():Hide()
				end,
			}
		end
		StaticPopup_Show("AUTOLOOT_POPUP_NAME")
	end)

	-- rename button - show a popup to rename the currently shown group
	buttonRename:SetScript("OnClick", function()
		if not GetGroupSettings(AutoLootSave.lastGroupShown) then
			return
		end
		-- create the dialog if it doesn't exist yet
		if not StaticPopupDialogs["AUTOLOOT_POPUP_RENAME"] then
			StaticPopupDialogs["AUTOLOOT_POPUP_RENAME"] = {
				text = "Enter a new name for the group:",
				button1 = ACCEPT,
				button2 = CANCEL,
				timeout = 0,
				whileDead = true,
				hideOnEscape = true,
				hasEditBox = true,
				preferredIndex = 3, -- to avoid interferring with Blizzard UI popups
				OnShow = function()
					_G[this:GetName().."EditBox"]:SetText(AutoLootSave.lastGroupShown)
				end,
				OnAccept = function()
					local name = _G[this:GetParent():GetName().."EditBox"]:GetText()
					if RenameGroup(AutoLootSave.lastGroupShown, name) then
						UpdateRules()
						ShowGroup(name)
					end
				end,
				EditBoxOnEnterPressed = function()
					StaticPopupDialogs["AUTOLOOT_POPUP_RENAME"]:OnAccept()
					this:GetParent():Hide()
				end,
				EditBoxOnEscapePressed = function()
					this:GetParent():Hide()
				end,
			}
		end
		StaticPopup_Show("AUTOLOOT_POPUP_RENAME")
	end)

	-- delete button - show confirmation popup to delete the currently shown group
	buttonDelete:SetScript("OnClick", function()
		if not GetGroupSettings(AutoLootSave.lastGroupShown) then
			return
		end
		-- create the dialog if it doesn't exist yet
		if not StaticPopupDialogs["AUTOLOOT_POPUP_DELETE"] then
			StaticPopupDialogs["AUTOLOOT_POPUP_DELETE"] = {
				text = "Really delete this group?",
				button1 = ACCEPT,
				button2 = CANCEL,
				timeout = 0,
				whileDead = true,
				hideOnEscape = true,
				hasEditBox = false,
				preferredIndex = 3, -- to avoid interferring with Blizzard UI popups
				OnAccept = function()
					if RemoveGroup(AutoLootSave.lastGroupShown) then
						UpdateRules()
						ShowGroup(AutoLootSave.groups[1] and AutoLootSave.groups[1].name or "")
					end
				end,
			}
		end
		StaticPopup_Show("AUTOLOOT_POPUP_DELETE")
	end)

	--------------------------------------------------
	-- GUI scripts - showing window
	--------------------------------------------------
	guiFrame:SetScript("OnShow", function()
		checkboxAutoloot:SetChecked(AutoLootSave.autoloot)
		checkboxAutoroll:SetChecked(AutoLootSave.autoroll)
		checkboxAutopass:SetChecked(AutoLootSave.autopass)
		checkboxSkinningMode:SetChecked(AutoLootSave.skinningMode)
		ShowGroup((GetGroupSettings(AutoLootSave.lastGroupShown) and AutoLootSave.lastGroupShown) or
			(AutoLootSave.groups[1] and AutoLootSave.groups[1].name) or "")
	end)

	-- only hide after everything is set up and placed
	guiFrame:Hide()

	return
end

----------------------------------------------------------------------------------------------------
-- Slash commands
----------------------------------------------------------------------------------------------------
_G.SLASH_AUTOLOOT1 = "/autoloot"
function SlashCmdList.AUTOLOOT(input)
	if not input or input == "" then
		if not guiFrame then
			CreateGUI()
		end
		guiFrame:Show()
	elseif input == "on" then
		AutoLootSave.autoloot = true
		DEFAULT_CHAT_FRAME:AddMessage("Autolooting is now enabled.")
	elseif input == "off" then
		AutoLootSave.autoloot = false
		DEFAULT_CHAT_FRAME:AddMessage("Autolooting is now disabled.")
	else
		DEFAULT_CHAT_FRAME:AddMessage("Syntax: /autoloot [on|off]")
	end
end

_G.SLASH_AUTOROLL1 = "/autoroll"
function SlashCmdList.AUTOROLL(input)
	if not input or input == "" then
		if not guiFrame then
			CreateGUI()
		end
		guiFrame:Show()
	elseif input == "on" then
		AutoLootSave.autoroll = true
		DEFAULT_CHAT_FRAME:AddMessage("Autorolling is now enabled.")
	elseif input == "off" then
		AutoLootSave.autoroll = false
		DEFAULT_CHAT_FRAME:AddMessage("Autorolling is now disabled.")
	else
		DEFAULT_CHAT_FRAME:AddMessage("Syntax: /autoroll [on|off]")
	end
end

_G.SLASH_AUTOPASS1 = "/autopass"
function SlashCmdList.AUTOPASS(input)
	if not input or input == "" then
		if not guiFrame then
			CreateGUI()
		end
		guiFrame:Show()
	elseif input == "on" then
		AutoLootSave.autopass = true
		DEFAULT_CHAT_FRAME:AddMessage("Autopassing is now enabled.")
	elseif input == "off" then
		AutoLootSave.autopass = false
		DEFAULT_CHAT_FRAME:AddMessage("Autopassing is now disabled.")
	else
		DEFAULT_CHAT_FRAME:AddMessage("Syntax: /autopass [on|off]")
	end
end

----------------------------------------------------------------------------------------------------
-- handle looting, rolling/passing, and skinning mode
----------------------------------------------------------------------------------------------------
local eventFrame = CreateFrame("frame")
eventFrame:Hide() -- so OnUpdate only runs when needed

--------------------------------------------------
-- confirm bind popups
--------------------------------------------------
local confirmLootTable = {} -- list of CONFIRM_LOOT_BIND loot slots

-- responding to CONFIRM_LOOT_BIND instantly won't work in all cases, so an OnUpdate script is used
-- to pick up the items and close the popup window.
local function AutoLoot_OnUpdate()
	-- if there are BoP items, confirm a single one and remove it from the list of things to confirm
	local amount = #confirmLootTable
	if amount > 0 then
		ConfirmLootSlot(confirmLootTable[amount])
		table.remove(confirmLootTable, amount)

		-- if there's more BoP, they need to be relooted
		amount = #confirmLootTable
		if amount > 0 then
			-- remove it from the confirmation table first because it's going to be put back on after
			-- the reloot of it
			local nextLootSlot = confirmLootTable[amount]
			table.remove(confirmLootTable, amount)
			LootSlot(nextLootSlot)
		end
	-- if there's no loot left to process, keep trying to close the last popup window
	elseif StaticPopup_Visible("LOOT_BIND") then
		StaticPopup_Hide("LOOT_BIND")
	-- when the popup is closed, there's nothing left to do
	else
		eventFrame:Hide() -- stops OnUpdate()
	end
end
eventFrame:SetScript("OnUpdate", AutoLoot_OnUpdate)

--------------------------------------------------
-- skinning mode: destroy unwanted items
--------------------------------------------------
local skinningFrame = CreateFrame("frame")
skinningFrame:Hide() -- so OnUpdate only runs when needed

local unwantedLootList = {} -- list of items to delete in skinning mode

local nextSkinningUpdate = 0
local function skinningFrame_OnUpdate()
	if GetTime() < nextSkinningUpdate then return end

	-- go through each inventory slot
	for k,v in pairs(unwantedLootList) do
		local found = false
		for bag=0,4 do
			for slot=1,GetContainerNumSlots(bag) do
				-- check if an unwanted item is there
				local link = GetContainerItemLink(bag, slot)
				if link and link:match("item:(%d+)") == k then
					-- delete the unwanted item
					PickupContainerItem(bag, slot)
					DeleteCursorItem()
					found = true
				end
			end
		end

		if found then
			unwantedLootList[k] = nil
		else -- if it's taking too long to successfully find/delete it, then give up
			unwantedLootList[k] = unwantedLootList[k] - 1
			if unwantedLootList[k] == 0 then
				unwantedLootList[k] = nil
			end
		end
	end

	-- stop or continue the updating based on if any items are left in the list
	if next(unwantedLootList) == nil then
		skinningFrame:Hide() -- stops OnUpdate()
	else
		nextSkinningUpdate = GetTime() + 1
	end
end
skinningFrame:SetScript("OnUpdate", skinningFrame_OnUpdate)

--------------------------------------------------
-- item testing
--------------------------------------------------
-- to convert to the values used in the passing/rolling api
local RollActionValues = {
	["Pass"]      = 0,
	["Need"]      = 1,
	["Greed"]     = 2,
}

-- helper function - search through a type table to find a matching group
-- ruleList.properties[fulltype][quality] = {min ilvl, max ilvl, group name}
function CheckTypeTable(fulltype, quality, ilvl)
	local typeTable = ruleList.properties[fulltype]
	if typeTable then
		-- specific quality
		local qualityTable = typeTable[quality]
		if qualityTable then
			for i=1,#qualityTable do
				if ilvl >= qualityTable[i][1] and ilvl <= qualityTable[i][2] then
					return GetGroupSettings(qualityTable[i][3])
				end
			end
		end
		-- any quality
		qualityTable = typeTable[-1]
		if qualityTable then
			for i=1,#qualityTable do
				if ilvl >= qualityTable[i][1] and ilvl <= qualityTable[i][2] then
					return GetGroupSettings(qualityTable[i][3])
				end
			end
		end
	end
end

-- find and return the group settings table an item belongs to
local function GetItemGroup(link)
	if not link then return end

	local name, _, quality, ilvl, _, itype, isubtype = GetItemInfo(link:match("item:(%d+)"))

	-- 1. check exact names
	local group = ruleList.fullName[name:lower()]
	if group then
		return GetGroupSettings(group)
	end

	-- 2. check lua patterns for name matching
	for pattern,group in pairs(ruleList.patternName) do
		if name:find(pattern) then
			return GetGroupSettings(group)
		end
	end

	-- 3. check item properties for a match
	local groupName = CheckTypeTable(itype .. isubtype, quality, ilvl)
	if not groupName then
		groupName = CheckTypeTable(itype .. "All", quality, ilvl)
		if not groupName then
			groupName = CheckTypeTable("AllAll", quality, ilvl)
		end
	end
	return groupName
end

-- handle the game events
local function AutoLoot_OnEvent(self, event, arg1, arg2)
	--------------------------------------------------
	-- the loot window opened
	--------------------------------------------------
	if event == "LOOT_OPENED" then
		if not AutoLootSave.autoloot or arg1 == 1 then -- arg1 is 1 if using normal in-game autolooting
			return
		end
		for i=1,GetNumLootItems() do
			if not LootSlotIsItem(i) then -- always take money
				LootSlot(i)
			else
				local group = GetItemGroup(GetLootSlotLink(i))
				if group and group.solo == "Take" then
					LootSlot(i)
				elseif AutoLootSave.skinningMode then
					LootSlot(i)
					unwantedLootList[GetLootSlotLink(i):match("item:(%d+)")] = 10 -- try up to 10 seconds to delete this item
				end
			end
		end
		return
	end

	--------------------------------------------------
	-- the loot window closed
	--------------------------------------------------
	if event == "LOOT_CLOSED" then
		if AutoLootSave.skinningMode and next(unwantedLootList) ~= nil then
			skinningFrame:Show() -- starts OnUpdate()
		end
		return
	end

	--------------------------------------------------
	-- a loot roll popup window happened
	--------------------------------------------------
	if event == "START_LOOT_ROLL" then
		if AutoLootSave.autopass then
			RollOnLoot(arg1, 0)
			return
		end
		if not AutoLootSave.autoroll then
			return
		end

		local group = GetItemGroup(GetLootRollItemLink(arg1))
		if group then
			local action
			if GetNumRaidMembers() > 0 then
				action = RollActionValues[group.raid]
			elseif GetNumPartyMembers() > 0 then
				if IsInInstance() then
					action = RollActionValues[group.instance]
				else
					action = RollActionValues[group.outside]
				end
			end

			if action then
				RollOnLoot(arg1, action)
				if action ~= 0 then
					ConfirmLootRoll(arg1, action)
				end
			end
		end
		return
	end

	--------------------------------------------------
	-- a BoP confirm window popped up
	--------------------------------------------------
	if event == "LOOT_BIND_CONFIRM" then
		-- only when not in a group - rolls are confirmed a different way
		if GetNumPartyMembers() == 0 and GetNumRaidMembers() == 0 then
			table.insert(confirmLootTable, arg1)
			eventFrame:Show() -- starts OnUpdate()
		end
		return
	end

	--------------------------------------------------
	-- addon has finished loading
	--------------------------------------------------
	if event == "ADDON_LOADED" and arg1 == "AutoLoot" then
		eventFrame:UnregisterEvent(event)

		-- set up default settings if needed
		if AutoLootSave                == nil then AutoLootSave                = {}    end
		if AutoLootSave.autoloot       == nil then AutoLootSave.autoloot       = true  end
		if AutoLootSave.autoroll       == nil then AutoLootSave.autoroll       = true  end
		if AutoLootSave.autopass       == nil then AutoLootSave.autopass       = false end
		if AutoLootSave.skinningMode   == nil then AutoLootSave.skinningMode   = false end
		if AutoLootSave.groups         == nil then AutoLootSave.groups         = {}    end
		if AutoLootSave.lastGroupShown == nil then AutoLootSave.lastGroupShown = ""    end

		UIDropDownMenu_Initialize(dropdownGroup, DropdownGroup_Initialize)
		UpdateRules()
		return
	end
end

eventFrame:SetScript("OnEvent", AutoLoot_OnEvent)
eventFrame:RegisterEvent("LOOT_OPENED")       -- to handle auto-looting
eventFrame:RegisterEvent("LOOT_CLOSED")       -- to handle destroying items in skinning mode
eventFrame:RegisterEvent("START_LOOT_ROLL")   -- to handle auto-rolling and auto-passing
eventFrame:RegisterEvent("LOOT_BIND_CONFIRM") -- to automatically accept bind popups
eventFrame:RegisterEvent("ADDON_LOADED")      -- temporary, to set up settings and rules
