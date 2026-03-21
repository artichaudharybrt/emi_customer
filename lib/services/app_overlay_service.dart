import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/emi_service.dart';
import '../services/fcm_service.dart';
import '../services/auth_service.dart';
import '../services/native_back_button_service.dart';
import '../services/system_overlay_service.dart';
import '../models/emi_models.dart';

import '../main.dart'; // Import for navigatorKey

class AppOverlayService {
  static const String _overlayActiveKey = 'overlay_active';
  static const String _overlayEmiIdKey = 'overlay_emi_id';
  static OverlayEntry? _overlayEntry;
  static OverlayState? _overlayState;
  static bool _isShowing = false;
  static FCMService? _fcmService;
  static BuildContext? _storedContext;
  static Timer? _watchdogTimer;
  static bool _initialized = false;

  /// Initialize overlay service
  static void initialize(OverlayState overlayState, {FCMService? fcmService, BuildContext? context}) {
    debugPrint('[AppOverlay] ========== INITIALIZING OVERLAY SERVICE ==========');
    debugPrint('[AppOverlay] OverlayState: PROVIDED');
    debugPrint('[AppOverlay] FCMService: ${fcmService != null ? 'PROVIDED' : 'NULL'}');
    debugPrint('[AppOverlay] Context: ${context != null ? 'PROVIDED' : 'NULL'}');
    
    _overlayState = overlayState;
    _fcmService = fcmService;
    if (context != null) {
      _storedContext = context;
    }
    
    _initialized = true;
    
    // Setup FCM listeners if FCM service is available
    if (_fcmService != null) {
      debugPrint('[AppOverlay] Setting up FCM callbacks...');
      _fcmService!.onLockCommand = (data) {
        debugPrint('[AppOverlay] Lock command callback triggered');
        _handleFcmLockCommand(data);
      };
      
      _fcmService!.onUnlockCommand = (data) {
        debugPrint('[AppOverlay] Unlock command callback triggered');
        _handleFcmUnlockCommand(data);
      };
      debugPrint('[AppOverlay] ✅ FCM callbacks set up successfully');
    } else {
      debugPrint('[AppOverlay] ⚠️ FCM service is null, callbacks not set');
      debugPrint('[AppOverlay] ⚠️ Overlay will work using backend API sync only');
    }
    
    debugPrint('[AppOverlay] ========== OVERLAY SERVICE INITIALIZATION COMPLETE ==========');
  }

  /// Update FCM service (call when FCM service becomes available)
  static void updateFCMService(FCMService fcmService) {
    debugPrint('[AppOverlay] ========== UPDATING FCM SERVICE ==========');
    _fcmService = fcmService;
    
    if (_fcmService != null) {
      debugPrint('[AppOverlay] Setting up FCM callbacks...');
      _fcmService!.onLockCommand = (data) {
        debugPrint('[AppOverlay] Lock command callback triggered (updated)');
        _handleFcmLockCommand(data);
      };
      
      _fcmService!.onUnlockCommand = (data) {
        debugPrint('[AppOverlay] Unlock command callback triggered (updated)');
        _handleFcmUnlockCommand(data);
      };
      debugPrint('[AppOverlay] ✅ FCM callbacks set up successfully (updated)');
    }
  }
  
  /// Update stored context (call when navigating)
  static void updateContext(BuildContext? context) {
    if (context != null) {
      _storedContext = context;
      // Update overlay state if available
      try {
        _overlayState = Overlay.of(context);
      } catch (e) {
        debugPrint('[AppOverlay] Could not update overlay state: $e');
      }
    }
  }
  
  /// Get current context (from navigator key or stored context)
  static BuildContext? _getCurrentContext() {
    // Try to get context from navigator key
    final navigatorContext = navigatorKey.currentContext;
    if (navigatorContext != null) {
      return navigatorContext;
    }
    // Fallback to stored context
    return _storedContext;
  }
  
