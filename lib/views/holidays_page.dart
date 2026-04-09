import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import '../services/api_service.dart';
import 'dart:math';

class HolidaysPage extends StatefulWidget {
  const HolidaysPage({Key? key}) : super(key: key);

  @override
  _HolidaysPageState createState() => _HolidaysPageState();
}

class _HolidaysPageState extends State<HolidaysPage> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  List<dynamic> _holidays = [];
  bool _isLoading = true;

  static const Color _pureWhite = Color(0xFFFFFFFF);
  static const Color _offWhite = Color(0xFFF8F8F8);
  static const Color _lightGray = Color(0xFFEEEEEE);
  static const Color _mediumGray = Color(0xFF9E9E9E);
  static const Color _charcoal = Color(0xFF2C2C2C);
  static const Color _pureBlack = Color(0xFF000000);
  static const Color _softRed = Color(0xFFD32F2F);

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _fetchHolidays();
  }

  Future<void> _fetchHolidays() async {
    setState(() => _isLoading = true);
    try {
      final holidays = await ApiService.getHolidays();
      if (mounted) setState(() { _holidays = holidays; _isLoading = false; });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        Get.snackbar('Error', 'Failed to load holidays: $e',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: _softRed, colorText: _pureWhite);
      }
    }
  }

  bool _isHoliday(DateTime day) =>
      _holidays.any((h) => isSameDay(DateTime.parse(h['date']), day));

  List<dynamic> _getHolidaysForMonth(DateTime month) {
    return _holidays.where((h) {
      final d = DateTime.parse(h['date']);
      return d.month == month.month && d.year == month.year;
    }).toList()..sort((a, b) => a['date'].compareTo(b['date']));
  }

  // Returns the next upcoming holiday from today
  Map<String, dynamic>? _getNextHoliday() {
    final now = DateTime.now();
    final upcoming = _holidays
        .where((h) => DateTime.parse(h['date']).isAfter(now))
        .toList()
      ..sort((a, b) => a['date'].compareTo(b['date']));
    return upcoming.isNotEmpty ? upcoming.first : null;
  }

  // Days remaining until a date
  int _daysUntil(DateTime date) {
    final now = DateTime.now();
    return date.difference(DateTime(now.year, now.month, now.day)).inDays;
  }

  // Year progress 0.0–1.0
  double _yearProgress() {
    final now = DateTime.now();
    final start = DateTime(now.year, 1, 1);
    final end = DateTime(now.year + 1, 1, 1);
    return now.difference(start).inDays / end.difference(start).inDays;
  }

  // Remaining holidays this year
  int _remainingHolidaysThisYear() {
    final now = DateTime.now();
    return _holidays
        .where((h) => DateTime.parse(h['date']).isAfter(now) &&
            DateTime.parse(h['date']).year == now.year)
        .length;
  }

  @override
  Widget build(BuildContext context) {
    final holidaysInMonth = _getHolidaysForMonth(_focusedDay);
    final nextHoliday = _getNextHoliday();
    final yearPct = _yearProgress();

    return Scaffold(
      backgroundColor: _offWhite,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Get.back(),
                    child: Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: _pureWhite,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _lightGray),
                      ),
                      child: const Icon(Icons.arrow_back_ios_new, size: 18, color: _charcoal),
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Public Holidays',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800,
                          color: _charcoal, letterSpacing: -0.5)),
                    Text('Official non-working days',
                      style: TextStyle(fontSize: 14, color: _mediumGray, fontWeight: FontWeight.w500)),
                  ]),
                ],
              ),
            ),

            if (_isLoading)
              const Expanded(child: Center(child: CircularProgressIndicator(color: _charcoal)))
            else
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  physics: const BouncingScrollPhysics(),
                  children: [

                    // ── Year Progress Banner ──────────────────────────────
                    Container(
                      decoration: BoxDecoration(
                        color: _charcoal,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          // Circular ring
                          SizedBox(
                            width: 56, height: 56,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                CustomPaint(
                                  size: const Size(56, 56),
                                  painter: _RingPainter(progress: yearPct, color: _softRed),
                                ),
                                Text(
                                  '${(yearPct * 100).round()}%',
                                  style: const TextStyle(
                                    fontSize: 11, fontWeight: FontWeight.w800, color: _pureWhite),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              const Text('YEAR PROGRESS',
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                                    color: _mediumGray, letterSpacing: 0.5)),
                              Text(
                                '${DateTime.now().year} · Q${((DateTime.now().month - 1) ~/ 3) + 1}',
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800,
                                    color: _pureWhite)),
                              Text(
                                '${DateTime.now().difference(DateTime(DateTime.now().year, 1, 1)).inDays} of 365 days elapsed',
                                style: const TextStyle(fontSize: 12, color: _mediumGray)),
                            ]),
                          ),
                          // Remaining pill
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: _softRed,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(children: [
                              Text(
                                '${_remainingHolidaysThisYear()}',
                                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900,
                                    color: _pureWhite, height: 1)),
                              const Text('left\nthis year',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700,
                                    color: Colors.white70, letterSpacing: 0.3, height: 1.3)),
                            ]),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // ── Next Holiday Hero Card ────────────────────────────
                    if (nextHoliday != null) ...[
                      Builder(builder: (ctx) {
                        final hDate = DateTime.parse(nextHoliday['date']);
                        final days = _daysUntil(hDate);
                        // Progress: how far through the gap since the previous holiday
                        final prevHolidays = _holidays
                            .where((h) => !DateTime.parse(h['date']).isAfter(DateTime.now()))
                            .toList()..sort((a, b) => b['date'].compareTo(a['date']));
                        final lastDate = prevHolidays.isNotEmpty
                            ? DateTime.parse(prevHolidays.first['date'])
                            : DateTime(DateTime.now().year, 1, 1);
                        final totalGap = hDate.difference(lastDate).inDays;
                        final elapsed = DateTime.now().difference(lastDate).inDays;
                        final progress = (totalGap > 0 ? elapsed / totalGap : 0.0).clamp(0.0, 1.0);

                        return Container(
                          decoration: BoxDecoration(
                            color: _pureWhite,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: _lightGray),
                          ),
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              // Countdown box
                              Container(
                                width: 62, height: 70,
                                decoration: BoxDecoration(
                                  color: _softRed,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                                  Text('$days',
                                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900,
                                        color: _pureWhite, height: 1)),
                                  const Text('DAYS',
                                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700,
                                        color: Colors.white70, letterSpacing: 0.5)),
                                ]),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: _softRed.withOpacity(0.08),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Text('→  Next up',
                                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                                          color: _softRed, letterSpacing: 0.3)),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(nextHoliday['name'],
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700,
                                        color: _charcoal)),
                                  Text(DateFormat('EEEE, d MMM yyyy').format(hDate),
                                    style: const TextStyle(fontSize: 12, color: _mediumGray)),
                                  const SizedBox(height: 8),
                                  // Thin progress bar
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: progress,
                                      minHeight: 3,
                                      backgroundColor: _lightGray,
                                      valueColor: const AlwaysStoppedAnimation(_softRed),
                                    ),
                                  ),
                                ]),
                              ),
                              const SizedBox(width: 12),
                              const Icon(Icons.beach_access_rounded,
                                  size: 24, color: Color(0x33D32F2F)),
                            ],
                          ),
                        );
                      }),
                      const SizedBox(height: 12),
                    ],

                    // ── Calendar ─────────────────────────────────────────
                    Container(
                      decoration: BoxDecoration(
                        color: _pureWhite,
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(color: _lightGray),
                      ),
                      padding: const EdgeInsets.all(12),
                      child: TableCalendar(
                        firstDay: DateTime.utc(2020, 1, 1),
                        lastDay: DateTime.utc(2030, 12, 31),
                        focusedDay: _focusedDay,
                        selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                        onDaySelected: (sel, foc) =>
                            setState(() { _selectedDay = sel; _focusedDay = foc; }),
                        onPageChanged: (foc) => setState(() => _focusedDay = foc),
                        calendarStyle: CalendarStyle(
                          todayDecoration: BoxDecoration(
                              color: _charcoal.withOpacity(0.1), shape: BoxShape.circle),
                          todayTextStyle: const TextStyle(
                              color: _charcoal, fontWeight: FontWeight.bold),
                          selectedDecoration: const BoxDecoration(
                              color: _charcoal, shape: BoxShape.circle),
                          // Sunday (red) is handled by builder; we keep this for fallback
                          weekendTextStyle: const TextStyle(color: _charcoal),
                          outsideDaysVisible: false,
                        ),
                        daysOfWeekStyle: const DaysOfWeekStyle(
                          weekendStyle: TextStyle(color: _charcoal), // Reset Sat/Sun header
                        ),
                        headerStyle: const HeaderStyle(
                          formatButtonVisible: false,
                          titleCentered: true,
                          titleTextStyle: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w700, color: _charcoal),
                          leftChevronIcon: Icon(Icons.chevron_left, color: _charcoal),
                          rightChevronIcon: Icon(Icons.chevron_right, color: _charcoal),
                        ),
                        calendarBuilders: CalendarBuilders(
                          // Maintain red color for Sunday headers only
                          dowBuilder: (context, day) {
                            if (day.weekday == DateTime.sunday) {
                              return Center(
                                child: Text(
                                  DateFormat.E().format(day),
                                  style: const TextStyle(color: _softRed, fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                              );
                            }
                            return null;
                          },
                          markerBuilder: (ctx, day, _) {
                            if (_isHoliday(day)) {
                              return Positioned(
                                bottom: 1,
                                child: Container(
                                  width: 5, height: 5,
                                  decoration: const BoxDecoration(
                                      color: _softRed, shape: BoxShape.circle),
                                ),
                              );
                            }
                            return null;
                          },
                          // Highlight Sundays in red within the calendar body
                          defaultBuilder: (ctx, day, _) {
                            if (_isHoliday(day)) {
                              return Center(
                                child: Text('${day.day}',
                                  style: const TextStyle(
                                      color: _softRed, fontWeight: FontWeight.bold)),
                              );
                            }
                            if (day.weekday == DateTime.sunday) {
                              return Center(
                                child: Text('${day.day}',
                                  style: const TextStyle(color: _softRed)),
                              );
                            }
                            return null;
                          },
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ── Monthly List ──────────────────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(DateFormat('MMMM yyyy').format(_focusedDay),
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700,
                              color: _charcoal)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                              color: _softRed.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20)),
                          child: Text('${holidaysInMonth.length} Holidays',
                            style: const TextStyle(fontSize: 12,
                                fontWeight: FontWeight.bold, color: _softRed)),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    if (holidaysInMonth.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(40),
                        decoration: BoxDecoration(
                          color: _pureWhite, borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: _lightGray),
                        ),
                        child: Column(children: [
                          Icon(Icons.event_available, size: 48, color: _lightGray),
                          const SizedBox(height: 12),
                          const Text('No holidays this month',
                            style: TextStyle(color: _mediumGray, fontWeight: FontWeight.w500)),
                        ]),
                      )
                    else
                      ...holidaysInMonth.map((holiday) {
                        final hDate = DateTime.parse(holiday['date']);
                        final isToday = isSameDay(hDate, DateTime.now());
                        final isPast = hDate.isBefore(DateTime.now()) && !isToday;
                        final days = isPast ? 0 : _daysUntil(hDate);

                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: _pureWhite,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isToday ? _charcoal : _lightGray,
                              width: isToday ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              // Date block
                              Container(
                                width: 50,
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  color: isPast ? const Color(0xFFF5F5F5) : _offWhite,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(children: [
                                  Text(DateFormat('dd').format(hDate),
                                    style: TextStyle(
                                      fontSize: 20, fontWeight: FontWeight.w800,
                                      color: isPast ? _mediumGray : _charcoal,
                                    )),
                                  Text(DateFormat('EEE').format(hDate).toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 9, fontWeight: FontWeight.w800,
                                      color: isPast ? _mediumGray : _softRed,
                                      letterSpacing: 0.5,
                                    )),
                                ]),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text(holiday['name'],
                                    style: TextStyle(
                                      fontSize: 15, fontWeight: FontWeight.w600,
                                      color: isPast ? _mediumGray : _charcoal,
                                    )),
                                  const SizedBox(height: 5),
                                  if (isToday)
                                    _StatusChip(label: 'Happening today', color: _softRed)
                                  else if (isPast)
                                    _StatusChip(label: 'Completed', color: _mediumGray)
                                  else
                                    Row(children: [
                                      _StatusChip(
                                        label: days <= 7 ? '$days days to go' : '$days days to go',
                                        color: days <= 7 ? _softRed : _mediumGray,
                                        bold: days <= 7,
                                      ),
                                    ]),
                                  // Urgency bar for upcoming holidays
                                  if (!isPast && !isToday) ...[
                                    const SizedBox(height: 6),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: LinearProgressIndicator(
                                        value: days <= 30 ? (30 - days) / 30 : 0.0,
                                        minHeight: 2,
                                        backgroundColor: _lightGray,
                                        valueColor: AlwaysStoppedAnimation(
                                            days <= 7 ? _softRed : _charcoal.withOpacity(0.2)),
                                      ),
                                    ),
                                  ],
                                ]),
                              ),
                              const SizedBox(width: 8),
                              Icon(Icons.beach_access_rounded,
                                color: isPast ? _lightGray : _softRed.withOpacity(0.18),
                                size: 22),
                            ],
                          ),
                        );
                      }).toList(),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Small reusable chip ───────────────────────────────────────────────────────
class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  final bool bold;
  const _StatusChip({required this.label, required this.color, this.bold = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
          color: color,
        )),
    );
  }
}

// ── Ring painter for year progress ───────────────────────────────────────────
class _RingPainter extends CustomPainter {
  final double progress;
  final Color color;
  const _RingPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 5;
    final trackPaint = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5;
    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, trackPaint);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      2 * pi * progress,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.progress != progress;
}