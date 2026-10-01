-- Edit notifications behavior here. Loaded by init.luau.
return function(ctx)
local Library, Window, Tab, Section, Control = ctx.Library, ctx.Window, ctx.Tab, ctx.Section, ctx.Control
local Players, UIS, TweenService, HttpService, RunService = ctx.Players, ctx.UIS, ctx.TweenService, ctx.HttpService, ctx.RunService
local h = ctx.Helpers
local rgb, new, corner, padding, list, point, primary, copy, contains, encodeValue, decodeValue = h.rgb, h.new, h.corner, h.padding, h.list, h.point, h.primary, h.copy, h.contains, h.encodeValue, h.decodeValue
function Window:Notify(options)
    if type(options)=="string" then options={Text=options} end
    options=options or {}
    local toast=self:_frame(self.Toasts,"Notification",UDim2.new(1,0,0,68),"Surface"); toast.LayoutOrder=#self.Toasts:GetChildren(); corner(toast,6); self:_stroke(toast)
    self:_icon(toast,"bell",UDim2.fromOffset(10,13),16,"Accent")
    local title=self:_text(toast,options.Title or "Vision",UDim2.new(1,-58,0,24)); title.Position=UDim2.fromOffset(34,6); title.Font=Enum.Font.BuilderSansMedium
    local body=self:_text(toast,options.Text or "",UDim2.new(1,-45,0,28),true); body.Position=UDim2.fromOffset(12,30); body.TextWrapped=true; body.TextSize=12
    local dismiss=self:_button(toast,"",UDim2.fromOffset(20,20)); dismiss.Position=UDim2.new(1,-27,0,8); self:_icon(dismiss,"x",UDim2.fromOffset(3,3),14)
    local bar=self:_frame(toast,"Duration",UDim2.new(1,-4,0,2),"Accent"); bar.Position=UDim2.new(0,2,1,-3)
    local duration=math.clamp(options.Duration or 4,0.5,60)
    local tween=TweenService:Create(bar,TweenInfo.new(duration,Enum.EasingStyle.Linear),{Size=UDim2.fromOffset(0,2)}); tween:Play()
    self:_connect(dismiss.Activated,function() if toast.Parent then toast:Destroy() end end)
    task.delay(duration,function() if toast.Parent then toast:Destroy() end end)
    return toast
end

return true
end
