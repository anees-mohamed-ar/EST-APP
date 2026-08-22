import 'dart:io';
import 'dart:typed_data';
import 'package:intl/intl.dart';

/// Saves payroll files to Downloads/EST_Payroll/ with unique timestamped names.
class PayrollFileService {
  static const _subDir = 'EST_Payroll';

  static Future<File> saveFile({
    required Uint8List bytes,
    required String employeeName,
    required String yearMonth,
    required String extension,
  }) async {
    final dir = Directory('/storage/emulated/0/Download/' + _subDir);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    final now = DateTime.now();
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(now);
    final safeName = employeeName
        .replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')
        .toLowerCase();
    final fileName = 'Payroll_' + safeName + '_' + yearMonth + '_' + timestamp + '.' + extension;
    final file = File(dir.path + '/' + fileName);
    await file.writeAsBytes(bytes);
    return file;
  }
}

