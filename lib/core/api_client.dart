import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart' as p;
import 'package:flutter/foundation.dart';

class ApiClient {
  Future<void> logError(String dir, String msg) async {
    try {
      final logFile = File(p.join(dir, 'encryptor_error_log.txt'));
      final timestamp = DateTime.now().toString();
      await logFile.writeAsString('[$timestamp] $msg\n', mode: FileMode.append);
    } catch (e) {
      debugPrint('Logger failure: $e');
    }
  }

  Future<void> saveLocalBackup({
    required int courseId,
    required String batchName,
    required List<Map<String, dynamic>> items,
    required String destDir,
  }) async {
    final fallbackFile = File(
      p.join(destDir, 'offline_vault_backup_$batchName.json'),
    );
    List<dynamic> existingData = [];

    if (await fallbackFile.exists()) {
      final content = await fallbackFile.readAsString();
      if (content.trim().isNotEmpty) {
        try {
          existingData = jsonDecode(content);
        } catch (e) {
          await logError(
            destDir,
            'Failed to parse existing JSON backup. Creating new array.',
          );
        }
      }
    }

    final backupData = {
      'course_id': courseId,
      'batch_name': batchName,
      'items': items,
      'timestamp': DateTime.now().toIso8601String(),
    };

    existingData.add(backupData);

    final encoder = const JsonEncoder.withIndent('  ');
    await fallbackFile.writeAsString(encoder.convert(existingData));
  }
}
