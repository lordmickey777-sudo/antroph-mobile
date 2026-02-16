# antroph-mobile

A Flutter mobile app (Android + iOS) base setup with:

- State management: Riverpod
- Networking: dio (+ interceptors)
- Storage: drift (SQLite)
- Routing: go_router
- Bluetooth/Wi‑Fi: flutter_blue_plus, wifi_iot
- Logging: logger, sentry_flutter
- CI/CD: Coolify (Docker-based Android build)

## Run locally

Ensure Flutter 3.32+ is installed.

```sh
# Get dependencies
flutter pub get

# Generate code for Drift
dart run build_runner build --delete-conflicting-outputs

# Run on a device/emulator
flutter run
```

### Running on specific devices

```sh
# List available devices
flutter devices

# Run on a specific device
flutter run -d <device-id>

# Common flags
flutter run -d <device-id> --release   # Release mode (faster, no debugging)
flutter run -d <device-id> --debug     # Debug mode with hot reload (default)
flutter run -d <device-id> --profile   # Profile mode for performance testing
```

### Other useful commands

```sh
flutter clean              # Clean build files
flutter pub get            # Get dependencies
flutter analyze            # Check for errors
flutter install -d <device-id>  # Install without running
flutter logs -d <device-id>     # View device logs
```

## Building release (APK & iOS)

Below are common Flutter commands to build Android and iOS release artifacts. Run these from the repository root. Building iOS artifacts requires a macOS machine with Xcode and proper code signing configured.

### Android (APK / App Bundle)

**Single APK (universal)**

1) `flutter pub get`
2) (Optional) add defines, e.g. `--dart-define=SENTRY_DSN=...`
3) Build: `flutter build apk --release`
4) Artifact: `build/app/outputs/flutter-apk/app-release.apk`



**Android App Bundle (Play Store)**

```sh
flutter build appbundle --release
# Artifact: build/app/outputs/bundle/release/app-release.aab
```

**Install release build on device**

```sh
flutter install --release
```

### Configure Android release signing

- Generate a keystore (example): `keytool -genkey -v -storetype JKS -keyalg RSA -keysize 2048 -validity 36500 -keystore android/app/antroph-release-key.jks -alias antroph`
- Create `android/key.properties` (git-ignored) using the values from your keystore. You can start from `android/key.properties.example`.
- Alternatively, set environment variables instead of a file: `ANDROID_KEYSTORE_PATH`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`.
- A release build will fail if these values are missing; configure them before running `flutter build appbundle --release` or uploading to Play Console.

### iOS (IPA / Archive)

Prerequisites: macOS, Xcode, CocoaPods, and valid provisioning profiles / signing set up in Xcode.

**One-time**

```sh
cd ios && pod install && cd -
```

**Archive for App Store/TestFlight (via Xcode)**

1) `flutter build ios --release`
2) Open workspace: `open ios/Runner.xcworkspace`
3) In Xcode: Product ➜ Archive ➜ distribute via Organizer.

**Build IPA via Flutter CLI**

```sh
flutter build ipa --export-method app-store
# Artifact: build/ios/ipa/Runner.ipa
```

Notes:

- For TestFlight/App Store uploads prefer `--export-method app-store` and ensure App Store Connect credentials are configured.
- For local device testing use `--export-method development` or use Xcode to manage signing.

Optional environment at build time:

- SENTRY_DSN: Provide at compile-time to enable Sentry (otherwise it runs without Sentry)

```sh
flutter run --dart-define=SENTRY_DSN=YOUR_SENTRY_DSN
```

## Project structure

- `lib/app.dart`: Root MaterialApp.router wired to go_router
- `lib/app_router.dart`: Routes
- `lib/bootstrap.dart`: Logger + Sentry initialization and guarded run
- `lib/core/network/dio_client.dart`: Dio with logging & Sentry interceptors (Riverpod provider)
- `lib/core/db/app_database.dart`: Drift database + Settings table (Riverpod provider)
- `lib/features/home/presentation/home_page.dart`: Sample home screen
- `lib/features/bluetooth/*`: Basic Bluetooth streams using flutter_blue_plus
- `lib/features/wifi/*`: Basic Wi‑Fi status/SSID via wifi_iot

## Theme

The app uses dark mode globally. The Scaffold background color is set to `#141718` via the dark theme in `lib/app.dart`.

## App icon

Launcher icons are generated with `flutter_launcher_icons` from `assets/images/app_logo.png`.

Regenerate after updating the logo:

```sh
fvm flutter pub get
fvm flutter pub run flutter_launcher_icons
```

## Typography

The global font for the app is Aeonik. The font file is included at `assets/fonts/aeonik.ttf` and registered in `pubspec.yaml`. Both light and dark themes set `fontFamily: 'Aeonik'` in `lib/app.dart`.

## Android/iOS permissions

Bluetooth and Wi‑Fi permissions/descriptions have been added in:

- Android: `android/app/src/main/AndroidManifest.xml`
- iOS: `ios/Runner/Info.plist`

Camera scanning (QR/barcode) requires:

- Android: `<uses-permission android:name="android.permission.CAMERA" />`
- iOS: `NSCameraUsageDescription` with a user-facing reason string

The Scan page uses the `mobile_scanner` package and will prompt for camera permission on first use.

On iOS, connecting to specific Wi‑Fi networks may require the HotspotConfiguration entitlement in your provisioning profile.

## CI with Coolify (Docker)

This repo includes a Dockerfile that builds the Android release APK.

1. Add a new Docker app in Coolify pointing to this repository
2. Build will run `flutter build apk --release` inside the container
3. The resulting artifact is placed at `/artifacts/app-release.apk` in the container

Locally test the Docker build:

```sh
docker build -t antroph-mobile:build .
docker run --rm antroph-mobile:build
```

Note: Building iOS requires macOS and code signing. Consider Fastlane + a macOS runner for iOS CI.

## Custom Button Widget

The app includes a general-purpose `AppButton` at `lib/widgets/app_button.dart` that provides subtle haptic and tap feedback when pressed. It wraps `ElevatedButton` and triggers `HapticFeedback.selectionClick()` plus `Feedback.forTap()` by default.

Usage:

```dart
AppButton(
  onPressed: () => print('Pressed!'),
  child: Text('Click me'),
  style: ElevatedButton.styleFrom(
    backgroundColor: Colors.blue,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
  ),
)
```

## Next steps

- Add API base URL and auth to `dio` client
- Create Drift DAOs/tables for your domain
- Implement feature modules and navigation
- Add Sentry user context and breadcrumbs
- Add permissions requests and UX for Bluetooth/Wi‑Fi

## Notes on Cupertino-style sheets

This app uses Flutter's built-in `CupertinoSheetRoute` (via `showCupertinoSheet` in `lib/widgets/app_bottom_sheet.dart`) to present full-height sheets. Use `showAppBottomSheet` to open a sheet; it always pushes to the root navigator so transitions stack correctly. To close:

- Use `Navigator.of(context).pop(result)` when you need to return a result.
- Use `CupertinoSheetRoute.popSheet(context)` if you ever enable nested sheet navigation and want to dismiss the entire sheet.

# antroph-mobile
