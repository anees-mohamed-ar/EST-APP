import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../controllers/leave_calendar_controller.dart';

/// Full-page leave range calendar widget.
///
/// Designed for all-age accessibility: enlarged day cells (56px tall),
/// clear visual states, smooth transitions, readable typography.
///
/// Usage:
/// ```dart
/// LeaveCalendarWidget(
///   controller: Get.put(LeaveCalendarController()),
///   onRangeConfirmed: (start, end, workingDays) { ... },
/// )
/// ```
class LeaveCalendarWidget extends StatelessWidget {
  final LeaveCalendarController controller;
  final void Function(DateTime start, DateTime end, int workingDays)?
  onRangeConfirmed;

  const LeaveCalendarWidget({
    super.key,
    required this.controller,
    this.onRangeConfirmed,
  });

  // ── Palette ───────────────────────────────────────────────────────────────
  static const Color _black = Color(0xFF111111);
  static const Color _charcoal = Color(0xFF2C2C2C);
  static const Color _darkGray = Color(0xFF4A4A4A);
  static const Color _mediumGray = Color(0xFF888888);
  static const Color _lightGray = Color(0xFFD8D8D8);
  static const Color _softGray = Color(0xFFF0F0F0);
  static const Color _offWhite = Color(0xFFF7F7F7);
  static const Color _pureWhite = Color(0xFFFFFFFF);
  static const Color _rangeBlue = Color(0xFFE8F0FE); // in-range strip tint
  static const Color _sundayRed = Color(0xFFD32F2F);
  static const Color _holidayAmber = Color(0xFFE65100);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _offWhite,
      body: SafeArea(
        child: Obx(
          () => Column(
            children: [
              // ── Top nav header ─────────────────────────────────────────
              _Header(controller: controller),

              // ── Instruction hint ───────────────────────────────────────
              _InstructionBanner(controller: controller),

              // ── Weekday row ────────────────────────────────────────────
              const _WeekdayLabels(),

              // ── Divider ────────────────────────────────────────────────
              const Divider(height: 1, thickness: 1, color: Color(0xFFEEEEEE)),

              // ── Calendar grid ──────────────────────────────────────────
              Expanded(
                child: controller.isLoadingHolidays.value
                    ? const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Color(0xFF111111),
                            ),
                            SizedBox(height: 16),
                            Text(
                              'Loading holidays…',
                              style: TextStyle(
                                fontSize: 14,
                                color: Color(0xFF888888),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      )
                    : _CalendarGrid(controller: controller),
              ),

              // ── Error message ──────────────────────────────────────────
              if (controller.errorMessage.value.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 6,
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 16,
                        color: Color(0xFFC62828),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          controller.errorMessage.value,
                          style: const TextStyle(
                            color: Color(0xFFC62828),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // ── Legend ─────────────────────────────────────────────────
              const _Legend(),

              // ── Bottom summary + confirm ────────────────────────────────
              _SelectionSummary(
                controller: controller,
                onConfirmed: onRangeConfirmed,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Header ──────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final LeaveCalendarController controller;
  const _Header({required this.controller});

  static const List<String> _monthNames = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final month = controller.focusedMonth.value;
      return Container(
        color: const Color(0xFF111111),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
        child: Row(
          children: [
            // ── Close / back button ──────────────────────────────────────
            _HeaderIconBtn(
              icon: Icons.close_rounded,
              tooltip: 'Close',
              onTap: () => Navigator.of(context).maybePop(),
            ),

            const Spacer(),

            // ── Month + year ─────────────────────────────────────────────
            Column(
              children: [
                Text(
                  _monthNames[month.month - 1],
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${month.year}',
                  style: const TextStyle(
                    color: Color(0xFF888888),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),

            const Spacer(),

            // ── Prev / Next ──────────────────────────────────────────────
            Row(
              children: [
                _HeaderIconBtn(
                  icon: Icons.chevron_left_rounded,
                  tooltip: 'Previous month',
                  onTap: () {
                    HapticFeedback.lightImpact();
                    controller.goToPreviousMonth();
                    controller.fetchHolidays(
                      controller.focusedMonth.value.year,
                    );
                  },
                ),
                const SizedBox(width: 8),
                _HeaderIconBtn(
                  icon: Icons.chevron_right_rounded,
                  tooltip: 'Next month',
                  onTap: () {
                    HapticFeedback.lightImpact();
                    controller.goToNextMonth();
                    controller.fetchHolidays(
                      controller.focusedMonth.value.year,
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      );
    });
  }
}

class _HeaderIconBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  const _HeaderIconBtn({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.10),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}

// ─── Instruction Banner ───────────────────────────────────────────────────────

class _InstructionBanner extends StatelessWidget {
  final LeaveCalendarController controller;
  const _InstructionBanner({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final start = controller.rangeStart.value;
      final end = controller.rangeEnd.value;

      String hint;
      IconData hintIcon;

      if (controller.isHalfDayMode.value) {
        if (start == null) {
          hint = 'Tap a date for your half-day leave';
          hintIcon = Icons.touch_app_rounded;
        } else {
          hint = 'Half-day selected — confirm below or tap to change';
          hintIcon = Icons.check_circle_outline_rounded;
        }
      } else {
        if (start == null) {
          hint = 'Tap a date to set your leave start';
          hintIcon = Icons.touch_app_rounded;
        } else if (end == null) {
          hint = 'Tap another date to set the end — or tap same day for 1 day';
          hintIcon = Icons.swipe_right_alt_rounded;
        } else {
          hint = 'Dates selected — confirm below or tap to change';
          hintIcon = Icons.check_circle_outline_rounded;
        }
      }

      return AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: Container(
          key: ValueKey(hint),
          width: double.infinity,
          color: const Color(0xFF111111),
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Row(
            children: [
              Icon(hintIcon, size: 16, color: const Color(0xFF888888)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  hint,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF888888),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }
}

// ─── Weekday Labels ───────────────────────────────────────────────────────────

class _WeekdayLabels extends StatelessWidget {
  const _WeekdayLabels();

  static const List<String> _days = [
    'SUN',
    'MON',
    'TUE',
    'WED',
    'THU',
    'FRI',
    'SAT',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: Row(
        children: List.generate(7, (i) {
          final isSun = i == 0;
          return Expanded(
            child: Center(
              child: Text(
                _days[i],
                style: TextStyle(
                  color: isSun
                      ? const Color(0xFFD32F2F)
                      : const Color(0xFF888888),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ─── Calendar Grid ────────────────────────────────────────────────────────────

class _CalendarGrid extends StatelessWidget {
  final LeaveCalendarController controller;
  const _CalendarGrid({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final month = controller.focusedMonth.value;
      final firstDay = DateTime(month.year, month.month, 1);
      final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
      final startOffset = firstDay.weekday == 7 ? 0 : firstDay.weekday;
      final totalCells = startOffset + daysInMonth;
      final rows = (totalCells / 7).ceil();

      return Container(
        color: Colors.white,
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Fill all available height evenly across rows
            final cellHeight = (constraints.maxHeight / rows).clamp(56.0, 80.0);
            return Column(
              children: List.generate(rows, (row) {
                return SizedBox(
                  height: cellHeight,
                  child: Row(
                    children: List.generate(7, (col) {
                      final cellIndex = row * 7 + col;
                      final dayNum = cellIndex - startOffset + 1;

                      if (dayNum < 1 || dayNum > daysInMonth) {
                        return Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: const Color(0xFFEEEEEE),
                                  width: row < rows - 1 ? 1 : 0,
                                ),
                                right: BorderSide(
                                  color: const Color(0xFFEEEEEE),
                                  width: col < 6 ? 0.5 : 0,
                                ),
                              ),
                            ),
                          ),
                        );
                      }

                      final date = DateTime(month.year, month.month, dayNum);
                      return Expanded(
                        child: _DayCell(
                          date: date,
                          controller: controller,
                          isLastRow: row == rows - 1,
                          isLastCol: col == 6,
                        ),
                      );
                    }),
                  ),
                );
              }),
            );
          },
        ),
      );
    });
  }
}

// ─── Day Cell ─────────────────────────────────────────────────────────────────

class _DayCell extends StatelessWidget {
  final DateTime date;
  final LeaveCalendarController controller;
  final bool isLastRow;
  final bool isLastCol;

  const _DayCell({
    required this.date,
    required this.controller,
    required this.isLastRow,
    required this.isLastCol,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final isSun = controller.isSunday(date);
      final isHol = controller.isHoliday(date);
      final isApproved = controller.isApprovedLeave(date);
      final isStart = controller.isRangeStart(date);
      final isEnd = controller.isRangeEnd(date);
      final inRange = controller.isInRange(date);
      final isToday = controller.isToday(date);
      final holiday = controller.getHoliday(date);

      final today = DateTime.now();
      final normalizedToday = DateTime(today.year, today.month, today.day);
      final isPast = date.isBefore(normalizedToday);

      final bool isSelected = isStart || isEnd;
      final bool hasEnd = controller.rangeEnd.value != null;
      final bool hasBothEnds = hasEnd;

      final bool isBlocked = isPast || isApproved || isSun || isHol;

      // ── Determine text colour ───────────────────────────────────────
      Color textColor;
      if (isSelected) {
        textColor = Colors.white;
      } else if (isApproved) {
        textColor = const Color(0xFFB0B0B0);
      } else if (isPast) {
        textColor = const Color(0xFFCCCCCC);
      } else if (isSun) {
        textColor = const Color(0xFFD32F2F);
      } else if (isHol) {
        textColor = const Color(0xFFE65100);
      } else {
        textColor = const Color(0xFF111111);
      }

      // ── Range strip colours ─────────────────────────────────────────
      final bool showRightStrip = isStart && hasBothEnds;
      final bool showLeftStrip = isEnd && hasBothEnds;

      return Semantics(
        label: _semanticLabel(
          date: date,
          isPast: isPast,
          isApproved: isApproved,
          isHol: isHol,
          isSun: isSun,
          isStart: isStart,
          isEnd: isEnd,
          inRange: inRange,
          holiday: holiday,
        ),
        button: !isBlocked,
        child: GestureDetector(
          onTap: isBlocked
              ? null
              : () {
                  HapticFeedback.selectionClick();
                  controller.onDayTapped(date);
                },
          child: Stack(
            children: [
              // ── Cell border ───────────────────────────────────────────
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: const Color(0xFFEEEEEE),
                        width: isLastRow ? 0 : 1,
                      ),
                      right: BorderSide(
                        color: const Color(0xFFEEEEEE),
                        width: isLastCol ? 0 : 0.5,
                      ),
                    ),
                  ),
                ),
              ),

              // ── In-range full strip ───────────────────────────────────
              if (inRange)
                Positioned.fill(
                  child: Container(color: const Color(0xFFE8F0FE)),
                ),

              // ── Start-cap: right half strip ───────────────────────────
              if (showRightStrip)
                Positioned(
                  right: 0,
                  top: 8,
                  bottom: 8,
                  left: 20,
                  child: Container(color: const Color(0xFFE8F0FE)),
                ),

              // ── End-cap: left half strip ──────────────────────────────
              if (showLeftStrip)
                Positioned(
                  left: 0,
                  top: 8,
                  bottom: 8,
                  right: 20,
                  child: Container(color: const Color(0xFFE8F0FE)),
                ),

              // ── Selected circle ───────────────────────────────────────
              if (isSelected)
                Center(
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                      color: Color(0xFF111111),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),

              // ── Approved leave overlay (blocked) ──────────────────────
              if (isApproved && !isSelected)
                Center(
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F0F0),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFFD8D8D8),
                        width: 1,
                      ),
                    ),
                  ),
                ),

              // ── Today ring ────────────────────────────────────────────
              if (isToday && !isSelected)
                Center(
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF111111),
                        width: 1.5,
                      ),
                    ),
                  ),
                ),

              // ── Day number + indicators ───────────────────────────────
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${date.day}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: isSelected
                            ? FontWeight.w800
                            : FontWeight.w500,
                        color: textColor,
                        height: 1,
                      ),
                    ),

                    const SizedBox(height: 3),

                    // Dot indicators row
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isToday && !isSelected)
                          _dot(const Color(0xFF111111)),
                        if (isApproved && !isSelected) ...[
                          if (isToday && !isSelected) const SizedBox(width: 3),
                          _dot(const Color(0xFFB0B0B0)),
                        ],
                        if (isHol && !isSelected) ...[
                          if (isToday && !isSelected) const SizedBox(width: 3),
                          _dot(const Color(0xFFE65100)),
                        ],
                        if (isSun && !isHol && !isSelected)
                          _dot(const Color(0xFFD32F2F)),
                      ],
                    ),
                  ],
                ),
              ),

              // ── Small lock glyph for approved leave ───────────────────
              if (isApproved && !isSelected)
                const Positioned(
                  right: 10,
                  top: 10,
                  child: Icon(
                    Icons.lock_rounded,
                    size: 14,
                    color: Color(0xFFB0B0B0),
                  ),
                ),
            ],
          ),
        ),
      );

      // Tooltip for holiday name
    });
  }

  Widget _dot(Color color) => Container(
    width: 5,
    height: 5,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );

  String _semanticLabel({
    required DateTime date,
    required bool isPast,
    required bool isApproved,
    required bool isHol,
    required bool isSun,
    required bool isStart,
    required bool isEnd,
    required bool inRange,
    required dynamic holiday,
  }) {
    final parts = <String>[];
    parts.add('${date.day} ${_monthName(date.month)} ${date.year}');
    if (isPast) parts.add('past date, not selectable');
    if (isApproved) parts.add('already approved leave, not selectable');
    if (isSun) parts.add('Sunday');
    if (isHol && holiday != null) parts.add('Holiday: ${holiday.name}');
    if (isStart) parts.add('selected as start');
    if (isEnd) parts.add('selected as end');
    if (inRange) parts.add('in selected range');
    return parts.join(', ');
  }

  String _monthName(int m) {
    const names = [
      '',
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return names[m];
  }
}

