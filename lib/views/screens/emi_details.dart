import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../utils/responsive.dart';
import '../../services/emi_service.dart';
import '../../services/payment_service.dart';
import '../../services/auth_service.dart';
import '../../services/app_overlay_service.dart';
import '../../utils/pdf_service.dart';
import '../../models/payment_models.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

class BrowseProductsScreen extends StatefulWidget {
  final Map<String, dynamic>? emiDetails;

  const BrowseProductsScreen({super.key, this.emiDetails});

  @override
  State<BrowseProductsScreen> createState() => _BrowseProductsScreenState();
}

class _BrowseProductsScreenState extends State<BrowseProductsScreen> {
  final EmiService _emiService = EmiService();
  final PaymentService _paymentService = PaymentService();
  final AuthService _authService = AuthService();
  bool _isDownloading = false;
  
  // Razorpay configuration
  // IMPORTANT: This key MUST match the key used in backend to create orders
  static const String _razorpayKeyId = 'rzp_test_RcPWCIhSFzHMjj';
  late Razorpay _razorpay;
  bool _isProcessingPayment = false;
  String? _currentEmiPaymentId; // Store current payment ID for verification

  @override
  void initState() {
    super.initState();
    print('[RAZORPAY_GATEWAY] Initializing Razorpay with key: $_razorpayKeyId');
    try {
      _razorpay = Razorpay();
      _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
      _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
      _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
      print('[RAZORPAY_GATEWAY] Razorpay initialized successfully');
    } catch (e) {
      print('[RAZORPAY_GATEWAY] ERROR: Failed to initialize Razorpay - $e');
    }
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.emiDetails != null) {
      return _emiDetailsScreen(context);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Browse Products",
          style: GoogleFonts.poppins(
            fontSize: Responsive.fontSize(context, mobile: 18, tablet: 20, desktop: 22),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      body: const Center(child: Text("Your product list UI here")),
    );
  }

