# SHA-1 Certificate Document
## Firebase & Google Services Configuration

---

## 📱 **App Information**

- **Package Name**: `com.rohit.emilockercustomer`
- **App Name**: Fasst Pay / EMI Locker Customer
- **Project**: emilockercustomer

---

## 🔐 **SHA-1 Certificate Fingerprints**

### **DEBUG BUILD (Development)**

```
SHA-1: 5A:AE:A1:B7:AC:24:C2:4D:EA:E3:97:55:8A:1D:3F:FD:3B:97:F6:E0
```

**Details:**
- **Keystore Location**: `C:\Users\brt7\.android\debug.keystore`
- **Alias**: `AndroidDebugKey`
- **MD5**: `06:9A:FF:01:68:82:DA:15:39:24:84:4A:3E:E0:1B:91`
- **SHA-256**: `BF:8F:9D:C7:D7:DD:91:17:98:E3:A8:1E:2F:F0:FE:C4:DE:40:04:0C:61:D6:54:97:72:D4:0C:FA:0D:D7:88:CD`
- **Valid Until**: Wednesday, 24 November, 2055

---

### **RELEASE BUILD (Production)**

> ⚠️ **Note**: Release SHA-1 certificate will be generated when you create a release keystore.
> 
> **To generate Release SHA-1:**
> 1. Create release keystore (if not exists)
> 2. Run: `keytool -list -v -keystore <path-to-release-keystore> -alias <alias-name>`
> 3. Or use: `./gradlew signingReport` after configuring release signing

**Release SHA-1**: `[To be added after release keystore creation]`

---

## 🔥 **Firebase Console Setup Steps**

### **Step 1: Add SHA-1 to Firebase Project**

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project
3. Click on **Project Settings** (⚙️ icon)
4. Scroll down to **Your apps** section
5. Click on your Android app (`com.rohit.emilockercustomer`)
6. Click **Add fingerprint** button
7. Add the following SHA-1:

   ```
   DEBUG SHA-1: 5A:AE:A1:B7:AC:24:C2:4D:EA:E3:97:55:8A:1D:3F:FD:3B:97:F6:E0
   ```

8. If you have release keystore, add release SHA-1 as well
9. Click **Save**

### **Step 2: Download google-services.json**

1. After adding SHA-1, download the updated `google-services.json`
2. Place it in: `android/app/google-services.json`
3. Make sure the file is in the correct location

---

## 📋 **Complete Certificate Information**

### **Debug Certificate (Current)**

| Property | Value |
|---------|-------|
| **SHA-1** | `5A:AE:A1:B7:AC:24:C2:4D:EA:E3:97:55:8A:1D:3F:FD:3B:97:F6:E0` |
| **SHA-256** | `BF:8F:9D:C7:D7:DD:91:17:98:E3:A8:1E:2F:F0:FE:C4:DE:40:04:0C:61:D6:54:97:72:D4:0C:FA:0D:D7:88:CD` |
| **MD5** | `06:9A:FF:01:68:82:DA:15:39:24:84:4A:3E:E0:1B:91` |
| **Keystore** | `C:\Users\brt7\.android\debug.keystore` |
| **Alias** | `AndroidDebugKey` |
| **Valid Until** | November 24, 2055 |

---

## 🛠️ **How to Generate SHA-1 Manually**

### **Method 1: Using Gradle (Recommended)**

```bash
cd android
./gradlew signingReport
```

Look for SHA-1 in the output under your app's variant.

### **Method 2: Using Keytool (For Release)**

```bash
keytool -list -v -keystore <path-to-keystore> -alias <alias-name>
```

**Example for Debug:**
```bash
keytool -list -v -keystore C:\Users\brt7\.android\debug.keystore -alias AndroidDebugKey
```

**Default Debug Keystore Password**: `android`

### **Method 3: Using Android Studio**

1. Open Android Studio
2. Go to **Gradle** panel (right side)
3. Navigate to: `YourApp > Tasks > android > signingReport`
4. Double-click to run
5. Check the output in **Run** panel

---

## ✅ **Verification Checklist**

- [ ] SHA-1 added to Firebase Console
- [ ] `google-services.json` downloaded
- [ ] `google-services.json` placed in `android/app/` directory
- [ ] App builds successfully
- [ ] FCM token received
- [ ] Push notifications working

---

## 🔄 **For Release Build**

When creating a release build, you'll need to:

1. **Create Release Keystore** (if not exists):
   ```bash
   keytool -genkey -v -keystore release.keystore -alias release -keyalg RSA -keysize 2048 -validity 10000
   ```

2. **Configure Release Signing** in `android/app/build.gradle.kts`:
   ```kotlin
   signingConfigs {
       release {
           storeFile = file("path/to/release.keystore")
           storePassword = "your-store-password"
           keyAlias = "release"
           keyPassword = "your-key-password"
       }
   }
   ```

3. **Generate Release SHA-1**:
   ```bash
   keytool -list -v -keystore release.keystore -alias release
   ```

4. **Add Release SHA-1** to Firebase Console

---

## 📝 **Important Notes**

1. **Debug vs Release**: 
   - Debug SHA-1 is for development/testing
   - Release SHA-1 is for production builds
   - Both should be added to Firebase Console

2. **Multiple SHA-1**: 
   - You can add multiple SHA-1 fingerprints in Firebase
   - This allows both debug and release builds to work

3. **SHA-1 Format**: 
   - Format: `XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX`
   - No spaces, only colons between pairs

4. **After Adding SHA-1**:
   - Download new `google-services.json`
   - Replace old file in `android/app/`
   - Rebuild the app

---

## 🚨 **Troubleshooting**

### **Issue: FCM not working after adding SHA-1**

**Solutions:**
1. Verify SHA-1 is correctly added (no extra spaces)
2. Download new `google-services.json` after adding SHA-1
3. Clean and rebuild: `flutter clean && flutter pub get`
4. Check Firebase Console for any errors

### **Issue: SHA-1 mismatch**

**Solutions:**
1. Verify you're using the correct keystore
2. Check if you're building with debug or release
3. Ensure SHA-1 matches the keystore used for signing

---

## 📞 **Quick Reference**

**Current Debug SHA-1** (Copy this):
```
5A:AE:A1:B7:AC:24:C2:4D:EA:E3:97:55:8A:1D:3F:FD:3B:97:F6:E0
```

**Firebase Console URL**:
```
https://console.firebase.google.com/
```

**Package Name**:
```
com.rohit.emilockercustomer
```

---

## 📅 **Document Information**

- **Generated On**: $(Get-Date -Format "dd-MM-yyyy HH:mm:ss")
- **Generated By**: Gradle signingReport
- **Project**: emilockercustomer
- **Status**: ✅ Debug SHA-1 Generated

---

**⚠️ Important**: Keep this document secure. Do not share SHA-1 certificates publicly if you're using them for production apps.

---

## 🔗 **Related Files**

- `android/app/build.gradle.kts` - App build configuration
- `android/app/google-services.json` - Firebase configuration (to be added)
- `FCM_IMPLEMENTATION_GUIDE.md` - FCM implementation guide
- `FCM_IMPLEMENTATION_SUMMARY.md` - Implementation summary

---

**End of Document**













