import 'package:flutter/material.dart';
import '../services/device_admin_service.dart';

/// Device Admin Test Screen
/// 
/// This screen is for testing device admin functionality.
/// Use this to verify that device admin is working properly.
class DeviceAdminTestScreen extends StatefulWidget {
  const DeviceAdminTestScreen({Key? key}) : super(key: key);

  @override
  State<DeviceAdminTestScreen> createState() => _DeviceAdminTestScreenState();
}

class _DeviceAdminTestScreenState extends State<DeviceAdminTestScreen> {
  bool _isDeviceAdminActive = false;
  bool _isLoading = false;
  String _statusMessage = 'Checking device admin status...';

  @override
  void initState() {
    super.initState();
    _checkDeviceAdminStatus();
  }

  /// Check current device admin status
  Future<void> _checkDeviceAdminStatus() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Checking device admin status...';
    });

    try {
      final bool isActive = await DeviceAdminService.isDeviceAdminActive();
      final String statusMsg = await DeviceAdminService.getStatusMessage();
      
      setState(() {
        _isDeviceAdminActive = isActive;
        _statusMessage = statusMsg;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isDeviceAdminActive = false;
        _statusMessage = 'Error checking status: $e';
        _isLoading = false;
      });
    }
  }

  /// Request device admin permission
  Future<void> _requestDeviceAdminPermission() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Requesting device admin permission...';
    });

    try {
      final bool granted = await DeviceAdminService.requestDeviceAdminPermission();
      
      setState(() {
        _isDeviceAdminActive = granted;
        _statusMessage = granted 
            ? '✅ Device admin activated successfully!' 
            : '❌ Device admin permission denied';
        _isLoading = false;
      });

      if (granted) {
        _showSnackBar('Device admin activated! App is now protected.', Colors.green);
      } else {
        _showSnackBar('Device admin permission was denied.', Colors.red);
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = 'Error requesting permission: $e';
      });
      _showSnackBar('Error: $e', Colors.red);
    }
  }

  /// Test device locking
  Future<void> _testDeviceLock() async {
    if (!_isDeviceAdminActive) {
      _showSnackBar('Device admin must be active to lock device', Colors.orange);
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = 'Locking device...';
    });

    try {
      final bool success = await DeviceAdminService.lockDeviceNow();
      
      setState(() {
        _isLoading = false;
        _statusMessage = success 
            ? '✅ Device locked successfully!' 
            : '❌ Failed to lock device';
      });

      if (success) {
        _showSnackBar('Device locked successfully!', Colors.green);
      } else {
        _showSnackBar('Failed to lock device', Colors.red);
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = 'Error locking device: $e';
      });
      _showSnackBar('Error: $e', Colors.red);
    }
  }

  /// Show blocking activity
  Future<void> _showBlockingActivity() async {
    try {
      await DeviceAdminService.showDeviceAdminBlockingActivity(
        message: 'Test EMI overdue message - This is a test',
        amount: '5000',
      );
      _showSnackBar('Blocking activity shown', Colors.blue);
    } catch (e) {
      _showSnackBar('Error showing blocking activity: $e', Colors.red);
    }
  }

  /// Hide blocking activity
  Future<void> _hideBlockingActivity() async {
    try {
      await DeviceAdminService.hideDeviceAdminBlockingActivity();
      _showSnackBar('Blocking activity hidden', Colors.blue);
    } catch (e) {
      _showSnackBar('Error hiding blocking activity: $e', Colors.red);
    }
  }

  /// Show snackbar
  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Device Admin Test'),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _checkDeviceAdminStatus,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status Card
            Card(
              color: _isDeviceAdminActive ? Colors.green[50] : Colors.red[50],
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Icon(
                      _isDeviceAdminActive ? Icons.shield : Icons.warning,
                      color: _isDeviceAdminActive ? Colors.green : Colors.red,
                      size: 48,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _isDeviceAdminActive 
                          ? 'Device Admin Active' 
                          : 'Device Admin Inactive',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: _isDeviceAdminActive ? Colors.green[700] : Colors.red[700],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _statusMessage,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _isDeviceAdminActive ? Colors.green[600] : Colors.red[600],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Action Buttons
            if (!_isDeviceAdminActive) ...[
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _requestDeviceAdminPermission,
                icon: _isLoading 
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.admin_panel_settings),
                label: const Text('Request Device Admin Permission'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[700],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.all(16),
                ),
              ),
            ] else ...[
              // Test buttons when device admin is active
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _testDeviceLock,
                icon: const Icon(Icons.lock),
                label: const Text('Test Device Lock'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange[700],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.all(16),
                ),
              ),
              
              const SizedBox(height: 12),
              
              ElevatedButton.icon(
                onPressed: _showBlockingActivity,
                icon: const Icon(Icons.block),
                label: const Text('Show Blocking Activity'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red[700],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.all(16),
                ),
              ),
              
              const SizedBox(height: 12),
              
              ElevatedButton.icon(
                onPressed: _hideBlockingActivity,
                icon: const Icon(Icons.check_circle),
                label: const Text('Hide Blocking Activity'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[700],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.all(16),
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Instructions
            Card(
              color: Colors.blue[50],
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '📋 Test Instructions',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[700],
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text('1. First, request device admin permission'),
                    const Text('2. Grant permission in Android system dialog'),
                    const Text('3. Test device lock functionality'),
                    const Text('4. Try to uninstall app - it should be blocked'),
                    const Text('5. Test blocking activity show/hide'),
                    const SizedBox(height: 12),
                    Text(
                      '⚠️ Warning: Device lock will actually lock your device!',
                      style: TextStyle(
                        color: Colors.orange[700],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const Spacer(),

            // Debug Info
            if (_isDeviceAdminActive) ...[
              Text(
                'Debug: Device admin is active. Try uninstalling the app from Settings > Apps - it should be blocked.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}