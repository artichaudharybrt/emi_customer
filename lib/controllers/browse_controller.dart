import 'package:flutter/material.dart';

import '../models/product_models.dart';

class BrowseController {
  const BrowseController();

  ProductFilters getFilters() {
    return const ProductFilters(
      categories: ['Phones, laptops & more', 'Appliances', 'Gaming', 'Wearables'],
      priceRanges: ['Price ₹10k - ₹1L', 'Price ₹1L - ₹2L', 'Price ₹2L+'],
      tenures: ['Tenure 3-12m', 'Tenure 12-24m', 'Tenure 24m+'],
      quickFilters: ['No-cost EMI only', 'Lowest monthly EMI', 'Tenure ≤ 6 months', 'Tenure 3-12m'],
    );
  }

  List<ProductItem> getProducts() {
    return const [
      ProductItem(
        title: 'Galaxy S24 Pro 5G (256 GB)',
        subtitle: '₹89,999 · MRP ₹99,999 · 7% off',
        meta: 'Tenure: 3-12m · No-cost EMI',
        price: '₹89,999',
        emi: 'EMI from ₹14,999 / month · 6 months',
        tag: 'No-cost EMI',
        tagColor: Color(0xFF1B5E20),
        rating: '4.7 (2.3k)',
      ),
      ProductItem(
        title: 'iPhone 15 (128 GB, Blue)',
        subtitle: '₹79,900 · Incl. ₹1,703 bank interest',
        meta: 'Flexible pre-close · Credit card EMI',
        price: '₹79,900',
        emi: 'EMI from ₹8,399 / month · 9 months',
        tag: 'Bank EMI',
        tagColor: Color(0xFF0D47A1),
        rating: '4.6 (1.8k)',
      ),
      ProductItem(
        title: 'Redmi Note 13 Pro (128 GB)',
        subtitle: '₹24,999 · No-cost on 12m',
        meta: 'Best plan: ₹1,299 / month · 12 months',
        price: '₹24,999',
        emi: 'EMI from ₹2,199 / month · 12m',
        tag: 'Low EMI',
        tagColor: Color(0xFF1B5E20),
        rating: '4.3 (860)',
      ),
      ProductItem(
        title: 'HP Pavilion Ryzen 5, 16GB, 512GB SSD',
        subtitle: '₹62,990 · From partner lenders',
        meta: 'Laptop · EMI date: 5th monthly',
        price: '₹62,990',
        emi: 'EMI from ₹4,999 / month · 12m',
        tag: 'No-cost EMI',
        tagColor: Color(0xFF1B5E20),
        rating: '4.4 (540)',
      ),
    ];
  }
}

















