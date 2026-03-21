import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../../utils/responsive.dart';
import '../../services/emi_service.dart';
import '../../services/auth_service.dart';
import '../../models/payment_models.dart';
import '../../models/home_models.dart';
import '../../config/api_config.dart';

// Razorpay Payment Screen
class RazorpayPaymentScreen extends StatefulWidget {
  final PendingPaymentModel installment;

  const RazorpayPaymentScreen({super.key, required this.installment});

  @override
  State<RazorpayPaymentScreen> createState() => _RazorpayPaymentScreenState();
}

class _RazorpayPaymentScreenState extends State<RazorpayPaymentScreen> {
  final EmiService _emiService = EmiService();
  final AuthService _authService = AuthService();
  Razorpay? _razorpay;
  bool _isLoading = false;
  bool _isProcessing = false;
  String? _errorMessage;
  RazorpayOrderData? _orderData;
  UserProfile? _userProfile;

  @override
  void initState() {
    super.initState();
    _initializeRazorpay();
    _loadUserProfile();
    _createOrder();
  }

  Future<void> _loadUserProfile() async {
    try {
      final response = await _authService.getUserProfile();
      if (mounted) {
        setState(() {
          _userProfile = response.data;
        });
        print('[RAZORPAY_SCREEN] User profile loaded');
        print('[RAZORPAY_SCREEN] Mobile: ${_userProfile?.mobile}');
        print('[RAZORPAY_SCREEN] Email: ${_userProfile?.email}');
      }
    } catch (e) {
      print('[RAZORPAY_SCREEN] ⚠️ WARNING: Failed to load user profile: $e');
      // Continue without profile - prefill will be empty
    }
  }

  void _initializeRazorpay() {
    print('[RAZORPAY_SCREEN] Initializing Razorpay...');
    
    // Clear previous instance if exists
    _razorpay?.clear();
    
    // Initialize Razorpay - key will be provided in options map
    // Version 1.4.0 constructor doesn't take parameters
    _razorpay = Razorpay();
    
    // Set up event handlers
    _razorpay!.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay!.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay!.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
    
    print('[RAZORPAY_SCREEN] ✅ Razorpay initialized successfully');
  }

