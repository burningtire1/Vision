-- Edit window behavior here. Loaded by init.luau.
return function(ctx)
local Library, Window, Tab, Section, Control = ctx.Library, ctx.Window, ctx.Tab, ctx.Section, ctx.Control
local Players, UIS, TweenService, HttpService, RunService = ctx.Players, ctx.UIS, ctx.TweenService, ctx.HttpService, ctx.RunService
local h = ctx.Helpers
local rgb, new, corner, padding, list, point, primary, copy, contains, encodeValue, decodeValue = h.rgb, h.new, h.corner, h.padding, h.list, h.point, h.primary, h.copy, h.contains, h.encodeValue, h.decodeValue
function Window:_connect(signal, fn)
    local connection=signal:Connect(fn); table.insert(self.Connections,connection); return connection
end

function Window:_paint(obj, property, token)
    obj[property]=self.Theme[token]
    table.insert(self.Paint,{obj,property,token})
end

function Window:_frame(parent,name,size,token)
    local obj=new("Frame",{Name=name,Size=size or UDim2.fromScale(1,1),BorderSizePixel=0},parent)
    self:_paint(obj,"BackgroundColor3",token or "Surface")
    return obj
end

function Window:_stroke(obj)
    local stroke=new("UIStroke",{Thickness=1,ApplyStrokeMode=Enum.ApplyStrokeMode.Border},obj)
    self:_paint(stroke,"Color","Border"); return stroke
end

function Window:_text(parent,text,size,muted)
    local obj=new("TextLabel",{BackgroundTransparency=1,Text=text or "",TextSize=13,Font=Enum.Font.BuilderSans,TextXAlignment=Enum.TextXAlignment.Left,Size=size or UDim2.fromScale(1,1)},parent)
    self:_paint(obj,"TextColor3",muted and "Muted" or "Text"); return obj
end

function Window:_button(parent,text,size)
    local obj=new("TextButton",{Name="Button",Text=text or "",TextSize=13,Font=Enum.Font.BuilderSans,AutoButtonColor=false,BorderSizePixel=0,Size=size or UDim2.fromScale(1,1)},parent)
    self:_paint(obj,"BackgroundColor3","Raised"); self:_paint(obj,"TextColor3","Text")
    corner(obj); self:_stroke(obj)
    obj:SetAttribute("BackgroundRole","Raised")
    self:_connect(obj.MouseEnter,function() if not self.Dead and not obj:GetAttribute("NoHover") then obj.BackgroundColor3=self.Theme[obj:GetAttribute("BackgroundRole")]:Lerp(self.Theme.Text,0.045) end end)
    self:_connect(obj.MouseLeave,function() if not self.Dead and not obj:GetAttribute("NoHover") then obj.BackgroundColor3=self.Theme[obj:GetAttribute("BackgroundRole")] end end)
    return obj
end

function Window:_input(parent,text,size)
    local obj=new("TextBox",{Text=text or "",ClearTextOnFocus=false,TextSize=13,Font=Enum.Font.BuilderSans,TextXAlignment=Enum.TextXAlignment.Left,BorderSizePixel=0,Size=size or UDim2.fromScale(1,1)},parent)
    self:_paint(obj,"BackgroundColor3","Raised"); self:_paint(obj,"TextColor3","Text")
    self:_paint(obj,"PlaceholderColor3","Muted"); corner(obj); self:_stroke(obj); padding(obj,6); return obj
end

function Window:_icon(parent,name,position,size,token)
    local asset=self.Icons[name]
    local obj=new("ImageLabel",{Name="Icon_"..name,BackgroundTransparency=1,Image=asset or "",Position=position or UDim2.new(),Size=UDim2.fromOffset(size or 16,size or 16)},parent)
    self:_paint(obj,"ImageColor3",token or "Muted")
    if not asset then
        -- Honest fallback if executor has no custom asset API.
        local glyph=({search="⌕",x="×",["chevron-down"]="⌄",["chevron-right"]="›",grip="⠿",check="✓",settings="⚙",crosshair="⊕",keyboard="⌨",eye="◉",swords="⚔",footprints="↗"})[name] or "•"
        local fallback=self:_text(obj,glyph); fallback.TextXAlignment=Enum.TextXAlignment.Center
    end
    return obj
