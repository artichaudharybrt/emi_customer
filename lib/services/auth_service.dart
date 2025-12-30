import 'dart:convert';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import '../models/home_models.dart';

class AuthService {
  static const String _authTokenKey = 'auth_token';
  static const String _googleAccountKey = 'google_account';
  static const String _deviceIdKey = 'device_id';
  static const String _isGoogleAccountBoundKey = 'is_google_account_bound';

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
  );

  // Get current Google account
  GoogleSignInAccount? get currentUser => _googleSignIn.currentUser;

  /// Perform credential login and persist the returned token
  Future<String> login({
    required String emailOrMobile,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse(ApiConfig.login),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'emailOrMobile': emailOrMobile,
        'password': password,
      }),
    );

    Map<String, dynamic> payload = {};
    try {
      payload = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      // Non-JSON response; keep payload empty for messaging below.
    }

    if (response.statusCode == 200 || response.statusCode == 201) {
      final token = _extractToken(payload);
      if (token == null || token.isEmpty) {
        throw Exception('Login succeeded but no token returned');
      }

      await _storeAuthToken(token);
      return token;
    }

    final message = payload['message'] ?? 'Login failed (${response.statusCode})';
    throw Exception(message.toString());
  }

  String? _extractToken(Map<String, dynamic> payload) {
    final data = payload['data'];
    final candidates = [
      payload['token'],
      payload['accessToken'],
      payload['access_token'],
      data is Map<String, dynamic> ? data['token'] : null,
      data is Map<String, dynamic> ? data['accessToken'] : null,
      data is Map<String, dynamic> ? data['access_token'] : null,
    ];

    for (final candidate in candidates) {
      if (candidate is String && candidate.isNotEmpty) {
        return candidate;
      }
    }
    return null;
  }

  // Check if user is signed in with Google
  Future<bool> isSignedInWithGoogle() async {
    return await _googleSignIn.isSignedIn();
  }

  // Sign in with Google
  Future<GoogleSignInAccount?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? account = await _googleSignIn.signIn();
      
      if (account != null) {
        // Store Google account information
        await _storeGoogleAccount(account);
        
        // Store device ID and bind Google account to device
        await _bindGoogleAccountToDevice();
        
        return account;
      }
      return null;
    } catch (e) {
      throw Exception('Google Sign-In failed: $e');
    }
  }

  // Sign out
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _clearStoredAccount();
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_authTokenKey);
    await signOut();
  }

  Future<String?> getAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_authTokenKey);
  }

  Future<bool> hasAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_authTokenKey);
  }

  // Store Google account information
  Future<void> _storeGoogleAccount(GoogleSignInAccount account) async {
    final prefs = await SharedPreferences.getInstance();
    final accountData = {
      'id': account.id,
      'email': account.email,
      'displayName': account.displayName,
      'photoUrl': account.photoUrl,
      'serverAuthCode': account.serverAuthCode,
    };
    await prefs.setString(_googleAccountKey, jsonEncode(accountData));
    await prefs.setBool(_isGoogleAccountBoundKey, true);
  }

  // Get stored Google account
  Future<Map<String, dynamic>?> getStoredGoogleAccount() async {
    final prefs = await SharedPreferences.getInstance();
    final accountJson = prefs.getString(_googleAccountKey);
    if (accountJson != null) {
      return jsonDecode(accountJson) as Map<String, dynamic>;
    }
    return null;
  }

  // Bind Google account to device
  Future<void> _bindGoogleAccountToDevice() async {
    final prefs = await SharedPreferences.getInstance();
    final deviceInfo = DeviceInfoPlugin();
    
    // Get device ID
    String deviceId;
    try {
      final androidInfo = await deviceInfo.androidInfo;
      deviceId = androidInfo.id; // Android ID
    } catch (e) {
      // Fallback for iOS or other platforms
      deviceId = 'device_${DateTime.now().millisecondsSinceEpoch}';
    }
    
    // Store device ID
    await prefs.setString(_deviceIdKey, deviceId);
    
    // Store binding timestamp
    await prefs.setString('google_account_bound_at', DateTime.now().toIso8601String());
  }

  // Get device ID
  Future<String?> getDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_deviceIdKey);
  }

  // Check if Google account is bound to device
  Future<bool> isGoogleAccountBound() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_isGoogleAccountBoundKey) ?? false;
  }

  // Clear stored account information
  Future<void> _clearStoredAccount() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_googleAccountKey);
    await prefs.setBool(_isGoogleAccountBoundKey, false);
  }

  // Verify Google account matches stored account (for FRP check)
  Future<bool> verifyGoogleAccountBinding() async {
    final storedAccount = await getStoredGoogleAccount();
    if (storedAccount == null) return false;

    final currentAccount = await _googleSignIn.signInSilently();
    if (currentAccount == null) return false;

    // Check if the signed-in account matches the stored account
    return currentAccount.id == storedAccount['id'] &&
           currentAccount.email == storedAccount['email'];
  }

  // Get FRP protection status message
  Future<String> getFRPStatusMessage() async {
    final isBound = await isGoogleAccountBound();
    final storedAccount = await getStoredGoogleAccount();
    
    if (isBound && storedAccount != null) {
      return 'Google Account Protection Active\n'
             'Account: ${storedAccount['email']}\n'
             'This device is protected. After factory reset, you will need this Google account to unlock.';
    }
    return 'No Google Account Protection\n'
           'Sign in with Google to enable Factory Reset Protection (FRP)';
  }

  Future<void> _storeAuthToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_authTokenKey, token);
  }

  /// Fetch current user profile
  Future<UserProfileResponse> getUserProfile() async {
    final token = await getAuthToken();
    
    if (token == null || token.isEmpty) {
      throw Exception('Authentication required. Please login first.');
    }

    final response = await http.get(
      Uri.parse(ApiConfig.userProfile),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    Map<String, dynamic> payload = {};
    try {
      payload = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw Exception('Invalid response format');
    }

    if (response.statusCode == 200 || response.statusCode == 201) {
      return UserProfileResponse.fromJson(payload);
    }

    final message = payload['message'] ?? 'Failed to fetch profile (${response.statusCode})';
    throw Exception(message.toString());
  }
}



