import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class LockScreen extends StatelessWidget {
  const LockScreen({
    super.key,
    required this.borrowerName,
    required this.loanNumber,
    required this.overdueAmount,
    required this.lockReason,
    required this.onMakePayment,
    required this.onContactSupport,
    this.lastUpdatedAt,
    required this.child,
  });

  final String borrowerName;
  final String loanNumber;
  final double overdueAmount;
  final String lockReason;
  final Future<void> Function() onMakePayment;
  final VoidCallback onContactSupport;
  final DateTime? lastUpdatedAt;
  final Widget child;

  String get _formattedAmount =>
      NumberFormat.currency(locale: 'en_IN', symbol: '₹')
          .format(overdueAmount);

  String get _timestamp => lastUpdatedAt != null
      ? DateFormat('hh:mm a, dd MMM yyyy').format(lastUpdatedAt!)
      : 'Just now';

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        Positioned.fill(
          child: AbsorbPointer(
            absorbing: true,
            child: Container(
              color: Colors.black.withOpacity(0.6),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 360),
                  child: Card(
                    margin: const EdgeInsets.all(24),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: const [
                              Icon(Icons.phonelink_lock, size: 32),
                              SizedBox(width: 12),
                              Text(
                                'Device locked',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Hi $borrowerName, we have locked this phone because an EMI payment is overdue.',
                            style: const TextStyle(fontSize: 16),
                          ),
                          const SizedBox(height: 16),
                          _InfoRow(
                            label: 'Loan number',
                            value: loanNumber,
                          ),
                          _InfoRow(
                            label: 'Amount pending',
                            value: _formattedAmount,
                          ),
                          if (lockReason.isNotEmpty)
                            _InfoRow(
                              label: 'Reason',
                              value: lockReason,
                            ),
                          _InfoRow(
                            label: 'Last synced',
                            value: _timestamp,
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            'To unlock your device, please clear the pending EMI or contact our support team for assistance.',
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: onMakePayment,
                              child: const Text('Pay EMI & Request Unlock'),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              onPressed: onContactSupport,
                              child: const Text('Contact support'),
                            ),
                          ),
                          const SizedBox(height: 16),
                          const _EmergencyNote(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.black54,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmergencyNote extends StatelessWidget {
  const _EmergencyNote();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: const [
        Icon(Icons.info_outline, size: 18, color: Colors.black54),
        SizedBox(width: 8),
        Expanded(
          child: Text(
            'Emergency calls remain enabled even when the phone is locked.',
            style: TextStyle(color: Colors.black54),
          ),
        ),
      ],
    );
  }
}
