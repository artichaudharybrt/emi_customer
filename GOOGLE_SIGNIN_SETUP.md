# Google Sign-In Setup Instructions

## Overview
This app implements Google Account Login with Factory Reset Protection (FRP) to encourage users to bind their Google accounts to their devices. After a factory reset, the device will require the same Google account to unlock.

## Features
- **Google Sign-In Integration**: Users can sign in with their Google accounts
- **Device Binding**: Google account is bound to the device ID
- **FRP Protection**: Information about Factory Reset Protection is displayed
- **Account Storage**: Google account information is securely stored locally

## Setup Instructions

### 1. Configure Google Sign-In for Android

#### Step 1: Get SHA-1 Certificate Fingerprint
```bash
# For debug builds
cd android
./gradlew signingReport

# Or use keytool
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
```

#### Step 2: Create OAuth 2.0 Credentials
1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select existing one
3. Enable "Google Sign-In API"
4. Go to "Credentials" → "Create Credentials" → "OAuth client ID"
5. Select "Android" application type
6. Enter your package name: `com.rohit.emilockercustomer`
7. Enter your SHA-1 fingerprint from Step 1
8. Download the `google-services.json` file

#### Step 3: Update Android Configuration
1. Place `google-services.json` in `android/app/` directory
2. The app will automatically use this configuration

### 2. Update Android Build Configuration (if needed)

In `android/app/build.gradle.kts`, ensure you have:

```kotlin
android {
    defaultConfig {
        minSdk = 21  // Google Sign-In requires at least API 21
    }
}
```

### 3. How FRP Protection Works

1. **During Setup**: When user signs in with Google, the account is:
   - Stored securely in SharedPreferences
   - Bound to the device ID (Android ID)
   - Timestamp of binding is recorded

2. **After Factory Reset**: 
   - Android OS will prompt for the Google account that was previously used
   - Without the correct Google account credentials, the device cannot be used
   - User must return to shop for assistance if they forget credentials

3. **In the App**:
   - Shows FRP protection status
   - Displays which Google account is bound
   - Warns about consequences of factory reset without account credentials

## Important Notes

⚠️ **Cannot Force FRP**: This app cannot force FRP protection - it's an Android OS feature. However, we:
- Encourage users to sign in with Google (prominent button)
- Explain the benefits of FRP protection
- Store account information to show protection status

⚠️ **Privacy**: All Google account data is stored locally on the device only. No data is sent to external servers unless you implement a backend.

## Testing

1. Sign in with a Google account
2. Check that FRP protection card appears
3. Verify account email is displayed
4. Test sign out and sign in again
5. Verify account binding persists after app restart

## Troubleshooting

### Google Sign-In not working?
- Verify SHA-1 fingerprint is correct
- Ensure `google-services.json` is in correct location
- Check that Google Sign-In API is enabled in Google Cloud Console
- Verify package name matches exactly

### FRP card not showing?
- Ensure you've signed in with Google at least once
- Check that SharedPreferences has stored account data
- Verify device ID is being captured correctly

## Security Considerations

- Google account information is stored in SharedPreferences (encrypted on Android)
- Consider implementing encryption for sensitive data
- Device ID binding helps track which device the account was used on
- Factory reset protection is enforced by Android OS, not the app
















