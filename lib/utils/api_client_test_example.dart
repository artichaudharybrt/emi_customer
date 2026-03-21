// Example: How to test API error handling
// This file shows how the new ApiClient handles different error scenarios

import 'api_client.dart';

void main() async {
  // Example 1: Server Error (502 Bad Gateway)
  // Before: Would show HTML error page
  // After: Shows "Oops! Our server is having a moment. Sorry for the troubles"
  try {
    final response = await ApiClient.get(
      Uri.parse('https://dev.server.lock.brtmultisoftware.com/api/test'),
      headers: {'Content-Type': 'application/json'},
    );
    print('Success: ${response.body}');
  } on ApiException catch (e) {
    print('Error: ${e.message}'); // User-friendly message
    print('Error Type: ${e.type}');
    print('Status Code: ${e.statusCode}');
  }

  // Example 2: Network Error (No Internet)
  // Shows: "Oops! Our server is having a moment. Sorry for the troubles"
  try {
    final response = await ApiClient.get(
      Uri.parse('https://invalid-domain-that-does-not-exist.com/api'),
      headers: {'Content-Type': 'application/json'},
    );
    print('Success: ${response.body}');
  } on ApiException catch (e) {
    print('Error: ${e.message}');
    print('Error Type: ${e.type}'); // ApiErrorType.network
  }

  // Example 3: Timeout Error
  // Shows: "Oops! Our server is having a moment. Sorry for the troubles"
  try {
    final response = await ApiClient.get(
      Uri.parse('https://httpstat.us/200?sleep=35000'), // Takes 35 seconds
      headers: {'Content-Type': 'application/json'},
      timeout: const Duration(seconds: 5), // Timeout after 5 seconds
    );
    print('Success: ${response.body}');
  } on ApiException catch (e) {
    print('Error: ${e.message}');
    print('Error Type: ${e.type}'); // ApiErrorType.timeout
  }

  // Example 4: Authentication Error (401)
  // Shows: "Authentication failed. Please login again."
  try {
    final response = await ApiClient.get(
      Uri.parse('https://dev.server.lock.brtmultisoftware.com/api/users/me'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer invalid-token',
      },
    );
    print('Success: ${response.body}');
  } on ApiException catch (e) {
    print('Error: ${e.message}');
    print('Error Type: ${e.type}'); // ApiErrorType.clientError
    print('Status Code: ${e.statusCode}'); // 401
  }

  // Example 5: HTML Error Response (502 from nginx)
  // Before: Would try to parse HTML as JSON and crash
  // After: Shows "Oops! Our server is having a moment. Sorry for the troubles"
  try {
    // Simulate HTML error response
    final response = await ApiClient.get(
      Uri.parse('https://httpstat.us/502'),
      headers: {'Content-Type': 'application/json'},
    );
    print('Success: ${response.body}');
  } on ApiException catch (e) {
    print('Error: ${e.message}');
    print('Error Type: ${e.type}'); // ApiErrorType.serverError
    print('Status Code: ${e.statusCode}'); // 502
  }
}

// How to use in your services:
/*
class MyService {
  Future<void> fetchData() async {
    try {
      final response = await ApiClient.get(
        Uri.parse('https://api.example.com/data'),
        headers: {'Content-Type': 'application/json'},
      );
      
      // Process successful response
      final data = jsonDecode(response.body);
      print('Data: $data');
      
    } on ApiException catch (e) {
      // Handle error with user-friendly message
      print('Error: ${e.message}');
      
      // Show error to user
      // showDialog(context, e.message);
      
      // Or rethrow with custom message
      throw Exception(e.message);
    }
  }
}
*/
