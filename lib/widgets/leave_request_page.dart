import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/leave_calendar_controller.dart';
import 'leave_calendar_widget.dart';

/// Example Leave Request Page showing how to use LeaveCalendarWidget
class LeaveRequestPage extends StatelessWidget {
  LeaveRequestPage({super.key});

  // Register the controller — use Get.put or Get.find if already registered
  final LeaveCalendarController _calendarController =
      Get.put(LeaveCalendarController());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F3FF),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Apply for Leave',
          style: TextStyle(
            color: Color(0xFF2D2D2D),
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              color: Color(0xFF2D2D2D), size: 18),
          onPressed: () => Get.back(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Leave type selector (your own UI)
            _LeaveTypeDropdown(),
            const SizedBox(height: 20),

            // ── The Calendar Component ──
            const Text(
              'Select Leave Dates',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Color(0xFF2D2D2D),
              ),
            ),
            const SizedBox(height: 10),
            LeaveCalendarWidget(
              controller: _calendarController,
              onRangeConfirmed: (start, end, workingDays) {
                // Handle the confirmed selection
                // You can store this in your leave request controller
                Get.snackbar(
                  'Date Range Selected',
                  'From ${_formatDate(start)} to ${_formatDate(end)} — $workingDays working day(s)',
                  backgroundColor: const Color(0xFF4F7AFF),
                  colorText: Colors.white,
                  snackPosition: SnackPosition.BOTTOM,
                  margin: const EdgeInsets.all(16),
                  borderRadius: 12,
                );
              },
            ),
            const SizedBox(height: 20),

            // Reason field
            _ReasonField(),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }
}

class _LeaveTypeDropdown extends StatefulWidget {
  @override
  State<_LeaveTypeDropdown> createState() => _LeaveTypeDropdownState();
}

class _LeaveTypeDropdownState extends State<_LeaveTypeDropdown> {
  String _selected = 'Casual Leave';

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selected,
          isExpanded: true,
          icon: const Icon(Icons.expand_more, color: Color(0xFF4F7AFF)),
          items: ['Casual Leave', 'Sick Leave', 'Earned Leave', 'LOP']
              .map((e) => DropdownMenuItem(value: e, child: Text(e)))
              .toList(),
          onChanged: (v) => setState(() => _selected = v!),
          style: const TextStyle(
            color: Color(0xFF2D2D2D),
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _ReasonField extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        maxLines: 4,
        decoration: InputDecoration(
          hintText: 'Reason for leave (optional)',
          hintStyle: const TextStyle(color: Color(0xFFBBBBBB), fontSize: 14),
          contentPadding: const EdgeInsets.all(16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.white,
        ),
      ),
    );
  }
}
