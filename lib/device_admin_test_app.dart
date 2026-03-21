import 'package:flutter/material.dart';
import 'screens/device_admin_test_screen.dart';

/// Simple test app for Device Admin functionality
/// 
/// Run this to test device admin features:
/// flutter run lib/device_admin_test_app.dart
class DeviceAdminTestApp extends StatelessWidget {
  const DeviceAdminTestApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Device Admin Test',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const DeviceAdminTestScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

void main() {
  runApp(const DeviceAdminTestApp());
}