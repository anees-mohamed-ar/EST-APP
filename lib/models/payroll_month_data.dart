class PayrollMonthData {
  final String yearMonth;
  final String displayLabel;
  final Map<String, dynamic> summary;
  final List<Map<String, dynamic>> days;
  final bool isEmpty;

  const PayrollMonthData({
    required this.yearMonth,
    required this.displayLabel,
    required this.summary,
    required this.days,
    this.isEmpty = false,
  });

  Map<String, dynamic> get attendance =>
      (summary['attendance'] as Map<String, dynamic>?) ?? {};
  Map<String, dynamic> get formatted =>
      (summary['formatted'] as Map<String, dynamic>?) ?? {};
  Map<String, dynamic> get minutes =>
      (summary['minutes'] as Map<String, dynamic>?) ?? {};

  int get totalDaysPresent {
    final raw = _safeInt(attendance['total_days_present']);
    if (raw > 0) return raw;
    if (days.isNotEmpty) {
      return days.where((d) => d['check_in'] != null || d['complete'] == true).length;
    }
    return 0;
  }

  int get totalCompleteDays {
    final raw = _safeInt(attendance['total_complete_days']);
    if (raw > 0) return raw;
    if (days.isNotEmpty) {
      return days.where((d) => d['complete'] == true).length;
    }
    return 0;
  }

  int get totalSundayDays {
    final raw = _safeInt(attendance['total_sunday_days']);
    if (raw > 0) return raw;
    if (days.isNotEmpty) {
      return days.where((d) => d['day_type'] == 'Sunday' || d['is_sunday'] == true).length;
    }
    return 0;
  }

  int get totalHolidayDays {
    final raw = _safeInt(attendance['total_holiday_days']);
    if (raw > 0) return raw;
    if (days.isNotEmpty) {
      return days.where((d) => d['day_type'] == 'Holiday' || d['is_holiday'] == true).length;
    }
    return 0;
  }

  String get totalRegular => formatted['total_regular'] ?? '--';
  String get totalOvertime => formatted['total_overtime'] ?? '--';
  String get totalWeekdayOt => formatted['total_weekday_ot'] ?? '--';
  String get totalSundayOt => formatted['total_sunday_ot'] ?? '--';
  String get totalDoubleOt => formatted['total_double_ot'] ?? '--';

  int get totalRegularMinutes => _safeInt(minutes['total_regular_minutes']);
  int get totalOvertimeMinutes => _safeInt(minutes['total_overtime_minutes']);
  int get totalWeekdayOtMinutes => _safeInt(minutes['total_weekday_ot_minutes']);
  int get totalSundayOtMinutes => _safeInt(minutes['total_sunday_ot_minutes']);
  int get totalDoubleOtMinutes => _safeInt(minutes['total_double_ot_minutes']);

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
}
