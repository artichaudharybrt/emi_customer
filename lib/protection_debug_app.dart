import 'package:flutter/material.dart';
import 'screens/protection_debug_screen.dart';

/// Protection Debug App
/// 
/// Simple app for testing protection features
/// Run with: flutter run lib/protection_debug_app.dart
class ProtectionDebugApp extends StatelessWidget {
  const ProtectionDebugApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Protection Debug',
      theme: ThemeData(
        primarySwatch: Colors.red,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const ProtectionDebugScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

void main() {
  runApp(const ProtectionDebugApp());
}