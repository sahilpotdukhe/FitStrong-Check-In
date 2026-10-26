# Brand source files

`logo.png` is the full size FitStrong Attendance icon, kept here rather than
in `assets/` so it is not bundled into the app - nothing loads it at runtime.

It is the master the shipped artwork is cut from:

* the Android launcher icons in `android/app/src/main/res/mipmap-*/`
* the iOS icons in `ios/Runner/Assets.xcassets/AppIcon.appiconset/`
* `assets/logo_mark.png`, the mark with the dark square erased, used on the
  sign in screen

Redo those from this file if the logo ever changes.