end

function Window:_drag(handle, fn)
    self:_connect(handle.InputBegan,function(input)
        if not primary(input) then return end
        local origin=point(input); local update,finish=fn(origin,input)
        if update then self.Drag={input=input,update=update,finish=finish} end
    end)
end

function Window:_popup(name,size,anchor)
    self:ClosePopup()
    self.Shield.Visible=true; self.Shield.BackgroundTransparency=1
    local popup=self:_frame(self.Overlay,name,size,"Surface"); popup.ZIndex=102; corner(popup,6); self:_stroke(popup)
    local p=anchor and anchor.AbsolutePosition or Vector2.new(80,80)
    p=p-self.Overlay.AbsolutePosition
    local s=anchor and anchor.AbsoluteSize or Vector2.zero
    local vp=self.Gui.AbsoluteSize
    popup.Position=UDim2.fromOffset(math.clamp(p.X,8,math.max(8,vp.X-size.X.Offset-8)),math.clamp(p.Y+s.Y+4,8,math.max(8,vp.Y-size.Y.Offset-8)))
    self.Popup=popup
    return popup
end

function Window:ClosePopup()
    if self.Popup then self.Popup:Destroy(); self.Popup=nil end
    if self.Shield then self.Shield.Visible=false end
end

function Window:SetTheme(theme)
    if type(theme)=="string" then assert(Library.Themes[theme],"Unknown theme"); self.ThemeName=theme; theme=Library.Themes[theme] end
    local merged=table.clone(self.Theme or Library.Themes.Lapse)
    for k,v in pairs(theme) do if merged[k] then assert(typeof(v)=="Color3","Theme values must be Color3"); merged[k]=v end end
    self.Theme=merged
    local alive={}
    for _,binding in ipairs(self.Paint) do
        if binding[1].Parent then
            if not (binding[2]=="BackgroundColor3" and binding[1]:GetAttribute("OwnColor")) then binding[1][binding[2]]=merged[binding[3]] end
            table.insert(alive,binding)
        end
    end
    self.Paint=alive
    for _,control in pairs(self.Controls) do control:_render() end
    for _,tab in ipairs(self.Tabs) do tab:_render() end
    self:UpdateHUD()
end

function Window:SetLayout(mode)
    if mode=="Mobile" then mode="Compact" end
    assert(mode=="Auto" or mode=="Desktop" or mode=="Compact","Layout must be Auto, Desktop, Compact or Mobile")
    self.Layout=mode; self:_layout()
end

function Window:_layout()
    local viewport=self.Gui.AbsoluteSize
    local width=math.min(self.DesiredSize.X,math.max(240,viewport.X-24))
    local height=math.min(self.DesiredSize.Y,math.max(200,viewport.Y-24))
    local compact=self.Layout=="Compact" or (self.Layout=="Auto" and (width<560 or viewport.X<640))
    self.Compact=compact
    self.Main.Size=UDim2.fromOffset(width,height)
    self.SearchButton.Size=UDim2.fromOffset(compact and 32 or 92,28)
    self.SearchButton.Position=UDim2.new(1,compact and -42 or -102,0,8)
    self.SearchCaption.Visible=not compact
    self.TabBar.Size=UDim2.new(1,compact and -138 or -198,0,44)
    for _,tab in ipairs(self.Tabs) do
        tab.Right.Visible=not compact
        local available=width-24
        local columnWidth=math.floor((available-10)/2)
        tab.Left.Size=UDim2.fromOffset(compact and available or columnWidth,0)
        tab.Right.Size=UDim2.fromOffset(columnWidth,0); tab.Right.Position=UDim2.fromOffset(columnWidth+10,0)
        for _,section in ipairs(tab.Sections) do
            if not section.Detached then section.Root.Parent=(compact or section.Column==1) and tab.Left or tab.Right end
        end
    end
    self:_clamp(self.Main)
    if self.MobileToggle then self.MobileToggle.Visible=compact or UIS.TouchEnabled end
