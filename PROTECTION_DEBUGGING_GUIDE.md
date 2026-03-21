# Protection Debugging Guide

## 🚨 Issue: Overlay Not Showing on App Info Click

You mentioned that accessibility service is enabled but overlay doesn't show when clicking "App info". Let's debug this step by step.

## 🔧 Debugging Steps

### Step 1: Test Basic Overlay Functionality
```bash
# Run debug app
flutter run lib/protection_debug_app.dart

# Or install APK and use debug screen
# In the debug screen, tap "Test Protection Overlay"
# This should show overlay immediately
```

**Expected Result**: Protection overlay should appear with blue styling and "Protection Test" message.

**If overlay doesn't appear**: There's an issue with overlay permission or SystemOverlayService.

### Step 2: Check Accessibility Service Status
```bash
# Check if service is actually running
adb shell settings get secure enabled_accessibility_services

# Should show: com.rohit.emilockercustomer/com.rohit.emilockercustomer.AppUsageMonitorService
```

### Step 3: Monitor Accessibility Events
```bash
# Monitor accessibility service logs
adb logcat | grep -E "(AppUsageMonitor|SystemOverlay)"

# Then try:
# 1. Long press Fasst Pay app icon
# 2. Click "App info"
# 3. Check if events are detected
```

**Expected Logs**:
```
AppUsageMonitorService: === ACCESSIBILITY EVENT ===
AppUsageMonitorService: Package: com.android.systemui
AppUsageMonitorService: Class: android.widget.PopupWindow
AppUsageMonitorService: 🔍 SYSTEM UI EVENT DETECTED - checking for app control options
AppUsageMonitorService: 🚨 DETECTED: App control options found!
```

### Step 4: Test Different Scenarios

#### Scenario A: Long Press App Icon
1. Long press Fasst Pay app icon
2. Look for context menu
3. Click "App info" or "Pause app"
4. Check logs for detection

#### Scenario B: Settings App
1. Open Settings > Apps
2. Find Fasst Pay app
3. Tap on it
4. Check if overlay appears

#### Scenario C: Manual Trigger
1. Use debug screen "Test Protection Overlay" button
2. This bypasses accessibility service
3. Tests overlay system directly

## 🐛 Common Issues and Solutions

### Issue 1: Accessibility Service Not Detecting Events
**Symptoms**: No logs in logcat when performing actions
**Solutions**:
```bash
# 1. Restart accessibility service
adb shell settings put secure enabled_accessibility_services ""
adb shell settings put secure enabled_accessibility_services com.rohit.emilockercustomer/com.rohit.emilockercustomer.AppUsageMonitorService

# 2. Check service permissions
adb shell dumpsys accessibility
```

### Issue 2: Overlay Permission Missing
**Symptoms**: Logs show detection but no overlay appears
**Solutions**:
```bash
# Check overlay permission
adb shell appops get com.rohit.emilockercustomer SYSTEM_ALERT_WINDOW

# Grant overlay permission
adb shell appops set com.rohit.emilockercustomer SYSTEM_ALERT_WINDOW allow
```

### Issue 3: Service Not Starting
**Symptoms**: SystemOverlayService logs missing
**Solutions**:
```kotlin
// Check if service is running
adb shell dumpsys activity services | grep SystemOverlayService
```

### Issue 4: Wrong Package Detection
**Symptoms**: Events detected but not for Fasst Pay
**Solutions**: The accessibility service now monitors ALL packages and looks for Fasst Pay text anywhere.

## 🧪 Enhanced Testing

### Test 1: Aggressive Detection Mode
I've updated the accessibility service to be more aggressive:
- Monitors ALL packages (not just system UI)
- Detects ANY mention of Fasst Pay text
- Shows overlay even if Fasst Pay context is unclear

### Test 2: Multiple Event Types
The service now monitors:
- `typeViewClicked` - Button/menu clicks
- `typeViewSelected` - Item selections
- `typeWindowStateChanged` - Window changes
- `typeViewTextChanged` - Text changes
- `typeWindowContentChanged` - Content changes

