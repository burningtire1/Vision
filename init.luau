-- Vision modular entry. Pass your raw GitHub repository URL as the chunk argument.
local base = ...
assert(type(base)=="string" and base:match("^https?://"), "Pass your raw repository base URL to the Vision loader")
if base:sub(-1)~="/" then base=base.."/" end
local cache = {}
local function load(path)
    if cache[path]~=nil then return cache[path] end
    local ok,source=pcall(function() return game:HttpGet(base..path) end)
    assert(ok,"Vision download failed: "..path.." : "..tostring(source))
    local chunk,err=loadstring(source,"Vision/"..path)
    assert(chunk,"Vision compile failed: "..path.." : "..tostring(err))
    local result=chunk()
    assert(result~=nil,"Vision module returned nil: "..path)
    cache[path]=result
    return result
end
local ctx={Load=load, Library={Version="1.3.0",Name="Vision",Distribution="modular"}}
ctx.Players=game:GetService("Players")
ctx.UIS=game:GetService("UserInputService")
ctx.TweenService=game:GetService("TweenService")
ctx.HttpService=game:GetService("HttpService")
ctx.RunService=game:GetService("RunService")
ctx.Window={}; ctx.Window.__index=ctx.Window
ctx.Tab={}; ctx.Tab.__index=ctx.Tab
ctx.Section={}; ctx.Section.__index=ctx.Section
ctx.Control={}; ctx.Control.__index=ctx.Control
ctx.Helpers=load("modules/Utils.luau")
ctx.Library.Themes=load("modules/Themes.luau")
ctx.Assets=load("modules/AssetLoader.luau")(ctx)
for _,name in ipairs({"Window","Tabs","Sections","Controls","Keybinds","Colorpicker","Text","Search","Notifications","Config","Modules","Dynamic"}) do
    local attach=load("modules/"..name..".luau")
    assert(type(attach)=="function","Vision module must return an installer: "..name)
    attach(ctx)
end
return ctx.Library
