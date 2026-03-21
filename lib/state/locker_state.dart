import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/lock_models.dart';
import '../services/auth_service.dart';
import '../utils/device_control.dart';
import '../utils/device_fingerprint.dart';

enum AuthStatus { unknown, unauthenticated, authenticated }

class LockerState extends ChangeNotifier {
  LockerState(this._backend) {
    _bootstrap();
  }

  static const _prefsTokenKey = 'locker_device_token';
  static const _prefsSnapshotKey = 'locker_snapshot';

  final AuthService _backend;
  SharedPreferences? _prefs;
  String? _deviceToken;
  final NumberFormat _currency =
      NumberFormat.currency(locale: 'en_IN', symbol: '₹');
  AuthStatus authStatus = AuthStatus.unknown;
  LockStatus lockStatus = LockStatus.unlocked;
  String? lockReason;
  LoanSummary? loanSummary;
  bool isBusy = false;
  DateTime? lastUpdatedAt;
  String? errorMessage;

  Future<void> _bootstrap() async {
    try {
      _prefs ??= await SharedPreferences.getInstance();
      final storedToken = _prefs?.getString(_prefsTokenKey);
      if (storedToken != null) {
        _deviceToken = storedToken;
        final cachedSnapshot = _prefs?.getString(_prefsSnapshotKey);
        if (cachedSnapshot != null) {
          final snapshot =
              LockSnapshot.fromJson(jsonDecode(cachedSnapshot));
          await _applySnapshot(snapshot, persist: false);
        }
        authStatus = AuthStatus.authenticated;
        await refresh();
      } else {
        authStatus = AuthStatus.unauthenticated;
      }
    } catch (error) {
      errorMessage = 'Failed to load startup data. Please retry.';
      authStatus = AuthStatus.unauthenticated;
    } finally {
      notifyListeners();
    }
  }

  Future<void> signIn(String phoneNumber, String otp) async {
    isBusy = true;
    errorMessage = null;
    notifyListeners();
    try {
      // Create a mock snapshot for demo
      final snapshot = _createMockSnapshot();
      final prefs = await _obtainPrefs();
      _deviceToken = 'mock-device-token';
      await prefs.setString(_prefsTokenKey, _deviceToken!);
      authStatus = AuthStatus.authenticated;
      await DeviceControl.requestAdmin();
      await DeviceControl.requestOverlayPermission();
      await _applySnapshot(snapshot);
      final deviceId = await DeviceFingerprint.hashedDeviceId();
      debugPrint('Device registered with hash: $deviceId');
    } catch (error) {
      errorMessage = 'Unable to sign in. Please try again.';
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    isBusy = true;
    notifyListeners();
    final prefs = await _obtainPrefs();
    await DeviceControl.hideOverlay();
    await DeviceControl.unlock();
    _deviceToken = null;
    await prefs.remove(_prefsTokenKey);
    await prefs.remove(_prefsSnapshotKey);
    authStatus = AuthStatus.unauthenticated;
    isBusy = false;
    loanSummary = null;
    lastUpdatedAt = null;
    lockReason = null;
    lockStatus = LockStatus.unlocked;
    notifyListeners();
  }

  Future<void> refresh() async {
    isBusy = true;
    notifyListeners();
    try {
      final snapshot = _createMockSnapshot();
      await _applySnapshot(snapshot);
    } catch (error) {
      errorMessage ??= 'Could not reach the server. Showing cached data.';
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }

  Future<void> acknowledgePayment() async {
    isBusy = true;
    notifyListeners();
    try {
      final snapshot = _createMockUnlockedSnapshot();
      await _applySnapshot(snapshot);
    } catch (error) {
      errorMessage = 'Payment acknowledgement failed.';
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }

  Future<void> reportMissedPayment() async {
    isBusy = true;
    notifyListeners();
    try {
      final snapshot = _createMockSnapshot();
      await _applySnapshot(snapshot);
    } catch (error) {
      errorMessage = 'Unable to sync missed payment status.';
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }

  void clearError() {
    errorMessage = null;
    notifyListeners();
  }

  Future<void> _applySnapshot(
    LockSnapshot snapshot, {
    bool persist = true,
  }) async {
    debugPrint('Lock state transition: ${lockStatus.name} -> ${snapshot.lockStatus.name}');
    loanSummary = snapshot.loanSummary;
    lockStatus = snapshot.lockStatus;
    lockReason = snapshot.lockReason;
    lastUpdatedAt = snapshot.lastUpdatedAt;
    errorMessage = null;
    if (persist) {
      final prefs = await _obtainPrefs();
      await prefs.setString(
        _prefsSnapshotKey,
        jsonEncode(snapshot.toJson()),
      );
    }
    if (snapshot.lockStatus == LockStatus.locked) {
      await DeviceControl.lockNow();
      final overlayPayload = {
        'borrowerName': snapshot.loanSummary.customerName,
        'loanNumber': snapshot.loanSummary.loanNumber,
        'overdueAmount': _currency.format(snapshot.loanSummary.overdueAmount),
        'lockReason': snapshot.lockReason ?? 'EMI overdue',
      };
      await DeviceControl.showOverlay(overlayPayload);
    } else {
      await DeviceControl.unlock();
      await DeviceControl.hideOverlay();
    }
  }

  bool get isLocked => lockStatus == LockStatus.locked;
  bool get isInGrace => lockStatus == LockStatus.grace;

  Future<SharedPreferences> _obtainPrefs() async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  LockSnapshot _createMockSnapshot() {
    return LockSnapshot(
      lockStatus: LockStatus.locked,
      loanSummary: LoanSummary(
        customerName: 'John Doe',
        loanNumber: 'LN001234567',
        outstandingPrincipal: 50000.0,
        nextDueDate: DateTime.now().subtract(const Duration(days: 5)),
        nextDueAmount: 5000.0,
        overdueAmount: 5000.0,
        schedule: [
          EmiScheduleEntry(
            dueDate: DateTime.now().subtract(const Duration(days: 5)),
            amount: 5000.0,
            paid: false,
          ),
        ],
      ),
      lockReason: 'EMI overdue',
      lastUpdatedAt: DateTime.now(),
    );
  }

  LockSnapshot _createMockUnlockedSnapshot() {
    return LockSnapshot(
      lockStatus: LockStatus.unlocked,
      loanSummary: LoanSummary(
        customerName: 'John Doe',
        loanNumber: 'LN001234567',
        outstandingPrincipal: 45000.0,
        nextDueDate: DateTime.now().add(const Duration(days: 25)),
        nextDueAmount: 5000.0,
        overdueAmount: 0.0,
        schedule: [
          EmiScheduleEntry(
            dueDate: DateTime.now().subtract(const Duration(days: 5)),
            amount: 5000.0,
            paid: true,
          ),
        ],
      ),
      lockReason: null,
      lastUpdatedAt: DateTime.now(),
    );
  }
}
