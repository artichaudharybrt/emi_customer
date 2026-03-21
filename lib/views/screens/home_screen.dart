import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/emi_service.dart';
import '../../utils/responsive.dart';
import '../../models/home_models.dart';
import '../../models/payment_models.dart';
import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AuthService _authService = AuthService();
  final EmiService _emiService = EmiService();
  UserProfile? _userProfile;
  bool _isLoading = true;
  String? _errorMessage;
  
  // EMI data
  PendingPaymentModel? _nearestInstallment;
  int _activeEmiCount = 0;
  double _totalMonthlyAmount = 0.0;
  bool _isLoadingEmiData = false;

  @override
  void initState() {
    super.initState();
    _fetchUserProfile();
    _fetchEmiData();
  }

  Future<void> _fetchUserProfile() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await _authService.getUserProfile();
      setState(() {
        _userProfile = response.data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchEmiData() async {
    setState(() {
      _isLoadingEmiData = true;
    });

    try {
      // Fetch pending payments to get nearest installment
      final pendingResponse = await _emiService.getPendingPayments();
      
      // Find nearest pending installment (sort by due date, find first pending)
      PendingPaymentModel? nearestPending;
      if (pendingResponse.data.isNotEmpty) {
        final pendingList = pendingResponse.data
            .where((p) => p.status.toLowerCase() == 'pending')
            .toList()
          ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
        
        if (pendingList.isNotEmpty) {
          nearestPending = pendingList.first;
        }
      }

      // Fetch active EMIs to get count and total monthly amount
      final emiResponse = await _emiService.getMyEmis(page: 1, limit: 100);
      final activeEmis = emiResponse.data
          .where((emi) => emi.status.toLowerCase() == 'active')
          .toList();
      
      double totalMonthly = 0.0;
      for (var emi in activeEmis) {
        totalMonthly += emi.installmentAmount;
      }

      setState(() {
        _nearestInstallment = nearestPending;
        _activeEmiCount = activeEmis.length;
        _totalMonthlyAmount = totalMonthly;
        _isLoadingEmiData = false;
      });
    } catch (e) {
      print('Error fetching EMI data: $e');
      setState(() {
        _isLoadingEmiData = false;
      });
    }
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${date.day.toString().padLeft(2, '0')} ${months[date.month - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F5FA),
      body: SafeArea(
        child: ResponsivePage(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              vertical: Responsive.spacing(context, mobile: 5, tablet: 8, desktop: 10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(context),
                SizedBox(height: Responsive.spacing(context, mobile: 16, tablet: 18, desktop: 20)),
                _buildSearchBar(context, 'Search for active EMI'),
                SizedBox(height: Responsive.spacing(context, mobile: 16, tablet: 18, desktop: 20)),
                _buildHeroCard(context),
                SizedBox(height: Responsive.spacing(context, mobile: 16, tablet: 18, desktop: 20)),
                _buildLockerSummary(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // HEADER
  // ------------------------------------------------------------
  Widget _buildHeader(BuildContext context) {
    return Padding(
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
            'Fasst Pay',
            style: TextStyle(
              fontSize: Responsive.fontSize(context, mobile: 20, tablet: 22, desktop: 24),
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const Spacer(),
          // Logout button hidden
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // SEARCH BAR
  // ------------------------------------------------------------
  Widget _buildSearchBar(BuildContext context, String hint) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(
          Responsive.spacing(context, mobile: 16, tablet: 18, desktop: 20),
        ),
        color: Colors.white.withOpacity(0.9),
        boxShadow: [
          BoxShadow(
            color: Colors.black12.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          )
        ],
      ),
      child: TextField(
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            fontSize: Responsive.fontSize(context, mobile: 14, tablet: 15, desktop: 16),
          ),
          prefixIcon: const Icon(Icons.search, color: Colors.blueAccent),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(
            horizontal: Responsive.spacing(context, mobile: 16, tablet: 18, desktop: 20),
            vertical: Responsive.spacing(context, mobile: 14, tablet: 16, desktop: 18),
          ),
        ),
      ),
    );
  }


  // ------------------------------------------------------------
  // HERO CARD (PROFILE + SUMMARIES)
  // ------------------------------------------------------------
  Widget _buildHeroCard(BuildContext context) {
    return Container(
      padding: Responsive.padding(
        context,
        mobile: const EdgeInsets.all(20),
        tablet: const EdgeInsets.all(24),
        desktop: const EdgeInsets.all(28),
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFDFEFF), Color(0xFFF3F6FF)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(
          Responsive.spacing(context, mobile: 22, tablet: 24, desktop: 26),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black12.withOpacity(0.08),
            blurRadius: 30,
            offset: const Offset(0, 12),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// Profile Row
          _isLoading
              ? Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(
                        Responsive.spacing(context, mobile: 2, tablet: 3, desktop: 4),
                      ),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF4C6FFF), Color(0xFF1B44E6)],
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: CircleAvatar(
                        radius: Responsive.spacing(context, mobile: 26, tablet: 28, desktop: 30),
                        backgroundColor: Colors.white,
                        child: SizedBox(
                          width: Responsive.spacing(context, mobile: 20, tablet: 22, desktop: 24),
                          height: Responsive.spacing(context, mobile: 20, tablet: 22, desktop: 24),
                          child: const CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1F3FFF)),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: Responsive.spacing(context, mobile: 14, tablet: 16, desktop: 18)),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            height: Responsive.fontSize(context, mobile: 18, tablet: 20, desktop: 22),
                            width: 120,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          SizedBox(height: Responsive.spacing(context, mobile: 4, tablet: 5, desktop: 6)),
                          Container(
                            height: Responsive.fontSize(context, mobile: 13, tablet: 14, desktop: 15),
                            width: 100,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                )
              : _errorMessage != null
                  ? Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(
                            Responsive.spacing(context, mobile: 2, tablet: 3, desktop: 4),
                          ),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF4C6FFF), Color(0xFF1B44E6)],
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: CircleAvatar(
                            radius: Responsive.spacing(context, mobile: 26, tablet: 28, desktop: 30),
                            backgroundColor: Colors.white,
                            child: Icon(
                              Icons.error_outline,
                              color: Colors.red,
                              size: Responsive.spacing(context, mobile: 20, tablet: 22, desktop: 24),
                            ),
                          ),
                        ),
                        SizedBox(width: Responsive.spacing(context, mobile: 14, tablet: 16, desktop: 18)),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Error loading profile',
                                style: TextStyle(
                                  fontSize: Responsive.fontSize(context, mobile: 18, tablet: 20, desktop: 22),
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              SizedBox(height: Responsive.spacing(context, mobile: 4, tablet: 5, desktop: 6)),
                              Text(
                                _errorMessage!,
                                style: TextStyle(
                                  color: Colors.red.shade700,
                                  fontSize: Responsive.fontSize(context, mobile: 12, tablet: 13, desktop: 14),
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.refresh),
                          onPressed: _fetchUserProfile,
                          tooltip: 'Retry',
                        ),
                      ],
                    )
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        final isSmallScreen = constraints.maxWidth < 350;
                        if (isSmallScreen) {
                          // Stack vertically on very small screens
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: EdgeInsets.all(
                                      Responsive.spacing(context, mobile: 2, tablet: 3, desktop: 4),
                                    ),
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [Color(0xFF4C6FFF), Color(0xFF1B44E6)],
                                      ),
                                      shape: BoxShape.circle,
                                    ),
                                    child: CircleAvatar(
                                      radius: Responsive.spacing(context, mobile: 24, tablet: 26, desktop: 28),
                                      backgroundColor: Colors.white,
                                      child: Text(
                                        _userProfile?.getInitials() ?? 'U',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: Responsive.fontSize(context, mobile: 18, tablet: 20, desktop: 22),
                                          color: const Color(0xFF1F3FFF),
                                        ),
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: Responsive.spacing(context, mobile: 12, tablet: 14, desktop: 16)),
                                  Expanded(
                                    child: Text(
                                      _userProfile?.fullName ?? 'User',
                                      style: TextStyle(
                                        fontSize: Responsive.fontSize(context, mobile: 18, tablet: 20, desktop: 22),
                                        fontWeight: FontWeight.w800,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: Responsive.spacing(context, mobile: 8, tablet: 10, desktop: 12)),
                              if (_userProfile?.userKey != null)
                                Text(
                                  'ID: ${_userProfile!.userKey}',
                                  style: TextStyle(
                                    color: Colors.black54,
                                    fontSize: Responsive.fontSize(context, mobile: 13, tablet: 14, desktop: 15),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              if (_userProfile?.userKey != null && _userProfile?.mobile != null)
                                SizedBox(height: Responsive.spacing(context, mobile: 2, tablet: 3, desktop: 4)),
                              if (_userProfile?.mobile != null)
                                Text(
                                  'Mobile: ${_userProfile!.mobile}',
                                  style: TextStyle(
                                    color: Colors.black54,
                                    fontSize: Responsive.fontSize(context, mobile: 13, tablet: 14, desktop: 15),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              SizedBox(height: Responsive.spacing(context, mobile: 8, tablet: 10, desktop: 12)),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: Responsive.spacing(context, mobile: 10, tablet: 12, desktop: 14),
                                    vertical: Responsive.spacing(context, mobile: 5, tablet: 6, desktop: 7),
                                  ),
                                  decoration: BoxDecoration(
                                    color: (_userProfile?.isKeyActive ?? false) && !(_userProfile?.isKeyExpired ?? true)
                                        ? const Color(0xFFE6EEFF)
                                        : Colors.grey.shade200,
                                    borderRadius: BorderRadius.circular(
                                      Responsive.spacing(context, mobile: 10, tablet: 12, desktop: 14),
                                    ),
                                  ),
                                  child: Text(
                                    (_userProfile?.isKeyActive ?? false) && !(_userProfile?.isKeyExpired ?? true)
                                        ? 'Verified'
                                        : 'Unverified',
                                    style: TextStyle(
                                      color: (_userProfile?.isKeyActive ?? false) && !(_userProfile?.isKeyExpired ?? true)
                                          ? const Color(0xFF1F6AFF)
                                          : Colors.grey.shade600,
                                      fontWeight: FontWeight.w700,
                                      fontSize: Responsive.fontSize(context, mobile: 12, tablet: 13, desktop: 14),
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
                            Container(
                              padding: EdgeInsets.all(
                                Responsive.spacing(context, mobile: 2, tablet: 3, desktop: 4),
                              ),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF4C6FFF), Color(0xFF1B44E6)],
                                ),
                                shape: BoxShape.circle,
                              ),
                              child: CircleAvatar(
                                radius: Responsive.spacing(context, mobile: 26, tablet: 28, desktop: 30),
                                backgroundColor: Colors.white,
                                child: Text(
                                  _userProfile?.getInitials() ?? 'U',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: Responsive.fontSize(context, mobile: 20, tablet: 22, desktop: 24),
                                    color: const Color(0xFF1F3FFF),
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(width: Responsive.spacing(context, mobile: 14, tablet: 16, desktop: 18)),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _userProfile?.fullName ?? 'User',
                                    style: TextStyle(
                                      fontSize: Responsive.fontSize(context, mobile: 18, tablet: 20, desktop: 22),
                                      fontWeight: FontWeight.w800,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  SizedBox(height: Responsive.spacing(context, mobile: 4, tablet: 5, desktop: 6)),
                                  if (_userProfile?.userKey != null)
                                    Text(
                                      'ID: ${_userProfile!.userKey}',
                                      style: TextStyle(
                                        color: Colors.black54,
                                        fontSize: Responsive.fontSize(context, mobile: 13, tablet: 14, desktop: 15),
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  if (_userProfile?.userKey != null && _userProfile?.mobile != null)
                                    SizedBox(height: Responsive.spacing(context, mobile: 2, tablet: 3, desktop: 4)),
                                  if (_userProfile?.mobile != null)
                                    Text(
                                      'Mobile: ${_userProfile!.mobile}',
                                      style: TextStyle(
                                        color: Colors.black54,
                                        fontSize: Responsive.fontSize(context, mobile: 13, tablet: 14, desktop: 15),
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                ],
                              ),
                            ),
                            Flexible(
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: Responsive.spacing(context, mobile: 10, tablet: 12, desktop: 14),
                                  vertical: Responsive.spacing(context, mobile: 6, tablet: 7, desktop: 8),
                                ),
                                decoration: BoxDecoration(
                                  color: (_userProfile?.isKeyActive ?? false) && !(_userProfile?.isKeyExpired ?? true)
                                      ? const Color(0xFFE6EEFF)
                                      : Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(
                                    Responsive.spacing(context, mobile: 12, tablet: 14, desktop: 16),
                                  ),
                                ),
                                child: Text(
                                  (_userProfile?.isKeyActive ?? false) && !(_userProfile?.isKeyExpired ?? true)
                                      ? 'Verified'
                                      : 'Unverified',
                                  style: TextStyle(
                                    color: (_userProfile?.isKeyActive ?? false) && !(_userProfile?.isKeyExpired ?? true)
                                        ? const Color(0xFF1F6AFF)
                                        : Colors.grey.shade600,
                                    fontWeight: FontWeight.w700,
                                    fontSize: Responsive.fontSize(context, mobile: 12, tablet: 13, desktop: 14),
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),

          SizedBox(height: Responsive.spacing(context, mobile: 22, tablet: 24, desktop: 26)),

          /// EMI Summary Section
          Container(
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
              boxShadow: [
                BoxShadow(
                  color: Colors.black12.withOpacity(0.04),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                )
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(
                    Responsive.spacing(context, mobile: 10, tablet: 12, desktop: 14),
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF0FF),
                    borderRadius: BorderRadius.circular(
                      Responsive.spacing(context, mobile: 14, tablet: 16, desktop: 18),
                    ),
                  ),
                  child: Icon(
                    Icons.payments_outlined,
                    color: const Color(0xFF1F6AFF),
                    size: Responsive.spacing(context, mobile: 28, tablet: 30, desktop: 32),
                  ),
                ),
                SizedBox(width: Responsive.spacing(context, mobile: 14, tablet: 16, desktop: 18)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Active EMIs',
                        style: TextStyle(
                          fontSize: Responsive.fontSize(context, mobile: 16, tablet: 17, desktop: 18),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: Responsive.spacing(context, mobile: 4, tablet: 5, desktop: 6)),
                      _isLoadingEmiData
                          ? Text(
                              'Loading...',
                              style: TextStyle(
                                color: Colors.black54,
                                fontSize: Responsive.fontSize(context, mobile: 14, tablet: 15, desktop: 16),
                              ),
                            )
                          : Text(
                              _nearestInstallment != null
                                  ? '$_activeEmiCount running • Next EMI on ${_formatDate(_nearestInstallment!.dueDate)}'
                                  : '$_activeEmiCount running',
                              style: TextStyle(
                                color: Colors.black54,
                                fontSize: Responsive.fontSize(context, mobile: 14, tablet: 15, desktop: 16),
                              ),
                            ),
                    ],
                  ),
                ),
                _isLoadingEmiData
                    ? SizedBox(
                        width: Responsive.spacing(context, mobile: 20, tablet: 22, desktop: 24),
                        height: Responsive.spacing(context, mobile: 20, tablet: 22, desktop: 24),
                        child: const CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1F6AFF)),
                        ),
                      )
                    : Text(
                        '₹${_totalMonthlyAmount.toStringAsFixed(0)}/m',
                        style: TextStyle(
                          fontSize: Responsive.fontSize(context, mobile: 17, tablet: 18, desktop: 19),
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF1F6AFF),
                        ),
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }


  // ------------------------------------------------------------
  // LOCKER SUMMARY (Improved Card)
  // ------------------------------------------------------------
  Widget _buildLockerSummary() {
    return Builder(
      builder: (context) => Container(
        padding: Responsive.padding(
          context,
          mobile: const EdgeInsets.all(20),
          tablet: const EdgeInsets.all(24),
          desktop: const EdgeInsets.all(28),
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(
            Responsive.spacing(context, mobile: 22, tablet: 24, desktop: 26),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black12.withOpacity(0.06),
              blurRadius: 25,
              offset: const Offset(0, 10),
            )
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(
                Responsive.spacing(context, mobile: 12, tablet: 14, desktop: 16),
              ),
              decoration: BoxDecoration(
                color: const Color(0xFFEAF0FF),
                borderRadius: BorderRadius.circular(
                  Responsive.spacing(context, mobile: 16, tablet: 18, desktop: 20),
                ),
              ),
              child: Icon(
                Icons.inventory_2_outlined,
                color: const Color(0xFF1F6AFF),
                size: Responsive.spacing(context, mobile: 28, tablet: 30, desktop: 32),
              ),
            ),
            SizedBox(width: Responsive.spacing(context, mobile: 16, tablet: 18, desktop: 20)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'My EMI Locker',
                    style: TextStyle(
                      fontSize: Responsive.fontSize(context, mobile: 16, tablet: 17, desktop: 18),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: Responsive.spacing(context, mobile: 4, tablet: 5, desktop: 6)),
                  Text(
                    '3 items • Max 12-month tenure',
                    style: TextStyle(
                      color: Colors.black54,
                      fontSize: Responsive.fontSize(context, mobile: 14, tablet: 15, desktop: 16),
                    ),
                  ),
                  SizedBox(height: Responsive.spacing(context, mobile: 4, tablet: 5, desktop: 6)),
                  Text(
                    '₹25,397 / month • First EMI on 05 Jan',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: Responsive.fontSize(context, mobile: 15, tablet: 16, desktop: 17),
                    ),
                  ),
                ],
              ),
            ),

          ],
        ),
      ),
    );
  }

}
