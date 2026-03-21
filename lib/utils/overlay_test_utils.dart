import 'package:flutter/material.dart';
import '../services/app_overlay_service.dart';
import '../services/system_overlay_service.dart';
import '../models/emi_models.dart';

/// Utility class for testing overlay functionality
class OverlayTestUtils {
  
  /// Test 1: Clear all overlay state and show fresh overlay
  static Future<void> testClearAndShow(BuildContext context) async {
    debugPrint('[OverlayTest] ========== TEST 1: CLEAR AND SHOW ==========');
    
    try {
      // Create dummy EMI for testing
      final dummyEmi = EmiModel(
        id: 'test_emi_123',
        userId: 'test_user',
        userName: 'Test User',
        userMobile: '1234567890',
        userEmail: 'test@example.com',
        principalAmount: 10000.0,
        interestPercentage: 12.0,
        totalAmount: 12000.0,
        description: 'Test EMI Payment',
        billNumber: 'TEST-001',
        startDate: DateTime.now(),
        dueDates: [DateTime.now().add(const Duration(days: 30))],
        paidInstallments: 0,
        totalInstallments: 12,
        status: 'active',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      
      // Force clear and show
      await AppOverlayService.forceShowOverlay(context, dummyEmi);
      
      debugPrint('[OverlayTest] ✅ Test 1 completed');
    } catch (e) {
      debugPrint('[OverlayTest] ❌ Test 1 failed: $e');
    }
  }
  
  /// Test 2: Test system overlay permission and display
  static Future<void> testSystemOverlayPermission() async {
    debugPrint('[OverlayTest] ========== TEST 2: SYSTEM OVERLAY PERMISSION ==========');
    
    try {
      // Check permission
      final hasPermission = await SystemOverlayService.hasOverlayPermission();
      debugPrint('[OverlayTest] Has permission: $hasPermission');
      
      if (!hasPermission) {
        debugPrint('[OverlayTest] Requesting permission...');
        await SystemOverlayService.requestOverlayPermission();
        
        // Wait and check again
        await Future.delayed(const Duration(seconds: 3));
        final hasPermissionAfter = await SystemOverlayService.hasOverlayPermission();
        debugPrint('[OverlayTest] Has permission after request: $hasPermissionAfter');
      }
      
      debugPrint('[OverlayTest] ✅ Test 2 completed');
    } catch (e) {
      debugPrint('[OverlayTest] ❌ Test 2 failed: $e');
    }
  }
  
  /// Test 3: Test system overlay display
  static Future<void> testSystemOverlayDisplay() async {
    debugPrint('[OverlayTest] ========== TEST 3: SYSTEM OVERLAY DISPLAY ==========');
    
    try {
      // Show system overlay
      await SystemOverlayService.showSystemOverlay(
        title: 'TEST OVERLAY',
        message: 'This is a test system overlay. Switch to another app to see if it appears over it.',
        amount: '9999',
        billNumber: 'TEST-123',
      );
      
      debugPrint('[OverlayTest] System overlay display command sent');
      
      // Check if showing
      await Future.delayed(const Duration(seconds: 1));
      final isShowing = await SystemOverlayService.isSystemOverlayShowing();
      debugPrint('[OverlayTest] Is system overlay showing: $isShowing');
      
      debugPrint('[OverlayTest] ✅ Test 3 completed');
    } catch (e) {
      debugPrint('[OverlayTest] ❌ Test 3 failed: $e');
    }
  }
  
  /// Test 4: Hide all overlays
  static Future<void> testHideAllOverlays() async {
    debugPrint('[OverlayTest] ========== TEST 4: HIDE ALL OVERLAYS ==========');
    
    try {
      // Hide system overlay
      await SystemOverlayService.hideSystemOverlay();
      
      // Hide app overlay
      await AppOverlayService.hideOverlay(reason: 'Test hide all');
      
      debugPrint('[OverlayTest] ✅ Test 4 completed - all overlays hidden');
    } catch (e) {
      debugPrint('[OverlayTest] ❌ Test 4 failed: $e');
    }
  }
  
  /// Run all tests in sequence
  static Future<void> runAllTests(BuildContext context) async {
    debugPrint('[OverlayTest] ========== RUNNING ALL OVERLAY TESTS ==========');
    
    await testSystemOverlayPermission();
    await Future.delayed(const Duration(seconds: 2));
    
    await testSystemOverlayDisplay();
    await Future.delayed(const Duration(seconds: 5));
    
    await testClearAndShow(context);
    await Future.delayed(const Duration(seconds: 5));
    
    await testHideAllOverlays();
    
    debugPrint('[OverlayTest] ========== ALL TESTS COMPLETED ==========');
  }
}