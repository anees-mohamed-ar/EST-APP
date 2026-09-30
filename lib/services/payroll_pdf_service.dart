import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/payroll_month_data.dart';

class PayrollPdfService {
  static Future<Uint8List> generate({
    required PayrollMonthData data,
    required String employeeName,
    required String username,
  }) async {
    final pdf = pw.Document();
    final headerColor = PdfColors.black;
    final accentGreen = PdfColor.fromHex('#059669');
    final accentBlue = PdfColor.fromHex('#2563EB');
    final accentPurple = PdfColor.fromHex('#7C3AED');
    final sundayBg = PdfColor.fromHex('#FFF5F5');
    final holidayBg = PdfColor.fromHex('#FFFBF0');
    final lightGray = PdfColor.fromHex('#F9FAFB');
    final borderColor = PdfColor.fromHex('#E5E7EB');
    final textPrimary = PdfColor.fromHex('#111827');
    final textSecondary = PdfColor.fromHex('#6B7280');

    pw.MemoryImage? logoImage;
    for (final path in [
      'assets/images/company_logo_in_payslip.jpg',
      'company_logo_in_payslip.jpg',
      'assets/images/me-logo-clean.png',
      'me-logo-clean.png',
    ]) {
      try {
        final logoData = await rootBundle.load(path);
        logoImage = pw.MemoryImage(logoData.buffer.asUint8List());
        break;
      } catch (_) {}
    }

    if (logoImage == null) {
      for (final filePath in [
        'c:/Users/IMT290/StudioProjects/EST/me-logo-clean.png',
        'c:/Users/IMT290/StudioProjects/EST/assets/images/me-logo-clean.png',
      ]) {
        try {
          final file = File(filePath);
          if (await file.exists()) {
            logoImage = pw.MemoryImage(await file.readAsBytes());
            break;
          }
        } catch (_) {}
      }
    }

    final now = DateTime.now();
    final generatedOn = _fmt(now.day) + '/' + _fmt(now.month) + '/' + now.year.toString() +
        '  ' + _fmt(now.hour) + ':' + _fmt(now.minute);

    // Normal OT minutes = weekday_ot + sunday_ot
    final normalOtMins = data.totalWeekdayOtMinutes + data.totalSundayOtMinutes;
    final doubleOtMins = data.totalDoubleOtMinutes;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        header: (ctx) => _buildHeader(
          employeeName: employeeName,
          username: username,
          month: data.displayLabel,
          generatedOn: generatedOn,
          headerColor: headerColor,
          logoImage: logoImage,
        ),
        footer: (ctx) => _buildFooter(ctx, textSecondary),
        build: (ctx) => [
          pw.SizedBox(height: 16),
          // Summary Cards
          _buildSummaryGrid(data, accentGreen, accentBlue, accentPurple, borderColor, lightGray, textPrimary, textSecondary, normalOtMins, doubleOtMins),
          pw.SizedBox(height: 20),
          if (data.days.isNotEmpty) ...[
            pw.Text('Daily Breakdown',
                style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: textPrimary)),
            pw.SizedBox(height: 8),
            _buildDailyTable(data.days, headerColor, sundayBg, holidayBg, borderColor, textPrimary, textSecondary),
            pw.SizedBox(height: 12),
            _buildTotalRow(data, normalOtMins, doubleOtMins, headerColor),
          ] else
            _buildEmptyState(textSecondary),
        ],
      ),
    );

    return pdf.save();
  }

  // ─── Header ──────────────────────────────────────────────────────────────────
  static pw.Widget _buildHeader({
    required String employeeName,
    required String username,
    required String month,
    required String generatedOn,
    required PdfColor headerColor,
    pw.MemoryImage? logoImage,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 12),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 1)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Row(
            children: [
              if (logoImage != null) ...[
                pw.Container(
                  width: 38,
                  height: 38,
                  margin: const pw.EdgeInsets.only(right: 10),
                  child: pw.Image(logoImage, fit: pw.BoxFit.contain),
                ),
              ],
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Menaka Electricals Pvt Ltd',
                      style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#000000'))),
                  pw.SizedBox(height: 2),
                  pw.Text('PAYROLL REPORT',
                      style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#4B5563'))),
                  pw.SizedBox(height: 2),
                  pw.Text('Employee: $employeeName  (@$username)',
                      style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                ],
              ),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: const pw.BoxDecoration(
                  color: PdfColors.black,
                  borderRadius: pw.BorderRadius.all(pw.Radius.circular(4)),
                ),
                child: pw.Text(month,
                    style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
              ),
              pw.SizedBox(height: 4),
              pw.Text('Generated: $generatedOn',
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Summary Grid ─────────────────────────────────────────────────────────────
  static pw.Widget _buildSummaryGrid(
    PayrollMonthData data,
    PdfColor accentGreen,
    PdfColor accentBlue,
    PdfColor accentPurple,
    PdfColor borderColor,
    PdfColor lightGray,
    PdfColor textPrimary,
    PdfColor textSecondary,
    int normalOtMins,
    int doubleOtMins,
  ) {
    final items = [
      ('Days Present', data.totalDaysPresent.toString(), PdfColors.black),
      ('Sundays', data.totalSundayDays.toString(), PdfColors.red700),
      ('Holidays', data.totalHolidayDays.toString(), PdfColors.orange700),
      ('Regular Hrs', data.totalRegular, accentGreen),
      ('Normal OT', _fmtMins(normalOtMins), accentBlue),
      ('Total OT', data.totalOvertime, PdfColors.black),
    ];

    return pw.Row(
      children: items.map((item) {
        return pw.Expanded(
          child: pw.Container(
            margin: const pw.EdgeInsets.only(right: 6),
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: lightGray,
              border: pw.Border.all(color: borderColor, width: 0.5),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(item.$1,
                    style: pw.TextStyle(fontSize: 7.5, color: textSecondary, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 4),
                pw.Text(item.$2,
                    style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: item.$3)),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // ─── Daily Table ─────────────────────────────────────────────────────────────
  static pw.Widget _buildDailyTable(
    List<Map<String, dynamic>> days,
    PdfColor headerColor,
    PdfColor sundayBg,
    PdfColor holidayBg,
    PdfColor borderColor,
    PdfColor textPrimary,
    PdfColor textSecondary,
  ) {
    final headers = ['Date', 'Day', 'Type', 'In', 'Out', 'Duration', 'Regular', 'Normal OT', '2x Double OT', 'Total OT'];
    final colWidths = [50.0, 42.0, 44.0, 32.0, 32.0, 42.0, 42.0, 46.0, 64.0, 42.0];

    pw.Widget cell(String text, {bool isHeader = false, PdfColor? bg, PdfColor? fg, double? w}) {
      return pw.Container(
        width: w,
        padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        color: bg ?? PdfColors.white,
        child: pw.Text(
          text,
          style: pw.TextStyle(
            fontSize: isHeader ? 7.5 : 7,
            fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
            color: fg ?? (isHeader ? PdfColors.white : PdfColors.grey800),
          ),
        ),
      );
    }

    return pw.Table(
      border: pw.TableBorder.all(color: borderColor, width: 0.5),
      columnWidths: {
        for (int i = 0; i < colWidths.length; i++)
          i: pw.FixedColumnWidth(colWidths[i]),
      },
      children: [
        // Header row
        pw.TableRow(
          decoration: pw.BoxDecoration(color: headerColor),
          children: headers.asMap().entries.map((e) =>
            cell(e.value, isHeader: true, bg: headerColor, fg: PdfColors.white, w: colWidths[e.key])
          ).toList(),
        ),
        // Data rows
        ...days.map((r) {
          final dateRaw = r['date'] ?? '';
          final weekday = _weekdayName(dateRaw);
          final dayType = r['day_type'] ?? 'Weekday';
          final isSunday = dayType == 'Sunday' || r['is_sunday'] == true || weekday == 'Sun';
          final isHoliday = dayType == 'Holiday' || r['is_holiday'] == true;
          final rowBg = isSunday ? sundayBg : isHoliday ? holidayBg : PdfColors.white;
          final textFg = isSunday ? PdfColors.red700 : isHoliday ? PdfColors.orange800 : null;

          String dateLabel = dateRaw;
          try {
            final parts = dateRaw.split('-');
            if (parts.length == 3) {
              dateLabel = parts[2] + '/' + parts[1] + '/' + parts[0].substring(2);
            }
          } catch (_) {}

          final typeLabel = isHoliday ? (r['holiday_name'] ?? 'Holiday') : (isSunday ? 'Sunday' : dayType);
          final checkIn = (r['check_in'] ?? '').toString().length >= 5
              ? r['check_in'].toString().substring(0, 5) : '--';
          final checkOut = (r['check_out'] ?? '').toString().length >= 5
              ? r['check_out'].toString().substring(0, 5) : '--';

          final mins = r['minutes'] as Map<String, dynamic>? ?? {};
          final normalOt = (_safeInt(mins['weekday_ot_minutes']) + _safeInt(mins['sunday_ot_minutes']));
          final doubleOt = _safeInt(mins['double_ot_minutes']);
          final doubleOtLabel = doubleOt > 0 ? '2x ${_fmtMins(doubleOt)}=${_fmtMins(doubleOt * 2)}' : '--';

          final fmt = r['formatted'] as Map<String, dynamic>? ?? {};

          return pw.TableRow(
            decoration: pw.BoxDecoration(color: rowBg),
            children: [
              cell(dateLabel, w: colWidths[0], bg: rowBg, fg: textFg),
              cell(weekday, w: colWidths[1], bg: rowBg, fg: textFg),
              cell(typeLabel, w: colWidths[2], bg: rowBg, fg: textFg),
              cell(checkIn, w: colWidths[3], bg: rowBg, fg: textFg),
              cell(checkOut, w: colWidths[4], bg: rowBg, fg: textFg),
              cell(fmt['duration'] ?? '--', w: colWidths[5], bg: rowBg, fg: textFg),
              cell(fmt['regular'] ?? '--', w: colWidths[6], bg: rowBg, fg: textFg),
              cell(normalOt > 0 ? _fmtMins(normalOt) : '--', w: colWidths[7], bg: rowBg, fg: textFg),
              cell(doubleOtLabel, w: colWidths[8], bg: rowBg, fg: textFg),
              cell(fmt['total_overtime'] ?? '--', w: colWidths[9], bg: rowBg, fg: textFg),
            ],
          );
        }),
      ],
    );
  }

  // ─── Total Footer Row ─────────────────────────────────────────────────────────
  static pw.Widget _buildTotalRow(
    PayrollMonthData data,
    int normalOtMins,
    int doubleOtMins,
    PdfColor headerColor,
  ) {
    final doubleLabel = doubleOtMins > 0
        ? '2x ${_fmtMins(doubleOtMins)}=${_fmtMins(doubleOtMins * 2)}'
        : '--';

    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: pw.BoxDecoration(color: headerColor),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('MONTHLY TOTAL',
              style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
          pw.Text('Regular: ${data.totalRegular}  |  Normal OT: ${_fmtMins(normalOtMins)}  |  2x OT: $doubleLabel  |  Total OT: ${data.totalOvertime}',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.white)),
        ],
      ),
    );
  }

  // ─── Empty State ─────────────────────────────────────────────────────────────
  static pw.Widget _buildEmptyState(PdfColor textSecondary) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(24),
      child: pw.Center(
        child: pw.Text('No payroll data available for this month.',
            style: pw.TextStyle(fontSize: 12, color: textSecondary)),
      ),
    );
  }

  // ─── PDF Footer ───────────────────────────────────────────────────────────────
  static pw.Widget _buildFooter(pw.Context ctx, PdfColor textSecondary) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text('MEPL Track',
            style: pw.TextStyle(fontSize: 8, color: textSecondary)),
        pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}',
            style: pw.TextStyle(fontSize: 8, color: textSecondary)),
      ],
    );
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────────
  static String _fmt(int n) => n.toString().padLeft(2, '0');

  static String _fmtMins(int mins) {
    if (mins <= 0) return '0m';
    final h = mins ~/ 60;
    final m = mins % 60;
    if (h > 0 && m > 0) return '${h}h ${m}m';
    if (h > 0) return '${h}h';
    return '${m}m';
  }

  static int _safeInt(dynamic val) {
    if (val == null) return 0;
    if (val is int) return val;
    if (val is num) return val.toInt();
    if (val is String) {
      final d = double.tryParse(val);
      if (d != null) return d.toInt();
      final i = int.tryParse(val);
      if (i != null) return i;
    }
    return 0;
  }

  static String _weekdayName(String dateRaw) {
    try {
      final parts = dateRaw.split('-');
      if (parts.length < 3) return '';
      final dt = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
      const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return days[dt.weekday - 1];
    } catch (_) {
      return '';
    }
  }
}
