import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart' show rootBundle;

/// Configuration for PDF report generation
class ReportConfig {
  final String title;
  final String subtitle;
  final DateTime generatedDate;
  final List<String>? filters;
  final Map<String, String>? summaryData;
  final List<List<String>> tableHeaders;
  final List<List<String>> tableData;
  final String? footerText;

  ReportConfig({
    required this.title,
    required this.subtitle,
    required this.generatedDate,
    this.filters,
    this.summaryData,
    required this.tableHeaders,
    required this.tableData,
    this.footerText,
  });
}

/// Service for generating PDF reports with consistent branding
class PdfService {
  static const String appName = 'Hotel Inventory Management System';
  static const String appAbbr = 'HIMS';

  /// Generate a PDF report from the provided configuration
  Future<File> generateReport(ReportConfig config) async {
    final pdf = pw.Document();

    // Add pages
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          _buildHeader(config),
          pw.SizedBox(height: 20),
          if (config.filters != null && config.filters!.isNotEmpty)
            _buildFilters(config.filters!),
          if (config.summaryData != null && config.summaryData!.isNotEmpty)
            _buildSummary(config.summaryData!),
          pw.SizedBox(height: 20),
          _buildTable(config.tableHeaders, config.tableData),
        ],
        footer: (context) => _buildFooter(
          config,
          context.pageNumber,
          context.pagesCount,
        ),
      ),
    );

    // Save PDF file
    return _savePdf(pdf, config.title);
  }

  /// Build report header with branding
  pw.Widget _buildHeader(ReportConfig config) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // App branding
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  appAbbr,
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue700,
                  ),
                ),
                pw.Text(
                  appName,
                  style: const pw.TextStyle(
                    fontSize: 10,
                    color: PdfColors.grey700,
                  ),
                ),
              ],
            ),
            pw.Container(
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(
                color: PdfColors.blue50,
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Text(
                'REPORT',
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue700,
                ),
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 10),
        pw.Divider(color: PdfColors.blue700, thickness: 2),
        pw.SizedBox(height: 10),

        // Report title and info
        pw.Text(
          config.title,
          style: pw.TextStyle(
            fontSize: 20,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          config.subtitle,
          style: const pw.TextStyle(
            fontSize: 12,
            color: PdfColors.grey700,
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          'Generated: ${DateFormat('dd MMM yyyy HH:mm').format(config.generatedDate)}',
          style: const pw.TextStyle(
            fontSize: 10,
            color: PdfColors.grey600,
          ),
        ),
      ],
    );
  }

  /// Build filters section
  pw.Widget _buildFilters(List<String> filters) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Applied Filters',
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 6),
          ...filters.map(
            (filter) => pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 2),
              child: pw.Row(
                children: [
                  pw.Container(
                    width: 4,
                    height: 4,
                    decoration: const pw.BoxDecoration(
                      color: PdfColors.blue700,
                      shape: pw.BoxShape.circle,
                    ),
                  ),
                  pw.SizedBox(width: 6),
                  pw.Text(
                    filter,
                    style: const pw.TextStyle(
                      fontSize: 10,
                      color: PdfColors.grey700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build summary section with key metrics
  pw.Widget _buildSummary(Map<String, String> summaryData) {
    final entries = summaryData.entries.toList();
    final rows = <pw.Widget>[];

    for (int i = 0; i < entries.length; i += 4) {
      final rowEntries = entries.skip(i).take(4).toList();
      rows.add(
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
          children: rowEntries.map((entry) {
            return pw.Expanded(
              child: pw.Container(
                margin: const pw.EdgeInsets.all(4),
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: PdfColors.blue50,
                  borderRadius: pw.BorderRadius.circular(4),
                  border: pw.Border.all(color: PdfColors.blue200),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      entry.key,
                      style: const pw.TextStyle(
                        fontSize: 9,
                        color: PdfColors.grey700,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      entry.value,
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue700,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      );
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Summary',
          style: pw.TextStyle(
            fontSize: 14,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 10),
        ...rows,
        pw.SizedBox(height: 10),
      ],
    );
  }

  /// Build data table
  pw.Widget _buildTable(
    List<List<String>> headers,
    List<List<String>> data,
  ) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400),
      columnWidths: {
        for (int i = 0; i < headers[0].length; i++)
          i: const pw.FlexColumnWidth(),
      },
      children: [
        // Header row
        pw.TableRow(
          decoration: const pw.BoxDecoration(
            color: PdfColors.blue700,
          ),
          children: headers[0].map((header) {
            return pw.Padding(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Text(
                header,
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                ),
              ),
            );
          }).toList(),
        ),

        // Data rows
        ...data.asMap().entries.map((entry) {
          final index = entry.key;
          final row = entry.value;

          return pw.TableRow(
            decoration: pw.BoxDecoration(
              color: index % 2 == 0 ? PdfColors.white : PdfColors.grey100,
            ),
            children: row.map((cell) {
              return pw.Padding(
                padding: const pw.EdgeInsets.all(8),
                child: pw.Text(
                  cell,
                  style: const pw.TextStyle(
                    fontSize: 9,
                    color: PdfColors.black,
                  ),
                ),
              );
            }).toList(),
          );
        }),
      ],
    );
  }

  /// Build footer with page numbers and branding
  pw.Widget _buildFooter(ReportConfig config, int pageNumber, int totalPages) {
    return pw.Container(
      alignment: pw.Alignment.center,
      margin: const pw.EdgeInsets.only(top: 16),
      padding: const pw.EdgeInsets.only(top: 8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          top: pw.BorderSide(
            color: PdfColors.grey400,
            width: 1,
          ),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            config.footerText ?? appName,
            style: const pw.TextStyle(
              fontSize: 8,
              color: PdfColors.grey600,
            ),
          ),
          pw.Text(
            'Page $pageNumber of $totalPages',
            style: const pw.TextStyle(
              fontSize: 8,
              color: PdfColors.grey600,
            ),
          ),
          pw.Text(
            'Generated: ${DateFormat('dd/MM/yyyy').format(config.generatedDate)}',
            style: const pw.TextStyle(
              fontSize: 8,
              color: PdfColors.grey600,
            ),
          ),
        ],
      ),
    );
  }

  /// Save PDF to device storage and return the file
  Future<File> _savePdf(pw.Document pdf, String fileName) async {
    // Get the app directory
    final directory = await getApplicationDocumentsDirectory();
    final reportsDir = Directory('${directory.path}/HIMS_Reports');

    // Create directory if it doesn't exist
    if (!await reportsDir.exists()) {
      await reportsDir.create(recursive: true);
    }

    // Create file path with timestamp
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final sanitizedFileName = fileName.replaceAll(RegExp(r'[^\w\s-]'), '');
    final filePath = '${reportsDir.path}/${sanitizedFileName}_$timestamp.pdf';

    // Save the PDF
    final file = File(filePath);
    await file.writeAsBytes(await pdf.save());

    return file;
  }

  /// Share or open the generated PDF
  /// Note: Requires platform-specific implementation
  Future<void> sharePdf(File pdfFile) async {
    // This is a placeholder for sharing functionality
    // In a real implementation, you would use:
    // - share_plus package for sharing on mobile
    // - url_launcher for opening on web
    // - Desktop-specific sharing on desktop platforms
    print('PDF saved to: ${pdfFile.path}');
    // TODO: Implement platform-specific sharing
  }
}