end

function Window:_clamp(frame)
    local size=self.Gui.AbsoluteSize; local p=frame.Position; local fs=frame.AbsoluteSize
    frame.Position=UDim2.fromOffset(math.clamp(p.X.Offset,0,math.max(0,size.X-fs.X)),math.clamp(p.Y.Offset,0,math.max(0,size.Y-fs.Y)))
end

function Library.new(options)
    options=options or {}
    local self=setmetatable({Connections={},Paint={},Tabs={},Controls={},Order={},Keybinds={},RecentColors={},Icons={},Layout=options.Layout=="Mobile" and "Compact" or options.Layout or "Auto",DesiredSize=options.Size or Vector2.new(650,452),Theme=table.clone(Library.Themes.Vision),ThemeName="Vision",ConfigFolder=options.ConfigFolder or "LapseUI/configs",Dead=false,Errors={},ActiveTab=nil},Window)
    ctx.Assets.Register(self)
    local parent=options.Parent
    if not parent then
        local ok,root=pcall(function() return type(gethui)=="function" and gethui() or Players.LocalPlayer:WaitForChild("PlayerGui") end)
        parent=ok and root or Players.LocalPlayer:WaitForChild("PlayerGui")
    end
    self.Gui=new("ScreenGui",{Name=options.Id or "VisionUI",IgnoreGuiInset=true,ResetOnSpawn=false,DisplayOrder=10000,ZIndexBehavior=Enum.ZIndexBehavior.Sibling},parent)
    self.Main=self:_frame(self.Gui,"Window",UDim2.fromOffset(650,452),"Background"); self.Main.Position=options.Position or UDim2.fromOffset(100,140); corner(self.Main,7); self:_stroke(self.Main)
    local shadow=new("Frame",{Name="Shadow",BackgroundColor3=Color3.new(),BackgroundTransparency=0.7,BorderSizePixel=0,Size=UDim2.new(1,10,1,10),Position=UDim2.fromOffset(-5,-3),ZIndex=0},self.Main); corner(shadow,10)
    local header=self:_frame(self.Main,"Header",UDim2.new(1,0,0,44),"Surface"); corner(header,7)
    self.Title=self:_text(header,options.Title or "Vision",UDim2.fromOffset(72,44)); self.Title.Position=UDim2.fromOffset(13,0); self.Title.Font=Enum.Font.BuilderSansMedium; self.Title.TextSize=16
    self.TabBar=new("ScrollingFrame",{Name="Tabs",BackgroundTransparency=1,BorderSizePixel=0,Position=UDim2.fromOffset(87,0),Size=UDim2.new(1,-198,0,44),CanvasSize=UDim2.new(),AutomaticCanvasSize=Enum.AutomaticSize.X,ScrollingDirection=Enum.ScrollingDirection.X,ScrollBarThickness=2,VerticalScrollBarInset=Enum.ScrollBarInset.None},header)
    self:_paint(self.TabBar,"ScrollBarImageColor3","Accent"); local tl=list(self.TabBar,4,Enum.FillDirection.Horizontal); tl.VerticalAlignment=Enum.VerticalAlignment.Center
    self.SearchButton=self:_button(header,"",UDim2.fromOffset(92,28)); self.SearchButton.Name="SearchButton"; self.SearchButton.Position=UDim2.new(1,-102,0,8)
    self:_icon(self.SearchButton,"search",UDim2.fromOffset(7,6),16)
    self.SearchCaption=self:_text(self.SearchButton,"Search...",UDim2.new(1,-29,1,0),true); self.SearchCaption.Position=UDim2.fromOffset(28,0); self.SearchCaption.TextSize=12
    self.Body=new("Frame",{Name="Body",BackgroundTransparency=1,Position=UDim2.fromOffset(0,44),Size=UDim2.new(1,0,1,-76),ClipsDescendants=true},self.Main)
    local footer=self:_frame(self.Main,"Footer",UDim2.new(1,0,0,32),"Surface"); footer.Position=UDim2.new(0,0,1,-32); corner(footer,7)
    self.Status=self:_text(footer,options.Footer or ("Welcome back, "..Players.LocalPlayer.DisplayName.."!"),UDim2.new(1,-45,1,0),true); self.Status.Position=UDim2.fromOffset(10,0); self.Status.TextSize=12
    self.Resize=self:_button(footer,"",UDim2.fromOffset(26,26)); self.Resize.Position=UDim2.new(1,-30,0,3); self.Resize.BackgroundTransparency=1; self.Resize:FindFirstChildOfClass("UIStroke").Enabled=false
    self:_icon(self.Resize,"grip",UDim2.fromOffset(6,5),16)
    self.Overlay=new("Frame",{Name="Overlay",BackgroundTransparency=1,Size=UDim2.fromScale(1,1),ZIndex=100},self.Gui)
    self.Shield=new("TextButton",{Name="Dismiss",BackgroundColor3=Color3.new(),BackgroundTransparency=1,Text="",AutoButtonColor=false,Size=UDim2.fromScale(1,1),Visible=false,ZIndex=101},self.Overlay)
    self.MobileToggle=self:_button(self.Gui,"Vision",UDim2.fromOffset(76,38)); self.MobileToggle.Name="MobileToggle"; self.MobileToggle.Position=UDim2.new(0,12,1,-50); self.MobileToggle.ZIndex=90
    self:_connect(self.MobileToggle.Activated,function() self.Main.Visible=not self.Main.Visible; self:ClosePopup() end)
    self:_connect(self.Shield.Activated,function() self:ClosePopup() end)
    self.Toasts=new("Frame",{Name="Notifications",BackgroundTransparency=1,Position=UDim2.new(1,-316,0,20),Size=UDim2.fromOffset(296,0),AutomaticSize=Enum.AutomaticSize.Y,ZIndex=200},self.Gui); list(self.Toasts,8)
    self.HUD=self:_frame(self.Gui,"KeybindHUD",UDim2.fromOffset(180,30),"Surface"); self.HUD.Position=UDim2.fromOffset(24,70); self.HUD.AutomaticSize=Enum.AutomaticSize.Y; self.HUD.Size=UDim2.fromOffset(180,0); corner(self.HUD); padding(self.HUD,7); list(self.HUD,5)
    local hudHeader=self:_text(self.HUD,"      Keybinds",UDim2.new(1,0,0,20)); hudHeader.Font=Enum.Font.BuilderSansMedium; self:_icon(hudHeader,"keyboard",UDim2.fromOffset(0,2),16)
    self.HUDRows=new("Frame",{Name="Entries",BackgroundTransparency=1,Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y},self.HUD); self.HUDRows.LayoutOrder=1; list(self.HUDRows,3)
    local function move(frame)
        return function(origin)
            local start=frame.Position
            return function(p) local d=p-origin; frame.Position=UDim2.fromOffset(start.X.Offset+d.X,start.Y.Offset+d.Y); self:_clamp(frame) end
        end
    end
    self:_drag(header,move(self.Main)); self:_drag(hudHeader,move(self.HUD))
    self:_drag(self.Resize,function(origin)
        local start=self.Main.AbsoluteSize
        return function(p) local d=p-origin; self.DesiredSize=Vector2.new(math.max(280,start.X+d.X),math.max(240,start.Y+d.Y)); self:_layout() end
    end)
    self:_connect(UIS.InputChanged,function(input)
        local drag=self.Drag
        if drag and (input==drag.input or (drag.input.UserInputType==Enum.UserInputType.MouseButton1 and input.UserInputType==Enum.UserInputType.MouseMovement)) then drag.update(point(input)) end
    end)
    self:_connect(UIS.InputEnded,function(input)
        if self.Drag and input==self.Drag.input then local drag=self.Drag; self.Drag=nil; if drag.finish then drag.finish(point(input)) end end
        for _,bind in ipairs(self.Keybinds) do if bind.Mode=="Hold" and bind.Value==input.KeyCode.Name and bind.Active then bind.Active=false; if bind.Target then bind.Target:Set(false) end; bind:_callback(false); self:UpdateHUD() end end
    end)
    self:_connect(UIS.InputBegan,function(input,processed)
        if input.UserInputType~=Enum.UserInputType.Keyboard then return end
        if self.Capturing then
            local bind=self.Capturing; self.Capturing=nil
            bind:Set(input.KeyCode==Enum.KeyCode.Escape and "None" or input.KeyCode.Name); return
        end
        -- Visibility shortcuts must work even when Roblox consumes Shift input.
        if input.KeyCode==(options.ToggleKey or Enum.KeyCode.RightShift) then
            self:SetVisible(self.Visible==false); return
        end
        if processed or UIS:GetFocusedTextBox() then return end
        if input.KeyCode==Enum.KeyCode.Escape then self:ClosePopup() end
        if input.KeyCode==Enum.KeyCode.F and (UIS:IsKeyDown(Enum.KeyCode.LeftControl) or UIS:IsKeyDown(Enum.KeyCode.RightControl)) then self:OpenSearch() end
        for _,bind in ipairs(self.Keybinds) do
            if not bind.Disabled and bind.Value==input.KeyCode.Name then
                if bind.Mode=="Hold" then bind.Active=true else bind.Active=not bind.Active end
                if bind.Target then bind.Target:Set(bind.Active) end
                bind:_callback(bind.Active); self:UpdateHUD()
            end
        end
    end)
    self:_connect(self.SearchButton.Activated,function() self:OpenSearch() end)
    self:_connect(self.Gui:GetPropertyChangedSignal("AbsoluteSize"),function() self:_layout() end)
    self:_layout(); if options.Theme then self:SetTheme(options.Theme) end
    return self
