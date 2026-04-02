import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';
import '../utils/api_client.dart';

/// Fetches `canUserUninstallFlag` from GET /users/me/uninstall-flag and syncs to Android
/// so [AppUsageMonitorService] can skip blocking overlays (same idea as location/SIM: background refresh after login).
class UninstallFlagService {
  static const String _prefsKey = 'can_user_uninstall_flag';
  static const MethodChannel _channel =
      MethodChannel('com.rohit.emilockercustomer/system_overlay');

  /// Non-blocking: schedule fetch like [UserLocationService.fetchAndSendLocation].then.
  static void refreshInBackground() {
    Future.microtask(() => fetchAndSyncToNative());
  }

  static Future<void> fetchAndSyncToNative() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    if (token == null || token.isEmpty) {
      await _persistAndSync(false);
      return;
    }
    try {
      final response = await ApiClient.get(
        Uri.parse(ApiConfig.userUninstallFlagMe),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      final data = payload['data'];
      var canUninstall = false;
      if (data is Map<String, dynamic>) {
        canUninstall = data['canUserUninstallFlag'] as bool? ?? false;
      }
      await _persistAndSync(canUninstall);
      debugPrint('[UninstallFlag] canUserUninstallFlag=$canUninstall → native');
    } catch (e, st) {
      debugPrint('[UninstallFlag] fetch failed (keeping last value): $e');
      debugPrint('[UninstallFlag] $st');
    }
  }

  static Future<void> _persistAndSync(bool canUserUninstall) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKey, canUserUninstall);
    try {
      await _channel.invokeMethod<void>('setCanUserUninstallFlag', {
        'value': canUserUninstall,
      });
    } catch (e) {
      debugPrint('[UninstallFlag] native sync failed: $e');
    }
  }

  static Future<void> clearOnLogout() async {
    await _persistAndSync(false);
  }

  /// FCM `type: can_user_uninstall_sync` — payload uses string or bool (same as Android data map).
  /// `true` = user may uninstall → disable accessibility protection overlays.
  /// `false` = keep showing blocking overlays in Settings / uninstall / factory reset flows.
  static Future<void> applyFromFcmPayload(Map<String, dynamic> data) async {
    final v = coerceCanUserUninstallFromPayload(data['canUserUninstallFlag']);
    await _persistAndSync(v);
    debugPrint('[UninstallFlag] FCM can_user_uninstall_sync → canUserUninstallFlag=$v (native synced)');
  }

  static bool coerceCanUserUninstallFromPayload(dynamic raw) {
    if (raw is bool) return raw;
    if (raw is String) {
      final s = raw.trim().toLowerCase();
      return s == 'true' || s == '1' || s == 'yes';
    }
    if (raw is num) return raw != 0;
    return false;
  }
}
