import 'package:flutter/material.dart';

import '../../controllers/help_controller.dart';
import '../../models/help_models.dart';
import '../../utils/responsive.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key}) : _controller = const HelpController();

  final HelpController _controller;

  @override
  Widget build(BuildContext context) {
    final topics = _controller.getTopics();

    return Scaffold(
      body: SafeArea(
        child: ResponsivePage(
          child: SingleChildScrollView(
            child: Builder(
              builder: (context) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  SizedBox(height: Responsive.spacing(context, mobile: 16, tablet: 18, desktop: 20)),
                  _buildSearchBar(),
                  SizedBox(height: Responsive.spacing(context, mobile: 16, tablet: 18, desktop: 20)),
                  _buildSupportCard(),
                  SizedBox(height: Responsive.spacing(context, mobile: 16, tablet: 18, desktop: 20)),
                  _buildTopicsSection(topics),
                  SizedBox(height: Responsive.spacing(context, mobile: 16, tablet: 18, desktop: 20)),
                  _buildLockerPlanCard(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
  Widget _buildHeader() {
    return Builder(
      builder: (context) => Padding(
        padding: EdgeInsets.only(top: Responsive.spacing(context, mobile: 5, tablet: 8, desktop: 10)),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1F6AFF), Color(0xFF4B89FF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: CircleAvatar(
                radius: Responsive.spacing(context, mobile: 15, tablet: 17, desktop: 20),
                backgroundColor: Colors.white,
                child: Text(
                  'E',
                  style: TextStyle(
                    color: const Color(0xFF1F6AFF),
                    fontWeight: FontWeight.w800,
                    fontSize: Responsive.fontSize(context, mobile: 15, tablet: 17, desktop: 20),
                  ),
                ),
              ),
            ),
            SizedBox(width: Responsive.spacing(context, mobile: 14, tablet: 16, desktop: 18)),
            Text(
              'EMI Locker',
              style: TextStyle(
                fontSize: Responsive.fontSize(context, mobile: 20, tablet: 22, desktop: 24),
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Builder(
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(
            Responsive.spacing(context, mobile: 18, tablet: 20, desktop: 22),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black12.withOpacity(0.04),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: TextField(
          decoration: InputDecoration(
            hintText: 'Search help & FAQs...',
            hintStyle: TextStyle(
              color: Colors.black.withOpacity(0.4),
              fontSize: Responsive.fontSize(context, mobile: 14, tablet: 15, desktop: 16),
            ),
            prefixIcon: const Icon(Icons.search, color: Color(0xFF1F6AFF)),
            suffixIcon: const Icon(Icons.mic_none_outlined, color: Colors.grey),
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(
              vertical: Responsive.spacing(context, mobile: 14, tablet: 16, desktop: 18),
            ),
          ),
        ),
      ),
    );
  }


  Widget _buildSupportCard() {
    return Builder(
      builder: (context) => Container(
        padding: Responsive.padding(
          context,
          mobile: const EdgeInsets.all(22),
          tablet: const EdgeInsets.all(26),
          desktop: const EdgeInsets.all(30),
        ),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFDFEFF), Color(0xFFF4F7FF)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: BorderRadius.circular(
            Responsive.spacing(context, mobile: 24, tablet: 26, desktop: 28),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black12.withOpacity(0.05),
              blurRadius: 25,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Help & support',
              style: TextStyle(
                fontSize: Responsive.fontSize(context, mobile: 22, tablet: 24, desktop: 26),
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),

            SizedBox(height: Responsive.spacing(context, mobile: 8, tablet: 10, desktop: 12)),

            Text(
              'Quick answers for EMIs, payments & locker usage.',
              style: TextStyle(
                color: Colors.black.withOpacity(0.55),
                fontSize: Responsive.fontSize(context, mobile: 15, tablet: 16, desktop: 17),
              ),
            ),

            SizedBox(height: Responsive.spacing(context, mobile: 20, tablet: 24, desktop: 28)),

            Row(
              children: [
                Expanded(
                  child: _buildStatusTile(
                    context,
                    'Support status',
                    'Replies in under 10 min',
                    Colors.blue,
                  ),
                ),
                SizedBox(width: Responsive.spacing(context, mobile: 14, tablet: 16, desktop: 18)),
                Expanded(
                  child: _buildStatusTile(
                    context,
                    'Active tickets',
                    '0 open requests',
                    Colors.green,
                  ),
                ),
              ],
            ),

            SizedBox(height: Responsive.spacing(context, mobile: 18, tablet: 20, desktop: 22)),

            Container(
              padding: Responsive.padding(
                context,
                mobile: const EdgeInsets.all(14),
                tablet: const EdgeInsets.all(16),
                desktop: const EdgeInsets.all(18),
              ),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F2FF),
                borderRadius: BorderRadius.circular(
                  Responsive.spacing(context, mobile: 14, tablet: 16, desktop: 18),
                ),
              ),
              child: Text(
                'Trusted EMI guidance · RBI-compliant partners',
                style: TextStyle(
                  color: const Color(0xFF1F6AFF),
                  fontWeight: FontWeight.w700,
                  fontSize: Responsive.fontSize(context, mobile: 14, tablet: 15, desktop: 16),
                ),
              ),
            ),

            SizedBox(height: Responsive.spacing(context, mobile: 20, tablet: 24, desktop: 28)),

            LayoutBuilder(
              builder: (context, constraints) {
                final isSmallScreen = constraints.maxWidth < 350;
                if (isSmallScreen) {
                  // Stack vertically on very small screens
                  return Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () {},
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.symmetric(
                              vertical: Responsive.spacing(context, mobile: 14, tablet: 16, desktop: 18),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                Responsive.spacing(context, mobile: 16, tablet: 18, desktop: 20),
                              ),
                            ),
                          ),
                          child: Text(
                            'Browse FAQs',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: Responsive.fontSize(context, mobile: 14, tablet: 15, desktop: 16),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: Responsive.spacing(context, mobile: 12, tablet: 14, desktop: 16)),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {},
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1F6AFF),
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(
                              vertical: Responsive.spacing(context, mobile: 14, tablet: 16, desktop: 18),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                Responsive.spacing(context, mobile: 16, tablet: 18, desktop: 20),
                              ),
                            ),
                            elevation: 2,
                          ),
                          child: Text(
                            'Chat with support',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: Responsive.fontSize(context, mobile: 14, tablet: 15, desktop: 16),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                }
                // Row layout for larger screens
                return Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {},
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.symmetric(
                            vertical: Responsive.spacing(context, mobile: 14, tablet: 16, desktop: 18),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              Responsive.spacing(context, mobile: 16, tablet: 18, desktop: 20),
                            ),
                          ),
                        ),
                        child: Text(
                          'Browse FAQs',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: Responsive.fontSize(context, mobile: 14, tablet: 15, desktop: 16),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: Responsive.spacing(context, mobile: 14, tablet: 16, desktop: 18)),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {},
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1F6AFF),
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(
                            vertical: Responsive.spacing(context, mobile: 14, tablet: 16, desktop: 18),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              Responsive.spacing(context, mobile: 16, tablet: 18, desktop: 20),
                            ),
                          ),
                          elevation: 2,
                        ),
                        child: Text(
                          'Chat with support',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: Responsive.fontSize(context, mobile: 14, tablet: 15, desktop: 16),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildStatusTile(BuildContext context, String title, String subtitle, Color color) {
    return Container(
      padding: Responsive.padding(
        context,
        mobile: const EdgeInsets.all(16),
        tablet: const EdgeInsets.all(18),
        desktop: const EdgeInsets.all(20),
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(
          Responsive.spacing(context, mobile: 18, tablet: 20, desktop: 22),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: Responsive.fontSize(context, mobile: 15, tablet: 16, desktop: 17),
            ),
          ),
          SizedBox(height: Responsive.spacing(context, mobile: 6, tablet: 8, desktop: 10)),
          Text(
            subtitle,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: Responsive.fontSize(context, mobile: 13, tablet: 14, desktop: 15),
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildTopicsSection(List<HelpTopic> topics) {
    return Builder(
      builder: (context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Popular topics',
                style: TextStyle(
                  fontSize: Responsive.fontSize(context, mobile: 20, tablet: 22, desktop: 24),
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                'View all',
                style: TextStyle(
                  color: const Color(0xFF1F6AFF),
                  fontWeight: FontWeight.w700,
                  fontSize: Responsive.fontSize(context, mobile: 15, tablet: 16, desktop: 17),
                ),
              ),
            ],
          ),
          SizedBox(height: Responsive.spacing(context, mobile: 16, tablet: 18, desktop: 20)),

          ...topics.map((topic) {
            return Container(
              margin: EdgeInsets.only(
                bottom: Responsive.spacing(context, mobile: 14, tablet: 16, desktop: 18),
              ),
              padding: Responsive.padding(
                context,
                mobile: const EdgeInsets.all(18),
                tablet: const EdgeInsets.all(20),
                desktop: const EdgeInsets.all(22),
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(
                  Responsive.spacing(context, mobile: 20, tablet: 22, desktop: 24),
                ),
                border: Border.all(color: const Color(0xFFE6E8F2)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12.withOpacity(0.03),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    topic.title,
                    style: TextStyle(
                      fontSize: Responsive.fontSize(context, mobile: 16, tablet: 17, desktop: 18),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: Responsive.spacing(context, mobile: 10, tablet: 12, desktop: 14)),
                  ...topic.items.map((item) => Padding(
                    padding: EdgeInsets.symmetric(
                      vertical: Responsive.spacing(context, mobile: 4, tablet: 5, desktop: 6),
                    ),
                    child: Text(
                      item,
                      style: TextStyle(
                        color: Colors.black54,
                        fontSize: Responsive.fontSize(context, mobile: 14, tablet: 15, desktop: 16),
                      ),
                    ),
                  )),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildLockerPlanCard() {
    return Builder(
      builder: (context) => Container(
        padding: Responsive.padding(
          context,
          mobile: const EdgeInsets.all(18),
          tablet: const EdgeInsets.all(22),
          desktop: const EdgeInsets.all(26),
        ),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFFFFFF), Color(0xFFF5F7FF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(
            Responsive.spacing(context, mobile: 22, tablet: 24, desktop: 26),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black12.withOpacity(0.05),
              blurRadius: 25,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isSmallScreen = constraints.maxWidth < 400;
            if (isSmallScreen) {
              // Stack vertically on small screens
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your current EMI plan',
                        style: TextStyle(
                          fontSize: Responsive.fontSize(context, mobile: 16, tablet: 17, desktop: 18),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: Responsive.spacing(context, mobile: 6, tablet: 8, desktop: 10)),
                      Text(
                        '3 items in locker · Safe usage: 42%',
                        style: TextStyle(
                          color: Colors.black54,
                          fontSize: Responsive.fontSize(context, mobile: 14, tablet: 15, desktop: 16),
                        ),
                      ),
                      SizedBox(height: Responsive.spacing(context, mobile: 6, tablet: 8, desktop: 10)),
                      Text(
                        '₹25,397 / month · First EMI on 05 Jan',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: Responsive.fontSize(context, mobile: 15, tablet: 16, desktop: 17),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: Responsive.spacing(context, mobile: 12, tablet: 14, desktop: 16)),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {},
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1F6AFF),
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(
                          horizontal: Responsive.spacing(context, mobile: 20, tablet: 22, desktop: 24),
                          vertical: Responsive.spacing(context, mobile: 14, tablet: 16, desktop: 18),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            Responsive.spacing(context, mobile: 16, tablet: 18, desktop: 20),
                          ),
                        ),
                      ),
                      child: Text(
                        'View locker',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: Responsive.fontSize(context, mobile: 14, tablet: 15, desktop: 16),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }
            // Row layout for larger screens
            return Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your current EMI plan',
                        style: TextStyle(
                          fontSize: Responsive.fontSize(context, mobile: 16, tablet: 17, desktop: 18),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: Responsive.spacing(context, mobile: 6, tablet: 8, desktop: 10)),
                      Text(
                        '3 items in locker · Safe usage: 42%',
                        style: TextStyle(
                          color: Colors.black54,
                          fontSize: Responsive.fontSize(context, mobile: 14, tablet: 15, desktop: 16),
                        ),
                      ),
                      SizedBox(height: Responsive.spacing(context, mobile: 6, tablet: 8, desktop: 10)),
                      Text(
                        '₹25,397 / month · First EMI on 05 Jan',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: Responsive.fontSize(context, mobile: 15, tablet: 16, desktop: 17),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: Responsive.spacing(context, mobile: 12, tablet: 14, desktop: 16)),
                ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1F6AFF),
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(
                      horizontal: Responsive.spacing(context, mobile: 20, tablet: 22, desktop: 24),
                      vertical: Responsive.spacing(context, mobile: 14, tablet: 16, desktop: 18),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        Responsive.spacing(context, mobile: 16, tablet: 18, desktop: 20),
                      ),
                    ),
                  ),
                  child: Text(
                    'View locker',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: Responsive.fontSize(context, mobile: 14, tablet: 15, desktop: 16),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

}

