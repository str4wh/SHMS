import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'admin_repository.dart';

class ReportService {
  ReportService._();

  static const PdfColor _brandBlue = PdfColor(30 / 255, 58 / 255, 138 / 255);
  static const PdfColor _brandAccent = PdfColor(91 / 255, 192 / 255, 255 / 255);
  static const PdfColor _surfaceBlue = PdfColor(
    239 / 255,
    246 / 255,
    255 / 255,
  );
  static const PdfColor _danger = PdfColor(220 / 255, 38 / 255, 38 / 255);
  static const PdfColor _warning = PdfColor(234 / 255, 88 / 255, 12 / 255);
  static const PdfColor _success = PdfColor(22 / 255, 163 / 255, 74 / 255);

  static Future<void> generateAndDownloadReport() async {
    final generatedAt = DateTime.now();
    final results = await Future.wait<dynamic>([
      AdminRepository.fetchTotalRoomsCount(),
      AdminRepository.fetchOccupiedRoomsCount(),
      AdminRepository.fetchPendingPaymentsCount(),
      AdminRepository.fetchOpenMaintenanceCount(),
      AdminRepository.fetchOpenMaintenanceRequests(),
      AdminRepository.fetchPendingBookings(),
      AdminRepository.fetchPendingPayments(),
    ]);

    final report = _AdminReportData(
      totalRooms: results[0] as int,
      occupiedRooms: results[1] as int,
      pendingPayments: results[2] as int,
      openMaintenance: results[3] as int,
      maintenanceRequests: _sortByNewest(
        results[4] as List<QueryDocumentSnapshot<Map<String, dynamic>>>,
        (data) => _extractDate(data, ['createdAt']),
      ).take(10).toList(),
      pendingBookings: _sortByNewest(
        results[5] as List<QueryDocumentSnapshot<Map<String, dynamic>>>,
        (data) => _extractDate(data, ['createdAt', 'bookingDate']),
      ).take(10).toList(),
      pendingPaymentItems: _sortByNewest(
        results[6] as List<QueryDocumentSnapshot<Map<String, dynamic>>>,
        (data) => _extractDate(data, [
          'createdAt',
          'transactionDate',
          'queuedAt',
          'completedAt',
        ]),
      ).take(10).toList(),
      generatedAt: generatedAt,
    );

    final pdfBytes = await _buildPdf(report);
    await Printing.layoutPdf(onLayout: (_) async => pdfBytes);
  }

  static Future<Uint8List> _buildPdf(_AdminReportData report) async {
    // Load Unicode-compatible fonts - required for Flutter Web
    final regularFont = await PdfGoogleFonts.notoSansRegular();
    final boldFont = await PdfGoogleFonts.notoSansBold();

    final document = pw.Document(
      theme: pw.ThemeData.withFont(base: regularFont, bold: boldFont),
    );
    final generatedLabel = DateFormat(
      'MMM d, yyyy h:mm a',
    ).format(report.generatedAt);

    document.addPage(
      pw.MultiPage(
        pageTheme: const pw.PageTheme(
          margin: pw.EdgeInsets.fromLTRB(28, 28, 28, 36),
        ),
        footer: (context) => pw.Container(
          margin: const pw.EdgeInsets.only(top: 12),
          padding: const pw.EdgeInsets.only(top: 8),
          decoration: const pw.BoxDecoration(
            border: pw.Border(
              top: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
            ),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Student Hostel Management',
                style: const pw.TextStyle(
                  fontSize: 9,
                  color: PdfColors.grey700,
                ),
              ),
              pw.Text(
                'Page ${context.pageNumber} of ${context.pagesCount}',
                style: const pw.TextStyle(
                  fontSize: 9,
                  color: PdfColors.grey700,
                ),
              ),
            ],
          ),
        ),
        build: (context) => [
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(18),
            decoration: const pw.BoxDecoration(
              color: _brandBlue,
              borderRadius: pw.BorderRadius.all(pw.Radius.circular(8)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Student Hostel Management - Admin Report',
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 6),
                pw.Text(
                  'Generated on $generatedLabel',
                  style: const pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 18),
          _buildSectionTitle('Section 1 - Overview Metrics'),
          pw.SizedBox(height: 8),
          _buildOverviewTable(report),
          pw.SizedBox(height: 18),
          _buildSectionTitle('Section 2 - Recent Maintenance Requests'),
          pw.SizedBox(height: 8),
          _buildMaintenanceTable(report.maintenanceRequests),
          pw.SizedBox(height: 18),
          _buildSectionTitle('Section 3 - Pending Bookings'),
          pw.SizedBox(height: 8),
          _buildBookingsTable(report.pendingBookings),
          pw.SizedBox(height: 18),
          _buildSectionTitle('Section 4 - Pending Payments'),
          pw.SizedBox(height: 8),
          _buildPaymentsTable(report.pendingPaymentItems),
        ],
      ),
    );

