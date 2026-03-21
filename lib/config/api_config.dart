class ApiConfig {
  // Base URL
  static const String baseUrl = 'https://api.fasstpay.coo/api';

  // Auth Endpoints
  static const String login = '$baseUrl/auth/login';
  static const String userProfile = '$baseUrl/users/me';
  
  // EMI Endpoints
  static const String myEmis = '$baseUrl/emis/my';
  static String emiPayments(String emiId) => '$baseUrl/emis/my/$emiId/payments';
  static const String checkDueEmis = '$baseUrl/emis/check-due';
  static const String pendingPayments = '$baseUrl/users/payments/pending';
  
  // FCM Endpoints
  static const String registerFcmToken = '$baseUrl/users/fcm-token';

  // Location (FCM get_location_command)
  static const String userLocations = '$baseUrl/user-locations';

  // Device / SIM details - post when user grants phone permission (install time)
  static const String deviceSimDetails = '$baseUrl/device-sim-details';
  
  // Payment Endpoints
  static String getQrCode(String emiPaymentId) => '$baseUrl/users/payments/qr/$emiPaymentId';
  static const String verifyQrPayment = '$baseUrl/users/payments/qr/verify';
  static const String verifyBankPayment = '$baseUrl/users/payments/bank/verify';
  

  static const String razorpayOrder = '$baseUrl/users/payments/razorpay/order';
  static const String razorpayVerify = '$baseUrl/users/payments/razorpay/verify';
  
  // Razorpay Key
  static const String razorpayKey = 'rzp_live_RftawzItpzRh1C';
  
  // Helper method to build URL with query parameters
  static Uri buildUri(String endpoint, {Map<String, String>? queryParameters}) {
    return Uri.parse(endpoint).replace(queryParameters: queryParameters);
  }
}

