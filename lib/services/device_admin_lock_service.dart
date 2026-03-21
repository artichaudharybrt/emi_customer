import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service to handle Device Admin lock functionality
/// Features:
/// - Device lock using DevicePolicyManager.lockNow()
/// - Blocking Activity when screen unlocks
/// - Watchdog service for continuous lock enforcement
/// - Unlock flow when EMI is paid
class DeviceAdminLockService {
  static const MethodChannel _channel = MethodChannel('device_control');
  static const String _prefsKey = 'device_admin_lock_enabled';
  static const String _prefsLockStatus = 'device_admin_lock_status';
  static const String _prefsEmiOverdue = 'emi_overdue_status';
  
  /// Check if Device Admin is active
  static Future<bool> isDeviceAdminActive() async {
    try {
      final result = await _channel.invokeMethod<bool>('isAdminActive');
      return result ?? false;
    } catch (e) {
      debugPrint('[DeviceAdminLock] ❌ Error checking device admin: $e');
      return false;
    }
  }
  
  /// Request Device Admin permission
  static Future<void> requestDeviceAdmin() async {
    try {
      await _channel.invokeMethod('requestAdmin');
      debugPrint('[DeviceAdminLock] ✅ Device admin request sent');
    } catch (e) {
      debugPrint('[DeviceAdminLock] ❌ Error requesting device admin: $e');
    }
  }
  
  /// Lock device immediately using DevicePolicyManager.lockNow()
  /// This locks the screen instantly
  static Future<void> lockDevice({
    String? message,
    String? amount,
  }) async {
    try {
      debugPrint('[DeviceAdminLock] ========== LOCKING DEVICE ==========');
      
      // Check if device admin is active
      final isActive = await isDeviceAdminActive();
      if (!isActive) {
        debugPrint('[DeviceAdminLock] ❌ Device admin not active - cannot lock');
        throw Exception('Device admin permission not granted');
      }
      
      // Save lock status (both Flutter and native SharedPreferences)
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefsLockStatus, true);
      await prefs.setBool(_prefsEmiOverdue, true);
      
      // Save lock message and amount for blocking activity
      if (message != null) {
        await prefs.setString('lock_message', message);
      }
      if (amount != null) {
        await prefs.setString('lock_amount', amount);
      }
      
      // Save lock info to native SharedPreferences (for USER_PRESENT receiver)
      // This is done via showBlockingActivity which saves to native prefs
      if (message != null && amount != null) {
        await showBlockingActivity(message: message, amount: amount);
      }
      
      // Lock device using DevicePolicyManager.lockNow()
      await _channel.invokeMethod('lockNow');
      
      debugPrint('[DeviceAdminLock] ✅ Device locked successfully');
      
      // Start watchdog to ensure lock stays active
      await startWatchdog();
      
    } catch (e) {
      debugPrint('[DeviceAdminLock] ❌ Error locking device: $e');
      rethrow;
    }
  }
  
  /// Unlock device (stop lock enforcement)
  static Future<void> unlockDevice() async {
    try {
      debugPrint('[DeviceAdminLock] ========== UNLOCKING DEVICE ==========');
      
      // Stop watchdog first
      await stopWatchdog();
      
      // Clear lock status
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefsLockStatus, false);
      await prefs.setBool(_prefsEmiOverdue, false);
      
      // Hide blocking activity
      await _channel.invokeMethod('hideBlockingActivity');
      
      debugPrint('[DeviceAdminLock] ✅ Device unlocked successfully');
      
    } catch (e) {
      debugPrint('[DeviceAdminLock] ❌ Error unlocking device: $e');
      rethrow;
    }
  }
  
  /// Check if device is currently locked
  static Future<bool> isDeviceLocked() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_prefsLockStatus) ?? false;
    } catch (e) {
      debugPrint('[DeviceAdminLock] ❌ Error checking lock status: $e');
      return false;
    }
  }
  
  /// Check if EMI is overdue
  static Future<bool> isEmiOverdue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_prefsEmiOverdue) ?? false;
    } catch (e) {
      debugPrint('[DeviceAdminLock] ❌ Error checking EMI status: $e');
      return false;
    }
  }
  
  /// Set EMI overdue status (called when backend detects overdue)
  static Future<void> setEmiOverdue(bool overdue, {String? message, String? amount}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefsEmiOverdue, overdue);
      
      if (overdue) {
        debugPrint('[DeviceAdminLock] EMI marked as overdue - will trigger lock');
        // Auto-lock if device admin is active
        final isActive = await isDeviceAdminActive();
        if (isActive) {
          await lockDevice(
            message: message ?? 'Your EMI is overdue. Please contact shopkeeper.',
            amount: amount ?? '0',
          );
        }
      } else {
        debugPrint('[DeviceAdminLock] EMI marked as paid - will unlock');
        await unlockDevice();
      }
    } catch (e) {
      debugPrint('[DeviceAdminLock] ❌ Error setting EMI status: $e');
    }
  }
  
  /// Start watchdog service that continuously enforces lock
  /// Checks every 2 seconds and re-locks if needed
  static Timer? _watchdogTimer;
  
  static Future<void> startWatchdog() async {
    if (_watchdogTimer != null) {
      debugPrint('[DeviceAdminLock] Watchdog already running');
      return;
    }
    
    debugPrint('[DeviceAdminLock] ========== STARTING WATCHDOG ==========');
    
    _watchdogTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      await _watchdogCheck();
    });
    
    debugPrint('[DeviceAdminLock] ✅ Watchdog started (checking every 2 seconds)');
  }
  
  /// Stop watchdog service
  static void stopWatchdog() {
    if (_watchdogTimer == null) {
      return;
    }
    
    debugPrint('[DeviceAdminLock] ========== STOPPING WATCHDOG ==========');
    
    _watchdogTimer?.cancel();
    _watchdogTimer = null;
    
    debugPrint('[DeviceAdminLock] ✅ Watchdog stopped');
  }
  
  /// Watchdog check - ensures lock is enforced
  static Future<void> _watchdogCheck() async {
    try {
      final isLocked = await isDeviceLocked();
      final isOverdue = await isEmiOverdue();
      
      if (isOverdue && isLocked) {
        // Device should be locked - ensure it stays locked
        final isActive = await isDeviceAdminActive();
        if (isActive) {
          // Re-lock if needed (lockNow is idempotent - safe to call multiple times)
          await _channel.invokeMethod('lockNow');
          debugPrint('[DeviceAdminLock] 🐕 Watchdog: Device re-locked');
        }
      } else if (!isOverdue && isLocked) {
        // EMI is paid but device is still locked - unlock it
        debugPrint('[DeviceAdminLock] 🐕 Watchdog: EMI paid, unlocking device');
        await unlockDevice();
      }
    } catch (e) {
      debugPrint('[DeviceAdminLock] ❌ Watchdog error: $e');
    }
  }
  
  /// Show blocking Activity (called when screen unlocks)
  static Future<void> showBlockingActivity({
    required String message,
    required String amount,
  }) async {
    try {
      await _channel.invokeMethod('showBlockingActivity', {
        'message': message,
        'amount': amount,
      });
      debugPrint('[DeviceAdminLock] ✅ Blocking Activity shown');
    } catch (e) {
      debugPrint('[DeviceAdminLock] ❌ Error showing blocking Activity: $e');
    }
  }
}

