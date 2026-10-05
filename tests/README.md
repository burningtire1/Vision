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

Config safety regressions:

```sh
lune run tests/config.luau .
```

Checks malformed and oversized JSON, invalid values and future schemas, style
preflight, injected render failure rollback, settings-before-activation ordering,
backup recovery, interrupted-write readback, explicit startup readiness, callback
dispatch and reserved profile names. Fixtures never enable gameplay automation.
