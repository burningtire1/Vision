-- Replace OWNER and REPO. Use a public repository for this no-token loader.
local BASE = "https://raw.githubusercontent.com/OWNER/REPO/main/"
local Vision = loadstring(game:HttpGet(BASE.."init.luau"))(BASE)
local window = Vision.new({Title="Vision"})
local tab = window:CreateTab({Name="Movement", Icon="wind"})
local section = tab:CreateSection({Name="Settings", Column=1})
section:AddToggle({Name="Enabled", Id="enabled", Default=true})
section:AddTextbox({Name="Profile", Id="profile", Placeholder="Type here"})
section:AddParagraph({Title="Welcome", Text="Your Vision UI is ready."})