    return document.save();
  }

  static List<Map<String, dynamic>> _sortByNewest(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    DateTime? Function(Map<String, dynamic> data) getDate,
  ) {
    final items = docs.map((doc) => doc.data()).toList();
    items.sort((a, b) {
      final aDate = getDate(a) ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bDate = getDate(b) ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bDate.compareTo(aDate);
    });
    return items;
  }

  static pw.Widget _buildSectionTitle(String title) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: const pw.BoxDecoration(
        color: _surfaceBlue,
        borderRadius: pw.BorderRadius.all(pw.Radius.circular(6)),
      ),
      child: pw.Row(
        children: [
          pw.Container(
            width: 6,
            height: 18,
            decoration: const pw.BoxDecoration(
              color: _brandAccent,
              borderRadius: pw.BorderRadius.all(pw.Radius.circular(99)),
            ),
          ),
          pw.SizedBox(width: 8),
          pw.Text(
            title,
            style: pw.TextStyle(
              color: _brandBlue,
              fontSize: 13,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildOverviewTable(_AdminReportData report) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      children: [
        pw.TableRow(
          children: [
            _buildMetricCell('Total Rooms', report.totalRooms),
            _buildMetricCell('Occupied Rooms', report.occupiedRooms),
          ],
        ),
        pw.TableRow(
          children: [
            _buildMetricCell('Pending Payments', report.pendingPayments),
            _buildMetricCell('Open Maintenance', report.openMaintenance),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildMetricCell(String label, int value) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: const pw.BoxDecoration(color: PdfColors.white),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            label,
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            value.toString(),
            style: pw.TextStyle(
              fontSize: 22,
              fontWeight: pw.FontWeight.bold,
              color: _brandBlue,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildMaintenanceTable(List<Map<String, dynamic>> items) {
    final rows = items
        .map(
          (item) => [
            _buildBodyCell(_stringValue(item, ['issueType'])),
            _buildBodyCell(
              _stringValue(item, ['roomNumber', 'roomID', 'roomId']),
            ),
            _buildUrgencyCell(
              _stringValue(item, ['urgency'], fallback: 'Unknown'),
            ),
            _buildBodyCell(
              _stringValue(item, ['description'], fallback: 'No description'),
            ),
          ],
        )
        .toList();

    return _buildTable(
      headers: const ['Issue Type', 'Room', 'Urgency', 'Description'],
      rows: rows,
      columnWidths: {
        0: const pw.FlexColumnWidth(1.3),
        1: const pw.FlexColumnWidth(0.8),
        2: const pw.FlexColumnWidth(0.9),
        3: const pw.FlexColumnWidth(2.4),
      },
      emptyMessage: 'No open maintenance requests.',
    );
  }

  static pw.Widget _buildBookingsTable(List<Map<String, dynamic>> items) {
    final rows = items
        .map(
          (item) => [
            _buildBodyCell(
              _stringValue(item, ['roomId', 'roomID', 'roomNumber']),
            ),
            _buildBodyCell(_stringValue(item, ['status'])),
            _buildBodyCell(
              _formatDate(_extractDate(item, ['createdAt', 'bookingDate'])),
            ),
          ],
        )
        .toList();

    return _buildTable(
      headers: const ['Room ID', 'Status', 'Date'],
      rows: rows,
      columnWidths: {
        0: const pw.FlexColumnWidth(1.5),
        1: const pw.FlexColumnWidth(1.0),
        2: const pw.FlexColumnWidth(1.3),
      },
      emptyMessage: 'No pending bookings.',
    );
  }

  static pw.Widget _buildPaymentsTable(List<Map<String, dynamic>> items) {
    final rows = items
        .map(
          (item) => [
            _buildBodyCell(_formatAmount(item['amount'])),
            _buildBodyCell(_stringValue(item, ['status'])),
            _buildBodyCell(
              _formatDate(
                _extractDate(item, [
                  'createdAt',
                  'transactionDate',
                  'queuedAt',
                  'completedAt',
                ]),
              ),
            ),
          ],
        )
        .toList();

    return _buildTable(
      headers: const ['Amount', 'Status', 'Date'],
      rows: rows,
      columnWidths: {
        0: const pw.FlexColumnWidth(1.0),
        1: const pw.FlexColumnWidth(1.0),
        2: const pw.FlexColumnWidth(1.4),
      },
      emptyMessage: 'No pending payments.',
    );
  }

  static pw.Widget _buildTable({
    required List<String> headers,
    required List<List<pw.Widget>> rows,
    required String emptyMessage,
    Map<int, pw.TableColumnWidth>? columnWidths,
  }) {
    final tableRows = <pw.TableRow>[
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: _brandBlue),
        children: headers.map(_buildHeaderCell).toList(),
      ),
    ];

    if (rows.isEmpty) {
      tableRows.add(
        pw.TableRow(
          children: [
            _buildBodyCell(emptyMessage),
            for (var index = 1; index < headers.length; index++)
              _buildBodyCell(''),
          ],
        ),
      );
    } else {
      tableRows.addAll(rows.map((row) => pw.TableRow(children: row)));
    }

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      columnWidths: columnWidths,
      children: tableRows,
    );
  }

  static pw.Widget _buildHeaderCell(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          color: PdfColors.white,
          fontSize: 10,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
    );
  }

  static pw.Widget _buildBodyCell(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: const pw.TextStyle(fontSize: 10, color: PdfColors.black),
      ),
    );
  }

  static pw.Widget _buildUrgencyCell(String urgency) {
    final normalized = urgency.toLowerCase();
    PdfColor color;
    if (normalized == 'high' ||
        normalized == 'urgent' ||
        normalized == 'critical') {
      color = _danger;
    } else if (normalized == 'medium') {
      color = _warning;
    } else {
      color = _success;
    }

    return pw.Container(
      color: color,
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        urgency,
        style: pw.TextStyle(
          color: PdfColors.white,
          fontSize: 10,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
    );
  }

  static DateTime? _extractDate(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key];
      final parsed = _toDateTime(value);
      if (parsed != null) {
        return parsed;
      }
    }
    return null;
  }

  static DateTime? _toDateTime(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }
    if (value is String) {
      return DateTime.tryParse(value);
    }
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }
    return null;
  }

  static String _formatDate(DateTime? value) {
    if (value == null) {
      return '-';
    }
    return DateFormat('yyyy-MM-dd HH:mm').format(value);
  }

  static String _formatAmount(dynamic amount) {
    if (amount is num) {
      return 'KES ${NumberFormat.decimalPattern().format(amount)}';
    }
    final parsed = num.tryParse(amount?.toString() ?? '');
    if (parsed == null) {
      return 'KES 0';
    }
    return 'KES ${NumberFormat.decimalPattern().format(parsed)}';
  }

  static String _stringValue(
    Map<String, dynamic> data,
    List<String> keys, {
    String fallback = '-',
  }) {
    for (final key in keys) {
      final value = data[key];
      final asString = value?.toString().trim();
      if (asString != null && asString.isNotEmpty) {
        return asString;
      }
    }
    return fallback;
  }
}

class _AdminReportData {
  const _AdminReportData({
    required this.totalRooms,
    required this.occupiedRooms,
    required this.pendingPayments,
    required this.openMaintenance,
    required this.maintenanceRequests,
    required this.pendingBookings,
    required this.pendingPaymentItems,
    required this.generatedAt,
  });

  final int totalRooms;
  final int occupiedRooms;
  final int pendingPayments;
  final int openMaintenance;
  final List<Map<String, dynamic>> maintenanceRequests;
  final List<Map<String, dynamic>> pendingBookings;
  final List<Map<String, dynamic>> pendingPaymentItems;
  final DateTime generatedAt;
}
