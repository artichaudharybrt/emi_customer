import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/system_overlay_service.dart';
import '../../utils/responsive.dart';

class OverlayPermissionScreen extends StatefulWidget {
  const OverlayPermissionScreen({super.key});

  @override
  State<OverlayPermissionScreen> createState() => _OverlayPermissionScreenState();
}

class _OverlayPermissionScreenState extends State<OverlayPermissionScreen> {
  bool _isChecking = false;
  bool _hasPermission = false;
  // Show tip on Android (Android 15+ and some OEMs show "App was denied access" for overlay; user must allow restricted settings first)
  bool get _showRestrictedSettingsTip => Platform.isAndroid;

  @override
  void initState() {
    super.initState();
    _checkPermission();
  }

  Future<void> _checkPermission() async {
    setState(() => _isChecking = true);
    
    try {
      final hasPermission = await SystemOverlayService.hasOverlayPermission();
      setState(() {
        _hasPermission = hasPermission;
        _isChecking = false;
      });
      
      if (hasPermission) {
        // Auto-close if permission is already granted (only pop if stack allows)
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted && Navigator.canPop(context)) {
            Navigator.of(context).pop(true);
          }
        });
      }
    } catch (e) {
      setState(() => _isChecking = false);
      debugPrint('Error checking overlay permission: $e');
    }
  }

  Future<void> _requestPermission() async {
    try {
      await SystemOverlayService.requestOverlayPermission();
      
      // Show dialog explaining next steps (including "App was denied access" fix for Android 15+)
      if (mounted) {
        final restrictedTip = _showRestrictedSettingsTip
            ? '\n\nIf you see "App was denied access":\nGo to Settings → Apps → Fasst Pay → ⋮ menu → "Allow restricted settings", then return here and enable "Display over other apps".'
            : '';
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(
              'Permission Required',
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
            ),
            content: SingleChildScrollView(
              child: Text(
                'Please enable "Display over other apps" for Fasst Pay in the settings that just opened, then return to the app.$restrictedTip',
                style: GoogleFonts.poppins(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  if (Navigator.canPop(context)) Navigator.of(context).pop();
                  _checkPermission(); // Re-check permission
                },
                child: Text(
                  'I\'ve Enabled It',
                  style: GoogleFonts.poppins(color: Colors.blue),
                ),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      debugPrint('Error requesting overlay permission: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error requesting permission: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        title: Text(
          'System Overlay Permission',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: Responsive.padding(
            context,
            mobile: const EdgeInsets.all(24),
            tablet: const EdgeInsets.all(32),
            desktop: const EdgeInsets.all(40),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
            // Icon
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: _hasPermission ? Colors.green.shade100 : Colors.orange.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                _hasPermission ? Icons.check_circle : Icons.security,
                size: 60,
                color: _hasPermission ? Colors.green : Colors.orange,
              ),
            ),
            
            SizedBox(height: Responsive.spacing(context, mobile: 32, tablet: 40, desktop: 48)),
            
            // Title
            Text(
              _hasPermission ? 'Permission Granted!' : 'System Overlay Permission Required',
              style: GoogleFonts.poppins(
                fontSize: Responsive.fontSize(context, mobile: 24, tablet: 28, desktop: 32),
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            
            SizedBox(height: Responsive.spacing(context, mobile: 16, tablet: 20, desktop: 24)),
            
            // Description
            Text(
              _hasPermission
                  ? 'Fasst Pay can now display system-wide overlays to ensure device security.'
                  : 'Fasst Pay needs permission to display overlays over other apps. This ensures that payment reminders are always visible, even when using other applications.',
              style: GoogleFonts.poppins(
                fontSize: Responsive.fontSize(context, mobile: 16, tablet: 18, desktop: 20),
                color: Colors.black54,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            
            if (!_hasPermission && _showRestrictedSettingsTip) ...[
              SizedBox(height: Responsive.spacing(context, mobile: 16, tablet: 20, desktop: 24)),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, color: Colors.amber.shade800, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'If you see "App was denied access": Open Settings → Apps → Fasst Pay → ⋮ → Allow restricted settings, then enable "Display over other apps".',
                        style: GoogleFonts.poppins(fontSize: 12, color: Colors.black87),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            
            SizedBox(height: Responsive.spacing(context, mobile: 32, tablet: 40, desktop: 48)),
            
            // Features list
            if (!_hasPermission) ...[
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    _buildFeatureItem(
                      icon: Icons.security,
                      title: 'Enhanced Security',
                      description: 'Ensures payment reminders are always visible',
                    ),
                    const Divider(height: 24),
                    _buildFeatureItem(
                      icon: Icons.notifications_active,
                      title: 'System-Wide Alerts',
                      description: 'Works even when app is in background',
                    ),
                    const Divider(height: 24),
                    _buildFeatureItem(
                      icon: Icons.lock,
                      title: 'Device Protection',
                      description: 'Prevents unauthorized access during lock',
                    ),
                  ],
                ),
              ),
              
              SizedBox(height: Responsive.spacing(context, mobile: 32, tablet: 40, desktop: 48)),
            ],
            
            // Action buttons
            if (_isChecking)
              const CircularProgressIndicator()
            else if (_hasPermission)
              ElevatedButton(
                onPressed: () {
                  if (Navigator.canPop(context)) Navigator.of(context).pop(true);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  'Continue',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )
            else
              Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _requestPermission,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1F6AFF),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        'Grant Permission',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  
                  SizedBox(height: Responsive.spacing(context, mobile: 12, tablet: 16, desktop: 20)),
                  
                  TextButton(
                    onPressed: () {
                      if (Navigator.canPop(context)) Navigator.of(context).pop(false);
                    },
                    child: Text(
                      'Skip for Now',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.black54,
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
        ),
      ),
    );
  }

  Widget _buildFeatureItem({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFF1F6AFF).withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: const Color(0xFF1F6AFF),
            size: 20,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.black54,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}