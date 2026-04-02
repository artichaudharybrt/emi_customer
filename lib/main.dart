import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:emilockercustomer/views/screens/splash_screen.dart';
import 'package:emilockercustomer/services/notification_service.dart';
import 'package:emilockercustomer/services/fcm_service.dart';
import 'package:emilockercustomer/services/overlay_lock_service.dart';
import 'package:emilockercustomer/services/fcm_background_handler.dart';
import 'package:emilockercustomer/services/app_overlay_service.dart';
import 'package:emilockercustomer/services/overlay_permission_monitor_service.dart';
import 'package:emilockercustomer/services/auth_service.dart';
import 'package:emilockercustomer/services/native_location_tracking_service.dart';
import 'package:emilockercustomer/services/user_location_service.dart';
import 'package:emilockercustomer/services/uninstall_flag_service.dart';
import 'package:flutter/foundation.dart';

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
  
  // Initialize Overlay Lock Service
  try {
    await OverlayLockService.initialize();
    print('[Main] Overlay Lock Service initialized successfully');
  } catch (e) {
    print('[Main] Overlay Lock Service initialization error: $e');
  }
  
  // Process any pending FCM commands
  await processPendingFcmCommands();
  
  // Initialize notification service
  await NotificationService.initialize();
  
  // Start overlay permission monitoring
  try {
    await OverlayPermissionMonitorService.startMonitoring();
    print('[Main] Overlay Permission Monitor started successfully');
  } catch (e) {
    print('[Main] Overlay Permission Monitor initialization error: $e');
  }
  
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
  static DateTime? _lastLocationSentOnResume;
  bool _appOverlayServiceInitialized = false;

  /// Overlay is under Navigator — MaterialApp.builder [context] has no Overlay ancestor.
  void _initAppOverlayServiceOnce([int attempt = 0]) {
    if (_appOverlayServiceInitialized) return;
    if (attempt > 24) {
      _appOverlayServiceInitialized = true; // stop scheduling retries on rebuild
      debugPrint('[Main] ⚠️ AppOverlayService: overlay not available after retries');
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final overlayState = navigatorKey.currentState?.overlay;
      final navContext = navigatorKey.currentContext;
      if (overlayState != null && navContext != null && navContext.mounted) {
        _appOverlayServiceInitialized = true;
        try {
          AppOverlayService.initialize(
            overlayState,
            fcmService: widget.fcmService,
            context: navContext,
          );
          debugPrint('[Main] ✅ AppOverlayService initialized (navigator overlay)');
        } catch (e) {
          debugPrint('[Main] ⚠️ AppOverlayService init error: $e');
        }
      } else {
        _initAppOverlayServiceOnce(attempt + 1);
      }
    });
  }

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
    
    // When app opens / comes to foreground → send location if logged in
    if (state == AppLifecycleState.resumed) {
      debugPrint('[Main] App resumed, checking if overlay should be shown...');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          // Check if device is locked and show overlay if needed
          OverlayLockService.isDeviceLocked().then((isLocked) {
            if (isLocked) {
              debugPrint('[Main] Device is locked - overlay should be showing');
            } else {
              debugPrint('[Main] Device is not locked');
            }
          });
          // Send location when user opens app (throttle: once per 30 sec)
          final now = DateTime.now();
          if (_lastLocationSentOnResume == null ||
              now.difference(_lastLocationSentOnResume!).inSeconds >= 30) {
            AuthService().hasAuthToken().then((hasToken) {
              if (hasToken) {
                NativeLocationTrackingService.startIfPossible();
                UninstallFlagService.refreshInBackground();
                _lastLocationSentOnResume = now;
                UserLocationService.fetchAndSendLocation().then((_) {
                  debugPrint('[Main] Location sent on app resume');
                }).catchError((e) {
                  debugPrint('[Main] Location on resume failed: $e');
                });
              }
            });
          }
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
        // Builder's context is ABOVE Navigator — Overlay.of(context) throws "No Overlay widget found".
        // Use the navigator's overlay from navigatorKey after the first frame.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _initAppOverlayServiceOnce();
        });
        
        // Check if overlay should be shown on app start (for notification auto-open)
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Future.delayed(const Duration(milliseconds: 1000), () {
            if (context.mounted) {
              // Check if device is locked and show overlay automatically
              OverlayLockService.isDeviceLocked().then((isLocked) {
                if (isLocked) {
                  debugPrint('[Main] ========== DEVICE IS LOCKED ON APP START ==========');
                  debugPrint('[Main] Notification opened app - showing overlay automatically...');
                  // Use navigatorKey to get context and show overlay
                  final navigatorContext = navigatorKey.currentContext;
                  if (navigatorContext != null && navigatorContext.mounted) {
                    AppOverlayService.checkAndShowOverlay(navigatorContext);
                  } else {
                    debugPrint('[Main] ⚠️ Navigator context not available yet, overlay will show when RootShell loads');
                  }
                } else {
                  debugPrint('[Main] Device is not locked on app start');
                }
              });
            }
          });
        });
        
        return child ?? const SizedBox();
      },
    );
  }
}

