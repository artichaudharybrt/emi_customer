import 'package:flutter/material.dart';
import 'emi_details.dart';
import '../../utils/responsive.dart';
import '../../services/emi_service.dart';
import '../../services/app_overlay_service.dart';

class LockerScreen extends StatefulWidget {
  const LockerScreen({super.key});

  @override
  State<LockerScreen> createState() => _LockerScreenState();
}

class _LockerScreenState extends State<LockerScreen> {
  final EmiService _emiService = EmiService();
  List<Map<String, dynamic>> activeEmis = [];
  List<Map<String, dynamic>> completedEmis = [];
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchEmis();
  }

  Future<void> _fetchEmis() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final response = await _emiService.getMyEmis(page: 1, limit: 10);
      
      final active = <Map<String, dynamic>>[];
      final completed = <Map<String, dynamic>>[];

      for (var emi in response.data) {
        final emiMap = emi.toMap();
        if (emi.status.toLowerCase() == 'active') {
          active.add(emiMap);
        } else {
          completed.add(emiMap);
        }
      }

      setState(() {
        activeEmis = active;
        completedEmis = completed;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = e.toString().replaceAll('Exception: ', '');
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ResponsivePage(
          child: Builder(
            builder: (context) {
              if (isLoading) {
                return const Center(
                  child: CircularProgressIndicator(),
                );
              }

              if (errorMessage != null) {
                return Center(
                  child: Padding(
                    padding: Responsive.padding(
                      context,
                      mobile: const EdgeInsets.all(20.0),
                      tablet: const EdgeInsets.all(24.0),
                      desktop: const EdgeInsets.all(28.0),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: Responsive.spacing(context, mobile: 64, tablet: 72, desktop: 80),
                          color: Colors.red.shade300,
                        ),
                        SizedBox(height: Responsive.spacing(context, mobile: 16, tablet: 18, desktop: 20)),
                        Text(
                          'Error',
                          style: TextStyle(
                            fontSize: Responsive.fontSize(context, mobile: 20, tablet: 22, desktop: 24),
                            fontWeight: FontWeight.bold,
                            color: Colors.red.shade700,
                          ),
                        ),
                        SizedBox(height: Responsive.spacing(context, mobile: 8, tablet: 10, desktop: 12)),
                        Text(
                          errorMessage!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: Responsive.fontSize(context, mobile: 14, tablet: 15, desktop: 16),
                            color: Colors.grey.shade700,
                          ),
                        ),
                        SizedBox(height: Responsive.spacing(context, mobile: 24, tablet: 28, desktop: 32)),
                        ElevatedButton(
                          onPressed: _fetchEmis,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(
                              horizontal: Responsive.spacing(context, mobile: 24, tablet: 28, desktop: 32),
                              vertical: Responsive.spacing(context, mobile: 12, tablet: 14, desktop: 16),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                Responsive.spacing(context, mobile: 12, tablet: 14, desktop: 16),
                              ),
                            ),
                          ),
                          child: Text(
                            'Retry',
                            style: TextStyle(
                              fontSize: Responsive.fontSize(context, mobile: 14, tablet: 15, desktop: 16),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  vertical: Responsive.spacing(context, mobile: 5, tablet: 8, desktop: 10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    SizedBox(height: Responsive.spacing(context, mobile: 16, tablet: 18, desktop: 20)),
                    
                    // Test Overlay Buttons
                    Container(
                      margin: EdgeInsets.symmetric(
                        horizontal: Responsive.spacing(context, mobile: 16, tablet: 20, desktop: 24),
                      ),
                      child: Column(
                        children: [
                          // Check Due EMIs Button
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                final result = await AppOverlayService.checkAndShowOverlay(context);
                                if (!mounted) return;
                                
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      result 
                                        ? 'Overlay displayed successfully!' 
                                        : 'No due EMIs found',
                                    ),
                                    backgroundColor: result ? Colors.green : Colors.orange,
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.notification_important),
                              label: const Text('Check Due EMIs'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.symmetric(
                                  horizontal: Responsive.spacing(context, mobile: 20, tablet: 24, desktop: 28),
                                  vertical: Responsive.spacing(context, mobile: 14, tablet: 16, desktop: 18),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    Responsive.spacing(context, mobile: 12, tablet: 14, desktop: 16),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          
                          SizedBox(height: Responsive.spacing(context, mobile: 12, tablet: 14, desktop: 16)),
                          
                          // Force Show Test Overlay Button
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                await AppOverlayService.showTestOverlay(context);
                                if (!mounted) return;
                                
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Test overlay displayed!'),
                                    backgroundColor: Colors.green,
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.bug_report),
                              label: const Text('Force Show Test Overlay'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange,
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.symmetric(
                                  horizontal: Responsive.spacing(context, mobile: 20, tablet: 24, desktop: 28),
                                  vertical: Responsive.spacing(context, mobile: 14, tablet: 16, desktop: 18),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    Responsive.spacing(context, mobile: 12, tablet: 14, desktop: 16),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    SizedBox(height: Responsive.spacing(context, mobile: 16, tablet: 18, desktop: 20)),
                    
                    if (activeEmis.isNotEmpty) ...[
                      _sectionTitle(context, "Active EMIs"),
                      _emiGrid(context, activeEmis),
                      SizedBox(height: Responsive.spacing(context, mobile: 20, tablet: 24, desktop: 28)),
                    ],
                    if (completedEmis.isNotEmpty) ...[
                      _sectionTitle(context, "Completed EMIs"),
                      _emiGrid(context, completedEmis),
                    ],
                    if (activeEmis.isEmpty && completedEmis.isEmpty)
                      Center(
                        child: Padding(
                          padding: Responsive.padding(
                            context,
                            mobile: const EdgeInsets.all(40.0),
                            tablet: const EdgeInsets.all(48.0),
                            desktop: const EdgeInsets.all(56.0),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.inbox_outlined,
                                size: Responsive.spacing(context, mobile: 64, tablet: 72, desktop: 80),
                                color: Colors.grey.shade400,
                              ),
                              SizedBox(height: Responsive.spacing(context, mobile: 16, tablet: 18, desktop: 20)),
                              Text(
                                'No EMIs found',
                                style: TextStyle(
                                  fontSize: Responsive.fontSize(context, mobile: 18, tablet: 20, desktop: 22),
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                              SizedBox(height: Responsive.spacing(context, mobile: 8, tablet: 10, desktop: 12)),
                              Text(
                                'You don\'t have any EMIs yet',
                                style: TextStyle(
                                  fontSize: Responsive.fontSize(context, mobile: 14, tablet: 15, desktop: 16),
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
  Widget _buildHeader() {
    return Builder(
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          top: Responsive.spacing(context, mobile: 2, tablet: 4, desktop: 6),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(
                Responsive.spacing(context, mobile: 2, tablet: 3, desktop: 4),
              ),
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
              'SafeEMI',
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
  Widget _sectionTitle(BuildContext context, String title) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: Responsive.spacing(context, mobile: 10, tablet: 12, desktop: 14),
      ),
      child: Text(
        title,
        style: TextStyle(
          fontSize: Responsive.fontSize(context, mobile: 20, tablet: 22, desktop: 24),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _emiGrid(BuildContext context, List<Map<String, dynamic>> data) {
    final width = MediaQuery.of(context).size.width;
    final crossAxisCount = Responsive.columnsForWidth(
      width,
      mobile: 2,
      tablet: 3,
      desktop: 4,
    );

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: data.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: Responsive.spacing(context, mobile: 12, tablet: 16, desktop: 20),
        crossAxisSpacing: Responsive.spacing(context, mobile: 12, tablet: 16, desktop: 20),
        childAspectRatio: Responsive.isDesktop(width) ? 0.75 : (Responsive.isTablet(width) ? 0.78 : 0.78),
      ),
      itemBuilder: (context, index) {
        final emi = data[index];
        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                   BrowseProductsScreen(emiDetails: emi),
              ),
            );
          },
          child: Container(
            padding: Responsive.padding(
              context,
              mobile: const EdgeInsets.all(10),
              tablet: const EdgeInsets.all(12),
              desktop: const EdgeInsets.all(14),
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(
                Responsive.spacing(context, mobile: 16, tablet: 18, desktop: 20),
              ),
              color: Colors.grey.shade200,
            ),
            child: Column(
              children: [
                Expanded(
                  child: Image.asset(emi["image"], fit: BoxFit.contain),
                ),
                SizedBox(height: Responsive.spacing(context, mobile: 8, tablet: 10, desktop: 12)),
                Text(
                  emi["product"],
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: Responsive.fontSize(context, mobile: 14, tablet: 15, desktop: 16),
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: Responsive.spacing(context, mobile: 5, tablet: 6, desktop: 8)),
                Text(
                  "₹${emi["amount"]}/month",
                  style: TextStyle(
                    fontSize: Responsive.fontSize(context, mobile: 13, tablet: 14, desktop: 15),
                    color: Colors.black54,
                  ),
                ),
                SizedBox(height: Responsive.spacing(context, mobile: 4, tablet: 5, desktop: 6)),
                Text(
                  "Tenure: ${emi["months"]} months\nPaid: ${emi["paid"]}",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: Responsive.fontSize(context, mobile: 12, tablet: 13, desktop: 14),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

