import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../views/widgets/emi_overlay_widget.dart';
import '../services/emi_service.dart';
import '../services/fcm_service.dart';
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

  /// Initialize overlay service
  static void initialize(OverlayState overlayState, {FCMService? fcmService, BuildContext? context}) {
    _overlayState = overlayState;
    _fcmService = fcmService;
    if (context != null) {
      _storedContext = context;
    }
    
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
      debugPrint('[AppOverlay] ✅ FCM callbacks set up');
    } else {
      debugPrint('[AppOverlay] ⚠️ FCM service is null, callbacks not set');
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
      // Hide overlay immediately
      debugPrint('[AppOverlay] Hiding overlay...');
      hideOverlay(reason: 'Unlock command from admin');
      debugPrint('[AppOverlay] ✅ Overlay hidden');
      
      // Clear stored state
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_overlayActiveKey, false);
      await prefs.remove(_overlayEmiIdKey);
      await prefs.setBool('device_locked', false);
      await prefs.remove('lock_emi_id');
      await prefs.remove('unlock_until');
      
      debugPrint('[AppOverlay] ✅ All lock state cleared');
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

  /// Check for due EMIs and show overlay
  static Future<bool> checkAndShowOverlay(BuildContext context) async {
    try {
      // First check FCM lock status
      if (_fcmService != null) {
        final isLocked = await _fcmService!.isDeviceLocked();
        if (isLocked) {
          final lockedEmiId = await _fcmService!.getLockedEmiId();
          if (lockedEmiId != null) {
            // Try to fetch EMI details
            try {
              final emiService = EmiService();
              final emis = await emiService.getMyEmis(page: 1, limit: 100);
              final emi = emis.data.firstWhere(
                (e) => e.id == lockedEmiId,
                orElse: () => _createEmiFromFcmData({'emiId': lockedEmiId}),
              );
              await showOverlay(context, emi);
              return true;
            } catch (e) {
              debugPrint('[AppOverlay] Error fetching locked EMI: $e');
              // Show overlay with minimal data
              final dummyEmi = _createEmiFromFcmData({'emiId': lockedEmiId});
              await showOverlay(context, dummyEmi);
              return true;
            }
          }
        }
      }
      
      // Fallback: Check for due EMIs from backend
      final emiService = EmiService();
      final dueEmis = await emiService.checkDueEmis();
      
      if (dueEmis.isNotEmpty) {
        // Show overlay for first due EMI
        await showOverlay(context, dueEmis.first);
        return true;
      }
      
      return false;
    } catch (e) {
      debugPrint('[AppOverlay] Error checking for due EMIs: $e');
      return false;
    }
  }

  /// Show overlay for EMI
  static Future<void> showOverlay(BuildContext context, EmiModel emi) async {
    debugPrint('[AppOverlay] ========== SHOW OVERLAY CALLED ==========');
    debugPrint('[AppOverlay] Current state - isShowing: $_isShowing, overlayEntry: ${_overlayEntry != null}, overlayState: ${_overlayState != null}');
    
    if (_isShowing) {
      debugPrint('[AppOverlay] ⚠️ Overlay already showing, skipping');
      return;
    }
    
    try {
      // Store overlay state
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_overlayActiveKey, true);
      await prefs.setString(_overlayEmiIdKey, emi.id);
      debugPrint('[AppOverlay] ✅ Overlay state stored');
      
      final emiData = emi.toMap();
      
      _overlayEntry = OverlayEntry(
        maintainState: true, // Keep overlay state
        opaque: true, // Make overlay opaque
        builder: (context) {
          // Wrap in Navigator to completely block back button
          return Navigator(
            onPopPage: (route, result) {
              // NEVER allow pop - overlay cannot be dismissed by back button
              debugPrint('[AppOverlay] Navigator pop attempted - BLOCKED');
              return false; // Prevent navigation
            },
            pages: [
              MaterialPage(
                child: EmiOverlayWidget(
                  emiData: emiData,
                  onPayNow: () {
                    // Don't hide overlay here - let payment verification handle it
                    // Navigate to locker screen to show EMI details
                    // User can navigate to payment from there
                    try {
                      Navigator.of(context).pushNamedAndRemoveUntil(
                        '/',
                        (route) => false,
                      );
                    } catch (e) {
                      print('Navigation error: $e');
                    }
                  },
                  // onDismiss removed - overlay cannot be dismissed manually
                  onDismiss: null,
                ),
              ),
            ],
          );
        },
      );
      
      debugPrint('[AppOverlay] Overlay entry created, inserting into overlay state...');
      if (_overlayState != null) {
        _overlayState!.insert(_overlayEntry!);
        _isShowing = true;
        debugPrint('[AppOverlay] ✅ Overlay inserted and showing');
      } else {
        debugPrint('[AppOverlay] ❌ ERROR: Overlay state is null!');
        _overlayEntry = null;
      }
    } catch (e, stackTrace) {
      debugPrint('[AppOverlay] ❌ EXCEPTION: Error showing overlay: $e');
      debugPrint('[AppOverlay] Stack Trace: $stackTrace');
      _isShowing = false;
      _overlayEntry = null;
    }
  }

  /// Hide overlay
  /// This should ONLY be called from:
  /// 1. Payment success (after verification)
  /// 2. Unlock command from admin (FCM)
  /// 3. Extend payment command (FCM)
  static void hideOverlay({String? reason}) {
    debugPrint('[AppOverlay] ========== HIDE OVERLAY CALLED ==========');
    debugPrint('[AppOverlay] Reason: ${reason ?? 'Not specified'}');
    debugPrint('[AppOverlay] Current state - isShowing: $_isShowing, overlayEntry: ${_overlayEntry != null}');
    
    if (!_isShowing) {
      debugPrint('[AppOverlay] ⚠️ Overlay not showing, nothing to hide');
      // Still clear stored state
      SharedPreferences.getInstance().then((prefs) {
        prefs.setBool(_overlayActiveKey, false);
        prefs.remove(_overlayEmiIdKey);
      });
      return;
    }
    
    if (_overlayEntry == null) {
      debugPrint('[AppOverlay] ⚠️ Overlay entry is null, but isShowing is true');
      _isShowing = false;
      // Clear stored state
      SharedPreferences.getInstance().then((prefs) {
        prefs.setBool(_overlayActiveKey, false);
        prefs.remove(_overlayEmiIdKey);
      });
      return;
    }
    
    try {
      debugPrint('[AppOverlay] Removing overlay entry...');
      _overlayEntry?.remove();
      _overlayEntry = null;
      _isShowing = false;
      debugPrint('[AppOverlay] ✅ Overlay entry removed');
      
      // Clear stored state
      SharedPreferences.getInstance().then((prefs) async {
        await prefs.setBool(_overlayActiveKey, false);
        await prefs.remove(_overlayEmiIdKey);
        debugPrint('[AppOverlay] ✅ Stored state cleared');
      });
    } catch (e, stackTrace) {
      debugPrint('[AppOverlay] ❌ EXCEPTION: Error hiding overlay: $e');
      debugPrint('[AppOverlay] Stack Trace: $stackTrace');
      // Force clear state even if remove fails
      _isShowing = false;
      _overlayEntry = null;
    }
  }

  /// Check if overlay should be shown on app start
  static Future<bool> shouldShowOverlayOnStart() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_overlayActiveKey) ?? false;
  }
  
  /// Check if overlay is currently showing
  static Future<bool> isOverlayShowing() async {
    // Check both runtime state and stored state
    if (_isShowing) {
      return true;
    }
    final prefs = await SharedPreferences.getInstance();
    final isActive = prefs.getBool(_overlayActiveKey) ?? false;
    
    // Also check if device is locked
    if (_fcmService != null) {
      final isLocked = await _fcmService!.isDeviceLocked();
      if (isLocked) {
        return true;
      }
    }
    
    return isActive;
  }


  /// Check for overlay on app start
  static Future<void> checkOnAppStart(BuildContext context) async {
    debugPrint('[AppOverlay] ========== CHECKING OVERLAY ON APP START ==========');
    
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
      
      // CRITICAL: Process unlock command FIRST (highest priority)
      if (unlockPending) {
        debugPrint('[AppOverlay] ========== PROCESSING UNLOCK COMMAND (HIGHEST PRIORITY) ==========');
        await prefs.setBool('fcm_unlock_pending', false);
        
        // Hide overlay immediately
        hideOverlay(reason: 'Unlock command from background');
        
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
      
      // Check FCM lock status (only if no unlock pending)
      if (_fcmService != null) {
        final isLocked = await _fcmService!.isDeviceLocked();
        debugPrint('[AppOverlay] FCM lock status: $isLocked');
        if (isLocked) {
          final lockedEmiId = await _fcmService!.getLockedEmiId();
          debugPrint('[AppOverlay] Locked EMI ID: $lockedEmiId');
          if (lockedEmiId != null) {
            await checkAndShowOverlay(context);
            return;
          }
        } else {
          // Device is not locked, ensure overlay is hidden
          debugPrint('[AppOverlay] Device is not locked, ensuring overlay is hidden');
          hideOverlay(reason: 'Device not locked');
          await prefs.setBool(_overlayActiveKey, false);
          await prefs.remove(_overlayEmiIdKey);
        }
      }
      
      // Fallback to stored overlay state (only if device is actually locked)
      final shouldShow = await shouldShowOverlayOnStart();
      final isDeviceLocked = await _fcmService?.isDeviceLocked() ?? false;
      
      debugPrint('[AppOverlay] Should show overlay: $shouldShow');
      debugPrint('[AppOverlay] Is device locked: $isDeviceLocked');
      
      // Only show overlay if device is actually locked
      if (shouldShow && isDeviceLocked) {
        await checkAndShowOverlay(context);
      } else if (!isDeviceLocked) {
        // Device is not locked, hide overlay
        debugPrint('[AppOverlay] Device not locked, hiding overlay');
        hideOverlay(reason: 'Device not locked on app start');
        await prefs.setBool(_overlayActiveKey, false);
        await prefs.remove(_overlayEmiIdKey);
      }
    } catch (e, stackTrace) {
      debugPrint('[AppOverlay] ❌ ERROR: Error checking overlay on app start: $e');
      debugPrint('[AppOverlay] Stack Trace: $stackTrace');
    }
  }
  
  /// Manually unlock device (e.g., after payment verification)
  static Future<void> unlockDevice() async {
    hideOverlay(reason: 'Payment verified successfully');
    await _fcmService?.unlockDevice();
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
}

