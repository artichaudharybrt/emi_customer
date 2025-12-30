import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import 'auth_service.dart';

class PaymentService {
  final AuthService _authService = AuthService();

  /// Create Razorpay order
  Future<RazorpayOrderResponse> createRazorpayOrder(String emiPaymentId) async {
    print('[RAZORPAY_GATEWAY] Creating Razorpay order for emiPaymentId: $emiPaymentId');
    
    final token = await _authService.getAuthToken();
    
    if (token == null || token.isEmpty) {
      print('[RAZORPAY_GATEWAY] ERROR: Authentication token is missing');
      throw Exception('Authentication required. Please login first.');
    }

    final uri = Uri.parse(ApiConfig.createRazorpayOrder);
    print('[RAZORPAY_GATEWAY] API Endpoint: ${uri.toString()}');

    try {
      final requestBody = jsonEncode({
        'emiPaymentId': emiPaymentId,
      });
      print('[RAZORPAY_GATEWAY] Request Body: $requestBody');

      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: requestBody,
      );

      print('[RAZORPAY_GATEWAY] Response Status Code: ${response.statusCode}');
      print('[RAZORPAY_GATEWAY] Response Body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        try {
          final jsonData = jsonDecode(response.body) as Map<String, dynamic>;
          final orderResponse = RazorpayOrderResponse.fromJson(jsonData);
          
          if (orderResponse.success && orderResponse.data != null) {
            print('[RAZORPAY_GATEWAY] SUCCESS: Order created - OrderId: ${orderResponse.data!.orderId}, Amount: ${orderResponse.data!.amount}');
          } else {
            print('[RAZORPAY_GATEWAY] ERROR: Order creation failed - Message: ${orderResponse.message}');
          }
          
          return orderResponse;
        } catch (e) {
          print('[RAZORPAY_GATEWAY] ERROR: Failed to parse response - $e');
          print('[RAZORPAY_GATEWAY] Raw Response: ${response.body}');
          throw Exception('Failed to parse response: $e');
        }
      } else {
        final errorMessage = _extractErrorMessage(response.body);
        print('[RAZORPAY_GATEWAY] ERROR: API returned error status ${response.statusCode} - $errorMessage');
        throw Exception(errorMessage);
      }
    } catch (e) {
      if (e is Exception) {
        print('[RAZORPAY_GATEWAY] EXCEPTION: ${e.toString()}');
        rethrow;
      }
      print('[RAZORPAY_GATEWAY] UNKNOWN ERROR: $e');
      throw Exception('Network error: $e');
    }
  }

  /// Verify Razorpay payment
  Future<RazorpayVerifyResponse> verifyRazorpayPayment({
    required String emiPaymentId,
    required String razorpayOrderId,
    required String razorpayPaymentId,
    required String razorpaySignature,
  }) async {
    print('[RAZORPAY_GATEWAY] Verifying payment - OrderId: $razorpayOrderId, PaymentId: $razorpayPaymentId');
    
    final token = await _authService.getAuthToken();
    
    if (token == null || token.isEmpty) {
      print('[RAZORPAY_GATEWAY] ERROR: Authentication token is missing');
      throw Exception('Authentication required. Please login first.');
    }

    final uri = Uri.parse(ApiConfig.verifyRazorpayPayment);
    print('[RAZORPAY_GATEWAY] Verification API Endpoint: ${uri.toString()}');

    try {
      final requestBody = jsonEncode({
        'emiPaymentId': emiPaymentId,
        'razorpayOrderId': razorpayOrderId,
        'razorpayPaymentId': razorpayPaymentId,
        'razorpaySignature': razorpaySignature,
      });
      print('[RAZORPAY_GATEWAY] Verification Request Body: $requestBody');

      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: requestBody,
      );

      print('[RAZORPAY_GATEWAY] Verification Response Status Code: ${response.statusCode}');
      print('[RAZORPAY_GATEWAY] Verification Response Body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        try {
          final jsonData = jsonDecode(response.body) as Map<String, dynamic>;
          final verifyResponse = RazorpayVerifyResponse.fromJson(jsonData);
          
          if (verifyResponse.success) {
            print('[RAZORPAY_GATEWAY] SUCCESS: Payment verified successfully');
          } else {
            print('[RAZORPAY_GATEWAY] ERROR: Payment verification failed - Message: ${verifyResponse.message}');
          }
          
          return verifyResponse;
        } catch (e) {
          print('[RAZORPAY_GATEWAY] ERROR: Failed to parse verification response - $e');
          print('[RAZORPAY_GATEWAY] Raw Response: ${response.body}');
          throw Exception('Failed to parse response: $e');
        }
      } else {
        final errorMessage = _extractErrorMessage(response.body);
        print('[RAZORPAY_GATEWAY] ERROR: Verification API returned error status ${response.statusCode} - $errorMessage');
        throw Exception(errorMessage);
      }
    } catch (e) {
      if (e is Exception) {
        print('[RAZORPAY_GATEWAY] EXCEPTION during verification: ${e.toString()}');
        rethrow;
      }
      print('[RAZORPAY_GATEWAY] UNKNOWN ERROR during verification: $e');
      throw Exception('Network error: $e');
    }
  }

  String _extractErrorMessage(String responseBody) {
    try {
      final jsonData = jsonDecode(responseBody) as Map<String, dynamic>;
      final message = jsonData['message'] as String? ?? 'Payment operation failed';
      print('[RAZORPAY_GATEWAY] Extracted error message: $message');
      return message;
    } catch (e) {
      final errorMsg = 'Payment operation failed: ${responseBody.length > 100 ? responseBody.substring(0, 100) : responseBody}';
      print('[RAZORPAY_GATEWAY] Failed to parse error response: $e');
      print('[RAZORPAY_GATEWAY] Raw error response: $responseBody');
      return errorMsg;
    }
  }
}

