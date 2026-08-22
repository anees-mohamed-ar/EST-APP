import 'dart:typed_data';
import 'package:excel/excel.dart';
import '../models/payroll_month_data.dart';

class PayrollExcelService {
  static Uint8List generate({
    required PayrollMonthData data,
    required String employeeName,
    required String username,
  }) {
    final excel = Excel.createExcel();
    final sheetName = username + ' - ' + data.displayLabel;
    final sheet = excel[sheetName];
    excel.delete('Sheet1');

    // Normal OT minutes
    final normalOtMins = data.totalWeekdayOtMinutes + data.totalSundayOtMinutes;
    final doubleOtMins = data.totalDoubleOtMinutes;

    // ── Style helpers ──────────────────────────────────────────────────────────
    CellStyle headerStyle() => CellStyle(
      bold: true,
      fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
      backgroundColorHex: ExcelColor.fromHexString('#000000'),
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );

    CellStyle summaryHeaderStyle() => CellStyle(
      bold: true,
      fontColorHex: ExcelColor.fromHexString('#111827'),
      backgroundColorHex: ExcelColor.fromHexString('#F9FAFB'),
      horizontalAlign: HorizontalAlign.Left,
    );

    CellStyle dataStyle(bool isSunday, bool isHoliday) {
      String bg = '#FFFFFF';
      if (isSunday) bg = '#FFF5F5';
      if (isHoliday) bg = '#FFFBF0';
      return CellStyle(
        horizontalAlign: HorizontalAlign.Center,
        backgroundColorHex: ExcelColor.fromHexString(bg),
      );
    }

    CellStyle totalStyle() => CellStyle(
      bold: true,
      fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
      backgroundColorHex: ExcelColor.fromHexString('#000000'),
      horizontalAlign: HorizontalAlign.Center,
    );

    void setCell(String addr, String value, CellStyle style) {
      final cell = sheet.cell(CellIndex.indexByString(addr));
      cell.value = TextCellValue(value);
      cell.cellStyle = style;
    }

    // ── Row 1: Title ──────────────────────────────────────────────────────────
    setCell('A1', 'MENAKA ELECTRICALS PVT LTD — PAYROLL REPORT (' + data.displayLabel + ') | ' + employeeName + ' (@' + username + ')', headerStyle());
    sheet.merge(CellIndex.indexByString('A1'), CellIndex.indexByString('J1'));

    // ── Row 2: Summary labels ─────────────────────────────────────────────────
    final summaryLabels = ['Days Present', 'Sundays', 'Holidays', 'Regular Hrs', 'Normal OT', '2x Double OT', 'Total OT', '', '', ''];
    for (int i = 0; i < summaryLabels.length; i++) {
      if (summaryLabels[i].isNotEmpty) {
        setCell(_col(i) + '2', summaryLabels[i], summaryHeaderStyle());
      }
    }

    // ── Row 3: Summary values ─────────────────────────────────────────────────
    final doubleLabel = doubleOtMins > 0
        ? '2x ' + _fmtMins(doubleOtMins) + '=' + _fmtMins(doubleOtMins * 2)
        : '--';
    final summaryValues = [
      data.totalDaysPresent.toString(),
      data.totalSundayDays.toString(),
      data.totalHolidayDays.toString(),
      data.totalRegular,
      _fmtMins(normalOtMins),
      doubleLabel,
      data.totalOvertime,
      '', '', '',
    ];
    for (int i = 0; i < summaryValues.length; i++) {
      if (summaryValues[i].isNotEmpty) {
        setCell(_col(i) + '3', summaryValues[i], CellStyle(
          bold: true,
          horizontalAlign: HorizontalAlign.Center,
        ));
      }
    }

    // ── Row 5: Column headers ─────────────────────────────────────────────────
    final headers = ['Date', 'Day', 'Type', 'Check In', 'Check Out', 'Duration', 'Regular', 'Normal OT', '2x Double OT', 'Total OT'];
    for (int i = 0; i < headers.length; i++) {
      setCell(_col(i) + '5', headers[i], headerStyle());
    }

    // ── Rows 6+: Daily data ───────────────────────────────────────────────────
    int row = 6;
    for (final r in data.days) {
      final dateRaw = r['date'] ?? '';
      final weekday = _weekdayName(dateRaw);
      final dayType = r['day_type'] ?? 'Weekday';
      final isSunday = dayType == 'Sunday' || r['is_sunday'] == true || weekday == 'Sun';
      final isHoliday = dayType == 'Holiday' || r['is_holiday'] == true;
      final style = dataStyle(isSunday, isHoliday);

      String dateLabel = dateRaw;
      try {
        final parts = dateRaw.split('-');
        if (parts.length == 3) dateLabel = parts[2] + '/' + parts[1] + '/' + parts[0].substring(2);
      } catch (_) {}

      final typeLabel = isHoliday ? (r['holiday_name'] ?? 'Holiday') : (isSunday ? 'Sunday' : dayType);
      final checkIn = (r['check_in'] ?? '').toString().length >= 5 ? r['check_in'].toString().substring(0, 5) : '--';
      final checkOut = (r['check_out'] ?? '').toString().length >= 5 ? r['check_out'].toString().substring(0, 5) : '--';

      final mins = r['minutes'] as Map<String, dynamic>? ?? {};
      final normalOt = (_safeInt(mins['weekday_ot_minutes']) + _safeInt(mins['sunday_ot_minutes']));
      final dOt = _safeInt(mins['double_ot_minutes']);
      final dOtLabel = dOt > 0 ? '2x ' + _fmtMins(dOt) + '=' + _fmtMins(dOt * 2) : '--';

      final fmt = r['formatted'] as Map<String, dynamic>? ?? {};

      final rowData = [dateLabel, weekday, typeLabel, checkIn, checkOut,
        fmt['duration'] ?? '--', fmt['regular'] ?? '--',
        normalOt > 0 ? _fmtMins(normalOt) : '--',
        dOtLabel, fmt['total_overtime'] ?? '--'];

      for (int i = 0; i < rowData.length; i++) {
        setCell(_col(i) + row.toString(), rowData[i], style);
      }
      row++;
    }

    // ── Total footer row ──────────────────────────────────────────────────────
    final totalRow = row;
    final totalStyle2 = totalStyle();
    setCell('A' + totalRow.toString(), 'MONTHLY TOTAL', totalStyle2);
    sheet.merge(CellIndex.indexByString('A' + totalRow.toString()), CellIndex.indexByString('E' + totalRow.toString()));
    setCell('F' + totalRow.toString(), _fmtMins(data.totalRegularMinutes + data.totalOvertimeMinutes), totalStyle2);
    setCell('G' + totalRow.toString(), data.totalRegular, totalStyle2);
    setCell('H' + totalRow.toString(), _fmtMins(normalOtMins), totalStyle2);
    setCell('I' + totalRow.toString(), doubleLabel, totalStyle2);
    setCell('J' + totalRow.toString(), data.totalOvertime, totalStyle2);

    // ── Column widths ─────────────────────────────────────────────────────────
    final widths = [14, 10, 16, 10, 10, 12, 12, 14, 22, 12];
    for (int i = 0; i < widths.length; i++) {
      sheet.setColumnWidth(i, widths[i].toDouble());
    }

    final bytes = excel.encode();
    return Uint8List.fromList(bytes!);
  }

  static String _col(int i) {
    const cols = ['A','B','C','D','E','F','G','H','I','J'];
    return i < cols.length ? cols[i] : 'A';
  }

  static String _fmtMins(int mins) {
    if (mins <= 0) return '0m';
    final h = mins ~/ 60;
    final m = mins % 60;
    if (h > 0 && m > 0) return h.toString() + 'h ' + m.toString() + 'm';
    if (h > 0) return h.toString() + 'h';
    return m.toString() + 'm';
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