  /// Handle FCM lock command
  static Future<void> _handleFcmLockCommand(Map<String, dynamic> data) async {
    debugPrint('[AppOverlay] ========== FCM LOCK COMMAND RECEIVED ==========');
    debugPrint('[AppOverlay] Lock command data: $data');
    
    try {
      final emiId = data['emiId'] as String?;
      if (emiId == null) {
        debugPrint('[AppOverlay] ❌ ERROR: No EMI ID in lock command');
        return;
      }
      
      debugPrint('[AppOverlay] EMI ID: $emiId');
      
      // Store lock status in FCM service
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('device_locked', true);
      await prefs.setString('lock_emi_id', emiId);
      await prefs.setBool(_overlayActiveKey, true);
      await prefs.setString(_overlayEmiIdKey, emiId);
      
      debugPrint('[AppOverlay] ✅ Lock status stored');
      
      // Try to show overlay immediately if context is available
      // Wait a bit for app to initialize if coming from notification
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Try multiple times to get context (in case app is still loading)
      BuildContext? context;
      for (int i = 0; i < 5; i++) {
        context = _getCurrentContext();
        if (context != null && context.mounted) {
          break;
        }
        await Future.delayed(const Duration(milliseconds: 300));
      }
      
      if (context != null && context.mounted) {
        debugPrint('[AppOverlay] Context available, showing overlay immediately...');
        try {
          // Create EMI from FCM data
          final emi = _createEmiFromFcmData(data);
          await showOverlay(context, emi);
          debugPrint('[AppOverlay] ✅ Overlay shown successfully');
        } catch (e, stackTrace) {
          debugPrint('[AppOverlay] ❌ Error showing overlay: $e');
          debugPrint('[AppOverlay] Stack Trace: $stackTrace');
          debugPrint('[AppOverlay] Overlay will show on next app check');
        }
      } else {
        debugPrint('[AppOverlay] ⚠️ Context not available, overlay will show on next app check');
      }
    } catch (e, stackTrace) {
      debugPrint('[AppOverlay] ❌ EXCEPTION: Error handling FCM lock command: $e');
      debugPrint('[AppOverlay] Stack Trace: $stackTrace');
    }
  }
  
