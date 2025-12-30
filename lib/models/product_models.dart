import 'package:flutter/material.dart';

class ProductFilters {
  final List<String> categories;
  final List<String> priceRanges;
  final List<String> tenures;
  final List<String> quickFilters;

  const ProductFilters({
    required this.categories,
    required this.priceRanges,
    required this.tenures,
    required this.quickFilters,
  });
}

class ProductItem {
  final String title;
  final String subtitle;
  final String meta;
  final String price;
  final String emi;
  final String tag;
  final Color tagColor;
  final String rating;

  const ProductItem({
    required this.title,
    required this.subtitle,
    required this.meta,
    required this.price,
    required this.emi,
    required this.tag,
    required this.tagColor,
    required this.rating,
  });
}

















