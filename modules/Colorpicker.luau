-- Edit colorpicker behavior here. Loaded by init.luau.
return function(ctx)
local Library, Window, Tab, Section, Control = ctx.Library, ctx.Window, ctx.Tab, ctx.Section, ctx.Control
local Players, UIS, TweenService, HttpService, RunService = ctx.Players, ctx.UIS, ctx.TweenService, ctx.HttpService, ctx.RunService
local h = ctx.Helpers
local rgb, new, corner, padding, list, point, primary, copy, contains, encodeValue, decodeValue = h.rgb, h.new, h.corner, h.padding, h.list, h.point, h.primary, h.copy, h.contains, h.encodeValue, h.decodeValue
function Section:AddColorpicker(options)
    options=options or {}; local c=self:_control("Colorpicker",options,24); local w=self.Window
    c.Alpha=options.Alpha or 1; c.Swatches=table.clone(options.Swatches or {rgb(86,127,214),rgb(145,120,255),rgb(255,79,94),rgb(61,203,185),rgb(155,239,30)})
    c.Swatch=w:_button(c.Row,"",UDim2.fromOffset(24,18)); c.Swatch.Position=UDim2.new(1,-24,0,3)
    c.Swatch:SetAttribute("NoHover",true)
    w:_connect(c.Swatch.Activated,function() if not c.Disabled then c:Open() end end)
    c:Set(options.Default or w.Theme.Accent,true); return c
end

function Control:SetAlpha(alpha,silent)
    assert(self.Kind=="Colorpicker" and type(alpha)=="number" and alpha==alpha and math.abs(alpha)<math.huge,"Expected finite alpha")
    self.Alpha=math.clamp(alpha,0,1)
    if not silent then self:_callback(self.Value) end
end

function Window:_rememberColor(color)
    for i=#self.RecentColors,1,-1 do if self.RecentColors[i]==color then table.remove(self.RecentColors,i) end end
    table.insert(self.RecentColors,1,color); while #self.RecentColors>8 do table.remove(self.RecentColors) end
end

