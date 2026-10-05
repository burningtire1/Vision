local fs=require("@lune/fs")
local luau=require("@lune/luau")
local roblox=require("@lune/roblox")
local serde=require("@lune/serde")
local task=require("@lune/task")
local process=require("@lune/process")
local root=process.args[1] or "."
local Vector2,UDim2=roblox.Vector2,roblox.UDim2
local function signal()
    local handlers={}; local s={}
    function s:Connect(fn)
        local c={Connected=true}
        function c:Disconnect() self.Connected=false end
        table.insert(handlers,{c,fn}); return c
    end
    function s:Fire(...)
        for _,entry in ipairs(table.clone(handlers)) do if entry[1].Connected then entry[2](...) end end
    end
    return s
end
local function instance(class)
    local p={ClassName=class,Name=class,Visible=true,Position=UDim2.new(),Size=UDim2.new(),AbsolutePosition=Vector2.new(10,10),AbsoluteSize=Vector2.new(800,600),CanvasPosition=Vector2.zero,BackgroundTransparency=0,Text="",ZIndex=1}
    local children,signals,attrs={},{},{}
    local o={}
    function o:IsA(name) return name==class or name=="GuiObject" and class~="ScreenGui" end
    function o:GetChildren() return table.clone(children) end
    function o:FindFirstChild(name) for _,child in ipairs(children) do if child.Name==name then return child end end end
    function o:FindFirstChildOfClass(name) for _,child in ipairs(children) do if child.ClassName==name then return child end end end
    function o:WaitForChild(name) return self:FindFirstChild(name) end
    function o:GetPropertyChangedSignal(name) local key="property/"..name; if not signals[key] then signals[key]=signal() end; return signals[key] end
    function o:SetAttribute(name,value) attrs[name]=value end
    function o:GetAttribute(name) return attrs[name] end
    function o:IsFocused() return false end
    function o:IsDescendantOf(parent) local current=p.Parent; while current do if current==parent then return true end; current=current.Parent end; return false end
    function o:Destroy()
        if p.Destroyed then return end
        p.Destroyed=true
        if signals.Destroying then signals.Destroying:Fire() end
        for _,child in ipairs(table.clone(children)) do child:Destroy() end
        self.Parent=nil
        for _,s in pairs(signals) do -- Connections owned by destroyed Instances disconnect.
            if s.Destroy then s:Destroy() end
        end
    end
    function o:_add(child) table.insert(children,child) end
    function o:_remove(child) local at=table.find(children,child); if at then table.remove(children,at) end end
    return setmetatable(o,{
        __index=function(_,key)
            if p[key]~=nil then return p[key] end
            if key:match("Changed$") or key=="Activated" or key=="InputBegan" or key=="InputEnded" or key=="InputChanged" or key=="Destroying" or key=="MouseEnter" or key=="MouseLeave" or key=="FocusLost" then
                if not signals[key] then signals[key]=signal() end; return signals[key]
            end
            return o:FindFirstChild(key)
        end,
        __newindex=function(_,key,value)
            if key=="Parent" then if p.Parent then p.Parent:_remove(o) end; if value then value:_add(o) end end
            p[key]=value
        end,
    })
end
local env={}
env.game={GameId=12345}
local gui=instance("PlayerGui")
local localPlayer=instance("Player"); localPlayer.DisplayName="Fixture"; gui.Parent=localPlayer
local services={Players={LocalPlayer=localPlayer},RunService={Heartbeat=signal(),RenderStepped=signal()},HttpService={}}
services.HttpService.JSONEncode=function(_,value) return serde.encode("json",value) end
services.HttpService.JSONDecode=function(_,value) return serde.decode("json",value) end
services.TweenService={Create=function(_,object,_,properties)
    local tween={Completed=signal()}
    function tween:Play() for key,value in pairs(properties) do object[key]=value end; self.Completed:Fire() end
    function tween:Cancel() end
    return tween
end}
services.UserInputService={KeyboardEnabled=true,TouchEnabled=false,InputBegan=signal(),InputChanged=signal(),InputEnded=signal(),WindowFocusReleased=signal(),TextBoxFocused=signal(),GetFocusedTextBox=function() return nil end,IsKeyDown=function() return false end}
function env.game:GetService(name) assert(services[name],"Unexpected service "..name); return services[name] end
local files,folders={},{}
env.readfile=function(path) return files[path] end
env.writefile=function(path,data) files[path]=data end
env.isfile=function(path) return files[path]~=nil end
env.isfolder=function(path) return folders[path]==true end
env.makefolder=function(path) folders[path]=true end
env.listfiles=function(path) local out={}; for key in pairs(files) do if key:sub(1,#path+1)==path.."/" then table.insert(out,key) end end; return out end
env.delfile=function(path) files[path]=nil end
env.Instance={new=instance}
for _,name in ipairs({"Vector2","UDim2","UDim","Color3","Enum"}) do env[name]=roblox[name] end
env.TweenInfo={new=function() return {} end}
env.getgenv=function() return env end
env.task=task; env.warn=function(...) print("WARN",...) end
env._G=env; env.gethui=function() return gui end
env.LPH_ATTRIBUTES=function() end; env.VM=function() end; env.OPAL=false; env.PRESET=function() end; env.FAST=false
setmetatable(env,{__index=getfenv()})
env.loadstring=function(source,name) return luau.load(source,{environment=env,injectGlobals=true,debugName=name or "fixture"}) end
local sources={}
local function load(path) return env.loadstring(fs.readFile(root.."/"..path),path)() end
local ctx={Load=load,Library={Version="fixture",Name="Vision"},Players=services.Players,UIS=services.UserInputService,TweenService=services.TweenService,HttpService=services.HttpService,RunService=services.RunService}
ctx.Window={}; ctx.Window.__index=ctx.Window; ctx.Tab={}; ctx.Tab.__index=ctx.Tab; ctx.Section={}; ctx.Section.__index=ctx.Section; ctx.Control={}; ctx.Control.__index=ctx.Control
ctx.Helpers=load("modules/Utils.luau");ctx.Library.Themes=load("modules/Themes.luau");ctx.Assets=load("modules/AssetLoader.luau")(ctx)
for _,name in ipairs({"Window","Tabs","Sections","Controls","Keybinds","Colorpicker","Text","Search","Notifications","Config","Modules","Dynamic"}) do load("modules/"..name..".luau")(ctx) end
local adapters={}
local run=env.loadstring(fs.readFile(root.."/tests/dynamic-cases.luau"))
run(env,ctx.Library,adapters)
local results=env.__VisionPortTest
for _,failure in ipairs(results.Failures) do print("FAIL "..failure) end
print("UI fixture checks passed "..results.Passed.." failed "..#results.Failures)
assert(#results.Failures==0,"UI fixture failed")
