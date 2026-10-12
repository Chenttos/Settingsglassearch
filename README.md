# SettingsGlassSearch

iOS 26 style floating **Liquid Glass search bar** for the Settings app on iOS 15 - 18.

- Glass pill pinned above the home indicator, rides above the keyboard while typing
- Round glass **X** button slides in next to it while searching (replaces "Cancel")
- Typing is forwarded into Settings' own `UISearchController`, so the real Settings search,
  results and row navigation are used
- The stock search field under the "Settings" title is removed
- Pill hides when you push into a page and returns when you come back
- Does nothing on iOS 26 (it already has this bar)

## Glass effect

Taken from the LiquidAss zip. The stack follows `LGFramework` / `LGButtonView`:

| layer | source |
|---|---|
| blur | `SGSBlurView` - `LGAdjustableBlurView` renamed (`CABackdropLayer` + gaussianBlur + saturate) |
| refraction | LiquidAss' real `LGLiveBackdropView`, created at runtime with the `dylv.liquidglass.searchpill` filter (the Home Screen search pill preset) |
| tint | same values as `LGButtonView` |
| rim light | `SGSSpecularView` - `LGSpecularHighlightView` renamed (used only when LiquidAss is missing; `LGLiveBackdropView` draws its own rim) |

Install **Liquid (Gl)ass 27** (`com.ngkhoi.liquidass27`) next to this tweak for the full refraction.
Without it the pill still works and falls back to a frosted blur + rim.
`LGLiveBackdropView` is looked up with `NSClassFromString`, so nothing is linked and there are no
duplicate-class clashes with LiquidAss in the same process. Tune the look in the LiquidAss prefs.

## Build

Needs [Theos](https://theos.dev).

```sh
make package FINALPACKAGE=1                              # rootless (default)
make package FINALPACKAGE=1 THEOS_PACKAGE_SCHEME=roothide
make package install THEOS_DEVICE_IP=<ip>               # build + install, respring Settings
```

## Files

```
Tweak.x                 hooks PSUIPrefsListController, drives the stock UISearchController
SGSSearchBarView.h/.m   floating pill + X button, keyboard tracking
Glass/SGSGlassView.*    glass stack (blur + LiquidAss refraction + tint + rim)
Glass/SGSBlurView.*     from LGAdjustableBlurView
Glass/SGSSpecularView.* from LGSpecularHighlightView
```

## Status / known rough edges

Written against the class and API names that Settings uses on iOS 15-18, but **not compiled or run
on a device yet** - I had no Theos or iOS SDK to test with. If something is off, check `oslog` for
lines starting with `[SettingsGlassSearch]`. Likely spots to tweak:

- `findStockSearchController` in `Tweak.x` (how the Settings root exposes its `UISearchController`)
- the 0.12s focus hand-back in `sgsSearchBarDidBeginEditing:`
- pill size/margins at the top of `SGSSearchBarView.m`

## License

The glass code is derived from LiquidAss (CC BY-NC 4.0), so this tweak is **non-commercial**.
See `NOTICE.md`.

## Safe mode

If Settings crashes while the tweak is starting, the next launch comes up with the tweak switched
off for 5 minutes (`SGSDisabledUntil` in Settings' defaults), so a bug
here can't lock you out of Settings. Crash logs: `/var/mobile/Library/Logs/CrashReporter/Settings-*.ips`.
