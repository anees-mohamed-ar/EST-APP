import 'package:get/get.dart';
import '../services/api_service.dart';

class Holiday {
  final DateTime date;
  final String name;

  Holiday({required this.date, required this.name});

  factory Holiday.fromJson(Map<String, dynamic> json) {
    return Holiday(date: DateTime.parse(json['date']), name: json['name']);
  }
}

class LeaveCalendarController extends GetxController {
  // Observable state
  final Rx<DateTime> focusedMonth = DateTime.now().obs;
  final Rx<DateTime?> rangeStart = Rx<DateTime?>(null);
  final Rx<DateTime?> rangeEnd = Rx<DateTime?>(null);
  final RxList<Holiday> holidays = <Holiday>[].obs;
  final RxSet<String> approvedLeaveDays = <String>{}.obs;
  final RxBool isLoadingHolidays = false.obs;
  final RxString errorMessage = ''.obs;
  final RxBool isHalfDayMode = false.obs;
  final RxSet<String> presentDays = <String>{}.obs;
  int? userId;

  // Computed: selected date range as list
  List<DateTime> get selectedRange {
    if (rangeStart.value == null) return [];
    if (rangeEnd.value == null) return [rangeStart.value!];
    final List<DateTime> days = [];
    DateTime current = rangeStart.value!;
    while (!current.isAfter(rangeEnd.value!)) {
      days.add(current);
      current = current.add(const Duration(days: 1));
    }
    return days;
  }

  // Total working days selected (excluding Sundays and holidays)
  // Applies sandwich rule: if there are working days in selection,
  // count ALL days (including Sundays/holidays) between rangeStart and rangeEnd,
  // but do NOT count Sundays/holidays if they are exactly the start or end day.
  int get totalWorkingDays {
    if (rangeStart.value == null) return 0;
    if (rangeEnd.value == null) return 1;

    // Get all working days in the selected range
    final workingDays = selectedRange
        .where((d) => !isSunday(d) && !isHoliday(d))
        .toList();

    if (workingDays.isEmpty) return 0;

    final start = rangeStart.value!;
    final end = rangeEnd.value!;

    bool isEndpoint(DateTime d) => _isSameDay(d, start) || _isSameDay(d, end);

    int count = 0;
    for (final d in selectedRange) {
      final isNonWorking = isSunday(d) || isHoliday(d);

      // Sandwich days: count non-working only when it's strictly inside the range.
      if (isNonWorking && isEndpoint(d)) continue;

      count++;
    }

    return count;
  }

  bool isSunday(DateTime date) => date.weekday == DateTime.sunday;

  bool isHoliday(DateTime date) {
    return holidays.any(
      (h) =>
          h.date.year == date.year &&
          h.date.month == date.month &&
          h.date.day == date.day,
    );
  }

  String _dayKey(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '${d.year}-$mm-$dd';
  }

  bool isApprovedLeave(DateTime date) =>
      approvedLeaveDays.contains(_dayKey(date));

  bool isPresent(DateTime date) =>
      presentDays.contains(_dayKey(date));

  Holiday? getHoliday(DateTime date) {
    try {
      return holidays.firstWhere(
        (h) =>
            h.date.year == date.year &&
            h.date.month == date.month &&
            h.date.day == date.day,
      );
    } catch (_) {
      return null;
    }
  }

  bool isInRange(DateTime date) {
    if (rangeStart.value == null || rangeEnd.value == null) return false;
    return date.isAfter(rangeStart.value!) && date.isBefore(rangeEnd.value!);
  }

  bool isRangeStart(DateTime date) {
    if (rangeStart.value == null) return false;
    return _isSameDay(date, rangeStart.value!);
  }

  bool isRangeEnd(DateTime date) {
    if (rangeEnd.value == null) return false;
    return _isSameDay(date, rangeEnd.value!);
  }

  bool isToday(DateTime date) => _isSameDay(date, DateTime.now());

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  void onDayTapped(DateTime date) {
    // Allow selecting past dates (e.g. to cover previous absences)
    // BUT only for the CURRENT MONTH (payroll constraint)
    final now = DateTime.now();
    final firstDayOfCurrentMonth = DateTime(now.year, now.month, 1);
    final normalizedDate = DateTime(date.year, date.month, date.day);
    
    if (normalizedDate.isBefore(firstDayOfCurrentMonth)) {
      errorMessage.value = 'Leave cannot be applied for previous months as payroll is already processed.';
      return;
    }

    // Don't allow selecting already-approved leave dates
    if (isApprovedLeave(normalizedDate)) {
      errorMessage.value = 'That day is already approved as leave.';
      return;
    }

    // Don't allow selecting Sundays or Holidays
    if (isSunday(normalizedDate)) {
      errorMessage.value = 'Sundays are already weekly offs.';
      return;
    }
    if (isHoliday(normalizedDate)) {
      errorMessage.value = 'That day is a public holiday.';
      return;
    }

    // Don't allow selecting days that already have attendance entries (except today)
    if (isPresent(normalizedDate) && !isToday(normalizedDate)) {
      errorMessage.value = 'You were present on this day. Leave can only be applied for absences.';
      return;
    }

    // If Half-Day mode is on, we only allow selecting a single day
    if (isHalfDayMode.value) {
      rangeStart.value = normalizedDate;
      rangeEnd.value = normalizedDate;
      errorMessage.value = '';
      return;
    }

    if (rangeStart.value == null || rangeEnd.value != null) {
      // Start new selection
      rangeStart.value = normalizedDate;
      rangeEnd.value = null;
      errorMessage.value = '';
    } else {
      // Set end date
      if (normalizedDate.isBefore(rangeStart.value!)) {
        final oldStart = rangeStart.value!;

        // Proposed range: normalizedDate .. oldStart
        final tmpStart = normalizedDate;
        final tmpEnd = oldStart;
        final containsBlocked = _rangeContainsApprovedDays(tmpStart, tmpEnd);
        if (containsBlocked) {
          errorMessage.value =
              'Your selected range includes an already-approved leave day. Please choose a different range.';
          return;
        }

        rangeEnd.value = oldStart;
        rangeStart.value = normalizedDate;
        errorMessage.value = '';
      } else if (_isSameDay(normalizedDate, rangeStart.value!)) {
        // Same-day selection => 1-day full leave range
        rangeEnd.value = rangeStart.value;
        errorMessage.value = '';
      } else {
        // Proposed range: rangeStart .. normalizedDate
        final tmpStart = rangeStart.value!;
        final tmpEnd = normalizedDate;
        final containsBlocked = _rangeContainsApprovedDays(tmpStart, tmpEnd);
        if (containsBlocked) {
          errorMessage.value =
              'Your selected range includes an already-approved leave day. Please choose a different range.';
          return;
        }

        rangeEnd.value = normalizedDate;
        errorMessage.value = '';
      }
    }
  }

