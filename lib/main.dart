import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:emilockercustomer/views/screens/splash_screen.dart';
import 'package:emilockercustomer/services/notification_service.dart';
import 'package:emilockercustomer/services/app_overlay_service.dart';
import 'package:emilockercustomer/services/fcm_service.dart';
import 'package:emilockercustomer/services/fcm_background_handler.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  try {
    await Firebase.initializeApp();
    print('[Main] Firebase initialized successfully');
  } catch (e) {
    print('[Main] Firebase initialization error: $e');
    // Continue even if Firebase fails (for development)
  }
  
  // Register background message handler
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  
  // Initialize FCM Service
  final fcmService = FCMService();
  try {
    await fcmService.initialize();
    print('[Main] FCM Service initialized successfully');
  } catch (e) {
    print('[Main] FCM Service initialization error: $e');
  }
  
  // Process any pending FCM commands
  await processPendingFcmCommands();
  
  // Initialize notification service
  await NotificationService.initialize();
  
  runApp(MyApp(fcmService: fcmService));
}

// Global navigator key for accessing context from anywhere
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class MyApp extends StatefulWidget {
  final FCMService? fcmService;
  
  const MyApp({super.key, this.fcmService});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    // Check for overlay when app comes to foreground
    if (state == AppLifecycleState.resumed) {
      debugPrint('[Main] App resumed, checking for overlay...');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          // Update context first
          AppOverlayService.updateContext(context);
          // Then check for overlay
          AppOverlayService.checkOnAppStart(context);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        navigatorKey: navigatorKey, // Add global navigator key
        debugShowCheckedModeBanner: false,
        title: 'EMI Locker',
        theme: ThemeData(
          useMaterial3: true,
          colorSchemeSeed: const Color(0xFF1F6AFF),
          scaffoldBackgroundColor: const Color(0xFFF5F7FB),
          fontFamily: 'Roboto',
        ),
        home: const SplashScreen(),
      builder: (context, child) {
        // Initialize overlay service with overlay state and FCM service
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final overlayState = Overlay.of(context);
          AppOverlayService.initialize(overlayState, fcmService: widget.fcmService, context: context);
          
          // Update context when app builds
          AppOverlayService.updateContext(context);
          
          // Check for overlay on app start (with delay to ensure app is fully loaded)
          Future.delayed(const Duration(milliseconds: 500), () {
            if (context.mounted) {
              AppOverlayService.checkOnAppStart(context);
            }
          });
        });
        
        // Wrap child in PopScope to block back button when overlay is showing
        return PopScope(
          canPop: false, // Block back button - will check overlay state
          onPopInvokedWithResult: (bool didPop, dynamic result) async {
            if (didPop) {
              // Back button was pressed, check if overlay is showing
              final isOverlayShowing = await AppOverlayService.isOverlayShowing();
              if (isOverlayShowing) {
                debugPrint('[Main] ========== BACK BUTTON PRESSED - OVERLAY IS SHOWING ==========');
                debugPrint('[Main] Back button BLOCKED - overlay cannot be dismissed');
                debugPrint('[Main] Overlay can only be removed by payment or unlock command');
                // Re-insert overlay if it was removed
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  AppOverlayService.checkOnAppStart(context);
                });
              } else {
                // Overlay not showing, allow normal back button
                debugPrint('[Main] Overlay not showing, allowing normal back button');
                // Allow app to close normally
                if (navigatorKey.currentState?.canPop() ?? false) {
                  navigatorKey.currentState?.pop();
                }
              }
            }
          },
          child: child ?? const SizedBox(),
        );
      },
    );
  }
}

