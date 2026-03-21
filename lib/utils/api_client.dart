import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

/// Centralized API client with user-friendly error handling
class ApiClient {
  /// Make a GET request with proper error handling
  static Future<http.Response> get(
    Uri uri, {
    Map<String, String>? headers,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    try {
      final response = await http.get(uri, headers: headers).timeout(
        timeout,
        onTimeout: () {
          throw ApiException(
            'Oops! Our server is having a moment. Sorry for the troubles',
            type: ApiErrorType.timeout,
          );
        },
      );
      
      return _handleResponse(response);
    } on SocketException {
      throw ApiException(
        'Oops! Our server is having a moment. Sorry for the troubles',
        type: ApiErrorType.network,
      );
    } on http.ClientException {
      throw ApiException(
        'Oops! Our server is having a moment. Sorry for the troubles',
        type: ApiErrorType.network,
      );
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(
        'Oops! Our server is having a moment. Sorry for the troubles',
        type: ApiErrorType.unknown,
      );
    }
  }

  /// Make a POST request with proper error handling
  static Future<http.Response> post(
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    try {
      final response = await http.post(
        uri,
        headers: headers,
        body: body,
      ).timeout(
        timeout,
        onTimeout: () {
          throw ApiException(
            'Oops! Our server is having a moment. Sorry for the troubles',
            type: ApiErrorType.timeout,
          );
        },
      );
      
      return _handleResponse(response);
    } on SocketException {
      throw ApiException(
        'Oops! Our server is having a moment. Sorry for the troubles',
        type: ApiErrorType.network,
      );
    } on http.ClientException {
      throw ApiException(
        'Oops! Our server is having a moment. Sorry for the troubles',
        type: ApiErrorType.network,
      );
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(
        'Oops! Our server is having a moment. Sorry for the troubles',
        type: ApiErrorType.unknown,
      );
    }
  }

  /// Handle HTTP response and check for errors
  static http.Response _handleResponse(http.Response response) {
    // Check if response is HTML (502 Bad Gateway, 503 Service Unavailable, etc.)
    final contentType = response.headers['content-type'] ?? '';
    final isHtml = contentType.contains('text/html') || 
                   response.body.trim().startsWith('<html') ||
                   response.body.trim().startsWith('<!DOCTYPE');

    // Handle server errors (5xx)
    if (response.statusCode >= 500) {
      throw ApiException(
        'Oops! Our server is having a moment. Sorry for the troubles',
        statusCode: response.statusCode,
        type: ApiErrorType.serverError,
      );
    }

    // Handle HTML responses (usually nginx/proxy errors)
    if (isHtml && response.statusCode != 200) {
      throw ApiException(
        'Oops! Our server is having a moment. Sorry for the troubles',
        statusCode: response.statusCode,
        type: ApiErrorType.serverError,
      );
    }

    // Handle client errors (4xx)
    if (response.statusCode >= 400 && response.statusCode < 500) {
      String errorMessage = 'Request failed';
      
      try {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        errorMessage = json['message'] as String? ?? 
                      json['error'] as String? ?? 
                      errorMessage;
      } catch (_) {
        // If JSON parsing fails, use default message
        if (response.statusCode == 401) {
          errorMessage = 'Authentication failed. Please login again.';
        } else if (response.statusCode == 403) {
          errorMessage = 'You do not have permission to perform this action.';
        } else if (response.statusCode == 404) {
          errorMessage = 'Resource not found.';
        }
      }
      
      throw ApiException(
        errorMessage,
        statusCode: response.statusCode,
        type: ApiErrorType.clientError,
      );
    }

    return response;
  }
}

/// Custom exception for API errors
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final ApiErrorType type;

  ApiException(
    this.message, {
    this.statusCode,
    this.type = ApiErrorType.unknown,
  });

  @override
  String toString() => message;
}

/// Types of API errors
enum ApiErrorType {
  network,      // No internet or connection failed
  timeout,      // Request timeout
  serverError,  // 5xx errors
  clientError,  // 4xx errors
  unknown,      // Unknown error
}
