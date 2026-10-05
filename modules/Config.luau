-- Edit config behavior here. Loaded by init.luau.
return function(ctx)
local Library, Window, Tab, Section, Control = ctx.Library, ctx.Window, ctx.Tab, ctx.Section, ctx.Control
local Players, UIS, TweenService, HttpService, RunService = ctx.Players, ctx.UIS, ctx.TweenService, ctx.HttpService, ctx.RunService
local Safety=ctx.Load("modules/ConfigSafety.luau")
local h = ctx.Helpers
local rgb, new, corner, padding, list, point, primary, copy, contains, encodeValue, decodeValue = h.rgb, h.new, h.corner, h.padding, h.list, h.point, h.primary, h.copy, h.contains, h.encodeValue, h.decodeValue
function Window:ExportConfig()
    local values={}
    for id,c in pairs(self.Controls) do if not c.IgnoreConfig then values[id]={value=encodeValue(c:Get()),alpha=c.Kind=="Colorpicker" and c.Alpha or nil} end end
    local sections={}
    for _,tab in ipairs(self.Tabs) do for _,s in ipairs(tab.Sections) do table.insert(sections,{id=s.Id,tabId=tab.Id,tab=tab.Name,name=s.Name,column=s.Column,detached=s.Detached,x=s.Root.Position.X.Offset,y=s.Root.Position.Y.Offset,order=s.Root.LayoutOrder}) end end
    local colors={}; for name,color in pairs(self.Theme) do colors[name]=color:ToHex() end
    return HttpService:JSONEncode({version=1,theme=self.ThemeName,themeColors=colors,layout=self.Layout,values=values,window={x=self.Main.Position.X.Offset,y=self.Main.Position.Y.Offset,width=self.DesiredSize.X,height=self.DesiredSize.Y},sections=sections})
end

local function finite(n)
    return type(n)=="number" and n==n and math.abs(n)<math.huge
