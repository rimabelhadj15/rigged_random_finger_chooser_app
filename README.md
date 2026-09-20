# Finger Chooser

A party-game app: everyone places a finger on the phone, a 3-second countdown
runs, then one finger is "chosen." Black background, neon glowing circle
around each finger, circles follow your finger if you drag it.

**The trick:** normally the winner is picked at random. But if the phone's
media **volume is muted (0)**, the app secretly always picks whichever
finger was placed *last* — so you can silently rig it in your favor by
muting the volume right before playing, with no visible sign anything is
different.

## Files in this folder
- `pubspec.yaml` — dependencies
- `lib/main.dart` — the entire app

## How to turn this into a real Flutter project

You need Flutter SDK installed (flutter.dev → get started). Then:

```bash
# 1. Create a fresh Flutter project skeleton (gives you android/, ios/, etc.)
flutter create finger_chooser
cd finger_chooser

# 2. Replace the generated pubspec.yaml and lib/main.dart with the ones
#    from this folder (overwrite them).

# 3. Install dependencies
flutter pub get

# 4. Run on a connected device / emulator to test
flutter run

# 5. Build the release APK
flutter build apk --release
```

The finished APK will be at:
`build/app/outputs/flutter-apk/app-release.apk`

Copy that file to your phone (or `flutter install`) to install it.

## Notes / things you may want to tweak
- **Trigger threshold**: in `main.dart`, `_volumeTriggerThreshold` (0.02)
  controls how close to "off" the volume needs to be to activate the rig.
  Raise it if your phone never reports an exact 0.
- **Countdown length**: `_countdownSeconds` (currently 3).
- **Minimum players**: the countdown only starts once 2+ fingers are down.
- **Package API**: `volume_controller` is read-only here (we never change
  the user's actual volume, just read it). If a future package version
  renames a method, the app falls back to "not rigged" rather than
  crashing.
- No special Android permissions are needed for reading volume.
