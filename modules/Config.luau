-- Edit config behavior here. Loaded by init.luau.
return function(ctx)
local Library, Window, Tab, Section, Control = ctx.Library, ctx.Window, ctx.Tab, ctx.Section, ctx.Control
local Players, UIS, TweenService, HttpService, RunService = ctx.Players, ctx.UIS, ctx.TweenService, ctx.HttpService, ctx.RunService
local h = ctx.Helpers
local rgb, new, corner, padding, list, point, primary, copy, contains, encodeValue, decodeValue = h.rgb, h.new, h.corner, h.padding, h.list, h.point, h.primary, h.copy, h.contains, h.encodeValue, h.decodeValue
function Window:ExportConfig()
    local values={}
    for id,c in pairs(self.Controls) do values[id]={value=encodeValue(c:Get()),alpha=c.Kind=="Colorpicker" and c.Alpha or nil} end
    local sections={}
    for _,tab in ipairs(self.Tabs) do for _,s in ipairs(tab.Sections) do table.insert(sections,{tab=tab.Name,name=s.Name,column=s.Column,detached=s.Detached,x=s.Root.Position.X.Offset,y=s.Root.Position.Y.Offset,order=s.Root.LayoutOrder}) end end
    local colors={}; for name,color in pairs(self.Theme) do colors[name]=color:ToHex() end
    return HttpService:JSONEncode({version=1,theme=self.ThemeName,themeColors=colors,layout=self.Layout,values=values,window={x=self.Main.Position.X.Offset,y=self.Main.Position.Y.Offset,width=self.DesiredSize.X,height=self.DesiredSize.Y},sections=sections})
end

function Window:ImportConfig(json,silent)
    local data=HttpService:JSONDecode(json); assert(type(data)=="table" and data.version==1 and type(data.values)=="table","Invalid config format")
    -- Validate all control values before committing any change.
    local pending={}
    for id,record in pairs(data.values) do
        local c=self.Controls[id]
        if c then
            assert(type(record)=="table","Invalid config record")
            local value=decodeValue(record.value)
            if c.Kind=="Dropdown" and not c.Multi and c.Aliases[value] then value=c.Aliases[value] end
            if c.Kind=="Toggle" then assert(type(value)=="boolean","Invalid toggle")
            elseif c.Kind=="Slider" then assert(type(value)=="number" and value==value and math.abs(value)<math.huge,"Invalid slider")
            elseif c.Kind=="Dropdown" then
                if c.Multi then assert(type(value)=="table","Invalid multi dropdown"); for _,v in ipairs(value) do assert(contains(c.Options,v),"Invalid option") end else assert(contains(c.Options,value),"Invalid option") end
            elseif c.Kind=="Keybind" then assert(type(value)=="string" and (value=="None" or Enum.KeyCode[value]),"Invalid keybind")
            elseif c.Kind=="Colorpicker" then assert(typeof(value)=="Color3","Invalid color"); assert(record.alpha==nil or type(record.alpha)=="number" and record.alpha==record.alpha and math.abs(record.alpha)<math.huge,"Invalid alpha")
            elseif c.Kind=="Textbox" then assert(type(value)=="string","Invalid textbox") end
            table.insert(pending,{c,value,record.alpha})
        end
    end
    assert(data.layout==nil or data.layout=="Auto" or data.layout=="Desktop" or data.layout=="Compact","Invalid layout")
    assert(data.theme==nil or Library.Themes[data.theme],"Invalid theme")
    if data.window then for _,key in ipairs({"x","y","width","height"}) do local n=data.window[key]; assert(type(n)=="number" and n==n and math.abs(n)<math.huge,"Invalid window geometry") end end
    local colors={}
    if data.themeColors then
        assert(type(data.themeColors)=="table","Invalid theme colors")
        for name,hex in pairs(data.themeColors) do assert(self.Theme[name] and type(hex)=="string" and hex:match("^%x%x%x%x%x%x$"),"Invalid theme color"); colors[name]=Color3.fromHex(hex) end
    end
    if data.sections then
        assert(type(data.sections)=="table","Invalid sections")
        for _,record in ipairs(data.sections) do
            assert(type(record)=="table" and type(record.tab)=="string" and type(record.name)=="string","Invalid section record")
            for _,field in ipairs({"x","y","order"}) do local n=record[field]; assert(n==nil or type(n)=="number" and n==n and math.abs(n)<math.huge,"Invalid section geometry") end
        end
    end
    if data.theme then self:SetTheme(data.theme) end
    if next(colors) then self:SetTheme(colors) end
    if data.layout then self:SetLayout(data.layout) end
    for _,entry in ipairs(pending) do entry[1]:Set(entry[2],silent~=false); if entry[3] then entry[1]:SetAlpha(entry[3],true) end end
    if data.window then self.DesiredSize=Vector2.new(math.max(280,data.window.width),math.max(240,data.window.height)); self.Main.Position=UDim2.fromOffset(data.window.x,data.window.y); self:_layout() end
    for _,record in ipairs(data.sections or {}) do
        for _,tab in ipairs(self.Tabs) do if tab.Name==record.tab then for _,section in ipairs(tab.Sections) do if section.Name==record.name then
            section:Dock(tab,record.column==2 and 2 or 1)
            if type(record.order)=="number" then section.Root.LayoutOrder=record.order end
            if record.detached and type(record.x)=="number" and type(record.y)=="number" then section:Detach(Vector2.new(record.x,record.y)) end
        end end end end
    end
    return true
end
local function configName(name)
    assert(type(name)=="string" and #name>0 and #name<=64 and name:match("^[%w_ ]+$"),"Use a simple config name")
    return name..".json"
end

function Window:SaveConfig(name)
    assert(type(writefile)=="function" and type(makefolder)=="function" and type(isfolder)=="function","Executor file APIs unavailable. Use ExportConfig instead")
    local filename=configName(name); local path=""
    for part in self.ConfigFolder:gmatch("[^/]+") do assert(part~=".." and part~=".","Invalid config folder"); path=path=="" and part or path.."/"..part; if not isfolder(path) then makefolder(path) end end
    writefile(self.ConfigFolder.."/"..filename,self:ExportConfig()); return self.ConfigFolder.."/"..filename
end

function Window:LoadConfig(name,silent)
    assert(type(readfile)=="function","Executor readfile unavailable. Use ImportConfig instead")
    return self:ImportConfig(readfile(self.ConfigFolder.."/"..configName(name)),silent)
end

return true
end
