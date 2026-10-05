-- Dynamic's existing flag API backed entirely by native Vision controls.
return function(ctx)
local Vision, h=ctx.Library,ctx.Helpers
local icons={Pickaxe="hand",Axe="swords",Bottle="message-square",Visibility="eye",Settings="settings",Info="info",Person="user",Movement="footprints",Cash="save",Swords="swords",Palette="palette",Target="crosshair"}
function Vision.CreateDynamic(options)
    options=options or {}
    local lib={Modules={},ToggleMap={},SliderMap={},DropdownMap={},TextBoxMap={},ColorPickerMap={},KeybindMap={},Defaults={},_FlagValues={},Cleanups={},Destroyed=false}
    lib.Assets={GetImage=function(_,path) return icons[path:match("([^/]+)%.png$")] or "crosshair" end}
    lib.Flags=setmetatable({}, {
        __index=lib._FlagValues,
        __newindex=function(_,key,value)
            lib._FlagValues[key]=value
            if lib.OnFlagChanged then lib.OnFlagChanged(key) end
            if lib.ConfigSystem then lib.ConfigSystem:ScheduleSave() end
            if lib.Window then lib.Window:RefreshConditions() end
        end,
    })
    function lib:SetFlagValue(key,value) self.Flags[key]=value end
    function lib:SetFlagValueSilently(key,value) self._FlagValues[key]=value end
    function lib:GetFlag(key) return self.Flags[key] end
    function lib:AddCleanup(fn) table.insert(self.Cleanups,fn) end
    function lib:Connect(signal,fn)
        local connection=signal:Connect(fn); self:AddCleanup(function() connection:Disconnect() end); return connection
    end
    function lib:Destroy()
        if self.Destroyed then return end
        self.Destroyed=true
        for _,module in pairs(self.Modules) do module:SetEnabled(false) end
        for _,fn in ipairs(self.Cleanups) do pcall(fn) end
        table.clear(self.Cleanups)
        if self.Window then self.Window:Destroy() end
    end
    function lib:SetTitle(title) if self.Window then self.Window.Title.Text=tostring(title) end end
    function lib:ToggleWindow(window,value) window:SetVisible(value==nil and not window.Visible or value) end
    function lib:Notify(text,kind,duration)
        if self.Window and not self.Destroyed then return self.Window:Notify({Text=tostring(text),Title=options.Title or "Dynamic",Duration=duration or 3}) end
    end
    function lib:TrackTheme(object,property,key)
        local token=({Text="Text",Background="Background",SideBar="Surface",Element="Raised",Border="Border"})[key] or "Text"
        if self.Window then self.Window:_paint(object,property,token) end
    end
    function lib:TrackAccent(object,property) if self.Window then self.Window:_paint(object,property,"Accent") end end
    function lib:AddToolTip(host,info) return self.Window:AddToolTip(host,info) end

    local function info(source)
        local copy=table.clone(source or {})
        copy.Name=copy.Text or copy.Name
        copy.Id=copy.Flag
        copy.Step=copy.Step or copy.Stepping
        copy.Multi=copy.Multi or copy.Multiple
        return copy
    end
    local function register(module,control,source,map,group)
        local flag=source.Flag or control.Id
        control.Flag=flag
        lib[map][flag]=control; module[group][flag]=control
        lib.Defaults[flag]=control:Get(); lib:SetFlagValueSilently(flag,control:Get())
        function control:GetValue() return self:Get() end
        function control:SetValue(value) self:Set(value) end
        function control:Reset() self:Set(h.copy(self.DefaultValue)) end
        return control
    end
    local function addToggle(module,source)
        local o=info(source)
        o.Callback=function(value)
            lib.Flags[source.Flag or o.Id]=value
            local callback=value and source.OnEnabled or source.OnDisabled
            if callback then task.spawn(callback) end
            if source.OnChange then task.spawn(source.OnChange,value) end
            if source.Callback then task.spawn(source.Callback,value) end
        end
        local c=module.Section:AddToggle(o)
        register(module,c,source,"ToggleMap","Toggles")
        return c
    end
    local function addSlider(module,source)
        local o=info(source)
        if source.ValueFormat and not o.Suffix then o.Suffix=source.ValueFormat:match("%%[%d%.]*[fg](.*)$") end
        o.Callback=function(value) lib.Flags[source.Flag or o.Id]=value; if source.OnChange then task.spawn(source.OnChange,value) end end
        return register(module,module.Section:AddSlider(o),source,"SliderMap","Sliders")
    end
    local function addText(module,source)
        local o=info(source); o.MaxLength=source.MaxLength or 4096
        o.Callback=function(value) lib.Flags[source.Flag or o.Id]=value; if source.OnChange then task.spawn(source.OnChange,value) end end
        local c=register(module,module.Section:AddTextbox(o),source,"TextBoxMap","TextBoxes")
        c.SetText=c.SetValue; c.GetText=c.GetValue
        return c
    end
    local function addDropdown(module,source,multi)
        local o=info(source); o.Multi=multi==true
        -- Dynamic's path and blacklist lists may legitimately be empty.
        local original=source.Options or source.Choices or {}; local empty=#original==0
        o.Options=empty and {"None"} or original
        if multi then o.Default=source.Default or {}
        elseif empty or not table.find(o.Options,source.Default) then o.Default=o.Options[1] end
        o.Callback=function(value)
            local result=empty and (multi and {} or nil) or value
            lib.Flags[source.Flag or o.Id]=result
            if source.OnChange then task.spawn(source.OnChange,result) end
        end
        local c=register(module,module.Section:AddDropdown(o),source,"DropdownMap","Dropdowns")
        c.IsMulti=multi==true; c.Empty=empty
        if empty then lib:SetFlagValueSilently(c.Flag,multi and {} or nil) end
        local set=c.Set; local setOptions=c.SetOptions
        function c:Set(value,silent)
            if self.Empty then value=self.Multi and {} or "None" end
            set(self,value,silent)
        end
        function c:GetValue() if self.Empty then return self.Multi and {} or nil end; return self:Get() end
        function c:SetOptions(values,keep)
            assert(type(values)=="table","Options must be an array")
            local replacement=table.clone(values)
            local nextEmpty=#replacement==0
            if nextEmpty then replacement={"None"} end
            local selection
            if multi then
                selection={}
                if keep~=false then for _,v in ipairs(self.Value) do if table.find(values,v) then table.insert(selection,v) end end end
            else selection=keep~=false and table.find(replacement,self.Value) and self.Value or replacement[1] end
            -- Validate before committing Empty. Native SetOptions validates replacements.
            local seen={}; for k,v in pairs(replacement) do assert(type(k)=="number" and k%1==0 and k>=1 and k<=#replacement and type(v)=="string" and not seen[v],"Invalid options"); seen[v]=true end
            self.Empty=nextEmpty; empty=nextEmpty
            setOptions(self,replacement,selection)
        end
        c.GetSelected=c.GetValue; c.SetSelected=c.SetValue
        function c:Clear() if self.Multi then self:Set({}) else self:SetOptions({}) end end
        function c:SelectAll() self:Set(self.Empty and {} or table.clone(self.Options)) end
        function c:ToggleOption(value)
            local values=self:Get(); local at=table.find(values,value)
            if at then table.remove(values,at) else table.insert(values,value) end
            self:Set(values)
        end
        return c
    end
    local function addColor(module,source)
        local o=info(source); o.Alpha=source.DefaultAlpha or source.Alpha or 1
        o.Callback=function(value,c) lib.Flags[source.Flag or o.Id]=value; if source.OnChange then task.spawn(source.OnChange,value,c.Alpha) end end
        return register(module,module.Section:AddColorpicker(o),source,"ColorPickerMap","ColorPickers")
    end
    local function addKey(module,source)
        local o=info(source)
        o.Default=typeof(source.Default)=="EnumItem" and source.Default.Name or source.Default or "None"
        -- Rise's Toggle OnPress means a press pulse, not alternating presses.
        o.Callback=function(active)
            if source.Mode=="Hold" then if source.OnPress then task.spawn(source.OnPress,active) end
            elseif source.OnPress then task.spawn(source.OnPress,true) end
        end
        local c=register(module,module.Section:AddKeybind(o),source,"KeybindMap","Keybinds")
        function c:GetKey() return self.Value~="None" and Enum.KeyCode[self.Value] or nil end
        function c:SetKey(key) self:Set(typeof(key)=="EnumItem" and key.Name or key or "None") end
        local set=c.Set
        function c:Set(value,silent) set(self,value,silent); lib:SetFlagValueSilently(self.Flag,self.Value) end
        return c
    end
    local function decorateModule(module,source)
        module.Flag=source.Flag or source.Name:gsub("%s+",""); module.Container=module.Section.Content
        for _,group in ipairs({"Toggles","Sliders","Dropdowns","TextBoxes","ColorPickers","Keybinds"}) do module[group]={} end
        module.AddToggle=addToggle; module.AddSlider=addSlider; module.AddDropdown=function(m,s) return addDropdown(m,s,s.Multi==true or s.Multiple==true) end
        module.AddDropdownMultiSelect=function(m,s) return addDropdown(m,s,true) end
        module.AddColorPicker=addColor; module.AddKeybind=addKey; module.AddTextBox=addText; module.AddTextbox=addText
        function module:AddLabel(o)
            local label=self.Section:AddLabel(type(o)=="table" and o.Text or o or "")
            if type(o)=="table" and o.Condition then self.Window:TrackCondition(label,o.Condition) end
            return label
        end
        module.AddSection=module.AddLabel
        function module:AddDivider(o) return self:AddLabel({Text=o and o.Text or "",Condition=o and o.Condition}) end
        function module:AddButton(o)
            local button=self.Section:AddButton({Name=o.Text or o.Name or "Button",Callback=o.Callback or o.OnClick})
            if o.ToolTip then self.Window:AddToolTip(button,o.ToolTip) end
            if o.Condition then self.Window:TrackCondition(button,o.Condition) end
            return button
        end
        lib.Modules[module.Flag]=module
        lib:SetFlagValueSilently(module.Flag,false)
        return module
    end
    function lib:AddTextBox(module,o) return addText(module,o) end
    function lib:CreateWindow(windowOptions)
        if self.Window then return self.Window end
        local o=table.clone(windowOptions or {})
        o.Id=options.Id or options.ConfigFolder or "DynamicVision"
        o.Title=options.Title or o.Name or "Dynamic"
        o.ConfigFolder=(options.ConfigFolder or "Dynamic").."/Vision/"..tostring(game.GameId)
        o.ToggleKey=Enum.KeyCode.RightShift
        local window=Vision.new(o); self.Window=window
        local destroy=window.Destroy
        function window:Destroy()
            if not lib.Destroyed then lib:Destroy() else destroy(self) end
        end
        function window:AddTab(tabOptions)
            local tab=self:CreateTab(tabOptions)
            function tab:AddModule(source)
                local module
                module=self:CreateModule({Name=source.Name,Id=source.Flag,ToolTip=source.ToolTip,
                    UpdateInterval=source.UpdateInterval,OnEnabled=source.OnEnabled,OnDisabled=source.OnDisabled,OnUpdate=source.OnUpdate,
                    OnChange=function(value) lib.Flags[source.Flag or source.Name:gsub("%s+","")]=value end})
                return decorateModule(module,source)
            end
            function tab:AddParagraph(source)
                local section=self:CreateSection({Name="",Id=self.Id.."/paragraph"..tostring(#self.Sections+1),Column=#self.Sections%2+1})
                local lines={}; for i=2,30 do if source["Line"..i] then table.insert(lines,source["Line"..i]) end end
                local paragraph=section:AddParagraph({Title=source.Line1 or source.Title,Text=source.Text or table.concat(lines,"\n")})
                paragraph.Title.RichText=true; paragraph.Body.RichText=true
                return paragraph
            end
            return tab
        end
        local filesAvailable=type(readfile)=="function" and type(writefile)=="function" and type(isfile)=="function" and type(isfolder)=="function" and type(makefolder)=="function" and type(listfiles)=="function"
        if filesAvailable then
            lib.ConfigSystem=ctx.Load("modules/DynamicConfig.luau")(lib,ctx.Load("modules/FileManager.luau"),options.ConfigFolder or "Dynamic",ctx.Load("modules/ConfigSafety.luau"))
            local config=lib.ConfigSystem
            local build=config.Build
            function config:ValidateStyle(data)
                if data.__VisionStyle then window:ValidateConfig(ctx.HttpService:JSONEncode(data.__VisionStyle)) end
            end
            function lib:InitializeConfig() return config:Ready() end
            local configChanged=window._configChanged
            function window:_configChanged()
                configChanged(self)
                if not self.Importing then config:ScheduleSave() end
            end
            function config:Build()
                local data=build(self)
                local style=ctx.HttpService:JSONDecode(window:ExportConfig())
                -- Only geometry and appearance. Transient/private controls are never shared.
                style.values={}; data.__VisionStyle=style
                return data
            end
            function config:ApplyStyle(data)
                if data and data.__VisionStyle then window:ImportConfig(ctx.HttpService:JSONEncode(data.__VisionStyle),true) end
            end
        else table.insert(window.Errors,"Config file APIs unavailable") end
        -- After the script has made its tabs, add settings without stealing focus.
        task.defer(function()
            if lib.Destroyed then return end
            local tab=window:CreateTab({Name="Settings",Id="VisionSettings",Icon="settings"})
            local appearance=tab:CreateSection({Name="Appearance",Id="VisionSettings/Appearance"})
            local themes={}; for name in pairs(Vision.Themes) do if name~="Lapse" then table.insert(themes,name) end end; table.sort(themes)
            appearance:AddDropdown({Name="Theme",Id="VisionSettings/theme",Options=themes,Default="Vision",Callback=function(value) window:SetTheme(value) end})
            appearance:AddColorpicker({Name="Accent",Id="VisionSettings/accent",Default=window.Theme.Accent,Callback=function(value) window:SetTheme({Accent=value}) end})
            appearance:AddDropdown({Name="Layout",Id="VisionSettings/layout",Options={"Auto","Desktop","Compact"},Callback=function(value) window:SetLayout(value) end})
            lib:_createConfigManager(tab)
        end)
        return window
    end
    function lib:_createConfigManager(tab)
        local section=tab:CreateSection({Name="Configs",Id="VisionSettings/Configs",Column=2})
        local config=self.ConfigSystem
        if not config then section:AddLabel("File APIs are needed to save configs"); return end
        local chosen=section:AddDropdown({Name="Saved configs",Id="VisionSettings/config",Options={"None"},IgnoreConfig=true})
        local name=section:AddTextbox({Name="Config name",Id="VisionSettings/name",Default="Default",IgnoreConfig=true,MaxLength=64})
        local code=section:AddTextbox({Name="Share code",Id="VisionSettings/code",IgnoreConfig=true,MaxLength=1000000})
        local function refresh(selection)
            local names=config:List(); if #names==0 then names={"None"} end
            chosen:SetOptions(names,table.find(names,selection) and selection or names[1])
        end
        local function action(fn)
            local ok,err=pcall(fn); if not ok then lib:Notify(tostring(err)) end
        end
        section:AddButtons({
            {Name="Save",Callback=function() action(function() config:Save(name:Get()); config:SetAutoLoad(name:Get()); refresh(name:Get()); lib:Notify("Config saved") end) end},
            {Name="Load",Callback=function() action(function() assert(config:Load(chosen:Get()),"Config not found"); config:SetAutoLoad(chosen:Get()); lib:Notify("Config loaded") end) end},
            {Name="Delete",Callback=function() action(function() config:Delete(chosen:Get()); refresh(); lib:Notify("Config deleted") end) end},
        })
        section:AddButtons({
            {Name="Export",Callback=function() action(function() code:Set(config:Export(chosen:Get()),true); config:CopyExport(chosen:Get()); lib:Notify("Share code copied") end) end},
            {Name="Import",Callback=function() action(function() assert(config:Import(code:Get()),"Invalid share code"); refresh(); lib:Notify("Config imported") end) end},
            {Name="Refresh",Callback=function() action(refresh) end},
        })
        section:AddButton({Name="Reset",Callback=function() action(function()
            for _,module in pairs(lib.Modules) do module:SetEnabled(false) end
            for flag,value in pairs(lib.Defaults) do
                local control=lib.ToggleMap[flag] or lib.SliderMap[flag] or lib.DropdownMap[flag] or lib.TextBoxMap[flag] or lib.ColorPickerMap[flag] or lib.KeybindMap[flag]
                if control then control:Set(h.copy(value)) end
            end
        end) end})
        section:AddToggle({Name="Autosave",Id="VisionSettings/autosave",Default=true,IgnoreConfig=true,Callback=function(value) config:SetAutoSave(value) end})
        action(refresh)
    end
    return lib
end
return true
end
