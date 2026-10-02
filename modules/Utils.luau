local function rgb(r,g,b) return Color3.fromRGB(r,g,b) end
local function new(class, props, parent)
    local obj = Instance.new(class)
    for k,v in pairs(props or {}) do obj[k] = v end
    obj.Parent = parent
    return obj
end
local function corner(obj, radius) new("UICorner",{CornerRadius=UDim.new(0,radius or 5)},obj) end
local function padding(obj,p)
    new("UIPadding",{PaddingTop=UDim.new(0,p),PaddingBottom=UDim.new(0,p),PaddingLeft=UDim.new(0,p),PaddingRight=UDim.new(0,p)},obj)
end
local function list(obj, gap, direction)
    return new("UIListLayout",{Padding=UDim.new(0,gap or 4),SortOrder=Enum.SortOrder.LayoutOrder,FillDirection=direction or Enum.FillDirection.Vertical},obj)
end
local function point(input) return Vector2.new(input.Position.X,input.Position.Y) end
local function primary(input) return input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch end
local function copy(v) if type(v)=="table" then return table.clone(v) end return v end
local function contains(values, value) return table.find(values,value)~=nil end
local function encodeValue(v)
    if typeof(v)=="Color3" then return {kind="Color3",hex=v:ToHex()} end
    return copy(v)
end
local function decodeValue(v)
    if type(v)=="table" and v.kind=="Color3" and type(v.hex)=="string" then return Color3.fromHex(v.hex) end
    return v
end

return {rgb=rgb,new=new,corner=corner,padding=padding,list=list,point=point,primary=primary,copy=copy,contains=contains,encodeValue=encodeValue,decodeValue=decodeValue}
