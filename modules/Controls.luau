-- Edit controls behavior here. Loaded by init.luau.
return function(ctx)
local Library, Window, Tab, Section, Control = ctx.Library, ctx.Window, ctx.Tab, ctx.Section, ctx.Control
local Players, UIS, TweenService, HttpService, RunService = ctx.Players, ctx.UIS, ctx.TweenService, ctx.HttpService, ctx.RunService
local h = ctx.Helpers
local rgb, new, corner, padding, list, point, primary, copy, contains, encodeValue, decodeValue = h.rgb, h.new, h.corner, h.padding, h.list, h.point, h.primary, h.copy, h.contains, h.encodeValue, h.decodeValue
function Control:_callback(value)
    if self.Callback then
        local ok,err=pcall(self.Callback,copy(value),self)
        if not ok then table.insert(self.Window.Errors,tostring(err)); warn("Lapse callback: "..tostring(err)) end
    end
end

function Control:Get() return copy(self.Value) end

function Control:Set(value,silent)
    if self.Kind=="Toggle" then assert(type(value)=="boolean","Toggle expects boolean")
    elseif self.Kind=="Slider" then
        assert(type(value)=="number" and value==value and math.abs(value)<math.huge,"Slider expects finite number")
        value=math.clamp(self.Min+math.round((value-self.Min)/self.Step)*self.Step,self.Min,self.Max)
    elseif self.Kind=="Dropdown" then
        if not self.Multi and self.Aliases[value] then value=self.Aliases[value] end
        if self.Multi then assert(type(value)=="table","Multi dropdown expects array"); local selected={}; for _,option in ipairs(value) do assert(contains(self.Options,option),"Unknown option"); if not contains(selected,option) then table.insert(selected,option) end end; value=selected
        else assert(contains(self.Options,value),"Unknown dropdown option") end
    elseif self.Kind=="Keybind" then assert(type(value)=="string" and (value=="None" or Enum.KeyCode[value]~=nil),"Unknown KeyCode")
    elseif self.Kind=="Colorpicker" then assert(typeof(value)=="Color3","Colorpicker expects Color3")
    elseif self.Kind=="Textbox" then assert(type(value)=="string","Textbox expects string"); value=value:sub(1,self.MaxLength) end
    self.Value=copy(value); self:_render()
    if self.Kind=="Toggle" then for _,bind in ipairs(self.Window.Keybinds) do if bind.Target==self then bind.Active=value end end end
    self.Window:UpdateHUD(); if not silent and self.Kind~="Keybind" then self:_callback(value) end
end

function Control:SetDisabled(disabled)
    self.Disabled=disabled==true; self.Row:SetAttribute("Disabled",self.Disabled)
    self.Row.GroupTransparency=self.Disabled and 0.55 or 0
    if self.Input then self.Input.TextEditable=not self.Disabled end
end

function Control:Focus()
    self.Section.Tab:Select()
    local page=self.Section.Tab.Page
    if not self.Section.Detached then
        page.CanvasPosition=Vector2.new(0,math.max(0,self.Row.AbsolutePosition.Y-page.AbsolutePosition.Y+page.CanvasPosition.Y-18))
    end
    local stroke=self.Window:_stroke(self.Row); stroke.Color=self.Window.Theme.Accent
    task.delay(0.8,function() if stroke.Parent then stroke:Destroy() end end)
end

