-- Vision Dynamic config compatibility. Keeps existing .cfg profiles.
-- Fast pure-Luau JSON codec
-- HttpService:JSONEncode/JSONDecode are slow inside executors (often a
-- pure-Lua implementation that takes multiple seconds on large configs),
-- and string-concat pretty printers are O(n^2). This codec is single-pass
-- with table.concat buffering: linear time, identical output format.

local JsonEscapes = {
    ['"'] = '\\"',
    ['\\'] = '\\\\',
    ['\n'] = '\\n',
    ['\r'] = '\\r',
    ['\t'] = '\\t',
    ['\b'] = '\\b',
    ['\f'] = '\\f',
}

local function JsonEncode(Value, Compact)
    local Buffer = {}
    local Count = 0

    local function Push(Text)
        Count = Count + 1
        Buffer[Count] = Text
    end

    local function Encode(Value, Indent)
        local ValueType = type(Value)

        if ValueType == "table" then
            local IsArray = (#Value > 0)
            local Padding = ""
            local NextPadding = ""

            if not Compact then
                Padding = string.rep("    ", Indent)
                NextPadding = string.rep("    ", Indent + 1)
            end

            local Entries = 0
            for _, Item in pairs(Value) do
                if Item ~= nil then
                    Entries = Entries + 1
                end
            end

            if Entries == 0 then
                Push(IsArray and "[]" or "{}")
                return
            end

            Push(IsArray and "[" or "{")
            if not Compact then
                Push("\n")
            end

            local Written = 0
            for Key, Item in pairs(Value) do
                if Item ~= nil then
                    if Written > 0 then
                        Push(",")
                        if not Compact then
                            Push("\n")
                        end
                    end
                    Written = Written + 1

                    if not Compact then
                        Push(NextPadding)
                    end

                    if not IsArray then
                        Push('"' .. tostring(Key):gsub('["\\\n\r\t\b\f]', JsonEscapes) .. '"')
                        Push(Compact and ":" or ": ")
                    end

                    Encode(Item, Indent + 1)
                end
            end

            if not Compact then
                Push("\n" .. Padding)
            end
            Push(IsArray and "]" or "}")
        elseif ValueType == "string" then
            Push('"' .. Value:gsub('["\\\n\r\t\b\f]', JsonEscapes) .. '"')
        elseif ValueType == "number" then
            if Value ~= Value or Value == math.huge or Value == -math.huge then
                Push("0")
            else
                Push(tostring(Value))
            end
        elseif ValueType == "boolean" then
            Push(Value and "true" or "false")
        else
            Push("null")
        end
    end

    Encode(Value, 0)
    return table.concat(Buffer)
end

local JsonDecode

local function SameValue(A, B)
    if A == B then
        return true
    end

    if type(A) == "table" and type(B) == "table" then
        local Count = 0

        for Key, Value in pairs(A) do
            Count = Count + 1
            if B[Key] ~= Value then
                return false
            end
        end

        for Key in pairs(B) do
            Count = Count - 1
            if Count < 0 then
                return false
            end
        end

        return Count == 0
    end

    return false
end

-- Minimal Base64 codec (works on any executor, no dependencies)
local Base64Chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

local Base64Map = {}
for Index = 1, #Base64Chars do
    Base64Map[Base64Chars:byte(Index, Index)] = Index - 1
end

local function Base64Encode(Value)
    local Result = {}

    for Index = 1, #Value, 3 do
        local B1 = Value:byte(Index) or 0
        local B2 = Value:byte(Index + 1) or 0
        local B3 = Value:byte(Index + 2) or 0

        local N = B1 * 65536 + B2 * 256 + B3

        Result[#Result + 1] = Base64Chars:sub(N // 262144 + 1, N // 262144 + 1)
        Result[#Result + 1] = Base64Chars:sub(N // 4096 % 64 + 1, N // 4096 % 64 + 1)
        Result[#Result + 1] = Base64Chars:sub(N // 64 % 64 + 1, N // 64 % 64 + 1)
        Result[#Result + 1] = Base64Chars:sub(N % 64 + 1, N % 64 + 1)
    end

    local Padding = #Value % 3
    if Padding == 1 then
        Result[#Result - 1] = "="
        Result[#Result] = "="
    elseif Padding == 2 then
        Result[#Result] = "="
    end

    return table.concat(Result)
end

local function Base64Decode(Value)
    Value = tostring(Value or "")
	Value = Value:gsub("^%s*```[%w_%-]*%s*", ""):gsub("%s*```%s*$", "")
	Value = Value:match("^%s*['\"](.-)['\"]%s*$") or Value
	Value = Value:gsub("%s", ""):gsub("%-", "+"):gsub("_", "/")
	if Value == "" or #Value % 4 == 1 or Value:find("[^A-Za-z0-9+/=]") or Value:find("=[^=]") then
		error("invalid base64")
	end

    local Decoded = {}
    local Buffer = 0
    local Bits = 0

    for Index = 1, #Value do
        local Byte = Value:byte(Index, Index)
        if Byte == 61 then -- '='
            break
        end

        local Digit = Base64Map[Byte]
        if Digit then
            Buffer = Buffer * 64 + Digit
            Bits = Bits + 6

            if Bits >= 8 then
                Bits = Bits - 8
                Decoded[#Decoded + 1] = string.char(math.floor(Buffer / (2 ^ Bits)) % 256)
				Buffer = Buffer % (2 ^ Bits)
            end
		else
			error("invalid base64")
        end
    end

    return table.concat(Decoded)
end

local function CopyToClipboard(Text)
    local Ok, Err = pcall(function()
        if setclipboard then
            setclipboard(Text)
        elseif toclipboard then
            toclipboard(Text)
        elseif set_clipboard then
            set_clipboard(Text)
        else
            error("no clipboard function available")
        end
    end)

    return Ok, Err
end

local function NewConfigSystem(Library, FileManager, Folder, Safety)
    JsonDecode=Safety.DecodeJson
    Folder=Safety.Folder(Folder)
    local ConfigSystem = {}

    ConfigSystem.BasePath = Folder .. "/Configs/" .. tostring(game.GameId)

    -- Current schema version. Older files are migrated through ConfigSystem.Migrations.
    ConfigSystem.SchemaVersion = 2
    ConfigSystem.Migrations = {
        -- v1 -> v2: old files had no Version field. Normalize keybind entries so
        -- the migration pipeline has a clean baseline for future schema changes.
        [2] = function(Data)
            for ModuleFlag, ModuleData in pairs(Data) do
                if type(ModuleData) == "table" and type(ModuleData.Keybinds) == "table" then
                    for KeyFlag, Key in pairs(ModuleData.Keybinds) do
                        if type(Key) ~= "string" then
                            ModuleData.Keybinds[KeyFlag] = ""
                        end
                    end
                end
            end
            return Data
        end,
    }

    -- Auto-save: enabled by default; saves into the active profile shortly
    -- after the last flag change. Uses ONE persistent heartbeat loop with a
    -- dirty flag instead of task.delay/cancel per flag write (thread churn
    -- is what makes executors lag).
    ConfigSystem.AutoSaveEnabled = true
    ConfigSystem.AutoSaveName = nil
    ConfigSystem.CurrentProfile = nil
    ConfigSystem.AutoSaveDirty = false
    ConfigSystem.AutoSaveInterval = 2.5
    ConfigSystem.AutoSaveReady = false
    ConfigSystem.DefaultAutoSaveName = "Autosave"

    -- Last serialized payload per profile: identical saves skip disk I/O.
    -- Executor writefile is slow and blocks the game thread, so avoiding
    -- redundant writes is what keeps save clicks instant.
    ConfigSystem.LastWrites = {}
    ConfigSystem.LastAutoLoad = nil

    function ConfigSystem:Init()
        FileManager:CreateFolder(self.BasePath)
    end

    function ConfigSystem:GetPath(Name)
        Name = Safety.ProfileName(Name or "Default")
        return self.BasePath .. "/" .. Name .. ".cfg"
    end

    function ConfigSystem:Build()
        local Data = {}

        for Flag, Module in pairs(Library.Modules or {}) do
            local ModuleData = {
                Enabled = Module.Enabled
            }

            if Module.Toggles then
                local ToggleData = {}

                for ToggleFlag, Toggle in pairs(Module.Toggles) do
                    ToggleData[ToggleFlag] = Library.Flags[ToggleFlag]
                end

                if next(ToggleData) then
                    ModuleData.Toggles = ToggleData
                end
            end

            if Module.Sliders then
                local SliderData = {}

                for SliderFlag, Slider in pairs(Module.Sliders) do
                    local Value, MinValue = Slider:GetValue()
                    if MinValue ~= nil then
                        SliderData[SliderFlag] = {Value = Value, MinValue = MinValue}
                    else
                        SliderData[SliderFlag] = Value
                    end
                end

                if next(SliderData) then
                    ModuleData.Sliders = SliderData
                end
            end

            if Module.Carousels then
                local CarouselData = {}

                for CarouselFlag, Carousel in pairs(Module.Carousels) do
                    CarouselData[CarouselFlag] = Library.Flags[CarouselFlag]
                end

                if next(CarouselData) then
                    ModuleData.Carousels = CarouselData
                end
            end

            if Module.Dropdowns then
                local DropdownData = {}

                for DropdownFlag, Dropdown in pairs(Module.Dropdowns) do
                    local Value = Library.Flags[DropdownFlag]

                    if Dropdown and Dropdown.IsMulti then
                        Value = type(Value) == "table" and Value or (Dropdown:GetSelected() or {})
                    elseif Dropdown and not Dropdown.IsMulti then
                        Value = Value ~= nil and Value or (Dropdown:GetValue() or nil)
                    end

                    DropdownData[DropdownFlag] = Value
                end

                if next(DropdownData) then
                    ModuleData.Dropdowns = DropdownData
                end
            end

            if Module.ColorPickers then
                local ColorData = {}

                for ColorFlag, ColorPicker in pairs(Module.ColorPickers) do
                    local Color = Library.Flags[ColorFlag]

                    if typeof(Color) ~= "Color3" then
                        Color = ColorPicker:GetValue()
                    end

                    ColorData[ColorFlag] = {
                        R = math.floor(Color.R * 255 + 0.5),
                        G = math.floor(Color.G * 255 + 0.5),
                        B = math.floor(Color.B * 255 + 0.5)
                    }
                end

                if next(ColorData) then
                    ModuleData.ColorPickers = ColorData
                end
            end

            if Module.TextBoxes then
                local TextBoxData = {}

                for TextBoxFlag, TextBox in pairs(Module.TextBoxes) do
                    TextBoxData[TextBoxFlag] = Library.Flags[TextBoxFlag]

                    if type(TextBoxData[TextBoxFlag]) ~= "string" then
                        TextBoxData[TextBoxFlag] = TextBox:GetText()
                    end
                end

                if next(TextBoxData) then
                    ModuleData.TextBoxes = TextBoxData
                end
            end

            if Module.Keybinds then
                local KeybindData = {}

                for KeybindFlag, Keybind in pairs(Module.Keybinds) do
                    local Key = Keybind:GetKey()
                    if Key and typeof(Key) == "EnumItem" then
                        local KeyName = tostring(Key)
                        KeyName = KeyName:gsub("Enum%.KeyCode%.", ""):gsub("Enum%.UserInputType%.", "")
                        KeybindData[KeybindFlag] = KeyName
                    else
                        KeybindData[KeybindFlag] = ""
                    end
                end

                if next(KeybindData) then
                    ModuleData.Keybinds = KeybindData
                end
            end

            Data[Flag] = ModuleData
        end

        for _,record in pairs(Data) do
            for group,mapName in pairs({Toggles="ToggleMap",Sliders="SliderMap",Dropdowns="DropdownMap",TextBoxes="TextBoxMap",ColorPickers="ColorPickerMap",Keybinds="KeybindMap"}) do
                for flag in pairs(record[group] or {}) do
                    local control=Library[mapName] and Library[mapName][flag]
                    if control and control.IgnoreConfig then record[group][flag]=nil end
                end
            end
        end
        return Data
    end

    -- Preflight every recognized value before flags, callbacks or modules change.
    function ConfigSystem:Validate(Data)
        Safety.Map(Data,"Invalid config data")
        for flag,record in pairs(Data) do
            if flag~="__VisionStyle" then
                Safety.Map(record,"Invalid module record")
                assert(record.Enabled==nil or type(record.Enabled)=="boolean","Invalid enabled state")
                for group,mapName in pairs({Toggles="ToggleMap",Sliders="SliderMap",Dropdowns="DropdownMap",TextBoxes="TextBoxMap",ColorPickers="ColorPickerMap",Keybinds="KeybindMap"}) do
                    if record[group]~=nil then
                        Safety.Map(record[group],"Invalid control group")
                        for key,value in pairs(record[group]) do
                            local c=Library[mapName] and Library[mapName][key]
                            if c and not c.IgnoreConfig then
                                if group=="ColorPickers" then
                                    Safety.Map(value,"Invalid color")
                                    for _,component in ipairs({"R","G","B"}) do assert(Safety.Finite(value[component]) and value[component]>=0 and value[component]<=255,"Invalid color component") end
                                    value=Color3.fromRGB(value.R,value.G,value.B)
                                elseif group=="Keybinds" then
                                    assert(type(value)=="string" and (value=="" or Enum.KeyCode[value]),"Invalid keybind")
                                    value=value=="" and "None" or value
                                elseif group=="Sliders" and type(value)=="table" then error("Range slider config is unsupported") end
                                Safety.ControlValue(c,value)
                            end
                        end
                    end
                end
            end
        end
        if Data.__VisionStyle then
            Safety.Map(Data.__VisionStyle,"Invalid style")
            Safety.Map(Data.__VisionStyle.values,"Invalid style values")
            assert(next(Data.__VisionStyle.values)==nil,"Style cannot contain control values")
        end
        if self.ValidateStyle then self:ValidateStyle(Data) end
        return Data
    end
    function ConfigSystem:Decode(Raw)
        local decoded=JsonDecode(self:SanitizeRaw(Raw))
        Safety.Map(decoded,"Invalid config format")
        local version=decoded.Version or 1
        assert(type(version)=="number" and version%1==0 and version>=1 and version<=self.SchemaVersion,"Unsupported config version")
        local data=decoded.Config or decoded
        self:Validate(data)
        return self:Migrate(Safety.Copy(data),version),decoded
    end

    function ConfigSystem:Apply(Data)
        self:Validate(Data)
        local pending,oldFlags={},table.clone(Library._FlagValues)
        for _,record in pairs(Data) do
            if type(record)=="table" then
                for group,mapName in pairs({Toggles="ToggleMap",Sliders="SliderMap",Dropdowns="DropdownMap",TextBoxes="TextBoxMap",ColorPickers="ColorPickerMap",Keybinds="KeybindMap"}) do
                    for flag,value in pairs(record[group] or {}) do
                        local c=Library[mapName] and Library[mapName][flag]
                        if c and not c.IgnoreConfig then
                            if group=="ColorPickers" then value=Color3.fromRGB(value.R,value.G,value.B)
                            elseif group=="Keybinds" then value=value=="" and "None" or value end
                            table.insert(pending,{control=c,value=value,previous=c:Get(),flag=flag})
                        end
                    end
                end
            end
        end
        local assigned={};for _,entry in ipairs(pending) do assigned[entry.flag]=true end
        for flag,c in pairs(Library.ToggleMap) do
            if not assigned[flag] and not c.IgnoreConfig and not tostring(flag):match("^Configs%.") then
                table.insert(pending,{control=c,value=false,previous=c:Get(),flag=flag})
            end
        end
        local style=Library.Window:ExportConfig()
        local wasImporting=Library.Window.Importing;Library.Window.Importing=true
        local ok,err=pcall(function()
            for _,entry in ipairs(pending) do entry.control:Set(entry.value,true) end
            if self.ApplyStyle then self:ApplyStyle(Data) end
        end)
        if not ok then
            local restored,restoreErr=pcall(function()
                for _,entry in ipairs(pending) do entry.control:Set(entry.previous,true) end
                Library.Window:ImportConfig(style,true)
            end)
            table.clear(Library._FlagValues);for flag,value in pairs(oldFlags) do Library._FlagValues[flag]=value end
            Library.Window.Importing=wasImporting
            error(tostring(err)..(restored and "" or "; rollback failed: "..tostring(restoreErr)),0)
        end
        -- Only committed values reach script callbacks. Module activation is last.
        for _,entry in ipairs(pending) do
            if entry.control.Kind~="Keybind" then entry.control:_callback(entry.control:Get()) end
        end
        for flag,module in pairs(Library.Modules) do
            local record=Data[flag]
            module:SetEnabled(record and record.Enabled==true or false)
        end
        Library.Window.Importing=wasImporting
        return true
    end

    function ConfigSystem:Save(Name, Description)
        local Path = self:GetPath(Name)
        local Data = self:Build()

        local Wrapped = {
            Version = self.SchemaVersion,
            Description = Description or "",
            Config = Data
        }

        local Json = JsonEncode(Wrapped)

        Safety.WriteVerified(FileManager,Path,Path:gsub("%.cfg$",".backup.cfg"),Json,function(raw) self:Decode(raw) end)
        self.LastWrites[Name] = Json

        self.CurrentProfile = Name
        self.AutoSaveName = Name
        self.AutoSaveDirty = false
        if Library then
            Library.LoadConfig = Name
            Library.CurrentConfig = Name
        end
    end

    -- Strips legacy "-- description" comment lines from old-format files
    function ConfigSystem:SanitizeRaw(Raw)
        while Raw:match("^%s*%-%-") do
            Raw = Raw:gsub("^%s*%-%-[^\n]*\n?", "")
        end
        return Raw
    end

    -- Migrates config data from an older schema to the current one
    function ConfigSystem:Migrate(Data, FromVersion)
        for Version = FromVersion + 1, self.SchemaVersion do
            local Migration = self.Migrations[Version]
            if Migration then
                local Result = Migration(Data)
                if Result then
                    Data = Result
                end
            end
        end
        return Data
    end

    function ConfigSystem:Load(Name)
        local Path = self:GetPath(Name)

        if not FileManager:IsFile(Path) and not FileManager:IsFile(Path:gsub("%.cfg$",".backup.cfg")) then
            return
        end

        local ok,Data=pcall(function() return self:Decode(FileManager:ReadFile(Path)) end)
        self.RecoveredFromBackup=false
        if not ok then
            local backup=Path:gsub("%.cfg$",".backup.cfg")
            if FileManager:IsFile(backup) then
                local recovered,value=pcall(function() return self:Decode(FileManager:ReadFile(backup)) end)
                if recovered then Data=value;ok=true;self.RecoveredFromBackup=true end
            end
        end
        assert(ok,Data)

        self:Apply(Data)
        self.CurrentProfile = Name
        self.AutoSaveName = Name

        if Library then
            Library.LoadConfig = Name
            Library.CurrentConfig = Name
        end
        self.AutoSaveDirty = false
        return true
    end

    -- Reads the header of a saved config (description + schema version)
    function ConfigSystem:GetInfo(Name)
        local Path = self:GetPath(Name)

        if not FileManager:IsFile(Path) then
            return {}
        end

        local Raw = self:SanitizeRaw(FileManager:ReadFile(Path))

        local Decoded = JsonDecode(Raw)
        if type(Decoded) == "table" then
            return {
                Description = Decoded.Config and (Decoded.Description or "") or "",
                Version = tonumber(Decoded.Version) or 1
            }
        end

        return {}
    end

    -- Auto-save (single heartbeat and dirty flag)
    function ConfigSystem:SetAutoSave(State)
        self.AutoSaveEnabled = State == true

        if self.AutoSaveEnabled then
            self:ScheduleSave()
        end
    end

    -- Called on every flag change. Just flips a flag: no threads, no I/O.
    function ConfigSystem:ScheduleSave()
        if not Library.Window or not Library.Window.Importing then self.AutoSaveDirty = true end
    end

    function ConfigSystem:StartAutoSaveLoop()
        task.spawn(function()
            while not Library.Destroyed do
                task.wait(self.AutoSaveInterval)

                if self.AutoSaveReady and self.AutoSaveEnabled ~= false and self.AutoSaveDirty then
                    self.AutoSaveDirty = false
                    local Ok = pcall(function()
                        self:Save(self.AutoSaveName or self.CurrentProfile or self.DefaultAutoSaveName)
                    end)
                    if not Ok then
                        self.AutoSaveDirty = true
                    end
                end
            end
        end)
    end

    -- Profiles
    function ConfigSystem:SwitchProfile(Name)
        if Name == nil or Name == "" then return end
        assert(self:Load(Name),"Config not found")
        self:SetAutoLoad(Name)
        self.CurrentProfile = Name
        self.AutoSaveName = Name

        if Library then
            Library.LoadConfig = Name
            Library.CurrentConfig = Name
        end

        self:Load(Name)
    end

    -- Sharing: export/import as a Base64 string
    function ConfigSystem:Export(Name)
        Name = Name or self.CurrentProfile or "Default"

        local Info = self:GetInfo(Name)
        local Packed = {
            Version = self.SchemaVersion,
            Name = Name,
            Description = Info.Description or "",
            Config = self:Build()
        }

        return Base64Encode(JsonEncode(Packed, true))
    end

    -- Copies the shareable code to the clipboard; returns the code itself
    function ConfigSystem:CopyExport(Name)
        local Code = self:Export(Name)
        local Ok, Err = CopyToClipboard(Code)

        if Ok then
            return Code
        end

        return nil, Err
    end

    function ConfigSystem:Import(Code)
        local Ok, Json = pcall(Base64Decode, Code)
        if not Ok or not Json or Json == "" then
            return false
        end

        local DecodeOk, Decoded = pcall(JsonDecode, Json)
        if not DecodeOk or type(Decoded) ~= "table" then
            return false
        end

        local valid,Data=pcall(function() return self:Decode(Json) end)
        if not valid then return false end

		local ImportOk = pcall(function()
			local Name = tostring(Decoded.Name or "Imported")
			Name = Name:gsub("[<>:%\"/\\|%?%*]", "_"):sub(1, 64)
			if Name == "" then Name = "Imported" end
            Safety.ProfileName(Name)
            self:Apply(Data)
			self:Save(Name, Decoded.Description or "")
			self:SetAutoLoad(Name)

			if Library then
				Library.LoadConfig = Name
				Library.CurrentConfig = Name
			end
		end)

		return ImportOk
    end

    function ConfigSystem:List()
        local Files = FileManager:ListFiles(self.BasePath)
        local Results = {}

        for _, File in ipairs(Files) do
            local Name = File:match("([^/\\]+)%.cfg$")
            if Name and not Name:match("%.backup$") then
                table.insert(Results, Name)
            end
        end

        return Results
    end

    function ConfigSystem:Delete(Name)
        local Path = self:GetPath(Name)

        if FileManager:IsFile(Path) then
            delfile(Path)
        end

        local Backup=Path:gsub("%.cfg$",".backup.cfg")
        if FileManager:IsFile(Backup) then delfile(Backup) end
        self.LastWrites[Name]=nil

        if self:GetAutoLoad() == Name or self.CurrentProfile == Name then
            local Fallback = self.DefaultAutoSaveName
            self:SetAutoLoad(Fallback)
            self.CurrentProfile = Fallback
            self.AutoSaveName = Fallback
            self.AutoSaveDirty = true
            if Library then
                Library.LoadConfig = Fallback
                Library.CurrentConfig = Fallback
            end
        end
    end

    function ConfigSystem:GetAutoLoadPath()
        return self.BasePath .. "/AutoLoad.txt"
    end

    function ConfigSystem:SetAutoLoad(Name)
        Name = Name or ""

        if self.LastAutoLoad == Name then
            return
        end

        if Name~="" then Safety.ProfileName(Name) end
        local Path = self:GetAutoLoadPath()
        FileManager:WriteFile(Path, Name)
        assert(FileManager:ReadFile(Path)==Name,"Autoload write verification failed")
        self.LastAutoLoad = Name
    end

    function ConfigSystem:GetAutoLoad()
        local Path = self:GetAutoLoadPath()

        if FileManager:IsFile(Path) then
            local Name = FileManager:ReadFile(Path)
            return Name ~= "" and Name or nil
        end

        return nil
    end

    ConfigSystem:Init()
    local Auto = ConfigSystem:GetAutoLoad() or ConfigSystem.DefaultAutoSaveName
    ConfigSystem:SetAutoLoad(Auto)
    ConfigSystem.CurrentProfile = Auto
    ConfigSystem.AutoSaveName = Auto
    Library.LoadConfig = Auto
    Library.CurrentConfig = Auto
    ConfigSystem:StartAutoSaveLoop()

    -- Explicit startup barrier. Call after all controls and listeners exist.
    function ConfigSystem:Ready()
        if self.AutoSaveReady then return true end
        local ok,err=pcall(function()
            if not self:Load(Auto) then self:Save(Auto) end
        end)
        if not ok then
            self.AutoSaveEnabled=false
            self.LastError=tostring(err)
            if Library.Notify then Library:Notify("Config could not load. Autosave paused") end
            return false,err
        end
        self.AutoSaveDirty=false
        self.AutoSaveReady=true
        return true
    end

    return ConfigSystem
end

return NewConfigSystem
