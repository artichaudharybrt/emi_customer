import 'package:flutter/foundation.dart';

enum LockStatus { unlocked, grace, locked }

class LockSnapshot {
  const LockSnapshot({
    required this.lockStatus,
    required this.loanSummary,
    required this.lockReason,
    required this.lastUpdatedAt,
  });

  final LockStatus lockStatus;
  final LoanSummary loanSummary;
  final String? lockReason;
  final DateTime lastUpdatedAt;

  LockSnapshot copyWith({
    LockStatus? lockStatus,
    LoanSummary? loanSummary,
    String? lockReason,
    DateTime? lastUpdatedAt,
  }) {
    return LockSnapshot(
      lockStatus: lockStatus ?? this.lockStatus,
      loanSummary: loanSummary ?? this.loanSummary,
      lockReason: lockReason ?? this.lockReason,
      lastUpdatedAt: lastUpdatedAt ?? this.lastUpdatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'lockStatus': lockStatus.name,
      'loanSummary': loanSummary.toJson(),
      'lockReason': lockReason,
      'lastUpdatedAt': lastUpdatedAt.toIso8601String(),
    };
  }

  factory LockSnapshot.fromJson(Map<String, dynamic> json) {
    return LockSnapshot(
      lockStatus: LockStatus.values.byName(json['lockStatus'] as String),
      loanSummary:
          LoanSummary.fromJson(json['loanSummary'] as Map<String, dynamic>),
      lockReason: json['lockReason'] as String?,
      lastUpdatedAt: DateTime.parse(json['lastUpdatedAt'] as String),
    );
  }
}

class LoanSummary {
  const LoanSummary({
    required this.customerName,
    required this.loanNumber,
    required this.outstandingPrincipal,
    required this.nextDueDate,
    required this.nextDueAmount,
    required this.overdueAmount,
    required this.schedule,
  });

  final String customerName;
  final String loanNumber;
  final double outstandingPrincipal;
  final DateTime nextDueDate;
  final double nextDueAmount;
  final double overdueAmount;
  final List<EmiScheduleEntry> schedule;

  LoanSummary copyWith({
    String? customerName,
    String? loanNumber,
    double? outstandingPrincipal,
    DateTime? nextDueDate,
    double? nextDueAmount,
    double? overdueAmount,
    List<EmiScheduleEntry>? schedule,
  }) {
    return LoanSummary(
      customerName: customerName ?? this.customerName,
      loanNumber: loanNumber ?? this.loanNumber,
      outstandingPrincipal:
          outstandingPrincipal ?? this.outstandingPrincipal,
      nextDueDate: nextDueDate ?? this.nextDueDate,
      nextDueAmount: nextDueAmount ?? this.nextDueAmount,
      overdueAmount: overdueAmount ?? this.overdueAmount,
      schedule: schedule ?? this.schedule,
    );
  }

  @override
  String toString() {
    return 'LoanSummary($loanNumber for $customerName, next EMI $nextDueAmount on $nextDueDate, overdue $overdueAmount)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LoanSummary &&
        other.customerName == customerName &&
        other.loanNumber == loanNumber &&
        other.outstandingPrincipal == outstandingPrincipal &&
        other.nextDueDate == nextDueDate &&
        other.nextDueAmount == nextDueAmount &&
        other.overdueAmount == overdueAmount &&
        listEquals(other.schedule, schedule);
  }

  @override
  int get hashCode => Object.hashAll([
        customerName,
        loanNumber,
        outstandingPrincipal,
        nextDueDate,
        nextDueAmount,
        overdueAmount,
        Object.hashAll(schedule),
      ]);

  Map<String, dynamic> toJson() {
    return {
      'customerName': customerName,
      'loanNumber': loanNumber,
      'outstandingPrincipal': outstandingPrincipal,
      'nextDueDate': nextDueDate.toIso8601String(),
      'nextDueAmount': nextDueAmount,
      'overdueAmount': overdueAmount,
      'schedule': schedule.map((entry) => entry.toJson()).toList(),
    };
  }

  factory LoanSummary.fromJson(Map<String, dynamic> json) {
    return LoanSummary(
      customerName: json['customerName'] as String,
      loanNumber: json['loanNumber'] as String,
      outstandingPrincipal:
          (json['outstandingPrincipal'] as num).toDouble(),
      nextDueDate: DateTime.parse(json['nextDueDate'] as String),
      nextDueAmount: (json['nextDueAmount'] as num).toDouble(),
      overdueAmount: (json['overdueAmount'] as num).toDouble(),
      schedule: (json['schedule'] as List<dynamic>)
          .map((entry) =>
              EmiScheduleEntry.fromJson(entry as Map<String, dynamic>))
          .toList(),
    );
  }
}

class EmiScheduleEntry {
  const EmiScheduleEntry({
    required this.dueDate,
    required this.amount,
    required this.paid,
  });

  final DateTime dueDate;
  final double amount;
  final bool paid;

  Map<String, dynamic> toJson() {
    return {
      'dueDate': dueDate.toIso8601String(),
      'amount': amount,
      'paid': paid,
    };
  }

  factory EmiScheduleEntry.fromJson(Map<String, dynamic> json) {
    return EmiScheduleEntry(
      dueDate: DateTime.parse(json['dueDate'] as String),
      amount: (json['amount'] as num).toDouble(),
      paid: json['paid'] as bool,
    );
  }
}
