# TestFlight Deployment Guide

## Application Configuration

The application ID has been successfully updated to: **`com.antroph.auraapp`**

## Prerequisites for TestFlight Deployment

### 1. Apple Developer Account

- You need an active Apple Developer Program membership ($99/year)
- Sign in at: https://developer.apple.com/

### 2. App Store Connect Setup

1. Go to https://appstoreconnect.apple.com/
2. Create a new app:
   - Click "My Apps" → "+" → "New App"
   - **Bundle ID**: Select or create `com.antroph.auraapp`
   - **App Name**: Your app's name (e.g., "Aura" or "Antroph")
   - **Primary Language**: English
   - **SKU**: A unique identifier (e.g., "antroph-aura-001")

### 3. Certificates & Provisioning Profiles

You need to set up:

1. **Distribution Certificate** (for signing the app)
2. **App Store Provisioning Profile** (for TestFlight/App Store)

#### Option A: Use Xcode Automatic Signing (Recommended)

1. Open the project in Xcode:
   ```bash
   open ios/Runner.xcworkspace
   ```
2. Select the "Runner" target
3. Go to "Signing & Capabilities"
4. Check "Automatically manage signing"
5. Select your development team

#### Option B: Manual Signing

1. Go to https://developer.apple.com/account/resources/certificates
2. Create certificates and provisioning profiles
3. Download and install them
4. Configure in Xcode manually

### 4. Update Version & Build Number (if needed)

In `pubspec.yaml`, update the version:

```yaml
version: 1.0.0+1
```

Format: `version_name+build_number`

## Building for TestFlight

### Step 1: Install Dependencies

```bash
cd /Users/mac/Documents/github/fortune/pld/antroph-mobile
flutter pub get
cd ios && pod install && cd ..
```

### Step 2: Build the iOS Archive

```bash
flutter build ipa --release
```

This creates an `.ipa` file at: `build/ios/ipa/*.ipa`

### Step 3: Upload to TestFlight

#### Option A: Using Xcode (Recommended)

1. Open Xcode:
   ```bash
   open ios/Runner.xcworkspace
   ```
2. Select "Any iOS Device (arm64)" as the destination
3. Product → Archive
4. Once archived, click "Distribute App"
5. Choose "App Store Connect" → Next
6. Choose "Upload" → Next
7. Select signing options (automatic recommended)
8. Upload

#### Option B: Using Transporter App

1. Download from Mac App Store: "Transporter"
2. Open Transporter
3. Drag and drop your `.ipa` file
4. Click "Deliver"

#### Option C: Using Command Line (xcrun altool)

```bash
xcrun altool --upload-app --type ios --file build/ios/ipa/antroph_mobile.ipa \
  --apiKey YOUR_API_KEY --apiIssuer YOUR_ISSUER_ID
```

Note: You'll need to create an API key in App Store Connect:

- Users and Access → Keys → App Store Connect API

## After Upload

### 1. Processing

- Apple will process your build (typically 15-30 minutes)
- You'll receive an email when processing completes

### 2. TestFlight Setup

1. Go to App Store Connect → TestFlight
2. Select your app
3. Once processed, click on the build
4. Fill in "What to Test" notes
5. Add internal testers (up to 100, no review needed)
6. Or add external testers (requires App Review)

### 3. Distribute to Testers

- **Internal Testing**: Add Apple Developer team members
- **External Testing**: Add anyone via email (requires Apple review)

## Common Issues & Solutions

### Issue: "No Provisioning Profile Found"

**Solution**:

1. Open Xcode
2. Preferences → Accounts → Download Manual Profiles
3. Or use automatic signing

### Issue: "Missing Development Team"

**Solution**: Update `ios/Runner.xcodeproj/project.pbxproj` - Development team is already set to `3SQ48GQRTQ`

### Issue: "Archive Build Failed"

**Solution**:

```bash
cd ios
pod deintegrate
pod install
cd ..
flutter clean
flutter pub get
flutter build ios --release
```

### Issue: "App Icon Missing"

**Solution**: Make sure `assets/images/app_logo.png` exists and run:

```bash
flutter pub run flutter_launcher_icons
```

## App Icon Requirements

TestFlight requires proper app icons:

- Current configuration is set in `pubspec.yaml` under `flutter_launcher_icons`
- Icon should be 1024x1024px PNG (no transparency)
- Run this to generate icons:
  ```bash
  flutter pub run flutter_launcher_icons
  ```

## Privacy & Permissions

Your app uses:

- Bluetooth (flutter_blue_plus)
- Camera (mobile_scanner, image_picker)
- Photo Library (image_picker)
- WiFi (wifi_iot)

Make sure to add usage descriptions in `ios/Runner/Info.plist` (if not already present):

```xml
<key>NSCameraUsageDescription</key>
<string>We need camera access to scan QR codes and take photos</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>We need photo library access to select images</string>
<key>NSBluetoothAlwaysUsageDescription</key>
<string>We need Bluetooth access to connect to devices</string>
<key>NSLocationWhenInUseUsageDescription</key>
<string>We need location access for WiFi configuration</string>
```

## Next Steps After TestFlight

1. Test thoroughly with internal testers
2. Fix any bugs
3. Add external testers for wider testing
4. When ready, submit for App Store Review
5. Release to production!

## Useful Commands

```bash
# Check Flutter setup
flutter doctor -v

# Build for iOS (development)
flutter build ios --debug

# Build for TestFlight/App Store
flutter build ipa --release

# Open in Xcode
open ios/Runner.xcworkspace

# Clean everything
flutter clean && cd ios && pod deintegrate && rm -rf Pods Podfile.lock && cd ..

# Reinstall everything
flutter pub get && cd ios && pod install && cd ..
```

## Resources

- [Flutter iOS Deployment](https://docs.flutter.dev/deployment/ios)
- [App Store Connect Help](https://help.apple.com/app-store-connect/)
- [TestFlight Documentation](https://developer.apple.com/testflight/)
