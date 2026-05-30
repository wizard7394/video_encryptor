import 'dart:io';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:flutter/foundation.dart';

class ApiClient {
  final Dio _dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 5)));

  Future<void> logError(String dir, String msg) async {
    try {
      final logFile = File(p.join(dir, 'encryptor_error_log.txt'));
      final timestamp = DateTime.now().toString();
      await logFile.writeAsString('[$timestamp] $msg\n', mode: FileMode.append);
    } catch (e) {
      debugPrint('Logger failure: $e');
    }
  }

  Future<String?> syncOrBackupKeys(
    String refId,
    List<int> k,
    List<int> i,
    String destDir,
    bool autoUpload,
  ) async {
    if (!autoUpload) {
      await _writeLocalBackup(refId, k, i, destDir);
      return null;
    }

    try {
      await _dio.post(
        'http://127.0.0.1:8000/api/v1/admin/video/keys',
        data: {
          'video_reference': refId,
          'encryption_key': k,
          'initialization_vector': i,
        },
        options: Options(headers: {'Authorization': 'Bearer YOUR_ADMIN_TOKEN'}),
      );
      return null;
    } on DioException catch (e) {
      await logError(destDir, 'Network error for $refId: ${e.message}');
      await _writeLocalBackup(refId, k, i, destDir);
      return 'Network down. Saved to local JSON.';
    } catch (e) {
      await logError(destDir, 'Unknown sync error for $refId: $e');
      await _writeLocalBackup(refId, k, i, destDir);
      return 'Server error. Saved to local JSON.';
    }
  }

  Future<void> _writeLocalBackup(
    String refId,
    List<int> k,
    List<int> i,
    String dest,
  ) async {
    final fallbackFile = File(p.join(dest, 'offline_keys_backup.json'));
    List<dynamic> existingData = [];

    if (await fallbackFile.exists()) {
      final content = await fallbackFile.readAsString();
      if (content.trim().isNotEmpty) {
        try {
          existingData = jsonDecode(content);
        } catch (e) {
          await logError(
            dest,
            'Failed to parse existing JSON backup. Creating new array.',
          );
        }
      }
    }

    final backupData = {
      'video_reference': refId,
      'encryption_key': base64Encode(k),
      'initialization_vector': base64Encode(i),
      'timestamp': DateTime.now().toIso8601String(),
    };

    existingData.add(backupData);

    final encoder = const JsonEncoder.withIndent('  ');
    await fallbackFile.writeAsString(encoder.convert(existingData));
  }
}