  bool _rangeContainsApprovedDays(DateTime start, DateTime end) {
    DateTime cur = DateTime(start.year, start.month, start.day);
    final last = DateTime(end.year, end.month, end.day);
    while (!cur.isAfter(last)) {
      if (isApprovedLeave(cur)) return true;
      cur = cur.add(const Duration(days: 1));
    }
    return false;
  }

  void goToPreviousMonth() {
    focusedMonth.value = DateTime(
      focusedMonth.value.year,
      focusedMonth.value.month - 1,
    );
    _onMonthChanged();
  }

  void goToNextMonth() {
    focusedMonth.value = DateTime(
      focusedMonth.value.year,
      focusedMonth.value.month + 1,
    );
    _onMonthChanged();
  }

  void _onMonthChanged() {
    fetchHolidays(focusedMonth.value.year);
    if (userId != null) {
      fetchApprovedLeaveDays(userId!);
      fetchPresentDays(userId!, focusedMonth.value);
    }
  }

  void clearSelection() {
    rangeStart.value = null;
    rangeEnd.value = null;
  }

  /// Call this to load holidays from your API
  Future<void> fetchHolidays(int year) async {
    isLoadingHolidays.value = true;
    errorMessage.value = '';
    try {
      // Fetch holidays for all months of the year
      final List<Holiday> allHolidays = [];

      for (int month = 1; month <= 12; month++) {
        final monthStr = '$year-${month.toString().padLeft(2, '0')}';
        final data = await ApiService.getLeaveCalendar(monthStr);
        final blocked = data['blockedDays'] as List<dynamic>? ?? [];

        for (final b in blocked) {
          final dateStr = b['date'] as String;
          final name = b['name'] as String;
          allHolidays.add(Holiday(date: DateTime.parse(dateStr), name: name));
        }
      }

      holidays.value = allHolidays;
    } catch (e) {
      errorMessage.value = 'Failed to load holidays. Please try again.';
    } finally {
      isLoadingHolidays.value = false;
    }
  }

  /// Loads already approved leave dates for the user and expands them to day-level
  /// so the calendar can block selecting them.
  Future<void> fetchApprovedLeaveDays(int userId) async {
    try {
      final reqs = await ApiService.getMyLeaveRequests(userId);
      final Set<String> blocked = <String>{};

      for (final r in reqs) {
        final status = (r['status'] ?? '').toString();
        if (status != 'approved') continue;

        final fromRaw = r['from_date'];
        final toRaw = r['to_date'];
        if (fromRaw == null || toRaw == null) continue;

        final fromStr = fromRaw.toString().substring(0, 10);
        final toStr = toRaw.toString().substring(0, 10);
        final from = DateTime.tryParse(fromStr);
        final to = DateTime.tryParse(toStr);
        if (from == null || to == null) continue;

        DateTime cur = DateTime(from.year, from.month, from.day);
        final last = DateTime(to.year, to.month, to.day);
        while (!cur.isAfter(last)) {
          blocked.add(_dayKey(cur));
          cur = cur.add(const Duration(days: 1));
        }
      }

      approvedLeaveDays
        ..clear()
        ..addAll(blocked);
    } catch (_) {
      // Do not block calendar usage if this fails.
    }
  }

  /// Fetches attendance records for the month to identify present days
  Future<void> fetchPresentDays(int userId, DateTime month) async {
    try {
      final startOfMonth = DateTime(month.year, month.month, 1);
      final endOfMonth = DateTime(month.year, month.month + 1, 0);

      final data = await ApiService.getMonthlyAttendance(
        userId,
        startDate: startOfMonth,
        endDate: endOfMonth,
      );

      final breakdown = data['daily_breakdown'] as List<dynamic>? ?? [];
      final Set<String> days = breakdown.map((b) => b['date'].toString()).toSet();

      presentDays
        ..clear()
        ..addAll(days);
    } catch (_) {
      // Fail silently
    }
  }

  @override
  void onInit() {
    super.onInit();
    fetchHolidays(DateTime.now().year);
  }
}
