import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Widget that completely blocks system UI interactions
/// Used to make overlay completely non-dismissible
class SystemUIBlocker extends StatefulWidget {
  final Widget child;
  
  const SystemUIBlocker({
    super.key,
    required this.child,
  });

  @override
  State<SystemUIBlocker> createState() => _SystemUIBlockerState();
}

class _SystemUIBlockerState extends State<SystemUIBlocker> {
  @override
  void initState() {
    super.initState();
    // Hide system UI and make it immersive
    _hideSystemUI();
  }

  @override
  void dispose() {
    // Restore system UI when overlay is removed
    _showSystemUI();
    super.dispose();
  }

  void _hideSystemUI() {
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.immersiveSticky,
      overlays: [], // Hide all system overlays
    );
  }

  void _showSystemUI() {
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
      overlays: SystemUiOverlay.values, // Show all system overlays
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        debugPrint('[SystemUIBlocker] Back button BLOCKED at system level');
        return false; // Never allow back button
      },
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (bool didPop, dynamic result) {
          debugPrint('[SystemUIBlocker] PopScope back button BLOCKED');
          // Do nothing - completely block back button
        },
        child: GestureDetector(
          onTap: () {
            debugPrint('[SystemUIBlocker] System tap intercepted');
            // Re-hide system UI if user tries to show it
            _hideSystemUI();
          },
          behavior: HitTestBehavior.opaque,
          child: Container(
            width: double.infinity,
            height: double.infinity,
            color: Colors.black.withOpacity(0.98), // Nearly opaque
            child: widget.child,
          ),
        ),
      ),
    );
  }
}