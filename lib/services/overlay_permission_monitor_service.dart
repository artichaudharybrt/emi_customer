import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service to continuously monitor overlay permission
/// When permission is turned OFF, immediately:
/// - Detect it
/// - Bring app to foreground
/// - Show blocking Activity
/// - Force user to permission page
class OverlayPermissionMonitorService {
  static const MethodChannel _channel = MethodChannel('com.rohit.emilockercustomer/system_overlay');
  static const String _prefsKey = 'overlay_monitor_enabled';
  static const String _prefsLastPermissionState = 'overlay_permission_last_state';
  
  static Timer? _monitorTimer;
  static bool _isMonitoring = false;
  static bool _lastPermissionState = false;
  
  /// Start continuous monitoring of overlay permission
  static Future<void> startMonitoring() async {
    if (_isMonitoring) {
      debugPrint('[OverlayMonitor] Already monitoring');
      return;
    }
    
    debugPrint('[OverlayMonitor] ========== STARTING OVERLAY PERMISSION MONITOR ==========');
    
    // Load last known state
    final prefs = await SharedPreferences.getInstance();
    _lastPermissionState = prefs.getBool(_prefsLastPermissionState) ?? false;
    
    // Check initial state
    final hasPermission = await hasOverlayPermission();
    _lastPermissionState = hasPermission;
    await prefs.setBool(_prefsLastPermissionState, hasPermission);
    
    if (!hasPermission) {
      debugPrint('[OverlayMonitor] ⚠️ Initial check: Permission is OFF');
      // Don't trigger action on start - only on change
    } else {
      debugPrint('[OverlayMonitor] ✅ Initial check: Permission is ON');
    }
    
    _isMonitoring = true;
    
    // Monitor every 1 second (frequent checks for immediate detection)
    _monitorTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      await _checkPermissionState();
    });
    
    debugPrint('[OverlayMonitor] ✅ Monitoring started (checking every 1 second)');
  }
  
  /// Stop monitoring
  static void stopMonitoring() {
    if (!_isMonitoring) {
      return;
    }
    
    debugPrint('[OverlayMonitor] ========== STOPPING OVERLAY PERMISSION MONITOR ==========');
    
    _monitorTimer?.cancel();
    _monitorTimer = null;
    _isMonitoring = false;
    
    debugPrint('[OverlayMonitor] ✅ Monitoring stopped');
  }
  
  /// Check current permission state and trigger action if changed
  static Future<void> _checkPermissionState() async {
    try {
      final hasPermission = await hasOverlayPermission();
      
      // If permission changed from ON to OFF
      if (_lastPermissionState && !hasPermission) {
        debugPrint('[OverlayMonitor] 🚨🚨🚨 PERMISSION TURNED OFF! 🚨🚨🚨');
        debugPrint('[OverlayMonitor] Last state: ON → Current state: OFF');
        debugPrint('[OverlayMonitor] Triggering immediate action...');
        
        // Update state
        _lastPermissionState = false;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_prefsLastPermissionState, false);
        
        // CRITICAL: Trigger immediate action
        await _onPermissionTurnedOff();
      } else if (!_lastPermissionState && hasPermission) {
        // Permission turned back ON
        debugPrint('[OverlayMonitor] ✅ Permission turned back ON');
        _lastPermissionState = true;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_prefsLastPermissionState, true);
      }
    } catch (e) {
      debugPrint('[OverlayMonitor] ❌ Error checking permission: $e');
    }
  }
  
  /// Action to take when permission is turned OFF
  static Future<void> _onPermissionTurnedOff() async {
    try {
      debugPrint('[OverlayMonitor] ========== PERMISSION OFF ACTION ==========');
      
      // CRITICAL: Show blocking Activity FIRST (most important)
      debugPrint('[OverlayMonitor] Step 1: Showing blocking Activity IMMEDIATELY...');
      await _showBlockingActivity();
      
      // Step 2: Bring app to foreground (to ensure activity is visible)
      debugPrint('[OverlayMonitor] Step 2: Bringing app to foreground...');
      await _bringAppToForeground();
      
      // Step 3: Show blocking Activity again to ensure it's on top
      debugPrint('[OverlayMonitor] Step 3: Ensuring blocking Activity is on top...');
      await Future.delayed(const Duration(milliseconds: 200));
      await _showBlockingActivity();
      
      debugPrint('[OverlayMonitor] ✅ Action completed');
    } catch (e) {
      debugPrint('[OverlayMonitor] ❌ Error in permission OFF action: $e');
      // Retry after delay
      Future.delayed(const Duration(milliseconds: 500), () {
        _showBlockingActivity();
      });
    }
  }
  
  /// Bring app to foreground
  static Future<void> _bringAppToForeground() async {
    try {
      await _channel.invokeMethod('bringAppToForeground');
      debugPrint('[OverlayMonitor] ✅ App brought to foreground');
    } catch (e) {
      debugPrint('[OverlayMonitor] ❌ Error bringing app to foreground: $e');
    }
  }
  
  /// Show blocking Activity that forces user to enable permission
  static Future<void> _showBlockingActivity() async {
    try {
      await _channel.invokeMethod('showOverlayPermissionBlockingActivity');
      debugPrint('[OverlayMonitor] ✅ Blocking Activity shown');
    } catch (e) {
      debugPrint('[OverlayMonitor] ❌ Error showing blocking Activity: $e');
    }
  }
  
  /// Check if overlay permission is granted
  static Future<bool> hasOverlayPermission() async {
    try {
      final result = await _channel.invokeMethod<bool>('checkOverlayPermission');
      return result ?? false;
    } catch (e) {
      debugPrint('[OverlayMonitor] ❌ Error checking overlay permission: $e');
      return false;
    }
  }
  
  /// Check if monitoring is active
  static bool isMonitoring() => _isMonitoring;
}

