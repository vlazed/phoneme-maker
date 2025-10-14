---@class LeftRightControlValue
---@field Name string
---@field RightValue number
---@field LeftValue number

---@class SingleControlValue
---@field Name string
---@field Value number

---@alias ControlValue SingleControlValue | LeftRightControlValue

---@class PhonemePreset
---@field ControlValues ControlValue[]
---@field Name string

---@class PresetGroup
---@field Presets PhonemePreset[]
---@field Name string

---@class PresetFile
---@field PresetGroups PresetGroup[]
---@field Model string

do
	return
end

local DIRECTORY = "phonemetool"

---@param ply Player
---@return TOOL|false
local function faceposerEquipped(ply)
	---@type TOOL
	local tool = ply:GetTool()
	return tool and tool.Mode == "faceposer" and tool
end

---@param model string
---@param presetGroup PresetGroup[]
---@return PhonemePreset
local function makePresetFile(model, presetGroup)
	local presetFile = {
		PresetGroups = { presetGroup },
		Model = model,
	}

	return presetFile
end

---@param name string
---@param controlValues ControlValue[]
---@return Preset
local function makePreset(name, controlValues)
	return {
		Name = name,
		ControlValues = controlValues,
	}
end

---@param presets {[string]: ControlValue[]}
local function makePresetGroup(presets, name)
	local presetGroup = {
		Presets = {},
		Name = name or "",
	}

	for name, controlValues in pairs(presets) do
		table.insert(presetGroup.Presets, makePreset(name, controlValues))
	end

	return presetGroup
end

---@param ply Player
---@return Entity?
local function getFaceposerEntity(ply)
	local faceposer = faceposerEquipped(ply)
	if not faceposer then
		return
	end
	---@diagnostic disable-next-line: param-type-mismatch
	local entity = faceposer:GetWeapon():GetNWEntity(1)
	if not IsValid(entity) then
		return
	end

	return entity
end

---@param name string
---@param value number
---@return ControlValue
local function makeControlValue(name, value)
	return {
		Value = value,
		Name = name,
	}
end

---@param name string
---@param leftValue number
---@param rightValue number
---@return LeftRightControlValue
local function makeLeftRightControlValue(name, leftValue, rightValue)
	return {
		LeftValue = leftValue,
		RightValue = rightValue,
		Name = name,
	}
end

