# Triple Tile Adventure

A complete Android-first Flutter puzzle game inspired by Triple Tile / Tile Explorer mechanics.

## Features

- Tap only uncovered overlapping tiles.
- Bottom tray holds tapped tiles; three identical tiles auto-match and disappear.
- Lose when the tray exceeds seven tiles; win when every tile is removed.
- Ten JSON-authored levels with increasing tile counts and layer complexity.
- Final configurable four-digit reward code after level 10.
- Main menu, settings, map, game, win, and final-code screens.
- Shuffle, hint, and undo boosters.
- Local progress, audio preferences, and code storage via `shared_preferences`.
- Portrait-only Android configuration.
- Runtime-generated procedural sound effects and looping background music, keeping the repository text-only for PR review tools.

## Run

```bash
flutter pub get
flutter run --flavor dev --dart-define=FLAVOR=dev
flutter run --flavor prod --dart-define=FLAVOR=prod
```

The `dev` flavor installs as **Tile Adventure DEV** with application ID
`com.ragarrwc.game.dev` and enables the QA menu. The `prod` flavor installs as
**Tile Adventure** with application ID `com.ragarrwc.game` and excludes QA
controls.

## Production bundle

```bash
flutter build appbundle --flavor prod --dart-define=FLAVOR=prod
```

## Configure reward code

The default code is `4286`. You can override it at build time:

```bash
flutter build appbundle --release --flavor prod --dart-define=FLAVOR=prod --dart-define=FINAL_CODE=1234
```

The Settings screen also allows changing the code locally for QA or promotional builds.

## Google Play publishing checklist

1. Create an upload keystore and provide these environment variables before release builds:
   - `ANDROID_KEYSTORE_PATH`
   - `ANDROID_KEYSTORE_PASSWORD`
   - `ANDROID_KEY_ALIAS`
   - `ANDROID_KEY_PASSWORD`
2. Build an Android App Bundle:

```bash
flutter build appbundle --release --flavor prod --dart-define=FLAVOR=prod --dart-define=FINAL_CODE=1234
```

3. Replace the simple XML launcher icon with final brand art if desired; avoid committing binary icon files if your PR tool rejects binary diffs.
4. Complete Play Console store listing, screenshots, content rating, privacy policy, and data safety declarations.
