import 'emi_models.dart';

class PaymentModel {
  final String id;
  final String emiId;
  final String userId;
  final int month;
  final int year;
  final DateTime dueDate;
  final int extendDays;
  final String status;
  final bool alertSent;
  final bool secondAlertSent;
  final DateTime createdAt;
  final DateTime updatedAt;

  PaymentModel({
    required this.id,
    required this.emiId,
    required this.userId,
    required this.month,
    required this.year,
    required this.dueDate,
    required this.extendDays,
    required this.status,
    required this.alertSent,
    required this.secondAlertSent,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PaymentModel.fromJson(Map<String, dynamic> json) {
    return PaymentModel(
      id: json['_id'] as String? ?? '',
      emiId: json['emiId'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      month: json['month'] as int? ?? 0,
      year: json['year'] as int? ?? 0,
      dueDate: json['dueDate'] != null
          ? DateTime.parse(json['dueDate'] as String)
          : DateTime.now(),
      extendDays: json['extendDays'] as int? ?? 0,
      status: json['status'] as String? ?? 'pending',
      alertSent: json['alertSent'] as bool? ?? false,
      secondAlertSent: json['secondAlertSent'] as bool? ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : DateTime.now(),
    );
  }
}

class PaymentResponse {
  final bool success;
  final String message;
  final List<PaymentModel> data;

  PaymentResponse({
    required this.success,
    required this.message,
    required this.data,
  });

  factory PaymentResponse.fromJson(Map<String, dynamic> json) {
    final dataList = json['data'] as List<dynamic>? ?? [];

    return PaymentResponse(
      success: json['success'] as bool? ?? false,
      message: json['message'] as String? ?? '',
      data: dataList.map((item) => PaymentModel.fromJson(item as Map<String, dynamic>)).toList(),
    );
  }
}

// Model for Pending Payment/Installment
class PendingPaymentModel {
  final String id;
  final EmiInfo emiId;
  final String userId;
  final int installmentNumber;
  final DateTime dueDate;
  final double amount;
  final double percentage;
  final int extendDays;
  final String status;
  final bool alertSent;
  final bool secondAlertSent;
  final DateTime createdAt;
  final DateTime updatedAt;

  PendingPaymentModel({
    required this.id,
    required this.emiId,
    required this.userId,
    required this.installmentNumber,
    required this.dueDate,
    required this.amount,
    required this.percentage,
    required this.extendDays,
    required this.status,
    required this.alertSent,
    required this.secondAlertSent,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PendingPaymentModel.fromJson(Map<String, dynamic> json) {
    final emiIdJson = json['emiId'] as Map<String, dynamic>? ?? {};
    
    return PendingPaymentModel(
      id: json['_id'] as String? ?? '',
      emiId: EmiInfo.fromJson(emiIdJson),
      userId: json['userId'] as String? ?? '',
      installmentNumber: json['installmentNumber'] as int? ?? 0,
      dueDate: json['dueDate'] != null
          ? DateTime.parse(json['dueDate'] as String)
          : DateTime.now(),
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      percentage: (json['percentage'] as num?)?.toDouble() ?? 0.0,
      extendDays: json['extendDays'] as int? ?? 0,
      status: json['status'] as String? ?? 'pending',
      alertSent: json['alertSent'] as bool? ?? false,
      secondAlertSent: json['secondAlertSent'] as bool? ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : DateTime.now(),
    );
  }
}

class EmiInfo {
  final String id;
  final double totalAmount;
  final String billNumber;

  EmiInfo({
    required this.id,
    required this.totalAmount,
    required this.billNumber,
  });

  factory EmiInfo.fromJson(Map<String, dynamic> json) {
    return EmiInfo(
      id: json['_id'] as String? ?? '',
      totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 0.0,
      billNumber: json['billNumber'] as String? ?? '',
    );
  }
}

class PendingPaymentResponse {
  final bool success;
  final String message;
  final List<PendingPaymentModel> data;
  final PaginationInfo? pagination;

  PendingPaymentResponse({
    required this.success,
    required this.message,
    required this.data,
    this.pagination,
  });

  factory PendingPaymentResponse.fromJson(Map<String, dynamic> json) {
    final dataList = json['data'] as List<dynamic>? ?? [];
    final paginationJson = json['pagination'] as Map<String, dynamic>?;

    return PendingPaymentResponse(
      success: json['success'] as bool? ?? false,
      message: json['message'] as String? ?? '',
      data: dataList.map((item) => PendingPaymentModel.fromJson(item as Map<String, dynamic>)).toList(),
      pagination: paginationJson != null ? PaginationInfo.fromJson(paginationJson) : null,
    );
  }
}


