import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/payment_models.dart';

class PdfService {

  /// ================================
  /// GENERATE EMI STATEMENT PDF
  /// ================================
  static Future<Map<String, dynamic>> generateEmiStatement({
    required String emiId,
    required String productName,
    required double installmentAmount,
    required int totalMonths,
    required int paidMonths,
    required String status,
    required List<PaymentModel> payments,
  }) async {

    final pdf = pw.Document();
    pw.MemoryImage? fasstPayLogo;

    // ✅ SAFE FONT (₹ + Hindi + English supported)
    final fontData = await rootBundle.load(
      'assets/font/NotoSans-Regular.ttf',
    );
    final ttf = pw.Font.ttf(fontData);

    // Try loading Fasst Pay logo from multiple known asset paths.
    const logoPaths = [
      'assets/images/fasstpay_logo.png',
      'android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png',
      'android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png',
      'android/app/src/main/res/mipmap-xhdpi/ic_launcher.png',
    ];
    for (final path in logoPaths) {
      try {
        final logoData = await rootBundle.load(path);
        fasstPayLogo = pw.MemoryImage(logoData.buffer.asUint8List());
        break;
      } catch (_) {
        // Keep trying next available path.
      }
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (context) => [

          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Text(
                'EMI STATEMENT',
                style: pw.TextStyle(
                  font: ttf,
                  fontSize: 22,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              if (fasstPayLogo != null)
                pw.Image(fasstPayLogo, width: 90, height: 40, fit: pw.BoxFit.contain)
              else
                pw.Text(
                  'FASST PAY',
                  style: pw.TextStyle(
                    font: ttf,
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
            ],
          ),

          pw.SizedBox(height: 12),

          pw.Text(
            'EMI ID: $emiId',
            style: pw.TextStyle(font: ttf),
          ),

          pw.SizedBox(height: 20),

          _row(ttf, 'Product', productName),
          _row(ttf, 'Monthly EMI', '₹$installmentAmount'),
          _row(ttf, 'Tenure', '$totalMonths months'),
          _row(ttf, 'Paid Months', '$paidMonths'),
          _row(ttf, 'Status', status.toUpperCase()),

          pw.SizedBox(height: 25),

          pw.Text(
            'Payment History',
            style: pw.TextStyle(
              font: ttf,
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
            ),
          ),

          pw.SizedBox(height: 10),

          pw.Table.fromTextArray(
            border: pw.TableBorder.all(),
            headerStyle: pw.TextStyle(
              font: ttf,
              fontWeight: pw.FontWeight.bold,
            ),
            cellStyle: pw.TextStyle(font: ttf),
            headers: ['Month', 'Year', 'Due Date', 'Status'],
            data: payments.map<List<String>>((p) {
              final dueDate = p.dueDate;
              final month = (p.month >= 1 && p.month <= 12) ? p.month : dueDate.month;
              final year = p.year > 0 ? p.year : dueDate.year;
              return [
                _getMonthName(month),
                year.toString(),
                '${dueDate.day}/${dueDate.month}/${dueDate.year}',
                p.status.toUpperCase(),
              ];
            }).toList(),
          ),
        ],
      ),
    );

    // ✅ SAVE TO DOCUMENTS FOLDER
    Directory? documentsDir;
    
    try {
      // Try to get external storage (Downloads/Documents folder)
      documentsDir = await getExternalStorageDirectory();
      if (documentsDir != null) {
        // Navigate to Documents folder
        final documentsPath = '${documentsDir.path.split('/Android')[0]}/Documents';
        documentsDir = Directory(documentsPath);
        
        // Create Documents folder if it doesn't exist
        if (!await documentsDir.exists()) {
          await documentsDir.create(recursive: true);
        }
      }
    } catch (e) {
      // Fallback to application documents directory
      documentsDir = await getApplicationDocumentsDirectory();
    }

    // Create Fasst Pay subfolder in Documents
    final fasstPayDir = Directory('${documentsDir!.path}/Fasst Pay');
    if (!await fasstPayDir.exists()) {
      await fasstPayDir.create(recursive: true);
    }

    // Generate filename with timestamp
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fileName = 'EMI_Statement_${emiId}_$timestamp.pdf';
    final file = File('${fasstPayDir.path}/$fileName');

    await file.writeAsBytes(await pdf.save());
    
    return {
      'file': file,
      'path': file.path,
      'fileName': fileName,
    };
  }

  /// ================================
  /// SHARE PDF (NO printPdf ERROR)
  /// ================================
  static Future<void> sharePdf(File file) async {
    final Uint8List bytes = await file.readAsBytes();

    await Printing.sharePdf(
      bytes: bytes,
      filename: file.path.split('/').last,
    );
  }

  /// ================================
  /// UI HELPER
  /// ================================
  static pw.Widget _row(pw.Font font, String key, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(key, style: pw.TextStyle(font: font)),
          pw.Text(value, style: pw.TextStyle(font: font)),
        ],
      ),
    );
  }

  /// Get month name from number
  static String _getMonthName(int month) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    if (month >= 1 && month <= 12) {
      return months[month - 1];
    }
    return month.toString();
  }
}
