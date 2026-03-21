import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/locker_state.dart';
import '../utils/device_control.dart';

class LockLifecycleListener extends StatefulWidget {
  const LockLifecycleListener({super.key, required this.child});

  final Widget child;

  @override
  State<LockLifecycleListener> createState() => _LockLifecycleListenerState();
}

class _LockLifecycleListenerState extends State<LockLifecycleListener>
    with WidgetsBindingObserver {
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
    final locker = Provider.of<LockerState>(context, listen: false);
    if (locker.isLocked &&
        (state == AppLifecycleState.paused ||
            state == AppLifecycleState.detached)) {
      DeviceControl.ensureForeground();
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
