import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

/// App Protection Service
/// 
/// This service manages app protection features including:
/// - Accessibility service for monitoring app control attempts
/// - Overlay protection when user tries to access app info/pause
/// - Integration with device admin for comprehensive protection
/// 
/// Key Features:
/// - Detects when user long-presses app icon
/// - Monitors "App info" and "Pause app" clicks
/// - Shows overlay to prevent app modification
/// - Works with FCM lock/unlock commands
class AppProtectionService {
  static const MethodChannel _channel = MethodChannel('device_control');
  
  /// Check if accessibility service is enabled
  /// Returns true if Fasst Pay protection service is active
  static Future<bool> isAccessibilityServiceEnabled() async {
    try {
      final bool isEnabled = await _channel.invokeMethod('isAccessibilityServiceEnabled') ?? false;
      debugPrint('📱 Accessibility Service Status: $isEnabled');
      return isEnabled;
    } catch (e) {
      debugPrint('❌ Error checking accessibility service status: $e');
      return false;
    }
  }
  
  /// Request accessibility service permission
  /// 
  /// This will open Android accessibility settings where user can
  /// enable "Fasst Pay Protection Service" to monitor app usage.
  /// 
  /// User needs to:
  /// 1. Find "Fasst Pay Protection Service" in the list
  /// 2. Toggle it ON
  /// 3. Confirm in the dialog that appears
  /// 
  /// Returns immediately - user will enable service manually
  static Future<void> requestAccessibilityPermission() async {
    try {
      debugPrint('📱 Opening accessibility settings...');
      await _channel.invokeMethod('requestAccessibilityPermission');
      debugPrint('✅ Accessibility settings opened');
    } catch (e) {
      debugPrint('❌ Error opening accessibility settings: $e');
    }
  }

  /// Opens system dialog so Fasst Pay is excluded from battery optimization (better FCM / background EMI actions).
  static Future<void> requestIgnoreBatteryOptimizations() async {
    try {
      await _channel.invokeMethod('requestIgnoreBatteryOptimizations');
    } catch (e) {
      debugPrint('❌ Battery optimization request: $e');
    }
  }
  
  /// Get comprehensive protection status
  /// 
  /// Returns map with all protection features status:
  /// - Device admin active
  /// - Accessibility service enabled
  /// - Overlay permission granted
  /// - Overall protection level
  static Future<Map<String, dynamic>> getProtectionStatus() async {
    try {
      // Check all protection features
      final bool isDeviceAdminActive = await _channel.invokeMethod('isAdminActive') ?? false;
      final bool isAccessibilityEnabled = await isAccessibilityServiceEnabled();
      final bool hasOverlayPermission = await _channel.invokeMethod('checkOverlayPermission') ?? false;
      
      // Calculate protection level
      int protectionLevel = 0;
      if (isDeviceAdminActive) protectionLevel += 40; // Most important
      if (isAccessibilityEnabled) protectionLevel += 35; // Very important
      if (hasOverlayPermission) protectionLevel += 25; // Important
      
      String protectionLevelText;
      if (protectionLevel >= 90) {
        protectionLevelText = 'Maximum Protection';
      } else if (protectionLevel >= 60) {
        protectionLevelText = 'High Protection';
      } else if (protectionLevel >= 30) {
        protectionLevelText = 'Medium Protection';
      } else {
        protectionLevelText = 'Low Protection';
      }
      
      return {
        'deviceAdminActive': isDeviceAdminActive,
        'accessibilityServiceEnabled': isAccessibilityEnabled,
        'overlayPermissionGranted': hasOverlayPermission,
        'protectionLevel': protectionLevel,
        'protectionLevelText': protectionLevelText,
        'isFullyProtected': protectionLevel >= 90,
        'recommendations': _getRecommendations(isDeviceAdminActive, isAccessibilityEnabled, hasOverlayPermission),
      };
    } catch (e) {
      debugPrint('❌ Error getting protection status: $e');
      return {
        'error': e.toString(),
        'protectionLevel': 0,
        'protectionLevelText': 'Unknown',
        'isFullyProtected': false,
      };
    }
  }
  
