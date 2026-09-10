# Pot Toepen

A polished, offline-first scorekeeper for Pot Toepen. The MVP is built for Android with Flutter and keeps all game data locally on the device.

## What is included

- New games for 2–8 players, each starting at `-1`
- Points, euro, dollar, and pound display units
- Explicit per-player stakes, including `0`, plus a one-tap `POT` action
- Winner selection and a complete score/pot preview before processing
- A configurable final phase that empties the remaining pot exactly
- Round history and repeatable undo
- Automatic local save and active-game resume
- Remembered player names and local game history
- Final standings shared through Android's share sheet, including WhatsApp
- Purpose-built dark card-table styling, transitions, haptics, and round celebrations

The full product and scoring rules are in [REQUIREMENTS.md](REQUIREMENTS.md).

## Architecture

The code is split into four small layers:

- `lib/domain`: immutable models and deterministic game rules
- `lib/data`: repository contract and SQLite persistence
- `lib/application`: app state and use-case coordination
- `lib/ui`: Material 3 theme, reusable widgets, and screens

The game engine has no Flutter or database dependency, so scoring and final-payout behavior can be tested independently.

## Run locally

Install the current stable Flutter SDK and Android SDK, then run:

```sh
flutter pub get
flutter run
```

Quality checks:

```sh
flutter analyze
flutter test
```

Build a test APK:

```sh
flutter build apk --debug
```

## Platform scope

Android is the MVP target. The Flutter project includes an iOS target to preserve a straightforward future migration path, but the iOS app is not currently tested, signed, or part of the MVP acceptance scope.