---@param parent EntryForm
---@param filter FilterEntry
---@param name string?
---@param controlValues ControlValue[]?
---@return PhonemeEntry
local function makeEntry(parent, filter, name, controlValues)
	---@class PhonemeEntry: DPanel
	local entry = vgui.Create("DPanel", parent)
	parent:AddItem(entry)

	entry.name = vgui.Create("DTextEntry", entry)
	entry.save = vgui.Create("DImageButton", entry)
	entry.save:SetImage("icon16/disk.png")
	entry.save:SetTooltip("Record flexes")
	entry.preview = vgui.Create("DImageButton", entry)
	entry.preview:SetTooltip("Preview flexes")
	entry.preview:SetImage("icon16/eye.png")
	entry.close = vgui.Create("DImageButton", entry)
	entry.close:SetTooltip("Remove entry")
	entry.close:SetImage("icon16/cross.png")

	entry.name:SetText(name or "")

	---@type ControlValue[]
	entry.controlValues = controlValues or {}

	function entry:PerformLayout(w, h)
		local nameSize = 0.625
		local buttonHeight = 0.7

		entry.name:SetSize(w * nameSize, h * buttonHeight)
		local height = 0.5 * h - entry.name:GetTall() * 0.5
		entry.name:SetPos(w * 0.025, height)

		entry.save:SetSize(h * buttonHeight, h * buttonHeight)
		entry.save:SetPos(entry.name:GetX() + entry.name:GetWide() + 0.025 * w, height)

		entry.preview:SetSize(h * buttonHeight, h * buttonHeight)
		entry.preview:SetPos(entry.save:GetX() + entry.save:GetWide() + 0.025 * w, height)

		entry.close:SetSize(h * buttonHeight, h * buttonHeight)
		entry.close:SetPos(entry.preview:GetX() + entry.preview:GetWide() + 0.025 * w, height)
	end

	function entry.close:DoClick()
		for i, item in ipairs(parent.Items) do
			if item == entry:GetParent() then
				item:Remove()
				table.remove(parent.Items, i)
			end
		end
	end

	function entry.save.DoClick(self)
		local entity = getFaceposerEntity(LocalPlayer())
		if not entity then
			return
		end

		entry.controlValues = {}

		local skip = {}
		for i = 0, entity:GetFlexNum() - 1 do
			local flexName = entity:GetFlexName(i)
			if filter.filters[flexName] then
				continue
			end
			if skip[flexName] then
				continue
			end

			local skipName = flexName
			local isPair = string.find(flexName, "left_") or string.find(flexName, "right_")
			if isPair then
				skipName = string.gsub(skipName, "left_", "")
				skipName = string.gsub(skipName, "right_", "")
				skip["left_" .. skipName] = true
				skip["right_" .. skipName] = true
			else
				skip[skipName] = true
			end

			table.insert(
				entry.controlValues,
				isPair
						and makeLeftRightControlValue(
							skipName,
							entity:GetFlexWeight(entity:GetFlexIDByName("left_" .. skipName)),
							entity:GetFlexWeight(entity:GetFlexIDByName("right_" .. skipName))
						)
					or makeControlValue(skipName, entity:GetFlexWeight(i))
			)
		end
	end

	function entry.preview:DoClick()
		if not entry.controlValues[1] then
			return
		end
		local faceposer = faceposerEquipped(LocalPlayer())
		if not faceposer then
			return
		end
		---@diagnostic disable-next-line: param-type-mismatch
		local entity = faceposer:GetWeapon():GetNWEntity(1)
		if not IsValid(entity) then
			return
		end
		---@cast entity Entity

		local flexName = "faceposer_flex%d"
		for _, controlValue in ipairs(entry.controlValues) do
			if controlValue.LeftValue then
				local leftId, rightId =
					entity:GetFlexIDByName("left_" .. controlValue.Name),
					entity:GetFlexIDByName("right_" .. controlValue.Name)

				if leftId then
					entity:SetFlexWeight(leftId, controlValue.LeftValue)
					GetConVar(Format(flexName, leftId)):SetFloat(controlValue.LeftValue)
				end
				if rightId then
					entity:SetFlexWeight(rightId, controlValue.RightValue)
					GetConVar(Format(flexName, rightId)):SetFloat(controlValue.RightValue)
				end
			else
				local id = entity:GetFlexIDByName(controlValue.Name)
				if id then
					entity:SetFlexWeight(id, controlValue.Value)
					GetConVar(Format(flexName, id)):SetFloat(controlValue.Value)
				end
			end
		end
	end

	return entry
end

local function GenerateDefaultFlexValue(ent, flexID)
	local min, max = ent:GetFlexBounds(flexID)
	if not max or max - min == 0 then
		return 0
	end
	return (0 - min) / (max - min)
end

