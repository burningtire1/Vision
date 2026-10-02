# Editing Vision

Open the module that matches what you want to change. The README lists them.

Each behavior module returns a function that receives ctx.
ctx contains the shared Library, Window, Tab, Section and Control tables.
Most functions attach to one of those tables.

Example: change slider behavior in modules/Controls.luau.
Change picker colors in modules/Colorpicker.luau.
Change config validation in modules/Config.luau.

Keep each module's final return statement.
If you add a new module, add its name to the module list in init.luau.
init.luau caches downloaded modules for that one library load.
Run the loader again after uploading edits to get a fresh copy.

Dependencies should come from the same repository version. Pin BASE to a commit
when you want all modules to stay on a fixed version.
