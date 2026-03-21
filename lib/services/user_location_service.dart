import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import '../utils/api_client.dart';

/// Service to get current location and POST to /user-locations (used by FCM get_location_command).
class UserLocationService {
  static const String _authTokenKey = 'auth_token';

  /// Get current position, optional address, then POST to API.
  /// Returns true if location was sent successfully.
  static Future<bool> fetchAndSendLocation() async {
    try {
      debugPrint('[UserLocation] Fetching current location...');

      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        final requested = await Geolocator.requestPermission();
        if (requested == LocationPermission.denied ||
            requested == LocationPermission.deniedForever) {
          debugPrint('[UserLocation] Location permission denied');
          return false;
        }
      }

      // Use best accuracy so we get GPS fix (India). High/low may use network and wrong coords.
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
          timeLimit: Duration(seconds: 15),
        ),
      );

      double lat = position.latitude;
      double lng = position.longitude;
      double? accuracy = position.accuracy;
      debugPrint('[UserLocation] Got position: lat=$lat, lng=$lng (accuracy=${position.accuracy}m)');
      // India: lng is positive (68-97). If you see California (e.g. lng ~ -122), set emulator/device location to India.
      if (lng < 0 || lat < 8 || lat > 37) {
        debugPrint('[UserLocation] ⚠️ Coords look outside India (lat 8-37, lng 68-97). Set device/emulator location to India (e.g. Greater Noida).');
      }
      String address = '';

      try {
        final placemarks = await placemarkFromCoordinates(lat, lng);
        if (placemarks.isNotEmpty) {
          final p = placemarks.first;
          address = [
            p.street,
            p.subLocality,
            p.locality,
            p.administrativeArea,
            p.country,
          ].where((e) => e != null && e.isNotEmpty).join(', ');
        }
      } catch (e) {
        debugPrint('[UserLocation] Geocoding failed: $e');
      }

      final body = {
        'latitude': lat,
        'longitude': lng,
        'address': address.isEmpty ? null : address,
        'label': null,
        'notes': null,
        'accuracy': accuracy,
        'recordedAt': DateTime.now().toUtc().toIso8601String(),
      };

      // Remove nulls for cleaner payload
      body.removeWhere((_, v) => v == null);

      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(_authTokenKey);
      if (token == null || token.isEmpty) {
        debugPrint('[UserLocation] No auth token - cannot send location');
        return false;
      }

      final uri = Uri.parse(ApiConfig.userLocations);
      await ApiClient.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      );

      debugPrint('[UserLocation] ✅ Location sent to /user-locations');
      return true;
    } catch (e, st) {
      debugPrint('[UserLocation] ❌ Error: $e');
      debugPrint('[UserLocation] $st');
      return false;
    }
  }
}