  Future<void> _downloadStatement() async {
    if (widget.emiDetails == null) return;

    setState(() {
      _isDownloading = true;
    });

    try {
      final emiId = widget.emiDetails!['emiId'] as String? ??
                   widget.emiDetails!['id'] as String? ?? '';

      if (emiId.isEmpty) {
        throw Exception('EMI ID not found');
      }

      // Fetch payments
      final paymentResponse = await _emiService.getEmiPayments(emiId);

      // Generate PDF
      final pdfResult = await PdfService.generateEmiStatement(
        emiId: emiId,
        productName: widget.emiDetails!['product'] as String? ?? 'EMI Product',
        installmentAmount: (widget.emiDetails!['amount'] as num?)?.toDouble() ?? 0.0,
        totalMonths: widget.emiDetails!['months'] as int? ?? 0,
        paidMonths: widget.emiDetails!['paid'] as int? ?? 0,
        status: widget.emiDetails!['status'] as String? ?? 'active',
        payments: paymentResponse.data,
      );

      final pdfFile = pdfResult['file'] as File;
      final savePath = pdfResult['path'] as String;

      // Share/Print PDF
      await PdfService.sharePdf(pdfFile);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PDF saved successfully!',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: Responsive.fontSize(context, mobile: 14, tablet: 15, desktop: 16),
                  ),
                ),
                SizedBox(height: Responsive.spacing(context, mobile: 4, tablet: 5, desktop: 6)),
                Text(
                  'Saved to: $savePath',
                  style: TextStyle(
                    fontSize: Responsive.fontSize(context, mobile: 12, tablet: 13, desktop: 14),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'OK',
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString().replaceAll('Exception: ', '')}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDownloading = false;
        });
      }
    }
  }

  Widget _emiDetailsScreen(BuildContext context) {
    final d = widget.emiDetails!;

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: Text(
          d["product"],
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: Responsive.fontSize(context, mobile: 18, tablet: 20, desktop: 22),
          ),
        ),
        elevation: 0,
      ),

      body: ResponsivePage(
        child: SingleChildScrollView(
          padding: Responsive.padding(
            context,
            mobile: const EdgeInsets.all(18),
            tablet: const EdgeInsets.all(24),
            desktop: const EdgeInsets.all(32),
          ),
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // PRODUCT CARD
            Container(
              padding: Responsive.padding(
                context,
                mobile: const EdgeInsets.all(15),
                tablet: const EdgeInsets.all(24),
                desktop: const EdgeInsets.all(28),
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(
                  Responsive.spacing(context, mobile: 18, tablet: 20, desktop: 24),
                ),
                boxShadow: [
                  BoxShadow(
                    blurRadius: 12,
                    spreadRadius: 2,
                    color: Colors.black12.withOpacity(0.05),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Center(
                    child: Image.asset(
                      d["image"],
                      height: Responsive.spacing(context, mobile: 170, tablet: 200, desktop: 240),
                      fit: BoxFit.contain,
                    ),
                  ),

                  SizedBox(height: Responsive.spacing(context, mobile: 16, tablet: 20, desktop: 24)),

                  Text(
                    d["product"],
                    style: GoogleFonts.poppins(
                      fontSize: Responsive.fontSize(context, mobile: 22, tablet: 24, desktop: 28),
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  SizedBox(height: Responsive.spacing(context, mobile: 6, tablet: 8, desktop: 10)),

                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: Responsive.spacing(context, mobile: 14, tablet: 16, desktop: 18),
                      vertical: Responsive.spacing(context, mobile: 6, tablet: 7, desktop: 8),
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(
                        Responsive.spacing(context, mobile: 8, tablet: 10, desktop: 12),
                      ),
                    ),
                    child: Text(
                      d["status"].toUpperCase(),
                      style: TextStyle(
                        color: d["status"] == "active"
                            ? Colors.blue
                            : Colors.green,
                        fontWeight: FontWeight.w600,
                        fontSize: Responsive.fontSize(context, mobile: 12, tablet: 13, desktop: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: Responsive.spacing(context, mobile: 25, tablet: 30, desktop: 35)),

            // DETAILS
            Text(
              "EMI Details",
              style: GoogleFonts.poppins(
                fontSize: Responsive.fontSize(context, mobile: 20, tablet: 22, desktop: 24),
                fontWeight: FontWeight.w600,
              ),
            ),

            SizedBox(height: Responsive.spacing(context, mobile: 12, tablet: 16, desktop: 20)),

            _detailCard(context, "Monthly EMI", "₹${d["amount"]}", Icons.currency_rupee),
            _detailCard(
              context, 
              "Tenure", 
              "${d["months"]} months", 
              Icons.calendar_month,
              onTap: () => _showInstallmentsDialog(context),
            ),
            _detailCard(context, "Paid Months", d["paid"].toString(), Icons.check_circle),
            _detailCard(context, "Due in", d["dueDay"].toString(), Icons.check_circle),
            _detailCard(context, "Status", d["status"].toUpperCase(), Icons.info_outline),

            SizedBox(height: Responsive.spacing(context, mobile: 30, tablet: 35, desktop: 40)),

            // BUTTON
            ElevatedButton(
              onPressed: _isDownloading ? null : _downloadStatement,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                disabledBackgroundColor: Colors.grey,
                minimumSize: Size(
                  double.infinity,
                  Responsive.spacing(context, mobile: 55, tablet: 60, desktop: 65),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    Responsive.spacing(context, mobile: 12, tablet: 14, desktop: 16),
                  ),
                ),
              ),
                  child: _isDownloading
                  ? SizedBox(
                      height: Responsive.spacing(context, mobile: 20, tablet: 22, desktop: 24),
                      width: Responsive.spacing(context, mobile: 20, tablet: 22, desktop: 24),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      "Download Statement",
                      style: TextStyle(
                        fontSize: Responsive.fontSize(context, mobile: 16, tablet: 18, desktop: 20),
                        color: Colors.white,
                      ),
                    ),
            ),
          ],
        ),
        ),
      ),
    );
  }

  // DETAIL CARD UI
  Widget _detailCard(BuildContext context, String title, String value, IconData icon, {VoidCallback? onTap}) {
    Widget cardContent = Container(
      margin: EdgeInsets.only(bottom: Responsive.spacing(context, mobile: 12, tablet: 14, desktop: 16)),
      padding: Responsive.padding(
        context,
        mobile: const EdgeInsets.all(14),
        tablet: const EdgeInsets.all(18),
        desktop: const EdgeInsets.all(22),
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(
          Responsive.spacing(context, mobile: 14, tablet: 16, desktop: 18),
        ),
        boxShadow: [
          BoxShadow(
            blurRadius: 8,
            offset: const Offset(0, 2),
            color: Colors.black12.withOpacity(0.05),
          )
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: Responsive.spacing(context, mobile: 18, tablet: 20, desktop: 24),
            backgroundColor: Colors.blue.shade50,
            child: Icon(
              icon,
              color: Colors.blue,
              size: Responsive.spacing(context, mobile: 20, tablet: 22, desktop: 26),
            ),
          ),
          SizedBox(width: Responsive.spacing(context, mobile: 14, tablet: 16, desktop: 20)),
          Expanded(
            child: Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: Responsive.fontSize(context, mobile: 15, tablet: 16, desktop: 18),
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Flexible(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    value,
                    style: GoogleFonts.poppins(
                      fontSize: Responsive.fontSize(context, mobile: 15, tablet: 16, desktop: 18),
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                  ),
                ),
                if (onTap != null) ...[
                  SizedBox(width: Responsive.spacing(context, mobile: 6, tablet: 8, desktop: 10)),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: Responsive.spacing(context, mobile: 14, tablet: 16, desktop: 18),
                    color: Colors.grey,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: cardContent,
      );
    }

    return cardContent;
  }

  Future<void> _showInstallmentsDialog(BuildContext context) async {
    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // Fetch pending payments
      final response = await _emiService.getPendingPayments();

      if (!context.mounted) return;
      Navigator.pop(context); // Close loading dialog

      // Filter installments for current EMI
      final emiId = widget.emiDetails!['emiId'] as String? ?? 
                    widget.emiDetails!['id'] as String? ?? '';
      
      final installments = response.data
          .where((payment) => payment.emiId.id == emiId)
          .toList()
        ..sort((a, b) => a.dueDate.compareTo(b.dueDate)); // Sort by due date (nearest first)

      // Find nearest pending installment
      PendingPaymentModel? nearestPending;
      for (var installment in installments) {
        if (installment.status.toLowerCase() == 'pending') {
          nearestPending = installment;
          break;
        }
      }

      // Show installments dialog
      if (!context.mounted) return;
      showDialog(
        context: context,
        builder: (context) => _InstallmentsDialog(
          installments: installments,
          nearestPending: nearestPending,
          onPayNow: _handlePayNow,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      Navigator.pop(context); // Close loading dialog if still open
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading installments: ${e.toString().replaceAll('Exception: ', '')}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _handlePayNow(BuildContext context, PendingPaymentModel installment) async {
    print('[RAZORPAY_GATEWAY] ========== PAYMENT FLOW STARTED ==========');
    print('[RAZORPAY_GATEWAY] Installment Details:');
    print('[RAZORPAY_GATEWAY]   - ID: ${installment.id}');
    print('[RAZORPAY_GATEWAY]   - Installment Number: ${installment.installmentNumber}');
    print('[RAZORPAY_GATEWAY]   - Amount: ₹${installment.amount}');
    print('[RAZORPAY_GATEWAY]   - Bill Number: ${installment.emiId.billNumber}');
    print('[RAZORPAY_GATEWAY]   - Due Date: ${installment.dueDate}');
    
    if (_isProcessingPayment) {
      print('[RAZORPAY_GATEWAY] WARNING: Payment already in progress, ignoring request');
      return;
    }

    // Store emiPaymentId for verification after payment success
    _currentEmiPaymentId = installment.id;
    print('[RAZORPAY_GATEWAY] Stored emiPaymentId for verification: $_currentEmiPaymentId');

    // Close dialog first
    Navigator.pop(context);

    setState(() {
      _isProcessingPayment = true;
    });

    try {
      // Show loading indicator
      if (!context.mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // Step 1: Create Razorpay order
      print('[RAZORPAY_GATEWAY] Step 1: Creating Razorpay order...');
      final orderResponse = await _paymentService.createRazorpayOrder(installment.id);

      print('[RAZORPAY_GATEWAY] Order response received, checking context...');
      
      // Close loading dialog if context is still mounted
      if (context.mounted) {
        print('[RAZORPAY_GATEWAY] Context is mounted, closing loading dialog...');
        Navigator.pop(context); // Close loading dialog
        print('[RAZORPAY_GATEWAY] Loading dialog closed');
      } else {
        print('[RAZORPAY_GATEWAY] WARNING: Context not mounted, but proceeding with payment');
      }

      print('[RAZORPAY_GATEWAY] Validating order response...');
      print('[RAZORPAY_GATEWAY]   - Success: ${orderResponse.success}');
      print('[RAZORPAY_GATEWAY]   - Data null: ${orderResponse.data == null}');
      
      if (!orderResponse.success || orderResponse.data == null) {
        final errorMsg = orderResponse.message.isNotEmpty 
            ? orderResponse.message 
            : 'Failed to create payment order';
        print('[RAZORPAY_GATEWAY] ERROR: Order creation failed - $errorMsg');
        throw Exception(errorMsg);
      }
      
      print('[RAZORPAY_GATEWAY] Order response validation passed');

      final orderData = orderResponse.data!;
      // Use amount from order response (already in paise) or convert from installment
      final amountInPaise = orderData.amount > 0 
          ? orderData.amount.toInt() 
          : (installment.amount * 100).toInt();
      print('[RAZORPAY_GATEWAY] Step 1 SUCCESS: Order created');
      print('[RAZORPAY_GATEWAY]   - Order ID: ${orderData.orderId}');
      print('[RAZORPAY_GATEWAY]   - Amount from order (paise): ${orderData.amount}');
      print('[RAZORPAY_GATEWAY]   - Amount to use (paise): $amountInPaise');
      print('[RAZORPAY_GATEWAY]   - Currency: ${orderData.currency}');

      // Validate order ID
      if (orderData.orderId.isEmpty) {
        print('[RAZORPAY_GATEWAY] ERROR: Order ID is empty, cannot proceed with payment');
        throw Exception('Invalid order ID received from server');
      }

      // Step 2: Open Razorpay checkout
      print('[RAZORPAY_GATEWAY] Step 2: Opening Razorpay checkout...');
      
      // CRITICAL: Key used in app MUST match the key used to create order on backend
      // If backend uses different key, Razorpay will show "Something went wrong" error
      print('[RAZORPAY_GATEWAY] ⚠️ CRITICAL CHECK: Key Verification');
      print('[RAZORPAY_GATEWAY]   - App Key: $_razorpayKeyId');
      print('[RAZORPAY_GATEWAY]   - Backend MUST use SAME key: $_razorpayKeyId');
      print('[RAZORPAY_GATEWAY]   - If backend uses different key, order validation will FAIL');
      
      // Ensure amount matches exactly with order amount
      // Razorpay requires amount to match the order amount when order_id is provided
      final orderAmountInPaise = orderData.amount.toInt();
      print('[RAZORPAY_GATEWAY] Order amount from response: $orderAmountInPaise paise');
      print('[RAZORPAY_GATEWAY] Calculated amount: $amountInPaise paise');
      
      // Use order amount directly to avoid any mismatch
      final finalAmount = orderAmountInPaise > 0 ? orderAmountInPaise : amountInPaise;
      
      // Razorpay requires amount as int, not double
      final int amountInt = finalAmount;
      
      // Verify amount matches order exactly
      if (amountInt != orderAmountInPaise) {
        print('[RAZORPAY_GATEWAY] ⚠️ WARNING: Amount mismatch!');
        print('[RAZORPAY_GATEWAY]   - Order amount: $orderAmountInPaise');
        print('[RAZORPAY_GATEWAY]   - Options amount: $amountInt');
      }
      
      // Fetch user profile to get mobile and email for prefill
      print('[RAZORPAY_GATEWAY] Fetching user profile for prefill data...');
      String userMobile = '';
      String userEmail = '';
      
      try {
        final userProfileResponse = await _authService.getUserProfile();
        userMobile = userProfileResponse.data.mobile;
        userEmail = userProfileResponse.data.email;
        print('[RAZORPAY_GATEWAY] User profile fetched:');
        print('[RAZORPAY_GATEWAY]   - Mobile: ${userMobile.isNotEmpty ? userMobile : 'Not available'}');
        print('[RAZORPAY_GATEWAY]   - Email: ${userEmail.isNotEmpty ? userEmail : 'Not available'}');
      } catch (e) {
        print('[RAZORPAY_GATEWAY] WARNING: Could not fetch user profile: $e');
        print('[RAZORPAY_GATEWAY] Proceeding without prefill data');
      }
      
      // Build prefill map only if we have data
      final Map<String, String> prefill = {};
      if (userMobile.isNotEmpty) {
        // Remove any spaces or special characters, keep only digits
        final cleanMobile = userMobile.replaceAll(RegExp(r'[^\d]'), '');
        if (cleanMobile.isNotEmpty && cleanMobile.length >= 10) {
          prefill['contact'] = cleanMobile;
          print('[RAZORPAY_GATEWAY] Added mobile to prefill: $cleanMobile');
        }
      }
      if (userEmail.isNotEmpty) {
        prefill['email'] = userEmail;
        print('[RAZORPAY_GATEWAY] Added email to prefill: $userEmail');
      }
      
      // When using order_id, Razorpay gets amount from order itself
      // But we still need to provide it for validation
      var options = <String, dynamic>{
        'key': _razorpayKeyId,
        'amount': amountInt, // Must match order amount exactly
        'currency': orderData.currency,
        'name': 'EMI Payment',
        'description': 'Installment ${installment.installmentNumber} - ${installment.emiId.billNumber}',
        'order_id': orderData.orderId,
        'theme': <String, String>{
          'color': '#0CA72F'
        },
        'retry': <String, dynamic>{
          'enabled': true,
          'max_count': 3
        }
      };
      
      // Add prefill only if we have data
      if (prefill.isNotEmpty) {
        options['prefill'] = prefill;
        print('[RAZORPAY_GATEWAY] Prefill data added to options: $prefill');
      } else {
        print('[RAZORPAY_GATEWAY] No prefill data available, skipping prefill');
      }

      print('[RAZORPAY_GATEWAY] Razorpay Options:');
      print('[RAZORPAY_GATEWAY]   - Key: $_razorpayKeyId');
      print('[RAZORPAY_GATEWAY]   - Amount: $finalAmount paise (₹${finalAmount / 100})');
      print('[RAZORPAY_GATEWAY]   - Currency: ${options['currency']}');
      print('[RAZORPAY_GATEWAY]   - Order ID: ${orderData.orderId}');
      print('[RAZORPAY_GATEWAY]   - Description: ${options['description']}');
      print('[RAZORPAY_GATEWAY]   - Full Options: $options');
      
      // Validate amount matches order
      if (finalAmount != orderAmountInPaise) {
        print('[RAZORPAY_GATEWAY] WARNING: Amount mismatch detected!');
        print('[RAZORPAY_GATEWAY]   - Order amount: $orderAmountInPaise');
        print('[RAZORPAY_GATEWAY]   - Options amount: $finalAmount');
      }
      
      try {
        print('[RAZORPAY_GATEWAY] Calling _razorpay.open()...');
        print('[RAZORPAY_GATEWAY] Razorpay instance: $_razorpay');
        print('[RAZORPAY_GATEWAY] Options type: ${options.runtimeType}');
        
        // Call open method
        _razorpay.open(options);
        
        print('[RAZORPAY_GATEWAY] _razorpay.open() called successfully');
        print('[RAZORPAY_GATEWAY] Waiting for Razorpay checkout to open...');
        print('[RAZORPAY_GATEWAY] Note: If checkout does not appear, check Android logs for native errors');
        print('[RAZORPAY_GATEWAY] Check logcat with filter: "Razorpay" or "razorpay_flutter"');
      } catch (e, stackTrace) {
        print('[RAZORPAY_GATEWAY] ERROR: Exception while opening Razorpay checkout: $e');
        print('[RAZORPAY_GATEWAY] Stack trace: $stackTrace');
        rethrow;
      }
    } catch (e, stackTrace) {
      print('[RAZORPAY_GATEWAY] ========== PAYMENT FLOW ERROR ==========');
      print('[RAZORPAY_GATEWAY] Error Type: ${e.runtimeType}');
      print('[RAZORPAY_GATEWAY] Error Message: ${e.toString()}');
      print('[RAZORPAY_GATEWAY] Stack Trace: $stackTrace');
      
      // Close loading dialog if still open and context is mounted
      if (context.mounted) {
        try {
          Navigator.pop(context); // Close loading dialog if still open
          print('[RAZORPAY_GATEWAY] Closed loading dialog in error handler');
        } catch (_) {
          print('[RAZORPAY_GATEWAY] Could not close dialog (might already be closed)');
        }
        
        final errorMessage = e.toString().replaceAll('Exception: ', '');
        print('[RAZORPAY_GATEWAY] Showing error to user: $errorMessage');
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment Error: $errorMessage'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      } else {
        print('[RAZORPAY_GATEWAY] Context not mounted, cannot show error message');
      }
    } finally {
      setState(() {
        _isProcessingPayment = false;
      });
      print('[RAZORPAY_GATEWAY] Payment processing flag reset');
    }
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    print('[RAZORPAY_GATEWAY] ========== PAYMENT SUCCESS ==========');
    print('[RAZORPAY_GATEWAY] Payment ID: ${response.paymentId ?? 'N/A'}');
    print('[RAZORPAY_GATEWAY] Order ID: ${response.orderId ?? 'N/A'}');
    print('[RAZORPAY_GATEWAY] Signature: ${response.signature != null ? 'Present' : 'Missing'}');
    
    // Close any open loading dialogs first
    if (mounted) {
      try {
        // Try to close dialog if it exists
        if (Navigator.of(context, rootNavigator: true).canPop()) {
          Navigator.of(context, rootNavigator: true).pop();
          print('[RAZORPAY_GATEWAY] Closed loading dialog');
        }
      } catch (e) {
        print('[RAZORPAY_GATEWAY] Could not close dialog: $e');
      }
    }
    
    if (!mounted) {
      print('[RAZORPAY_GATEWAY] WARNING: Widget not mounted, cannot show success message');
      return;
    }

    // Validate required fields for verification
    if (response.paymentId == null || response.orderId == null || response.signature == null) {
      print('[RAZORPAY_GATEWAY] ERROR: Missing payment details for verification');
      print('[RAZORPAY_GATEWAY]   - Payment ID: ${response.paymentId ?? 'MISSING'}');
      print('[RAZORPAY_GATEWAY]   - Order ID: ${response.orderId ?? 'MISSING'}');
      print('[RAZORPAY_GATEWAY]   - Signature: ${response.signature != null ? 'Present' : 'MISSING'}');
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Payment successful but verification failed: Missing payment details'),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }

    if (_currentEmiPaymentId == null || _currentEmiPaymentId!.isEmpty) {
      print('[RAZORPAY_GATEWAY] ERROR: emiPaymentId not stored, cannot verify payment');
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Payment successful but verification failed: Missing payment ID'),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }

    // Show loading message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: Responsive.spacing(context, mobile: 20, tablet: 22, desktop: 24),
              height: Responsive.spacing(context, mobile: 20, tablet: 22, desktop: 24),
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            SizedBox(width: Responsive.spacing(context, mobile: 12, tablet: 14, desktop: 16)),
            Text(
              'Verifying payment...',
              style: TextStyle(
                fontSize: Responsive.fontSize(context, mobile: 14, tablet: 15, desktop: 16),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.blue,
        duration: const Duration(seconds: 2),
      ),
    );

    // Verify payment with backend
    try {
      print('[RAZORPAY_GATEWAY] ========== VERIFYING PAYMENT ==========');
      print('[RAZORPAY_GATEWAY] Calling verify API...');
      print('[RAZORPAY_GATEWAY]   - emiPaymentId: $_currentEmiPaymentId');
      print('[RAZORPAY_GATEWAY]   - razorpayOrderId: ${response.orderId}');
      print('[RAZORPAY_GATEWAY]   - razorpayPaymentId: ${response.paymentId}');
      final signaturePreview = response.signature!.length > 20 
          ? '${response.signature!.substring(0, 20)}...' 
          : response.signature!;
      print('[RAZORPAY_GATEWAY]   - razorpaySignature: $signaturePreview');

      final verifyResponse = await _paymentService.verifyRazorpayPayment(
        emiPaymentId: _currentEmiPaymentId!,
        razorpayOrderId: response.orderId!,
        razorpayPaymentId: response.paymentId!,
        razorpaySignature: response.signature!,
      );

      print('[RAZORPAY_GATEWAY] Verification response received');
      print('[RAZORPAY_GATEWAY]   - Success: ${verifyResponse.success}');
      print('[RAZORPAY_GATEWAY]   - Message: ${verifyResponse.message}');

      if (!mounted) return;

      if (verifyResponse.success) {
        print('[RAZORPAY_GATEWAY] ✅ Payment verified successfully!');
        
        // Clear stored payment ID
        _currentEmiPaymentId = null;
        
        // Unlock device after successful payment verification
        print('[RAZORPAY_GATEWAY] Unlocking device after payment verification...');
        await AppOverlayService.unlockDevice();
        print('[RAZORPAY_GATEWAY] Device unlocked successfully');
        
        // Close any open loading dialogs
        if (mounted) {
          try {
            // Close dialog if it exists
            if (Navigator.of(context, rootNavigator: true).canPop()) {
              Navigator.of(context, rootNavigator: true).pop();
              print('[RAZORPAY_GATEWAY] Closed loading dialog after verification');
            }
          } catch (e) {
            print('[RAZORPAY_GATEWAY] Could not close dialog: $e');
          }
        }

        // Show success message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                  'Payment Verified Successfully!',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                fontSize: Responsive.fontSize(context, mobile: 16, tablet: 17, desktop: 18),
                    color: Colors.white,
              ),
            ),
            SizedBox(height: Responsive.spacing(context, mobile: 4, tablet: 5, desktop: 6)),
            Text(
                  'Payment ID: ${response.paymentId}',
              style: TextStyle(
                fontSize: Responsive.fontSize(context, mobile: 12, tablet: 13, desktop: 14),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );
      } else {
        print('[RAZORPAY_GATEWAY] ❌ Payment verification failed');
        print('[RAZORPAY_GATEWAY]   - Message: ${verifyResponse.message}');
        
        // Close any open dialogs
        if (mounted) {
          try {
            if (Navigator.of(context, rootNavigator: true).canPop()) {
              Navigator.of(context, rootNavigator: true).pop();
              print('[RAZORPAY_GATEWAY] Closed dialog after verification failure');
            }
          } catch (e) {
            print('[RAZORPAY_GATEWAY] Could not close dialog: $e');
          }
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment verification failed: ${verifyResponse.message}'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      print('[RAZORPAY_GATEWAY] ❌ ERROR during payment verification: $e');
      
      if (!mounted) return;
      
      // Close any open dialogs
      try {
        if (Navigator.of(context, rootNavigator: true).canPop()) {
          Navigator.of(context, rootNavigator: true).pop();
          print('[RAZORPAY_GATEWAY] Closed dialog after verification error');
        }
      } catch (e) {
        print('[RAZORPAY_GATEWAY] Could not close dialog: $e');
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Payment successful but verification error: ${e.toString().replaceAll('Exception: ', '')}'),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    print('[RAZORPAY_GATEWAY] ========== PAYMENT ERROR CALLBACK TRIGGERED ==========');
    print('[RAZORPAY_GATEWAY] ⚠️ THIS IS THE EXACT ERROR FROM RAZORPAY ⚠️');
    print('[RAZORPAY_GATEWAY] Error Code: ${response.code ?? 'Unknown'}');
    print('[RAZORPAY_GATEWAY] Error Message: ${response.message ?? 'No message'}');
    
    if (response.error != null) {
      print('[RAZORPAY_GATEWAY] Error Details: ${response.error}');
      print('[RAZORPAY_GATEWAY] Full Error Object: ${response.error.toString()}');
      try {
        if (response.error is Map) {
          final errorMap = response.error as Map;
          print('[RAZORPAY_GATEWAY] Error Map Keys: ${errorMap.keys.toList()}');
          errorMap.forEach((key, value) {
            print('[RAZORPAY_GATEWAY]   - $key: $value');
          });
        }
      } catch (e) {
        print('[RAZORPAY_GATEWAY] Could not parse error details: $e');
      }
    }
    
    // Log common error scenarios
    if (response.code == Razorpay.INVALID_OPTIONS) {
      print('[RAZORPAY_GATEWAY] ❌ ERROR TYPE: Invalid Options');
      print('[RAZORPAY_GATEWAY] Most Common Causes:');
      print('[RAZORPAY_GATEWAY]   1. KEY MISMATCH - Backend used different key to create order');
      print('[RAZORPAY_GATEWAY]   2. Amount mismatch with order');
      print('[RAZORPAY_GATEWAY]   3. Invalid order_id format');
      print('[RAZORPAY_GATEWAY]   4. Order created with different account');
      print('[RAZORPAY_GATEWAY] SOLUTION: Verify backend uses SAME key: rzp_live_RftawzItpzRh1C');
    } else if (response.code == Razorpay.NETWORK_ERROR) {
      print('[RAZORPAY_GATEWAY] ❌ ERROR TYPE: Network Error');
    } else if (response.code == Razorpay.PAYMENT_CANCELLED) {
      print('[RAZORPAY_GATEWAY] ⚠️ Payment Cancelled by User');
    } else {
      print('[RAZORPAY_GATEWAY] ❌ ERROR TYPE: ${response.code}');
    }
    
    // Map error codes to user-friendly messages
    String errorCodeDescription = 'Unknown error';
    switch (response.code) {
      case Razorpay.NETWORK_ERROR:
        errorCodeDescription = 'Network Error';
        break;
      case Razorpay.INVALID_OPTIONS:
        errorCodeDescription = 'Invalid Options';
        break;
      case Razorpay.PAYMENT_CANCELLED:
        errorCodeDescription = 'Payment Cancelled';
        break;
      case Razorpay.TLS_ERROR:
        errorCodeDescription = 'TLS Error';
        break;
      case Razorpay.INCOMPATIBLE_PLUGIN:
        errorCodeDescription = 'Incompatible Plugin';
        break;
      case Razorpay.UNKNOWN_ERROR:
        errorCodeDescription = 'Unknown Error';
        break;
    }
    print('[RAZORPAY_GATEWAY] Error Code Description: $errorCodeDescription');
    
    if (!mounted) {
      print('[RAZORPAY_GATEWAY] WARNING: Widget not mounted, cannot show error message');
      return;
    }

    String errorMessage = 'Payment failed';
    if (response.code == Razorpay.PAYMENT_CANCELLED) {
      errorMessage = 'Payment was cancelled by user';
      print('[RAZORPAY_GATEWAY] User cancelled the payment');
    } else if (response.message != null) {
      errorMessage = response.message!;
    }

    print('[RAZORPAY_GATEWAY] Showing error message to user: $errorMessage');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(errorMessage),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    print('[RAZORPAY_GATEWAY] ========== EXTERNAL WALLET SELECTED ==========');
    print('[RAZORPAY_GATEWAY] Wallet Name: ${response.walletName ?? 'Unknown'}');
    
    if (!mounted) {
      print('[RAZORPAY_GATEWAY] WARNING: Widget not mounted, cannot show wallet message');
      return;
    }

    print('[RAZORPAY_GATEWAY] Showing wallet selection message to user');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('External wallet selected: ${response.walletName ?? 'Unknown'}'),
        backgroundColor: Colors.blue,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}

// Installments Dialog Widget
class _InstallmentsDialog extends StatelessWidget {
  final List<PendingPaymentModel> installments;
  final PendingPaymentModel? nearestPending;
  final Future<void> Function(BuildContext, PendingPaymentModel) onPayNow;

  const _InstallmentsDialog({
    required this.installments,
    this.nearestPending,
    required this.onPayNow,
  });

  String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${date.day.toString().padLeft(2, '0')} ${months[date.month - 1]} ${date.year}';
  }

  @override
  Widget build(BuildContext context) {

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Responsive.spacing(context, mobile: 16, tablet: 18, desktop: 20)),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
          maxWidth: MediaQuery.of(context).size.width * 0.95,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: Responsive.padding(
                context,
                mobile: const EdgeInsets.all(16),
                tablet: const EdgeInsets.all(20),
                desktop: const EdgeInsets.all(24),
              ),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(Responsive.spacing(context, mobile: 16, tablet: 18, desktop: 20)),
                  topRight: Radius.circular(Responsive.spacing(context, mobile: 16, tablet: 18, desktop: 20)),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Installments',
                      style: GoogleFonts.poppins(
                        fontSize: Responsive.fontSize(context, mobile: 18, tablet: 20, desktop: 22),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.close,
                      size: Responsive.spacing(context, mobile: 20, tablet: 22, desktop: 24),
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Installments List
            Flexible(
              child: installments.isEmpty
                  ? Padding(
                      padding: Responsive.padding(
                        context,
                        mobile: const EdgeInsets.all(32),
                        tablet: const EdgeInsets.all(40),
                        desktop: const EdgeInsets.all(48),
                      ),
                      child: Text(
                        'No installments found',
                        style: GoogleFonts.poppins(
                          fontSize: Responsive.fontSize(context, mobile: 16, tablet: 18, desktop: 20),
                          color: Colors.grey,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      padding: Responsive.padding(
                        context,
                        mobile: const EdgeInsets.all(16),
                        tablet: const EdgeInsets.all(20),
                        desktop: const EdgeInsets.all(24),
                      ),
                      itemCount: installments.length,
                      itemBuilder: (context, index) {
                        final installment = installments[index];
                        final isPending = installment.status.toLowerCase() == 'pending';
                        final isNearestPending = nearestPending != null && 
                                                 installment.id == nearestPending!.id;
                        
                        return Container(
                          margin: EdgeInsets.only(
                            bottom: Responsive.spacing(context, mobile: 12, tablet: 14, desktop: 16),
                          ),
                          padding: Responsive.padding(
                            context,
                            mobile: const EdgeInsets.all(14),
                            tablet: const EdgeInsets.all(18),
                            desktop: const EdgeInsets.all(20),
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(
                              color: isPending ? Colors.orange.shade200 : Colors.green.shade200,
                              width: 1.5,
                            ),
                            borderRadius: BorderRadius.circular(
                              Responsive.spacing(context, mobile: 12, tablet: 14, desktop: 16),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // First Row - Installment info and amount
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Flexible(
                                    flex: 2,
                                    child: Wrap(
                                      spacing: Responsive.spacing(context, mobile: 6, tablet: 8, desktop: 10),
                                      runSpacing: Responsive.spacing(context, mobile: 6, tablet: 8, desktop: 10),
                                      children: [
                                        Container(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: Responsive.spacing(context, mobile: 8, tablet: 10, desktop: 12),
                                            vertical: Responsive.spacing(context, mobile: 4, tablet: 5, desktop: 6),
                                          ),
                                          decoration: BoxDecoration(
                                            color: isPending 
                                                ? Colors.orange.shade50 
                                                : Colors.green.shade50,
                                            borderRadius: BorderRadius.circular(
                                              Responsive.spacing(context, mobile: 6, tablet: 8, desktop: 10),
                                            ),
                                          ),
                                          child: Text(
                                            'Installment ${installment.installmentNumber}',
                                            style: GoogleFonts.poppins(
                                              fontSize: Responsive.fontSize(context, mobile: 12, tablet: 13, desktop: 14),
                                              fontWeight: FontWeight.w600,
                                              color: isPending ? Colors.orange.shade700 : Colors.green.shade700,
                                            ),
                                          ),
                                        ),
                                        Container(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: Responsive.spacing(context, mobile: 6, tablet: 8, desktop: 10),
                                            vertical: Responsive.spacing(context, mobile: 3, tablet: 4, desktop: 5),
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.grey.shade100,
                                            borderRadius: BorderRadius.circular(
                                              Responsive.spacing(context, mobile: 5, tablet: 6, desktop: 7),
                                            ),
                                          ),
                                          child: Text(
                                            installment.status.toUpperCase(),
                                            style: GoogleFonts.poppins(
                                              fontSize: Responsive.fontSize(context, mobile: 10, tablet: 11, desktop: 12),
                                              fontWeight: FontWeight.w500,
                                              color: Colors.grey.shade700,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Flexible(
                                    flex: 1,
                                    child: Text(
                                      '₹${installment.amount.toStringAsFixed(0)}',
                                      style: GoogleFonts.poppins(
                                        fontSize: Responsive.fontSize(context, mobile: 16, tablet: 18, desktop: 20),
                                        fontWeight: FontWeight.w700,
                                        color: Colors.blue,
                                      ),
                                      textAlign: TextAlign.end,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: Responsive.spacing(context, mobile: 10, tablet: 12, desktop: 14)),
                              Row(
                                children: [
                                  Icon(
                                    Icons.calendar_today,
                                    size: Responsive.spacing(context, mobile: 16, tablet: 18, desktop: 20),
                                    color: Colors.grey.shade600,
                                  ),
                                  SizedBox(width: Responsive.spacing(context, mobile: 6, tablet: 8, desktop: 10)),
                                  Text(
                                    'Due Date: ${_formatDate(installment.dueDate)}',
                                    style: GoogleFonts.poppins(
                                      fontSize: Responsive.fontSize(context, mobile: 13, tablet: 14, desktop: 15),
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                ],
                              ),
                              // Pay Now Button for nearest pending installment
                              if (isNearestPending) ...[
                                SizedBox(height: Responsive.spacing(context, mobile: 12, tablet: 14, desktop: 16)),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: () => _handlePayNow(context, installment),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      foregroundColor: Colors.white,
                                      padding: EdgeInsets.symmetric(
                                        vertical: Responsive.spacing(context, mobile: 12, tablet: 14, desktop: 16),
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(
                                          Responsive.spacing(context, mobile: 10, tablet: 12, desktop: 14),
                                        ),
                                      ),
                                      elevation: 2,
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.payment,
                                          size: Responsive.spacing(context, mobile: 18, tablet: 20, desktop: 22),
                                        ),
                                        SizedBox(width: Responsive.spacing(context, mobile: 6, tablet: 8, desktop: 10)),
                                        Flexible(
                                          child: Text(
                                            'Pay Now',
                                            style: GoogleFonts.poppins(
                                              fontSize: Responsive.fontSize(context, mobile: 14, tablet: 16, desktop: 18),
                                              fontWeight: FontWeight.w600,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _handlePayNow(BuildContext context, PendingPaymentModel installment) {
    onPayNow(context, installment);
  }
}
