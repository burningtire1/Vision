return function(ctx)
    local api = {}
    function api.Register(self)
        local IconBytes = ctx.Load("assets/Icons.luau")
    self.AssetStatus="fallback"
    if type(writefile)=="function" and type(makefolder)=="function" and type(getcustomasset)=="function" then
        local ok=pcall(function()
            if not isfolder("LapseUI") then makefolder("LapseUI") end
            if not isfolder("LapseUI/assets") then makefolder("LapseUI/assets") end
            for name,bytes in pairs(IconBytes) do
                local path="LapseUI/assets/"..name..".png"
                if not isfile(path) then writefile(path,bytes) end
                self.Icons[name]=getcustomasset(path)
            end
        end)
        if ok and next(self.Icons) then self.AssetStatus="lucide" end
    end

    end
    return api
end
