import 'package:flutter/material.dart';

import '../../utils/responsive.dart';
import '../../services/app_overlay_service.dart';
import 'help_screen.dart';
import 'home_screen.dart';
import 'locker_screen.dart';

class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> with WidgetsBindingObserver {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Update context in overlay service
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AppOverlayService.updateContext(context);
      // Check for overlay when screen loads
      AppOverlayService.checkAndShowOverlay(context);
    });
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
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          AppOverlayService.checkAndShowOverlay(context);
        }
      });
    }
  }

  final List<Widget> _screens = [
    HomeScreen(),
    LockerScreen(),
    HelpScreen(),
  ];

  final List<NavigationDestination> _destinations = const [
    NavigationDestination(
      icon: Icon(Icons.home_outlined),
      selectedIcon: Icon(Icons.home_rounded),
      label: 'Home',
    ),
    NavigationDestination(
      icon: Icon(Icons.lock_outline),
      selectedIcon: Icon(Icons.lock),
      label: 'My locker',
    ),
    NavigationDestination(
      icon: Icon(Icons.help_outline),
      selectedIcon: Icon(Icons.help_rounded),
      label: 'Help',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isRail = constraints.maxWidth >= ResponsiveBreakpoints.tablet;
        final body = _screens[_currentIndex];

        // --------------------------
        // TABLET / DESKTOP MODE
        // --------------------------
        if (isRail) {
          return Scaffold(
            body: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 240),
                  curve: Curves.easeOut,
                  width: constraints.maxWidth >= ResponsiveBreakpoints.desktop ? 220 : 82,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 18,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: NavigationRail(
                    selectedIndex: _currentIndex,
                    onDestinationSelected: (index) {
                      setState(() => _currentIndex = index);
                    },

                    groupAlignment: -0.9,
                    extended: constraints.maxWidth >= ResponsiveBreakpoints.desktop,
                    useIndicator: true,
                    indicatorColor: const Color(0xFF1F6AFF).withOpacity(0.15),

                    leading: Builder(
                      builder: (context) => Padding(
                        padding: EdgeInsets.symmetric(
                          vertical: Responsive.spacing(context, mobile: 20, tablet: 22, desktop: 24),
                        ),
                        child: CircleAvatar(
                          radius: Responsive.spacing(context, mobile: 22, tablet: 24, desktop: 26),
                          backgroundColor: const Color(0xFF1F6AFF),
                          child: Text(
                            ['H', 'L', 'H'][_currentIndex],
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: Responsive.fontSize(context, mobile: 18, tablet: 20, desktop: 22),
                            ),
                          ),
                        ),
                      ),
                    ),

                    destinations: const [
                      NavigationRailDestination(
                        icon: Icon(Icons.home_outlined),
                        selectedIcon: Icon(Icons.home_rounded),
                        label: Text('Home'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.lock_outline),
                        selectedIcon: Icon(Icons.lock),
                        label: Text('My locker'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.help_outline),
                        selectedIcon: Icon(Icons.help_rounded),
                        label: Text('Help'),
                      ),
                    ],
                  ),
                ),
                const VerticalDivider(width: 1),
                Expanded(child: body),
              ],
            ),
          );
        }

        // --------------------------
        // MOBILE MODE (BOTTOM NAV)
        // --------------------------
        return Scaffold(
          body: body,
          bottomNavigationBar: NavigationBar(
            height: 60,
            elevation: 5,
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,

            shadowColor: Colors.black.withOpacity(0.08),
            indicatorColor: const Color(0xFF1F6AFF).withOpacity(0.15),

            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,

            selectedIndex: _currentIndex,
            onDestinationSelected: (index) {
              setState(() => _currentIndex = index);
            },

            destinations: _destinations
                .map(
                  (d) => NavigationDestination(
                icon: Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: d.icon,
                ),
                selectedIcon: Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: d.selectedIcon,
                ),
                label: d.label,
              ),
            )
                .toList(),
          ),
        );
      },
    );
  }
}
