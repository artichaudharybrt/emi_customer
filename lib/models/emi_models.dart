class EmiModel {
  final String id;
  final String userId;
  final String userName;
  final String userMobile;
  final String userEmail;
  final double principalAmount;
  final double interestPercentage;
  final double totalAmount;
  final String description;
  final String billNumber;
  final DateTime startDate;
  final String? paymentScheduleType;
  final List<DateTime> dueDates;
  final int paidInstallments;
  final int totalInstallments;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;

  EmiModel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userMobile,
    required this.userEmail,
    required this.principalAmount,
    required this.interestPercentage,
    required this.totalAmount,
    required this.description,
    required this.billNumber,
    required this.startDate,
    this.paymentScheduleType,
    required this.dueDates,
    required this.paidInstallments,
    required this.totalInstallments,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  // Calculated properties
  double get installmentAmount {
    if (totalInstallments > 0) {
      return totalAmount / totalInstallments;
    }
    return 0.0;
  }

  int get dueDay {
    if (dueDates.isNotEmpty) {
      return dueDates.first.day;
    }
    // Fallback to start date day if no due dates
    return startDate.day;
  }

  int get paidMonths => paidInstallments;
  int get totalMonths => totalInstallments;

  factory EmiModel.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>? ?? {};
    
    // Parse dueDates array
    final dueDatesList = json['dueDates'] as List<dynamic>? ?? [];
    final dueDates = dueDatesList.map((dateStr) {
      try {
        return DateTime.parse(dateStr as String);
      } catch (_) {
        return DateTime.now();
      }
    }).toList();
    
    return EmiModel(
      id: json['_id'] as String? ?? '',
      userId: user['_id'] as String? ?? user['id'] as String? ?? '',
      userName: user['fullName'] as String? ?? '',
      userMobile: user['mobile'] as String? ?? '',
      userEmail: user['email'] as String? ?? '',
      principalAmount: (json['principalAmount'] as num?)?.toDouble() ?? 0.0,
      interestPercentage: (json['interestPercentage'] as num?)?.toDouble() ?? 0.0,
      totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 0.0,
      description: json['description'] as String? ?? '',
      billNumber: json['billNumber'] as String? ?? '',
      startDate: json['startDate'] != null
          ? DateTime.parse(json['startDate'] as String)
          : DateTime.now(),
      paymentScheduleType: json['paymentScheduleType'] as String?,
      dueDates: dueDates,
      paidInstallments: json['paidInstallments'] as int? ?? 0,
      totalInstallments: json['totalInstallments'] as int? ?? 0,
      status: json['status'] as String? ?? 'active',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : DateTime.now(),
    );
  }

  // Convert to Map for UI compatibility
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'emiId': id, // For API calls
      'product': description.isNotEmpty ? description : (billNumber.isNotEmpty ? billNumber : 'EMI Product'),
      'image': 'assets/images/iphone.png', // Default image
      'amount': installmentAmount.toInt(),
      'months': totalInstallments,
      'paid': paidInstallments,
      'status': status,
      'totalAmount': totalAmount,
      'principalAmount': principalAmount,
      'interestPercentage': interestPercentage,
      'billNumber': billNumber,
      'description': description,
      'startDate': startDate,
      'dueDay': dueDay,
      'paymentScheduleType': paymentScheduleType,
      'dueDates': dueDates.map((d) => d.toIso8601String()).toList(),
    };
  }
}

class EmiResponse {
  final bool success;
  final String message;
  final List<EmiModel> data;
  final PaginationInfo pagination;

  EmiResponse({
    required this.success,
    required this.message,
    required this.data,
    required this.pagination,
  });

  factory EmiResponse.fromJson(Map<String, dynamic> json) {
    final dataList = json['data'] as List<dynamic>? ?? [];
    final paginationJson = json['pagination'] as Map<String, dynamic>? ?? {};

    return EmiResponse(
      success: json['success'] as bool? ?? false,
      message: json['message'] as String? ?? '',
      data: dataList.map((item) => EmiModel.fromJson(item as Map<String, dynamic>)).toList(),
      pagination: PaginationInfo.fromJson(paginationJson),
    );
  }
}

class PaginationInfo {
  final int page;
  final int limit;
  final int total;
  final int totalPages;
  final bool hasNextPage;
  final bool hasPrevPage;

  PaginationInfo({
    required this.page,
    required this.limit,
    required this.total,
    required this.totalPages,
    required this.hasNextPage,
    required this.hasPrevPage,
  });

  factory PaginationInfo.fromJson(Map<String, dynamic> json) {
    return PaginationInfo(
      page: json['page'] as int? ?? 1,
      limit: json['limit'] as int? ?? 10,
      total: json['total'] as int? ?? 0,
      totalPages: json['totalPages'] as int? ?? 1,
      hasNextPage: json['hasNextPage'] as bool? ?? false,
      hasPrevPage: json['hasPrevPage'] as bool? ?? false,
    );
  }
}

