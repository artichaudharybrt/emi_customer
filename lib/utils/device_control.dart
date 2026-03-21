import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class DeviceControl {
  DeviceControl._();

  static const MethodChannel _channel = MethodChannel('device_control');

  static Future<void> requestAdmin() async {
    await _invoke('requestAdmin');
  }

  static Future<void> requestOverlayPermission() async {
    await _invoke('requestOverlayPermission');
  }

  static Future<void> lockNow() async {
    await _invoke('lockNow');
  }

  static Future<void> unlock() async {
    await _invoke('unlock');
  }

  static Future<void> ensureForeground() async {
    await _invoke('ensureForeground');
  }

  static Future<void> showOverlay(Map<String, dynamic> payload) async {
    await _invokeWithArgs('showOverlay', payload);
  }

  static Future<void> hideOverlay() async {
    await _invoke('hideOverlay');
  }

  static Future<void> _invoke(String method) async {
    try {
      await _channel.invokeMethod(method);
      debugPrint('DeviceControl $method invoked');
    } on MissingPluginException {
      debugPrint('DeviceControl $method invoked (stubbed)');
    } catch (error, stackTrace) {
      debugPrint('DeviceControl $method failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  static Future<void> _invokeWithArgs(
    String method,
    Map<String, dynamic> arguments,
  ) async {
    try {
      await _channel.invokeMethod(method, arguments);
      debugPrint('DeviceControl $method invoked with payload');
    } on MissingPluginException {
      debugPrint('DeviceControl $method stubbed');
    } catch (error, stackTrace) {
      debugPrint('DeviceControl $method failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }
}
