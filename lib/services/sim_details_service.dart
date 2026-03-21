import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import '../utils/api_client.dart';

/// Service to request phone permission and post SIM details + number to backend.
/// API is called only after login (with token); on splash we only request permission.
class SimDetailsService {
  static const String _authTokenKey = 'auth_token';
  static const String _simDetailsPostedKey = 'sim_details_posted';

  /// Only request phone permission (no API call). Use on splash so user grants permission before login.
  static Future<void> requestPermissionOnly() async {
    try {
      final status = await Permission.phone.status;
      if (status.isGranted) return;
      if (status.isDenied) {
        await Permission.phone.request();
        return;
      }
      if (status.isPermanentlyDenied) {
        debugPrint('[SimDetails] Phone permission permanently denied');
      }
    } catch (e, st) {
      debugPrint('[SimDetails] Error requesting permission: $e');
    }
  }

  /// Request permission and, when granted, POST SIM details (only call when user has token, e.g. after login).
  static Future<bool> requestPermissionAndPostSimDetails() async {
    try {
      final status = await Permission.phone.status;
      if (status.isGranted) {
        return await _fetchAndPostSimDetails();
      }
      if (status.isDenied) {
        final result = await Permission.phone.request();
        if (result.isGranted) {
          return await _fetchAndPostSimDetails();
        }
        debugPrint('[SimDetails] Phone permission denied');
        return false;
      }
      if (status.isPermanentlyDenied) {
        debugPrint('[SimDetails] Phone permission permanently denied');
        return false;
      }
      return false;
    } catch (e, st) {
      debugPrint('[SimDetails] Error: $e');
      debugPrint('[SimDetails] $st');
      return false;
    }
  }

  /// Check if we have phone permission and post SIM details if not yet posted.
  static Future<bool> postSimDetailsIfAllowed() async {
    final status = await Permission.phone.status;
    if (!status.isGranted) return false;
    return await _fetchAndPostSimDetails();
  }

  static Future<bool> _fetchAndPostSimDetails() async {
    if (!Platform.isAndroid) return false;
    try {
      final details = await _getSimDetailsFromPlatform();
      if (details == null || details.isEmpty) {
        debugPrint('[SimDetails] No SIM details from platform');
        return false;
      }
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(_authTokenKey);
      final body = <String, dynamic>{
        'phoneNumber': details['phoneNumber'],
        'simOperatorName': details['simOperatorName'],
        'simCountryIso': details['simCountryIso'],
        'networkOperatorName': details['networkOperatorName'],
        'simCount': details['simCount'],
        'deviceId': details['deviceId'],
        'recordedAt': DateTime.now().toUtc().toIso8601String(),
      };
      if (details['carrierNames'] != null) body['carrierNames'] = details['carrierNames'];
      if (details['simNumbers'] != null) body['simNumbers'] = details['simNumbers'];
      body.removeWhere((_, v) => v == null || v == '');
      if (token != null && token.isNotEmpty) body['hasAuth'] = true;
      final headers = <String, String>{
        'Content-Type': 'application/json',
      };
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
      await ApiClient.post(
        Uri.parse(ApiConfig.deviceSimDetails),
        headers: headers,
        body: jsonEncode(body),
      );
      await prefs.setBool(_simDetailsPostedKey, true);
      try {
        await _simChannel.invokeMethod('markSimDetailsPosted');
      } catch (_) {}
      debugPrint('[SimDetails] SIM details posted successfully (phone: ${details['phoneNumber']})');
      return true;
    } on ApiException catch (e) {
      debugPrint('[SimDetails] API error: ${e.message}');
      return false;
    } catch (e, st) {
      debugPrint('[SimDetails] Error posting: $e');
      debugPrint('[SimDetails] $st');
      return false;
    }
  }

  static const MethodChannel _simChannel = MethodChannel('com.rohit.emilockercustomer/sim_details');

  static Future<Map<String, dynamic>?> _getSimDetailsFromPlatform() async {
    try {
      final result = await _simChannel.invokeMethod('getSimDetails');
      if (result == null || result is! Map) return null;
      return Map<String, dynamic>.from(result);
    } on PlatformException catch (e) {
      debugPrint('[SimDetails] Platform channel error: ${e.code} ${e.message}');
      return null;
    } catch (e) {
      debugPrint('[SimDetails] Platform channel error: $e');
      return null;
    }
  }
}
