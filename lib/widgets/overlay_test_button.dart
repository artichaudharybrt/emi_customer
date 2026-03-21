import 'package:flutter/material.dart';
import '../services/app_overlay_service.dart';
import '../models/emi_models.dart';

class OverlayTestButton extends StatelessWidget {
  const OverlayTestButton({super.key});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      onPressed: () async {
        // Create a test EMI
        final testEmi = EmiModel(
          id: 'test_emi_123',
          userId: 'test_user',
          userName: 'Test User',
          userMobile: '9999999999',
          userEmail: 'test@example.com',
          principalAmount: 10000.0,
          interestPercentage: 4.0,
          totalAmount: 10400.0,
          description: 'Test EMI - Payment Due',
          billNumber: 'BILL-TEST-001',
          startDate: DateTime.now().subtract(const Duration(days: 30)),
          paymentScheduleType: '3',
          dueDates: [DateTime.now()],
          paidInstallments: 0,
          totalInstallments: 3,
          status: 'active',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        // Show the overlay
        await AppOverlayService.showOverlay(context, testEmi);
      },
      child: const Icon(Icons.lock),
      tooltip: 'Test Lock Overlay',
    );
  }
}
