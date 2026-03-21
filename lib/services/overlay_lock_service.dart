import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'system_overlay_service.dart';
import 'app_overlay_service.dart';

/// Simplified overlay lock service
/// Handles lock/unlock commands from FCM and shows/hides overlay
class OverlayLockService {
  static const String _lockStatusKey = 'device_locked';
  static const String _lockMessageKey = 'lock_message';
  static const String _lockAmountKey = 'lock_amount';
  
  /// Initialize overlay lock service
  static Future<void> initialize() async {
    try {
      debugPrint('[OverlayLock] ========== INITIALIZING OVERLAY LOCK SERVICE ==========');
      
      // Initialize system overlay service
      await SystemOverlayService.initialize();
      
      // Check if device should be locked
      final isLocked = await isDeviceLocked();
      if (isLocked) {
        debugPrint('[OverlayLock] Device is locked - overlay should be showing');
      } else {
        debugPrint('[OverlayLock] Device is not locked');
      }
      
      debugPrint('[OverlayLock] ========== OVERLAY LOCK SERVICE INITIALIZED ==========');
    } catch (e) {
      debugPrint('[OverlayLock] ❌ Error initializing overlay lock service: $e');
    }
  }
  
  /// Lock device - Show overlay (called from FCM lock command)
  static Future<void> lockDevice({
    required String message,
    required String amount,
  }) async {
    try {
      debugPrint('[OverlayLock] ========== LOCKING DEVICE ==========');
      debugPrint('[OverlayLock] Message: $message');
      debugPrint('[OverlayLock] Amount: $amount');
      
      // Store lock status
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_lockStatusKey, true);
      await prefs.setString(_lockMessageKey, message);
      await prefs.setString(_lockAmountKey, amount);
      
      // Show system overlay
      await SystemOverlayService.showSystemOverlay(
        message: message,
        amount: amount,
      );
      
      debugPrint('[OverlayLock] ✅ Device locked successfully');
      debugPrint('[OverlayLock] 🔒 Phone is now blocked');
    } catch (e) {
      debugPrint('[OverlayLock] ❌ Error locking device: $e');
    }
  }
  
  /// Unlock device - Hide overlay (called from FCM unlock command)
  static Future<void> unlockDevice() async {
    try {
      debugPrint('[OverlayLock] ========== UNLOCKING DEVICE ==========');
      
      // CRITICAL: Clear ALL lock status keys from ALL services
      final prefs = await SharedPreferences.getInstance();
      
      // Clear OverlayLockService keys
      await prefs.setBool(_lockStatusKey, false);
      await prefs.remove(_lockMessageKey);
      await prefs.remove(_lockAmountKey);
      
      // Clear SystemOverlayService keys
      await prefs.setBool('overlay_lock_status', false);
      await prefs.remove('overlay_message');
      await prefs.remove('overlay_amount');
      
      // Clear AppOverlay keys
      await prefs.setBool('device_locked', false);
      await prefs.remove('lock_emi_id');
      await prefs.remove('unlock_until');
      await prefs.setBool('overlay_active', false);
      await prefs.remove('overlay_emi_id');
      
      debugPrint('[OverlayLock] ✅ All Flutter lock status keys cleared');
      
      // CRITICAL: Hide system overlay FIRST (this will also clear native SharedPreferences)
      await SystemOverlayService.hideSystemOverlay();
      debugPrint('[OverlayLock] ✅ System overlay hidden (native SharedPreferences cleared)');
      
      // CRITICAL: Also hide AppOverlay if it's showing
      try {
        await AppOverlayService.hideOverlay(reason: 'Unlock command from FCM');
        debugPrint('[OverlayLock] ✅ AppOverlay hidden');
      } catch (e) {
        debugPrint('[OverlayLock] ⚠️ Error hiding AppOverlay: $e');
        // Continue - native overlay is already hidden
      }
      
      debugPrint('[OverlayLock] ✅ Device unlocked successfully');
      debugPrint('[OverlayLock] 🔓 Phone is now unblocked');
    } catch (e) {
      debugPrint('[OverlayLock] ❌ Error unlocking device: $e');
    }
  }
  
  /// Check if device is locked
  static Future<bool> isDeviceLocked() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_lockStatusKey) ?? false;
    } catch (e) {
      debugPrint('[OverlayLock] ❌ Error checking lock status: $e');
      return false;
    }
  }
  
  /// Get lock message
  static Future<String?> getLockMessage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_lockMessageKey);
    } catch (e) {
      debugPrint('[OverlayLock] ❌ Error getting lock message: $e');
      return null;
    }
  }
  
  /// Get lock amount
  static Future<String?> getLockAmount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_lockAmountKey);
    } catch (e) {
      debugPrint('[OverlayLock] ❌ Error getting lock amount: $e');
      return null;
    }
  }
}


