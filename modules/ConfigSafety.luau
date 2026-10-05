-- Shared strict codec, bounded values and verified persistence for both formats.
local Safety={MaxBytes=2*1024*1024,MaxDepth=64,MaxNodes=50000,Null={}}
function Safety.Copy(value,seen)
    if type(value)~="table" or value==Safety.Null then return value end
    seen=seen or {}; assert(not seen[value],"Cyclic config")
    seen[value]=true; local result={}
    for key,item in pairs(value) do result[key]=Safety.Copy(item,seen) end
    seen[value]=nil; return result
end
function Safety.Finite(value) return type(value)=="number" and value==value and math.abs(value)<math.huge end
function Safety.Map(value,message) assert(type(value)=="table" and value~=Safety.Null,message or "Expected config object") end
function Safety.Array(value)
    Safety.Map(value,"Expected array"); local count=0
    for key in pairs(value) do assert(type(key)=="number" and key>=1 and key%1==0,"Invalid array key"); count+=1 end
    assert(count==#value,"Sparse config array")
end
function Safety.DecodeJson(text)
    assert(type(text)=="string" and #text>0 and #text<=Safety.MaxBytes,"Invalid config size")
    local at,n,nodes=1,#text,0
    local function whitespace() while at<=n and text:sub(at,at):match("[ \t\r\n]") do at+=1 end end
    local function stringValue()
        assert(text:sub(at,at)=='"',"Expected JSON string"); at+=1
        local out={};local start=at
        while at<=n do
            local byte=text:byte(at)
            if byte==34 then
                table.insert(out,text:sub(start,at-1));at+=1
                local result=table.concat(out);assert(utf8.len(result),"Invalid UTF-8");return result
            elseif byte==92 then
                table.insert(out,text:sub(start,at-1));at+=1
                local char=text:sub(at,at);local escaped=({['"']='"',['\\']='\\',['/']='/',b='\b',f='\f',n='\n',r='\r',t='\t'})[char]
                if escaped then table.insert(out,escaped);at+=1
                else
                    assert(char=='u',"Invalid JSON escape")
                    local hex=text:sub(at+1,at+4);assert(#hex==4 and hex:match("^%x%x%x%x$"),"Invalid Unicode escape")
                    local code=tonumber(hex,16);at+=5
                    if code>=0xD800 and code<=0xDBFF then
                        assert(text:sub(at,at+1)=='\\u',"Missing low surrogate")
                        local lowHex=text:sub(at+2,at+5);assert(lowHex:match("^%x%x%x%x$"),"Invalid low surrogate")
                        local low=tonumber(lowHex,16);assert(low>=0xDC00 and low<=0xDFFF,"Invalid low surrogate")
                        code=0x10000+(code-0xD800)*0x400+low-0xDC00;at+=6
                    else assert(code<0xDC00 or code>0xDFFF,"Unexpected low surrogate") end
                    table.insert(out,utf8.char(code))
                end
                start=at
            else assert(byte>=32,"Unescaped control character");at+=1 end
        end
        error("Unterminated JSON string")
    end
    local parse
    parse=function(depth)
        assert(depth<=Safety.MaxDepth,"Config nesting limit exceeded");nodes+=1;assert(nodes<=Safety.MaxNodes,"Config node limit exceeded")
        whitespace();local char=text:sub(at,at)
        if char=='"' then return stringValue() end
        if char=='{' or char=='[' then
            local object=char=='{';local closing=object and '}' or ']';local result,seen={},{}
            at+=1;whitespace();if text:sub(at,at)==closing then at+=1;return result end
            while true do
                local key
                if object then key=stringValue();assert(not seen[key],"Duplicate JSON key");seen[key]=true;whitespace();assert(text:sub(at,at)==':',"Missing JSON colon");at+=1 else key=#result+1 end
                result[key]=parse(depth+1);whitespace();char=text:sub(at,at)
                if char==closing then at+=1;return result end
                assert(char==',',"Missing JSON separator");at+=1;whitespace();assert(text:sub(at,at)~=closing,"Trailing JSON comma")
            end
        end
        for literal,value in pairs({["true"]=true,["false"]=false,["null"]=Safety.Null}) do
            if text:sub(at,at+#literal-1)==literal then at+=#literal;return value end
        end
        local start=at
        if char=='-' then at+=1 end
        char=text:sub(at,at)
        if char=='0' then at+=1
        else assert(char:match("^[1-9]$"),"Invalid JSON value");repeat at+=1 until not text:sub(at,at):match("^%d$") end
        if text:sub(at,at)=='.' then at+=1;assert(text:sub(at,at):match("^%d$"),"Invalid fraction");repeat at+=1 until not text:sub(at,at):match("^%d$") end
        char=text:sub(at,at)
        if char=='e' or char=='E' then
            at+=1;char=text:sub(at,at);if char=='+' or char=='-' then at+=1 end
            assert(text:sub(at,at):match("^%d$"),"Invalid exponent");repeat at+=1 until not text:sub(at,at):match("^%d$")
        end
        local value=tonumber(text:sub(start,at-1));assert(Safety.Finite(value),"Invalid finite number");return value
    end
    local result=parse(0);whitespace();assert(at>n,"Trailing JSON data");return result
end
function Safety.ProfileName(name)
    assert(type(name)=="string" and utf8.len(name) and utf8.len(name)>0 and utf8.len(name)<=64,"Invalid config name")
    assert(not name:find('[<>:"/\\|?*%c]') and name:sub(-1)~='.' and name:sub(-1)~=' ' and name~='.' and name~='..',"Invalid config name")
    local stem=(name:match("^([^%.]+)") or name):upper()
    assert(not ({CON=true,PRN=true,AUX=true,NUL=true})[stem] and not stem:match("^COM%d$") and not stem:match("^LPT%d$"),"Reserved config name")
    assert(not name:lower():match("%.backup$") and not name:lower():match("%.tmp$"),"Reserved config suffix")
    return name
end
function Safety.Folder(folder)
    assert(type(folder)=="string" and #folder>0 and folder:sub(1,1)~='/' and folder:sub(-1)~='/' and not folder:find('\\',1,true) and not folder:find(':',1,true) and not folder:find('//',1,true),"Invalid config folder")
    for part in folder:gmatch('[^/]+') do assert(part~='.' and part~='..' and not part:find('%c'),"Invalid config folder") end
    return folder
end
function Safety.ControlValue(control,value,alpha)
    local kind=control.Kind
    if kind=="Toggle" then assert(type(value)=="boolean","Invalid toggle")
    elseif kind=="Slider" then assert(Safety.Finite(value),"Invalid slider");value=math.clamp(control.Min+math.round((value-control.Min)/control.Step)*control.Step,control.Min,control.Max)
    elseif kind=="Dropdown" then
        if control.Multi then
            Safety.Array(value);local selected={};for _,item in ipairs(value) do assert(type(item)=="string" and table.find(control.Options,item),"Invalid dropdown option");if not table.find(selected,item) then table.insert(selected,item) end end;value=selected
        else if control.Aliases and control.Aliases[value] then value=control.Aliases[value] end;assert(type(value)=="string" and table.find(control.Options,value),"Invalid dropdown option") end
    elseif kind=="Textbox" then assert(type(value)=="string" and utf8.len(value) and utf8.len(value)<=control.MaxLength,"Invalid textbox")
    elseif kind=="Keybind" then assert(type(value)=="string" and (value=="None" or Enum.KeyCode[value]),"Invalid keybind")
    elseif kind=="Colorpicker" then assert(typeof(value)=="Color3","Invalid color")
    else error("Unsupported config control") end
    assert(alpha==nil or kind=="Colorpicker" and Safety.Finite(alpha) and alpha>=0 and alpha<=1,"Invalid alpha")
    return Safety.Copy(value)
end
-- No atomic rename is assumed. Readback and a verified last-good backup protect
-- normal write failures; an executor crash cannot be made fully atomic here.
function Safety.WriteVerified(files,path,backup,json,validate)
    assert(type(json)=="string" and #json<=Safety.MaxBytes,"Config too large");validate(json)
    local old
    if files:IsFile(path) then old=files:ReadFile(path) end
    if old==json then return false end
    local validOld=old~=nil and pcall(validate,old)
    if validOld then files:WriteFile(backup,old);assert(files:ReadFile(backup)==old,"Backup verification failed") end
    local ok,err=pcall(function() files:WriteFile(path,json);assert(files:ReadFile(path)==json,"Config write verification failed") end)
    if not ok then
        local restored=not validOld or pcall(function() files:WriteFile(path,old);assert(files:ReadFile(path)==old,"Restore verification failed") end)
        error(tostring(err)..(restored and "" or "; restore failed, use backup"),0)
    end
    return true
end
return Safety
