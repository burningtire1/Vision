return function(env,ctx,files)
local Safety=ctx.Load("modules/ConfigSafety.luau")
local passed=0
local function check(name,fn) fn();passed+=1;print("PASS "..name) end
local lib=ctx.Library.CreateDynamic({ConfigFolder="VisionConfigRegression"})
local w=lib:CreateWindow({Animations=false})
local m=w:AddTab({Name="Audit"}):AddModule({Name="Audit",Flag="Audit"})
local toggle=m:AddToggle({Text="Toggle",Flag="toggle",Default=false})
local slider=m:AddSlider({Text="Speed",Flag="speed",Min=0,Max=100,Default=10})
local config=lib.ConfigSystem
local ok,err=pcall(function()
check("malformed JSON rejected",function()
 for _,raw in ipairs({'{broken','{"a":1,}','{"a":1,"a":2}','[1,]','01','1e999','{"a":true} false','"\\uD800"'}) do assert(not pcall(Safety.DecodeJson,raw),raw) end
 assert(Safety.DecodeJson('{"a":false}').a==false)
 assert(not pcall(Safety.DecodeJson,string.rep('[',66)..'0'..string.rep(']',66)))
 assert(not pcall(Safety.DecodeJson,string.rep(' ',Safety.MaxBytes+1)))
end)
check("invalid profile leaves controls flags and module unchanged",function()
 assert(not pcall(function() config:Apply({Audit={Enabled=true,Toggles={toggle="invalid"}}}) end))
 assert(not m.Enabled and toggle:Get()==false and lib.Flags.toggle==false)
 assert(not pcall(function() config:Apply({Audit={Enabled=true,Sliders={speed=0/0}}}) end))
 assert(slider:Get()==10 and not m.Enabled)
 assert(not pcall(function() config:Decode('{"Version":99,"Config":{}}') end))
end)
check("invalid style preflight prevents flag changes",function()
 assert(not pcall(function() config:Apply({Audit={Enabled=true,Toggles={toggle=true}},__VisionStyle={version=1,values={},layout="invalid"}}) end))
 assert(not m.Enabled and not toggle:Get())
end)
check("render failure restores staged controls",function()
 local render=slider._render;local once=true
 slider._render=function(self) if once then once=false;error("Injected render failure") end;return render(self) end
 assert(not pcall(function() config:Apply({Audit={Enabled=true,Toggles={toggle=true},Sliders={speed=25}}}) end))
 slider._render=render
 assert(not toggle:Get() and slider:Get()==10 and not m.Enabled and lib.Flags.toggle==false)
end)
check("settings commit before module activation",function()
 local enable=m.SetEnabled
 m.SetEnabled=function(self,value) if value then assert(toggle:Get()==true and slider:Get()==25 and lib.Flags.toggle==true) end;return enable(self,value) end
 config:Apply({Audit={Enabled=true,Toggles={toggle=true},Sliders={speed=25}}})
 assert(m.Enabled);m.SetEnabled=enable;m:SetEnabled(false)
end)
check("verified backup recovers corrupted primary",function()
 toggle:Set(false);config:Save("Good")
 toggle:Set(true);config:Save("Good")
 local path=config:GetPath("Good");files[path]='{broken'
 assert(config:Load("Good") and config.RecoveredFromBackup and toggle:Get()==false)
 for _,name in ipairs(config:List()) do assert(not name:match("%.backup$")) end
end)
check("failed write readback restores previous bytes",function()
 config:Save("Writes");local path=config:GetPath("Writes");local original=files[path]
 toggle:Set(true)
 local once=true
 local disk={IsFile=function(_,p) return files[p]~=nil end,ReadFile=function(_,p) return files[p] end,WriteFile=function(_,p,value) if p==path and once then once=false;files[p]='partial' else files[p]=value end end}
 local nextJson=ctx.HttpService:JSONEncode({Version=2,Config=config:Build()})
 assert(not pcall(function() Safety.WriteVerified(disk,path,path..".backup",nextJson,function(raw) config:Decode(raw) end) end))
 assert(files[path]==original)
end)
check("explicit readiness and failed startup pause autosave",function()
 local other=ctx.Library.CreateDynamic({ConfigFolder="VisionStartupRegression"})
 local otherWindow=other:CreateWindow({Animations=false})
 local otherConfig=other.ConfigSystem
 assert(otherConfig.AutoSaveReady==false and not files[otherConfig:GetPath("Autosave")])
 files[otherConfig:GetPath("Autosave")]='{broken'
 assert(other:InitializeConfig()==false and otherConfig.AutoSaveEnabled==false and files[otherConfig:GetPath("Autosave")]=='{broken')
 other:Destroy()
end)
check("native import rollback and callbacks",function()
 local native=ctx.Library.new({Id="NativeRegression",Animations=false})
 local count=0
 local control=native:CreateTab({Name="Test"}):CreateSection({Name="Settings"}):AddToggle({Id="nativeToggle",Name="Toggle",Default=false,Callback=function() count+=1 end})
 local data=ctx.HttpService:JSONDecode(native:ExportConfig());data.values.nativeToggle.value=true
 native:ImportConfig(ctx.HttpService:JSONEncode(data),false)
 assert(control:Get()==true and count==1)
 local activated=0
 local module=native.Tabs[1]:CreateModule({Name="Module",Id="nativeModule",OnEnabled=function() assert(control:Get()==true);activated+=1 end})
 data=ctx.HttpService:JSONDecode(native:ExportConfig());data.values[module.Switch.Id].value=true
 native:ImportConfig(ctx.HttpService:JSONEncode(data),false)
 env.task.wait(.02);assert(module.Enabled and activated==1)
 native:Destroy()
end)
check("reserved profile names rejected",function()
 for _,name in ipairs({'CON','LPT1','../oops','bad.','bad ','Good.backup'}) do assert(not pcall(function() config:GetPath(name) end)) end
 assert(config:GetPath("Legacy profile"))
end)
end)
lib:Destroy()
assert(ok,err)
print("Config regression checks passed "..passed)
end