end

function Window:SetVisible(visible)
    if self.Dead then return end
    visible=visible==true
    self.Visible=visible
    self.VisibilityRevision=(self.VisibilityRevision or 0)+1
    local revision=self.VisibilityRevision
    self:ClosePopup()
    local roots={self.Main}
    for _,tab in ipairs(self.Tabs) do
        for _,section in ipairs(tab.Sections) do
            if section.Detached then table.insert(roots,section.Root) end
        end
    end
    self.VisibilityTweens=self.VisibilityTweens or {}
    for _,tween in ipairs(self.VisibilityTweens) do tween:Cancel() end
    table.clear(self.VisibilityTweens)
    for _,root in ipairs(roots) do
        local scale=root:FindFirstChild("VisibilityScale")
        if not scale then scale=new("UIScale",{Name="VisibilityScale",Scale=1},root) end
        if visible and not root.Visible then scale.Scale=.96 end
        root.Visible=true
        local tween=TweenService:Create(scale,TweenInfo.new(.16,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{Scale=visible and 1 or .96})
        table.insert(self.VisibilityTweens,tween); tween:Play()
    end
    task.delay(.16,function()
        if self.Dead or self.VisibilityRevision~=revision then return end
        for _,root in ipairs(roots) do
            if root.Parent and (root==self.Main or root.Parent==self.Gui) then
                root.Visible=visible
                if not visible then root.VisibilityScale.Scale=1 end
            end
        end
    end)
end


function Window:Destroy()
    if self.Dead then return end
    self.Dead=true; self.Drag=nil; self.Capturing=nil
    for _,connection in ipairs(self.Connections) do connection:Disconnect() end
    table.clear(self.Connections); self.Gui:Destroy()
end

return true
end