### Test 3: Comprehensive Text Search
Searches for:
- "Fasst Pay", "fasst pay", "emilockercustomer"
- "App info", "Pause app", "Force stop", "Uninstall"
- "Storage", "Permissions", "Battery", "Data usage"

## 🔍 Advanced Debugging

### Enable Verbose Logging
```bash
# Enable all accessibility logs
adb shell setprop log.tag.AccessibilityManagerService VERBOSE
adb shell setprop log.tag.AccessibilityService VERBOSE

# Monitor specific logs
adb logcat -s AppUsageMonitorService SystemOverlayService MainActivity
```

### Check Accessibility Service Configuration
```bash
# Dump accessibility service info
adb shell dumpsys accessibility | grep -A 20 "Fasst Pay"
```

### Monitor System UI Events
```bash
# Monitor system UI specifically
adb logcat | grep -E "(systemui|PopupWindow|AlertDialog)"
```

## 🎯 Step-by-Step Testing Protocol

### Phase 1: Basic Functionality
1. ✅ Install APK
2. ✅ Run debug app: `flutter run lib/protection_debug_app.dart`
3. ✅ Test overlay: Tap "Test Protection Overlay"
4. ✅ Verify overlay appears and can be dismissed with back button

### Phase 2: Accessibility Service
1. ✅ Enable accessibility service in settings
2. ✅ Check status in debug app
3. ✅ Monitor logs: `adb logcat | grep AppUsageMonitor`
4. ✅ Perform test actions and check for event detection

### Phase 3: Real-World Testing
1. ✅ Long press Fasst Pay app icon
2. ✅ Click "App info" - should trigger overlay
3. ✅ Click "Pause app" - should trigger overlay
4. ✅ Open Settings > Apps > Fasst Pay - should trigger overlay

### Phase 4: Edge Cases
1. ✅ Test on different launchers
2. ✅ Test with different Android versions
3. ✅ Test with OEM customizations

## 🚀 Quick Fix Attempts

### Fix 1: More Aggressive Detection
```kotlin
// Now detects ANY app control text, even without Fasst Pay context
if (appInfoNodes.isNotEmpty()) {
    Log.e(TAG, "🚨 App control options detected - showing protection as precaution")
    showProtectionOverlay("App Control Detected", "App modification attempts are monitored")
}
```

### Fix 2: Monitor All Packages
```xml
<!-- Removed packageNames restriction - now monitors everything -->
<accessibility-service xmlns:android="http://schemas.android.com/apk/res/android"
    android:accessibilityEventTypes="typeViewClicked|typeViewSelected|typeWindowStateChanged|typeViewTextChanged|typeWindowContentChanged"
    android:canRetrieveWindowContent="true" />
```

### Fix 3: Enhanced Event Types
Added more event types to catch different interaction patterns.

## 📱 Testing Commands

```bash
# 1. Install and test basic overlay
flutter run lib/protection_debug_app.dart

# 2. Monitor logs while testing
adb logcat | grep -E "(AppUsageMonitor|SystemOverlay|MainActivity)"

# 3. Check accessibility service status
adb shell settings get secure enabled_accessibility_services

# 4. Test overlay permission
adb shell appops get com.rohit.emilockercustomer SYSTEM_ALERT_WINDOW

# 5. Force restart accessibility service
adb shell settings put secure enabled_accessibility_services ""
adb shell settings put secure enabled_accessibility_services com.rohit.emilockercustomer/com.rohit.emilockercustomer.AppUsageMonitorService
```

## 🎉 Expected Results

After implementing these fixes:

1. **Basic Overlay Test**: Should work immediately
2. **Accessibility Detection**: Should see logs when interacting with any app
3. **Fasst Pay Protection**: Should trigger overlay when accessing Fasst Pay app controls
4. **Back Button**: Should dismiss protection overlay
5. **Comprehensive Coverage**: Should catch most app control attempts

## 🔄 Next Steps

1. **Test basic overlay first** using debug app
2. **Check accessibility logs** to see if events are detected
3. **Try different interaction methods** (long press, settings app, etc.)
4. **Report specific logs** if still not working
5. **Test on different devices/Android versions** if needed

The enhanced system should be much more reliable at detecting app control attempts and showing protection overlays.