import 'package:flutter/material.dart';

import '../../models/category.dart';
import '../../utils/responsive.dart';

class CategoryCard extends StatelessWidget {
  const CategoryCard({super.key, required this.data});

  final Category data;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: Responsive.padding(
        context,
        mobile: const EdgeInsets.all(16),
        tablet: const EdgeInsets.all(18),
        desktop: const EdgeInsets.all(20),
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(
          Responsive.spacing(context, mobile: 18, tablet: 20, desktop: 22),
        ),
        border: Border.all(color: const Color(0xFFE6E8F2)),
      ),
      child: Row(
        children: [
          Container(
            width: Responsive.spacing(context, mobile: 52, tablet: 56, desktop: 60),
            height: Responsive.spacing(context, mobile: 52, tablet: 56, desktop: 60),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(
                Responsive.spacing(context, mobile: 14, tablet: 16, desktop: 18),
              ),
              color: const Color(0xFFF0F4FF),
            ),
            child: Icon(
              Icons.devices_other,
              color: const Color(0xFF1F6AFF),
              size: Responsive.spacing(context, mobile: 24, tablet: 26, desktop: 28),
            ),
          ),
          SizedBox(width: Responsive.spacing(context, mobile: 16, tablet: 18, desktop: 20)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.title,
                  style: TextStyle(
                    fontSize: Responsive.fontSize(context, mobile: 16, tablet: 17, desktop: 18),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: Responsive.spacing(context, mobile: 4, tablet: 5, desktop: 6)),
                Text(
                  data.subtitle,
                  style: TextStyle(
                    color: Colors.black54,
                    fontSize: Responsive.fontSize(context, mobile: 14, tablet: 15, desktop: 16),
                  ),
                ),
                SizedBox(height: Responsive.spacing(context, mobile: 4, tablet: 5, desktop: 6)),
                Text(
                  data.emi,
                  style: TextStyle(
                    color: const Color(0xFF1F6AFF),
                    fontWeight: FontWeight.w600,
                    fontSize: Responsive.fontSize(context, mobile: 14, tablet: 15, desktop: 16),
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right,
            color: Colors.black38,
            size: Responsive.spacing(context, mobile: 20, tablet: 22, desktop: 24),
          ),
        ],
      ),
    );
  }
}










