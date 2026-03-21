import 'package:flutter/material.dart';
import '../services/app_protection_service.dart';

/// Protection Debug Screen
/// 
/// Simple screen for testing and debugging protection features
class ProtectionDebugScreen extends StatefulWidget {
  const ProtectionDebugScreen({Key? key}) : super(key: key);

  @override
  State<ProtectionDebugScreen> createState() => _ProtectionDebugScreenState();
}

class _ProtectionDebugScreenState extends State<ProtectionDebugScreen> {
  String _statusMessage = 'Ready to test...';
  bool _isAccessibilityEnabled = false;

  @override
  void initState() {
    super.initState();
    _checkAccessibilityStatus();
  }

  Future<void> _checkAccessibilityStatus() async {
    try {
      final bool isEnabled = await AppProtectionService.isAccessibilityServiceEnabled();
      setState(() {
        _isAccessibilityEnabled = isEnabled;
        _statusMessage = isEnabled 
            ? '✅ Accessibility service is enabled' 
            : '❌ Accessibility service is disabled';
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Error checking accessibility: $e';
      });
    }
  }

  Future<void> _testOverlay() async {
    try {
      setState(() {
        _statusMessage = 'Testing overlay...';
      });
      
      await AppProtectionService.testProtectionOverlay();
      
      setState(() {
        _statusMessage = '✅ Overlay test triggered - check if overlay appeared';
      });
    } catch (e) {
      setState(() {
        _statusMessage = '❌ Error testing overlay: $e';
      });
    }
  }

  Future<void> _openAccessibilitySettings() async {
    try {
      await AppProtectionService.requestAccessibilityPermission();
      setState(() {
        _statusMessage = 'Accessibility settings opened - enable Fasst Pay Protection Service';
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Error opening accessibility settings: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Protection Debug'),
        backgroundColor: Colors.red[700],
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status Card
            Card(
              color: _isAccessibilityEnabled ? Colors.green[50] : Colors.red[50],
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Icon(
                      _isAccessibilityEnabled ? Icons.check_circle : Icons.error,
                      color: _isAccessibilityEnabled ? Colors.green : Colors.red,
                      size: 48,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _statusMessage,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: _isAccessibilityEnabled ? Colors.green[700] : Colors.red[700],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Test Buttons
            ElevatedButton.icon(
              onPressed: _testOverlay,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Test Protection Overlay'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[700],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.all(16),
              ),
            ),

            const SizedBox(height: 12),

            ElevatedButton.icon(
              onPressed: _openAccessibilitySettings,
              icon: const Icon(Icons.settings),
              label: const Text('Open Accessibility Settings'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange[700],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.all(16),
              ),
            ),

            const SizedBox(height: 12),

            ElevatedButton.icon(
              onPressed: _checkAccessibilityStatus,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh Status'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[700],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.all(16),
              ),
            ),

            const SizedBox(height: 24),

            // Instructions
            Card(
              color: Colors.amber[50],
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '🧪 Debug Instructions',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.amber[700],
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text('1. First enable accessibility service'),
                    const Text('2. Test overlay to see if it works'),
                    const Text('3. Try long-pressing Fasst Pay app icon'),
                    const Text('4. Click "App info" - overlay should appear'),
                    const Text('5. Check logcat for debugging info'),
                    const SizedBox(height: 12),
                    Text(
                      '📱 Logcat command:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.amber[700],
                      ),
                    ),
                    const Text('adb logcat | grep -E "(AppUsageMonitor|SystemOverlay)"'),
                  ],
                ),
              ),
            ),

            const Spacer(),

            // Warning
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red[300]!),
              ),
              child: Text(
                '⚠️ This is a debug screen. The overlay test will show a protection screen that you can dismiss with back button.',
                style: TextStyle(
                  color: Colors.red[700],
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}