// ─── Legend ───────────────────────────────────────────────────────────────────

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 20,
        runSpacing: 8,
        children: const [
          _LegendItem(
            color: Color(0xFF111111),
            label: 'Selected',
            filled: true,
          ),
          _LegendItem(
            color: Color(0xFFB0B0B0),
            label: 'Approved',
            filled: true,
          ),
          _LegendItem(color: Color(0xFFD32F2F), label: 'Sunday'),
          _LegendItem(color: Color(0xFFE65100), label: 'Holiday'),
          _LegendItem(color: Color(0xFFE8F0FE), label: 'Range', filled: true),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final bool filled;
  const _LegendItem({
    required this.color,
    required this.label,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: filled ? color : Colors.transparent,
            shape: BoxShape.circle,
            border: filled ? null : Border.all(color: color, width: 2),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF888888),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

// ─── Selection Summary + Confirm ─────────────────────────────────────────────

class _SelectionSummary extends StatelessWidget {
  final LeaveCalendarController controller;
  final void Function(DateTime, DateTime, int)? onConfirmed;

  const _SelectionSummary({required this.controller, this.onConfirmed});

  String _formatDate(DateTime? d) {
    if (d == null) return '—';
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${d.day} ${months[d.month - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final start = controller.rangeStart.value;
      final end = controller.rangeEnd.value;
      final workingDays = controller.totalWorkingDays;
      final hasSelection = start != null;

      return Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFEEEEEE), width: 1)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Summary Row ──────────────────────────────────────────────
            Row(
              children: [
                // From
                Expanded(
                  child: _SummaryBox(
                    label: 'From',
                    value: _formatDate(start),
                    icon: Icons.arrow_circle_right_outlined,
                    isSet: start != null,
                  ),
                ),
                // Arrow
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(
                    Icons.arrow_forward_rounded,
                    size: 18,
                    color: hasSelection
                        ? const Color(0xFF111111)
                        : const Color(0xFFD8D8D8),
                  ),
                ),
                // To
                Expanded(
                  child: _SummaryBox(
                    label: 'To',
                    value: _formatDate(end ?? start),
                    icon: Icons.arrow_circle_left_outlined,
                    isSet: start != null,
                  ),
                ),
                // Divider
                Container(
                  width: 1,
                  height: 44,
                  color: const Color(0xFFEEEEEE),
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                ),
                // Days count
                Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Text(
                      'DAYS',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF888888),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      start == null ? '—' : '$workingDays',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF111111),
                        height: 1,
                        letterSpacing: -1,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 16),

            // ── Buttons ──────────────────────────────────────────────────
            Row(
              children: [
                // Clear
                SizedBox(
                  width: 80,
                  child: OutlinedButton(
                    onPressed: hasSelection ? controller.clearSelection : null,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: const BorderSide(
                        color: Color(0xFFD8D8D8),
                        width: 1.5,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      disabledForegroundColor: const Color(0xFFD8D8D8),
                    ),
                    child: const Text(
                      'Clear',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF888888),
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 12),

                // Confirm
                Expanded(
                  child: ElevatedButton(
                    onPressed: hasSelection
                        ? () {
                            HapticFeedback.mediumImpact();
                            onConfirmed?.call(
                              start!,
                              end ?? start,
                              workingDays,
                            );
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF111111),
                      disabledBackgroundColor: const Color(0xFFF0F0F0),
                      disabledForegroundColor: const Color(0xFFD8D8D8),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      hasSelection
                          ? 'Confirm $workingDays day${workingDays != 1 ? 's' : ''}'
                          : 'Select dates first',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    });
  }
}

class _SummaryBox extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final bool isSet;

  const _SummaryBox({
    required this.label,
    required this.value,
    required this.icon,
    required this.isSet,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isSet ? const Color(0xFFF7F7F7) : const Color(0xFFF7F7F7),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isSet ? const Color(0xFFD8D8D8) : const Color(0xFFEEEEEE),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF888888),
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              color: isSet ? const Color(0xFF111111) : const Color(0xFFD8D8D8),
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
