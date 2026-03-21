import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/app_overlay_service.dart';

/// Widget that completely blocks back button when overlay is showing
class BackButtonBlocker extends StatelessWidget {
  final Widget child;
  
  const BackButtonBlocker({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // Never allow pop
      onPopInvokedWithResult: (bool didPop, dynamic result) async {
        await _handleBackButton(context, didPop);
      },
      child: WillPopScope(
        onWillPop: () async {
          await _handleBackButton(context, false);
          return false; // Never allow back button
        },
        child: child,
      ),
    );
  }
  
  Future<void> _handleBackButton(BuildContext context, bool didPop) async {
    debugPrint('[BackButtonBlocker] ========== BACK BUTTON INTERCEPTED ==========');
    debugPrint('[BackButtonBlocker] didPop: $didPop');
    
    try {
      // Check if overlay should be showing
      final isOverlayShowing = await AppOverlayService.isOverlayShowing();
      debugPrint('[BackButtonBlocker] Overlay showing: $isOverlayShowing');
      
      if (isOverlayShowing) {
        debugPrint('[BackButtonBlocker] 🚫 BACK BUTTON COMPLETELY BLOCKED');
        debugPrint('[BackButtonBlocker] Device is locked - preventing app exit');
        debugPrint('[BackButtonBlocker] Overlay must be dismissed by payment or unlock');
        
        // Show a brief message to user (optional)
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Device is locked. Please complete payment to unlock.'),
              duration: Duration(seconds: 2),
              backgroundColor: Colors.red,
            ),
          );
        }
        
        // Ensure overlay is still visible
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) {
            AppOverlayService.checkAndShowOverlay(context);
          }
        });
        
        // CRITICAL: Do nothing else - completely block back button
        return;
      } else {
        debugPrint('[BackButtonBlocker] ✅ Overlay not showing - allowing normal behavior');
        
        // Check if we can navigate back
        final navigator = Navigator.of(context);
        if (navigator.canPop()) {
          debugPrint('[BackButtonBlocker] Popping current route');
          navigator.pop();
        } else {
          debugPrint('[BackButtonBlocker] No routes to pop - exiting app');
          SystemNavigator.pop();
        }
      }
    } catch (e) {
      debugPrint('[BackButtonBlocker] Error handling back button: $e');
      // In case of error, be safe and block back button
      debugPrint('[BackButtonBlocker] Error occurred - blocking back button as safety measure');
    }
  }
}