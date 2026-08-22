import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:permission_handler/permission_handler.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as syncfusion;
import '../services/api_service.dart';

class PayslipPage extends StatefulWidget {
  final String username;
  final String displayName;

  const PayslipPage({
    super.key,
    required this.username,
    required this.displayName,
  });

  @override
  State<PayslipPage> createState() => _PayslipPageState();
}

class _PayslipPageState extends State<PayslipPage> {
  bool _isAuthenticated = false;
  bool _isInitLoading = true;
  String _enteredPin = '';
  String _authError = '';
  bool _useSystemKeyboard = false;
  final TextEditingController _pinController = TextEditingController();
  final FocusNode _pinFocusNode = FocusNode();

  List<Map<String, dynamic>> _months      = [];
  String?                    _selectedKey;
  Map<String, dynamic>?      _slip;
  Map<String, dynamic>?      _userFromDb;
  bool _loadingList   = true;
  bool _loadingDetail = false;
  bool _exporting     = false;

  pw.Font? _pdfFont;
  pw.Font? _pdfFontBold;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _pinController.dispose();
    _pinFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isInitLoading = true);
    await _loadFonts();
    await _fetchUserFromDb();
    await _loadMonths(initial: true);
    if (mounted) {
      setState(() => _isInitLoading = false);
    }
  }

  Future<void> _fetchUserFromDb() async {
    try {
      final user = await ApiService.getUserByUsername(widget.username);
      if (user != null && mounted) {
        setState(() {
          _userFromDb = user;
        });
      }
    } catch (e) {
      debugPrint('Error fetching user from users table: $e');
    }
  }

  Future<void> _loadFonts() async {
    try {
      final reg  = await rootBundle.load('assets/fonts/NotoSans-Regular.ttf');
      final bold = await rootBundle.load('assets/fonts/NotoSans-Bold.ttf');
      _pdfFont     = pw.Font.ttf(reg);
      _pdfFontBold = pw.Font.ttf(bold);
    } catch (e) {
      debugPrint('Font load error: $e');
    }
  }

  Future<void> _loadMonths({bool initial = false}) async {
    setState(() => _loadingList = true);
    final months = await ApiService.getPayslipList(widget.username);
    if (!mounted) return;
    setState(() {
      _months      = months;
      _loadingList = false;
      if (months.isNotEmpty) _selectedKey = months.first['month_key']?.toString();
    });
    if (_selectedKey != null) {
      await _loadDetail(_selectedKey!, initial: initial);
    }
  }

  Future<void> _loadDetail(String monthKey, {bool initial = false}) async {
    if (!initial) setState(() => _loadingDetail = true);
    _selectedKey = monthKey;
    final payslip = await ApiService.getPayslip(widget.username, monthKey);
    if (!mounted) return;
    setState(() {
      _slip = payslip;
      if (!initial) _loadingDetail = false;
    });
  }

  void _onNumpadPress(String val) {
    if (_enteredPin.length >= 15) return;
    setState(() {
      _enteredPin += val;
      _pinController.text = _enteredPin;
      _authError = '';
    });
  }

  void _onNumpadBackspace() {
    if (_enteredPin.isNotEmpty) {
      setState(() {
        _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
        _pinController.text = _enteredPin;
        _authError = '';
      });
    }
  }

  void _onNumpadClear() {
    setState(() {
      _enteredPin = '';
      _pinController.clear();
      _authError = '';
    });
  }

  void _toggleKeyboardMode() {
    setState(() {
      _useSystemKeyboard = !_useSystemKeyboard;
      _pinController.text = _enteredPin;
      _authError = '';
    });
    if (_useSystemKeyboard) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) _pinFocusNode.requestFocus();
      });
    } else {
      FocusScope.of(context).unfocus();
    }
  }

  bool _isPasscodeValid(String entered, Map<String, dynamic> slip) {
    final cleanEntered = entered.trim().toUpperCase();
    if (cleanEntered.isEmpty) return false;

    // Use users table profile as the primary source of user identity & credentials
    final user = _userFromDb ?? {};
    final rawUser = widget.username.isNotEmpty
        ? widget.username
        : (user['username'] ?? user['employee_id'] ?? slip['username'] ?? slip['employee_no'] ?? '');

    String idDigits = rawUser.toString().replaceAll(RegExp(r'^[A-Za-z]+'), '');
    if (idDigits.isEmpty) idDigits = rawUser.toString();

    String id3 = idDigits;
    if (RegExp(r'^\d+$').hasMatch(idDigits) && idDigits.length < 3) {
      id3 = idDigits.padLeft(3, '0');
    }

    final List<String> candidateYears = [];

    // 1. Fetch DOB from users table
    final dobStr = user['dob']?.toString() ?? slip['dob']?.toString();
    if (dobStr != null && dobStr.isNotEmpty && dobStr != 'null') {
      final match = RegExp(r'\b(19\d\d|20\d\d)\b').firstMatch(dobStr);
      if (match != null) candidateYears.add(match.group(1)!);
    }

    // 2. Fallback to Date of Joining from users table
    final dojStr = (user['user_doj'] ?? user['date_of_joining'] ?? slip['user_doj'] ?? slip['date_of_joining'])?.toString();
    if (dojStr != null && dojStr.isNotEmpty && dojStr != 'null') {
      final match = RegExp(r'\b(19\d\d|20\d\d)\b').firstMatch(dojStr);
      if (match != null) candidateYears.add(match.group(1)!);
    }

    candidateYears.add('2000'); // default fallback

    for (final yr in candidateYears) {
      if (cleanEntered == '$id3$yr' ||
          cleanEntered == '$idDigits$yr' ||
          cleanEntered == '${rawUser.toString().toUpperCase()}$yr') {
        return true;
      }
    }

    return false;
  }

  void _verifyPasscode() {
    if (_enteredPin.trim().isEmpty) {
      setState(() => _authError = 'Please enter your passcode');
      return;
    }

    if (_isPasscodeValid(_enteredPin, _slip ?? {})) {
      setState(() {
        _isAuthenticated = true;
        _authError = '';
      });
    } else {
      HapticFeedback.heavyImpact();
      setState(() {
        _authError = 'Incorrect passcode. Format: Employee ID (e.g. 001) + Year of Birth (e.g. 2000)';
        _enteredPin = '';
        _pinController.clear();
      });
    }
  }

  String _monthLabel(String? k) {
    if (k == null || k.isEmpty) return '';
    try {
      final p = k.split('-');
      return DateFormat('MMMM yyyy').format(DateTime(int.parse(p[0]), int.parse(p[1])));
    } catch (_) { return k; }
  }

  String _formatDate(dynamic dateVal) {
    if (dateVal == null) return '—';
    final s = dateVal.toString().trim();
    if (s.isEmpty || s == 'null' || s == '—') return '—';
    try {
      if (s.contains('-') && s.split('-')[0].length == 4) {
        final dt = DateTime.parse(s);
        return DateFormat('dd-MM-yyyy').format(dt);
      }
      return s;
    } catch (_) {
      return s;
    }
  }

  double _num(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }

  String _cur(dynamic v) {
    final n = _num(v);
    return 'Rs.${NumberFormat('#,##,##0', 'en_IN').format(n)}';
  }

  String _plain(dynamic v) {
    final n = _num(v);
    return n % 1 == 0 ? n.toInt().toString() : n.toStringAsFixed(1);
  }

  /// Builds password for PDF encryption: Employee ID part + Birth Year (from users table)
  /// Example: username 'MEPL001' & DOB year '1974' -> password '0011974'
  /// Example: username 'MEPL261' & DOB year '1986' -> password '2611986'
  String _buildPassword(Map<String, dynamic> slip) {
    final user = _userFromDb ?? {};
    final rawUser = widget.username.isNotEmpty
        ? widget.username
        : (user['username'] ?? user['employee_id'] ?? slip['username'] ?? slip['employee_no'] ?? '');

    // Extract numeric/ID portion by stripping non-digit prefix (e.g. MEPL001 -> 001, MEPL261 -> 261)
    String idPart = rawUser.toString().replaceAll(RegExp(r'^[A-Za-z]+'), '');
    if (idPart.isEmpty) idPart = rawUser.toString();

    // Pad single or double digit numbers to 3 digits if needed (e.g. 1 -> 001)
    if (RegExp(r'^\d+$').hasMatch(idPart) && idPart.length < 3) {
      idPart = idPart.padLeft(3, '0');
    }

    // Extract Birth Year directly from users table
    String birthYear = '';
    final dobStr = user['dob']?.toString() ?? slip['dob']?.toString();
    if (dobStr != null && dobStr.isNotEmpty && dobStr != 'null') {
      final match = RegExp(r'\b(19\d\d|20\d\d)\b').firstMatch(dobStr);
      if (match != null) {
        birthYear = match.group(1)!;
      }
    }

    // Fallback: If DOB not populated, check date_of_joining year from users table or default '2000'
    if (birthYear.isEmpty) {
      final dojStr = (user['user_doj'] ?? user['date_of_joining'] ?? slip['user_doj'] ?? slip['date_of_joining'])?.toString();
      if (dojStr != null && dojStr.isNotEmpty && dojStr != 'null') {
        final match = RegExp(r'\b(19\d\d|20\d\d)\b').firstMatch(dojStr);
        if (match != null) {
          birthYear = match.group(1)!;
        }
      }
    }

    if (birthYear.isEmpty) birthYear = '2000';

    return '$idPart$birthYear';
  }

  Future<Directory> _getMeplTrackDir() async {
    Directory? targetDir;

    if (Platform.isAndroid) {
      // Request storage & manageExternalStorage permissions if needed
      try {
        if (await Permission.storage.isDenied) {
          await Permission.storage.request();
        }
        if (await Permission.manageExternalStorage.isDenied) {
          await Permission.manageExternalStorage.request();
        }
      } catch (_) {}

      // 1. Try root internal storage folder: /storage/emulated/0/MEPL-Track
      try {
        final pubRoot = Directory('/storage/emulated/0/MEPL-Track');
        if (!await pubRoot.exists()) {
          await pubRoot.create(recursive: true);
        }
        targetDir = pubRoot;
      } catch (e) {
        debugPrint('Root MEPL-Track directory creation error: $e');
      }

      // 2. Try Download/MEPL-Track folder fallback
      if (targetDir == null) {
        try {
          final pubDownload = Directory('/storage/emulated/0/Download/MEPL-Track');
          if (!await pubDownload.exists()) {
            await pubDownload.create(recursive: true);
          }
          targetDir = pubDownload;
        } catch (_) {}
      }

      // 3. Try app external storage /MEPL-Track
      if (targetDir == null) {
        try {
          final ext = await getExternalStorageDirectory();
          if (ext != null) {
            final meplDir = Directory('${ext.path}/MEPL-Track');
            if (!await meplDir.exists()) {
              await meplDir.create(recursive: true);
            }
            targetDir = meplDir;
          }
        } catch (_) {}
      }
    }

    // 4. App Documents fallback (iOS or Android fallback)
    if (targetDir == null) {
      final docs = await getApplicationDocumentsDirectory();
      final meplDir = Directory('${docs.path}/MEPL-Track');
      if (!await meplDir.exists()) {
        await meplDir.create(recursive: true);
      }
      targetDir = meplDir;
    }

    return targetDir;
  }

  // ── PDF ──────────────────────────────────────────────────────────────────
  Future<void> _exportPdf() async {
    final slip = _slip;
    if (slip == null) return;
    setState(() => _exporting = true);
    try {
      if (_pdfFont == null) await _loadFonts();
      final font     = _pdfFont;
      final fontBold = _pdfFontBold;

      pw.TextStyle ts(double sz, {bool bold = false, PdfColor? color}) => pw.TextStyle(
        font: bold ? fontBold : font,
        fontSize: sz,
        color: color ?? PdfColors.black,
      );

      final pdf       = pw.Document();
      final monthName = _monthLabel(_selectedKey);

      pw.MemoryImage? logo;
      for (final p in ['assets/images/me-logo-clean.png', 'me-logo-clean.png']) {
        try { final d = await rootBundle.load(p); logo = pw.MemoryImage(d.buffer.asUint8List()); break; } catch (_) {}
      }

      // Computed values from exact DB column names
      final fixedBasic  = _num(slip['fixed_basic']);
      final fixedDa     = _num(slip['fixed_da']);
      final fixedOther  = _num(slip['other_allowance_fixed']);
      final actualBasic = _num(slip['actual_basic']);
      final actualDa    = _num(slip['actual_da']);
      final mealEarned  = _num(slip['lunch_tea_amount']);
      final actualOther = _num(slip['other_allowance']);
      final arear       = _num(slip['arear']);
      final attBonus    = _num(slip['attendance_bonus']);
      final otPay       = _num(slip['ot_amount']);
      final grossSal    = _num(slip['gross_salary']);
      final totalAll    = _num(slip['total_allowances']);
      final totalEarn   = grossSal + totalAll;
      final epf         = _num(slip['epf_deduction']);
      final esic        = _num(slip['esic_deduction']);
      final iou         = _num(slip['emp_control']);
      final lic         = _num(slip['lic_amount']);
      final pt          = _num(slip['pt_deduction']);
      final staffLoan   = _num(slip['loan_deduction']);
      final gmcIns      = _num(slip['gmc_insurance']);
      final salAdv      = _num(slip['salary_advance']);
      final totalDed    = _num(slip['total_deductions']);
      // Net Pay = Total Earnings - Total Deductions (or net_salary from DB)
      final netPay      = _num(slip['net_salary']) > 0 ? _num(slip['net_salary']) : (totalEarn - totalDed);
      final awd         = _plain(slip['awd']);
      final coff        = _plain(slip['coff']);
      final lop         = _plain(slip['actual_leave']);
      final exHrs       = _plain(slip['ex_hrs']);
      final cl          = _plain(slip['closing_cl']);
      final el          = _plain(slip['closing_el']);
      final mealDays    = _plain(slip['lunch_tea_days']);

      String amt(double v) => NumberFormat('#,##,##0', 'en_IN').format(v);

      pdf.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        build: (ctx) {
          pw.Widget cell(String t, {bool bold = false, double sz = 8.5,
              PdfColor? color, pw.TextAlign align = pw.TextAlign.left}) =>
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
              child: pw.Text(t, style: ts(sz, bold: bold, color: color), textAlign: align),
            );

          pw.Widget hCell(String t) => pw.Container(
            color: PdfColor.fromHex('#D0D0D0'),
            child: cell(t, bold: true),
          );

          pw.TableRow eRow(String e, double act, double earn, String d, double da) =>
            pw.TableRow(children: [
              cell(e), cell(amt(act), align: pw.TextAlign.right),
              cell(amt(earn), align: pw.TextAlign.right),
              cell(d), cell(amt(da), align: pw.TextAlign.right),
            ]);

          pw.TableRow dOnlyRow(String d, double da) => pw.TableRow(children: [
            cell(''), cell(''), cell(''), cell(d), cell(amt(da), align: pw.TextAlign.right),
          ]);

          pw.Widget infoLine(String lbl, String val) => pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
            child: pw.Row(children: [
              pw.SizedBox(width: 88, child: pw.Text(lbl, style: ts(8.5))),
              pw.Text(':  $val', style: ts(8.5)),
            ]),
          );

          // Company header
          final header = pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
            if (logo != null) ...[pw.Container(width: 54, height: 54, child: pw.Image(logo, fit: pw.BoxFit.contain)), pw.SizedBox(width: 10)],
            pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
              pw.Text('MENAKA ELECTRICALS PVT LTD', style: ts(14, bold: true), textAlign: pw.TextAlign.center),
              pw.SizedBox(height: 3),
              pw.Text('No.1/177 Bharathiyar Street Singaperumalkoil, Chengalpattu 603204.', style: ts(9), textAlign: pw.TextAlign.center),
            ])),
            pw.SizedBox(width: 10),
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
              pw.Text('FORM No. XXVIII', style: ts(7.5, bold: true)),
              pw.Text('[See rule 78 (1) (b)]', style: ts(7)),
            ]),
          ]);

          // Employee info table
          final empTable = pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey600, width: 0.5),
            columnWidths: const {
              0: pw.FlexColumnWidth(1),
              1: pw.FlexColumnWidth(1),
            },
            children: [pw.TableRow(children: [
              pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  infoLine('Date of Joining', _formatDate(_userFromDb?['date_of_joining'] ?? _userFromDb?['user_doj'] ?? slip['date_of_joining'] ?? slip['user_doj'])),
                  infoLine('Worked Days', awd),
                  infoLine('COFF', coff),
                  infoLine('Lop Days', lop),
                  infoLine('Overtime Pay', exHrs),
                  infoLine('CL', cl),
                  infoLine('EL', el),
                  infoLine('Meal allowance', mealDays),
                ],
              )),
              pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  infoLine('Employee name', slip['emp_name']?.toString() ?? '—'),
                  infoLine('Designation', slip['designation']?.toString() ?? '—'),
                  infoLine('Department', slip['department']?.toString() ?? '—'),
                  infoLine('Employee no', slip['employee_no']?.toString() ?? '—'),
                  infoLine('EPF No', slip['epf_no']?.toString() ?? '—'),
                  infoLine('ESIC No', slip['esic_no']?.toString() ?? '—'),
                ],
              )),
            ])],
          );

          // Main 3-section table
          final mainTable = pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey600, width: 0.5),
            columnWidths: {
              0: const pw.FlexColumnWidth(3.2),
              1: const pw.FlexColumnWidth(2.0),
              2: const pw.FlexColumnWidth(2.0),
              3: const pw.FlexColumnWidth(2.8),
              4: const pw.FlexColumnWidth(1.8),
            },
            children: [
              pw.TableRow(decoration: pw.BoxDecoration(color: PdfColor.fromHex('#D0D0D0')), children: [
                hCell('Earnings'), hCell('Actual Salary'), hCell('Earned Salary'), hCell('Deductions'), hCell(''),
              ]),
              eRow('Basic',            fixedBasic, actualBasic, 'EPF Employee',  epf),
              eRow('DA',               fixedDa,    actualDa,    'ESIC Employee', esic),
              eRow('Meal allowance',   0,          mealEarned,  'IOU',           iou),
              eRow('Other Allowance',  fixedOther, actualOther, 'LIC',           lic),
              eRow('Arear',            0,          arear,       'PT',            pt),
              eRow('Attendance Bonus', 0,          attBonus,    'Staff Loan',    staffLoan),
              eRow('Overtime Pay',     0,          otPay,       'GM Insurance',  gmcIns),
              dOnlyRow('Salary Advance', salAdv),
              pw.TableRow(decoration: pw.BoxDecoration(color: PdfColor.fromHex('#E0E0E0')), children: [
                cell('Gross Salary', bold: true), cell(''),
                cell(amt(totalEarn), bold: true, align: pw.TextAlign.right),
                cell('Total Deductions', bold: true),
                cell(amt(totalDed), bold: true, align: pw.TextAlign.right),
              ]),
              pw.TableRow(decoration: pw.BoxDecoration(color: PdfColor.fromHex('#E0E0E0')), children: [
                cell(''), cell(''),
                cell(''),
                cell('Net Pay', bold: true),
                cell(amt(netPay), bold: true, align: pw.TextAlign.right),
              ]),
            ],
          );

          final leaveTable = pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey600, width: 0.5),
            columnWidths: {
              0: const pw.FlexColumnWidth(3.2),
              1: const pw.FlexColumnWidth(2.0),
              2: const pw.FlexColumnWidth(2.0),
              3: const pw.FlexColumnWidth(2.8),
              4: const pw.FlexColumnWidth(1.8),
            },
            children: [
              pw.TableRow(children: [cell('Available CL'), cell(''), cell(_plain(slip['closing_cl'])), cell(''), cell('')]),
              pw.TableRow(children: [cell('Available EL'), cell(''), cell(_plain(slip['closing_el'])), cell(''), cell('')]),
              pw.TableRow(children: [
                cell('Closing Loan Balance'),
                cell(''),
                cell(amt(_num(slip['closing_loan_balance'] ?? slip['loan_closing']))),
                cell(''),
                cell(''),
              ]),
            ],
          );

          return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
            header,
            pw.SizedBox(height: 6),
            pw.Divider(thickness: 0.8, color: PdfColors.black),
            pw.SizedBox(height: 4),
            pw.Center(child: pw.Text('Payslip for the Month of  $monthName', style: ts(11, bold: true))),
            pw.SizedBox(height: 6),
            empTable,
            pw.SizedBox(height: 6),
            mainTable,
            leaveTable,
            pw.SizedBox(height: 14),
            pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
              pw.Text('Employee Signature', style: ts(8)),
              pw.Text('Authorised Signatory - Menaka Electricals Pvt Ltd', style: ts(8)),
            ]),
          ]);
        },
      ));

      final Uint8List rawBytes = await pdf.save();

      // Apply Password Security (Employee ID part + Birth Year, e.g. 0012000 or 2612000)
      final pdfPassword = _buildPassword(slip);
      List<int> finalBytes = rawBytes;

      try {
        final syncfusion.PdfDocument document = syncfusion.PdfDocument(inputBytes: rawBytes);
        document.security.userPassword = pdfPassword;
        document.security.ownerPassword = pdfPassword;
        finalBytes = await document.save();
        document.dispose();
      } catch (encErr) {
        debugPrint('PDF Encryption warning: $encErr');
      }

      final targetDir = await _getMeplTrackDir();
      final sMonth = (_selectedKey ?? 'payslip').replaceAll('-', '_');
      final fileName = 'Payslip_${widget.username}_$sMonth.pdf';
      final file  = File('${targetDir.path}/$fileName');
      await file.writeAsBytes(finalBytes, flush: true);

      Get.snackbar(
        'Payslip Downloaded 🔒',
        'Saved to MEPL-Track folder',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFF059669),
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
      );

      await OpenFile.open(file.path);
    } catch (e, st) {
      debugPrint('PDF error: $e\n$st');
      Get.snackbar('Export Failed', 'Could not generate PDF: $e',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.redAccent, colorText: Colors.white);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  // ── Color System (Aligned with Leave & App Theme) ─────────────────────────
  static const Color _charcoalBlack  = Color(0xFF111111);
  static const Color _darkGrey       = Color(0xFF2C2C2C);
  static const Color _subGrey        = Color(0xFF666666);
  static const Color _borderGrey     = Color(0xFFE5E7EB);
  static const Color _bgSoft         = Color(0xFFF8F9FA);
  static const Color _white          = Color(0xFFFFFFFF);

  // Leave page uniform accents
  static const Color _elBlue         = Color(0xFF1565C0); // EL (Earned Leave)
  static const Color _clTeal         = Color(0xFF00796B); // CL (Casual Leave)
  static const Color _greenEarn      = Color(0xFF2E7D32); // Earnings
  static const Color _redDed         = Color(0xFFC62828); // Deductions
  static const Color _amberAccent    = Color(0xFFE65100); // LOP / OT

  // ── UI ────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_isInitLoading) {
      return Scaffold(
        backgroundColor: _bgSoft,
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: _charcoalBlack, strokeWidth: 2.5),
              SizedBox(height: 16),
              Text(
                'Loading payroll data...',
                style: TextStyle(fontSize: 13, color: _subGrey, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      );
    }

    if (!_isAuthenticated) {
      return Scaffold(
        backgroundColor: _bgSoft,
        appBar: AppBar(
          backgroundColor: _white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: _charcoalBlack),
            onPressed: () => Get.back(),
          ),
          title: const Text(
            'Security Passcode',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _charcoalBlack),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(color: _borderGrey, height: 1),
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Column(
                    children: [
                      const SizedBox(height: 10),
                      // Lock icon card
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: _white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                          border: Border.all(color: _borderGrey),
                        ),
                        child: const Icon(Icons.lock_outline_rounded, size: 30, color: _charcoalBlack),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Enter Payroll Passcode',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _charcoalBlack),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Employee ID (e.g. 001) + Year of Birth (e.g. 2000)\nExample: 0012000',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: _subGrey, height: 1.4),
                      ),
                      const SizedBox(height: 24),

                      // PIN Code Display Indicator / Text Field
                      if (!_useSystemKeyboard)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          decoration: BoxDecoration(
                            color: _white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: _authError.isNotEmpty ? const Color(0xFFEF4444) : _borderGrey,
                              width: _authError.isNotEmpty ? 1.5 : 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.02),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_enteredPin.isEmpty)
                                const Text(
                                  '• • • • • • •',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFFD1D5DB),
                                    letterSpacing: 6,
                                  ),
                                )
                              else
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: List.generate(_enteredPin.length, (index) {
                                    return Container(
                                      margin: const EdgeInsets.symmetric(horizontal: 4),
                                      child: Text(
                                        _enteredPin[index],
                                        style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w800,
                                          color: _charcoalBlack,
                                          letterSpacing: 2,
                                        ),
                                      ),
                                    );
                                  }),
                                ),
                            ],
                          ),
                        )
                      else
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: _white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: _authError.isNotEmpty ? const Color(0xFFEF4444) : _borderGrey,
                              width: _authError.isNotEmpty ? 1.5 : 1,
                            ),
                          ),
                          child: TextField(
                            controller: _pinController,
                            focusNode: _pinFocusNode,
                            autofocus: true,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: _charcoalBlack,
                              letterSpacing: 2,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Enter passcode (letters/digits)',
                              hintStyle: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF9CA3AF),
                                letterSpacing: 0,
                                fontWeight: FontWeight.normal,
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              suffixIcon: IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: _onNumpadClear,
                              ),
                            ),
                            onChanged: (val) {
                              setState(() {
                                _enteredPin = val;
                                _authError = '';
                              });
                            },
                            onSubmitted: (_) => _verifyPasscode(),
                          ),
                        ),

                      const SizedBox(height: 12),

                      // Keyboard mode toggle button (Fallback option)
                      TextButton.icon(
                        onPressed: _toggleKeyboardMode,
                        style: TextButton.styleFrom(
                          foregroundColor: _charcoalBlack,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        ),
                        icon: Icon(
                          _useSystemKeyboard ? Icons.dialpad_rounded : Icons.keyboard_alt_outlined,
                          size: 16,
                          color: _subGrey,
                        ),
                        label: Text(
                          _useSystemKeyboard ? 'Use On-Screen Numpad' : 'Use Full Keyboard (Fallback)',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _subGrey,
                          ),
                        ),
                      ),

                      if (_authError.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEE2E2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFFCA5A5)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.error_outline_rounded, size: 15, color: Color(0xFFDC2626)),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  _authError,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 11, color: Color(0xFFDC2626), fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      if (_useSystemKeyboard) ...[
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: _enteredPin.isNotEmpty ? _verifyPasscode : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _charcoalBlack,
                              disabledBackgroundColor: const Color(0xFFE5E7EB),
                              foregroundColor: _white,
                              disabledForegroundColor: const Color(0xFF9CA3AF),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 0,
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.lock_open_rounded, size: 18),
                                SizedBox(width: 8),
                                Text(
                                  'Unlock Payroll',
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // Custom Numpad (Shown when not in system keyboard mode)
              if (!_useSystemKeyboard) _buildCustomNumpad(),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: _bgSoft,
      appBar: AppBar(
        backgroundColor: _white,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.displayName.isNotEmpty ? widget.displayName : 'My Payslip',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _charcoalBlack, letterSpacing: -0.3),
            ),
            const Text(
              'Salary & Earnings Statement',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: _subGrey),
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: _charcoalBlack),
          onPressed: () => Get.back(),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: _borderGrey, height: 1),
        ),
        actions: [
          if (_slip != null && !_loadingDetail)
            IconButton(
              icon: _exporting
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: _charcoalBlack))
                  : const Icon(Icons.download_rounded, color: _charcoalBlack),
              tooltip: 'Download PDF',
              onPressed: _exporting ? null : _exportPdf,
            ),
        ],
      ),
      body: _loadingList
          ? const Center(child: CircularProgressIndicator(color: _charcoalBlack, strokeWidth: 2.5))
          : _months.isEmpty
              ? _buildEmpty()
              : Column(
                  children: [
                    _buildMonthSelector(),
                    Expanded(
                      child: _loadingDetail
                          ? const Center(child: CircularProgressIndicator(color: _charcoalBlack, strokeWidth: 2.5))
                          : _slip == null
                              ? const Center(child: Text('Could not load payslip data.', style: TextStyle(color: _subGrey)))
                              : _buildContent(),
                    ),
                  ],
                ),
    );
  }

  // ── Custom Numpad for Passcode ───────────────────────────────────────────
  Widget _buildCustomNumpad() {
    return Container(
      padding: const EdgeInsets.fromLTRB(28, 16, 28, 24),
      decoration: const BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 20,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildNumpadKey('1'),
              _buildNumpadKey('2'),
              _buildNumpadKey('3'),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildNumpadKey('4'),
              _buildNumpadKey('5'),
              _buildNumpadKey('6'),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildNumpadKey('7'),
              _buildNumpadKey('8'),
              _buildNumpadKey('9'),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Clear key
              _buildActionKey(
                icon: Icons.clear_rounded,
                label: 'C',
                onTap: _onNumpadClear,
              ),
              _buildNumpadKey('0'),
              // Backspace key
              _buildActionKey(
                icon: Icons.backspace_outlined,
                onTap: _onNumpadBackspace,
              ),
            ],
          ),
          const SizedBox(height: 18),
          // Submit Unlock button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _enteredPin.isNotEmpty ? _verifyPasscode : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: _charcoalBlack,
                disabledBackgroundColor: const Color(0xFFE5E7EB),
                foregroundColor: _white,
                disabledForegroundColor: const Color(0xFF9CA3AF),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.lock_open_rounded, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Unlock Payroll',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNumpadKey(String value) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          _onNumpadPress(value);
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 72,
          height: 52,
          decoration: BoxDecoration(
            color: _bgSoft,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _borderGrey, width: 1),
          ),
          child: Center(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: _charcoalBlack,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionKey({IconData? icon, String? label, required VoidCallback onTap}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 72,
          height: 52,
          decoration: BoxDecoration(
            color: _bgSoft,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _borderGrey, width: 1),
          ),
          child: Center(
            child: label != null
                ? Text(
                    label,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: _charcoalBlack,
                    ),
                  )
                : Icon(icon, size: 20, color: _charcoalBlack),
          ),
        ),
      ),
    );
  }

  // ── Month Selector (Clean horizontal pill bar) ───────────────────────────
  Widget _buildMonthSelector() {
    return Container(
      color: _white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: SizedBox(
        height: 36,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: _months.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, i) {
            final m   = _months[i];
            final key = m['month_key']?.toString() ?? '';
            final sel = key == _selectedKey;
            final lbl = m['month_label']?.toString() ?? _monthLabel(key);
            return GestureDetector(
              onTap: () => _loadDetail(key),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: sel ? _charcoalBlack : _bgSoft,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: sel ? _charcoalBlack : _borderGrey),
                ),
                child: Text(
                  lbl,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                    color: sel ? _white : _darkGrey,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ── Empty State ───────────────────────────────────────────────────────────
  Widget _buildEmpty() => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(color: _white, shape: BoxShape.circle),
            child: const Icon(Icons.receipt_long_outlined, size: 44, color: _subGrey),
          ),
          const SizedBox(height: 16),
          const Text('No Payslips Available', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _charcoalBlack)),
          const SizedBox(height: 6),
          const Text(
            'Payslips will appear here once uploaded by the admin.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: _subGrey, height: 1.4),
          ),
        ],
      ),
    ),
  );

  // ── Main Payslip Content ──────────────────────────────────────────────────
  Widget _buildContent() {
    final s         = _slip!;
    final gross     = _num(s['gross_salary']);
    final totalAll  = _num(s['total_allowances']);
    final totalEarn = gross + totalAll;
    final totalDed  = _num(s['total_deductions']);
    // Net Pay = Total Earnings - Total Deductions (or net_salary from DB)
    final netPay    = _num(s['net_salary']) > 0 ? _num(s['net_salary']) : (totalEarn - totalDed);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Net Pay Summary Header Card ──────────────────────────────
          _buildNetPayCard(netPay, totalEarn, totalDed),
          const SizedBox(height: 14),

          // ── Leave & Attendance Overview ──────────────────────────────
          _buildLeaveAndAttendanceCard(s),
          const SizedBox(height: 14),

          // ── Employee Profile Info ────────────────────────────────────
          _buildEmployeeDetailsCard(s),
          const SizedBox(height: 14),

          // ── Earnings Breakdown ───────────────────────────────────────
          _buildEarningsCard(s, totalEarn),
          const SizedBox(height: 14),

          // ── Deductions Breakdown ─────────────────────────────────────
          _buildDeductionsCard(s, totalDed),
          const SizedBox(height: 16),

          // ── PDF Download Button ──────────────────────────────────────
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: _exporting ? null : _exportPdf,
              style: OutlinedButton.styleFrom(
                backgroundColor: _white,
                side: const BorderSide(color: _charcoalBlack, width: 1.2),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: _exporting
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: _charcoalBlack))
                  : const Icon(Icons.download_rounded, color: _charcoalBlack, size: 18),
              label: Text(
                _exporting ? 'Generating PDF...' : 'Download Payslip (PDF)',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _charcoalBlack),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Net Pay Card ──────────────────────────────────────────────────────────
  Widget _buildNetPayCard(double netPay, double gross, double totalDed) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderGrey),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'NET TAKE-HOME PAY',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _subGrey, letterSpacing: 0.5),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: _bgSoft, borderRadius: BorderRadius.circular(6), border: Border.all(color: _borderGrey)),
                child: Text(_monthLabel(_selectedKey), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _darkGrey)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '₹${NumberFormat('#,##,##0', 'en_IN').format(netPay)}',
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: _charcoalBlack, letterSpacing: -0.5),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(color: _bgSoft, borderRadius: BorderRadius.circular(8)),
            child: Row(
              children: [
                _summaryCol('Gross Salary', gross, _darkGrey),
                Container(width: 1, height: 28, color: _borderGrey),
                _summaryCol('Total Deductions', totalDed, _redDed),
                Container(width: 1, height: 28, color: _borderGrey),
                _summaryCol('Net Take-Home', netPay, _greenEarn),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryCol(String label, double amount, Color valColor) => Expanded(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 10, color: _subGrey, fontWeight: FontWeight.w500)),
          const SizedBox(height: 2),
          Text(
            '₹${NumberFormat('#,##,##0', 'en_IN').format(amount)}',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: valColor),
          ),
        ],
      ),
    ),
  );

  // ── Leave & Attendance (Uniform with Leave Page Colors) ────────────────────
  Widget _buildLeaveAndAttendanceCard(Map<String, dynamic> s) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderGrey),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Attendance & Leave Balance',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _charcoalBlack),
          ),
          const SizedBox(height: 12),
          // Attendance summary row
          Row(
            children: [
              _metricChip('Worked Days', _plain(s['awd']), Icons.calendar_today_rounded, _darkGrey),
              const SizedBox(width: 8),
              _metricChip('LOP Days', _plain(s['actual_leave']), Icons.warning_amber_rounded, _amberAccent),
              const SizedBox(width: 8),
              _metricChip('OT Hours', _plain(s['ex_hrs']), Icons.timer_outlined, _darkGrey),
            ],
          ),
          const SizedBox(height: 10),
          // Leave balance row (Matching leave page uniform EL & CL colors)
          Row(
            children: [
              _leaveCard('Casual Leave (CL)', _plain(s['closing_cl']), _clTeal),
              const SizedBox(width: 8),
              _leaveCard('Earned Leave (EL)', _plain(s['closing_el']), _elBlue),
              const SizedBox(width: 8),
              _leaveCard('Total Leave', _plain(s['total_leave']), _darkGrey),
            ],
          ),
          const SizedBox(height: 10),
          // Closing Loan Balance row
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            decoration: BoxDecoration(
              color: _bgSoft,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _borderGrey),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.account_balance_wallet_outlined, size: 14, color: _subGrey),
                    SizedBox(width: 6),
                    Text(
                      'Closing Loan Balance',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _darkGrey),
                    ),
                  ],
                ),
                Text(
                  _cur(s['closing_loan_balance'] ?? s['loan_closing']),
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _charcoalBlack),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _metricChip(String label, String value, IconData icon, Color iconColor) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      decoration: BoxDecoration(
        color: _bgSoft,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _borderGrey),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 12, color: iconColor),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10, color: _subGrey, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _charcoalBlack)),
        ],
      ),
    ),
  );

  /// Consistent with leave_page.dart _balanceCard style
  Widget _leaveCard(String title, String balance, Color accentColor) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: accentColor.withOpacity(0.3), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(color: accentColor, shape: BoxShape.circle),
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  title,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: accentColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            balance,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: accentColor, height: 1.1),
          ),
        ],
      ),
    ),
  );

  // ── Employee Details Card ─────────────────────────────────────────────────
  Widget _buildEmployeeDetailsCard(Map<String, dynamic> s) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderGrey),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Employee Details',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _charcoalBlack),
          ),
          const SizedBox(height: 10),
          _detailRow('Name', (s['emp_name'] ?? widget.displayName).toString()),
          _detailRow('Employee No', (s['employee_no'] ?? widget.username).toString()),
          _detailRow('Date of Joining', _formatDate(_userFromDb?['date_of_joining'] ?? _userFromDb?['user_doj'] ?? s['date_of_joining'] ?? s['user_doj'])),
          _detailRow('Designation', s['designation']?.toString() ?? '—'),
          _detailRow('Department', s['department']?.toString() ?? '—'),
          _detailRow('EPF Number', s['epf_no']?.toString() ?? '—'),
          _detailRow('ESIC Number', s['esic_no']?.toString() ?? '—'),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: _subGrey)),
        Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _charcoalBlack)),
      ],
    ),
  );

  // ── Earnings Card ─────────────────────────────────────────────────────────
  Widget _buildEarningsCard(Map<String, dynamic> s, double totalEarn) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderGrey),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Earnings', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _charcoalBlack)),
              Text('Rate  |  Earned', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _subGrey)),
            ],
          ),
          const SizedBox(height: 8),
          const Divider(height: 1, color: _borderGrey),
          const SizedBox(height: 6),
          _breakdownRow('Basic Pay', s['fixed_basic'], s['actual_basic']),
          _breakdownRow('DA', s['fixed_da'], s['actual_da']),
          _breakdownRow('Meal Allowance', 0, s['lunch_tea_amount']),
          _breakdownRow('Other Allowance', s['other_allowance_fixed'], s['other_allowance']),
          _breakdownRow('Arrear', 0, s['arear']),
          _breakdownRow('Attendance Bonus', 0, s['attendance_bonus']),
          _breakdownRow('Overtime Pay', 0, s['ot_amount']),
          const SizedBox(height: 6),
          const Divider(height: 1, color: _borderGrey),
          const SizedBox(height: 8),
          _totalRow('Gross Salary', totalEarn, true, color: _greenEarn),
        ],
      ),
    );
  }

  Widget _breakdownRow(String label, dynamic fixed, dynamic earned) {
    final f = _num(fixed);
    final e = _num(earned);
    if (f == 0 && e == 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: const TextStyle(fontSize: 12, color: _darkGrey)),
          ),
          SizedBox(
            width: 75,
            child: Text(
              f > 0 ? _cur(f) : '—',
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 12, color: _subGrey),
            ),
          ),
          SizedBox(
            width: 85,
            child: Text(
              _cur(e),
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _charcoalBlack),
            ),
          ),
        ],
      ),
    );
  }

  // ── Deductions Card ───────────────────────────────────────────────────────
  Widget _buildDeductionsCard(Map<String, dynamic> s, double totalDed) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderGrey),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Deductions', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _charcoalBlack)),
          const SizedBox(height: 8),
          const Divider(height: 1, color: _borderGrey),
          const SizedBox(height: 6),
          _deductionRow('EPF Employee (12%)', s['epf_deduction']),
          _deductionRow('ESIC Employee (0.75%)', s['esic_deduction']),
          _deductionRow('IOU / Control Account', s['emp_control']),
          _deductionRow('LIC Deduction', s['lic_amount']),
          _deductionRow('Professional Tax (PT)', s['pt_deduction']),
          _deductionRow('Staff Loan Deduction', s['loan_deduction']),
          _deductionRow('GMC Insurance', s['gmc_insurance']),
          _deductionRow('Salary Advance', s['salary_advance']),
          const SizedBox(height: 6),
          const Divider(height: 1, color: _borderGrey),
          const SizedBox(height: 8),
          _totalRow('Total Deductions', totalDed, true, color: _redDed),
        ],
      ),
    );
  }

  Widget _deductionRow(String label, dynamic val) {
    final n = _num(val);
    if (n == 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: _darkGrey)),
          Text(_cur(n), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _charcoalBlack)),
        ],
      ),
    );
  }

  Widget _totalRow(String label, double val, bool bold, {Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: bold ? 13 : 12,
            fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
            color: _charcoalBlack,
          ),
        ),
        Text(
          '₹${NumberFormat('#,##,##0', 'en_IN').format(val)}',
          style: TextStyle(
            fontSize: bold ? 13 : 12,
            fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
            color: color ?? _charcoalBlack,
          ),
        ),
      ],
    );
  }
}

