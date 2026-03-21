import 'package:flutter/material.dart';
import '../../utils/responsive.dart';
import '../../services/auth_service.dart';
import '../../services/fcm_service.dart';
import '../../services/user_location_service.dart';
import '../../services/sim_details_service.dart';
import 'root_shell.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailOrMobileController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();
  final _fcmService = FCMService();
  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _isGoogleLoading = false;
  bool _isGoogleAccountBound = false;
  Map<String, dynamic>? _storedGoogleAccount;

  @override
  void initState() {
    super.initState();
    _checkGoogleAccountStatus();
  }

  @override
  void dispose() {
    _emailOrMobileController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _checkGoogleAccountStatus() async {
    final isBound = await _authService.isGoogleAccountBound();
    final storedAccount = await _authService.getStoredGoogleAccount();
    
    if (mounted) {
      setState(() {
        _isGoogleAccountBound = isBound;
        _storedGoogleAccount = storedAccount;
      });
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isGoogleLoading = true);

    try {
      final account = await _authService.signInWithGoogle();
      
      if (account != null && mounted) {
        // Refresh status
        await _checkGoogleAccountStatus();
        
        // Register FCM token after Google sign-in
        print('[Login] Registering FCM token after Google sign-in...');
        try {
          final registered = await _fcmService.registerTokenAfterLogin();
          if (registered) {
            print('[Login] ✅ FCM token registered successfully');
          } else {
            print('[Login] ⚠️ FCM token registration failed (will retry later)');
          }
        } catch (e) {
          print('[Login] ⚠️ Error registering FCM token: $e');
          // Don't block login if FCM registration fails
        }

        // Send location to API after Google login (same as email login)
        UserLocationService.fetchAndSendLocation().then((_) {
          print('[Login] ✅ Location sent after Google login');
        }).catchError((e) {
          print('[Login] ⚠️ Location after Google login failed: $e');
        });
        // Post SIM details with token (user allowed permission on splash, now logged in)
        SimDetailsService.postSimDetailsIfAllowed().then((ok) {
          if (ok) print('[Login] ✅ SIM details sent after Google login');
        }).catchError((e) {
          print('[Login] ⚠️ SIM details after Google login failed: $e');
        });
        
        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Signed in with ${account.email}'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }

        // Navigate to app
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const RootShell()),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Google Sign-In failed: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isGoogleLoading = false);
      }
    }
  }

  Future<void> _handleLogin() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      try {
        // Login user
        await _authService.login(
          emailOrMobile: _emailOrMobileController.text.trim(),
          password: _passwordController.text,
        );

        if (!mounted) return;

        // Register FCM token after successful login
        print('[Login] Registering FCM token after login...');
        try {
          final registered = await _fcmService.registerTokenAfterLogin();
          if (registered) {
            print('[Login] ✅ FCM token registered successfully');
          } else {
            print('[Login] ⚠️ FCM token registration failed (will retry later)');
          }
        } catch (e) {
          print('[Login] ⚠️ Error registering FCM token: $e');
          // Don't block login if FCM registration fails
        }

        // Send location to API after login (as requested)
        UserLocationService.fetchAndSendLocation().then((_) {
          print('[Login] ✅ Location sent after login');
        }).catchError((e) {
          print('[Login] ⚠️ Location after login failed: $e');
        });
        // Post SIM details with token (user allowed permission on splash, now logged in)
        SimDetailsService.postSimDetailsIfAllowed().then((ok) {
          if (ok) print('[Login] ✅ SIM details sent after login');
        }).catchError((e) {
          print('[Login] ⚠️ SIM details after login failed: $e');
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Logged in successfully'),
            backgroundColor: Colors.green,
          ),
        );

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const RootShell()),
        );
      } catch (e) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F5FA),
      body: SafeArea(
        child: ResponsivePage(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              vertical: Responsive.spacing(context, mobile: 20, tablet: 30, desktop: 40),
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(height: Responsive.spacing(context, mobile: 20, tablet: 40, desktop: 60)),

                  // Logo
                  Container(
                    padding: EdgeInsets.all(
                      Responsive.spacing(context, mobile: 12, tablet: 14, desktop: 16),
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1F6AFF), Color(0xFF4B89FF)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF1F6AFF).withOpacity(0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: CircleAvatar(
                      radius: Responsive.spacing(context, mobile: 35, tablet: 42, desktop: 50),
                      backgroundColor: Colors.white,
                      child: Text(
                        'E',
                        style: TextStyle(
                          color: const Color(0xFF1F6AFF),
                          fontWeight: FontWeight.w900,
                          fontSize: Responsive.fontSize(context, mobile: 40, tablet: 48, desktop: 56),
                        ),
                      ),
                    ),
                  ),

                  SizedBox(height: Responsive.spacing(context, mobile: 30, tablet: 36, desktop: 42)),

                  // Welcome Text
                  Text(
                    'Welcome Back',
                    style: TextStyle(
                      fontSize: Responsive.fontSize(context, mobile: 28, tablet: 32, desktop: 36),
                      fontWeight: FontWeight.w800,
                      color: Colors.black87,
                      letterSpacing: -0.5,
                    ),
                  ),

                  SizedBox(height: Responsive.spacing(context, mobile: 8, tablet: 10, desktop: 12)),

                  Text(
                    'Sign in to continue to Fasst Pay',
                    style: TextStyle(
                      fontSize: Responsive.fontSize(context, mobile: 15, tablet: 16, desktop: 17),
                      color: Colors.black54,
                      fontWeight: FontWeight.w500,
                    ),
                  ),

                  SizedBox(height: Responsive.spacing(context, mobile: 40, tablet: 48, desktop: 56)),

                  // FRP Protection Info Card
                  if (_isGoogleAccountBound && _storedGoogleAccount != null)
                    _buildFRPProtectionCard(context),

                  // Google Sign-In Button (Prominent)
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _isGoogleLoading ? null : _handleGoogleSignIn,
                      icon: _isGoogleLoading
                          ? SizedBox(
                              width: Responsive.spacing(context, mobile: 18, tablet: 20, desktop: 22),
                              height: Responsive.spacing(context, mobile: 18, tablet: 20, desktop: 22),
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(const Color(0xFF1F6AFF)),
                              ),
                            )
                          : Icon(
                              Icons.account_circle,
                              size: Responsive.spacing(context, mobile: 24, tablet: 26, desktop: 28),
                              color: const Color(0xFF4285F4),
                            ),
                      label: Text(
                        _isGoogleAccountBound && _storedGoogleAccount != null
                            ? 'Continue with ${_storedGoogleAccount!['email']}'
                            : 'Sign in with Google (Recommended)',
                        style: TextStyle(
                          fontSize: Responsive.fontSize(context, mobile: 15, tablet: 16, desktop: 17),
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF1F6AFF),
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: const Color(0xFF1F6AFF),
                          width: 2,
                        ),
                        padding: EdgeInsets.symmetric(
                          vertical: Responsive.spacing(context, mobile: 14, tablet: 16, desktop: 18),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            Responsive.spacing(context, mobile: 16, tablet: 18, desktop: 20),
                          ),
                        ),
                      ),
                    ),
                  ),

                  SizedBox(height: Responsive.spacing(context, mobile: 24, tablet: 28, desktop: 32)),

                  // Divider
                  Row(
                    children: [
                      Expanded(
                        child: Divider(
                          color: Colors.black.withOpacity(0.2),
                          thickness: 1,
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: Responsive.spacing(context, mobile: 16, tablet: 18, desktop: 20),
                        ),
                        child: Text(
                          'OR',
                          style: TextStyle(
                            fontSize: Responsive.fontSize(context, mobile: 14, tablet: 15, desktop: 16),
                            color: Colors.black54,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Divider(
                          color: Colors.black.withOpacity(0.2),
                          thickness: 1,
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: Responsive.spacing(context, mobile: 24, tablet: 28, desktop: 32)),

                  // Phone Number Field
                  _buildTextField(
                    context,
                    controller: _emailOrMobileController,
                    label: 'Email or Mobile',
                    hint: 'Enter email address or mobile number',
                    prefixIcon: Icons.person_outline,
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your email or mobile';
                      }
                      if (value.length < 4) {
                        return 'Please enter a valid email or mobile';
                      }
                      return null;
                    },
                  ),

                  SizedBox(height: Responsive.spacing(context, mobile: 20, tablet: 24, desktop: 28)),

                  // Password Field
                  _buildTextField(
                    context,
                    controller: _passwordController,
                    label: 'Password',
                    hint: 'Enter your password',
                    prefixIcon: Icons.lock_outline,
                    obscureText: _obscurePassword,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                        color: Colors.black54,
                      ),
                      onPressed: () {
                        setState(() => _obscurePassword = !_obscurePassword);
                      },
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your password';
                      }
                      if (value.length < 6) {
                        return 'Password must be at least 6 characters';
                      }
                      return null;
                    },
                  ),

                  SizedBox(height: Responsive.spacing(context, mobile: 12, tablet: 14, desktop: 16)),

                  // Forgot Password
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {},
                      child: Text(
                        'Forgot Password?',
                        style: TextStyle(
                          fontSize: Responsive.fontSize(context, mobile: 14, tablet: 15, desktop: 16),
                          color: const Color(0xFF1F6AFF),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),

                  SizedBox(height: Responsive.spacing(context, mobile: 30, tablet: 36, desktop: 42)),

                  // Login Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleLogin,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1F6AFF),
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(
                          vertical: Responsive.spacing(context, mobile: 16, tablet: 18, desktop: 20),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            Responsive.spacing(context, mobile: 16, tablet: 18, desktop: 20),
                          ),
                        ),
                        elevation: 2,
                      ),
                      child: _isLoading
                          ? SizedBox(
                              height: Responsive.spacing(context, mobile: 20, tablet: 22, desktop: 24),
                              width: Responsive.spacing(context, mobile: 20, tablet: 22, desktop: 24),
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Text(
                              'Sign In',
                              style: TextStyle(
                                fontSize: Responsive.fontSize(context, mobile: 16, tablet: 17, desktop: 18),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ),

                  SizedBox(height: Responsive.spacing(context, mobile: 24, tablet: 28, desktop: 32)),

                  // Sign Up Option
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Don't have an account? ",
                        style: TextStyle(
                          fontSize: Responsive.fontSize(context, mobile: 14, tablet: 15, desktop: 16),
                          color: Colors.black54,
                        ),
                      ),
                      TextButton(
                        onPressed: () {},
                        child: Text(
                          'Sign Up',
                          style: TextStyle(
                            fontSize: Responsive.fontSize(context, mobile: 14, tablet: 15, desktop: 16),
                            color: const Color(0xFF1F6AFF),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: Responsive.spacing(context, mobile: 20, tablet: 24, desktop: 28)),

                  // Trust Badge
                  Container(
                    padding: Responsive.padding(
                      context,
                      mobile: const EdgeInsets.all(16),
                      tablet: const EdgeInsets.all(18),
                      desktop: const EdgeInsets.all(20),
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F2FF),
                      borderRadius: BorderRadius.circular(
                        Responsive.spacing(context, mobile: 16, tablet: 18, desktop: 20),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.verified_outlined,
                          color: const Color(0xFF1F6AFF),
                          size: Responsive.spacing(context, mobile: 18, tablet: 20, desktop: 22),
                        ),
                        SizedBox(width: Responsive.spacing(context, mobile: 8, tablet: 10, desktop: 12)),
                        Text(
                          'RBI-compliant · Secure & Trusted',
                          style: TextStyle(
                            fontSize: Responsive.fontSize(context, mobile: 13, tablet: 14, desktop: 15),
                            color: const Color(0xFF1F6AFF),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(
    BuildContext context, {
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData prefixIcon,
    IconButton? suffixIcon,
    bool obscureText = false,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: Responsive.fontSize(context, mobile: 14, tablet: 15, desktop: 16),
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        SizedBox(height: Responsive.spacing(context, mobile: 8, tablet: 10, desktop: 12)),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(
              Responsive.spacing(context, mobile: 16, tablet: 18, desktop: 20),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black12.withOpacity(0.05),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: TextFormField(
            controller: controller,
            obscureText: obscureText,
            keyboardType: keyboardType,
            validator: validator,
            style: TextStyle(
              fontSize: Responsive.fontSize(context, mobile: 15, tablet: 16, desktop: 17),
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                fontSize: Responsive.fontSize(context, mobile: 15, tablet: 16, desktop: 17),
                color: Colors.black.withOpacity(0.4),
              ),
              prefixIcon: Icon(prefixIcon, color: const Color(0xFF1F6AFF)),
              suffixIcon: suffixIcon,
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(
                horizontal: Responsive.spacing(context, mobile: 16, tablet: 18, desktop: 20),
                vertical: Responsive.spacing(context, mobile: 16, tablet: 18, desktop: 20),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFRPProtectionCard(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(
        bottom: Responsive.spacing(context, mobile: 24, tablet: 28, desktop: 32),
      ),
      padding: Responsive.padding(
        context,
        mobile: const EdgeInsets.all(18),
        tablet: const EdgeInsets.all(20),
        desktop: const EdgeInsets.all(22),
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFE8F5E9),
            const Color(0xFFC8E6C9),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(
          Responsive.spacing(context, mobile: 18, tablet: 20, desktop: 22),
        ),
        border: Border.all(
          color: Colors.green.withOpacity(0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(
                  Responsive.spacing(context, mobile: 8, tablet: 9, desktop: 10),
                ),
                decoration: BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.shield_outlined,
                  color: Colors.white,
                  size: Responsive.spacing(context, mobile: 20, tablet: 22, desktop: 24),
                ),
              ),
              SizedBox(width: Responsive.spacing(context, mobile: 12, tablet: 14, desktop: 16)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Factory Reset Protection Active',
                      style: TextStyle(
                        fontSize: Responsive.fontSize(context, mobile: 16, tablet: 17, desktop: 18),
                        fontWeight: FontWeight.w800,
                        color: Colors.green.shade900,
                      ),
                    ),
                    SizedBox(height: Responsive.spacing(context, mobile: 4, tablet: 5, desktop: 6)),
                    if (_storedGoogleAccount != null)
                      Text(
                        'Account: ${_storedGoogleAccount!['email']}',
                        style: TextStyle(
                          fontSize: Responsive.fontSize(context, mobile: 13, tablet: 14, desktop: 15),
                          color: Colors.green.shade800,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: Responsive.spacing(context, mobile: 12, tablet: 14, desktop: 16)),
          Container(
            padding: Responsive.padding(
              context,
              mobile: const EdgeInsets.all(12),
              tablet: const EdgeInsets.all(14),
              desktop: const EdgeInsets.all(16),
            ),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.7),
              borderRadius: BorderRadius.circular(
                Responsive.spacing(context, mobile: 12, tablet: 14, desktop: 16),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline,
                  color: Colors.green.shade800,
                  size: Responsive.spacing(context, mobile: 18, tablet: 20, desktop: 22),
                ),
                SizedBox(width: Responsive.spacing(context, mobile: 10, tablet: 12, desktop: 14)),
                Expanded(
                  child: Text(
                    'After factory reset, this phone will require the same Google account to unlock. Without the password, the device will be unusable and must be returned to the shop for assistance.',
                    style: TextStyle(
                      fontSize: Responsive.fontSize(context, mobile: 12, tablet: 13, desktop: 14),
                      color: Colors.green.shade900,
                      height: 1.4,
                    ),
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