function Window:_openColor(c)
    local popup=self:_popup("ColorpickerPopup",UDim2.fromOffset(248,318),c.Swatch)
    local h,s,v=c.Value:ToHSV()
    local title=self:_text(popup,c.Name,UDim2.new(1,-38,0,28)); title.Position=UDim2.fromOffset(10,0)
    local close=self:_button(popup,"",UDim2.fromOffset(20,20)); close.Position=UDim2.new(1,-26,0,4); self:_icon(close,"x",UDim2.fromOffset(3,3),14); self:_connect(close.Activated,function() self:_rememberColor(c.Value); self:ClosePopup() end)
    local sv=self:_button(popup,"",UDim2.fromOffset(170,170)); sv.Name="SVPlane"; sv.Position=UDim2.fromOffset(10,34); sv.ClipsDescendants=true; sv:SetAttribute("NoHover",true); sv:SetAttribute("OwnColor",true)
    local white=new("Frame",{BackgroundColor3=Color3.new(1,1,1),Size=UDim2.fromScale(1,1),BorderSizePixel=0},sv); corner(white)
    new("UIGradient",{Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,0),NumberSequenceKeypoint.new(1,1)})},white)
    local black=new("Frame",{BackgroundColor3=Color3.new(),Size=UDim2.fromScale(1,1),BorderSizePixel=0},sv); corner(black)
    new("UIGradient",{Rotation=90,Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(1,0)})},black)
    local marker=new("Frame",{Name="SVMarker",Size=UDim2.fromOffset(6,6),BackgroundColor3=Color3.new(1,1,1),BorderSizePixel=0,ZIndex=4},sv); corner(marker,3); local outline=new("UIStroke",{Color=Color3.new(),Thickness=1},marker)
    local hue=self:_button(popup,"",UDim2.fromOffset(14,170)); hue.Name="Hue"; hue.Position=UDim2.fromOffset(190,34)
    local stops={}; for i=0,6 do table.insert(stops,ColorSequenceKeypoint.new(i/6,Color3.fromHSV(i/6,1,1))) end
    hue:SetAttribute("NoHover",true); hue:SetAttribute("OwnColor",true); hue.BackgroundColor3=Color3.new(1,1,1); new("UIGradient",{Rotation=90,Color=ColorSequence.new(stops)},hue)
    local hueMark=new("Frame",{Size=UDim2.new(1,4,0,2),Position=UDim2.fromOffset(-2,0),BackgroundColor3=Color3.new(1,1,1),BorderSizePixel=0},hue)
    local alpha=self:_button(popup,"",UDim2.fromOffset(14,170)); alpha.Name="Alpha"; alpha.Position=UDim2.fromOffset(216,34); alpha:SetAttribute("NoHover",true)
    for y=0,16 do for x=0,1 do new("Frame",{BackgroundColor3=(x+y)%2==0 and rgb(95,95,102) or rgb(46,46,52),BorderSizePixel=0,Size=UDim2.fromOffset(7,10),Position=UDim2.fromOffset(x*7,y*10)},alpha) end end
    local alphaTint=new("Frame",{Size=UDim2.fromScale(1,1),BorderSizePixel=0},alpha); corner(alphaTint)
    new("UIGradient",{Rotation=90,Transparency=NumberSequence.new(0,1)},alphaTint)
    local alphaMark=new("Frame",{Size=UDim2.new(1,4,0,2),Position=UDim2.fromOffset(-2,0),BackgroundColor3=Color3.new(1,1,1),BorderSizePixel=0},alpha)
    local hex=self:_input(popup,"",UDim2.fromOffset(125,24)); hex.Name="HexInput"; hex.Position=UDim2.fromOffset(10,213)
    local rgbBox=self:_input(popup,"",UDim2.fromOffset(170,24)); rgbBox.Name="RGBInput"; rgbBox.Position=UDim2.fromOffset(10,243)
    local preview=self:_button(popup,"",UDim2.fromOffset(32,24)); preview.Position=UDim2.fromOffset(198,243); preview:SetAttribute("NoHover",true); preview:SetAttribute("OwnColor",true)
    local function refresh()
        sv.BackgroundColor3=Color3.fromHSV(h,1,1); marker.Position=UDim2.new(s,-3,1-v,-3); hueMark.Position=UDim2.new(0,-2,h,-1)
        alphaMark.Position=UDim2.new(0,-2,1-c.Alpha,-1); alphaTint.BackgroundColor3=c.Value; preview.BackgroundColor3=c.Value
        hex.Text="#"..string.upper(c.Value:ToHex()); rgbBox.Text=string.format("%d, %d, %d",math.round(c.Value.R*255),math.round(c.Value.G*255),math.round(c.Value.B*255))
    end
    local function change() c:Set(Color3.fromHSV(h,s,v)); refresh() end
    self:_drag(sv,function(origin)
        local function update(p) s=math.clamp((p.X-sv.AbsolutePosition.X)/sv.AbsoluteSize.X,0,1); v=1-math.clamp((p.Y-sv.AbsolutePosition.Y)/sv.AbsoluteSize.Y,0,1); change() end
        update(origin); return update,function() self:_rememberColor(c.Value) end
    end)
    self:_drag(hue,function(origin)
        local function update(p) h=math.clamp((p.Y-hue.AbsolutePosition.Y)/hue.AbsoluteSize.Y,0,1); change() end
        update(origin); return update,function() self:_rememberColor(c.Value) end
    end)
    self:_drag(alpha,function(origin)
        local function update(p) c:SetAlpha(1-math.clamp((p.Y-alpha.AbsolutePosition.Y)/alpha.AbsoluteSize.Y,0,1)); refresh() end
        update(origin); return update
    end)
    self:_connect(hex.FocusLost,function()
        local text=hex.Text:gsub("#",""):gsub("%s","")
        if text:match("^%x%x%x%x%x%x$") then c:Set(Color3.fromHex(text)); h,s,v=c.Value:ToHSV(); self:_rememberColor(c.Value) end; refresh()
    end)
    self:_connect(rgbBox.FocusLost,function()
        local r,g,b=rgbBox.Text:match("^%s*(%d+)%s*,%s*(%d+)%s*,%s*(%d+)%s*$")
        if r and tonumber(r)<=255 and tonumber(g)<=255 and tonumber(b)<=255 then c:Set(rgb(tonumber(r),tonumber(g),tonumber(b))); h,s,v=c.Value:ToHSV(); self:_rememberColor(c.Value) end; refresh()
    end)
    local swatches=new("Frame",{Name="Swatches",BackgroundTransparency=1,Size=UDim2.fromOffset(228,18),Position=UDim2.fromOffset(10,278)},popup); list(swatches,5,Enum.FillDirection.Horizontal)
    local colors=table.clone(self.RecentColors)
    for _,color in ipairs(c.Swatches) do if #colors<8 and not contains(colors,color) then table.insert(colors,color) end end
    for _,color in ipairs(colors) do
        local button=self:_button(swatches,"",UDim2.fromOffset(23,17)); button.BackgroundColor3=color; button:SetAttribute("NoHover",true); button:SetAttribute("OwnColor",true)
        self:_connect(button.Activated,function() c:Set(color); h,s,v=color:ToHSV(); self:_rememberColor(color); refresh() end)
    end
    local hint=self:_text(popup,"RGB / HEX editable",UDim2.fromOffset(200,14),true); hint.Position=UDim2.fromOffset(10,301); hint.TextSize=10
    self:_drag(title,function(origin)
        local start=popup.Position
        return function(p) local d=p-origin; popup.Position=UDim2.fromOffset(start.X.Offset+d.X,start.Y.Offset+d.Y); self:_clamp(popup) end
    end)
    refresh()
end

return true
end
