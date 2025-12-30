class ApiConfig {
  static const String baseUrl = 'http://192.168.31.70:3050/api';

  // Auth Endpoints
  static const String login = '$baseUrl/auth/login';
  static const String userProfile = '$baseUrl/users/me';
  
  // EMI Endpoints
  static const String myEmis = '$baseUrl/emis/my';
  static String emiPayments(String emiId) => '$baseUrl/emis/my/$emiId/payments';
  static const String checkDueEmis = '$baseUrl/emis/check-due';
  static const String pendingPayments = '$baseUrl/users/payments/pending';
  
  // Payment Endpoints
  static const String createRazorpayOrder = '$baseUrl/users/payments/razorpay/order';
  static const String verifyRazorpayPayment = '$baseUrl/users/payments/razorpay/verify';
  
  // FCM Endpoints
  static const String registerFcmToken = '$baseUrl/users/fcm-token';
  
  // Helper method to build URL with query parameters
  static Uri buildUri(String endpoint, {Map<String, String>? queryParameters}) {
    return Uri.parse(endpoint).replace(queryParameters: queryParameters);
  }
}

