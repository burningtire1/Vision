# Vision: quick API guide

Start with the loading example in README.md. Then add controls to a section.
Give each control a unique `Id` so configs can find it later.

## Window, tabs and sections

```lua
local window = Library.new({Title="Vision", Size=Vector2.new(650,452)})
local tab = window:CreateTab({Name="Movement", Icon="wind"})
local section = tab:CreateSection({Name="Settings", Column=1})
```

Column 1 is left. Column 2 is right. Compact mode puts both into one column.
Use `tab:Select()` to open a tab.
Drag a section header out to detach it. Drop it into the window to dock it.
You can also use `section:Detach(Vector2.new(790,242))` and `section:Dock()`.

## Toggles and sliders

```lua
local toggle = section:AddToggle({Name="Enabled", Id="enabled", Default=true})
section:AddToggle({Name="Checkbox", Id="check", Style="Checkbox"})
section:AddSlider({Name="Amount", Id="amount", Min=0, Max=100,
    Step=1, Default=25, Suffix="%"})
```

## Dropdowns

```lua
section:AddDropdown({Name="Mode", Id="mode",
    Options={"One","Two","Three"}, Default="Two"})
section:AddDropdown({Name="Checks", Id="checks", Multi=true,
    Options={"Alive","Visible","Team"}, Default={"Alive","Visible"}})
```

`Multi=true` lets users choose more than one option.
`dropdown:SetOptions({"A","B"}, "A")` changes the available options.

## Text boxes and paragraphs

```lua
local input = section:AddTextbox({Name="Name", Id="name",
    Default="My profile", Placeholder="Type here", MaxLength=64,
    Callback=function(text) print(text) end})

section:AddTextbox({Name="Notes", Id="notes", MultiLine=true, MaxLength=1000})

local paragraph = section:AddParagraph({Title="Information",
    Text="This is readable text, not an input. It wraps automatically."})
paragraph:Set("New title", "New text")
```

Text box callbacks run when typing finishes and focus leaves the field.
Add `Live=true` to run the callback while typing. `AddTextBox` is an alias.
Text boxes save in configs. Paragraphs do not.

## Buttons

```lua
section:AddButton({Name="Apply", Primary=true, Callback=function() end})
section:AddButtons({{Name="One"}, {Name="Two"}, {Name="Three"}})
section:AddLabel("A short line of text")
```

## Keybinds

```lua
toggle:Bind({Default="B"})
section:AddKeybind({Name="Hold action", Id="hold", Default="V", Mode="Hold",
    Callback=function(active) print(active) end})
```

Click the key field, then press a key. Key names are strings like "B" or "LeftShift".
Use "None" for no binding. Hold mode turns on while the key is held.
Default mode toggles on each press. Keybinds need a keyboard.
Bindings show in the draggable keybind HUD.

## Color pickers

```lua
local picker = section:AddColorpicker({Name="Tint", Id="tint",
    Default=Color3.fromRGB(86,127,214), Alpha=1,
    Callback=function(color, control) print(color, control.Alpha) end})
picker:SetAlpha(0.5)
```

RGB accepts three numbers from 0 to 255, separated by commas.
HEX accepts six digits, such as #567FD6.
Use `Swatches={Color3.new(1,0,0), Color3.new(0,1,0)}` for custom palette buttons.
Recent colors are shared across pickers. Reopen the picker to refresh the list.

## Read or change a control

```lua
control:Get()
control:Set(value)
control:Set(value, true) -- do not run its callback
control:SetDisabled(true)
control:Focus()
```

Most controls accept `Callback=function(value, control) ... end`.
Starting values do not run callbacks. Disabled controls ignore user input.

## Themes, mobile and notifications

```lua
window:SetTheme("Vision") -- also Midnight or Rose
window:SetTheme({Accent=Color3.fromRGB(145,120,255)})
window:SetLayout("Auto") -- also Desktop, Compact or Mobile
window:Notify({Title="Vision", Text="Saved", Duration=4})
window:OpenSearch()
window:Destroy()
```

Auto chooses compact layout for small windows. Mobile is another name for Compact.
On touch devices, Roblox handles text field focus and the on-screen keyboard.
Physical phone keyboard behavior has not been tested.

## Save and load

```lua
window:SaveConfig("Default")
window:LoadConfig("Default", false)
local json = window:ExportConfig()
window:ImportConfig(json, false)
```

Save and load use executor file APIs. JSON export/import does not need file APIs.
The final `false` runs callbacks while loading. Leave it out to load silently.
Use simple config names. The legacy folder is `LapseUI/configs`.

## Icons and optional setup

Use an icon's filename without .svg, such as wind, swords, eye, settings or file-text.
All 49 names are in `assets/manifest.json`.

Window options also include Position, Parent, Id, Footer, ConfigFolder and ToggleKey.
For Studio, require the library as a ModuleScript from a LocalScript and use PlayerGui.
Without executor asset APIs, icons fall back to text symbols.


## Sub tabs
Dragged out sections are called sub tabs. Right Shift hides or shows the main window and its sub tabs with a short animation. Their positions stay saved. Use `window:SetVisible(false)` to hide or `window:SetVisible(true)` to show. Existing `section:Detach()` and `section:Dock()` calls still work.
