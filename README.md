# FitStrong Check-In

The front desk app. A tablet or spare phone sits by the door with the camera
running; members hold up their QR code and their arrival is recorded.

It is one of three parts. Members and their codes are created in the owner's
app; this app only reads codes and writes attendance; both read the same rules
from a shared package, so the desk and the office can never disagree about who
is allowed in.

| Repo | What it is |
| --- | --- |
| [FitStrong — Gym Manager](https://github.com/sahilpotdukhe/FitStrongGymApp) | The owner's app: members, money, reports |
| **FitStrong Check-In** (this one) | The front desk scanner |
| [fitstrong_core](https://github.com/sahilpotdukhe/fitstrong_core) | Shared rules and record shapes both apps depend on |

---

## What it does

- **Runs the camera continuously.** No buttons to press: a member holds up
  their code and the card appears.
- **Shows the member's face.** Every result card carries their photo and name,
  so staff can see at a glance that the person matches the code.
- **Keeps working when the Wi-Fi drops.** The member list is kept in the
  device's own cache, so an offline lookup still finds everybody rather than
  turning paying members away. Arrivals are written to disk and sync
  themselves later; a counter shows how many are still waiting.
- **Never double-counts.** A second scan the same day is not a new record,
  which also covers the camera reading the same code many times a second.
- **Ignores other QR codes.** Payment codes, Wi-Fi codes and posters are
  thrown out before they ever reach the database.

### What the desk sees and hears

Staff are usually looking at the member, not the screen, so each outcome has
its own sound.

| Result | Card | Sound |
| --- | --- | --- |
| Checked in | Green | One click |
| **Payment due** | Amber — *"Plan ended 3 days ago, 4 days left to renew"* | **Two clicks** |
| Already checked in | Amber | Alert |
| Membership expired | Red — turned away, nothing recorded | Alert |
| Code not recognised | Red | Alert |
| Not a member code | Amber | Alert |

**Payment due** is the window a member gets to settle up after their plan runs
out. They are let in and the arrival is recorded exactly like anyone else's —
the desk's job is to ask for the money, not to stop them at the door. Once the
window is gone, the card turns red and nothing is written. The length of that
window is one number in
[fitstrong_core](https://github.com/sahilpotdukhe/fitstrong_core), read by both
apps.

---

## Requirements

- Flutter **3.47.7** or newer (stable)
- A camera on the device
- The same Firebase project the owner's app uses

---

## Setup

```bash
git clone https://github.com/sahilpotdukhe/FitStrong-Check-In.git && cd FitStrong-Check-In
```

```bash
flutter pub get
```

Firebase config is already committed, so there is nothing to generate and no
environment file to fill in.

**Signing in:** the desk signs in with the **gym owner's own account** — the
same email and password used in the owner's app. That account's user id *is*
the gym id, which is how this app knows whose members to look for. "Remember
me" is on by default so a tablet left at the door stays signed in.

---

## Everyday commands

| Task | Command |
| --- | --- |
| Run on a connected device | `flutter run` |
| Run all tests | `flutter test` |
| Static analysis | `flutter analyze lib test` |
| Format | `dart format lib test` |
| Refresh dependencies | `flutter pub get` |
| Clear a bad build | `flutter clean && flutter pub get` |
| List connected devices | `flutter devices` |

Run it on the tablet:

```bash
flutter run
```

Run the tests:

```bash
flutter test
```

---

## Release builds

### One-time: signing key

Release builds are **not** debug-signed, and a release build **stops** if no
key is set up:

```
No signing key, so this release would be unsigned and could not be installed
on any device.
```

That guard is there because Android on its own does not stop — it writes
unsigned APKs that fail to install, and the problem only shows up on the
tablet. Debug builds need no key and are unaffected.

**Use the same keystore as the owner's app.** One key signs both: they have
different package names, so they never collide, and it is one file to back up
instead of two. If you have not made one yet:

```bash
keytool -genkey -v -keystore ~/fitstrong-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Then create `android/key.properties` here (gitignored), pointing at that same
file:

```properties
storePassword=yourStorePassword
keyPassword=yourKeyPassword
keyAlias=upload
storeFile=/Users/you/fitstrong-upload.jks
```

Keep the `.jks` backed up. Losing it means you can never update an installed
app in place — every phone and tablet would need the old one uninstalled
first.

### Check a build really is signed

```bash
$(ls ~/Library/Android/sdk/build-tools/*/apksigner | tail -1) verify --print-certs build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

A signed APK prints its certificate. An unsigned one says `DOES NOT VERIFY`.

### APK split per ABI (recommended for direct sharing)

One APK per phone architecture, each carrying native code for one chip
family instead of all three. Measured on this app: 36 MB universal against
26 MB for arm64, 22 MB for armeabi-v7a.

```bash
flutter build apk --release --split-per-abi
```

Output lands in `build/app/outputs/flutter-apk/`:

| File | Install on |
| --- | --- |
| `app-arm64-v8a-release.apk` | Almost every tablet and phone from 2016 onward — **use this one** |
| `app-armeabi-v7a-release.apk` | Older 32-bit devices, including some cheap desk tablets |
| `app-x86_64-release.apk` | Emulators and a few Intel tablets |

Cheap front-desk tablets are the one place `armeabi-v7a` still genuinely
turns up, so keep that one around.

### Universal APK (one file that installs anywhere)

```bash
flutter build apk --release
```

### Play Store bundle

```bash
flutter build appbundle --release
```

### Installing straight onto a plugged-in tablet

```bash
flutter install --release
```

### Bumping the version

Edit `version:` in `pubspec.yaml` — `1.0.0+1` means version name `1.0.0`,
build number `1`.

---

## How a scan is decided

In order, stopping at the first that applies:

1. Not our QR format → **Not a member code**. Costs nothing, never hits the
   database.
2. No member holds this token → **Code not recognised**. Revoked or deleted.
3. Past the payment window → **Membership expired**. Nothing is written.
4. Already recorded today → **Already checked in**. No second record, whatever
   they owe.
5. Inside the payment window → **Payment due**. Recorded, money chased.
6. Otherwise → **Checked in**.

A write that cannot reach the server within a few seconds is reported as
saved-and-waiting rather than failed, because it is on disk and will sync.
Telling staff it failed would send them to scan again and create duplicates.

---

## Project layout

```
lib/
├── main.dart             sign-in gate; the signed-in uid becomes the gym id
├── sign_in_page.dart     email and password, with remember me
├── scanner_page.dart     the camera, the result cards, the sounds
└── checkin_service.dart  lookups, the decision, and the write
test/                     every branch the desk can hit, no Firestore needed
```

---

## Installing on the tablet

A release APK built as above installs normally. Two things are worth knowing:

**Uninstall any older build first.** Android refuses to install an APK signed
with a different key over one already on the tablet. Debug builds (anything
from `flutter run`) are signed with the shared Android debug key, release
builds with the upload key, so the first release install on any tablet you
have ever developed on will be rejected. Over USB the reason is explicit:

```
INSTALL_FAILED_UPDATE_INCOMPATIBLE: Existing package com.fitstrong.checkin
signatures do not match newer version; ignoring!
```

Through Firebase App Distribution or a file manager you get only a blunt
*"App not installed"*, with nothing saying why.

**The trap is that the old build can be invisible.** Android keeps the package
record and its signature even after the app has been removed for your user, so
it is gone from the launcher and from the app list while still blocking the
install. `adb shell dumpsys package com.fitstrong.checkin` shows it as
`installed=false` with a `DEBUGGABLE` flag and a `codePath` still on disk.

Clearing it takes one command, and loses nothing — such a record has no app
data behind it (`dataDir=null`), and the real data lives in Firestore:

```bash
adb uninstall com.fitstrong.checkin
```

Then install normally. This is a one-time step per tablet; once everything
is on the same key, release updates install straight over the top.

**Play Protect may ask once.** Any app installed outside the Play Store can
raise a *"scan this app?"* or *"unknown developer"* prompt, because Google has
never seen the signing key before. That is sideloading itself, not a fault in
the build — signing properly is what keeps it to a prompt rather than a block.
Allowing it once is enough, and nothing needs to be switched off. Publishing
through Play is the only way to remove the prompt entirely.

## Firebase

The app is registered in the Firebase project **fitstrong-gym** as
`com.fitstrong.checkin`. Two files are tied to that:

- `android/app/google-services.json` — matched by package name at build time.
  A mismatch fails the build with *"No matching client found"*.
- `lib/firebase_options.dart` — carries the Firebase App ID, used by
  `Firebase.initializeApp` in `main.dart`.

**Both must be updated together.** Changing the package name in Gradle alone
breaks the build; changing it in Gradle and `google-services.json` but not in
`firebase_options.dart` builds fine and then talks to the wrong app at
runtime, which is the harder failure to spot.

Sign-in is email and password, so no SHA-1 certificate fingerprint needs
registering. If Google Sign-In is ever added, the signing key's SHA-1 has to
be added to the Firebase app first.

## Known gaps

- **Android only.** `firebase_options.dart` is configured for Android alone,
  and asking it for any other platform throws a clear `UnsupportedError`. The
  iOS, macOS and Windows folders still carry Flutter's template
  `com.example.fitstrongcheckin` identifier and have no Firebase app behind
  them. Porting the scanner means picking a real identifier, registering it
  in the **fitstrong-gym** project, and running the FlutterFire CLI again.
