import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:aplikasi_pdam/models/bill.dart';

class InvoicePdfService {
  /// Generate PDF invoice for a Bill and return raw bytes
  Future<Uint8List> generateInvoice(Bill bill) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.copyWith(
          marginBottom: 1.5 * PdfPageFormat.cm,
          marginLeft: 1.5 * PdfPageFormat.cm,
          marginRight: 1.5 * PdfPageFormat.cm,
          marginTop: 1.5 * PdfPageFormat.cm,
        ),
        build: (ctx) => [
          _buildHeader(bill),
          pw.SizedBox(height: 20),
          _buildInfoSection(bill),
          pw.SizedBox(height: 20),
          _buildAmountTable(bill),
          pw.SizedBox(height: 20),
          _buildFooter(bill),
        ],
      ),
    );

    return pdf.save();
  }

  // ==================== HEADER ====================
  pw.Widget _buildHeader(Bill bill) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'PDAM',
                  style: pw.TextStyle(
                    fontSize: 28,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColor.fromInt(0xFF295CD0),
                  ),
                ),
                pw.Text(
                  'Perusahaan Daerah Air Minum',
                  style: pw.TextStyle(
                    fontSize: 10,
                    color: PdfColor.fromInt(0xFF667085),
                  ),
                ),
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                  'INVOICE',
                  style: pw.TextStyle(
                    fontSize: 32,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColor.fromInt(0xFF295CD0),
                  ),
                ),
                pw.Text(
                  bill.invoiceNumber,
                  style: pw.TextStyle(
                    fontSize: 12,
                    color: PdfColor.fromInt(0xFF667085),
                  ),
                ),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 4),
        pw.Divider(thickness: 2, color: PdfColor.fromInt(0xFF295CD0)),
      ],
    );
  }

  // ==================== INFO SECTION ====================
  pw.Widget _buildInfoSection(Bill bill) {
    final isVerified = bill.verifiedPayment;
    final isPaid = bill.paid;

    String statusText;
    PdfColor statusColor;
    if (isVerified) {
      statusText = 'LUNAS / TERVERIFIKASI';
      statusColor = PdfColor.fromInt(0xFF12B76A);
    } else if (isPaid) {
      statusText = 'MENUNGGU VERIFIKASI';
      statusColor = PdfColor.fromInt(0xFFFFA500);
    } else {
      statusText = 'BELUM DIBAYAR';
      statusColor = PdfColor.fromInt(0xFFEF4444);
    }

    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _infoLabel('Kepada:'),
              pw.SizedBox(height: 4),
              pw.Text(
                bill.customer?.name ?? '-',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                bill.customer?.address ?? '-',
                style: pw.TextStyle(fontSize: 10, color: PdfColor.fromInt(0xFF667085)),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                'Telp: ${bill.customer?.phone ?? '-'}',
                style: pw.TextStyle(fontSize: 10, color: PdfColor.fromInt(0xFF667085)),
              ),
            ],
          ),
        ),
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              _infoLabel('Status Pembayaran:'),
              pw.SizedBox(height: 4),
              pw.Container(
                padding: pw.EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: pw.BoxDecoration(
                  color: statusColor,
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Text(
                  statusText,
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColor.fromInt(0xFFFFFFFF),
                  ),
                ),
              ),
              pw.SizedBox(height: 8),
              _infoLabel('Tanggal Cetak:'),
              pw.Text(
                _formatDate(DateTime.now().toIso8601String()),
                style: pw.TextStyle(fontSize: 10, color: PdfColor.fromInt(0xFF667085)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ==================== AMOUNT TABLE ====================
  pw.Widget _buildAmountTable(Bill bill) {
    const headerColor = 0xFF295CD0;
    const borderColor = 0xFFE5E7EB;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'RINCIAN TAGIHAN',
          style: pw.TextStyle(
            fontSize: 14,
            fontWeight: pw.FontWeight.bold,
            color: PdfColor.fromInt(headerColor),
          ),
        ),
        pw.SizedBox(height: 8),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColor.fromInt(borderColor)),
          columnWidths: {
            0: const pw.FlexColumnWidth(2),
            1: const pw.FlexColumnWidth(1),
            2: const pw.FlexColumnWidth(1.5),
          },
          children: [
            // Header row
            pw.TableRow(
              decoration: pw.BoxDecoration(color: PdfColor.fromInt(headerColor)),
              children: [
                _tableHeader('Deskripsi'),
                _tableHeader('Volume'),
                _tableHeader('Jumlah'),
              ],
            ),
            // Service row
            pw.TableRow(
              children: [
                _tableCell('Pemakaian Air (${bill.service?.name ?? '-'})'),
                _tableCell('${bill.usageValue} m³'),
                _tableCell('Rp ${_formatNumber(bill.amount)}'),
              ],
            ),
            // Period row
            pw.TableRow(
              children: [
                _tableCell('Periode'),
                _tableCell(''),
                _tableCell(bill.period),
              ],
            ),
            // Measurement number
            pw.TableRow(
              children: [
                _tableCell('No. Meteran'),
                _tableCell(''),
                _tableCell(bill.measurementNumber),
              ],
            ),
            // Divider row
            pw.TableRow(
              children: [
                pw.Container(),
                pw.Container(),
                pw.Container(),
              ],
            ),
            // Total
            pw.TableRow(
              decoration: pw.BoxDecoration(color: PdfColor.fromInt(0xFFF8F9FA)),
              children: [
                pw.Container(
                  padding: pw.EdgeInsets.all(8),
                  child: pw.Text(
                    'TOTAL',
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
                pw.Container(
                  padding: pw.EdgeInsets.all(8),
                  child: pw.Text(''),
                ),
                pw.Container(
                  padding: pw.EdgeInsets.all(8),
                  child: pw.Text(
                    'Rp ${_formatNumber(bill.amount)}',
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColor.fromInt(0xFF295CD0),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  // ==================== FOOTER ====================
  pw.Widget _buildFooter(Bill bill) {
    return pw.Column(
      children: [
        pw.Divider(thickness: 1, color: PdfColor.fromInt(0xFFE5E7EB)),
        pw.SizedBox(height: 8),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'No. Pelanggan: ${bill.customer?.customerNumber ?? '-'}',
                  style: pw.TextStyle(fontSize: 9, color: PdfColor.fromInt(0xFF667085)),
                ),
                pw.Text(
                  'ID Tagihan: ${bill.id}',
                  style: pw.TextStyle(fontSize: 9, color: PdfColor.fromInt(0xFF667085)),
                ),
              ],
            ),
            pw.Text(
              'Dicetak otomatis dari sistem PDAM',
              style: pw.TextStyle(fontSize: 8, color: PdfColor.fromInt(0xFF98A2B3)),
            ),
          ],
        ),
      ],
    );
  }

  // ==================== HELPERS ====================
  pw.Widget _tableHeader(String text) {
    return pw.Container(
      padding: pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 10,
          fontWeight: pw.FontWeight.bold,
          color: PdfColor.fromInt(0xFFFFFFFF),
        ),
      ),
    );
  }

  pw.Widget _tableCell(String text) {
    return pw.Container(
      padding: pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: pw.TextStyle(fontSize: 10),
      ),
    );
  }

  pw.Widget _infoLabel(String text) {
    return pw.Text(
      text,
      style: pw.TextStyle(
        fontSize: 10,
        fontWeight: pw.FontWeight.bold,
        color: PdfColor.fromInt(0xFF98A2B3),
      ),
    );
  }

  String _formatNumber(num n) {
    return n.toInt().toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]}.',
    );
  }

  String _formatDate(String dateStr) {
    if (dateStr.isEmpty) return '-';
    try {
      final dt = DateTime.parse(dateStr);
      const months = [
        '', 'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
        'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
      ];
      return '${dt.day} ${months[dt.month]} ${dt.year}';
    } catch (_) {
      return dateStr;
    }
  }

  // ==================== SHOW PREVIEW / PRINT ====================
  /// Generate PDF, save to temp file, then open share sheet
  static Future<void> showInvoicePreview(BuildContext context, Bill bill) async {
    try {
      final service = InvoicePdfService();
      final bytes = await service.generateInvoice(bill);

      final dir = await getTemporaryDirectory();
      final fileName = 'invoice_${bill.invoiceNumber.replaceAll('/', '_')}.pdf';
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(bytes);

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          subject: 'Invoice ${bill.invoiceNumber}',
          text: 'Invoice PDAM - ${bill.invoiceNumber}',
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mencetak invoice: $e')),
        );
      }
    }
  }
}