end
local function array(value,message)
    assert(type(value)=="table",message)
    local count=0
    for key in pairs(value) do
        assert(type(key)=="number" and key>=1 and key%1==0,message)
        count=count+1
    end
    assert(count==#value,message)
end

function Window:ValidateConfig(json)
    local data=Safety.DecodeJson(json); assert(type(data)=="table" and data.version==1 and type(data.values)=="table" and data.values~=Safety.Null,"Invalid config format")
    -- Validate all control values before committing any change.
    local pending={}
    for id,record in pairs(data.values) do
        local c=self.Controls[id]
        if c and not c.IgnoreConfig then
            assert(type(record)=="table","Invalid config record")
            assert(record.alpha==nil or c.Kind=="Colorpicker","Alpha only valid for colorpickers")
            local value=decodeValue(record.value)
            if c.Kind=="Dropdown" and not c.Multi and c.Aliases[value] then value=c.Aliases[value] end
            if c.Kind=="Toggle" then assert(type(value)=="boolean","Invalid toggle")
            elseif c.Kind=="Slider" then assert(type(value)=="number" and value==value and math.abs(value)<math.huge,"Invalid slider")
            elseif c.Kind=="Dropdown" then
                if c.Multi then array(value,"Invalid multi dropdown"); for _,v in ipairs(value) do assert(contains(c.Options,v),"Invalid option") end else assert(contains(c.Options,value),"Invalid option") end
            elseif c.Kind=="Keybind" then assert(type(value)=="string" and (value=="None" or Enum.KeyCode[value]),"Invalid keybind")
            elseif c.Kind=="Colorpicker" then assert(typeof(value)=="Color3","Invalid color"); assert(record.alpha==nil or type(record.alpha)=="number" and record.alpha==record.alpha and record.alpha>=0 and record.alpha<=1,"Invalid alpha")
            elseif c.Kind=="Textbox" then assert(type(value)=="string" and utf8.len(value)~=nil and utf8.len(value)<=c.MaxLength,"Invalid textbox") end
            table.insert(pending,{c,value,record.alpha})
        end
    end
    assert(data.layout==nil or data.layout=="Auto" or data.layout=="Desktop" or data.layout=="Compact","Invalid layout")
    assert(data.theme==nil or type(data.theme)=="string" and Library.Themes[data.theme],"Invalid theme")
    if data.window then assert(type(data.window)=="table","Invalid window geometry"); for _,key in ipairs({"x","y","width","height"}) do local n=data.window[key]; assert(type(n)=="number" and n==n and math.abs(n)<math.huge,"Invalid window geometry") end end
    local colors={}
    if data.themeColors then
        assert(type(data.themeColors)=="table","Invalid theme colors")
        for name,hex in pairs(data.themeColors) do assert(self.Theme[name] and type(hex)=="string" and hex:match("^%x%x%x%x%x%x$"),"Invalid theme color"); colors[name]=Color3.fromHex(hex) end
    end
    local pendingSections={}
    if data.sections then
        array(data.sections,"Invalid sections")
        for _,record in ipairs(data.sections) do
            assert(type(record)=="table" and (type(record.id)=="string" or type(record.tab)=="string" and type(record.name)=="string"),"Invalid section record")
            assert(record.tabId==nil or type(record.tabId)=="string","Invalid tab Id")
            local matches={}; local destination
            for _,tab in ipairs(self.Tabs) do
                if record.tabId and tab.Id==record.tabId then destination=tab end
                for _,section in ipairs(tab.Sections) do
                    if record.id and section.Id==record.id or not record.id and tab.Name==record.tab and section.Name==record.name then table.insert(matches,section) end
                end
            end
            assert(#matches<=1,"Ambiguous legacy section name; use stable IDs")
            if #matches==1 then
                local section=matches[1]
                for _,entry in ipairs(pendingSections) do assert(entry.section~=section,"Duplicate section record") end
                table.insert(pendingSections,{section=section,tab=destination or section.Tab,record=record})
            end
            assert(record.column==nil or record.column==1 or record.column==2,"Invalid section column")
            assert(record.detached==nil or type(record.detached)=="boolean","Invalid detached state")
            assert(not record.detached or finite(record.x) and finite(record.y),"Detached sections need coordinates")
            for _,field in ipairs({"x","y","order"}) do local n=record[field]; assert(n==nil or type(n)=="number" and n==n and math.abs(n)<math.huge,"Invalid section geometry") end
        end
    end
    return data,pending,colors,pendingSections
end

function Window:ImportConfig(json,silent)
    local data,pending,colors,pendingSections=self:ValidateConfig(json)
    local snapshot=not self.ConfigRestoring and self:ExportConfig() or nil
    local wasImporting=self.Importing; self.Importing=true
    local ok,err=pcall(function()
        if data.theme then self:SetTheme(data.theme) end
        if next(colors) then self:SetTheme(colors) end
        if data.layout then self:SetLayout(data.layout) end
        for _,entry in ipairs(pending) do if entry[3]~=nil then entry[1]:SetAlpha(entry[3],true) end; if not entry[1].Module then entry[1]:Set(entry[2],true) end end
        if data.window then self.DesiredSize=Vector2.new(math.max(280,data.window.width),math.max(240,data.window.height)); self.Main.Position=UDim2.fromOffset(data.window.x,data.window.y); self:_layout() end
        for _,entry in ipairs(pendingSections) do
            local section,record=entry.section,entry.record
            section:Dock(entry.tab,record.column or section.Column)
            if record.order~=nil then section.Root.LayoutOrder=record.order end
            if record.detached then section:Detach(Vector2.new(record.x,record.y)) end
        end
    end)
    self.Importing=wasImporting
    if not ok then
        if snapshot then
            self.ConfigRestoring=true
            local restored,restoreErr=pcall(function() self:ImportConfig(snapshot,true) end)
            self.ConfigRestoring=nil
            if not restored then err=tostring(err).."; rollback failed: "..tostring(restoreErr) end
        end
        error(err,0)
    end
    if silent==false then
        for _,entry in ipairs(pending) do if not entry[1].Module and entry[1].Kind~="Keybind" then entry[1]:_callback(entry[1]:Get()) end end
    end
    for _,entry in ipairs(pending) do if entry[1].Module then entry[1]:Set(entry[2],silent~=false) end end
    return true
end
local function configName(name)
    assert(type(name)=="string" and #name>0 and #name<=64 and name:match("^[%w_ ]+$"),"Use a simple config name")
    return name..".json"
end

-- Use the same relative folder validation for every disk operation.
local function configFolder(self)
    local folder=self.ConfigFolder
    assert(type(folder)=="string" and #folder>0 and not folder:find("\\",1,true)
        and folder:sub(1,1)~="/" and not folder:find(":",1,true)
        and not folder:find("//",1,true) and folder:sub(-1)~="/","Invalid config folder")
    for part in folder:gmatch("[^/]+") do
        assert(part~=".." and part~="." and not part:find("%c"),"Invalid config folder")
    end
    return folder
end

function Window:SaveConfig(name)
    assert(type(writefile)=="function" and type(makefolder)=="function" and type(isfolder)=="function","Executor file APIs unavailable. Use ExportConfig instead")
    local filename=configName(name); local folder=configFolder(self); local path=""
    local json=self:ExportConfig()
    for part in folder:gmatch("[^/]+") do path=path=="" and part or path.."/"..part; if not isfolder(path) then makefolder(path) end end
    local target=folder.."/"..filename
    assert(type(isfile)=="function" and type(readfile)=="function","Executor readback APIs unavailable")
    local files={IsFile=function(_,p) return isfile(p) end,ReadFile=function(_,p) return readfile(p) end,WriteFile=function(_,p,v) writefile(p,v) end}
    Safety.WriteVerified(files,target,folder.."/"..name..".backup.json",json,function(value) self:ValidateConfig(value) end)
    return target
end

function Window:LoadConfig(name,silent)
    assert(type(readfile)=="function","Executor readfile unavailable. Use ImportConfig instead")
    local path=configFolder(self).."/"..configName(name)
    local ok,result=pcall(function() return self:ImportConfig(readfile(path),silent) end)
    if ok then return result end
    local backup=configFolder(self).."/"..name..".backup.json"
    if type(isfile)=="function" and isfile(backup) then return self:ImportConfig(readfile(backup),silent),"backup" end
    error(result,0)
end

function Window:ListConfigs()
    assert(type(listfiles)=="function" and type(isfolder)=="function","Executor listfiles/isfolder unavailable")
    local folder=configFolder(self)
    if not isfolder(folder) then return {} end
    local names={}; local seen={}
    for _,path in ipairs(listfiles(folder)) do
        local filename=path:gsub("\\","/"):match("([^/]+)$")
        local name=filename and filename:match("^(.+)%.json$")
        if name and pcall(configName,name) and not seen[name] then
            seen[name]=true; table.insert(names,name)
        end
    end
    table.sort(names)
    return names
end

function Window:DeleteConfig(name)
    assert(type(delfile)=="function" and type(isfile)=="function","Executor delfile/isfile unavailable")
    local path=configFolder(self).."/"..configName(name)
    local removed=false
    if isfile(path) then delfile(path); removed=true end
    local backup=configFolder(self).."/"..name..".backup.json"
    if isfile(backup) then delfile(backup); removed=true end
    return removed
end

function Window:ConfigureAutosave(options)
    options=options or {}
    assert(type(options)=="table","Autosave expects options")
    local name=options.Name or "Auto"; configName(name); configFolder(self)
    local debounce=options.Debounce or 1
    assert(finite(debounce) and debounce>=.1 and debounce<=60,"Autosave debounce must be 0.1 to 60 seconds")
    self.AutosaveRevision=(self.AutosaveRevision or 0)+1
    self.Autosave={Name=name,Debounce=debounce,Enabled=options.Enabled~=false}
    for _,c in ipairs(self.Order or {}) do if c.AutosaveToggle then c:Set(self.Autosave.Enabled,true) end end
    return self.Autosave
end

function Window:_configChanged()
    if self.Dead or self.Importing or not self.Autosave or not self.Autosave.Enabled then return end
    self.AutosaveRevision=(self.AutosaveRevision or 0)+1
    local revision=self.AutosaveRevision; local settings=self.Autosave
    task.delay(settings.Debounce,function()
        if self.Dead or self.AutosaveRevision~=revision or self.Autosave~=settings or not settings.Enabled then return end
        local ok,err=pcall(function() self:SaveConfig(settings.Name) end)
        if not ok then self.LastAutosaveError=tostring(err); table.insert(self.Errors,tostring(err)); warn("Vision autosave: "..tostring(err)) else self.LastAutosaveError=nil end
    end)
end

function Window:ResetConfig(silent)
    assert(not self.Dead,"Window destroyed")
    self:_releaseHolds()
    self.Importing=true
    local ok,err=pcall(function()
        self:ClosePopup()
        for _,c in ipairs(self.Order) do
            if not c.IgnoreConfig then
                if c.Kind=="Colorpicker" then c:SetAlpha(c.DefaultAlpha,true) end
                c:Set(copy(c.DefaultValue),silent~=false)
            end
        end
        local sections={}
        for _,tab in ipairs(self.Tabs) do for _,section in ipairs(tab.Sections) do table.insert(sections,section) end end
        for _,section in ipairs(sections) do section:Dock(section.InitialTab,section.InitialColumn); section.Root.LayoutOrder=section.Order end
        local initial=self.InitialState
        self.ThemeName=initial.themeName; self:SetTheme(initial.theme); self:SetLayout(initial.layout)
        self.DesiredSize=initial.size; self.Main.Position=initial.position; self:_layout()
    end)
    self.Importing=false
    if not ok then error(err,0) end
    self:_configChanged()
    return true
end

function Window:CreateConfigManager(options)
    options=options or {}
    local tab=options.Tab or self:CreateTab({Name="Settings",Id=options.Id or "VisionSettings",Icon="settings"})
    local section=tab:CreateSection({Name="Configs",Id=(options.Id or "VisionSettings").."/Configs"})
    local manager={Window=self,Section=section}
    local id=section.Id
    manager.Selected=section:AddDropdown({Name="Saved configs",Id=id.."/selected",Options={"None"},IgnoreConfig=true})
    manager.Name=section:AddTextbox({Name="Config name",Id=id.."/name",Default="Default",MaxLength=64,IgnoreConfig=true})
    function manager:Refresh(selectName)
        local names=self.Window:ListConfigs()
        self.HasConfigs=#names>0
        if #names==0 then names={"None"} end
        self.Selected:SetOptions(names,contains(names,selectName) and selectName or names[1])
        return names
    end
    local function perform(action)
        local ok,err=pcall(action)
        if not ok then self:Notify({Text=tostring(err)}) end
    end
    manager.Buttons=section:AddButtons({
        {Name="Save",Callback=function() perform(function() local name=manager.Name:Get(); self:SaveConfig(name); manager:Refresh(name); self:Notify("Config saved") end) end},
        {Name="Load",Callback=function() perform(function() local name=manager.Selected:Get(); assert(manager.HasConfigs,"Choose a config first"); self:LoadConfig(name,false); self:Notify("Config loaded") end) end},
        {Name="Delete",Callback=function() perform(function() local name=manager.Selected:Get(); assert(manager.HasConfigs,"Choose a config first"); self:DeleteConfig(name); manager:Refresh(); self:Notify("Config deleted") end) end},
        {Name="Reset",Callback=function() perform(function() self:ResetConfig(false); self:Notify("Settings reset") end) end},
    })
    local settings=self:ConfigureAutosave({Name=options.AutosaveName or "Auto",Debounce=options.Debounce or 1,Enabled=options.Autosave==true})
    manager.Autosave=section:AddToggle({Name="Autosave",Id=id.."/autosave",Default=settings.Enabled,IgnoreConfig=true,Callback=function(value) self:ConfigureAutosave({Name=self.Autosave.Name,Debounce=self.Autosave.Debounce,Enabled=value}); if value then self:_configChanged() end end})
    manager.Autosave.AutosaveToggle=true
    section:AddButton({Name="Refresh",Callback=function() perform(function() manager:Refresh() end) end})
    perform(function() manager:Refresh() end)
    return manager
end

return true
end
