-- Edit tabs behavior here. Loaded by init.luau.
return function(ctx)
local Library, Window, Tab, Section, Control = ctx.Library, ctx.Window, ctx.Tab, ctx.Section, ctx.Control
local Players, UIS, TweenService, HttpService, RunService = ctx.Players, ctx.UIS, ctx.TweenService, ctx.HttpService, ctx.RunService
local h = ctx.Helpers
local rgb, new, corner, padding, list, point, primary, copy, contains, encodeValue, decodeValue = h.rgb, h.new, h.corner, h.padding, h.list, h.point, h.primary, h.copy, h.contains, h.encodeValue, h.decodeValue
function Window:CreateTab(options)
    if type(options)=="string" then options={Name=options} end
    options=options or {}
    local id=options.Id or options.Name or "Tab"
    assert(type(id)=="string" and #id>0,"Tab Id must be a nonempty string")
    for _,existing in ipairs(self.Tabs) do assert(existing.Id~=id,"Duplicate tab Id: "..id) end
    local tab=setmetatable({Id=id,Window=self,Name=options.Name or "Tab",Sections={}},Tab)
    tab.Button=self:_button(self.TabBar,"",UDim2.fromOffset(math.max(80,#tab.Name*7+35),28)); tab.Button.Name="Tab_"..tab.Name; tab.Button.LayoutOrder=#self.Tabs+1
    tab.Icon=self:_icon(tab.Button,options.Icon or "crosshair",UDim2.fromOffset(8,6),16)
    tab.Caption=self:_text(tab.Button,tab.Name,UDim2.new(1,-31,1,0),true); tab.Caption.Position=UDim2.fromOffset(30,0)
    tab.Page=new("ScrollingFrame",{Name="Page_"..tab.Name,Visible=false,BackgroundTransparency=1,BorderSizePixel=0,Size=UDim2.fromScale(1,1),CanvasSize=UDim2.new(),AutomaticCanvasSize=Enum.AutomaticSize.Y,ScrollBarThickness=4,ScrollingDirection=Enum.ScrollingDirection.Y,VerticalScrollBarInset=Enum.ScrollBarInset.ScrollBar},self.Body)
    self:_paint(tab.Page,"ScrollBarImageColor3","Accent"); padding(tab.Page,10)
    tab.Left=new("Frame",{Name="Left",BackgroundTransparency=1,Size=UDim2.new(0.5,-5,0,0),AutomaticSize=Enum.AutomaticSize.Y},tab.Page)
    tab.Right=new("Frame",{Name="Right",BackgroundTransparency=1,Position=UDim2.new(0.5,5,0,0),Size=UDim2.new(0.5,-5,0,0),AutomaticSize=Enum.AutomaticSize.Y},tab.Page)
    list(tab.Left,10); list(tab.Right,10)
    table.insert(self.Tabs,tab); self:_connect(tab.Button.Activated,function() tab:Select() end)
    if not self.ActiveTab then tab:Select() end; self:_layout(); return tab
end

function Tab:_render()
    local w=self.Window; local selected=w.ActiveTab==self
    self.Button.BackgroundTransparency=selected and 0 or 1
    self.Button:FindFirstChildOfClass("UIStroke").Enabled=selected
    self.Caption.TextColor3=selected and w.Theme.Text or w.Theme.Muted
    self.Icon.ImageColor3=selected and w.Theme.Text or w.Theme.Muted
end

function Tab:Select()
    local w=self.Window; if w.Dead or w.ActiveTab==self then return end; w.ActiveTab=self; w:ClosePopup()
    for _,tab in ipairs(w.Tabs) do tab.Page.Visible=tab==self; tab:_render() end
    self.Page.Position=UDim2.fromOffset(0,w.Animations==false and 0 or 8)
    w:_tween(self.Page,{Position=UDim2.fromOffset(0,0)},.18)
    local left=self.Button.AbsolutePosition.X-w.TabBar.AbsolutePosition.X+w.TabBar.CanvasPosition.X
    local x=w.TabBar.CanvasPosition.X; local viewport=w.TabBar.AbsoluteSize.X
    if left<x then w.TabBar.CanvasPosition=Vector2.new(left,0) elseif left+self.Button.AbsoluteSize.X>x+viewport then w.TabBar.CanvasPosition=Vector2.new(left+self.Button.AbsoluteSize.X-viewport,0) end
end

return true
end
