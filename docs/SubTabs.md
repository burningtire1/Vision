# Sub tabs

Drag a section out of the window to make a sub tab.
Right Shift hides and shows the window with all its sub tabs.
The short animation takes 0.16 seconds. Positions stay unchanged.
Click the dock icon to put a sub tab back.

Use window:SetVisible(false) to hide or window:SetVisible(true) to show.
The existing section:Detach() and section:Dock() methods still work.
section.IsSubTab tells you whether a section is a sub tab.
