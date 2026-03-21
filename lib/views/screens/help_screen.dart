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
      backgroundColor: const Color(0xFFF6F8FC),
      body: SafeArea(
        child: ResponsivePage(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(context),
                SizedBox(height: Responsive.spacing(context, mobile: 16, tablet: 18, desktop: 20)),
                _buildSearchBar(context),
                SizedBox(height: Responsive.spacing(context, mobile: 16, tablet: 18, desktop: 20)),
                _buildSupportCard(context),
                SizedBox(height: Responsive.spacing(context, mobile: 20, tablet: 22, desktop: 24)),
                _buildTopicsSection(context, topics),
                SizedBox(height: Responsive.spacing(context, mobile: 20, tablet: 22, desktop: 24)),

              ],
            ),
          ),
        ),
      ),
    );
  }

  // ================= HEADER =================

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        top: Responsive.spacing(context, mobile: 8, tablet: 10, desktop: 12),
        bottom: Responsive.spacing(context, mobile: 12, tablet: 14, desktop: 16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1F6AFF), Color(0xFF4B89FF)],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withOpacity(0.35),
                  blurRadius: 12,
                ),
              ],
            ),
            child: CircleAvatar(
              radius: Responsive.spacing(context, mobile: 16, tablet: 18, desktop: 20),
              backgroundColor: Colors.white,
              child: Text(
                'E',
                style: TextStyle(
                  color: const Color(0xFF1F6AFF),
                  fontWeight: FontWeight.w900,
                  fontSize: Responsive.fontSize(context, mobile: 16, tablet: 18, desktop: 20),
                ),
              ),
            ),
          ),
          SizedBox(width: Responsive.spacing(context, mobile: 14, tablet: 16, desktop: 18)),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'EMI Locker',
                style: TextStyle(
                  fontSize: Responsive.fontSize(context, mobile: 20, tablet: 22, desktop: 24),
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                'Help & customer support',
                style: TextStyle(
                  fontSize: Responsive.fontSize(context, mobile: 13, tablet: 14, desktop: 15),
                  color: Colors.black54,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ================= SEARCH =================

  Widget _buildSearchBar(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(
          Responsive.spacing(context, mobile: 20, tablet: 22, desktop: 24),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1F6AFF).withOpacity(0.08),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: TextField(
        decoration: InputDecoration(
          hintText: 'Search EMIs, payments, locker issues...',
          hintStyle: TextStyle(
            color: Colors.black45,
            fontSize: Responsive.fontSize(context, mobile: 14, tablet: 15, desktop: 16),
          ),
          prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF1F6AFF)),
          suffixIcon: const Icon(Icons.mic_none_rounded, color: Colors.grey),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(
            vertical: Responsive.spacing(context, mobile: 15, tablet: 17, desktop: 19),
          ),
        ),
      ),
    );
  }

  // ================= SUPPORT CARD =================

  Widget _buildSupportCard(BuildContext context) {
    return Container(
      padding: Responsive.padding(
        context,
        mobile: const EdgeInsets.all(22),
        tablet: const EdgeInsets.all(26),
        desktop: const EdgeInsets.all(30),
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFFFFF), Color(0xFFF4F7FF)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(
          Responsive.spacing(context, mobile: 24, tablet: 26, desktop: 28),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black12.withOpacity(0.06),
            blurRadius: 26,
            offset: const Offset(0, 12),
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
            ),
          ),
          SizedBox(height: Responsive.spacing(context, mobile: 8, tablet: 10, desktop: 12)),
          Text(
            'Quick answers for EMIs, payments & locker usage.',
            style: TextStyle(
              color: Colors.black54,
              fontSize: Responsive.fontSize(context, mobile: 15, tablet: 16, desktop: 17),
            ),
          ),
          SizedBox(height: Responsive.spacing(context, mobile: 22, tablet: 26, desktop: 30)),
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
        ],
      ),
    );
  }

  Widget _buildStatusTile(
      BuildContext context,
      String title,
      String subtitle,
      Color color,
      ) {
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
      child: Row(
        children: [
          Icon(Icons.verified_rounded, color: color),
          SizedBox(width: Responsive.spacing(context, mobile: 10, tablet: 12, desktop: 14)),
          Expanded(
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
          ),
        ],
      ),
    );
  }

  // ================= TOPICS =================

  Widget _buildTopicsSection(BuildContext context, List<HelpTopic> topics) {
    return Column(
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
            width: double.infinity,
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
                ...topic.items.map(
                      (item) => Padding(
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
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

}
