import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service to handle system-wide overlays that display over other apps
/// This creates a full-screen overlay that blocks phone usage
class SystemOverlayService {
  static const MethodChannel _channel = MethodChannel('com.rohit.emilockercustomer/system_overlay');
  static const String _prefsKey = 'overlay_lock_status';
  
  /// Check if overlay permission is granted
  static Future<bool> hasOverlayPermission() async {
    try {
      final result = await _channel.invokeMethod('checkOverlayPermission');
      debugPrint('[SystemOverlay] Overlay permission status: $result');
      return result as bool? ?? false;
    } catch (e) {
      debugPrint('[SystemOverlay] ❌ Error checking overlay permission: $e');
      return false;
    }
  }
  
  /// Request overlay permission from user
  static Future<void> requestOverlayPermission() async {
    try {
      await _channel.invokeMethod('requestOverlayPermission');
      debugPrint('[SystemOverlay] ✅ Overlay permission request sent');
    } catch (e) {
      debugPrint('[SystemOverlay] ❌ Error requesting overlay permission: $e');
    }
  }
  
  /// Show system-wide overlay (blocks phone usage)
  /// This is called when shopkeeper sends lock command via FCM
  static Future<void> showSystemOverlay({
    required String message,
    required String amount,
  }) async {
    try {
      debugPrint('[SystemOverlay] ========== SHOWING SYSTEM OVERLAY ==========');
      debugPrint('[SystemOverlay] Message: $message');
      debugPrint('[SystemOverlay] Amount: $amount');
      
      // Check permission first
      final hasPermission = await hasOverlayPermission();
      if (!hasPermission) {
        debugPrint('[SystemOverlay] ❌ No overlay permission - requesting permission');
        await requestOverlayPermission();
        return;
      }
      
      // CRITICAL: Store lock status locally (for boot recovery)
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefsKey, true);
      await prefs.setString('overlay_message', message);
      await prefs.setString('overlay_amount', amount);
      
      // Show overlay via native service
      // The native service will store lock status in its own SharedPreferences
      // This ensures BootReceiver can read it on boot
      await _channel.invokeMethod('showSystemOverlay', {
        'message': message,
        'amount': amount,
      });
      
      debugPrint('[SystemOverlay] ✅ System overlay displayed successfully');
      debugPrint('[SystemOverlay] 🔒 Phone is now locked - all touches are blocked');
    } catch (e) {
      debugPrint('[SystemOverlay] ❌ Error showing system overlay: $e');
    }
  }
  
  /// Hide system-wide overlay (unlock phone)
  /// This is called when shopkeeper sends unlock command via FCM
  static Future<void> hideSystemOverlay() async {
    try {
      debugPrint('[SystemOverlay] ========== HIDING SYSTEM OVERLAY ==========');
      
      // CRITICAL: Clear lock status locally FIRST
      // This prevents initialize() from showing overlay again
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefsKey, false);
      await prefs.remove('overlay_message');
      await prefs.remove('overlay_amount');
      
      debugPrint('[SystemOverlay] ✅ Flutter lock status cleared locally');
      
      // Hide overlay via native service
      // The native service will also clear its own SharedPreferences
      // Use try-catch to handle case where service might already be stopped
      try {
        await _channel.invokeMethod('hideSystemOverlay');
        debugPrint('[SystemOverlay] ✅ System overlay hide command sent to native service');
        debugPrint('[SystemOverlay] ✅ Native service will clear its SharedPreferences');
      } catch (e) {
        debugPrint('[SystemOverlay] ⚠️ Error sending hide command (service might already be stopped): $e');
        debugPrint('[SystemOverlay] ⚠️ But native SharedPreferences will be cleared by MainActivity');
        // This is OK - MainActivity will clear native SharedPreferences even if service is not running
      }
      
      debugPrint('[SystemOverlay] ✅ System overlay hidden successfully');
      debugPrint('[SystemOverlay] 🔓 Phone is now unlocked');
    } catch (e) {
      debugPrint('[SystemOverlay] ❌ Error hiding system overlay: $e');
    }
  }
  
  /// Check if system overlay is currently showing
  static Future<bool> isSystemOverlayShowing() async {
    try {
      final result = await _channel.invokeMethod('isSystemOverlayShowing');
      debugPrint('[SystemOverlay] System overlay showing status: $result');
      return result as bool? ?? false;
    } catch (e) {
      debugPrint('[SystemOverlay] ❌ Error checking system overlay status: $e');
      return false;
    }
  }
  
  /// Check if device should be locked (from local storage)
  static Future<bool> isDeviceLocked() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_prefsKey) ?? false;
    } catch (e) {
      debugPrint('[SystemOverlay] ❌ Error checking lock status: $e');
      return false;
    }
  }
  
  /// Initialize system overlay service and check permissions
  static Future<bool> initialize() async {
    try {
      debugPrint('[SystemOverlay] ========== INITIALIZING SYSTEM OVERLAY SERVICE ==========');
      
      final hasPermission = await hasOverlayPermission();
      debugPrint('[SystemOverlay] Initial permission status: $hasPermission');
      
      if (!hasPermission) {
        debugPrint('[SystemOverlay] ⚠️ Overlay permission not granted');
        debugPrint('[SystemOverlay] Call requestOverlayPermission() to request permission');
      } else {
        debugPrint('[SystemOverlay] ✅ Overlay permission already granted');
      }
      
      // CRITICAL: Check native SharedPreferences FIRST (highest priority)
      // Native state is the source of truth for overlay display
      bool shouldShowOverlay = false;
      bool nativeIsLocked = false;
      
      try {
        final nativeIsLockedResult = await _channel.invokeMethod<bool>('isNativeDeviceLocked');
        nativeIsLocked = nativeIsLockedResult ?? false;
        debugPrint('[SystemOverlay] Native device lock status: $nativeIsLocked');
        
        // CRITICAL: Native state has highest priority
        shouldShowOverlay = nativeIsLocked;
      } catch (e) {
        debugPrint('[SystemOverlay] ⚠️ Could not check native lock status: $e');
        // Fallback to Flutter SharedPreferences if native check fails
        final isLocked = await isDeviceLocked();
        shouldShowOverlay = isLocked;
        debugPrint('[SystemOverlay] Using Flutter SharedPreferences as fallback: $isLocked');
      }
      
      // Sync Flutter SharedPreferences with native state
      final prefs = await SharedPreferences.getInstance();
      final flutterIsLocked = prefs.getBool(_prefsKey) ?? false;
      
      if (nativeIsLocked != flutterIsLocked) {
        debugPrint('[SystemOverlay] ⚠️ MISMATCH: Native=$nativeIsLocked, Flutter=$flutterIsLocked');
        debugPrint('[SystemOverlay] Syncing Flutter to native state...');
        await prefs.setBool(_prefsKey, nativeIsLocked);
        if (!nativeIsLocked) {
          await prefs.remove('overlay_message');
          await prefs.remove('overlay_amount');
        }
        debugPrint('[SystemOverlay] ✅ Flutter SharedPreferences synced to native state');
      }
      
      // CRITICAL: Only show overlay if native says device is locked
      if (shouldShowOverlay && hasPermission) {
        debugPrint('[SystemOverlay] Device is locked - showing overlay');
        final message = prefs.getString('overlay_message') ?? 'Your EMI is overdue. Please contact shopkeeper.';
        final amount = prefs.getString('overlay_amount') ?? '0';
        
        // Add small delay to avoid race condition with unlock
        await Future.delayed(const Duration(milliseconds: 500));
        
        // Double-check native lock status before showing (might have been unlocked in the meantime)
        try {
          final stillLockedResult = await _channel.invokeMethod<bool>('isNativeDeviceLocked');
          final stillLocked = stillLockedResult ?? false;
          if (stillLocked) {
            await showSystemOverlay(message: message, amount: amount);
          } else {
            debugPrint('[SystemOverlay] Device was unlocked during initialization - not showing overlay');
          }
        } catch (e) {
          debugPrint('[SystemOverlay] ⚠️ Could not verify native lock status: $e');
          // If we can't verify, don't show overlay to be safe
          debugPrint('[SystemOverlay] Not showing overlay - cannot verify lock status');
        }
      } else if (shouldShowOverlay && !hasPermission) {
        debugPrint('[SystemOverlay] ⚠️ Device is locked but no overlay permission - requesting permission');
        await requestOverlayPermission();
      } else {
        debugPrint('[SystemOverlay] Device is not locked - overlay will not be shown');
      }
      
      debugPrint('[SystemOverlay] ========== SYSTEM OVERLAY SERVICE INITIALIZED ==========');
      return hasPermission;
    } catch (e) {
      debugPrint('[SystemOverlay] ❌ Error initializing system overlay service: $e');
      return false;
    }
  }
}
