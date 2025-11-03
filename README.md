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

## Android/iOS permissions

Bluetooth and Wi‑Fi permissions/descriptions have been added in:

- Android: `android/app/src/main/AndroidManifest.xml`
- iOS: `ios/Runner/Info.plist`

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

## Next steps

- Add API base URL and auth to `dio` client
- Create Drift DAOs/tables for your domain
- Implement feature modules and navigation
- Add Sentry user context and breadcrumbs
- Add permissions requests and UX for Bluetooth/Wi‑Fi

# antroph-mobile
