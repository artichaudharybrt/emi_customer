import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'state/locker_state.dart';

void main() {
  final authService = AuthService(); // Use existing auth service

  runApp(
    ChangeNotifierProvider(
      create: (_) => LockerState(authService),
      child: const LockerApp(),
    ),
  );
}