  /// Handle FCM unlock command
  static Future<void> _handleFcmUnlockCommand(Map<String, dynamic> data) async {
    debugPrint('[AppOverlay] ========== FCM UNLOCK COMMAND RECEIVED ==========');
    debugPrint('[AppOverlay] Unlock command data: $data');
    
    try {
      // CRITICAL: Clear ALL lock state FIRST, before hiding overlay
      // This ensures that even if hideOverlay fails, the state is cleared
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_overlayActiveKey, false);
      await prefs.remove(_overlayEmiIdKey);
      await prefs.setBool('device_locked', false);
      await prefs.remove('lock_emi_id');
      await prefs.remove('unlock_until');
      
      // Also clear SystemOverlayService keys
      await prefs.setBool('overlay_lock_status', false);
      await prefs.remove('overlay_message');
      await prefs.remove('overlay_amount');
      
      debugPrint('[AppOverlay] ✅ All Flutter SharedPreferences cleared');
      
      // Hide overlay immediately (this will also clear native SharedPreferences)
      debugPrint('[AppOverlay] Hiding overlay...');
      await hideOverlay(reason: 'Unlock command from admin');
      debugPrint('[AppOverlay] ✅ Overlay hidden');
      
      // CRITICAL: Ensure _isShowing is false and watchdog is stopped
      _isShowing = false;
      _stopWatchdogTimer();
      
      debugPrint('[AppOverlay] ✅ All lock state cleared');
      debugPrint('[AppOverlay] ✅ Watchdog stopped');
      debugPrint('[AppOverlay] Device unlocked via FCM');
    } catch (e, stackTrace) {
      debugPrint('[AppOverlay] ❌ EXCEPTION: Error handling FCM unlock command: $e');
      debugPrint('[AppOverlay] Stack Trace: $stackTrace');
    }
  }
  
  /// Create EMI model from FCM data (fallback)
  static EmiModel _createEmiFromFcmData(Map<String, dynamic> data) {
    debugPrint('[AppOverlay] Creating EMI model from FCM data');
    debugPrint('[AppOverlay] FCM Data: $data');
    
    // Parse overdue amount
    double overdueAmount = 0.0;
    if (data.containsKey('overdueAmount')) {
      final overdue = data['overdueAmount'];
      if (overdue is String) {
        overdueAmount = double.tryParse(overdue) ?? 0.0;
      } else if (overdue is num) {
        overdueAmount = overdue.toDouble();
      }
    }
    
    return EmiModel(
      id: data['emiId'] as String? ?? 'unknown',
      userId: data['userId'] as String? ?? '',
      userName: data['borrowerName'] as String? ?? data['userName'] as String? ?? 'Customer',
      userMobile: data['userMobile'] as String? ?? '',
      userEmail: data['userEmail'] as String? ?? '',
      principalAmount: (data['principalAmount'] as num?)?.toDouble() ?? overdueAmount * 0.8,
      interestPercentage: (data['interestPercentage'] as num?)?.toDouble() ?? 4.0,
      totalAmount: overdueAmount > 0 ? overdueAmount : 
                   (data['totalAmount'] as num?)?.toDouble() ?? 0.0,
      description: data['reason'] as String? ?? data['description'] as String? ?? 'EMI Payment Due',
      billNumber: data['loanNumber'] as String? ?? data['billNumber'] as String? ?? 'N/A',
      startDate: DateTime.now(),
      paymentScheduleType: null,
      dueDates: [DateTime.now()],
      paidInstallments: 0,
      totalInstallments: 1,
      status: 'active',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  /// Sync device lock status from backend API
  static Future<void> syncDeviceLockStatusFromBackend() async {
    try {
      debugPrint('[AppOverlay] ========== SYNCING DEVICE LOCK STATUS FROM BACKEND ==========');
      
      final authService = AuthService();
      final userProfileResponse = await authService.getUserProfile();
      final backendDeviceLocked = userProfileResponse.data.deviceLocked;
      
      debugPrint('[AppOverlay] Backend device lock status: $backendDeviceLocked');
      debugPrint('[AppOverlay] User: ${userProfileResponse.data.fullName}');
      debugPrint('[AppOverlay] Email: ${userProfileResponse.data.email}');
      
      // Update local status regardless of FCM service availability
      final prefs = await SharedPreferences.getInstance();
      
      if (backendDeviceLocked) {
        // Backend says device should be locked
        await prefs.setBool('device_locked', true);
        debugPrint('[AppOverlay] ✅ Local status updated to LOCKED (from backend)');
      } else {
        // Backend says device should be unlocked
        await prefs.setBool('device_locked', false);
        await prefs.remove('lock_emi_id');
        await prefs.remove('unlock_until');
        await prefs.setBool(_overlayActiveKey, false);
        await prefs.remove(_overlayEmiIdKey);
        debugPrint('[AppOverlay] ✅ Local status updated to UNLOCKED (from backend)');
        debugPrint('[AppOverlay] ✅ All lock-related preferences cleared');
        
        // Hide overlay if it's currently showing
        if (_isShowing) {
          debugPrint('[AppOverlay] 🚫 HIDING OVERLAY - Backend reports device unlocked');
          await hideOverlay(reason: 'Backend reports device unlocked');
        }
      }
      
      // Also update FCM service if available
      if (_fcmService != null) {
        final localDeviceLocked = await _fcmService!.isDeviceLocked();
        debugPrint('[AppOverlay] Local FCM device lock status: $localDeviceLocked');
        
        if (backendDeviceLocked != localDeviceLocked) {
          debugPrint('[AppOverlay] ⚠️ FCM STATUS MISMATCH DETECTED!');
          debugPrint('[AppOverlay] Backend says: ${backendDeviceLocked ? 'LOCKED' : 'UNLOCKED'}');
          debugPrint('[AppOverlay] FCM says: ${localDeviceLocked ? 'LOCKED' : 'UNLOCKED'}');
          debugPrint('[AppOverlay] FCM status will be synced with backend');
        } else {
          debugPrint('[AppOverlay] ✅ FCM and backend status are in sync (both ${backendDeviceLocked ? 'LOCKED' : 'UNLOCKED'})');
        }
      } else {
        debugPrint('[AppOverlay] ⚠️ FCM service not available, but local preferences updated from backend');
      }
      
      debugPrint('[AppOverlay] ========== DEVICE LOCK STATUS SYNC COMPLETE ==========');
    } catch (e, stackTrace) {
      debugPrint('[AppOverlay] ❌ Error syncing device lock status from backend: $e');
      debugPrint('[AppOverlay] Stack trace: $stackTrace');
    }
  }

  /// Check for due EMIs and show overlay
  static Future<bool> checkAndShowOverlay(BuildContext context) async {
    try {
      debugPrint('[AppOverlay] ========== CHECK AND SHOW OVERLAY ==========');
      
      // First sync with backend to ensure we have the latest status
      await syncDeviceLockStatusFromBackend();
      
      // Check device lock status from local preferences (synced with backend)
      final prefs = await SharedPreferences.getInstance();
      final isLocked = prefs.getBool('device_locked') ?? false;
      debugPrint('[AppOverlay] Device lock status (from backend sync): $isLocked');
      
      if (isLocked) {
        // Device is locked, show overlay
        final lockedEmiId = prefs.getString('lock_emi_id');
        debugPrint('[AppOverlay] Locked EMI ID: $lockedEmiId');
        
        if (lockedEmiId != null) {
          // Try to fetch EMI details
          try {
            final emiService = EmiService();
            final emis = await emiService.getMyEmis(page: 1, limit: 100);
            final emi = emis.data.firstWhere(
              (e) => e.id == lockedEmiId,
              orElse: () => _createEmiFromFcmData({'emiId': lockedEmiId}),
            );
            debugPrint('[AppOverlay] ✅ Showing overlay for locked device (EMI: ${emi.id})');
            await showOverlay(context, emi);
            return true;
          } catch (e) {
            debugPrint('[AppOverlay] Error fetching locked EMI: $e');
            // Show overlay with minimal data
            final dummyEmi = _createEmiFromFcmData({'emiId': lockedEmiId});
            debugPrint('[AppOverlay] ✅ Showing overlay for locked device (dummy EMI)');
            await showOverlay(context, dummyEmi);
            return true;
          }
        } else {
          // Device is locked but no EMI ID, check for due EMIs
          debugPrint('[AppOverlay] Device locked but no EMI ID, checking for due EMIs...');
          final emiService = EmiService();
          final dueEmis = await emiService.checkDueEmis();
          
          if (dueEmis.isNotEmpty) {
            debugPrint('[AppOverlay] ✅ Found ${dueEmis.length} due EMIs, showing overlay for locked device');
            await showOverlay(context, dueEmis.first);
            return true;
          } else {
            debugPrint('[AppOverlay] ⚠️ Device locked but no due EMIs found');
          }
        }
      } else {
        // Device is NOT locked according to backend - do not show overlay
        debugPrint('[AppOverlay] ❌ Device is NOT locked according to backend - overlay will NOT be shown');
        debugPrint('[AppOverlay] Even if there are due EMIs, overlay should not show when device is unlocked');
        
        // Ensure overlay is hidden if it's currently showing
        if (_isShowing) {
          debugPrint('[AppOverlay] 🚫 Hiding overlay because device is unlocked');
          await hideOverlay(reason: 'Device unlocked according to backend');
        }
        
        return false;
      }
      
      debugPrint('[AppOverlay] ❌ No overlay needed - device not locked or no EMIs to show');
      return false;
    } catch (e) {
      debugPrint('[AppOverlay] ❌ Error checking for overlay: $e');
      return false;
    }
  }

  /// Show overlay for EMI (both in-app and system-wide)
  static Future<void> showOverlay(BuildContext context, EmiModel emi) async {
    debugPrint('[AppOverlay] ========== SHOW OVERLAY CALLED ==========');
    debugPrint('[AppOverlay] Current state - isShowing: $_isShowing, overlayEntry: ${_overlayEntry != null}, overlayState: ${_overlayState != null}');
    
    if (_isShowing) {
      debugPrint('[AppOverlay] ⚠️ Overlay already showing, skipping');
      return;
    }
    
    try {
      // CRITICAL: Enable native back button blocking FIRST, before showing overlay
      await NativeBackButtonService.enableBackButtonBlocking();
      debugPrint('[AppOverlay] 🔒 NATIVE BACK BUTTON BLOCKING ENABLED (BEFORE OVERLAY)');
      
      // Start watchdog timer to ensure back button stays blocked
      _startWatchdogTimer();
      
      // Store overlay state
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_overlayActiveKey, true);
      await prefs.setString(_overlayEmiIdKey, emi.id);
      debugPrint('[AppOverlay] ✅ Overlay state stored');
      
      // Show system-wide overlay first (works even when app is closed)
      await SystemOverlayService.showSystemOverlay(
        message: emi.description,
        amount: emi.installmentAmount.toStringAsFixed(0),
      );
      
      // In-app overlay disabled - user requested removal
      // Only system-wide overlay will be shown
      debugPrint('[AppOverlay] ✅ System-wide overlay displayed');
      debugPrint('[AppOverlay] ⚠️ In-app overlay disabled (user requested removal)');
      
      // Don't show in-app overlay widget
      // _overlayEntry = null; // Keep null to prevent in-app overlay
      _isShowing = false; // Mark as not showing since we're not showing in-app overlay
    } catch (e, stackTrace) {
      debugPrint('[AppOverlay] ❌ EXCEPTION: Error showing overlay: $e');
      debugPrint('[AppOverlay] Stack Trace: $stackTrace');
      _isShowing = false;
      _overlayEntry = null;
    }
  }

  /// Hide overlay (both in-app and system-wide)
  /// This should ONLY be called from:
  /// 1. Payment success (after verification)
  /// 2. Unlock command from admin (FCM)
  /// 3. Extend payment command (FCM)
  static Future<void> hideOverlay({String? reason}) async {
    debugPrint('[AppOverlay] ========== HIDE OVERLAY CALLED ==========');
    debugPrint('[AppOverlay] Reason: ${reason ?? 'Not specified'}');
    debugPrint('[AppOverlay] Current state - isShowing: $_isShowing, overlayEntry: ${_overlayEntry != null}');
    
    try {
      // Hide system-wide overlay first
      await SystemOverlayService.hideSystemOverlay();
      debugPrint('[AppOverlay] 🌐 System-wide overlay hidden');
      
      if (!_isShowing) {
        debugPrint('[AppOverlay] ⚠️ In-app overlay not showing, but clearing state');
        // Still clear stored state and disable native blocking
        await NativeBackButtonService.disableBackButtonBlocking();
        SharedPreferences.getInstance().then((prefs) {
          prefs.setBool(_overlayActiveKey, false);
          prefs.remove(_overlayEmiIdKey);
        });
        return;
      }
      
      if (_overlayEntry == null) {
        debugPrint('[AppOverlay] ⚠️ Overlay entry is null, but isShowing is true');
        _isShowing = false;
        // Clear stored state and disable native blocking
        await NativeBackButtonService.disableBackButtonBlocking();
        SharedPreferences.getInstance().then((prefs) {
          prefs.setBool(_overlayActiveKey, false);
          prefs.remove(_overlayEmiIdKey);
        });
        return;
      }
      
      debugPrint('[AppOverlay] Removing in-app overlay entry...');
      _overlayEntry?.remove();
      _overlayEntry = null;
      _isShowing = false;
      
      // CRITICAL: Stop watchdog timer when overlay is hidden
      _stopWatchdogTimer();
      debugPrint('[AppOverlay] ✅ In-app overlay entry removed');
      
      // Disable native back button blocking
      await NativeBackButtonService.disableBackButtonBlocking();
      
      // Stop watchdog timer
      _stopWatchdogTimer();
      
      // Restore system UI
      _restoreSystemUI();
      
      debugPrint('[AppOverlay] 🔓 NATIVE BACK BUTTON BLOCKING DISABLED');
      debugPrint('[AppOverlay] 🌐 SYSTEM-WIDE OVERLAY HIDDEN');
      
      // Clear stored state
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_overlayActiveKey, false);
      await prefs.remove(_overlayEmiIdKey);
      debugPrint('[AppOverlay] ✅ Stored state cleared');
      
    } catch (e, stackTrace) {
      debugPrint('[AppOverlay] ❌ EXCEPTION: Error hiding overlay: $e');
      debugPrint('[AppOverlay] Stack Trace: $stackTrace');
      // Force clear state even if remove fails
      _isShowing = false;
      _overlayEntry = null;
      // Still try to disable native blocking and hide system overlay
      try {
        await NativeBackButtonService.disableBackButtonBlocking();
        await SystemOverlayService.hideSystemOverlay();
        _stopWatchdogTimer();
      } catch (nativeError) {
        debugPrint('[AppOverlay] ❌ Error in cleanup: $nativeError');
      }
    }
  }

  /// Restore system UI after overlay is hidden
  static void _restoreSystemUI() {
    try {
      SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.edgeToEdge,
        overlays: SystemUiOverlay.values,
      );
      debugPrint('[AppOverlay] ✅ System UI restored');
    } catch (e) {
      debugPrint('[AppOverlay] ⚠️ Error restoring system UI: $e');
    }
  }

  /// Check if overlay should be shown on app start
  static Future<bool> shouldShowOverlayOnStart() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_overlayActiveKey) ?? false;
  }
  
  /// Check if overlay is currently showing
  static Future<bool> isOverlayShowing() async {
    debugPrint('[AppOverlay] Checking if overlay is showing...');
    debugPrint('[AppOverlay] Runtime _isShowing: $_isShowing');
    
    // Check both runtime state and stored state
    if (_isShowing) {
      debugPrint('[AppOverlay] ✅ Overlay is showing (runtime state)');
      return true;
    }
    
    final prefs = await SharedPreferences.getInstance();
    final isActive = prefs.getBool(_overlayActiveKey) ?? false;
    debugPrint('[AppOverlay] Stored overlay active: $isActive');
    
    // Check if device is locked (from backend sync)
    final isLocked = prefs.getBool('device_locked') ?? false;
    debugPrint('[AppOverlay] Device locked status: $isLocked');
    
    if (isLocked || isActive) {
      debugPrint('[AppOverlay] ✅ Overlay should be showing (device locked or stored active)');
      return true;
    }
    
    debugPrint('[AppOverlay] ❌ Overlay should not be showing');
    return false;
  }


  /// Check for overlay on app start
  static Future<void> checkOnAppStart(BuildContext context) async {
    debugPrint('[AppOverlay] ========== CHECKING OVERLAY ON APP START ==========');
    debugPrint('[AppOverlay] FCM Service status: ${_fcmService != null ? 'AVAILABLE' : 'NULL'}');
    
    // Wait a bit for app to initialize
    await Future.delayed(const Duration(milliseconds: 500));
    
    if (!context.mounted) {
      debugPrint('[AppOverlay] Context not mounted, skipping check');
      return;
    }
    
    try {
      // First, check for pending background FCM commands
      final prefs = await SharedPreferences.getInstance();
      final lockPending = prefs.getBool('fcm_lock_pending') ?? false;
      final unlockPending = prefs.getBool('fcm_unlock_pending') ?? false;
      
      debugPrint('[AppOverlay] Lock pending: $lockPending, Unlock pending: $unlockPending');
      
      // CRITICAL: Process unlock command FIRST (highest priority)
      if (unlockPending) {
        debugPrint('[AppOverlay] ========== PROCESSING UNLOCK COMMAND (HIGHEST PRIORITY) ==========');
        await prefs.setBool('fcm_unlock_pending', false);
        
        // Hide overlay immediately
        await hideOverlay(reason: 'Unlock command from background');
        
        // Clear ALL lock-related flags
        await prefs.setBool('device_locked', false);
        await prefs.setBool(_overlayActiveKey, false);
        await prefs.remove('lock_emi_id');
        await prefs.remove(_overlayEmiIdKey);
        await prefs.remove('unlock_until');
        await prefs.remove('fcm_lock_emi_id');
        await prefs.remove('fcm_lock_data');
        
        debugPrint('[AppOverlay] ✅ All unlock flags cleared');
        debugPrint('[AppOverlay] ✅ Unlock processed - overlay will NOT show');
        return; // IMPORTANT: Return early, don't check for lock
      }
      
      // Only process lock if unlock is not pending
      if (lockPending) {
        debugPrint('[AppOverlay] Processing pending lock command from background');
        await prefs.setBool('fcm_lock_pending', false);
        final emiId = prefs.getString('fcm_lock_emi_id');
        if (emiId != null) {
          await prefs.setBool('device_locked', true);
          await prefs.setString('lock_emi_id', emiId);
          debugPrint('[AppOverlay] Lock status stored, showing overlay...');
          await checkAndShowOverlay(context);
          return;
        }
      }
      
      // Use the updated checkAndShowOverlay method which syncs with backend
      debugPrint('[AppOverlay] No pending commands, checking current overlay status...');
      await checkAndShowOverlay(context);
      
    } catch (e, stackTrace) {
      debugPrint('[AppOverlay] ❌ ERROR: Error checking overlay on app start: $e');
      debugPrint('[AppOverlay] Stack Trace: $stackTrace');
    }
  }
  
  /// Manually unlock device (e.g., after payment verification)
  static Future<void> unlockDevice() async {
    await hideOverlay(reason: 'Payment verified successfully');
    await _fcmService?.unlockDevice();
  }

  /// Manual sync for testing - call this to force sync with backend
  static Future<void> forceSyncWithBackend(BuildContext context) async {
    debugPrint('[AppOverlay] ========== MANUAL SYNC TRIGGERED ==========');
    await syncDeviceLockStatusFromBackend();
    await checkAndShowOverlay(context);
    debugPrint('[AppOverlay] ========== MANUAL SYNC COMPLETE ==========');
  }

  /// Force clear overlay state and show fresh overlay
  static Future<void> forceShowOverlay(BuildContext context, EmiModel emi) async {
    debugPrint('[AppOverlay] ========== FORCE SHOW OVERLAY CALLED ==========');
    debugPrint('[AppOverlay] Clearing existing state first...');
    
    // Force clear existing state
    if (_isShowing || _overlayEntry != null) {
      debugPrint('[AppOverlay] Force clearing existing overlay...');
      try {
        _overlayEntry?.remove();
      } catch (e) {
        debugPrint('[AppOverlay] Error removing existing overlay: $e');
      }
      _overlayEntry = null;
      _isShowing = false;
    }
    
    // Clear stored preferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_overlayActiveKey, false);
    await prefs.remove(_overlayEmiIdKey);
    
    // Hide any existing system overlay
    await SystemOverlayService.hideSystemOverlay();
    
    debugPrint('[AppOverlay] State cleared, now showing fresh overlay...');
    
    // Now show fresh overlay
    await showOverlay(context, emi);
  }

  /// Test system overlay functionality with detailed debugging
  static Future<void> testSystemOverlay() async {
    debugPrint('[AppOverlay] ========== TESTING SYSTEM OVERLAY ==========');
    
    try {
      // Check if permission is granted
      final hasPermission = await SystemOverlayService.hasOverlayPermission();
      debugPrint('[AppOverlay] System overlay permission: $hasPermission');
      
      if (!hasPermission) {
        debugPrint('[AppOverlay] ❌ No system overlay permission - requesting...');
        await SystemOverlayService.requestOverlayPermission();
        
        // Wait a bit and check again
        await Future.delayed(const Duration(seconds: 2));
        final hasPermissionAfter = await SystemOverlayService.hasOverlayPermission();
        debugPrint('[AppOverlay] Permission after request: $hasPermissionAfter');
        
        if (!hasPermissionAfter) {
          debugPrint('[AppOverlay] ⚠️ Permission still not granted - user needs to enable it manually');
          return;
        }
      }
      
      // Check if system overlay is already showing
      final isShowing = await SystemOverlayService.isSystemOverlayShowing();
      debugPrint('[AppOverlay] System overlay currently showing: $isShowing');
      
      if (isShowing) {
        debugPrint('[AppOverlay] Hiding existing system overlay first...');
        await SystemOverlayService.hideSystemOverlay();
        await Future.delayed(const Duration(milliseconds: 500));
      }
      
      // Show test overlay
      debugPrint('[AppOverlay] Showing test system overlay...');
      await SystemOverlayService.showSystemOverlay(
        message: 'This is a test of the system-wide overlay functionality. If you can see this over other apps, it\'s working!',
        amount: '1234',
      );
      
      // Check if it's now showing
      await Future.delayed(const Duration(milliseconds: 1000));
      final isShowingAfter = await SystemOverlayService.isSystemOverlayShowing();
      debugPrint('[AppOverlay] System overlay showing after display: $isShowingAfter');
      
      if (isShowingAfter) {
        debugPrint('[AppOverlay] ✅ Test system overlay displayed successfully');
        debugPrint('[AppOverlay] 🌐 Try switching to another app to see if overlay appears over it');
      } else {
        debugPrint('[AppOverlay] ❌ System overlay failed to display');
      }
      
    } catch (e, stackTrace) {
      debugPrint('[AppOverlay] ❌ Error in system overlay test: $e');
      debugPrint('[AppOverlay] Stack trace: $stackTrace');
    }
    
    debugPrint('[AppOverlay] ========== SYSTEM OVERLAY TEST COMPLETE ==========');
  }

  /// Show test overlay with dummy data (for testing)
  static Future<void> showTestOverlay(BuildContext context) async {
    if (_isShowing) return;
    
    try {
      // Create dummy EMI data for testing
      final dummyEmi = EmiModel(
        id: 'test_emi_123',
        userId: 'test_user',
        userName: 'Test User',
        userMobile: '9999999999',
        userEmail: 'test@example.com',
        principalAmount: 10000.0,
        interestPercentage: 4.0,
        totalAmount: 10400.0,
        description: 'Test EMI Product - Payment Due',
        billNumber: 'BILL-TEST-001',
        startDate: DateTime.now().subtract(const Duration(days: 30)),
        paymentScheduleType: '3',
        dueDates: [DateTime.now()],
        paidInstallments: 0,
        totalInstallments: 3,
        status: 'active',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      
      await showOverlay(context, dummyEmi);
    } catch (e) {
      debugPrint('[AppOverlay] Error showing test overlay: $e');
    }
  }
  
  /// Start watchdog timer to ensure back button blocking stays enabled
  static void _startWatchdogTimer() {
    _stopWatchdogTimer(); // Stop any existing timer
    
    debugPrint('[AppOverlay] 🐕 Starting overlay watchdog timer');
    
    _watchdogTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      if (_isShowing) {
        try {
          // Check if back button blocking is still enabled
          final isBlocked = await NativeBackButtonService.isBackButtonBlocked();
          if (!isBlocked) {
            debugPrint('[AppOverlay] 🚨 WATCHDOG: Back button blocking disabled! Re-enabling...');
            await NativeBackButtonService.enableBackButtonBlocking();
            debugPrint('[AppOverlay] ✅ WATCHDOG: Back button blocking re-enabled');
          }
          
          // Check if system overlay is still showing
          final isSystemOverlayShowing = await SystemOverlayService.isSystemOverlayShowing();
          if (!isSystemOverlayShowing) {
            // CRITICAL: Check if device is actually unlocked
            // If device is unlocked, this is expected behavior - stop watchdog
            final prefs = await SharedPreferences.getInstance();
            final isDeviceLocked = prefs.getBool('device_locked') ?? false;
            final overlayActive = prefs.getBool(_overlayActiveKey) ?? false;
            
            if (!isDeviceLocked && !overlayActive) {
              // Device is unlocked - this is expected, stop showing overlay
              debugPrint('[AppOverlay] ✅ WATCHDOG: Device is unlocked - overlay correctly removed');
              _isShowing = false;
              _stopWatchdogTimer();
            } else {
              // Device should be locked but overlay disappeared - this is an issue
              debugPrint('[AppOverlay] 🚨 WATCHDOG: System overlay disappeared but device is still locked!');
              debugPrint('[AppOverlay] 🚨 This should not happen - native watchdog should handle this');
              // Note: We don't re-show it here as it might cause issues
              // The native watchdog in SystemOverlayService should handle this
            }
          }
          
        } catch (e) {
          debugPrint('[AppOverlay] ⚠️ WATCHDOG: Error checking overlay state: $e');
        }
      } else {
        debugPrint('[AppOverlay] 🐕 WATCHDOG: Overlay not showing, stopping timer');
        _stopWatchdogTimer();
      }
    });
  }
  
  /// Stop watchdog timer
  static void _stopWatchdogTimer() {
    if (_watchdogTimer != null) {
      _watchdogTimer!.cancel();
      _watchdogTimer = null;
      debugPrint('[AppOverlay] 🐕 Overlay watchdog timer stopped');
    }
  }
}

