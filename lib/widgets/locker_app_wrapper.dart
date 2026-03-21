import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../state/locker_state.dart';
import '../widgets/lock_lifecycle_listener.dart';
import '../views/screens/splash_screen.dart';

class LockerAppWrapper extends StatelessWidget {
  const LockerAppWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => LockerState(AuthService()),
      child: LockLifecycleListener(
        child: Consumer<LockerState>(
          builder: (context, lockerState, _) {
            return MaterialApp(
              title: 'EMI Locker Enhanced',
              debugShowCheckedModeBanner: false,
              theme: ThemeData(
                colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF005EB8)),
                useMaterial3: true,
                fontFamily: 'Roboto',
              ),
              home: _LockerRouter(lockerState: lockerState),
            );
          },
        ),
      ),
    );
  }
}

class _LockerRouter extends StatelessWidget {
  final LockerState lockerState;

  const _LockerRouter({required this.lockerState});

  @override
  Widget build(BuildContext context) {
    if (lockerState.authStatus == AuthStatus.unknown) {
      return const SplashScreen();
    }
    
    if (lockerState.authStatus == AuthStatus.unauthenticated) {
      return _LoginScreen(lockerState: lockerState);
    }

    final child = _DashboardScreen(lockerState: lockerState);

    if (lockerState.isLocked) {
      return _LockScreenOverlay(
        lockerState: lockerState,
        child: child,
      );
    }

    return child;
  }
}

class _LoginScreen extends StatelessWidget {
  final LockerState lockerState;

  const _LoginScreen({required this.lockerState});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('EMI Locker Demo Login'),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: lockerState.isBusy ? null : () async {
                await lockerState.signIn('9999999999', '123456');
              },
              child: lockerState.isBusy 
                ? const CircularProgressIndicator()
                : const Text('Sign In'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardScreen extends StatelessWidget {
  final LockerState lockerState;

  const _DashboardScreen({required this.lockerState});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          // Logout button hidden
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Status: ${lockerState.lockStatus.name}'),
            Text('Customer: ${lockerState.loanSummary?.customerName ?? 'N/A'}'),
            Text('Loan: ${lockerState.loanSummary?.loanNumber ?? 'N/A'}'),
            Text('Overdue: ₹${lockerState.loanSummary?.overdueAmount.toStringAsFixed(2) ?? '0.00'}'),
            const SizedBox(height: 20),
            if (lockerState.errorMessage != null)
              Text(
                lockerState.errorMessage!,
                style: const TextStyle(color: Colors.red),
              ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: lockerState.refresh,
              child: const Text('Refresh'),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: lockerState.isLocked ? lockerState.acknowledgePayment : lockerState.reportMissedPayment,
              child: Text(lockerState.isLocked ? 'Pay EMI' : 'Simulate Missed Payment'),
            ),
          ],
        ),
      ),
    );
  }
}

class _LockScreenOverlay extends StatelessWidget {
  final LockerState lockerState;
  final Widget child;

  const _LockScreenOverlay({
    required this.lockerState,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        Positioned.fill(
          child: AbsorbPointer(
            absorbing: true,
            child: Container(
              color: Colors.black.withOpacity(0.8),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 360),
                  child: Card(
                    margin: const EdgeInsets.all(24),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: const [
                              Icon(Icons.phonelink_lock, size: 32, color: Colors.red),
                              SizedBox(width: 12),
                              Text(
                                'Device Locked',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Hi ${lockerState.loanSummary?.customerName ?? 'Customer'},',
                            style: const TextStyle(fontSize: 16),
                          ),
                          const Text(
                            'your device is locked due to overdue EMI payment.',
                            style: TextStyle(fontSize: 16),
                          ),
                          const SizedBox(height: 16),
                          _InfoRow(
                            label: 'Loan Number',
                            value: lockerState.loanSummary?.loanNumber ?? '--',
                          ),
                          _InfoRow(
                            label: 'Overdue Amount',
                            value: '₹${lockerState.loanSummary?.overdueAmount.toStringAsFixed(2) ?? '0.00'}',
                          ),
                          _InfoRow(
                            label: 'Reason',
                            value: lockerState.lockReason ?? 'EMI overdue',
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            'Pay your overdue EMI to unlock your device.',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: lockerState.isBusy ? null : () async {
                                await lockerState.acknowledgePayment();
                              },
                              child: lockerState.isBusy
                                ? const CircularProgressIndicator()
                                : const Text('Pay EMI & Unlock'),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Contact support feature coming soon')),
                                );
                              },
                              child: const Text('Contact Support'),
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
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(color: Colors.black54),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