---@return PhonemeMaker
local function buildPhonemeMaker()
	local width, height = ScrW(), ScrH()

	---@class PhonemeMaker: EditablePanel
	local frame = vgui.Create("EditablePanel")
	frame.list = vgui.Create("DCategoryList", frame)
	frame.list:Dock(FILL)

	frame:SetPos(width * 0.1, height * 0.25)
	frame:SetSize(width * 0.125, height * 0.5)

	frame.form = vgui.Create("DForm", frame.list)
	frame.form:Dock(FILL)
	frame.form:SetLabel("Phoneme Maker")

	frame.presets = vgui.Create("phonememaker_presetsaver", frame.form)
	frame.presets:SetDirectory(DIRECTORY)
	frame.presets:RefreshDirectory()

	function frame.presets:OnSaveSuccess(name)
		notification.AddLegacy(Format("Saved preset to %s", name), NOTIFY_GENERIC, 3)
	end
	function frame.presets:OnSaveFailure(msg)
		notification.AddLegacy(Format("Something went wrong with saving preset: %s", msg), NOTIFY_ERROR, 3)
	end

	function frame.presets:OnSavePreset()
		local entity = getFaceposerEntity(LocalPlayer())
		if not entity then
			return
		end

		---@type {[string]: ControlValue}
		local presets = {}
		for _, entry in ipairs(frame.entryForm.Items) do
			---@diagnostic disable-next-line
			presets[entry:GetChild(0).name:GetText()] = entry:GetChild(0).controlValues
		end
		local presetGroup = makePresetGroup(presets, frame.combo:GetValue())
		return util.TableToJSON(makePresetFile(entity:GetModel(), presetGroup), true)
	end
	---@param preset PresetFile
	function frame.presets:OnLoadPreset(preset)
		frame.entryForm:Clear()

		-- Get the preset group according to the combo value.
		-- Default to the first one if it doesn't exist
		local desiredPresetGroup = preset.PresetGroups[1]
		for _, presetGroup in ipairs(preset.PresetGroups) do
			if presetGroup.Name == frame.combo:GetValue() then
				desiredPresetGroup = presetGroup
				break
			end
		end
		for _, p in ipairs(desiredPresetGroup.Presets) do
			makeEntry(frame.entryForm, frame.filterEntry, p.Name, p.ControlValues)
		end
	end
	frame.form:AddItem(frame.presets)

	---@diagnostic disable-next-line: missing-parameter
	local combo = frame.form:ComboBox("Preset Group Type")
	---@cast combo DComboBox
	frame.combo = combo
	frame.combo:AddChoice("Emotion")
	frame.combo:AddChoice("Phoneme")
	frame.combo:AddChoice("Viseme", nil, true)

	frame.form:Help(
		"You can only edit one preset group at a time. If you want to combine preset groups, you can manually edit the text file and append to the preset groups"
	)

	frame.form:Help(
		"Use the text box below to filter out face flexes to ignore when making phoneme control values. This is useful for making preset groups"
	)

	---@class FilterEntry: DTextEntry
	frame.filterEntry = vgui.Create("DTextEntry", frame.form)
	frame.form:AddItem(frame.filterEntry)
	frame.filterEntry:SizeTo(-1, 250, 0)
	frame.filterEntry:SetMultiline(true)
	frame.filterEntry:SetAllowNonAsciiCharacters(true)
	frame.filterEntry:SetEnterAllowed(false)
	frame.filterEntry:SetUpdateOnType(true)

	frame.filterEntry.filters = {}

	function frame.filterEntry:OnValueChange(value)
		self.filters = string.Split(value, "\n")
		self.filters = table.Flip(self.filters)
	end

	function frame:Think()
		local entity = getFaceposerEntity(LocalPlayer())
		if not entity then
			return
		end

		self.presets:SetEntity(entity)
	end

	frame.addButton = vgui.Create("DButton", frame.form)
	frame.addButton:SetText("Add entry")
	frame.resetButton = vgui.Create("DButton", frame.form)
	frame.resetButton:SetText("Reset flexes")
	frame.resetButton:SetTooltip("Set flexes to their default values")
	frame.removeButton = vgui.Create("DButton", frame.form)
	frame.removeButton:SetText("Clear all entries")

	frame.form:AddItem(frame.addButton)
	frame.form:AddItem(frame.resetButton)

	function frame.addButton:DoClick()
		makeEntry(frame.entryForm, frame.filterEntry)
	end

	function frame.resetButton:DoClick()
		local entity = getFaceposerEntity(LocalPlayer())
		if not entity then
			return
		end

		for i = 0, entity:GetFlexNum() - 1 do
			local defaultValue = GenerateDefaultFlexValue(entity, i)
			entity:SetFlexWeight(i, defaultValue)
			GetConVar(Format("faceposer_flex%d", i)):SetFloat(defaultValue)
		end
	end

	function frame.removeButton:DoClick()
		frame.entryForm:Clear()
	end

	---@class EntryForm: DForm
	---@field Items PhonemeEntry[]
	frame.entryForm = vgui.Create("DForm", frame.form)
	frame.entryForm:SetLabel("Entries")
	frame.form:AddItem(frame.entryForm)

	frame.form:AddItem(frame.removeButton)

	frame:SetVisible(false)

	frame.hangOpen = false

	function frame:SetHangOpen(val)
		self.hangOpen = val
	end

	function frame:GetHangOpen()
		return self.hangOpen
	end

	function frame:StartKeyFocus(pPanel)
		self.focus = pPanel

		self:SetKeyboardInputEnabled(true)
		self:SetHangOpen(true)
	end

	function frame:EndKeyFocus(pPanel)
		if self.focus ~= pPanel then
			return
		end
		self:SetKeyboardInputEnabled(false)
	end

	return frame
