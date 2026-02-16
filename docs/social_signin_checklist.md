# Social Sign-In Checklist (Google + Apple)

This app now includes local code/project wiring for Google and Apple sign-in.
Complete the external console configuration below to guarantee release builds work.

## 1. Firebase Auth Providers

In Firebase Console for project `anthroph-11199`:

1. Enable `Google` provider in Authentication -> Sign-in method.
2. Enable `Apple` provider in Authentication -> Sign-in method.
3. Confirm iOS app bundle id is `com.antroph.auraapp`.
4. Confirm Android package name is `com.antroph.aura`.

## 2. Android OAuth Fingerprints (Required For Release)

Google sign-in on Android release requires SHA-1/SHA-256 fingerprints registered on the Firebase Android app.

Current local signing report:

- Debug SHA-1: `75:38:8A:18:5C:8B:4E:BE:61:17:38:B9:43:FE:B3:AE:AC:BF:F9:FC`
- Release SHA-1: `C2:C1:29:08:AB:27:CA:2F:EB:3C:F1:FE:70:F0:82:55:33:53:3A:FD`
- Release SHA-256: `A0:3F:DF:91:B5:63:51:3B:24:D2:D3:15:46:61:14:66:D2:A4:B8:34:64:EE:C4:48:FC:01:93:73:C0:F9:82:72`

After adding fingerprints in Firebase Console:

1. Download updated `google-services.json`.
2. Replace `android/app/google-services.json`.
3. Run `cd android && ./gradlew :app:processDebugGoogleServices`.

## 3. Apple Developer Capability + Firebase Provider Details

For Apple sign-in to work on real devices/TestFlight:

1. Apple app id for `com.antroph.auraapp` must have `Sign In with Apple` capability enabled.
2. Firebase Apple provider must be configured with valid Apple Service ID/key/team details.
3. Use a physical iOS device for final verification (simulator support is limited).

## 4. Validation Commands

From project root:

```bash
flutter analyze
flutter build apk --debug
cd ios && xcodebuild -workspace Runner.xcworkspace -scheme Runner -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16 Pro (Flutter)' build CODE_SIGNING_ALLOWED=NO
```
