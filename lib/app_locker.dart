import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/lock_screen.dart';
import 'state/locker_state.dart';
import 'widgets/lock_lifecycle_listener.dart';

class LockerApp extends StatelessWidget {
  const LockerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return LockLifecycleListener(
      child: MaterialApp(
        title: 'EMI Locker',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF005EB8)),
          useMaterial3: true,
          fontFamily: 'Roboto',
        ),
        home: const _RootRouter(),
      ),
    );
  }
}

class _RootRouter extends StatelessWidget {
  const _RootRouter();

  @override
  Widget build(BuildContext context) {
    return Consumer<LockerState>(
      builder: (context, state, _) {
        if (state.authStatus == AuthStatus.unknown) {
          return const SplashScreen();
        }
        if (state.authStatus == AuthStatus.unauthenticated) {
          return LoginScreen(isBusy: state.isBusy);
        }

        final child = DashboardScreen(
          loanSummary: state.loanSummary,
          lockStatus: state.lockStatus,
          lockReason: state.lockReason,
          lastUpdatedAt: state.lastUpdatedAt,
          isSyncing: state.isBusy,
          onRefresh: state.refresh,
          onAcknowledgedPayment: state.acknowledgePayment,
          onReportMissedPayment: state.reportMissedPayment,
          onSignOut: state.signOut,
          errorMessage: state.errorMessage,
          onDismissError: state.clearError,
        );

        if (state.isLocked) {
          return LockScreen(
            borrowerName: state.loanSummary?.customerName ?? 'Customer',
            loanNumber: state.loanSummary?.loanNumber ?? '--',
            overdueAmount: state.loanSummary?.overdueAmount ?? 0,
            lockReason: state.lockReason ?? 'EMI overdue',
            onContactSupport: () {},
            onMakePayment: state.acknowledgePayment,
            lastUpdatedAt: state.lastUpdatedAt,
            child: child,
          );
        }

        return child;
      },
    );
  }
}
