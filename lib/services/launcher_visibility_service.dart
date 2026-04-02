import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Android: launcher icon is [LauncherAlias]. After login the alias is disabled so the app
/// leaves the app drawer; [MainActivity] stays open via explicit intents from FCM/services.
class LauncherVisibilityService {
  static const _channel = MethodChannel('device_control');

  static Future<void> setLauncherEntryVisible(bool visible) async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>('setLauncherEntryEnabled', {'visible': visible});
    } catch (e) {
      debugPrint('[LauncherVisibility] setLauncherEntryVisible: $e');
    }
  }

  static Future<void> syncWithStoredSession() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>('syncLauncherWithSession');
    } catch (e) {
      debugPrint('[LauncherVisibility] syncWithStoredSession: $e');
    }
  }
}
