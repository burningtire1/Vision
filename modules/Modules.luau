-- Native module switches, conditional rows, tooltips and confirmation dialogs.
return function(ctx)
local Window, Tab, Section, Control = ctx.Window, ctx.Tab, ctx.Section, ctx.Control
local h = ctx.Helpers

function Window:Prompt(options)
    options=options or {}
    local width=math.min(360,math.max(240,self.Gui.AbsoluteSize.X-24))
    local popup=self:_popup("ConfirmPopup",UDim2.fromOffset(width,166))
    local title=self:_text(popup,options.Title or "Confirm",UDim2.new(1,-24,0,26))
    title.Position=UDim2.fromOffset(12,10)
    local body=self:_text(popup,options.Text or "Continue?",UDim2.new(1,-24,0,78),true)
    body.Position=UDim2.fromOffset(12,38); body.TextWrapped=true; body.TextYAlignment=Enum.TextYAlignment.Top
    local accept=self:_button(popup,options.ConfirmText or "Enable",UDim2.new(.5,-18,0,28))
    accept.Name="Confirm"; accept.Position=UDim2.fromOffset(12,126)
    local cancel=self:_button(popup,options.CancelText or "Cancel",UDim2.new(.5,-18,0,28))
    cancel.Name="Cancel"; cancel.Position=UDim2.new(.5,6,0,126)
    local finished=false
    local function finish(accepted)
        if finished or self.Popup~=popup then return end
        finished=true; self:ClosePopup()
        if options.Callback then options.Callback(accepted) end
    end
    self:_connect(accept.Activated,function() finish(true) end)
    self:_connect(cancel.Activated,function() finish(false) end)
    return popup
end

function Window:AddToolTip(host,options)
    if type(options)=="string" then options={Text=options} end
    local text=tostring(options and options.Text or "")
    host.Active=true
    local function show()
        if self.Dead or not host.Parent then return end
        if self.Tooltip then self.Tooltip:Destroy() end
        local width=math.min(320,math.max(220,self.Gui.AbsoluteSize.X-24))
        local popup=self:_frame(self.Overlay,"TooltipPopup",UDim2.fromOffset(width,110),"Surface")
        popup.ZIndex=110; h.corner(popup,6); self:_stroke(popup)
        local position=host.AbsolutePosition-self.Overlay.AbsolutePosition
        popup.Position=UDim2.fromOffset(math.clamp(position.X,8,math.max(8,self.Gui.AbsoluteSize.X-width-8)),math.clamp(position.Y+host.AbsoluteSize.Y+4,8,math.max(8,self.Gui.AbsoluteSize.Y-118)))
        self.Tooltip=popup
        local label=self:_text(popup,text,UDim2.new(1,-20,1,-20),true)
        label.Position=UDim2.fromOffset(10,10); label.TextWrapped=true; label.TextYAlignment=Enum.TextYAlignment.Top
    end
    self:_connect(host.MouseEnter,show)
    self:_connect(host.MouseLeave,function() if self.Tooltip then self.Tooltip:Destroy(); self.Tooltip=nil end end)
    self:_connect(host.InputBegan,function(input) if input.UserInputType==Enum.UserInputType.Touch then show() end end)
    return {Text=text,Show=show}
end
local close=Window.ClosePopup
function Window:ClosePopup()
    if self.Tooltip then self.Tooltip:Destroy(); self.Tooltip=nil end
    close(self)
end

function Window:TrackCondition(row,condition)
    self.Conditions=self.Conditions or {}
    table.insert(self.Conditions,{Row=row,Condition=condition})
    if not self.ConditionConnection then
        local elapsed=0
        self.ConditionConnection=self:_connect(ctx.RunService.Heartbeat,function(dt)
            elapsed+=dt; if elapsed<.1 then return end; elapsed=0; self:RefreshConditions()
        end)
    end
    self:RefreshConditions()
