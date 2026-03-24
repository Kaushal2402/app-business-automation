import 'dart:io';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:business_automation/features/invoicing/data/models/invoice_model.dart';
import 'package:business_automation/features/dashboard/data/models/settings_model.dart';

class PdfInvoiceService {
  static Future<Uint8List> generate(Invoice invoice, SettingsModel settings) async {
    final pdf = pw.Document();

    final primaryColor = PdfColor.fromHex('#4F46E5');
    final secondaryColor = PdfColor.fromHex('#1E1B4B');
    final neutralColor = PdfColor.fromHex('#64748B');
    
    // Load a font that supports currency symbols, e.g. Roboto
    final font = await PdfGoogleFonts.robotoRegular();
    final fontBold = await PdfGoogleFonts.robotoBold();

    final symbol = settings.currencySymbol;

    pw.ImageProvider? logoProvider;
    if (settings.businessLogoPath.isNotEmpty && File(settings.businessLogoPath).existsSync()) {
      final imageBytes = await File(settings.businessLogoPath).readAsBytes();
      logoProvider = pw.MemoryImage(imageBytes);
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(
          base: font,
          bold: fontBold,
        ),
        build: (context) {
          return [
            // Header
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    if (logoProvider != null)
                      pw.Container(
                        width: 60,
                        height: 60,
                        child: pw.Image(logoProvider),
                        margin: const pw.EdgeInsets.only(bottom: 10),
                      ),
                    pw.Text(settings.businessName, style: pw.TextStyle(color: secondaryColor, fontWeight: pw.FontWeight.bold, fontSize: 18)),
                    if (settings.businessAddress.isNotEmpty)
                      pw.Text(settings.businessAddress, style: pw.TextStyle(color: neutralColor, fontSize: 10)),
                    if (settings.businessPhone.isNotEmpty)
                      pw.Text(settings.businessPhone, style: pw.TextStyle(color: neutralColor, fontSize: 10)),
                    if (settings.businessEmail.isNotEmpty)
                      pw.Text(settings.businessEmail, style: pw.TextStyle(color: neutralColor, fontSize: 10)),
                    if (settings.businessTaxNumber.isNotEmpty)
                      pw.Text('Tax No: ${settings.businessTaxNumber}', style: pw.TextStyle(color: neutralColor, fontSize: 10)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('INVOICE', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: primaryColor)),
                    pw.SizedBox(height: 10),
                    pw.Text('#${invoice.invoiceNumber}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
                    pw.SizedBox(height: 5),
                    pw.Text('Date: ${DateFormat('dd MMM yyyy').format(invoice.date)}', style: pw.TextStyle(color: neutralColor, fontSize: 10)),
                    pw.Text('Due Date: ${DateFormat('dd MMM yyyy').format(invoice.dueDate)}', style: pw.TextStyle(color: neutralColor, fontSize: 10)),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 30),

            // Bill To
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Billed To:', style: pw.TextStyle(color: neutralColor, fontSize: 10)),
                      pw.SizedBox(height: 5),
                      pw.Text(invoice.customerName, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
                      if (invoice.customerAddress != null && invoice.customerAddress!.isNotEmpty)
                        pw.Text(invoice.customerAddress!, style: pw.TextStyle(fontSize: 10, color: neutralColor)),
                      if (invoice.customerPhone != null && invoice.customerPhone!.isNotEmpty)
                        pw.Text(invoice.customerPhone!, style: pw.TextStyle(fontSize: 10, color: neutralColor)),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 30),

            // Item Table
            _buildItemTable(invoice, symbol, primaryColor),
            pw.SizedBox(height: 20),

            // Summary
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.end,
              children: [
                pw.Expanded(
                  flex: 5,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      if (invoice.notes != null && invoice.notes!.isNotEmpty) ...[
                        pw.Text('Notes:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                        pw.SizedBox(height: 2),
                        pw.Text(invoice.notes!, style: pw.TextStyle(fontSize: 10, color: neutralColor)),
                      ]
                    ],
                  ),
                ),
                pw.Expanded(
                  flex: 3,
                  child: pw.Column(
                    children: [
                      _buildSummaryRow('Subtotal', '$symbol${invoice.subtotal.toStringAsFixed(2)}'),
                      if (invoice.discountAmount > 0)
                        _buildSummaryRow('Discount', '-$symbol${invoice.discountAmount.toStringAsFixed(2)}'),
                      _buildSummaryRow('Tax (${invoice.taxRate}%)', '$symbol${invoice.taxAmount.toStringAsFixed(2)}'),
                      pw.Divider(color: PdfColors.grey300),
                      _buildSummaryRow('Total', '$symbol${invoice.total.toStringAsFixed(2)}', isBold: true, color: primaryColor),
                    ],
                  ),
                ),
              ],
            ),
            
            // Footer
            pw.SizedBox(height: 50),
            pw.Divider(color: PdfColors.grey300),
            pw.SizedBox(height: 10),
            pw.Center(
              child: pw.Text('Thank you for your business!', style: pw.TextStyle(color: primaryColor, fontSize: 12, fontWeight: pw.FontWeight.bold)),
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildItemTable(Invoice invoice, String symbol, PdfColor primaryColor) {
    return pw.TableHelper.fromTextArray(
      headers: ['Description', 'Qty', 'Unit Price', 'Tax %', 'Total'],
      data: List<List<dynamic>>.generate(
        invoice.items.length,
        (index) {
          final item = invoice.items[index];
          return [
            item.description ?? 'Item',
            item.quantity.toString(),
            '$symbol${item.unitPrice.toStringAsFixed(2)}',
            '${item.taxRate.toStringAsFixed(1)}%',
            '$symbol${item.total.toStringAsFixed(2)}',
          ];
        },
      ),
      headerStyle: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 10),
      headerDecoration: pw.BoxDecoration(color: primaryColor),
      rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey200))),
      cellStyle: const pw.TextStyle(fontSize: 10),
      cellAlignments: {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.center,
        2: pw.Alignment.centerRight,
        3: pw.Alignment.centerRight,
        4: pw.Alignment.centerRight,
      },
    );
  }

  static pw.Widget _buildSummaryRow(String label, String value, {bool isBold = false, PdfColor? color}) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: pw.TextStyle(fontSize: 10, fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal)),
          pw.Text(value, style: pw.TextStyle(fontSize: 12, fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal, color: color)),
        ],
      ),
    );
  }
}
