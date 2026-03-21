# Fasst Pay Overlay Test Guide

## 🚨 Problem
Overlay Settings > Apps mein Fasst Pay app par click karte hi show nahi ho raha.

## ✅ Solution Implemented

### Changes Made:
1. **Immediate Click Detection**: Ab jab bhi user Settings > Apps mein Fasst Pay app par click karega, overlay immediately show hoga
2. **Package Name Detection**: Ab sirf text hi nahi, package name "com.rohit.emilockercustomer" bhi detect hota hai
3. **Better Event Monitoring**: TYPE_WINDOW_CONTENT_CHANGED event bhi monitor hota hai
4. **Enhanced Logging**: Ab detailed logs aayenge accessibility service ke

## 🔧 Testing Steps

### Step 1: Verify Accessibility Service is Enabled

**Option A: Via App**
1. App mein Protection Debug Screen kholo
2. Check karo ki "Accessibility Service Enabled" green dikh raha hai
3. Agar red hai, to "Open Accessibility Settings" button par click karo
4. Settings mein "Fasst Pay Protection Service" enable karo

**Option B: Via ADB**
```bash
# Check if service is enabled
adb shell settings get secure enabled_accessibility_services

# Should show: com.rohit.emilockercustomer/com.rohit.emilockercustomer.AppUsageMonitorService
```

### Step 2: Check Logs

```bash
# Monitor accessibility service logs
adb logcat | grep -E "(AppUsageMonitor|MainActivity)"

# You should see:
# AppUsageMonitorService: ========== ✅ APP USAGE MONITOR SERVICE CONNECTED ==========
```

### Step 3: Test Overlay

**Method 1: Direct Test (Recommended)**
1. App mein Protection Debug Screen kholo
2. "Test Protection Overlay" button par click karo
3. Overlay immediately show hona chahiye

**Method 2: Settings Test**
1. Settings > Apps kholo
2. Fasst Pay app dhundho
3. Fasst Pay app par click karo
4. **Overlay immediately show hona chahiye!**

### Step 4: Verify Detection

Jab aap Settings > Apps mein Fasst Pay par click karte ho, logs mein ye dikhna chahiye:

```
AppUsageMonitorService: 🔍 SETTINGS APP EVENT DETECTED
AppUsageMonitorService: 🔄 Starting continuous settings monitoring for Fasst Pay
AppUsageMonitorService: 🚨 CRITICAL: Fasst Pay detected in settings!
AppUsageMonitorService: 🚨 BLOCKING: Showing protection overlay!
```

## 🐛 Troubleshooting

### Issue 1: No Logs Appearing
**Problem**: Accessibility service enabled nahi hai

**Solution**:
1. Settings > Accessibility kholo
2. "Fasst Pay Protection Service" dhundho
3. Toggle ON karo
4. Dialog mein "OK" click karo

### Issue 2: Logs Appear But No Overlay
**Problem**: Overlay permission missing

**Solution**:
```bash
# Check overlay permission
adb shell appops get com.rohit.emilockercustomer SYSTEM_ALERT_WINDOW

# Grant overlay permission
adb shell appops set com.rohit.emilockercustomer SYSTEM_ALERT_WINDOW allow
```

### Issue 3: Service Not Detecting Clicks
**Problem**: Service restart karna padega

**Solution**:
```bash
# Restart accessibility service
adb shell settings put secure enabled_accessibility_services ""
adb shell settings put secure enabled_accessibility_services com.rohit.emilockercustomer/com.rohit.emilockercustomer.AppUsageMonitorService
```

## 📱 New Features Added

1. **checkForFasstPayAppClick()**: Directly Fasst Pay app click detect karta hai
2. **checkForFasstPayPackage()**: Package name se bhi detect karta hai
3. **Enhanced Text Search**: Ab "Fasst Pay", "fasst pay", "FasstPay" sab detect hota hai
4. **Faster Monitoring**: Settings app monitoring ab 200ms interval par hai (pehle 300ms)

## ✅ Expected Behavior

1. **Settings > Apps mein Fasst Pay click** → Overlay immediately show
2. **Fasst Pay app info screen open** → Overlay show
3. **Uninstall/Clear Data button click** → Overlay show
4. **Kisi bhi jagah Fasst Pay detect** → Overlay show

## 🔍 Debug Commands

### Check Service Status
```bash
adb shell dumpsys accessibility | grep -A 20 "Fasst Pay"
```

### Monitor All Events
```bash
adb logcat | grep "AppUsageMonitorService"
```

### Test Direct Overlay
App mein Protection Debug Screen > "Test Protection Overlay"

## 📝 Notes

- Accessibility service enable karna **zaroori** hai
- Overlay permission bhi **zaroori** hai
- Service enable hone ke baad app restart karo
- Logs check karke verify karo ki service connected hai
