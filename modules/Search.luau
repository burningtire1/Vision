-- Edit search behavior here. Loaded by init.luau.
return function(ctx)
local Library, Window, Tab, Section, Control = ctx.Library, ctx.Window, ctx.Tab, ctx.Section, ctx.Control
local Players, UIS, TweenService, HttpService, RunService = ctx.Players, ctx.UIS, ctx.TweenService, ctx.HttpService, ctx.RunService
local h = ctx.Helpers
local rgb, new, corner, padding, list, point, primary, copy, contains, encodeValue, decodeValue = h.rgb, h.new, h.corner, h.padding, h.list, h.point, h.primary, h.copy, h.contains, h.encodeValue, h.decodeValue
function Window:Search(query)
    local result={}; query=string.lower(query or "")
    for _,c in ipairs(self.Order) do
        local haystack=string.lower(c.Name.." "..c.Section.Name.." "..c.Section.Tab.Name)
        if query=="" or haystack:find(query,1,true) then table.insert(result,c) end
    end
    return result
end

function Window:OpenSearch()
    local width=math.min(400,self.Gui.AbsoluteSize.X-24)
    local popup=self:_popup("SearchPopup",UDim2.fromOffset(width,244))
    local origin=self.Main.AbsolutePosition-self.Overlay.AbsolutePosition
    popup.Position=UDim2.fromOffset(math.max(12,origin.X+(self.Main.AbsoluteSize.X-width)/2),math.max(12,origin.Y+14))
    self:_clamp(popup); self.Shield.BackgroundTransparency=0.35
    local field=self:_input(popup,"",UDim2.new(1,-16,0,34)); field.Name="Query"; field.PlaceholderText="Search controls..."; field.Position=UDim2.fromOffset(8,8)
    local results=new("ScrollingFrame",{Name="Results",BackgroundTransparency=1,BorderSizePixel=0,Position=UDim2.fromOffset(8,49),Size=UDim2.new(1,-16,1,-57),CanvasSize=UDim2.new(),AutomaticCanvasSize=Enum.AutomaticSize.Y,ScrollBarThickness=3},popup); list(results,4); self:_paint(results,"ScrollBarImageColor3","Accent")
    local function update()
        for _,child in ipairs(results:GetChildren()) do if child:IsA("GuiObject") then child:Destroy() end end
        local found=self:Search(field.Text)
        for i,c in ipairs(found) do
            local button=self:_button(results,"",UDim2.new(1,-5,0,30)); button.LayoutOrder=i
            local title=self:_text(button,c.Name,UDim2.new(0.62,-8,1,0)); title.Position=UDim2.fromOffset(8,0); title.TextTruncate=Enum.TextTruncate.AtEnd
            local context=self:_text(button,c.Section.Name,UDim2.new(0.38,-10,1,0),true); context.Position=UDim2.fromScale(0.62,0); context.TextXAlignment=Enum.TextXAlignment.Right; context.TextSize=11; context.TextTruncate=Enum.TextTruncate.AtEnd
            self:_connect(button.Activated,function() self:ClosePopup(); c:Focus() end)
        end
        if #found==0 then self:_text(results,"No results",UDim2.new(1,0,0,30),true) end
    end
    self:_connect(field:GetPropertyChangedSignal("Text"),update); update(); field:CaptureFocus()
end

return true
end
