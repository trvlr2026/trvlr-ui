# Trvlr UI

Flutter mobile app for **Trvlr** — a travel game where users earn points for visiting places, climb leaderboards (district / state / national), and import past travels from photo GPS metadata.

This repo is **UI-only** for now. Data is mocked locally via `MockTrvlrRepository` (no backend required).

## Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (stable, Dart 3.11+)
- **iOS:** Xcode + CocoaPods (for iPhone / iOS Simulator)
- **Android:** Android Studio + SDK (for Android Emulator or device)

Verify your setup:

```bash
flutter doctor
```

## Setup

```bash
cd trvlr-ui
flutter pub get
```

## Run the app

List available devices:

```bash
flutter devices
```

### Android Emulator (recommended for quick testing)

```bash
# List emulators
flutter emulators

# Launch one (e.g. Pixel 8)
flutter emulators --launch Pixel_8_API_35

# Run on the emulator
flutter run -d emulator-5554
# or
flutter run -d Pixel_8_API_35
```

If the emulator shows `unauthorized` for ADB, cold-boot it:

```bash
export PATH="$PATH:$HOME/Library/Android/sdk/platform-tools:$HOME/Library/Android/sdk/emulator"
adb kill-server && adb start-server
emulator -avd Pixel_8_API_35 -no-snapshot-load
```

Add sample photos via the emulator: **Extended controls (⋯) → Images**.

### iOS Simulator

```bash
open -a Simulator
flutter run -d "iPhone 17 Pro"
```

Pick any simulator name from `flutter devices`.

### Physical device

**Android:** Enable USB debugging, connect via cable, then:

```bash
flutter run
```

**iPhone:** USB connection is more reliable than wireless. Trust the computer on the device, then:

```bash
flutter run
```

If wireless debugging fails with “Unable to find a destination”, use a cable or run on an iOS Simulator instead.

## Permissions

The app requests permissions at runtime:

| Permission | Used for |
|---|---|
| Location | Map, check-in at POIs |
| Photos | My Photos gallery scan, onboarding import |

On **My Photos**, tap **Grant access** if prompted. If you previously denied access, use **Open Settings** and enable Photos (and **Location** for photo metadata on Android).

After changing `AndroidManifest.xml` or `Info.plist`, do a **full restart** (`flutter run`), not just hot reload.

## Tests

```bash
flutter test
flutter analyze
```

## Project structure

```
lib/
  core/           # GPS, photo scanning, permissions, theme
  data/           # Models, dummy POI data, mock repository
  features/       # Auth, map, photos, leaderboards, profile
  providers/      # Riverpod providers
  router/         # go_router navigation
```

## App flow

1. Register / sign in (mock auth — any credentials work)
2. Onboarding — location + photo permissions
3. Optional photo import — awards points from geotagged photos
4. **Map** — check in at curated India POIs
5. **My Photos** — all gallery photos with GPS / place names
6. **Ranks** — district, state, national leaderboards
7. **Profile** — stats and visit history

## Notes

- Leaderboard and visit data persist locally via `shared_preferences`.
- A real API can replace `MockTrvlrRepository` later without rewriting screens.
- Backend (`trvlr-be`) is a separate repo and not required to run this app.
