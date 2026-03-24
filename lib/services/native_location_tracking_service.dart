import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Android: starts/stops [LocationTrackingService] so FCM `get_location_command` has a fresh cache
/// when the app is not open.
class NativeLocationTrackingService {
  static const _channel =
      MethodChannel('com.rohit.emilockercustomer/location_tracking');

  static Future<void> startIfPossible() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>('start');
    } catch (e, st) {
      debugPrint('[LocationTracking] start failed: $e\n$st');
    }
  }

  static Future<void> stop() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>('stop');
    } catch (e, st) {
      debugPrint('[LocationTracking] stop failed: $e\n$st');
    }
  }
}