end
function Window:RefreshConditions()
    for i=#(self.Conditions or {}),1,-1 do
        local entry=self.Conditions[i]
        if not entry.Row.Parent then table.remove(self.Conditions,i)
        else local ok,visible=pcall(entry.Condition); entry.Row.Visible=ok and visible==true end
    end
end
function Control:SetVisible(visible) self.Row.Visible=visible==true end
function Control:RequestSet(value)
    if self.Disabled or self.Dead then return end
    if value==true and self.Confirm then
        local options=table.clone(self.Confirm)
        options.Callback=function(accepted) if accepted and not self.Dead and not self.Disabled then self:Set(true) end end
        self.Window:Prompt(options); self.Window.PopupOwner=self
    else self:Set(value) end
end

-- This runs for every native configurable control, not only migrated scripts.
local create=Section._control
function Section:_control(kind,options,height)
    local control=create(self,kind,options,height)
    control.Confirm=options.Confirm
    if options.Risky and not control.Confirm then control.Confirm={Title="Confirm",Text=type(options.ToolTip)=="string" and options.ToolTip or "Enable this feature?"} end
    if options.Condition then self.Window:TrackCondition(control.Row,options.Condition) end
    if options.ToolTip then control.ToolTip=self.Window:AddToolTip(control.Label,options.ToolTip) end
    return control
end

function Tab:CreateModule(options)
    options=options or {}
    local section=self:CreateSection({Name=options.Name or "Module",Id=options.Id,Column=options.Column or (#self.Sections%2+1)})
    local module={Section=section,Window=self.Window,Name=options.Name or "Module",Enabled=false,Revision=0}
    module.Switch=section:AddToggle({Name="Enabled",Id=section.Id.."/enabled",Default=false,ToolTip=options.ToolTip,Confirm=options.Confirm})
    module.Switch.Module=module
    local set=module.Switch.Set
    function module.Switch:Set(value,silent)
        value=value==true
        if module.Enabled==value then return end
        if value and options.OnEnable and options.OnEnable()==false then return end
        set(self,value,true); module.Enabled=value; module.Revision+=1
        if options.OnChange then options.OnChange(value) end
        if not silent then
            local callback=value and options.OnEnabled or options.OnDisabled
            if callback then task.spawn(callback) end
            if value and options.OnUpdate then
                local revision=module.Revision
                task.spawn(function()
                    while not module.Window.Dead and not module.Section.Dead and module.Enabled and module.Revision==revision do
                        local ok,err=pcall(options.OnUpdate)
                        if not ok then table.insert(module.Window.Errors,tostring(err)) end
                        task.wait(options.UpdateInterval or .1)
                    end
                end)
            end
        end
    end
    function module:SetEnabled(value) self.Switch:Set(value==nil and not self.Enabled or value) end
    -- Go through the module method on user interaction so adapters can install
    -- their enable veto and state-object hooks without being bypassed by the row.
    function module.Switch:RequestSet(value)
        if self.Disabled or self.Dead then return end
        if value==true and self.Confirm then
            local confirmation=table.clone(self.Confirm)
            confirmation.Callback=function(accepted) if accepted and not self.Dead and not self.Disabled then module:SetEnabled(true) end end
            self.Window:Prompt(confirmation); self.Window.PopupOwner=self
        else module:SetEnabled(value) end
    end
    function module:GetEnabled() return self.Enabled end
    function module:SetExpanded(value)
        for _,control in ipairs(self.Section.Controls) do if control~=self.Switch and control.Row then control.Row.Visible=value~=false end end
        self.Switch.Row.Visible=true
    end
    function module:Destroy() self:SetEnabled(false); self.Section:Destroy() end
    for _,name in ipairs({"AddToggle","AddSlider","AddDropdown","AddColorpicker","AddKeybind","AddTextbox","AddTextBox","AddButton","AddLabel","AddParagraph"}) do
        module[name]=function(_,info) return section[name](section,info) end
    end
    if options.Default then module:SetEnabled(true) end
    return module
end
return true
end
