# Dynamic compatibility tests

From the Vision repository root, run:

```sh
lune run tests/dynamic.luau .
```

Requires Lune. The fixture supplies Roblox datatypes, mocked UI instances and
in-memory executor file APIs. It executes Vision's real modules and tests flags,
callbacks, config round trips, Base64 sharing, theme and layout restoration,
empty dropdowns, keybind press semantics, conditional rows, confirmation dialogs,
tooltip shields, detached sections and destruction. No game automation runs.
This is not a rendered in-game or physical touch-device test.
