import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Service to handle native back button blocking
class NativeBackButtonService {
  static const MethodChannel _channel = MethodChannel('com.rohit.emilockercustomer/back_button');
  
  /// Enable back button blocking at native level
  static Future<void> enableBackButtonBlocking() async {
    try {
      await _channel.invokeMethod('enableBackButtonBlocking');
      debugPrint('[NativeBackButton] ✅ Back button blocking enabled at native level');
    } catch (e) {
      debugPrint('[NativeBackButton] ❌ Error enabling back button blocking: $e');
    }
  }
  
  /// Disable back button blocking at native level
  static Future<void> disableBackButtonBlocking() async {
    try {
      await _channel.invokeMethod('disableBackButtonBlocking');
      debugPrint('[NativeBackButton] ✅ Back button blocking disabled at native level');
    } catch (e) {
      debugPrint('[NativeBackButton] ❌ Error disabling back button blocking: $e');
    }
  }
  
  /// Check if back button blocking is enabled
  static Future<bool> isBackButtonBlocked() async {
    try {
      final result = await _channel.invokeMethod('isBackButtonBlocked');
      return result as bool? ?? false;
    } catch (e) {
      debugPrint('[NativeBackButton] ❌ Error checking back button status: $e');
      return false;
    }
  }
}