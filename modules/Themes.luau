local function rgb(r,g,b) return Color3.fromRGB(r,g,b) end
local Themes = {
    Lapse = {Background=rgb(26,26,30), Surface=rgb(31,31,36), Raised=rgb(38,38,44), Border=rgb(48,48,55), Text=rgb(221,221,227), Muted=rgb(145,145,155), Accent=rgb(145,120,255)},
    Midnight = {Background=rgb(17,22,31), Surface=rgb(23,30,42), Raised=rgb(31,40,55), Border=rgb(46,57,75), Text=rgb(227,233,244), Muted=rgb(145,160,183), Accent=rgb(89,160,246)},
    Rose = {Background=rgb(29,24,28), Surface=rgb(37,29,35), Raised=rgb(46,36,43), Border=rgb(62,47,57), Text=rgb(241,225,235), Muted=rgb(168,143,157), Accent=rgb(231,128,174)},
}
Themes.Vision = Themes.Lapse -- Legacy theme/config alias.

return Themes
