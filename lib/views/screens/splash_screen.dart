import 'package:flutter/material.dart';
import '../../utils/responsive.dart';
import '../../services/auth_service.dart';
import 'login_screen.dart';
import 'root_shell.dart';

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
    await Future.delayed(const Duration(seconds: 3));
    if (!mounted) return;

    final hasToken = await _authService.hasAuthToken();
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
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF1F6AFF),
              const Color(0xFF4B89FF),
              const Color(0xFF6BA3FF),
            ],
          ),
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
                      // Logo Container
                      Container(
                        padding: EdgeInsets.all(
                          Responsive.spacing(context, mobile: 20, tablet: 24, desktop: 28),
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 30,
                              offset: const Offset(0, 15),
                            ),
                          ],
                        ),
                        child: CircleAvatar(
                          radius: Responsive.spacing(context, mobile: 40, tablet: 50, desktop: 60),
                          backgroundColor: const Color(0xFF1F6AFF),
                          child: Text(
                            'E',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: Responsive.fontSize(context, mobile: 50, tablet: 60, desktop: 70),
                            ),
                          ),
                        ),
                      ),
                      
                      SizedBox(height: Responsive.spacing(context, mobile: 30, tablet: 36, desktop: 42)),

                      // App Name
                      Text(
                        'SafeEMI',
                        style: TextStyle(
                          fontSize: Responsive.fontSize(context, mobile: 36, tablet: 42, desktop: 48),
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: -1.0,
                          shadows: [
                            Shadow(
                              color: Colors.black.withOpacity(0.2),
                              offset: const Offset(0, 4),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: Responsive.spacing(context, mobile: 12, tablet: 14, desktop: 16)),

                      // Tagline
                      Text(
                        'Your trusted EMI management partner',
                        style: TextStyle(
                          fontSize: Responsive.fontSize(context, mobile: 16, tablet: 18, desktop: 20),
                          color: Colors.white.withOpacity(0.9),
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),

                      SizedBox(height: Responsive.spacing(context, mobile: 60, tablet: 70, desktop: 80)),

                      // Loading Indicator
                      SizedBox(
                        width: Responsive.spacing(context, mobile: 30, tablet: 35, desktop: 40),
                        height: Responsive.spacing(context, mobile: 30, tablet: 35, desktop: 40),
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white.withOpacity(0.8),
                          ),
                        ),
                      ),
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



