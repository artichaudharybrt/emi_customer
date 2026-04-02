import 'package:flutter/material.dart';
import '../../utils/responsive.dart';
import '../../services/auth_service.dart';
import '../../services/system_overlay_service.dart';
import '../../services/native_location_tracking_service.dart';
import '../../services/user_location_service.dart';
import '../../services/sim_details_service.dart';
import '../../services/launcher_visibility_service.dart';
import '../../services/uninstall_flag_service.dart';
import '../../theme/app_theme.dart';
import 'login_screen.dart';
import 'root_shell.dart';
import 'overlay_permission_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeIn),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _animationController.forward();
    _navigateToNext();
  }

  Future<void> _navigateToNext() async {
    // Only request phone permission here; device-sim-details API is called after login (with token)
    await SimDetailsService.requestPermissionOnly();

    await Future.delayed(const Duration(seconds: 3));
    if (!mounted) return;

    final hasToken = await _authService.hasAuthToken();
    if (!mounted) return;

    // If overlay permission not granted, show explanation screen first (don't auto-open settings).
    // This avoids "App was denied access" on Android 15+ and other devices - user taps "Grant" to open settings.
    final hasOverlay = await SystemOverlayService.hasOverlayPermission();
    if (!hasOverlay && mounted) {
      final granted = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => const OverlayPermissionScreen(),
        ),
      );
      if (granted == true) {
        debugPrint('[SplashScreen] Overlay permission granted by user');
      }
    }

    if (!mounted) return;

    // When user opens app and is logged in → send location and post SIM details (with token)
    if (hasToken) {
      NativeLocationTrackingService.startIfPossible();
      UninstallFlagService.refreshInBackground();
      UserLocationService.fetchAndSendLocation().then((_) {
        debugPrint('[SplashScreen] Location sent on app open');
      }).catchError((e) {
        debugPrint('[SplashScreen] Location on open failed: $e');
      });
      SimDetailsService.postSimDetailsIfAllowed().then((_) {
        debugPrint('[SplashScreen] SIM details sent if permission allowed');
      }).catchError((e) {
        debugPrint('[SplashScreen] SIM details on open failed: $e');
      });
    }

    if (!mounted) return;

    await LauncherVisibilityService.syncWithStoredSession();

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => hasToken ? const RootShell() : const LoginScreen(),
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: AppTheme.brandGradient,
        ),
        child: SafeArea(
          child: ResponsivePage(
            child: Center(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.accentGreen.withOpacity(0.28),
                              blurRadius: 34,
                              offset: const Offset(0, 16),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(28),
                          child: Image.asset(
                            'assets/images/fasstpay_logo.png',
                            width: Responsive.spacing(context, mobile: 160, tablet: 200, desktop: 240),
                            height: Responsive.spacing(context, mobile: 160, tablet: 200, desktop: 240),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),

                      SizedBox(height: Responsive.spacing(context, mobile: 30, tablet: 36, desktop: 42)),



                      // Tagline
                      Text(
                        'Your trusted EMI management partner',
                        style: TextStyle(
                          fontSize: Responsive.fontSize(context, mobile: 16, tablet: 18, desktop: 20),
                          color: AppTheme.textOnDark.withOpacity(0.92),
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),

                      SizedBox(height: Responsive.spacing(context, mobile: 60, tablet: 70, desktop: 80)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}