function Control:_render()
    local w=self.Window
    self.Row:SetAttribute("Value",typeof(self.Value)=="Color3" and self.Value:ToHex() or type(self.Value)=="table" and table.concat(self.Value,", ") or self.Value)
    if self.Kind=="Toggle" then
        self.Switch.BackgroundColor3=self.Value and w.Theme.Accent or w.Theme.Raised
        if self.Style=="Checkbox" then self.Tick.Visible=self.Value else self.Knob.Position=self.Value and UDim2.new(1,-17,0.5,-6) or UDim2.new(0,4,0.5,-6); self.Knob.BackgroundColor3=self.Value and Color3.new(1,1,1) or w.Theme.Muted end
    elseif self.Kind=="Slider" then
        self.Fill.Size=UDim2.fromScale((self.Value-self.Min)/(self.Max-self.Min),1)
        self.Fill.BackgroundColor3=w.Theme.Accent
        self.Thumb.Position=UDim2.new((self.Value-self.Min)/(self.Max-self.Min),-5,0.5,-5)
        local decimals=math.max(0,math.ceil(-math.log10(self.Step)))
        self.Readout.Text=string.format("%."..math.min(4,decimals).."f",self.Value)..(self.Suffix or "")
    elseif self.Kind=="Dropdown" then
        self.Caption.Text=self.Multi and (#self.Value>0 and table.concat(self.Value,", ") or "None") or self.Value
    elseif self.Kind=="Keybind" then self.Key.Text=self.Value=="None" and "..." or self.Value
    elseif self.Kind=="Colorpicker" then self.Swatch.BackgroundColor3=self.Value
    elseif self.Kind=="Textbox" then if self.Input.Text~=self.Value then self.Input.Text=self.Value end end
end

function Section:AddToggle(options)
    options=options or {}; local c=self:_control("Toggle",options,24); local w=self.Window
    c.Style=options.Style or "Pill"
    if c.Style=="Checkbox" then
        c.Switch=w:_button(c.Row,"",UDim2.fromOffset(16,16)); c.Switch.Position=UDim2.fromOffset(0,4); corner(c.Switch,3)
        c.Label.Position=UDim2.fromOffset(23,0); c.Label.Size=UDim2.new(1,-25,1,0)
        c.Tick=w:_icon(c.Switch,"check",UDim2.fromOffset(1,1),14,"Text")
    else
        c.Switch=w:_button(c.Row,"",UDim2.fromOffset(32,18)); c.Switch.Position=UDim2.new(1,-32,0,3); corner(c.Switch,9)
        c.Knob=new("Frame",{Size=UDim2.fromOffset(12,12),BorderSizePixel=0},c.Switch); corner(c.Knob,6)
    end
    c.Switch:SetAttribute("NoHover",true)
    w:_connect(c.Switch.Activated,function() if not c.Disabled then c:Set(not c.Value) end end)
    c:Set(options.Default==true,true); return c
end

function Section:AddSlider(options)
    options=options or {}; local c=self:_control("Slider",options,42); local w=self.Window
    c.Min=options.Min or 0; c.Max=options.Max or 100; c.Step=options.Step or 1; c.Suffix=options.Suffix or ""
    assert(c.Max>c.Min and c.Step>0,"Slider requires Max > Min and Step > 0")
    c.Readout=w:_text(c.Row,"",UDim2.new(0.45,0,0,22),true); c.Readout.Position=UDim2.fromScale(0.55,0); c.Readout.TextXAlignment=Enum.TextXAlignment.Right; c.Readout.TextSize=12
    c.Label.Size=UDim2.new(0.55,0,0,22)
    c.Track=w:_frame(c.Row,"Track",UDim2.new(1,0,0,5),"Raised"); c.Track.Position=UDim2.fromOffset(0,30); corner(c.Track,3)
    c.Fill=w:_frame(c.Track,"Fill",UDim2.new(),"Accent"); corner(c.Fill,3)
    c.Thumb=new("Frame",{Name="Thumb",BackgroundColor3=Color3.new(1,1,1),Size=UDim2.fromOffset(10,10),BorderSizePixel=0},c.Track); corner(c.Thumb,5)
    local hit=new("TextButton",{Name="SliderHit",Text="",BackgroundTransparency=1,Size=UDim2.new(1,0,0,20),Position=UDim2.fromOffset(0,21)},c.Row)
    w:_drag(hit,function(origin)
        if c.Disabled then return end
        local function update(p) c:Set(c.Min+math.clamp((p.X-c.Track.AbsolutePosition.X)/math.max(1,c.Track.AbsoluteSize.X),0,1)*(c.Max-c.Min)) end
        update(origin); return update
    end)
    c:Set(options.Default or c.Min,true); return c
end

function Section:AddDropdown(options)
    options=options or {}; local c=self:_control("Dropdown",options,54); local w=self.Window
    c.Options=table.clone(options.Options or {"Option 1","Option 2"}); assert(#c.Options>0,"Dropdown needs options"); c.Multi=options.Multi==true; c.Aliases=options.Aliases or {}
    c.Button=w:_button(c.Row,"",UDim2.new(1,0,0,28)); c.Button.Name="DropdownButton"; c.Button.Position=UDim2.fromOffset(0,24)
    c.Caption=w:_text(c.Button,"",UDim2.new(1,-33,1,0)); c.Caption.Position=UDim2.fromOffset(7,0); c.Caption.TextTruncate=Enum.TextTruncate.AtEnd
    w:_icon(c.Button,"chevron-down",UDim2.new(1,-23,0,7),14)
    w:_connect(c.Button.Activated,function() if not c.Disabled then c:Open() end end)
    c:Set(options.Default or (c.Multi and {} or c.Options[1]),true); return c
end

function Control:SetOptions(options,default)
    assert(self.Kind=="Dropdown" and #options>0,"Expected nonempty dropdown options")
    self.Options=table.clone(options); self:Set(default or (self.Multi and {} or self.Options[1])); self.Window:ClosePopup()
end

function Control:Open()
    if self.Disabled then return end
    if self.Kind=="Colorpicker" then self.Window:_openColor(self); return end
    assert(self.Kind=="Dropdown","Open requires dropdown or colorpicker")
    local w=self.Window; local width=math.max(190,self.Button.AbsoluteSize.X)
    local popup=w:_popup("DropdownPopup",UDim2.fromOffset(width,math.min(224,#self.Options*28+12)),self.Button)
    local scroll=new("ScrollingFrame",{Name="Options",BackgroundTransparency=1,BorderSizePixel=0,Size=UDim2.fromScale(1,1),CanvasSize=UDim2.new(),AutomaticCanvasSize=Enum.AutomaticSize.Y,ScrollBarThickness=3},popup); padding(scroll,6); list(scroll,2); w:_paint(scroll,"ScrollBarImageColor3","Accent")
    for i,option in ipairs(self.Options) do
        local selected=self.Multi and contains(self.Value,option) or self.Value==option
        local button=w:_button(scroll,"",UDim2.new(1,-3,0,26)); button.Name="Option_"..i; button.LayoutOrder=i; button.BackgroundTransparency=selected and 0 or 1; button:FindFirstChildOfClass("UIStroke").Enabled=selected
        local text=w:_text(button,option,UDim2.new(1,-25,1,0)); text.Position=UDim2.fromOffset(17,0)
        local dot=w:_frame(button,"Selected",UDim2.fromOffset(4,4),"Accent"); dot.Position=UDim2.fromOffset(6,11); corner(dot,2); dot.Visible=selected
        w:_connect(button.Activated,function()
            if self.Multi then
                local values=table.clone(self.Value); local at=table.find(values,option); if at then table.remove(values,at) else table.insert(values,option) end; self:Set(values)
                dot.Visible=contains(self.Value,option)
            else self:Set(option); w:ClosePopup() end
        end)
    end
end

function Section:AddButtons(options)
    local w=self.Window
    local row=new("Frame",{Name="Buttons",BackgroundTransparency=1,Size=UDim2.new(1,0,0,30),LayoutOrder=#self.Controls+1},self.Content)
    local buttons=options.Buttons or options; local count=#buttons; assert(count>0,"Need at least one button")
    local results={}
    for i,option in ipairs(buttons) do
        local button=w:_button(row,option.Name or "Button",UDim2.new(1/count,-((count-1)*5/count),1,0)); button.Position=UDim2.new((i-1)/count,(i-1)*5/count,0,0)
        if option.Primary then button:SetAttribute("BackgroundRole","Accent"); w:_paint(button,"BackgroundColor3","Accent") end
        w:_connect(button.Activated,function() if option.Disabled then return end; if option.Callback then local ok,err=pcall(option.Callback); if not ok then table.insert(w.Errors,tostring(err)); warn("Lapse button: "..tostring(err)) end end end)
        table.insert(results,button)
    end
    -- Reserve row order without adding nonconfigurable buttons to the registry.
    table.insert(self.Controls,{Kind="Buttons",Row=row})
    return results
end

function Section:AddButton(options) return self:AddButtons({options})[1] end

return true
end
