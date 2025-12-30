import 'package:flutter/material.dart';

import '../models/home_models.dart';

class HomeController {
  const HomeController();

  List<QuickFilter> getQuickFilters() {
    return const [
      QuickFilter(label: 'Most popular', icon: Icons.local_fire_department, selected: true),
      QuickFilter(label: 'Lowest EMI', icon: Icons.trending_down),
      QuickFilter(label: 'No-cost EMI', icon: Icons.verified),
      QuickFilter(label: 'Tenure ≤ 6m', icon: Icons.timer_outlined),
      QuickFilter(label: 'Top rated', icon: Icons.star_rate_rounded),
    ];
  }

  List<HomeCategoryCard> getTopCategories() {
    return const [
      HomeCategoryCard(
        title: 'Smartphones',
        subtitle: '3,240 options',
        price: 'From ₹899/mo',
        icon: Icons.phone_android_outlined,
      ),
      HomeCategoryCard(
        title: 'Laptops',
        subtitle: '1,120 options',
        price: 'From ₹1,499/mo',
        icon: Icons.laptop_outlined,
      ),
      HomeCategoryCard(
        title: 'Televisions',
        subtitle: '860 options',
        price: 'From ₹1,099/mo',
        icon: Icons.tv_outlined,
      ),
      HomeCategoryCard(
        title: 'Appliances',
        subtitle: '540 options',
        price: 'From ₹999/mo',
        icon: Icons.kitchen_outlined,
      ),
    ];
  }

  List<RecommendedEmi> getRecommendedEmis() {
    return const [
      RecommendedEmi(
        title: 'Galaxy S24 Pro 5G (256 GB)',
        price: '₹89,999',
        emiLabel: 'EMI from ₹14,999 / month · 6m',
        tenure: 'Best for 6 months',
        rating: 4.7,
      ),
      RecommendedEmi(
        title: 'iPhone 15 (128 GB, Blue)',
        price: '₹79,900',
        emiLabel: 'EMI from ₹8,399 / month · 9m',
        tenure: 'Safe pick',
        rating: 4.6,
      ),
      RecommendedEmi(
        title: 'Redmi Note 13 Pro (128 GB)',
        price: '₹24,999',
        emiLabel: 'EMI from ₹2,199 / month · 12m',
        tenure: 'Room for ₹12k more',
        rating: 4.3,
      ),
    ];
  }

  String getUsageSummary() => 'Using ~42% of your EMI eligibility';
}
