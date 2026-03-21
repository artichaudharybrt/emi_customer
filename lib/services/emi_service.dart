import 'dart:convert';
import '../models/emi_models.dart';
import '../models/payment_models.dart';
import '../config/api_config.dart';
import 'auth_service.dart';
import '../utils/api_client.dart';

class EmiService {
  final AuthService _authService = AuthService();

  /// Fetch EMIs for the current user
  Future<EmiResponse> getMyEmis({
    int page = 1,
    int limit = 10,
  }) async {
    final token = await _authService.getAuthToken();
    
    if (token == null || token.isEmpty) {
      throw Exception('Authentication required. Please login first.');
    }

    final uri = ApiConfig.buildUri(
      ApiConfig.myEmis,
      queryParameters: {
        'page': page.toString(),
        'limit': limit.toString(),
      },
    );

    try {
      final response = await ApiClient.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        try {
          final jsonData = jsonDecode(response.body) as Map<String, dynamic>;
          return EmiResponse.fromJson(jsonData);
        } catch (e) {
          throw Exception('Failed to parse response: $e');
        }
      } else {
        final errorMessage = _extractErrorMessage(response.body);
        throw Exception(errorMessage);
      }
    } on ApiException catch (e) {
      throw Exception(e.message);
    }
  }

  /// Check for due EMIs from backend
  Future<List<EmiModel>> checkDueEmis() async {
    final token = await _authService.getAuthToken();
    
    if (token == null || token.isEmpty) {
      throw Exception('Authentication required. Please login first.');
    }

    try {
      final response = await ApiClient.get(
        Uri.parse(ApiConfig.checkDueEmis),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final jsonData = jsonDecode(response.body) as Map<String, dynamic>;
        if (jsonData['success'] == true) {
          final dataList = jsonData['data'] as List<dynamic>? ?? [];
          return dataList.map((item) => EmiModel.fromJson(item as Map<String, dynamic>)).toList();
        }
        return [];
      } else {
        // If endpoint doesn't exist, fallback to checking locally
        return await _checkDueEmisLocally();
      }
    } catch (e) {
      // Fallback to local check if API fails
      return await _checkDueEmisLocally();
    }
  }

  /// Check for due EMIs locally
  Future<List<EmiModel>> _checkDueEmisLocally() async {
    try {
      final response = await getMyEmis(page: 1, limit: 100);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      
      final dueEmis = <EmiModel>[];
      
      for (var emi in response.data) {
        if (emi.status.toLowerCase() != 'active') continue;
        
        bool isDue = false;
        if (emi.dueDates.isNotEmpty) {
          for (var dueDate in emi.dueDates) {
            final due = DateTime(dueDate.year, dueDate.month, dueDate.day);
            if (due.isBefore(today) || due.isAtSameMomentAs(today)) {
              isDue = true;
              break;
            }
          }
        } else {
          // Check based on start date
          final startDate = DateTime(emi.startDate.year, emi.startDate.month, emi.startDate.day);
          if (startDate.isBefore(today) || startDate.isAtSameMomentAs(today)) {
            if (emi.paidInstallments < emi.totalInstallments) {
              isDue = true;
            }
          }
        }
        
        if (isDue) {
          dueEmis.add(emi);
        }
      }
      
      return dueEmis;
    } catch (e) {
      print('Error checking due EMIs locally: $e');
      return [];
    }
  }

  /// Fetch payments for a specific EMI
  Future<PaymentResponse> getEmiPayments(String emiId) async {
    final token = await _authService.getAuthToken();
    
    if (token == null || token.isEmpty) {
      throw Exception('Authentication required. Please login first.');
    }

    final uri = Uri.parse(ApiConfig.emiPayments(emiId));

    try {
      final response = await ApiClient.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        try {
          final jsonData = jsonDecode(response.body) as Map<String, dynamic>;
          return PaymentResponse.fromJson(jsonData);
        } catch (e) {
          throw Exception('Failed to parse response: $e');
        }
      } else {
        final errorMessage = _extractErrorMessage(response.body);
        throw Exception(errorMessage);
      }
    } on ApiException catch (e) {
      throw Exception(e.message);
    }
  }

  /// Fetch pending payments/installments
  Future<PendingPaymentResponse> getPendingPayments() async {
    final token = await _authService.getAuthToken();
    
    if (token == null || token.isEmpty) {
      throw Exception('Authentication required. Please login first.');
    }

    final uri = Uri.parse(ApiConfig.pendingPayments);

    try {
      final response = await ApiClient.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        try {
          final jsonData = jsonDecode(response.body) as Map<String, dynamic>;
          return PendingPaymentResponse.fromJson(jsonData);
        } catch (e) {
          throw Exception('Failed to parse response: $e');
        }
      } else {
        final errorMessage = _extractErrorMessage(response.body);
        throw Exception(errorMessage);
      }
    } on ApiException catch (e) {
      throw Exception(e.message);
    }
  }

  /// Get QR Code for payment
  Future<QrCodeResponse> getQrCode(String emiPaymentId) async {
    final token = await _authService.getAuthToken();
    
    if (token == null || token.isEmpty) {
      throw Exception('Authentication required. Please login first.');
    }

    final uri = Uri.parse(ApiConfig.getQrCode(emiPaymentId));

    try {
      final response = await ApiClient.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        try {
          final jsonData = jsonDecode(response.body) as Map<String, dynamic>;
          return QrCodeResponse.fromJson(jsonData);
        } catch (e) {
          throw Exception('Failed to parse response: $e');
        }
      } else {
        final errorMessage = _extractErrorMessage(response.body);
        throw Exception(errorMessage);
      }
    } on ApiException catch (e) {
      throw Exception(e.message);
    }
  }

  /// Verify QR Code Payment
  Future<PaymentVerificationResponse> verifyQrPayment({
    required String emiPaymentId,
    required String transactionId,
  }) async {
    final token = await _authService.getAuthToken();
    
    if (token == null || token.isEmpty) {
      throw Exception('Authentication required. Please login first.');
    }

    final uri = Uri.parse(ApiConfig.verifyQrPayment);

    try {
      final response = await ApiClient.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'emiPaymentId': emiPaymentId,
          'transactionId': transactionId,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        try {
          final jsonData = jsonDecode(response.body) as Map<String, dynamic>;
          return PaymentVerificationResponse.fromJson(jsonData);
        } catch (e) {
          throw Exception('Failed to parse response: $e');
        }
      } else {
        final errorMessage = _extractErrorMessage(response.body);
        throw Exception(errorMessage);
      }
    } on ApiException catch (e) {
      throw Exception(e.message);
    }
  }

  /// Verify Bank Transfer Payment
  Future<PaymentVerificationResponse> verifyBankPayment({
    required String emiPaymentId,
    required String transactionId,
    required String paymentDate,
    required double amount,
    required String bankName,
    required String accountNumber,
    String? screenshot, // base64 encoded image or URL
  }) async {
    final token = await _authService.getAuthToken();
    
    if (token == null || token.isEmpty) {
      throw Exception('Authentication required. Please login first.');
    }

    final uri = Uri.parse(ApiConfig.verifyBankPayment);

    final requestBody = <String, dynamic>{
      'emiPaymentId': emiPaymentId,
      'transactionId': transactionId,
      'paymentDate': paymentDate,
      'amount': amount,
      'bankName': bankName,
      'accountNumber': accountNumber,
    };

    if (screenshot != null && screenshot.isNotEmpty) {
      requestBody['screenshot'] = screenshot;
    }

    try {
      final response = await ApiClient.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        try {
          final jsonData = jsonDecode(response.body) as Map<String, dynamic>;
          return PaymentVerificationResponse.fromJson(jsonData);
        } catch (e) {
          throw Exception('Failed to parse response: $e');
        }
      } else {
        final errorMessage = _extractErrorMessage(response.body);
        throw Exception(errorMessage);
      }
    } on ApiException catch (e) {
      throw Exception(e.message);
    }
  }

  /// Create Razorpay Order for Package Payment
  /// Note: This method uses the package order endpoint
  /// For EMI payments, use createRazorpayOrderForEmi instead
  Future<RazorpayOrderResponse> createRazorpayOrder({
    String packageType = 'basic',
  }) async {
    final token = await _authService.getAuthToken();
    
    if (token == null || token.isEmpty) {
      throw Exception('Authentication required. Please login first.');
    }

    // Using the package order endpoint (if still available)
    // For EMI payments, use createRazorpayOrderForEmi
    final uri = Uri.parse('${ApiConfig.baseUrl}/razorpay/package/order');

    try {
      final response = await ApiClient.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'packageType': packageType,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        try {
          final jsonData = jsonDecode(response.body) as Map<String, dynamic>;
          return RazorpayOrderResponse.fromJson(jsonData);
        } catch (e) {
          throw Exception('Failed to parse response: $e');
        }
      } else {
        final errorMessage = _extractErrorMessage(response.body);
        throw Exception(errorMessage);
      }
    } on ApiException catch (e) {
      throw Exception(e.message);
    }
  }

  /// Create Razorpay Order for EMI Payment
  Future<RazorpayOrderResponse> createRazorpayOrderForEmi({
    required String emiPaymentId,
    required double amount,
  }) async {
    print('[RAZORPAY] ========== Creating Razorpay Order ==========');
    print('[RAZORPAY] EMI Payment ID: $emiPaymentId');
    print('[RAZORPAY] Amount: $amount');
    
    final token = await _authService.getAuthToken();
    
    if (token == null || token.isEmpty) {
      print('[RAZORPAY] ❌ ERROR: Authentication token not found');
      throw Exception('Authentication required. Please login first.');
    }

    print('[RAZORPAY] ✅ Auth token found');
    final uri = Uri.parse(ApiConfig.razorpayOrder);
    print('[RAZORPAY] API Endpoint: $uri');

    final requestBody = {
      'emiPaymentId': emiPaymentId,
      'amount': amount,
    };
    
    print('[RAZORPAY] Request Body: ${jsonEncode(requestBody)}');
    print('[RAZORPAY] Sending POST request...');
    
    try {
      final response = await ApiClient.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(requestBody),
      );

      print('[RAZORPAY] Response Status Code: ${response.statusCode}');
      print('[RAZORPAY] Response Body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        try {
          final jsonData = jsonDecode(response.body) as Map<String, dynamic>;
          print('[RAZORPAY] ✅ Order created successfully');
          
          // Log order ID from nested structure
          final orderId = jsonData['data']?['order']?['id'] ?? 
                         jsonData['data']?['orderId'] ?? 'N/A';
          print('[RAZORPAY] Order ID: $orderId');
          
          return RazorpayOrderResponse.fromJson(jsonData);
        } catch (e) {
          print('[RAZORPAY] ❌ ERROR: Failed to parse response: $e');
          print('[RAZORPAY] Response body: ${response.body}');
          throw Exception('Failed to parse response: $e');
        }
      } else {
        final errorMessage = _extractRazorpayErrorMessage(response.body, response.statusCode);
        print('[RAZORPAY] ❌ ERROR: API call failed');
        print('[RAZORPAY] Status Code: ${response.statusCode}');
        print('[RAZORPAY] Error Message: $errorMessage');
        throw Exception(errorMessage);
      }
    } on ApiException catch (e) {
      print('[RAZORPAY] ❌ API EXCEPTION: ${e.message}');
      throw Exception(e.message);
    } catch (e) {
      print('[RAZORPAY] ❌ EXCEPTION: $e');
      rethrow;
    }
  }

  /// Verify Razorpay Payment
  Future<PaymentVerificationResponse> verifyRazorpayPayment({
    required String emiPaymentId,
    required String razorpayOrderId,
    required String razorpayPaymentId,
    required String razorpaySignature,
  }) async {
    print('[RAZORPAY] ========== Verifying Razorpay Payment ==========');
    print('[RAZORPAY] EMI Payment ID: $emiPaymentId');
    print('[RAZORPAY] Order ID: $razorpayOrderId');
    print('[RAZORPAY] Payment ID: $razorpayPaymentId');
    
    final token = await _authService.getAuthToken();
    
    if (token == null || token.isEmpty) {
      print('[RAZORPAY] ❌ ERROR: Authentication token not found');
      throw Exception('Authentication required. Please login first.');
    }

    print('[RAZORPAY] ✅ Auth token found');
    final uri = Uri.parse(ApiConfig.razorpayVerify);
    print('[RAZORPAY] API Endpoint: $uri');

    final requestBody = {
      'emiPaymentId': emiPaymentId,
      'razorpay_order_id': razorpayOrderId,
      'razorpay_payment_id': razorpayPaymentId,
      'razorpay_signature': razorpaySignature,
    };
    
    print('[RAZORPAY] Request Body: ${jsonEncode(requestBody)}');
    print('[RAZORPAY] Sending POST request...');

    try {
      final response = await ApiClient.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(requestBody),
      );

      print('[RAZORPAY] Response Status Code: ${response.statusCode}');
      print('[RAZORPAY] Response Body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        try {
          final jsonData = jsonDecode(response.body) as Map<String, dynamic>;
          print('[RAZORPAY] ✅ Payment verified successfully');
          return PaymentVerificationResponse.fromJson(jsonData);
        } catch (e) {
          print('[RAZORPAY] ❌ ERROR: Failed to parse response: $e');
          print('[RAZORPAY] Response body: ${response.body}');
          throw Exception('Failed to parse response: $e');
        }
      } else {
        final errorMessage = _extractRazorpayErrorMessage(response.body, response.statusCode);
        print('[RAZORPAY] ❌ ERROR: API call failed');
        print('[RAZORPAY] Status Code: ${response.statusCode}');
        print('[RAZORPAY] Error Message: $errorMessage');
        throw Exception(errorMessage);
      }
    } on ApiException catch (e) {
      print('[RAZORPAY] ❌ API EXCEPTION: ${e.message}');
      throw Exception(e.message);
    } catch (e) {
      print('[RAZORPAY] ❌ EXCEPTION: $e');
      rethrow;
    }
  }

  String _extractErrorMessage(String responseBody) {
    try {
      final json = jsonDecode(responseBody) as Map<String, dynamic>;
      return json['message'] as String? ?? 
             'Failed to fetch EMIs (${responseBody.length > 100 ? responseBody.substring(0, 100) : responseBody})';
    } catch (_) {
      return 'Failed to fetch EMIs. Please try again.';
    }
  }

  String _extractRazorpayErrorMessage(String responseBody, int statusCode) {
    try {
      final json = jsonDecode(responseBody) as Map<String, dynamic>;
      final message = json['message'] as String?;
      
      if (message != null && message.isNotEmpty) {
        return message;
      }
      
      // Check for error field
      final error = json['error'] as String?;
      if (error != null && error.isNotEmpty) {
        return error;
      }
      
      // Status code based messages
      switch (statusCode) {
        case 400:
          return 'Invalid request. Please check the payment details.';
        case 401:
          return 'Authentication failed. Please login again.';
        case 403:
          return 'You do not have permission to perform this action.';
        case 404:
          return 'Payment endpoint not found. Please contact support.';
        case 500:
          return 'Server error. Please try again later.';
        default:
          return 'Failed to create payment order. Status: $statusCode';
      }
    } catch (e) {
      print('[RAZORPAY] Error parsing error message: $e');
      return 'Failed to create payment order. Please try again.';
    }
  }
}