end

---@type PhonemeMaker
VLAZED_PHONEME_MAKER = VLAZED_PHONEME_MAKER
if VLAZED_PHONEME_MAKER then
	VLAZED_PHONEME_MAKER:Remove()
end
-- After a few ticks, vgui components should be available
timer.Simple(0.1, function()
	VLAZED_PHONEME_MAKER = buildPhonemeMaker()
end)

local function openPhonemeMaker()
	if faceposerEquipped(LocalPlayer()) and IsValid(VLAZED_PHONEME_MAKER) and not VLAZED_PHONEME_MAKER:IsVisible() then
		VLAZED_PHONEME_MAKER:SetVisible(true)
		VLAZED_PHONEME_MAKER:MakePopup()
	end
end

local function closePhonemeMaker()
	if not IsValid(VLAZED_PHONEME_MAKER) then
		return
	end

	if VLAZED_PHONEME_MAKER:GetHangOpen() then
		VLAZED_PHONEME_MAKER:SetHangOpen(false)
		return
	end

	VLAZED_PHONEME_MAKER:SetMouseInputEnabled(false)
	VLAZED_PHONEME_MAKER:SetKeyboardInputEnabled(false)
	VLAZED_PHONEME_MAKER:SetVisible(false)
end

hook.Remove("OnContextMenuOpen", "phoneme_maker_hookcontext")
hook.Add("OnContextMenuOpen", "phoneme_maker_hookcontext", openPhonemeMaker)

hook.Remove("OnContextMenuClose", "phoneme_maker_hookcontext")
hook.Add("OnContextMenuClose", "phoneme_maker_hookcontext", closePhonemeMaker)

local function menuKeyboardFocusOn(pnl)
	if IsValid(VLAZED_PHONEME_MAKER) and IsValid(pnl) and pnl:HasParent(VLAZED_PHONEME_MAKER) then
		VLAZED_PHONEME_MAKER:StartKeyFocus(pnl)
	end
end
hook.Remove("OnTextEntryGetFocus", "menuKeyboardFocusOn")
hook.Add("OnTextEntryGetFocus", "menuKeyboardFocusOn", menuKeyboardFocusOn)

local function menuKeyboardFocusOff(pnl)
	if IsValid(VLAZED_PHONEME_MAKER) and IsValid(pnl) and pnl:HasParent(VLAZED_PHONEME_MAKER) then
		VLAZED_PHONEME_MAKER:EndKeyFocus(pnl)
	end
end
hook.Remove("OnTextEntryLoseFocus", "menuKeyboardFocusOff")
hook.Add("OnTextEntryLoseFocus", "menuKeyboardFocusOff", menuKeyboardFocusOff)
