import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../utils/responsive.dart';

class EmiOverlayWidget extends StatelessWidget {
  final Map<String, dynamic> emiData;
  final VoidCallback? onPayNow;
  final VoidCallback? onDismiss;

  const EmiOverlayWidget({
    super.key,
    required this.emiData,
    this.onPayNow,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final billNumber = emiData['billNumber'] as String? ?? 'N/A';
    final amount = emiData['amount'] as int? ?? 0;
    final description = emiData['description'] as String? ?? '';

    return WillPopScope(
      onWillPop: () async {
        // CRITICAL: Block ALL back button attempts
        debugPrint('[EmiOverlay] ========== BACK BUTTON BLOCKED ==========');
        debugPrint(
            '[EmiOverlay] Back button press IGNORED - overlay cannot be dismissed');
        debugPrint(
            '[EmiOverlay] Device is locked - payment required to unlock');
        return false; // Never allow back button to dismiss overlay
      },
      child: Material(
        color: Colors.black.withOpacity(0.95), // Slightly more opaque
        child: PopScope(
          canPop: false,
          // CRITICAL: Prevent back button from dismissing overlay
          onPopInvokedWithResult: (bool didPop, dynamic result) {
            // Explicitly prevent back button - overlay should NEVER be dismissed by back button
            debugPrint(
                '[EmiOverlay] ========== BACK BUTTON INTERCEPTED ==========');
            debugPrint(
                '[EmiOverlay] didPop: $didPop - BLOCKED (overlay cannot be dismissed)');
            debugPrint('[EmiOverlay] Overlay can only be removed by:');
            debugPrint('[EmiOverlay]   1. Payment success');
            debugPrint('[EmiOverlay]   2. Unlock command from admin');
            debugPrint('[EmiOverlay]   3. Backend device unlock');
            // Do nothing - overlay stays visible
          },
          child: Focus(
            autofocus: true,
            // Ensure this widget gets focus to receive key events
            onKeyEvent: (FocusNode node, KeyEvent event) {
              // Intercept ALL key events, especially back button
              if (event.logicalKey == LogicalKeyboardKey.escape ||
                  event.logicalKey == LogicalKeyboardKey.goBack) {
                debugPrint(
                    '[EmiOverlay] 🚫 KEY EVENT BLOCKED: ${event.logicalKey}');
                return KeyEventResult.handled; // Block the key event
              }
              return KeyEventResult.ignored;
            },
            child: Container(
              width: double.infinity,
              height: double.infinity,
              color: Colors.black.withOpacity(0.95),
              // Prevent clicks from passing through to underlying UI
              child: GestureDetector(
                onTap: () {
                  // Prevent dismissing overlay by clicking outside
                  debugPrint(
                      '[EmiOverlay] Outside tap IGNORED - overlay cannot be dismissed');
                },
                onPanDown: (_) {
                  // Block pan gestures
                  debugPrint('[EmiOverlay] Pan gesture BLOCKED');
                },
                onLongPress: () {
                  // Block long press
                  debugPrint('[EmiOverlay] Long press BLOCKED');
                },
                behavior: HitTestBehavior.opaque,
                // Capture all touch events
                child: AbsorbPointer(
                  absorbing: false, // Allow interactions with Pay Now button
                  child: Center(
                    child: Container(
                      margin: Responsive.padding(
                        context,
                        mobile: const EdgeInsets.symmetric(horizontal: 24),
                        tablet: const EdgeInsets.symmetric(horizontal: 32),
                        desktop: const EdgeInsets.symmetric(horizontal: 40),
                      ),
                      constraints: BoxConstraints(
                        maxWidth: Responsive.isDesktop(MediaQuery
                            .of(context)
                            .size
                            .width) ? 500 : double.infinity,
                      ),
                      padding: Responsive.padding(
                        context,
                        mobile: const EdgeInsets.all(24),
                        tablet: const EdgeInsets.all(28),
                        desktop: const EdgeInsets.all(32),
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(
                          Responsive.spacing(
                              context, mobile: 20, tablet: 24, desktop: 28),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Warning Icon
                          Container(
                            padding: Responsive.padding(
                              context,
                              mobile: const EdgeInsets.all(16),
                              tablet: const EdgeInsets.all(18),
                              desktop: const EdgeInsets.all(20),
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.warning_rounded,
                              size: Responsive.spacing(
                                  context, mobile: 48, tablet: 52, desktop: 56),
                              color: Colors.red.shade700,
                            ),
                          ),

                          SizedBox(height: Responsive.spacing(
                              context, mobile: 20, tablet: 24, desktop: 28)),

                          // Title
                          Text(
                            'EMI Payment Due!',
                            style: GoogleFonts.poppins(
                              fontSize: Responsive.fontSize(
                                  context, mobile: 24, tablet: 26, desktop: 28),
                              fontWeight: FontWeight.bold,
                              color: Colors.red.shade700,
                            ),
                            textAlign: TextAlign.center,
                          ),

                          SizedBox(height: Responsive.spacing(
                              context, mobile: 16, tablet: 18, desktop: 20)),

                          // Description
                          if (description.isNotEmpty)
                            Text(
                              description,
                              style: GoogleFonts.poppins(
                                fontSize: Responsive.fontSize(
                                    context, mobile: 16,
                                    tablet: 17,
                                    desktop: 18),
                                fontWeight: FontWeight.w500,
                                color: Colors.grey.shade700,
                              ),
                              textAlign: TextAlign.center,
                            ),

                          SizedBox(height: Responsive.spacing(
                              context, mobile: 8, tablet: 10, desktop: 12)),

                          // Bill Number
                          Text(
                            'Bill Number: $billNumber',
                            style: GoogleFonts.poppins(
                              fontSize: Responsive.fontSize(
                                  context, mobile: 14, tablet: 15, desktop: 16),
                              color: Colors.grey.shade600,
                            ),
                            textAlign: TextAlign.center,
                          ),

                          SizedBox(height: Responsive.spacing(
                              context, mobile: 24, tablet: 28, desktop: 32)),

                          // Amount Card
                          Container(
                            padding: Responsive.padding(
                              context,
                              mobile: const EdgeInsets.all(16),
                              tablet: const EdgeInsets.all(18),
                              desktop: const EdgeInsets.all(20),
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(
                                Responsive.spacing(context, mobile: 12,
                                    tablet: 14,
                                    desktop: 16),
                              ),
                              border: Border.all(
                                color: Colors.blue.shade200,
                                width: 2,
                              ),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  'Due Amount',
                                  style: GoogleFonts.poppins(
                                    fontSize: Responsive.fontSize(
                                        context, mobile: 14,
                                        tablet: 15,
                                        desktop: 16),
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                                SizedBox(height: Responsive.spacing(
                                    context, mobile: 4, tablet: 5, desktop: 6)),
                                Text(
                                  '₹${amount.toStringAsFixed(0)}',
                                  style: GoogleFonts.poppins(
                                    fontSize: Responsive.fontSize(
                                        context, mobile: 32,
                                        tablet: 36,
                                        desktop: 40),
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          SizedBox(height: Responsive.spacing(
                              context, mobile: 24, tablet: 28, desktop: 32)),

                          // Pay Now Button
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: onPayNow,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red.shade700,
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.symmetric(
                                  vertical: Responsive.spacing(
                                      context, mobile: 16,
                                      tablet: 18,
                                      desktop: 20),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    Responsive.spacing(context, mobile: 12,
                                        tablet: 14,
                                        desktop: 16),
                                  ),
                                ),
                                elevation: 4,
                              ),
                              child: Text(
                                'Pay Now',
                                style: GoogleFonts.poppins(
                                  fontSize: Responsive.fontSize(
                                      context, mobile: 18,
                                      tablet: 20,
                                      desktop: 22),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),

                          // Note: Dismiss button removed - overlay cannot be dismissed manually
                          // Only payment or unlock command can remove overlay
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
