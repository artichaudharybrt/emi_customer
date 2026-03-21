import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

/// Device Admin Service for Fasst Pay App
/// 
/// This service handles device administrator functionality to prevent
/// app uninstallation during EMI period. It provides secure device
/// locking capabilities and prevents unauthorized app removal.
/// 
/// Key Features:
/// - Request device admin permission from user
/// - Check device admin activation status
/// - Lock device remotely via FCM commands
/// - Prevent app uninstallation during EMI period
/// - Show blocking interface when device is locked
/// 
/// Legal Compliance:
/// - User must explicitly consent to device admin activation
/// - Clear explanation of permissions and their purpose
/// - Option to deactivate when EMI is completed
/// - Transparent about data usage and device control
class DeviceAdminService {
  static const MethodChannel _channel = MethodChannel('device_control');
  
  /// Check if device admin is currently active
  /// Returns true if app has device administrator privileges
  static Future<bool> isDeviceAdminActive() async {
    try {
      final bool isActive = await _channel.invokeMethod('isAdminActive') ?? false;
      debugPrint('📱 Device Admin Status: $isActive');
      return isActive;
    } catch (e) {
      debugPrint('❌ Error checking device admin status: $e');
      return false;
    }
  }
  
  /// Request device admin permission from user
  /// 
  /// This will show Android's system dialog asking user to grant
  /// device administrator privileges to the app.
  /// 
  /// User will see explanation of what permissions are needed and why.
  /// They can choose to grant or deny the permission.
  /// 
  /// Returns true if permission was granted, false if denied
  static Future<bool> requestDeviceAdminPermission() async {
    try {
      debugPrint('📱 Requesting device admin permission...');
      
      // Check if already active
      if (await isDeviceAdminActive()) {
        debugPrint('✅ Device admin already active');
        return true;
      }
      
      // Request permission - this will show system dialog
      await _channel.invokeMethod('requestAdmin');
      
      // Wait a moment for user to respond to dialog
      await Future.delayed(const Duration(seconds: 2));
      
      // Check if permission was granted
      final bool isActive = await isDeviceAdminActive();
      
      if (isActive) {
        debugPrint('✅ Device admin permission granted');
      } else {
        debugPrint('❌ Device admin permission denied or cancelled');
      }
      
      return isActive;
    } catch (e) {
      debugPrint('❌ Error requesting device admin permission: $e');
      return false;
    }
  }
  
  /// Lock device immediately using device admin
  /// 
  /// This will lock the device screen immediately, similar to pressing
  /// the power button. User will need to unlock with PIN/pattern/fingerprint.
  /// 
  /// Requires device admin permission to be active.
  /// Returns true if device was locked successfully
  static Future<bool> lockDeviceNow() async {
    try {
      debugPrint('🔒 Attempting to lock device...');
      
      // Check if device admin is active
      if (!await isDeviceAdminActive()) {
        debugPrint('❌ Cannot lock device - device admin not active');
        return false;
      }
      
      // Lock the device
      final bool success = await _channel.invokeMethod('lockNow') ?? false;
      
      if (success) {
        debugPrint('✅ Device locked successfully');
      } else {
        debugPrint('❌ Failed to lock device');
      }
      
      return success;
    } catch (e) {
      debugPrint('❌ Error locking device: $e');
      return false;
    }
  }
  
  /// Show device admin blocking activity
  /// 
  /// This shows a full-screen blocking interface that cannot be dismissed
  /// until EMI payment is made. The activity is protected by device admin.
  /// 
  /// [message] - Custom message to show to user
  /// [amount] - Overdue EMI amount to display
  static Future<void> showDeviceAdminBlockingActivity({
    String? message,
    String? amount,
  }) async {
    try {
      debugPrint('🚫 Showing device admin blocking activity...');
      
      await _channel.invokeMethod('showBlockingActivity', {
        'message': message ?? 'Your EMI is overdue. Please contact shopkeeper.',
        'amount': amount ?? '0',
      });
      
      debugPrint('✅ Device admin blocking activity shown');
    } catch (e) {
      debugPrint('❌ Error showing device admin blocking activity: $e');
    }
  }
  
  /// Hide device admin blocking activity
  /// 
  /// This removes the blocking interface and allows normal device usage.
  /// Should only be called after EMI payment is confirmed.
  static Future<void> hideDeviceAdminBlockingActivity() async {
    try {
      debugPrint('✅ Hiding device admin blocking activity...');
      
      await _channel.invokeMethod('hideBlockingActivity');
      
      debugPrint('✅ Device admin blocking activity hidden');
    } catch (e) {
      debugPrint('❌ Error hiding device admin blocking activity: $e');
    }
  }
  
  /// Get device admin information for debugging
  /// 
  /// Returns map with device admin status and capabilities
  static Future<Map<String, dynamic>> getDeviceAdminInfo() async {
    try {
      final bool isActive = await isDeviceAdminActive();
      
      return {
        'isActive': isActive,
        'canLockDevice': isActive,
        'canPreventUninstall': isActive,
        'description': 'Fasst Pay Device Administrator - Prevents app uninstallation during EMI period',
        'permissions': [
          'Lock device remotely',
          'Prevent app uninstallation',
          'Monitor device unlock attempts',
          'Show blocking interface',
        ],
      };
    } catch (e) {
      debugPrint('❌ Error getting device admin info: $e');
      return {
        'isActive': false,
        'error': e.toString(),
      };
    }
  }
  
  /// Check if device admin is supported on this device
  /// 
  /// All Android devices support device admin, so this always returns true.
  /// Included for completeness and future compatibility.
  static Future<bool> isDeviceAdminSupported() async {
    return true; // Device admin is supported on all Android devices
  }
  
  /// Show device admin permission explanation dialog
  /// 
  /// This explains to user why device admin permission is needed
  /// and what it will be used for. Should be called before requesting permission.
  static String getDeviceAdminExplanation() {
    return '''
🛡️ Device Administrator Permission Required

Fasst Pay needs device administrator access to:

✅ Prevent app uninstallation during EMI period
✅ Lock device remotely for payment security  
✅ Monitor unauthorized access attempts
✅ Ensure EMI payment compliance
✅ Protect your loan agreement

🔒 Your Privacy:
• No personal data is accessed
• Only security functions are used
• Permission can be revoked after EMI completion

📋 Legal Compliance:
• You agreed to these terms in your loan agreement
• This protects both you and the lender
• Ensures responsible lending practices

⚠️ Important:
This permission is required to proceed with your EMI plan.
You can deactivate it after completing all payments.
''';
  }
  
  /// Get user-friendly status message
  static Future<String> getStatusMessage() async {
    try {
      final bool isActive = await isDeviceAdminActive();
      
      if (isActive) {
        return '✅ Device protection is active\nYour EMI agreement is secured';
      } else {
        return '⚠️ Device protection is not active\nPlease enable device administrator';
      }
    } catch (e) {
      return '❌ Unable to check device protection status';
    }
  }
}