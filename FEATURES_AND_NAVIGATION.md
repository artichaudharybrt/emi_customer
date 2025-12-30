**EMI Locker — Features & Navigation**

Overview
- Purpose: Mobile app to manage EMI items, view payments, receive due alerts and securely unlock devices.
- Entry: `lib/main.dart` initializes Firebase, FCM and runs `MyApp` (global `navigatorKey`).

High-level Features
- Authentication
  - Google Sign-In and credential-based login (`lib/views/screens/login_screen.dart`, `lib/services/auth_service.dart`).
  - On successful login the app navigates to the main shell (`RootShell`).

- App Shell & Navigation
  - App entry -> `SplashScreen` (`lib/views/screens/splash_screen.dart`) which routes to `LoginScreen` or `RootShell` using `Navigator.pushReplacement`.
  - `RootShell` (`lib/views/screens/root_shell.dart`) is the main scaffold and implements responsive navigation:
    - Mobile: bottom `NavigationBar` with destinations Home, My locker, Help.
    - Tablet/Desktop: `NavigationRail` with the same destinations.
    - The three body screens are: `HomeScreen`, `LockerScreen`, `HelpScreen`.

- Home (`lib/views/screens/home_screen.dart`)
  - Shows user profile and EMI summary (active count, next due installment, total monthly amount).
  - Logout action calls `AuthService.logout()` and `Navigator.pushAndRemoveUntil` back to `LoginScreen`.

- Locker (`lib/views/screens/locker_screen.dart`)
  - Displays active and completed EMIs fetched via `EmiService`.
  - Two testing buttons: "Check Due EMIs" (calls `AppOverlayService.checkAndShowOverlay`) and "Force Show Test Overlay".
  - Tapping an EMI opens `BrowseProductsScreen` / EMI details using `Navigator.push(MaterialPageRoute(...))`.

- EMI Details & Payments (`lib/views/screens/emi_details.dart`)
  - `BrowseProductsScreen` shows EMI/product detail when `emiDetails` is provided.
  - Razorpay integration: client-side event handlers configured (success, error, external wallet).
  - PDF statement generation via `PdfService` and share/print flows.

- Help (`lib/views/screens/help_screen.dart`)
  - FAQ / topics list driven by `HelpController` and `HelpModel`.
  - Support actions (browse FAQs, chat with support) available.

- Notifications & Background
  - FCM initialization in `main.dart` and `FCMService` (`lib/services/fcm_service.dart`).
  - Background message handler registered: `firebaseMessagingBackgroundHandler`.
  - `NotificationService` initialized at startup.

- App Overlay / Locking behavior
  - `AppOverlayService` manages overlays shown for due EMIs or lock/unlock UX. Initialized in `MyApp.builder` and uses app context + overlay state.
  - Main app back behavior is wrapped with `PopScope` logic to block back when overlay is active.

- Services & Models (core)
  - `AuthService` — authentication flows + stored Google account handling.
  - `FCMService` — token storage, registration after login, command processing.
  - `EmiService` — fetch EMIs, payments, pending payments.
  - `PaymentService` — interacts with payment backend and Razorpay flows.
  - `PdfService` — generate & share EMI statements.
  - Models: `emi_models.dart`, `home_models.dart`, `payment_models.dart`, etc.

Navigation Map (text)
- Launch -> `SplashScreen`
  - if has auth token -> `RootShell`
  - else -> `LoginScreen`
- `LoginScreen` (on success) -> `RootShell` (pushReplacement)
- `RootShell` tabs -> `HomeScreen`, `LockerScreen`, `HelpScreen` (index changes, no Navigator push)
- `HomeScreen` -> Logout -> `LoginScreen` (pushAndRemoveUntil)
- `LockerScreen` -> tap EMI -> `BrowseProductsScreen` / `EMI Details` (Navigator.push)

Key files and responsibilities
- `lib/main.dart`: App bootstrap (Firebase, FCM, globals, overlay init).
- `lib/views/screens/splash_screen.dart`: Splash + navigation decision.
- `lib/views/screens/login_screen.dart`: Sign-in UI and login flows.
- `lib/views/screens/root_shell.dart`: Responsive app shell and main navigation.
- `lib/views/screens/home_screen.dart`: Dashboard, profile and summary.
- `lib/views/screens/locker_screen.dart`: List of EMIs, overlay triggers.
- `lib/views/screens/emi_details.dart`: EMI detail view, payment & PDF exports.
- `lib/views/screens/help_screen.dart`: Help & FAQs.
- `lib/services/*.dart`: Business logic for auth, FCM, EMI, payments, overlay.

Known navigation-related details & tips for maintainers
- The app uses `MaterialPageRoute` for most full-screen navigations and direct widget swap for tab navigation inside `RootShell`.
- A global `navigatorKey` is available (`main.dart`) — useful for navigation from services (e.g., deep-link or FCM command handlers).
- Overlay handling is centralized in `AppOverlayService` — it can re-insert overlays on resume; check `didChangeAppLifecycleState` hooks in `MyApp` and `RootShell`.

Suggested next steps (for doc improvement)
- Add a simple flow diagram image (SVG/PNG) showing Splash -> Login -> RootShell -> Screens.
- Extract a small routing helper if named routes are desired instead of many `MaterialPageRoute` usages.
- Add a short developer quickstart section showing how to run the app and where to configure Razorpay keys / Firebase settings.

If you want, I can:
- Generate a visual diagram and add it to the repo.
- Create a `docs/` folder with per-feature detailed docs (auth, payments, FCM, overlay).
- Produce a developer quickstart including env setup and run commands.

----
Generated by repository scan on request.
