# Vision UI

A modular Roblox UI library. Each part is a separate editable Luau file.

## Upload to GitHub

1. Unzip this package.
2. Upload its contents to the root of your repository. Keep the folders unchanged.
3. Make the repository public if you want this simple loader to work without a token.
4. Replace OWNER and REPO in the code below.

```lua
local BASE = "https://raw.githubusercontent.com/OWNER/REPO/main/"
local Vision = loadstring(game:HttpGet(BASE.."init.luau"))(BASE)

local window = Vision.new({Title="Vision"})
local tab = window:CreateTab({Name="Movement", Icon="wind"})
local section = tab:CreateSection({Name="Settings", Column=1})
section:AddToggle({Name="Enabled", Id="enabled", Default=true})
```

Use your branch name instead of main if it is different.
For a fixed version, replace main with a commit SHA in BASE.
Only load repositories you trust. This downloads and runs their code.
GitHub permanent links: https://docs.github.com/en/repositories/working-with-files/using-files/getting-permanent-links-to-files

## Where to edit

`init.luau`: downloads the modules and returns the library.
`modules/AssetLoader.luau`: registers icon files in the executor.
`assets/Icons.luau`: the 49 embedded icon PNGs, downloaded as a separate module.
`modules/Config.luau`: saves and loads configs.
`modules/Themes.luau`: default theme colors.
`modules/Window.luau`: window setup, dragging, resizing and mobile controls.
`modules/Tabs.luau`: tabs and scrolling tab bar.
`modules/Sections.luau`: section layout, detached headers and docking.
`modules/Controls.luau`: toggles, sliders, dropdowns and buttons.
`modules/Keybinds.luau`: key capture and keybind HUD.
`modules/Colorpicker.luau`: picker UI, RGB, HEX and swatches.
`modules/Text.luau`: text boxes, labels and paragraphs.
`modules/Search.luau`: control search.
`modules/Notifications.luau`: notification toasts.
`modules/Utils.luau`: shared UI helpers.

Edit these files directly. No build step is needed for the modular version.
The modules attach to a shared context passed by init.luau, not a global variable.
Dependencies are fetched once per loader call. Icons are loaded when you create a window.
Library loading alone does not open the demo or change gameplay.

## Examples and docs

Example.luau is a short example.
examples/FullDemo.luau shows all controls.
docs/API.md has simple examples for each control.

## Requirements

Your executor needs game:HttpGet and loadstring.
Custom icon registration uses executor file APIs and getcustomasset.
Without those asset APIs, text symbols are used instead. Disk configs also need file APIs.
Touch gestures were tested with simulated input, not on a physical phone.

## Licenses

Lucide's license is included in assets/LUCIDE-LICENSE.txt. Keep it with the icons.
Choose a license for your own library before allowing others to redistribute it.

## Animation and repeat execution

Animations are enabled by default. Pass `Animations=false` to `Vision.new` for instant transitions. Window opening, visibility, tab changes, popups, button hover and toggle knobs animate.

Creating a window replaces and destroys the previous window with the same `Id` (default `VisionUI`), including its input connections and animations. Use distinct IDs to keep multiple windows. The registry uses `getgenv()` when available and `_G` otherwise. A stale same-name ScreenGui in the chosen parent is also removed. A GUI created by an older version can be removed, but its inaccessible Lua connections cannot be recovered by the new version.

Config helpers: `window:ListConfigs()` returns sorted names without `.json`; `window:DeleteConfig(name)` returns false when missing. These require executor file APIs.

## Reliability features

Version 1.2.0 includes a config manager with Save, Load, Delete, Reset and Refresh. Call `window:CreateConfigManager({Autosave=false})` after adding your controls. Autosave is opt in, debounced and keeps a previous-save backup when the executor file APIs support it.

Controls and sections support `:Destroy()`. Hold keybinds release when focus is lost or a bind is changed, disabled or removed. Explicit tab, section and control IDs preserve config identity across display-name changes. Textbox limits count Unicode code points and slider inputs are checked before rows are created.

See docs/API.md for options, backup behavior and examples. Runtime tests were performed through a connected Roblox client with synthetic touch input. Physical handset testing and screenshot-based visual approval are not claimed.
