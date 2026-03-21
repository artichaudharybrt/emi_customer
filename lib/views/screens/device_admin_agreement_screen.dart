import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/device_admin_lock_service.dart';
import '../../services/system_overlay_service.dart';
import '../../utils/responsive.dart';

/// Agreement screen shown before enabling Device Admin
/// User must agree to terms before device admin can be activated
class DeviceAdminAgreementScreen extends StatefulWidget {
  const DeviceAdminAgreementScreen({super.key});

  @override
  State<DeviceAdminAgreementScreen> createState() => _DeviceAdminAgreementScreenState();
}

class _DeviceAdminAgreementScreenState extends State<DeviceAdminAgreementScreen> {
  bool _agreedToTerms = false;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Device Security Setup",
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        automaticallyImplyLeading: false, // Prevent back button
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(Responsive.width(4, context)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Center(
              child: Icon(
                Icons.security,
                size: 80,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            SizedBox(height: Responsive.height(2, context)),
            
            Text(
              "Device Security Agreement",
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: Responsive.height(2, context)),
            
            // Terms section
            _buildTermsSection(),
            SizedBox(height: Responsive.height(3, context)),
            
            // Agreement checkbox
            CheckboxListTile(
              value: _agreedToTerms,
              onChanged: (value) {
                setState(() {
                  _agreedToTerms = value ?? false;
                });
              },
              title: Text(
                "I agree to the terms and conditions",
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              controlAffinity: ListTileControlAffinity.leading,
            ),
            SizedBox(height: Responsive.height(3, context)),
            
            // Permissions list
            _buildPermissionsList(),
            SizedBox(height: Responsive.height(4, context)),
            
            // Continue button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _agreedToTerms && !_isLoading ? _onContinue : null,
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Theme.of(context).colorScheme.primary,
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        "Continue",
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTermsSection() {
    return Container(
      padding: EdgeInsets.all(Responsive.width(4, context)),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Important Terms:",
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: Responsive.height(1, context)),
          _buildTermItem(
            "If your EMI payment is overdue, this app may temporarily restrict device access.",
          ),
          _buildTermItem(
            "Device administrator permission is required to enforce security measures.",
          ),
          _buildTermItem(
            "Display over other apps permission is required for security notifications.",
          ),
          _buildTermItem(
            "You agreed to these terms when taking the loan.",
          ),
        ],
      ),
    );
  }

  Widget _buildTermItem(String text) {
    return Padding(
      padding: EdgeInsets.only(bottom: Responsive.height(1, context)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.check_circle,
            color: Colors.green,
            size: 20,
          ),
          SizedBox(width: Responsive.width(2, context)),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey[800],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionsList() {
    return Container(
      padding: EdgeInsets.all(Responsive.width(4, context)),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Required Permissions:",
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.blue[900],
            ),
          ),
          SizedBox(height: Responsive.height(1.5, context)),
          _buildPermissionItem(
            Icons.admin_panel_settings,
            "Device Administrator",
            "Prevents unauthorized uninstallation during EMI period",
          ),
          _buildPermissionItem(
            Icons.layers,
            "Display Over Other Apps",
            "Shows security notifications and warnings",
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionItem(IconData icon, String title, String description) {
    return Padding(
      padding: EdgeInsets.only(bottom: Responsive.height(1.5, context)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: Colors.blue[700],
            size: 24,
          ),
          SizedBox(width: Responsive.width(3, context)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue[900],
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  description,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.blue[700],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _onContinue() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Step 1: Request Device Admin permission
      debugPrint('[Agreement] Requesting Device Admin permission...');
      await DeviceAdminLockService.requestDeviceAdmin();
      
      // Wait a bit for user to grant/deny
      await Future.delayed(const Duration(seconds: 2));
      
      // Check if device admin is active
      final isAdminActive = await DeviceAdminLockService.isDeviceAdminActive();
      if (!isAdminActive) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Device Admin permission is required. Please enable it.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        setState(() {
          _isLoading = false;
        });
        return;
      }
      
      // Step 2: Request Overlay permission
      debugPrint('[Agreement] Requesting Overlay permission...');
      final hasOverlayPermission = await SystemOverlayService.hasOverlayPermission();
      
      if (!hasOverlayPermission) {
        await SystemOverlayService.requestOverlayPermission();
        // Wait a bit for user to grant/deny
        await Future.delayed(const Duration(seconds: 2));
        
        final hasPermission = await SystemOverlayService.hasOverlayPermission();
        if (!hasPermission) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Overlay permission is required. Please enable it.'),
                backgroundColor: Colors.orange,
              ),
            );
          }
          setState(() {
            _isLoading = false;
          });
          return;
        }
      }
      
      // Step 3: All permissions granted - navigate to next screen
      if (mounted) {
        Navigator.of(context).pop(true); // Return success
      }
    } catch (e) {
      debugPrint('[Agreement] Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}

