import 'package:flutter/material.dart';
import '../services/device_admin_service.dart';
import '../services/app_protection_service.dart';

/// App Protection Setup Screen
/// 
/// This screen guides users through setting up comprehensive app protection
/// including device admin, accessibility service, and overlay permissions.
/// 
/// Features:
/// - Shows current protection status
/// - Guides through each protection feature setup
/// - Explains why each permission is needed
/// - Tests protection features
/// - Provides troubleshooting help
class AppProtectionSetupScreen extends StatefulWidget {
  const AppProtectionSetupScreen({Key? key}) : super(key: key);

  @override
  State<AppProtectionSetupScreen> createState() => _AppProtectionSetupScreenState();
}

class _AppProtectionSetupScreenState extends State<AppProtectionSetupScreen> {
  Map<String, dynamic> _protectionStatus = {};
  bool _isLoading = false;
  bool _isChecking = true;

  @override
  void initState() {
    super.initState();
    _checkProtectionStatus();
  }

  /// Check current protection status
  Future<void> _checkProtectionStatus() async {
    setState(() {
      _isChecking = true;
    });

    try {
      final status = await AppProtectionService.getProtectionStatus();
      setState(() {
        _protectionStatus = status;
        _isChecking = false;
      });
    } catch (e) {
      setState(() {
        _protectionStatus = {'error': e.toString()};
        _isChecking = false;
      });
    }
  }

  /// Request device admin permission
  Future<void> _requestDeviceAdmin() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final bool granted = await DeviceAdminService.requestDeviceAdminPermission();
      