  Future<void> _createOrder() async {
    print('[RAZORPAY_SCREEN] ========== Starting Order Creation ==========');
    print('[RAZORPAY_SCREEN] Installment ID: ${widget.installment.id}');
    print('[RAZORPAY_SCREEN] Amount: ${widget.installment.amount}');
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await _emiService.createRazorpayOrderForEmi(
        emiPaymentId: widget.installment.id,
        amount: widget.installment.amount,
      );

      print('[RAZORPAY_SCREEN] ✅ Order created successfully');
      print('[RAZORPAY_SCREEN] Order ID: ${response.data.orderId}');
      print('[RAZORPAY_SCREEN] Amount: ${response.data.amount}');
      print('[RAZORPAY_SCREEN] Currency: ${response.data.currency}');

      if (mounted) {
        setState(() {
          _orderData = response.data;
          _isLoading = false;
        });

        // Use key from API response, or fallback to config key
        final keyId = response.data.keyId ?? ApiConfig.razorpayKey;
        
        if (keyId.isEmpty) {
          print('[RAZORPAY_SCREEN] ⚠️ WARNING: Key ID not found in response or config');
          setState(() {
            _errorMessage = 'Payment gateway configuration error. Key ID not found.';
            _isLoading = false;
          });
          return;
        }
        
        print('[RAZORPAY_SCREEN] Using Razorpay Key: $keyId');
        
        // Update order data with key (create new instance with key)
        final orderData = response.data;
        _orderData = RazorpayOrderData(
          orderId: orderData.orderId,
          packageId: orderData.packageId,
          keyId: keyId,
          amount: orderData.amount,
          currency: orderData.currency,
        );

        // Open Razorpay checkout
        _openRazorpayCheckout();
      }
    } catch (e, stackTrace) {
      print('[RAZORPAY_SCREEN] ❌ ERROR: $e');
      print('[RAZORPAY_SCREEN] Stack Trace: $stackTrace');
      
      if (mounted) {
        String errorMsg = e.toString().replaceAll('Exception: ', '');
        
        // Make error message more user-friendly
        if (errorMsg.contains('timeout')) {
          errorMsg = 'Connection timeout. Please check your internet connection and try again.';
        } else if (errorMsg.contains('Authentication')) {
          errorMsg = 'Please login again to continue.';
        } else if (errorMsg.contains('Failed to parse')) {
          errorMsg = 'Invalid response from server. Please try again.';
        }
        
        setState(() {
          _isLoading = false;
          _errorMessage = errorMsg;
        });
      }
    }
  }

  void _openRazorpayCheckout() {
    print('[RAZORPAY_SCREEN] ========== Opening Razorpay Checkout ==========');
    
    if (_orderData == null) {
      print('[RAZORPAY_SCREEN] ❌ ERROR: Order data is null');
      setState(() {
        _errorMessage = 'Order data not available. Please try again.';
      });
      return;
    }

    if (_orderData!.orderId.isEmpty) {
      print('[RAZORPAY_SCREEN] ❌ ERROR: Order ID is empty');
      setState(() {
        _errorMessage = 'Invalid order ID. Please try again.';
      });
      return;
    }

    // Use key from order data or fallback to config
    final keyId = _orderData!.keyId ?? ApiConfig.razorpayKey;
    
    if (keyId.isEmpty) {
      print('[RAZORPAY_SCREEN] ❌ ERROR: Razorpay key ID is missing');
      setState(() {
        _errorMessage = 'Payment gateway configuration error. Please contact support.';
      });
      return;
    }

    final amountInPaise = (_orderData!.amount * 100).toInt();
    print('[RAZORPAY_SCREEN] Order ID: ${_orderData!.orderId}');
    print('[RAZORPAY_SCREEN] Amount (paise): $amountInPaise');
    print('[RAZORPAY_SCREEN] Key ID: $keyId');

    // Get user mobile and email for prefill
    final userMobile = _userProfile?.mobile ?? '';
    final userEmail = _userProfile?.email ?? '';
    
    print('[RAZORPAY_SCREEN] Prefilling with mobile: $userMobile, email: $userEmail');

    final options = {
      'key': keyId,
      'amount': amountInPaise,
      'name': 'EMI Payment',
      'description': 'Installment ${widget.installment.installmentNumber} Payment',
      'order_id': _orderData!.orderId,
      'prefill': {
        'contact': userMobile,
        'email': userEmail,
      },
      'external': {
        'wallets': ['paytm']
      },
      'theme': {
        'color': '#0CA72F'
      },
      'retry': {
        'enabled': true,
        'max_count': 1
      }
    };

    print('[RAZORPAY_SCREEN] Opening Razorpay checkout with options...');
    try {
      if (_razorpay == null) {
        print('[RAZORPAY_SCREEN] ❌ ERROR: Razorpay instance is null');
        setState(() {
          _errorMessage = 'Payment gateway not initialized. Please try again.';
        });
        return;
      }
      
      _razorpay!.open(options);
      print('[RAZORPAY_SCREEN] ✅ Razorpay checkout opened successfully');
    } catch (e, stackTrace) {
      print('[RAZORPAY_SCREEN] ❌ ERROR: Failed to open Razorpay: $e');
      print('[RAZORPAY_SCREEN] Stack Trace: $stackTrace');
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to open payment gateway. Please try again.';
        });
      }
    }
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      // Verify payment on backend
      final verifyResponse = await _emiService.verifyRazorpayPayment(
        emiPaymentId: widget.installment.id,
        razorpayOrderId: response.orderId ?? _orderData?.orderId ?? '',
        razorpayPaymentId: response.paymentId ?? '',
        razorpaySignature: response.signature ?? '',
      );

      if (mounted) {
        setState(() {
          _isProcessing = false;
        });

        if (verifyResponse.success) {
          // Close payment screen and payment method selection
          Navigator.pop(context); // Close Razorpay screen
          Navigator.pop(context); // Close payment method selection
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(verifyResponse.message),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        } else {
          setState(() {
            _errorMessage = verifyResponse.message;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _errorMessage = 'Payment verification failed: ${e.toString().replaceAll('Exception: ', '')}';
        });
      }
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    setState(() {
      _isProcessing = false;
    });

    String errorMsg = 'Payment failed';
    if (response.code == Razorpay.PAYMENT_CANCELLED) {
      errorMsg = 'Payment was cancelled by user';
    } else if (response.code == Razorpay.NETWORK_ERROR) {
      errorMsg = 'Network error. Please check your internet connection';
    } else {
      errorMsg = response.message ?? 'Payment failed';
    }

    setState(() {
      _errorMessage = errorMsg;
    });
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    // Handle external wallet selection if needed
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('External wallet selected: ${response.walletName}'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  @override
  void dispose() {
    _razorpay?.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.6,
        maxWidth: Responsive.isDesktop(screenWidth) 
            ? ResponsiveBreakpoints.maxContentWidth * 0.5 
            : double.infinity,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(Responsive.spacing(context, mobile: 24, tablet: 28, desktop: 32)),
          topRight: Radius.circular(Responsive.spacing(context, mobile: 24, tablet: 28, desktop: 32)),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: EdgeInsets.only(
              top: Responsive.spacing(context, mobile: 12, tablet: 14, desktop: 16),
            ),
            width: Responsive.spacing(context, mobile: 40, tablet: 48, desktop: 56),
            height: Responsive.spacing(context, mobile: 4, tablet: 5, desktop: 6),
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(Responsive.spacing(context, mobile: 2, tablet: 2.5, desktop: 3)),
            ),
          ),
          
          // Header
          Padding(
            padding: Responsive.padding(
              context,
              mobile: const EdgeInsets.fromLTRB(24, 20, 24, 16),
              tablet: const EdgeInsets.fromLTRB(28, 24, 28, 20),
              desktop: const EdgeInsets.fromLTRB(32, 28, 32, 24),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.payment,
                  color: Colors.blue.shade600,
                  size: Responsive.spacing(context, mobile: 28, tablet: 32, desktop: 36),
                ),
                SizedBox(width: Responsive.spacing(context, mobile: 12, tablet: 14, desktop: 16)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Online Payment',
                        style: GoogleFonts.poppins(
                          fontSize: Responsive.fontSize(context, mobile: 22, tablet: 24, desktop: 28),
                          fontWeight: FontWeight.w700,
                          color: Colors.grey.shade900,
                        ),
                      ),
                      SizedBox(height: Responsive.spacing(context, mobile: 4, tablet: 6, desktop: 8)),
                      Text(
                        'Amount: ₹${widget.installment.amount.toStringAsFixed(0)}',
                        style: GoogleFonts.poppins(
                          fontSize: Responsive.fontSize(context, mobile: 16, tablet: 18, desktop: 20),
                          fontWeight: FontWeight.w600,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          
          // Content
          Flexible(
            child: SingleChildScrollView(
              padding: Responsive.padding(
                context,
                mobile: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                tablet: const EdgeInsets.fromLTRB(28, 0, 28, 28),
                desktop: const EdgeInsets.fromLTRB(32, 0, 32, 32),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_isLoading)
                    Padding(
                      padding: EdgeInsets.all(Responsive.spacing(context, mobile: 40, tablet: 60, desktop: 80)),
                      child: Column(
                        children: [
                          const CircularProgressIndicator(),
                          SizedBox(height: Responsive.spacing(context, mobile: 16, tablet: 20, desktop: 24)),
                          Text(
                            'Preparing payment...',
                            style: GoogleFonts.poppins(
                              fontSize: Responsive.fontSize(context, mobile: 16, tablet: 18, desktop: 20),
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    )
                  else if (_isProcessing)
                    Padding(
                      padding: EdgeInsets.all(Responsive.spacing(context, mobile: 40, tablet: 60, desktop: 80)),
                      child: Column(
                        children: [
                          const CircularProgressIndicator(),
                          SizedBox(height: Responsive.spacing(context, mobile: 16, tablet: 20, desktop: 24)),
                          Text(
                            'Verifying payment...',
                            style: GoogleFonts.poppins(
                              fontSize: Responsive.fontSize(context, mobile: 16, tablet: 18, desktop: 20),
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    )
                  else if (_errorMessage != null)
                    Padding(
                      padding: EdgeInsets.all(Responsive.spacing(context, mobile: 24, tablet: 28, desktop: 32)),
                      child: Column(
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: Responsive.spacing(context, mobile: 64, tablet: 80, desktop: 96),
                            color: Colors.red.shade400,
                          ),
                          SizedBox(height: Responsive.spacing(context, mobile: 16, tablet: 20, desktop: 24)),
                          Text(
                            _errorMessage!,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(
                              fontSize: Responsive.fontSize(context, mobile: 14, tablet: 15, desktop: 16),
                              color: Colors.red.shade700,
                            ),
                          ),
                          SizedBox(height: Responsive.spacing(context, mobile: 24, tablet: 28, desktop: 32)),
                          ElevatedButton(
                            onPressed: () {
                              setState(() {
                                _errorMessage = null;
                              });
                              _createOrder();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue.shade600,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(
                                horizontal: Responsive.spacing(context, mobile: 24, tablet: 28, desktop: 32),
                                vertical: Responsive.spacing(context, mobile: 12, tablet: 14, desktop: 16),
                              ),
                            ),
                            child: Text(
                              'Retry',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Padding(
                      padding: EdgeInsets.all(Responsive.spacing(context, mobile: 24, tablet: 28, desktop: 32)),
                      child: Column(
                        children: [
                          Icon(
                            Icons.payment,
                            size: Responsive.spacing(context, mobile: 64, tablet: 80, desktop: 96),
                            color: Colors.blue.shade400,
                          ),
                          SizedBox(height: Responsive.spacing(context, mobile: 16, tablet: 20, desktop: 24)),
                          Text(
                            'Payment gateway will open shortly',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(
                              fontSize: Responsive.fontSize(context, mobile: 16, tablet: 18, desktop: 20),
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }
}

