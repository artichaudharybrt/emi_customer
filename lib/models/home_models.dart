import 'package:flutter/material.dart';

class QuickFilter {
  const QuickFilter({
    required this.label,
    required this.icon,
    this.selected = false,
  });

  final String label;
  final IconData icon;
  final bool selected;
}

class HomeCategoryCard {
  const HomeCategoryCard({
    required this.title,
    required this.subtitle,
    required this.price,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final String price;
  final IconData icon;
}

class RecommendedEmi {
  const RecommendedEmi({
    required this.title,
    required this.price,
    required this.emiLabel,
    required this.tenure,
    required this.rating,
  });

  final String title;
  final String price;
  final String emiLabel;
  final String tenure;
  final double rating;
}

class UserProfile {
  final String id;
  final String fullName;
  final String? aadhar;
  final String? pan;
  final String mobile;
  final String email;
  final String? userKey;
  final bool isKeyActive;
  final bool isKeyExpired;
  final DateTime? keyExpiryDate;
  final DateTime createdAt;
  final DateTime updatedAt;

  UserProfile({
    required this.id,
    required this.fullName,
    this.aadhar,
    this.pan,
    required this.mobile,
    required this.email,
    this.userKey,
    this.isKeyActive = false,
    this.isKeyExpired = false,
    this.keyExpiryDate,
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['_id'] as String? ?? json['id'] as String? ?? '',
      fullName: json['fullName'] as String? ?? '',
      aadhar: json['aadhar'] as String?,
      pan: json['pan'] as String?,
      mobile: json['mobile'] as String? ?? '',
      email: json['email'] as String? ?? '',
      userKey: json['userKey'] as String?,
      isKeyActive: json['isKeyActive'] as bool? ?? false,
      isKeyExpired: json['isKeyExpired'] as bool? ?? false,
      keyExpiryDate: json['keyExpiryDate'] != null
          ? DateTime.parse(json['keyExpiryDate'] as String)
          : null,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : DateTime.now(),
    );
  }

  String getInitials() {
    if (fullName.isEmpty) return 'U';
    final parts = fullName.trim().split(' ');
    if (parts.length >= 2) {
      return (parts[0][0] + parts[1][0]).toUpperCase();
    }
    return fullName[0].toUpperCase();
  }
}

class UserProfileResponse {
  final bool success;
  final String message;
  final UserProfile data;

  UserProfileResponse({
    required this.success,
    required this.message,
    required this.data,
  });

  factory UserProfileResponse.fromJson(Map<String, dynamic> json) {
    return UserProfileResponse(
      success: json['success'] as bool? ?? false,
      message: json['message'] as String? ?? '',
      data: UserProfile.fromJson(json['data'] as Map<String, dynamic>),
    );
  }
}








