import 'package:flutter/material.dart';
import '../services/device_admin_service.dart';

/// Device Admin Setup Screen
/// 
/// This screen guides users through the device administrator setup process.
/// It explains why the permission is needed and helps users activate it.
/// 
/// Features:
/// - Clear explanation of device admin purpose
/// - Step-by-step setup guide
/// - Permission status checking
/// - User-friendly interface
/// - Legal compliance information
class DeviceAdminSetupScreen extends StatefulWidget {
  const DeviceAdminSetupScreen({Key? key}) : super(key: key);

  @override
  State<DeviceAdminSetupScreen> createState() => _DeviceAdminSetupScreenState();
}

class _DeviceAdminSetupScreenState extends State<DeviceAdminSetupScreen> {
  bool _isDeviceAdminActive = false;
  bool _isLoading = false;
  bool _isChecking = true;

  @override
  void initState() {
    super.initState();
    _checkDeviceAdminStatus();
  }

  /// Check current device admin status
  Future<void> _checkDeviceAdminStatus() async {
    setState(() {
      _isChecking = true;
    });

    try {
      final bool isActive = await DeviceAdminService.isDeviceAdminActive();
      setState(() {
        _isDeviceAdminActive = isActive;
        _isChecking = false;
      });
    } catch (e) {
      setState(() {
        _isDeviceAdminActive = false;
        _isChecking = false;
      });
    }
  }

  /// Request device admin permission
  Future<void> _requestDeviceAdminPermission() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final bool granted = await DeviceAdminService.requestDeviceAdminPermission();
      
      setState(() {
        _isDeviceAdminActive = granted;
        _isLoading = false;
      });

      if (granted) {
        _showSuccessDialog();
      } else {
        _showErrorDialog('Device administrator permission was not granted. This is required for EMI security.');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorDialog('Error requesting device admin permission: $e');
    }
  }

  /// Show success dialog
  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.check_circle, color: Colors.green, size: 48),
        title: const Text('Device Protection Activated'),
        content: const Text(
          'Your device is now protected during the EMI period. '
          'The app cannot be uninstalled until all payments are completed.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              if (Navigator.canPop(context)) {
                Navigator.of(context).pop(true); // Return success to previous screen
              }
            },
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  /// Show error dialog
  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.error, color: Colors.red, size: 48),
        title: const Text('Setup Required'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Device Protection Setup'),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
      ),
      body: _isChecking
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status Card
                  Card(
                    color: _isDeviceAdminActive ? Colors.green[50] : Colors.orange[50],
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(
                            _isDeviceAdminActive ? Icons.shield : Icons.warning,
                            color: _isDeviceAdminActive ? Colors.green : Colors.orange,
                            size: 32,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _isDeviceAdminActive 
                                      ? 'Device Protection Active' 
                                      : 'Device Protection Required',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: _isDeviceAdminActive ? Colors.green[700] : Colors.orange[700],
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _isDeviceAdminActive
                                      ? 'Your EMI agreement is secured'
                                      : 'Please activate device administrator',
                                  style: TextStyle(
                                    color: _isDeviceAdminActive ? Colors.green[600] : Colors.orange[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Explanation Section
                  const Text(
                    '🛡️ Why Device Administrator?',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  
                  const Text(
                    'Fasst Pay requires device administrator permission to ensure EMI payment security and compliance with your loan agreement.',
                    style: TextStyle(fontSize: 16),
                  ),

                  const SizedBox(height: 16),

                  // Features List
                  _buildFeatureItem(
                    Icons.block,
                    'Prevent App Uninstallation',
                    'Protects the app from being removed during EMI period',
                  ),
                  _buildFeatureItem(
                    Icons.lock,
                    'Remote Device Locking',
                    'Allows secure device locking for payment reminders',
                  ),
                  _buildFeatureItem(
                    Icons.security,
                    'Payment Security',
                    'Ensures compliance with EMI terms and conditions',
                  ),
                  _buildFeatureItem(
                    Icons.visibility,
                    'Access Monitoring',
                    'Monitors unauthorized attempts to bypass security',
                  ),

                  const SizedBox(height: 24),

                  // Privacy Section
                  Card(
                    color: Colors.blue[50],
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.privacy_tip, color: Colors.blue[700]),
                              const SizedBox(width: 8),
                              Text(
                                'Your Privacy & Rights',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue[700],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Text('• No personal data is accessed or stored'),
                          const Text('• Only security functions are used'),
                          const Text('• Permission can be revoked after EMI completion'),
                          const Text('• Complies with data protection regulations'),
                          const Text('• You agreed to these terms in your loan agreement'),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Action Button
                  if (!_isDeviceAdminActive) ...[
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _requestDeviceAdminPermission,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[700],
                          foregroundColor: Colors.white,
                        ),
                        child: _isLoading
                            ? const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  Text('Activating...'),
                                ],
                              )
                            : const Text(
                                'Activate Device Administrator',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'This will open Android settings where you can grant device administrator permission.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                        fontStyle: FontStyle.italic,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ] else ...[
                    // Already activated
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.green[100],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green[300]!),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.check_circle, color: Colors.green[700], size: 48),
                          const SizedBox(height: 8),
                          Text(
                            'Device Administrator Active',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.green[700],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Your device is protected during the EMI period',
                            style: TextStyle(color: Colors.green[600]),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green[700],
                          foregroundColor: Colors.white,
                        ),
                        child: const Text(
                          'Continue',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // Legal Notice
                  Card(
                    color: Colors.grey[50],
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.gavel, color: Colors.grey[700]),
                              const SizedBox(width: 8),
                              Text(
                                'Legal Notice',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'By activating device administrator, you confirm that you have read and agreed to the terms and conditions of your EMI loan agreement. This permission is required for loan security and compliance.',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  /// Build feature item widget
  Widget _buildFeatureItem(IconData icon, String title, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.blue[700], size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}