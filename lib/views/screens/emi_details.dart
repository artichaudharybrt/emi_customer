import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../utils/responsive.dart';
import '../../services/emi_service.dart';
import '../../utils/pdf_service.dart';
import '../../models/payment_models.dart';
import 'razorpay_payment_screen.dart';

class BrowseProductsScreen extends StatefulWidget {
  final Map<String, dynamic>? emiDetails;

  const BrowseProductsScreen({super.key, this.emiDetails});

  @override
  State<BrowseProductsScreen> createState() => _BrowseProductsScreenState();
}

class _BrowseProductsScreenState extends State<BrowseProductsScreen> {
  final EmiService _emiService = EmiService();
  bool _isDownloading = false;

  @override
  Widget build(BuildContext context) {
    if (widget.emiDetails != null) {
      return _emiDetailsScreen(context);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Browse Products",
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      body: const Center(child: Text("Your product list UI here")),
    );
  }

  Future<void> _downloadStatement() async {
    if (widget.emiDetails == null) return;

    setState(() {
      _isDownloading = true;
    });

    try {
      final emiId = widget.emiDetails!['emiId'] as String? ??
                   widget.emiDetails!['id'] as String? ?? '';

      if (emiId.isEmpty) {
        throw Exception('EMI ID not found');
      }

      // Fetch payments
      final paymentResponse = await _emiService.getEmiPayments(emiId);

      // Generate PDF
      final pdfResult = await PdfService.generateEmiStatement(
        emiId: emiId,
        productName: widget.emiDetails!['product'] as String? ?? 'EMI Product',
        installmentAmount: (widget.emiDetails!['amount'] as num?)?.toDouble() ?? 0.0,
        totalMonths: widget.emiDetails!['months'] as int? ?? 0,
        paidMonths: widget.emiDetails!['paid'] as int? ?? 0,
        status: widget.emiDetails!['status'] as String? ?? 'active',
        payments: paymentResponse.data,
      );

      final pdfFile = pdfResult['file'] as File;
      final savePath = pdfResult['path'] as String;

      // Share/Print PDF
      await PdfService.sharePdf(pdfFile);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'PDF saved successfully!',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  'Saved to: $savePath',
                  style: const TextStyle(fontSize: 12),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'OK',
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString().replaceAll('Exception: ', '')}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDownloading = false;
        });
      }
    }
  }

  Widget _emiDetailsScreen(BuildContext context) {
    final d = widget.emiDetails!;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(
          d["product"],
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w700,
            fontSize: Responsive.fontSize(context, mobile: 18, tablet: 20, desktop: 22),
          ),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.grey.shade900,
        centerTitle: false,
      ),

      body: ResponsivePage(
        child: SingleChildScrollView(
          padding: Responsive.padding(
            context,
            mobile: const EdgeInsets.all(18),
            tablet: const EdgeInsets.all(24),
            desktop: const EdgeInsets.all(32),
          ),
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // PRODUCT CARD with enhanced styling
            Container(
              padding: Responsive.padding(
                context,
                mobile: const EdgeInsets.all(22),
                tablet: const EdgeInsets.all(30),
                desktop: const EdgeInsets.all(36),
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(
                  Responsive.spacing(context, mobile: 24, tablet: 28, desktop: 32),
                ),
                boxShadow: [
                  BoxShadow(
                    blurRadius: 24,
                    spreadRadius: 0,
                    offset: const Offset(0, 6),
                    color: Colors.black.withOpacity(0.1),
                  ),
                  BoxShadow(
                    blurRadius: 12,
                    spreadRadius: 0,
                    offset: const Offset(0, 3),
                    color: Colors.black.withOpacity(0.06),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    padding: EdgeInsets.all(
                      Responsive.spacing(context, mobile: 18, tablet: 22, desktop: 26),
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.grey.shade50,
                          Colors.grey.shade100,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(
                        Responsive.spacing(context, mobile: 18, tablet: 20, desktop: 22),
                      ),
                      border: Border.all(
                        color: Colors.grey.shade200,
                        width: 1,
                      ),
                    ),
                    child: Center(
                      child: d["image"] != null && d["image"].toString().isNotEmpty
                          ? Image.asset(
                              d["image"],
                              height: Responsive.spacing(context, mobile: 180, tablet: 220, desktop: 260),
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) {
                                return Text(
                                  d["product"],
                                  style: GoogleFonts.poppins(
                                    fontSize: Responsive.fontSize(context, mobile: 20, tablet: 24, desktop: 28),
                                    fontWeight: FontWeight.w700,
                                    color: Colors.grey.shade900,
                                  ),
                                  textAlign: TextAlign.center,
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 2,
                                );
                              },
                            )
                          : Text(
                              d["product"],
                              style: GoogleFonts.poppins(
                                fontSize: Responsive.fontSize(context, mobile: 20, tablet: 24, desktop: 28),
                                fontWeight: FontWeight.w700,
                                color: Colors.grey.shade900,
                              ),
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 2,
                            ),
                    ),
                  ),



                  SizedBox(height: Responsive.spacing(context, mobile: 12, tablet: 14, desktop: 16)),

                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: Responsive.spacing(context, mobile: 20, tablet: 24, desktop: 28),
                      vertical: Responsive.spacing(context, mobile: 12, tablet: 14, desktop: 16),
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: d["status"] == "active"
                            ? [Colors.blue.shade500, Colors.blue.shade700]
                            : [Colors.green.shade500, Colors.green.shade700],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(
                        Responsive.spacing(context, mobile: 14, tablet: 16, desktop: 18),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: (d["status"] == "active" ? Colors.blue : Colors.green).withOpacity(0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: Responsive.spacing(context, mobile: 8, tablet: 10, desktop: 12),
                          height: Responsive.spacing(context, mobile: 8, tablet: 10, desktop: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                        SizedBox(width: Responsive.spacing(context, mobile: 8, tablet: 10, desktop: 12)),
                        Flexible(
                          child: Text(
                            d["status"].toUpperCase(),
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: Responsive.fontSize(context, mobile: 14, tablet: 15, desktop: 16),
                              letterSpacing: 1.5,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: Responsive.spacing(context, mobile: 28, tablet: 32, desktop: 40)),

            // DETAILS Section Header
            Row(
              children: [
                Container(
                  width: Responsive.spacing(context, mobile: 5, tablet: 6, desktop: 7),
                  height: Responsive.spacing(context, mobile: 28, tablet: 32, desktop: 36),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.blue.shade500, Colors.blue.shade700],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    borderRadius: BorderRadius.circular(
                      Responsive.spacing(context, mobile: 3, tablet: 3.5, desktop: 4),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.withOpacity(0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: Responsive.spacing(context, mobile: 14, tablet: 16, desktop: 18)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "EMI Details",
                        style: GoogleFonts.poppins(
                          fontSize: Responsive.fontSize(context, mobile: 24, tablet: 26, desktop: 30),
                          fontWeight: FontWeight.w700,
                          color: Colors.grey.shade900,
                          letterSpacing: 0.5,
                        ),
                      ),
                      SizedBox(height: Responsive.spacing(context, mobile: 2, tablet: 3, desktop: 4)),
                      Container(
                        width: Responsive.spacing(context, mobile: 40, tablet: 50, desktop: 60),
                        height: Responsive.spacing(context, mobile: 3, tablet: 4, desktop: 5),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.blue.shade400, Colors.blue.shade600],
                          ),
                          borderRadius: BorderRadius.circular(
                            Responsive.spacing(context, mobile: 2, tablet: 2.5, desktop: 3),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            SizedBox(height: Responsive.spacing(context, mobile: 16, tablet: 20, desktop: 24)),

            _detailCard(context, "Monthly EMI", "₹${d["amount"]}", Icons.currency_rupee),
            _detailCard(
              context, 
              "Tenure", 
              "${d["months"]} months", 
              Icons.calendar_month,
              onTap: () => _showInstallmentsDialog(context),
            ),
            _detailCard(context, "Paid Months", d["paid"].toString(), Icons.check_circle),
            _detailCard(context, "Due in", "${d["dueDay"]} days", Icons.access_time),
            _detailCard(context, "Status", d["status"].toUpperCase(), Icons.info_outline),

            SizedBox(height: Responsive.spacing(context, mobile: 32, tablet: 40, desktop: 48)),

            // BUTTON with enhanced styling - Fully Responsive
            Container(
              width: double.infinity,
              constraints: BoxConstraints(
                maxWidth: double.infinity,
                minHeight: Responsive.spacing(context, mobile: 56, tablet: 64, desktop: 72),
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(
                  Responsive.spacing(context, mobile: 16, tablet: 18, desktop: 20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.4),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: _isDownloading ? null : _downloadStatement,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade600,
                  disabledBackgroundColor: Colors.grey.shade400,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(
                    horizontal: Responsive.spacing(context, mobile: 16, tablet: 20, desktop: 24),
                    vertical: Responsive.spacing(context, mobile: 16, tablet: 18, desktop: 20),
                  ),
                  minimumSize: Size(
                    double.infinity,
                    Responsive.spacing(context, mobile: 56, tablet: 64, desktop: 72),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      Responsive.spacing(context, mobile: 16, tablet: 18, desktop: 20),
                    ),
                  ),
                  elevation: 0,
                ),
                child: _isDownloading
                    ? SizedBox(
                        height: Responsive.spacing(context, mobile: 24, tablet: 28, desktop: 32),
                        width: Responsive.spacing(context, mobile: 24, tablet: 28, desktop: 32),
                        child: const CircularProgressIndicator(
                          strokeWidth: 3.5,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: EdgeInsets.all(
                                Responsive.spacing(context, mobile: 6, tablet: 8, desktop: 10),
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(
                                  Responsive.spacing(context, mobile: 6, tablet: 8, desktop: 10),
                                ),
                              ),
                              child: Icon(
                                Icons.download_rounded,
                                size: Responsive.spacing(context, mobile: 20, tablet: 22, desktop: 24),
                              ),
                            ),
                            SizedBox(width: Responsive.spacing(context, mobile: 8, tablet: 10, desktop: 12)),
                            Flexible(
                              child: Text(
                                "Download Statement",
                                style: GoogleFonts.poppins(
                                  fontSize: Responsive.fontSize(context, mobile: 16, tablet: 18, desktop: 20),
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5,
                                ),
                                textAlign: TextAlign.center,
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }

  // DETAIL CARD UI with enhanced styling
  Widget _detailCard(BuildContext context, String title, String value, IconData icon, {VoidCallback? onTap}) {
    Widget cardContent = Container(
      margin: EdgeInsets.only(bottom: Responsive.spacing(context, mobile: 16, tablet: 18, desktop: 20)),
      padding: Responsive.padding(
        context,
        mobile: const EdgeInsets.all(20),
        tablet: const EdgeInsets.all(24),
        desktop: const EdgeInsets.all(28),
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(
          Responsive.spacing(context, mobile: 18, tablet: 20, desktop: 22),
        ),
        border: Border.all(
          color: Colors.grey.shade200,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            blurRadius: 12,
            offset: const Offset(0, 4),
            color: Colors.black.withOpacity(0.06),
            spreadRadius: 0,
          ),
          BoxShadow(
            blurRadius: 6,
            offset: const Offset(0, 2),
            color: Colors.black.withOpacity(0.04),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(
              Responsive.spacing(context, mobile: 14, tablet: 16, desktop: 18),
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue.shade500, Colors.blue.shade700],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(
                Responsive.spacing(context, mobile: 14, tablet: 16, desktop: 18),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: Responsive.spacing(context, mobile: 24, tablet: 26, desktop: 30),
            ),
          ),
          SizedBox(width: Responsive.spacing(context, mobile: 16, tablet: 20, desktop: 24)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: Responsive.fontSize(context, mobile: 14, tablet: 15, desktop: 16),
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade600,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                SizedBox(height: Responsive.spacing(context, mobile: 4, tablet: 6, desktop: 8)),
                Text(
                  value,
                  style: GoogleFonts.poppins(
                    fontSize: Responsive.fontSize(context, mobile: 18, tablet: 20, desktop: 22),
                    fontWeight: FontWeight.w700,
                    color: Colors.grey.shade900,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
              ],
            ),
          ),
          if (onTap != null)
            Container(
              padding: EdgeInsets.all(
                Responsive.spacing(context, mobile: 10, tablet: 12, desktop: 14),
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue.shade50, Colors.blue.shade100],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(
                  Responsive.spacing(context, mobile: 10, tablet: 12, desktop: 14),
                ),
                border: Border.all(
                  color: Colors.blue.shade200,
                  width: 1,
                ),
              ),
              child: Icon(
                Icons.arrow_forward_ios,
                size: Responsive.spacing(context, mobile: 18, tablet: 20, desktop: 22),
                color: Colors.blue.shade700,
              ),
            ),
        ],
      ),
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(
            Responsive.spacing(context, mobile: 16, tablet: 18, desktop: 20),
          ),
          child: cardContent,
        ),
      );
    }

    return cardContent;
  }

  Future<void> _showInstallmentsDialog(BuildContext context) async {
    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // Fetch pending payments
      final response = await _emiService.getPendingPayments();

      if (!context.mounted) return;
      Navigator.pop(context); // Close loading dialog

      // Filter installments for current EMI
      final emiId = widget.emiDetails!['emiId'] as String? ?? 
                    widget.emiDetails!['id'] as String? ?? '';
      
      final installments = response.data
          .where((payment) => payment.emiId.id == emiId)
          .toList()
        ..sort((a, b) => a.installmentNumber.compareTo(b.installmentNumber));

      // Show installments dialog
      if (!context.mounted) return;
      showDialog(
        context: context,
        builder: (context) => _InstallmentsDialog(installments: installments),
      );
    } catch (e) {
      if (!context.mounted) return;
      Navigator.pop(context); // Close loading dialog if still open
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading installments: ${e.toString().replaceAll('Exception: ', '')}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

// Installments Dialog Widget
class _InstallmentsDialog extends StatelessWidget {
  final List<PendingPaymentModel> installments;

  const _InstallmentsDialog({required this.installments});

  String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${date.day.toString().padLeft(2, '0')} ${months[date.month - 1]} ${date.year}';
  }

  void _showPaymentOptions(BuildContext context, PendingPaymentModel installment) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _PaymentMethodBottomSheet(installment: installment),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Responsive.spacing(context, mobile: 24, tablet: 28, desktop: 32)),
      ),
      insetPadding: Responsive.padding(
        context,
        mobile: const EdgeInsets.symmetric(horizontal: 16, vertical: 40),
        tablet: const EdgeInsets.symmetric(horizontal: 40, vertical: 60),
        desktop: const EdgeInsets.symmetric(horizontal: 120, vertical: 80),
      ),
      backgroundColor: Colors.transparent,
      child: Container(
        width: Responsive.isDesktop(screenWidth) 
            ? ResponsiveBreakpoints.maxContentWidth * 0.65 
            : null,
        constraints: BoxConstraints(
          maxHeight: screenHeight * 0.9,
          maxWidth: Responsive.isDesktop(screenWidth) 
              ? ResponsiveBreakpoints.maxContentWidth * 0.65 
              : screenWidth * 0.95,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(Responsive.spacing(context, mobile: 24, tablet: 28, desktop: 32)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 24,
              offset: const Offset(0, 8),
              spreadRadius: 0,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with gradient
            Container(
              padding: Responsive.padding(
                context,
                mobile: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                tablet: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                desktop: const EdgeInsets.symmetric(horizontal: 28, vertical: 28),
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue.shade500, Colors.blue.shade700],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(Responsive.spacing(context, mobile: 20, tablet: 24, desktop: 28)),
                  topRight: Radius.circular(Responsive.spacing(context, mobile: 20, tablet: 24, desktop: 28)),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(
                      Responsive.spacing(context, mobile: 10, tablet: 12, desktop: 14),
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(
                        Responsive.spacing(context, mobile: 12, tablet: 14, desktop: 16),
                      ),
                    ),
                    child: Icon(
                      Icons.payment,
                      color: Colors.white,
                      size: Responsive.spacing(context, mobile: 24, tablet: 28, desktop: 32),
                    ),
                  ),
                  SizedBox(width: Responsive.spacing(context, mobile: 14, tablet: 16, desktop: 18)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Installments',
                          style: GoogleFonts.poppins(
                            fontSize: Responsive.fontSize(context, mobile: 22, tablet: 24, desktop: 28),
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                        SizedBox(height: Responsive.spacing(context, mobile: 2, tablet: 3, desktop: 4)),
                        Text(
                          '${installments.length} ${installments.length == 1 ? 'installment' : 'installments'}',
                          style: GoogleFonts.poppins(
                            fontSize: Responsive.fontSize(context, mobile: 13, tablet: 14, desktop: 15),
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withOpacity(0.9),
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ],
                    ),
                  ),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => Navigator.pop(context),
                      borderRadius: BorderRadius.circular(
                        Responsive.spacing(context, mobile: 20, tablet: 24, desktop: 28),
                      ),
                      child: Container(
                        padding: EdgeInsets.all(
                          Responsive.spacing(context, mobile: 8, tablet: 10, desktop: 12),
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.close,
                          color: Colors.white,
                          size: Responsive.spacing(context, mobile: 20, tablet: 22, desktop: 24),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Installments List
            Flexible(
              child: installments.isEmpty
                  ? Padding(
                      padding: Responsive.padding(
                        context,
                        mobile: const EdgeInsets.all(48),
                        tablet: const EdgeInsets.all(60),
                        desktop: const EdgeInsets.all(72),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: EdgeInsets.all(
                              Responsive.spacing(context, mobile: 24, tablet: 28, desktop: 32),
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.inbox_outlined,
                              size: Responsive.spacing(context, mobile: 64, tablet: 80, desktop: 96),
                              color: Colors.grey.shade400,
                            ),
                          ),
                          SizedBox(height: Responsive.spacing(context, mobile: 20, tablet: 24, desktop: 28)),
                          Text(
                            'No installments found',
                            style: GoogleFonts.poppins(
                              fontSize: Responsive.fontSize(context, mobile: 18, tablet: 20, desktop: 22),
                              color: Colors.grey.shade700,
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: Responsive.spacing(context, mobile: 8, tablet: 10, desktop: 12)),
                          Text(
                            'All installments have been paid',
                            style: GoogleFonts.poppins(
                              fontSize: Responsive.fontSize(context, mobile: 14, tablet: 15, desktop: 16),
                              color: Colors.grey.shade500,
                              fontWeight: FontWeight.w400,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      physics: const BouncingScrollPhysics(),
                      padding: Responsive.padding(
                        context,
                        mobile: const EdgeInsets.all(16),
                        tablet: const EdgeInsets.all(20),
                        desktop: const EdgeInsets.all(24),
                      ),
                      itemCount: installments.length,
                      itemBuilder: (context, index) {
                        final installment = installments[index];
                        final isPending = installment.status.toLowerCase() == 'pending';
                        
                        return Container(
                          margin: EdgeInsets.only(
                            bottom: Responsive.spacing(context, mobile: 16, tablet: 18, desktop: 20),
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(
                              color: isPending 
                                  ? Colors.orange.shade300 
                                  : Colors.green.shade300,
                              width: 1.5,
                            ),
                            borderRadius: BorderRadius.circular(
                              Responsive.spacing(context, mobile: 18, tablet: 20, desktop: 22),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: (isPending ? Colors.orange : Colors.green).withOpacity(0.15),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                                spreadRadius: 0,
                              ),
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                                spreadRadius: 0,
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: Responsive.padding(
                                  context,
                                  mobile: const EdgeInsets.all(16),
                                  tablet: const EdgeInsets.all(20),
                                  desktop: const EdgeInsets.all(24),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: Wrap(
                                            spacing: Responsive.spacing(context, mobile: 8, tablet: 10, desktop: 12),
                                            runSpacing: Responsive.spacing(context, mobile: 8, tablet: 10, desktop: 12),
                                            children: [
                                              Container(
                                                padding: EdgeInsets.symmetric(
                                                  horizontal: Responsive.spacing(context, mobile: 12, tablet: 14, desktop: 16),
                                                  vertical: Responsive.spacing(context, mobile: 8, tablet: 10, desktop: 12),
                                                ),
                                                decoration: BoxDecoration(
                                                  gradient: LinearGradient(
                                                    colors: isPending 
                                                        ? [Colors.orange.shade400, Colors.orange.shade600]
                                                        : [Colors.green.shade400, Colors.green.shade600],
                                                    begin: Alignment.topLeft,
                                                    end: Alignment.bottomRight,
                                                  ),
                                                  borderRadius: BorderRadius.circular(
                                                    Responsive.spacing(context, mobile: 10, tablet: 12, desktop: 14),
                                                  ),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: (isPending ? Colors.orange : Colors.green).withOpacity(0.3),
                                                      blurRadius: 4,
                                                      offset: const Offset(0, 2),
                                                    ),
                                                  ],
                                                ),
                                                child: Text(
                                                  'Installment ${installment.installmentNumber}',
                                                  style: GoogleFonts.poppins(
                                                    fontSize: Responsive.fontSize(context, mobile: 13, tablet: 14, desktop: 15),
                                                    fontWeight: FontWeight.w700,
                                                    color: Colors.white,
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              Container(
                                                padding: EdgeInsets.symmetric(
                                                  horizontal: Responsive.spacing(context, mobile: 10, tablet: 12, desktop: 14),
                                                  vertical: Responsive.spacing(context, mobile: 6, tablet: 8, desktop: 10),
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Colors.grey.shade100,
                                                  borderRadius: BorderRadius.circular(
                                                    Responsive.spacing(context, mobile: 8, tablet: 10, desktop: 12),
                                                  ),
                                                  border: Border.all(
                                                    color: Colors.grey.shade300,
                                                    width: 1,
                                                  ),
                                                ),
                                                child: Text(
                                                  installment.status.toUpperCase(),
                                                  style: GoogleFonts.poppins(
                                                    fontSize: Responsive.fontSize(context, mobile: 10, tablet: 11, desktop: 12),
                                                    fontWeight: FontWeight.w600,
                                                    color: Colors.grey.shade700,
                                                    letterSpacing: 0.5,
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                  maxLines: 1,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        SizedBox(width: Responsive.spacing(context, mobile: 8, tablet: 10, desktop: 12)),
                                        Container(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: Responsive.spacing(context, mobile: 10, tablet: 12, desktop: 14),
                                            vertical: Responsive.spacing(context, mobile: 8, tablet: 10, desktop: 12),
                                          ),
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [Colors.blue.shade400, Colors.blue.shade600],
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              Responsive.spacing(context, mobile: 10, tablet: 12, desktop: 14),
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.blue.withOpacity(0.3),
                                                blurRadius: 4,
                                                offset: const Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                          child: Text(
                                            '₹${installment.amount.toStringAsFixed(0)}',
                                            style: GoogleFonts.poppins(
                                              fontSize: Responsive.fontSize(context, mobile: 18, tablet: 20, desktop: 22),
                                              fontWeight: FontWeight.w800,
                                              color: Colors.white,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: Responsive.spacing(context, mobile: 16, tablet: 18, desktop: 20)),
                                    Container(
                                      padding: EdgeInsets.all(
                                        Responsive.spacing(context, mobile: 14, tablet: 16, desktop: 18),
                                      ),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            Colors.blue.shade50,
                                            Colors.blue.shade50.withOpacity(0.7),
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                        borderRadius: BorderRadius.circular(
                                          Responsive.spacing(context, mobile: 12, tablet: 14, desktop: 16),
                                        ),
                                        border: Border.all(
                                          color: Colors.blue.shade100,
                                          width: 1,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            padding: EdgeInsets.all(
                                              Responsive.spacing(context, mobile: 8, tablet: 10, desktop: 12),
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.blue.shade100,
                                              borderRadius: BorderRadius.circular(
                                                Responsive.spacing(context, mobile: 8, tablet: 10, desktop: 12),
                                              ),
                                            ),
                                            child: Icon(
                                              Icons.calendar_today,
                                              size: Responsive.spacing(context, mobile: 18, tablet: 20, desktop: 22),
                                              color: Colors.blue.shade700,
                                            ),
                                          ),
                                          SizedBox(width: Responsive.spacing(context, mobile: 12, tablet: 14, desktop: 16)),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'Due Date',
                                                  style: GoogleFonts.poppins(
                                                    fontSize: Responsive.fontSize(context, mobile: 11, tablet: 12, desktop: 13),
                                                    color: Colors.grey.shade600,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                                SizedBox(height: Responsive.spacing(context, mobile: 2, tablet: 3, desktop: 4)),
                                                Text(
                                                  _formatDate(installment.dueDate),
                                                  style: GoogleFonts.poppins(
                                                    fontSize: Responsive.fontSize(context, mobile: 15, tablet: 16, desktop: 17),
                                                    color: Colors.grey.shade900,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Pay Now Button for pending installments
                              if (isPending)
                                Container(
                                  width: double.infinity,
                                  margin: EdgeInsets.only(
                                    left: Responsive.spacing(context, mobile: 16, tablet: 20, desktop: 24),
                                    right: Responsive.spacing(context, mobile: 16, tablet: 20, desktop: 24),
                                    bottom: Responsive.spacing(context, mobile: 16, tablet: 20, desktop: 24),
                                  ),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(
                                      Responsive.spacing(context, mobile: 14, tablet: 16, desktop: 18),
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.blue.withOpacity(0.4),
                                        blurRadius: 12,
                                        offset: const Offset(0, 6),
                                        spreadRadius: 0,
                                      ),
                                    ],
                                  ),
                                  child: ElevatedButton(
                                    onPressed: () => _showPaymentOptions(context, installment),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue.shade600,
                                      foregroundColor: Colors.white,
                                      padding: EdgeInsets.symmetric(
                                        horizontal: Responsive.spacing(context, mobile: 16, tablet: 20, desktop: 24),
                                        vertical: Responsive.spacing(context, mobile: 16, tablet: 18, desktop: 20),
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(
                                          Responsive.spacing(context, mobile: 14, tablet: 16, desktop: 18),
                                        ),
                                      ),
                                      elevation: 0,
                                    ),
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            padding: EdgeInsets.all(
                                              Responsive.spacing(context, mobile: 6, tablet: 8, desktop: 10),
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.white.withOpacity(0.2),
                                              borderRadius: BorderRadius.circular(
                                                Responsive.spacing(context, mobile: 6, tablet: 8, desktop: 10),
                                              ),
                                            ),
                                            child: Icon(
                                              Icons.payment,
                                              size: Responsive.spacing(context, mobile: 18, tablet: 20, desktop: 22),
                                            ),
                                          ),
                                          SizedBox(width: Responsive.spacing(context, mobile: 8, tablet: 10, desktop: 12)),
                                          Flexible(
                                            child: Text(
                                              'Pay Now',
                                              style: GoogleFonts.poppins(
                                                fontSize: Responsive.fontSize(context, mobile: 16, tablet: 18, desktop: 20),
                                                fontWeight: FontWeight.w700,
                                                letterSpacing: 0.5,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                              maxLines: 1,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// Payment Method Selection Bottom Sheet
class _PaymentMethodBottomSheet extends StatelessWidget {
  final PendingPaymentModel installment;

  const _PaymentMethodBottomSheet({required this.installment});

  void _handlePaymentMethod(BuildContext context, String method) {
    Navigator.pop(context); // Close bottom sheet
    
    switch (method) {
      case 'Online':
        // Show Razorpay payment screen
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => RazorpayPaymentScreen(installment: installment),
        );
        break;
      case 'QR Code':
        // Show QR code screen
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => _QrCodePaymentScreen(installment: installment),
        );
        break;
      case 'Bank':
        // Show bank transfer form
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => _BankTransferScreen(installment: installment),
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    
    return Container(
      constraints: BoxConstraints(
        maxWidth: Responsive.isDesktop(screenWidth) 
            ? ResponsiveBreakpoints.maxContentWidth * 0.5 
            : double.infinity,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(Responsive.spacing(context, mobile: 24, tablet: 28, desktop: 32)),
          topRight: Radius.circular(Responsive.spacing(context, mobile: 24, tablet: 28, desktop: 32)),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: EdgeInsets.only(
              top: Responsive.spacing(context, mobile: 12, tablet: 14, desktop: 16),
            ),
            width: Responsive.spacing(context, mobile: 40, tablet: 48, desktop: 56),
            height: Responsive.spacing(context, mobile: 4, tablet: 5, desktop: 6),
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(Responsive.spacing(context, mobile: 2, tablet: 2.5, desktop: 3)),
            ),
          ),
          
          // Header
          Padding(
            padding: Responsive.padding(
              context,
              mobile: const EdgeInsets.fromLTRB(24, 20, 24, 16),
              tablet: const EdgeInsets.fromLTRB(28, 24, 28, 20),
              desktop: const EdgeInsets.fromLTRB(32, 28, 32, 24),
            ),
            child: Column(
              children: [
                Text(
                  'Select Payment Method',
                  style: GoogleFonts.poppins(
                    fontSize: Responsive.fontSize(context, mobile: 22, tablet: 24, desktop: 28),
                    fontWeight: FontWeight.w700,
                    color: Colors.grey.shade900,
                  ),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                SizedBox(height: Responsive.spacing(context, mobile: 8, tablet: 10, desktop: 12)),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: Responsive.spacing(context, mobile: 16, tablet: 20, desktop: 24),
                    vertical: Responsive.spacing(context, mobile: 10, tablet: 12, desktop: 14),
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(
                      Responsive.spacing(context, mobile: 12, tablet: 14, desktop: 16),
                    ),
                  ),
                  child: Text(
                    'Amount: ₹${installment.amount.toStringAsFixed(0)}',
                    style: GoogleFonts.poppins(
                      fontSize: Responsive.fontSize(context, mobile: 18, tablet: 20, desktop: 22),
                      fontWeight: FontWeight.w700,
                      color: Colors.blue.shade700,
                    ),
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ],
            ),
          ),
          
          // Payment Options
          Padding(
            padding: Responsive.padding(
              context,
              mobile: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              tablet: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              desktop: const EdgeInsets.fromLTRB(28, 0, 28, 28),
            ),
            child: Column(
              children: [
                _PaymentOptionCard(
                  title: 'Online Payment',
                  subtitle: 'Pay via UPI, Cards, Net Banking',
                  icon: Icons.payment,
                  color: Colors.blue,
                  onTap: () => _handlePaymentMethod(context, 'Online'),
                ),
                SizedBox(height: Responsive.spacing(context, mobile: 14, tablet: 16, desktop: 18)),
                _PaymentOptionCard(
                  title: 'QR Code',
                  subtitle: 'Scan QR code to pay',
                  icon: Icons.qr_code_scanner,
                  color: Colors.green,
                  onTap: () => _handlePaymentMethod(context, 'QR Code'),
                ),
                SizedBox(height: Responsive.spacing(context, mobile: 14, tablet: 16, desktop: 18)),
                _PaymentOptionCard(
                  title: 'Bank Transfer',
                  subtitle: 'Direct bank transfer details',
                  icon: Icons.account_balance,
                  color: Colors.orange,
                  onTap: () => _handlePaymentMethod(context, 'Bank'),
                ),
              ],
            ),
          ),
          
          // Bottom safe area
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }
}

// Payment Option Card Widget
class _PaymentOptionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _PaymentOptionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(
          Responsive.spacing(context, mobile: 16, tablet: 18, desktop: 20),
        ),
        child: Container(
          padding: Responsive.padding(
            context,
            mobile: const EdgeInsets.all(20),
            tablet: const EdgeInsets.all(24),
            desktop: const EdgeInsets.all(28),
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(
              color: color.withOpacity(0.3),
              width: 2,
            ),
            borderRadius: BorderRadius.circular(
              Responsive.spacing(context, mobile: 16, tablet: 18, desktop: 20),
            ),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 4),
                spreadRadius: 0,
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(
                  Responsive.spacing(context, mobile: 12, tablet: 14, desktop: 16),
                ),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(
                    Responsive.spacing(context, mobile: 12, tablet: 14, desktop: 16),
                  ),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: Responsive.spacing(context, mobile: 28, tablet: 32, desktop: 36),
                ),
              ),
              SizedBox(width: Responsive.spacing(context, mobile: 16, tablet: 20, desktop: 24)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.poppins(
                        fontSize: Responsive.fontSize(context, mobile: 18, tablet: 20, desktop: 22),
                        fontWeight: FontWeight.w700,
                        color: Colors.grey.shade900,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    SizedBox(height: Responsive.spacing(context, mobile: 4, tablet: 6, desktop: 8)),
                    Text(
                      subtitle,
                      style: GoogleFonts.poppins(
                        fontSize: Responsive.fontSize(context, mobile: 14, tablet: 15, desktop: 16),
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w400,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: color,
                size: Responsive.spacing(context, mobile: 20, tablet: 22, desktop: 24),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// QR Code Payment Screen
class _QrCodePaymentScreen extends StatefulWidget {
  final PendingPaymentModel installment;

  const _QrCodePaymentScreen({required this.installment});

  @override
  State<_QrCodePaymentScreen> createState() => _QrCodePaymentScreenState();
}

class _QrCodePaymentScreenState extends State<_QrCodePaymentScreen> {
  final EmiService _emiService = EmiService();
  final TextEditingController _transactionIdController = TextEditingController();
  bool _isLoading = false;
  bool _isVerifying = false;
  QrCodeData? _qrCodeData;

  @override
  void initState() {
    super.initState();
    _loadQrCode();
  }

  Future<void> _loadQrCode() async {
    setState(() => _isLoading = true);
    try {
      final response = await _emiService.getQrCode(widget.installment.id);
      if (mounted) {
        setState(() {
          _qrCodeData = response.data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString().replaceAll('Exception: ', '')}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _verifyPayment() async {
    if (_transactionIdController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter transaction ID'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isVerifying = true);
    try {
      final response = await _emiService.verifyQrPayment(
        emiPaymentId: widget.installment.id,
        transactionId: _transactionIdController.text.trim(),
      );

      if (mounted) {
        setState(() => _isVerifying = false);
        if (response.success) {
          Navigator.pop(context); // Close QR code screen
          Navigator.pop(context); // Close payment method selection
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response.message),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response.message),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isVerifying = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString().replaceAll('Exception: ', '')}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _transactionIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
        maxWidth: Responsive.isDesktop(screenWidth) 
            ? ResponsiveBreakpoints.maxContentWidth * 0.6 
            : double.infinity,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(Responsive.spacing(context, mobile: 24, tablet: 28, desktop: 32)),
          topRight: Radius.circular(Responsive.spacing(context, mobile: 24, tablet: 28, desktop: 32)),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: EdgeInsets.only(
              top: Responsive.spacing(context, mobile: 12, tablet: 14, desktop: 16),
            ),
            width: Responsive.spacing(context, mobile: 40, tablet: 48, desktop: 56),
            height: Responsive.spacing(context, mobile: 4, tablet: 5, desktop: 6),
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(Responsive.spacing(context, mobile: 2, tablet: 2.5, desktop: 3)),
            ),
          ),
          
          // Header
          Padding(
            padding: Responsive.padding(
              context,
              mobile: const EdgeInsets.fromLTRB(24, 20, 24, 16),
              tablet: const EdgeInsets.fromLTRB(28, 24, 28, 20),
              desktop: const EdgeInsets.fromLTRB(32, 28, 32, 24),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.qr_code_scanner,
                  color: Colors.green.shade600,
                  size: Responsive.spacing(context, mobile: 28, tablet: 32, desktop: 36),
                ),
                SizedBox(width: Responsive.spacing(context, mobile: 12, tablet: 14, desktop: 16)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'QR Code Payment',
                        style: GoogleFonts.poppins(
                          fontSize: Responsive.fontSize(context, mobile: 22, tablet: 24, desktop: 28),
                          fontWeight: FontWeight.w700,
                          color: Colors.grey.shade900,
                        ),
                      ),
                      SizedBox(height: Responsive.spacing(context, mobile: 4, tablet: 6, desktop: 8)),
                      Text(
                        'Amount: ₹${widget.installment.amount.toStringAsFixed(0)}',
                        style: GoogleFonts.poppins(
                          fontSize: Responsive.fontSize(context, mobile: 16, tablet: 18, desktop: 20),
                          fontWeight: FontWeight.w600,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          
          // Content
          Flexible(
            child: SingleChildScrollView(
              padding: Responsive.padding(
                context,
                mobile: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                tablet: const EdgeInsets.fromLTRB(28, 0, 28, 28),
                desktop: const EdgeInsets.fromLTRB(32, 0, 32, 32),
              ),
              child: Column(
                children: [
                  if (_isLoading)
                    Padding(
                      padding: EdgeInsets.all(Responsive.spacing(context, mobile: 40, tablet: 60, desktop: 80)),
                      child: const CircularProgressIndicator(),
                    )
                  else if (_qrCodeData != null) ...[
                    // UPI ID
                    Container(
                      padding: EdgeInsets.all(Responsive.spacing(context, mobile: 16, tablet: 20, desktop: 24)),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(Responsive.spacing(context, mobile: 12, tablet: 14, desktop: 16)),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.account_circle, color: Colors.green.shade700),
                          SizedBox(width: Responsive.spacing(context, mobile: 12, tablet: 14, desktop: 16)),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'UPI ID',
                                  style: GoogleFonts.poppins(
                                    fontSize: Responsive.fontSize(context, mobile: 12, tablet: 13, desktop: 14),
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                SizedBox(height: Responsive.spacing(context, mobile: 4, tablet: 6, desktop: 8)),
                                Text(
                                  _qrCodeData!.upiId,
                                  style: GoogleFonts.poppins(
                                    fontSize: Responsive.fontSize(context, mobile: 16, tablet: 18, desktop: 20),
                                    fontWeight: FontWeight.w700,
                                    color: Colors.grey.shade900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    SizedBox(height: Responsive.spacing(context, mobile: 24, tablet: 28, desktop: 32)),
                    
                    // QR Code Image
                    Container(
                      padding: EdgeInsets.all(Responsive.spacing(context, mobile: 20, tablet: 24, desktop: 28)),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(Responsive.spacing(context, mobile: 16, tablet: 18, desktop: 20)),
                        border: Border.all(color: Colors.grey.shade300, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: _qrCodeData!.qrCodeImage.isNotEmpty
                          ? Image.memory(
                              base64Decode(_qrCodeData!.qrCodeImage.split(',').last),
                              width: Responsive.spacing(context, mobile: 250, tablet: 300, desktop: 350),
                              height: Responsive.spacing(context, mobile: 250, tablet: 300, desktop: 350),
                              fit: BoxFit.contain,
                            )
                          : const Icon(Icons.error, size: 100, color: Colors.red),
                    ),
                    
                    SizedBox(height: Responsive.spacing(context, mobile: 24, tablet: 28, desktop: 32)),
                    
                    // Transaction ID Input
                    TextField(
                      controller: _transactionIdController,
                      decoration: InputDecoration(
                        labelText: 'Transaction ID',
                        hintText: 'Enter UPI transaction ID',
                        prefixIcon: const Icon(Icons.receipt),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(Responsive.spacing(context, mobile: 12, tablet: 14, desktop: 16)),
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                      ),
                      style: GoogleFonts.poppins(),
                    ),
                    
                    SizedBox(height: Responsive.spacing(context, mobile: 24, tablet: 28, desktop: 32)),
                    
                    // Verify Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isVerifying ? null : _verifyPayment,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade600,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(
                            vertical: Responsive.spacing(context, mobile: 16, tablet: 18, desktop: 20),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(Responsive.spacing(context, mobile: 12, tablet: 14, desktop: 16)),
                          ),
                          elevation: 4,
                        ),
                        child: _isVerifying
                            ? SizedBox(
                                height: Responsive.spacing(context, mobile: 24, tablet: 28, desktop: 32),
                                width: Responsive.spacing(context, mobile: 24, tablet: 28, desktop: 32),
                                child: const CircularProgressIndicator(
                                  strokeWidth: 3,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.verified),
                                  SizedBox(width: Responsive.spacing(context, mobile: 8, tablet: 10, desktop: 12)),
                                  Text(
                                    'Verify Payment',
                                    style: GoogleFonts.poppins(
                                      fontSize: Responsive.fontSize(context, mobile: 16, tablet: 18, desktop: 20),
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }
}

// Bank Transfer Screen
class _BankTransferScreen extends StatefulWidget {
  final PendingPaymentModel installment;

  const _BankTransferScreen({required this.installment});

  @override
  State<_BankTransferScreen> createState() => _BankTransferScreenState();
}

class _BankTransferScreenState extends State<_BankTransferScreen> {
  final EmiService _emiService = EmiService();
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _transactionIdController = TextEditingController();
  final TextEditingController _bankNameController = TextEditingController();
  final TextEditingController _accountNumberController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  DateTime? _paymentDate;
  String? _screenshotBase64;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _paymentDate = DateTime.now();
    _amountController.text = widget.installment.amount.toStringAsFixed(2);
  }

  Future<void> _pickScreenshot() async {
    // TODO: Implement image picker
    // For now, show a message
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Image picker will be implemented'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _paymentDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _paymentDate = picked);
    }
  }

  Future<void> _submitPayment() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    try {
      final response = await _emiService.verifyBankPayment(
        emiPaymentId: widget.installment.id,
        transactionId: _transactionIdController.text.trim(),
        paymentDate: _paymentDate!.toIso8601String().split('T')[0],
        amount: double.parse(_amountController.text),
        bankName: _bankNameController.text.trim(),
        accountNumber: _accountNumberController.text.trim(),
        screenshot: _screenshotBase64,
      );

      if (mounted) {
        setState(() => _isSubmitting = false);
        if (response.success) {
          Navigator.pop(context); // Close bank transfer screen
          Navigator.pop(context); // Close payment method selection
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response.message),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response.message),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString().replaceAll('Exception: ', '')}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _transactionIdController.dispose();
    _bankNameController.dispose();
    _accountNumberController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
        maxWidth: Responsive.isDesktop(screenWidth) 
            ? ResponsiveBreakpoints.maxContentWidth * 0.6 
            : double.infinity,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(Responsive.spacing(context, mobile: 24, tablet: 28, desktop: 32)),
          topRight: Radius.circular(Responsive.spacing(context, mobile: 24, tablet: 28, desktop: 32)),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: EdgeInsets.only(
              top: Responsive.spacing(context, mobile: 12, tablet: 14, desktop: 16),
            ),
            width: Responsive.spacing(context, mobile: 40, tablet: 48, desktop: 56),
            height: Responsive.spacing(context, mobile: 4, tablet: 5, desktop: 6),
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(Responsive.spacing(context, mobile: 2, tablet: 2.5, desktop: 3)),
            ),
          ),
          
          // Header
          Padding(
            padding: Responsive.padding(
              context,
              mobile: const EdgeInsets.fromLTRB(24, 20, 24, 16),
              tablet: const EdgeInsets.fromLTRB(28, 24, 28, 20),
              desktop: const EdgeInsets.fromLTRB(32, 28, 32, 24),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.account_balance,
                  color: Colors.orange.shade600,
                  size: Responsive.spacing(context, mobile: 28, tablet: 32, desktop: 36),
                ),
                SizedBox(width: Responsive.spacing(context, mobile: 12, tablet: 14, desktop: 16)),
                Expanded(
                  child: Text(
                    'Bank Transfer Payment',
                    style: GoogleFonts.poppins(
                      fontSize: Responsive.fontSize(context, mobile: 22, tablet: 24, desktop: 28),
                      fontWeight: FontWeight.w700,
                      color: Colors.grey.shade900,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          
          // Form
          Flexible(
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: Responsive.padding(
                  context,
                  mobile: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  tablet: const EdgeInsets.fromLTRB(28, 0, 28, 28),
                  desktop: const EdgeInsets.fromLTRB(32, 0, 32, 32),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Transaction ID
                    TextFormField(
                      controller: _transactionIdController,
                      decoration: InputDecoration(
                        labelText: 'Transaction ID *',
                        hintText: 'Enter transaction ID',
                        prefixIcon: const Icon(Icons.receipt),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(Responsive.spacing(context, mobile: 12, tablet: 14, desktop: 16)),
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                      ),
                      validator: (value) => value?.isEmpty ?? true ? 'Please enter transaction ID' : null,
                    ),
                    
                    SizedBox(height: Responsive.spacing(context, mobile: 16, tablet: 20, desktop: 24)),
                    
                    // Payment Date
                    InkWell(
                      onTap: _selectDate,
                      child: Container(
                        padding: EdgeInsets.all(Responsive.spacing(context, mobile: 16, tablet: 18, desktop: 20)),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(Responsive.spacing(context, mobile: 12, tablet: 14, desktop: 16)),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.calendar_today, color: Colors.grey.shade600),
                            SizedBox(width: Responsive.spacing(context, mobile: 12, tablet: 14, desktop: 16)),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Payment Date *',
                                    style: GoogleFonts.poppins(
                                      fontSize: Responsive.fontSize(context, mobile: 12, tablet: 13, desktop: 14),
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                  SizedBox(height: Responsive.spacing(context, mobile: 4, tablet: 6, desktop: 8)),
                                  Text(
                                    _paymentDate != null
                                        ? '${_paymentDate!.day}/${_paymentDate!.month}/${_paymentDate!.year}'
                                        : 'Select date',
                                    style: GoogleFonts.poppins(
                                      fontSize: Responsive.fontSize(context, mobile: 16, tablet: 18, desktop: 20),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    SizedBox(height: Responsive.spacing(context, mobile: 16, tablet: 20, desktop: 24)),
                    
                    // Amount
                    TextFormField(
                      controller: _amountController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Amount *',
                        hintText: 'Enter amount',
                        prefixIcon: const Icon(Icons.currency_rupee),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(Responsive.spacing(context, mobile: 12, tablet: 14, desktop: 16)),
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                      ),
                      validator: (value) {
                        if (value?.isEmpty ?? true) return 'Please enter amount';
                        if (double.tryParse(value!) == null) return 'Please enter valid amount';
                        return null;
                      },
                    ),
                    
                    SizedBox(height: Responsive.spacing(context, mobile: 16, tablet: 20, desktop: 24)),
                    
                    // Bank Name
                    TextFormField(
                      controller: _bankNameController,
                      decoration: InputDecoration(
                        labelText: 'Bank Name *',
                        hintText: 'Enter bank name',
                        prefixIcon: const Icon(Icons.account_balance),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(Responsive.spacing(context, mobile: 12, tablet: 14, desktop: 16)),
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                      ),
                      validator: (value) => value?.isEmpty ?? true ? 'Please enter bank name' : null,
                    ),
                    
                    SizedBox(height: Responsive.spacing(context, mobile: 16, tablet: 20, desktop: 24)),
                    
                    // Account Number
                    TextFormField(
                      controller: _accountNumberController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Account Number *',
                        hintText: 'Enter account number',
                        prefixIcon: const Icon(Icons.account_circle),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(Responsive.spacing(context, mobile: 12, tablet: 14, desktop: 16)),
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                      ),
                      validator: (value) => value?.isEmpty ?? true ? 'Please enter account number' : null,
                    ),
                    
                    SizedBox(height: Responsive.spacing(context, mobile: 16, tablet: 20, desktop: 24)),
                    
                    // Screenshot
                    InkWell(
                      onTap: _pickScreenshot,
                      child: Container(
                        padding: EdgeInsets.all(Responsive.spacing(context, mobile: 16, tablet: 18, desktop: 20)),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(Responsive.spacing(context, mobile: 12, tablet: 14, desktop: 16)),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.image, color: Colors.grey.shade600),
                            SizedBox(width: Responsive.spacing(context, mobile: 12, tablet: 14, desktop: 16)),
                            Expanded(
                              child: Text(
                                _screenshotBase64 != null ? 'Screenshot selected' : 'Upload Screenshot (Optional)',
                                style: GoogleFonts.poppins(
                                  fontSize: Responsive.fontSize(context, mobile: 16, tablet: 18, desktop: 20),
                                  color: _screenshotBase64 != null ? Colors.green.shade700 : Colors.grey.shade600,
                                ),
                              ),
                            ),
                            if (_screenshotBase64 != null)
                              Icon(Icons.check_circle, color: Colors.green.shade700),
                          ],
                        ),
                      ),
                    ),
                    
                    SizedBox(height: Responsive.spacing(context, mobile: 24, tablet: 28, desktop: 32)),
                    
                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _submitPayment,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange.shade600,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(
                            vertical: Responsive.spacing(context, mobile: 16, tablet: 18, desktop: 20),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(Responsive.spacing(context, mobile: 12, tablet: 14, desktop: 16)),
                          ),
                          elevation: 4,
                        ),
                        child: _isSubmitting
                            ? SizedBox(
                                height: Responsive.spacing(context, mobile: 24, tablet: 28, desktop: 32),
                                width: Responsive.spacing(context, mobile: 24, tablet: 28, desktop: 32),
                                child: const CircularProgressIndicator(
                                  strokeWidth: 3,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.send),
                                  SizedBox(width: Responsive.spacing(context, mobile: 8, tablet: 10, desktop: 12)),
                                  Text(
                                    'Submit Payment',
                                    style: GoogleFonts.poppins(
                                      fontSize: Responsive.fontSize(context, mobile: 16, tablet: 18, desktop: 20),
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }
}