  /// Get recommendations for improving protection
  static List<String> _getRecommendations(bool deviceAdmin, bool accessibility, bool overlay) {
    List<String> recommendations = [];
    
    if (!deviceAdmin) {
      recommendations.add('Enable Device Administrator to prevent app uninstallation');
    }
    
    if (!accessibility) {
      recommendations.add('Enable Accessibility Service to monitor app control attempts');
    }
    
    if (!overlay) {
      recommendations.add('Grant Overlay Permission to show protection screens');
    }
    
    if (recommendations.isEmpty) {
      recommendations.add('All protection features are active - your EMI is secure!');
    }
    
    return recommendations;
  }
  
  /// Test protection overlay manually (for debugging)
  /// 
  /// This directly triggers the protection overlay to test if it works
  static Future<void> testProtectionOverlay() async {
    try {
      debugPrint('🧪 Testing protection overlay...');
      await _channel.invokeMethod('testProtectionOverlay');
      debugPrint('✅ Protection overlay test triggered');
    } catch (e) {
      debugPrint('❌ Error testing protection overlay: $e');
    }
  }
  
  /// Show protection overlay manually (for testing)
  /// 
  /// This can be used to test the overlay functionality
  /// or show protection message when needed.
  static Future<void> showProtectionOverlay({
    String? title,
    String? message,
  }) async {
    try {
      debugPrint('🛡️ Showing protection overlay...');
      
      await _channel.invokeMethod('showSystemOverlay', {
        'message': '${title ?? "App Protection Active"}\n\n${message ?? "Fasst Pay app is protected during EMI period"}\n\nThis protection ensures loan security and compliance.',
        'amount': '0',
        'is_protection_overlay': true,
      });
      
      debugPrint('✅ Protection overlay shown');
    } catch (e) {
      debugPrint('❌ Error showing protection overlay: $e');
    }
  }
  
  /// Hide protection overlay
  static Future<void> hideProtectionOverlay() async {
    try {
      debugPrint('✅ Hiding protection overlay...');
      await _channel.invokeMethod('hideSystemOverlay');
      debugPrint('✅ Protection overlay hidden');
    } catch (e) {
      debugPrint('❌ Error hiding protection overlay: $e');
    }
  }
  
  /// Get user-friendly setup instructions
  static String getAccessibilitySetupInstructions() {
    return '''
🛡️ Enable App Protection Service

To protect Fasst Pay from unauthorized access:

1️⃣ Tap "Open Accessibility Settings" below
2️⃣ Find "Fasst Pay Protection Service" in the list
3️⃣ Tap on it and toggle the switch ON
4️⃣ Confirm "OK" in the dialog that appears

🔒 What this protects:
• Prevents access to "App info" option
• Blocks "Pause app" functionality  
• Monitors unauthorized app control attempts
• Shows protection overlay when needed

⚠️ Important:
This service only monitors app control attempts.
No personal data is accessed or stored.

✅ You can disable this service after EMI completion.
''';
  }
  
  /// Get protection feature explanation
  static Map<String, String> getProtectionFeatureExplanations() {
    return {
      'Device Administrator': 'Prevents app uninstallation during EMI period. Most important protection.',
      'Accessibility Service': 'Monitors when user tries to access app settings or pause the app.',
      'Overlay Permission': 'Allows showing protection screens when unauthorized access is detected.',
    };
  }
  
  /// Check if all critical protections are enabled
  static Future<bool> isCriticalProtectionActive() async {
    try {
      final status = await getProtectionStatus();
      return status['deviceAdminActive'] == true && status['accessibilityServiceEnabled'] == true;
    } catch (e) {
      debugPrint('❌ Error checking critical protection: $e');
      return false;
    }
  }
  
  /// Get protection summary for display
  static Future<String> getProtectionSummary() async {
    try {
      final status = await getProtectionStatus();
      final level = status['protectionLevelText'] ?? 'Unknown';
      final isFullyProtected = status['isFullyProtected'] ?? false;
      
      if (isFullyProtected) {
        return '✅ $level - Your EMI is fully secured';
      } else {
        return '⚠️ $level - Additional setup recommended';
      }
    } catch (e) {
      return '❌ Unable to check protection status';
    }
  }
}