// Razorpay Order Response Model
class RazorpayOrderResponse {
  final bool success;
  final String message;
  final RazorpayOrderData? data;

  RazorpayOrderResponse({
    required this.success,
    required this.message,
    this.data,
  });

  factory RazorpayOrderResponse.fromJson(Map<String, dynamic> json) {
    final dataJson = json['data'] as Map<String, dynamic>?;
    
    print('[RAZORPAY_GATEWAY] Parsing RazorpayOrderResponse:');
    print('[RAZORPAY_GATEWAY]   - Success: ${json['success']}');
    print('[RAZORPAY_GATEWAY]   - Message: ${json['message']}');
    print('[RAZORPAY_GATEWAY]   - Data present: ${dataJson != null}');
    if (dataJson != null) {
      print('[RAZORPAY_GATEWAY]   - Data keys: ${dataJson.keys.toList()}');
      if (dataJson['order'] != null) {
        print('[RAZORPAY_GATEWAY]   - Order object present: ${dataJson['order']}');
      }
    }
    
    return RazorpayOrderResponse(
      success: json['success'] as bool? ?? false,
      message: json['message'] as String? ?? '',
      data: dataJson != null ? RazorpayOrderData.fromJson(dataJson) : null,
    );
  }
}

class RazorpayOrderData {
  final String orderId;
  final String? keyId;
  final double amount;
  final String currency;

  RazorpayOrderData({
    required this.orderId,
    this.keyId,
    required this.amount,
    required this.currency,
  });

  factory RazorpayOrderData.fromJson(Map<String, dynamic> json) {
    // Handle nested order structure: data.order.id
    String? orderId;
    double amount = 0.0;
    String currency = 'INR';
    
    if (json['order'] != null && json['order'] is Map<String, dynamic>) {
      final orderData = json['order'] as Map<String, dynamic>;
      orderId = orderData['id'] as String?;
      amount = (orderData['amount'] as num?)?.toDouble() ?? 0.0;
      currency = orderData['currency'] as String? ?? 'INR';
    } else {
      // Fallback to direct fields
      orderId = json['orderId'] as String? ?? json['id'] as String?;
      amount = (json['amount'] as num?)?.toDouble() ?? 0.0;
      currency = json['currency'] as String? ?? 'INR';
    }
    
    print('[RAZORPAY_GATEWAY] Parsing order data:');
    print('[RAZORPAY_GATEWAY]   - Order ID: $orderId');
    print('[RAZORPAY_GATEWAY]   - Amount: $amount');
    print('[RAZORPAY_GATEWAY]   - Currency: $currency');
    
    return RazorpayOrderData(
      orderId: orderId ?? '',
      keyId: json['keyId'] as String?,
      amount: amount,
      currency: currency,
    );
  }
}

// Razorpay Verify Response Model
class RazorpayVerifyResponse {
  final bool success;
  final String message;
  final Map<String, dynamic>? data;

  RazorpayVerifyResponse({
    required this.success,
    required this.message,
    this.data,
  });

  factory RazorpayVerifyResponse.fromJson(Map<String, dynamic> json) {
    return RazorpayVerifyResponse(
      success: json['success'] as bool? ?? false,
      message: json['message'] as String? ?? '',
      data: json['data'] as Map<String, dynamic>?,
    );
  }
}

