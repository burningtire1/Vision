-- Edit sections behavior here. Loaded by init.luau.
return function(ctx)
local Library, Window, Tab, Section, Control = ctx.Library, ctx.Window, ctx.Tab, ctx.Section, ctx.Control
local Players, UIS, TweenService, HttpService, RunService = ctx.Players, ctx.UIS, ctx.TweenService, ctx.HttpService, ctx.RunService
local h = ctx.Helpers
local rgb, new, corner, padding, list, point, primary, copy, contains, encodeValue, decodeValue = h.rgb, h.new, h.corner, h.padding, h.list, h.point, h.primary, h.copy, h.contains, h.encodeValue, h.decodeValue
function Tab:CreateSection(options)
    if type(options)=="string" then options={Name=options} end
    options=options or {}; local w=self.Window
    local column=options.Column or ((#self.Sections%2)+1)
    local section=setmetatable({Window=w,Tab=self,Name=options.Name or "Section",Column=column,Controls={},Detached=false,Order=#self.Sections+1},Section)
    section.Root=new("Frame",{Name="Section_"..section.Name,BackgroundTransparency=1,Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,LayoutOrder=section.Order},(w.Compact or column==1) and self.Left or self.Right)
    list(section.Root,6)
    section.Header=new("TextButton",{Name="SectionHeader",Text="",BackgroundTransparency=1,AutoButtonColor=false,Size=UDim2.new(1,0,0,22),LayoutOrder=0},section.Root)
    local title=w:_text(section.Header,section.Name,UDim2.new(1,options.Icon and -55 or -33,1,0),true); title.Font=Enum.Font.BuilderSansMedium; title.TextSize=14; title.TextTruncate=Enum.TextTruncate.AtEnd; title.Position=UDim2.fromOffset(options.Icon and 24 or 2,0); section.Title=title
    if options.Icon then section.Icon=w:_icon(section.Header,options.Icon,UDim2.fromOffset(2,3),16) end
    w:_paint(section.Header,"BackgroundColor3","Raised"); corner(section.Header,5); section.HeaderStroke=w:_stroke(section.Header); section.HeaderStroke.Enabled=false
    section.Content=w:_frame(section.Root,"Content",UDim2.new(1,0,0,0)); section.Content.AutomaticSize=Enum.AutomaticSize.Y; section.Content.LayoutOrder=1; corner(section.Content); w:_stroke(section.Content); padding(section.Content,8); list(section.Content,5)
    section.DockButton=w:_button(section.Header,"",UDim2.fromOffset(20,20)); section.DockButton.Position=UDim2.new(1,-22,0,1); section.DockButton.BackgroundTransparency=1; section.DockButton:FindFirstChildOfClass("UIStroke").Enabled=false; section.DockButton.Visible=false; w:_icon(section.DockButton,"rotate-ccw",UDim2.fromOffset(3,3),14)
    w:_connect(section.DockButton.Activated,function() section:Dock() end)
    w:_drag(section.Header,function(origin)
        local started=false; local position
        return function(p)
            if not started and (p-origin).Magnitude>7 then
                position=section.Root.AbsolutePosition-w.Overlay.AbsolutePosition; section:Detach(position); started=true
            end
            if started then local d=p-origin; section.Root.Position=UDim2.fromOffset(position.X+d.X,position.Y+d.Y); w:_clamp(section.Root) end
        end,function(p)
            if not started then return end
            local bp=w.Body.AbsolutePosition; local bs=w.Body.AbsoluteSize
            if p.X>=bp.X and p.X<=bp.X+bs.X and p.Y>=bp.Y and p.Y<=bp.Y+bs.Y then
                local col=(p.X-bp.X<bs.X/2 or w.Compact) and 1 or 2
                section:Dock(w.ActiveTab or self,col,p.Y)
            end
        end
    end)
    table.insert(self.Sections,section)
    return section
end

function Section:Detach(position)
    if self.Detached then return end
    local size=self.Root.AbsoluteSize; local old=self.Root.AbsolutePosition-self.Window.Overlay.AbsolutePosition
    self.Root.Parent=self.Window.Gui; self.Root.Size=UDim2.fromOffset(math.max(260,size.X),0); self.Root.Position=UDim2.fromOffset((position or old).X,(position or old).Y); self.Root.ZIndex=20
    self.Detached=true; self.IsSubTab=true; self.Root.Visible=self.Window.Visible~=false; self.Root.Name="SubTab_"..self.Name; self.DockButton.Visible=true
    self.Header.BackgroundTransparency=0; self.Header.Size=UDim2.new(1,0,0,34); self.HeaderStroke.Enabled=true
    self.Title.Position=UDim2.fromOffset(self.Icon and 30 or 10,0); self.Title.TextColor3=self.Window.Theme.Text
    if self.Icon then self.Icon.Position=UDim2.fromOffset(9,9) end
    self.DockButton.Position=UDim2.new(1,-28,0,7); self.Window:_clamp(self.Root)
end

function Section:Dock(tab,column,y)
    tab=tab or self.Tab
    assert(tab.Window==self.Window,"Cannot dock into another window")
    if tab~=self.Tab then local old=table.find(self.Tab.Sections,self); if old then table.remove(self.Tab.Sections,old) end; table.insert(tab.Sections,self); self.Tab=tab end
    self.Column=column or self.Column; self.Detached=false; self.IsSubTab=false; self.Root.Visible=true; self.Root.Name="Section_"..self.Name; local scale=self.Root:FindFirstChild("VisibilityScale"); if scale then scale.Scale=1 end; self.DockButton.Visible=false
    self.Header.BackgroundTransparency=1; self.Header.Size=UDim2.new(1,0,0,22); self.HeaderStroke.Enabled=false
    self.Title.Position=UDim2.fromOffset(self.Icon and 24 or 2,0); self.Title.TextColor3=self.Window.Theme.Muted
    if self.Icon then self.Icon.Position=UDim2.fromOffset(2,3) end
    self.Root.Parent=(self.Window.Compact or self.Column==1) and tab.Left or tab.Right
    self.Root.Size=UDim2.new(1,0,0,0); self.Root.Position=UDim2.new(); self.Root.ZIndex=1
    if y then
        local peers={}
        for _,s in ipairs(tab.Sections) do if s~=self and not s.Detached and s.Column==self.Column then table.insert(peers,s) end end
        table.sort(peers,function(a,b) return a.Root.LayoutOrder<b.Root.LayoutOrder end)
        local inserted=false; local order=1
        for _,s in ipairs(peers) do
            if not inserted and y<s.Root.AbsolutePosition.Y+s.Root.AbsoluteSize.Y/2 then self.Root.LayoutOrder=order; order+=1; inserted=true end
            s.Root.LayoutOrder=order; order+=1
        end
        if not inserted then self.Root.LayoutOrder=order end
    end
end

function Section:_control(kind,options,height)
    options=options or {}; local w=self.Window
    local id=options.Id or (self.Tab.Name.."/"..self.Name.."/"..(options.Name or kind))
    assert(not w.Controls[id],"Duplicate control Id: "..id)
    local c=setmetatable({Kind=kind,Id=id,Name=options.Name or kind,Section=self,Window=w,Callback=options.Callback,Value=options.Default,Disabled=false},Control)
    c.Row=new("CanvasGroup",{Name=id,BackgroundTransparency=1,Size=UDim2.new(1,0,0,height or 24),LayoutOrder=#self.Controls+1},self.Content)
    c.Label=w:_text(c.Row,c.Name,UDim2.new(1,-58,0,24)); c.Label.TextTruncate=Enum.TextTruncate.AtEnd
    w.Controls[id]=c; table.insert(w.Order,c); table.insert(self.Controls,c)
    c:SetDisabled(options.Disabled); return c
end

return true
end