      if (granted) {
        _showSnackBar('Device administrator activated!', Colors.green);
      } else {
        _showSnackBar('Device administrator permission denied', Colors.red);
      }
    } catch (e) {
      _showSnackBar('Error: $e', Colors.red);
    } finally {
      setState(() {
        _isLoading = false;
      });
      _checkProtectionStatus();
    }
  }

  /// Request accessibility service permission
  Future<void> _requestAccessibilityService() async {
    try {
      await AppProtectionService.requestAccessibilityPermission();
      _showSnackBar('Accessibility settings opened. Please enable Fasst Pay Protection Service.', Colors.blue);
    } catch (e) {
      _showSnackBar('Error: $e', Colors.red);
    }
  }

  /// Test protection overlay
  Future<void> _testProtectionOverlay() async {
    try {
      await AppProtectionService.showProtectionOverlay(
        title: 'Protection Test',
        message: 'This is a test of the protection overlay. Tap back button to dismiss.',
      );
      _showSnackBar('Protection overlay shown. Use back button to dismiss.', Colors.blue);
    } catch (e) {
      _showSnackBar('Error: $e', Colors.red);
    }
  }

  /// Show snackbar
  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('App Protection Setup'),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _checkProtectionStatus,
          ),
        ],
      ),
      body: _isChecking
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Protection Status Overview
                  _buildProtectionStatusCard(),
                  
                  const SizedBox(height: 24),
                  
                  // Protection Features
                  const Text(
                    '🛡️ Protection Features',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  
                  // Device Admin
                  _buildProtectionFeatureCard(
                    title: 'Device Administrator',
                    description: 'Prevents app uninstallation during EMI period',
                    isActive: _protectionStatus['deviceAdminActive'] ?? false,
                    onSetup: _requestDeviceAdmin,
                    icon: Icons.admin_panel_settings,
                    importance: 'Critical',
                    importanceColor: Colors.red,
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Accessibility Service
                  _buildProtectionFeatureCard(
                    title: 'App Protection Service',
                    description: 'Monitors app control attempts (App info, Pause app)',
                    isActive: _protectionStatus['accessibilityServiceEnabled'] ?? false,
                    onSetup: _requestAccessibilityService,
                    icon: Icons.security,
                    importance: 'Important',
                    importanceColor: Colors.orange,
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Overlay Permission
                  _buildProtectionFeatureCard(
                    title: 'Overlay Permission',
                    description: 'Shows protection screens when needed',
                    isActive: _protectionStatus['overlayPermissionGranted'] ?? false,
                    onSetup: () async {
                      // This would open overlay permission settings
                      _showSnackBar('Overlay permission setup not implemented yet', Colors.blue);
                    },
                    icon: Icons.layers,
                    importance: 'Recommended',
                    importanceColor: Colors.blue,
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Test Section
                  if (_protectionStatus['protectionLevel'] != null && _protectionStatus['protectionLevel'] > 0) ...[
                    const Text(
                      '🧪 Test Protection',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Test Protection Features',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 12),
                            const Text('Test the protection overlay to ensure it works correctly.'),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: _testProtectionOverlay,
                                icon: const Icon(Icons.play_arrow),
                                label: const Text('Test Protection Overlay'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue[700],
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                  ],
                  
                  // Instructions
                  _buildInstructionsCard(),
                  
                  const SizedBox(height: 24),
                  
                  // Recommendations
                  if (_protectionStatus['recommendations'] != null) ...[
                    _buildRecommendationsCard(),
                    const SizedBox(height: 24),
                  ],
                  
                  // Legal Notice
                  _buildLegalNoticeCard(),
                ],
              ),
            ),
    );
  }

  /// Build protection status overview card
  Widget _buildProtectionStatusCard() {
    final protectionLevel = _protectionStatus['protectionLevel'] ?? 0;
    final protectionLevelText = _protectionStatus['protectionLevelText'] ?? 'Unknown';
    final isFullyProtected = _protectionStatus['isFullyProtected'] ?? false;
    
    return Card(
      color: isFullyProtected ? Colors.green[50] : Colors.orange[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(
              isFullyProtected ? Icons.shield : Icons.warning,
              color: isFullyProtected ? Colors.green : Colors.orange,
              size: 48,
            ),
            const SizedBox(height: 12),
            Text(
              protectionLevelText,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isFullyProtected ? Colors.green[700] : Colors.orange[700],
              ),
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: protectionLevel / 100,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(
                isFullyProtected ? Colors.green : Colors.orange,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '$protectionLevel% Protection Active',
              style: TextStyle(
                color: isFullyProtected ? Colors.green[600] : Colors.orange[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build protection feature card
  Widget _buildProtectionFeatureCard({
    required String title,
    required String description,
    required bool isActive,
    required VoidCallback onSetup,
    required IconData icon,
    required String importance,
    required Color importanceColor,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              icon,
              color: isActive ? Colors.green : Colors.grey,
              size: 32,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: importanceColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          importance,
                          style: TextStyle(
                            fontSize: 12,
                            color: importanceColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
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
            const SizedBox(width: 16),
            Column(
              children: [
                Icon(
                  isActive ? Icons.check_circle : Icons.cancel,
                  color: isActive ? Colors.green : Colors.red,
                  size: 24,
                ),
                const SizedBox(height: 8),
                if (!isActive)
                  ElevatedButton(
                    onPressed: _isLoading ? null : onSetup,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: importanceColor,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(80, 32),
                    ),
                    child: const Text('Setup', style: TextStyle(fontSize: 12)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Build instructions card
  Widget _buildInstructionsCard() {
    return Card(
      color: Colors.blue[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info, color: Colors.blue[700]),
                const SizedBox(width: 8),
                Text(
                  'Setup Instructions',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[700],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text('1. Enable Device Administrator first (most important)'),
            const Text('2. Enable App Protection Service for monitoring'),
            const Text('3. Grant Overlay Permission for protection screens'),
            const Text('4. Test protection features to ensure they work'),
            const SizedBox(height: 12),
            Text(
              '⚠️ All permissions are required for complete EMI security',
              style: TextStyle(
                color: Colors.blue[700],
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build recommendations card
  Widget _buildRecommendationsCard() {
    final recommendations = _protectionStatus['recommendations'] as List<dynamic>? ?? [];
    
    return Card(
      color: Colors.amber[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.lightbulb, color: Colors.amber[700]),
                const SizedBox(width: 8),
                Text(
                  'Recommendations',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.amber[700],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...recommendations.map((rec) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text('• $rec'),
            )),
          ],
        ),
      ),
    );
  }

  /// Build legal notice card
  Widget _buildLegalNoticeCard() {
    return Card(
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
              'These protection features are part of your EMI loan agreement. '
              'They ensure loan security and compliance during the EMI period. '
              'All permissions can be revoked after EMI completion.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}