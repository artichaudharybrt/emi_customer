import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/emi_models.dart';
import '../models/payment_models.dart';
import '../config/api_config.dart';
import 'auth_service.dart';

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

    final response = await http.get(
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
  }

  /// Check for due EMIs from backend
  Future<List<EmiModel>> checkDueEmis() async {
    final token = await _authService.getAuthToken();
    
    if (token == null || token.isEmpty) {
      throw Exception('Authentication required. Please login first.');
    }

    try {
      final response = await http.get(
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

    final response = await http.get(
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
  }

  /// Fetch pending payments/installments
  Future<PendingPaymentResponse> getPendingPayments() async {
    final token = await _authService.getAuthToken();
    
    if (token == null || token.isEmpty) {
      throw Exception('Authentication required. Please login first.');
    }

    final uri = Uri.parse(ApiConfig.pendingPayments);

    final response = await http.get(
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
}
