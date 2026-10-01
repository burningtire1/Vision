-- Edit keybinds behavior here. Loaded by init.luau.
return function(ctx)
local Library, Window, Tab, Section, Control = ctx.Library, ctx.Window, ctx.Tab, ctx.Section, ctx.Control
local Players, UIS, TweenService, HttpService, RunService = ctx.Players, ctx.UIS, ctx.TweenService, ctx.HttpService, ctx.RunService
local h = ctx.Helpers
local rgb, new, corner, padding, list, point, primary, copy, contains, encodeValue, decodeValue = h.rgb, h.new, h.corner, h.padding, h.list, h.point, h.primary, h.copy, h.contains, h.encodeValue, h.decodeValue
function Control:Bind(options)
    assert(self.Kind=="Toggle","Bind requires a toggle")
    options=table.clone(options or {}); options.Name=options.Name or self.Name; options.Id=options.Id or (self.Id.."/keybind"); options.Target=self
    local bind=self.Section:AddKeybind(options)
    if options.Inline~=false then
        bind.Row.Visible=false; bind.Key.Parent=self.Row; bind.Key.Size=UDim2.fromOffset(21,20)
        bind.Key.Position=UDim2.new(1,-60,0,2); self.Label.Size=UDim2.new(1,-78,1,0)
    end
    return bind
end

function Section:AddKeybind(options)
    options=options or {}; local c=self:_control("Keybind",options,24); local w=self.Window
    c.Mode=options.Mode or "Toggle"; assert(c.Mode=="Toggle" or c.Mode=="Hold","Keybind mode must be Toggle or Hold")
    c.Target=options.Target; c.Active=c.Target and c.Target.Value or false
    c.Key=w:_button(c.Row,"...",UDim2.fromOffset(38,22)); c.Key.Position=UDim2.new(1,-38,0,1); c.Key.TextSize=12
    table.insert(w.Keybinds,c)
    w:_connect(c.Key.Activated,function() if c.Disabled or UIS.TouchEnabled and not UIS.KeyboardEnabled then return end; w.Capturing=c; c.Key.Text="..." end)
    c:Set(options.Default or "None",true); return c
end

function Window:UpdateHUD()
    if not self.HUDRows then return end
    for _,bind in ipairs(self.Keybinds) do
        if not bind.HUDRow then
            bind.HUDRow=self:_text(self.HUDRows,"",UDim2.new(1,0,0,22)); bind.HUDRow.LayoutOrder=table.find(self.Keybinds,bind)
            bind.HUDIcon=self:_icon(bind.HUDRow,"corner-down-right",UDim2.fromOffset(0,3),15)
        end
        bind.HUDRow.Text="      "..bind.Name.."   "..bind.Value
        bind.HUDRow.TextColor3=bind.Active and self.Theme.Accent or self.Theme.Muted
        bind.HUDIcon.ImageColor3=bind.Active and self.Theme.Accent or self.Theme.Muted
        bind.HUDRow.Visible=bind.Value~="None" and not bind.Disabled
    end
end

return true
end
