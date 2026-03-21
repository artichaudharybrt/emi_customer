import 'package:flutter/foundation.dart';
import 'package:device_info_plus/device_info_plus.dart';

class DeviceFingerprint {
  DeviceFingerprint._();

  static Future<String> hashedDeviceId() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;
      final deviceId = '${androidInfo.brand}_${androidInfo.model}_${androidInfo.id}';
      debugPrint('Device fingerprint generated: $deviceId');
      return deviceId.hashCode.toString();
    } catch (e) {
      debugPrint('Error generating device fingerprint: $e');
      return 'unknown_device';
    }
  }
}
