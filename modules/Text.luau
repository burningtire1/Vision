-- Edit text behavior here. Loaded by init.luau.
return function(ctx)
local Library, Window, Tab, Section, Control = ctx.Library, ctx.Window, ctx.Tab, ctx.Section, ctx.Control
local Players, UIS, TweenService, HttpService, RunService = ctx.Players, ctx.UIS, ctx.TweenService, ctx.HttpService, ctx.RunService
local h = ctx.Helpers
local rgb, new, corner, padding, list, point, primary, copy, contains, encodeValue, decodeValue = h.rgb, h.new, h.corner, h.padding, h.list, h.point, h.primary, h.copy, h.contains, h.encodeValue, h.decodeValue
function Section:AddLabel(text)
    local label=self.Window:_text(self.Content,text,UDim2.new(1,0,0,24),true); label.LayoutOrder=#self.Controls+1; table.insert(self.Controls,{Kind="Label",Row=label}); return label
end

function Section:AddTextbox(options)
    options=options or {}; local c=self:_control("Textbox",options,68); local w=self.Window
    c.MaxLength=options.MaxLength or 256; assert(c.MaxLength>=1,"MaxLength must be positive")
    c.Input=w:_input(c.Row,"",UDim2.new(1,0,0,36)); c.Input.Name="TextInput"; c.Input.Position=UDim2.fromOffset(0,26); c.Input.PlaceholderText=options.Placeholder or "Type here..."; c.Input.MultiLine=options.MultiLine==true
    c.Input.TextEditable=not c.Disabled
    w:_connect(c.Input.FocusLost,function() if not c.Disabled then c:Set(c.Input.Text) end end)
    if options.Live then w:_connect(c.Input:GetPropertyChangedSignal("Text"),function() if not c.Disabled and c.Input:IsFocused() then c:Set(c.Input.Text) end end) end
    c:Set(options.Default or "",true); return c
end
Section.AddTextBox=Section.AddTextbox

function Section:AddParagraph(options)
    if type(options)=="string" then options={Text=options} end
    options=options or {}; local w=self.Window
    local row=w:_frame(self.Content,"Paragraph",UDim2.new(1,0,0,0),"Raised"); row.AutomaticSize=Enum.AutomaticSize.Y; row.LayoutOrder=#self.Controls+1; corner(row); padding(row,9); list(row,5)
    local title=w:_text(row,options.Title or "",UDim2.new(1,0,0,20)); title.Font=Enum.Font.BuilderSansMedium; title.TextWrapped=true; title.Visible=options.Title~=nil
    local body=w:_text(row,options.Text or options.Content or "",UDim2.new(1,0,0,0),true); body.AutomaticSize=Enum.AutomaticSize.Y; body.TextWrapped=true; body.TextYAlignment=Enum.TextYAlignment.Top; body.LayoutOrder=1
    local paragraph={Kind="Paragraph",Row=row,Title=title,Body=body}
    function paragraph:Set(heading,text) self.Title.Text=heading or ""; self.Title.Visible=heading~=nil and heading~=""; self.Body.Text=text or "" end
    table.insert(self.Controls,paragraph); return paragraph
end

return true
end
