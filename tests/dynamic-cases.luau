-- UI only. No job, combat, movement, network remote or staff callbacks run.
local env,Vision,adapters = ...
local results={Passed=0,Failures={},Scripts={},Events={}}
env.__VisionPortTest=results
local function check(name,fn)
    local ok,err=pcall(fn)
    if ok then results.Passed+=1 else table.insert(results.Failures,name..": "..tostring(err)) end
end
local function eq(actual,expected) assert(actual==expected,tostring(actual).." ~= "..tostring(expected)) end
for _,product in ipairs({"Automine","AutoChop","AutoBarkeep","AutoDoctor"}) do
    local lib=Vision.CreateDynamic({ConfigFolder="VisionPortTest/"..product,Title=product.." Vision test"})
    local window=lib:CreateWindow({Animations=false})
    local module,compat
    if adapters[product] then
        compat=adapters[product](lib,{RunService=game:GetService("RunService")})
        compat.AttachWindow(window)
        window:AddCategory({Name="Farm"})
        module=window:AddModule({Name="Test",Category="Farm"})
        compat.Init()
    else module=window:AddTab({Name=product}):AddModule({Name="Test",Flag="Test"}) end
    local native=module.Rise or module
    local toggle,slider,multi,text,key,color
    check(product.." controls",function()
        toggle=module:AddToggle({Text="Toggle",Flag="test.toggle",Default=true,ToolTip="Toggle info",Condition=function() return lib.Flags["test.show"]~=false end})
        slider=module:AddSlider({Text="Delay",Flag="test.slider",Min=0,Max=10,Step=.5,Default=1,Suffix="s"})
        multi=module:AddDropdown({Text="Modes",Flag="test.multi",Options={"A","B"},Choices={"A","B"},Multiple=true,Default={"A"}})
        local method=module.AddKeybox or module.AddTextBox
        text=method(module,{Text="Name",Flag="test.text",Default="hello"})
        key=native:AddKeybind({Text="Key",Flag="test.key",Default=Enum.KeyCode.B,OnPress=function(value) table.insert(results.Events,value) end})
        local picker=module.AddColorpicker or module.AddColorPicker
        color=picker(module,{Text="Tint",Flag="test.color",Default=Color3.fromRGB(30,80,120)})
    end)
    check(product.." module identity and toggle",function()
        if compat then
            local identity=lib.Flags.Test; eq(identity,module)
            module.OnEnable=function() return false end
            native.Switch:RequestSet(true); eq(identity.Value,false)
            module.OnEnable=nil
            native.Switch:RequestSet(true); eq(identity.Value,true)
            native.Switch:RequestSet(false); eq(identity.Value,false)
            module:SetState(true); eq(identity.Value,true); eq(lib.Flags.Test,identity)
            module:SetState(false); eq(identity.Value,false); eq(lib.Flags.Test,identity)
        else module:SetEnabled(true); eq(lib.Flags.Test,true); module:SetEnabled(false); eq(lib.Flags.Test,false) end
    end)
    check(product.." control flags",function()
        toggle:Set(false); eq(lib.Flags["test.toggle"],false)
        slider:SetValue(2.5); eq(lib.Flags["test.slider"],2.5)
        text:SetValue("changed")
        if compat then eq(lib.Flags["test.text"].Value,"changed") else eq(lib.Flags["test.text"],"changed") end
        local dropdown=native.Dropdowns["test.multi"]
        dropdown:SetSelected({"A","B"}); eq(#dropdown:GetSelected(),2)
        if compat then eq(lib.Flags["test.multi_A"],true); eq(lib.Flags["test.multi_B"],true) end
        dropdown:Clear(); eq(#dropdown:GetSelected(),0)
        dropdown:SetOptions({}); eq(#dropdown:GetSelected(),0)
        dropdown:SetOptions({"B","C"}); dropdown:SelectAll(); eq(#dropdown:GetSelected(),2)
    end)
    check(product.." conditions",function()
        lib.Flags["test.show"]=false; window:RefreshConditions(); eq(toggle.Row.Visible,false)
        lib.Flags["test.show"]=true; window:RefreshConditions(); eq(toggle.Row.Visible,true)
    end)
    check(product.." key pulse and rebinding",function()
        key:_callback(true); key:_callback(false)
        eq(results.Events[#results.Events],true)
        key:SetKey(Enum.KeyCode.N); eq(key:GetKey(),Enum.KeyCode.N)
    end)
    check(product.." profiles and share codes",function()
        local config=lib.ConfigSystem
        config:SetAutoSave(false); toggle:Set(true); slider:SetValue(3.5)
        config:Save("Fixture"); local code=config:Export("Fixture")
        toggle:Set(false); slider:SetValue(8); window:SetTheme("Rose"); window:SetLayout("Compact")
        assert(config:Load("Fixture")); eq(toggle:Get(),true); eq(slider:GetValue(),3.5); eq(window.ThemeName,"Vision"); eq(window.Layout,"Auto")
        toggle:Set(false); assert(config:Import(code)); eq(toggle:Get(),true)
        assert(not pcall(function() config:Save("../escape") end),"Unsafe profile name accepted")
        eq(config.BasePath,"VisionPortTest/"..product.."/Configs/"..tostring(game.GameId))
    end)
    check(product.." detach and compact",function()
        native.Section:Detach(Vector2.new(30,40)); eq(native.Section.Detached,true)
        window:SetVisible(false); window:SetVisible(true)
        native.Section:Dock(); eq(native.Section.Detached,false)
        window:SetLayout("Compact"); eq(window.Compact,true)
        window:SetTheme("Rose"); eq(window.ThemeName,"Rose")
    end)
    check(product.." lifecycle",function()
        lib:Destroy(); eq(window.Dead,true); eq(lib.Destroyed,true)
        if compat then eq(compat.RenderLoop.Connected,false); eq(compat.HeartbeatLoop.Connected,false) end
        lib:Destroy()
    end)
    table.insert(results.Scripts,product)
end
check("Native modules callbacks and confirmation",function()
    local w=Vision.new({Id="VisionPortTestNative",Title="Vision",Animations=false})
    local tab=w:CreateTab({Name="Native"})
    local enabled,disabled=0,0
    local module=tab:CreateModule({Name="Module",Id="module",OnEnabled=function() enabled+=1 end,OnDisabled=function() disabled+=1 end})
    module:SetEnabled(true); task.wait(); eq(module.Enabled,true); eq(enabled,1)
    module:SetEnabled(false); task.wait(); eq(disabled,1)
    local risky=module:AddToggle({Name="Risky",Id="risky",Confirm={Text="Enable?"}})
    risky:RequestSet(true); eq(risky:Get(),false); eq(w.Popup.Name,"ConfirmPopup")
    w:ClosePopup(); eq(risky:Get(),false)
    risky:RequestSet(true)
    if w.Popup.Confirm.Activated.Fire then w.Popup.Confirm.Activated:Fire(); eq(risky:Get(),true) end
    risky:Set(true); eq(risky:Get(),true)
    local tooltip=module:AddToggle({Name="Tooltip",Id="tooltip",ToolTip="Info"})
    tooltip.ToolTip.Show(); eq(w.Shield.Visible,false); eq(w.Tooltip.Name,"TooltipPopup")
    w:ClosePopup(); eq(w.Tooltip,nil)
    module:Destroy(); w:Destroy()
end)
task.wait(.1)
results.Done=true
