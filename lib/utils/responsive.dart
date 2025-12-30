import 'package:flutter/material.dart';

class ResponsiveBreakpoints {
  static const double tablet = 720;
  static const double desktop = 1080;
  static const double maxContentWidth = 1100;
}

class ResponsivePage extends StatelessWidget {
  const ResponsivePage({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final padding = _pagePadding(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final constrainedWidth = constraints.maxWidth > ResponsiveBreakpoints.desktop
            ? ResponsiveBreakpoints.maxContentWidth
            : constraints.maxWidth;
        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: constrainedWidth),
            child: Padding(padding: padding, child: child),
          ),
        );
      },
    );
  }

  EdgeInsets _pagePadding(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width >= ResponsiveBreakpoints.desktop) {
      return const EdgeInsets.symmetric(horizontal: 48, vertical: 24);
    }
    if (width >= ResponsiveBreakpoints.tablet) {
      return const EdgeInsets.symmetric(horizontal: 32, vertical: 20);
    }
    return const EdgeInsets.symmetric(horizontal: 16, vertical: 16);
  }
}

class Responsive {
  static bool isTablet(double width) =>
      width >= ResponsiveBreakpoints.tablet && width < ResponsiveBreakpoints.desktop;

  static bool isDesktop(double width) => width >= ResponsiveBreakpoints.desktop;

  static int columnsForWidth(double width, {int mobile = 1, int tablet = 2, int desktop = 3}) {
    if (isDesktop(width)) return desktop;
    if (isTablet(width)) return tablet;
    return mobile;
  }

  /// Returns responsive font size based on screen width
  static double fontSize(BuildContext context, {required double mobile, double? tablet, double? desktop}) {
    final width = MediaQuery.of(context).size.width;
    if (isDesktop(width)) return desktop ?? tablet ?? mobile;
    if (isTablet(width)) return tablet ?? mobile;
    return mobile;
  }

  /// Returns responsive padding based on screen width
  static EdgeInsets padding(BuildContext context, {
    required EdgeInsets mobile,
    EdgeInsets? tablet,
    EdgeInsets? desktop,
  }) {
    final width = MediaQuery.of(context).size.width;
    if (isDesktop(width)) return desktop ?? tablet ?? mobile;
    if (isTablet(width)) return tablet ?? mobile;
    return mobile;
  }

  /// Returns responsive spacing (double) based on screen width
  static double spacing(BuildContext context, {required double mobile, double? tablet, double? desktop}) {
    final width = MediaQuery.of(context).size.width;
    if (isDesktop(width)) return desktop ?? tablet ?? mobile;
    if (isTablet(width)) return tablet ?? mobile;
    return mobile;
  }
}


