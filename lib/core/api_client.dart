import 'dart:io';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:flutter/foundation.dart';

class ApiClient {
  final Dio _dio = Dio(
    BaseOptions(connectTimeout: const Duration(seconds: 15)),
  );

  final String baseUrl = 'https://api.devstorage.site';
  final String adminToken = '12345';

  Future<void> logError(String dir, String msg) async {
    try {
      final logFile = File(p.join(dir, 'encryptor_error_log.txt'));
      final timestamp = DateTime.now().toString();
      await logFile.writeAsString('[$timestamp] $msg\n', mode: FileMode.append);
    } catch (e) {
      debugPrint('Logger failure: $e');
    }
  }

  Future<String?> uploadVaultBatch({
    required int courseId,
    required String batchName,
    required List<Map<String, dynamic>> items,
    required String destDir,
  }) async {
    try {
      await _dio.post(
        '$baseUrl/api/v1/admin/vault/bulk',
        data: {'course_id': courseId, 'batch_name': batchName, 'items': items},
        options: Options(headers: {'Authorization': 'Bearer $adminToken'}),
      );
      return null;
    } on DioException catch (e) {
      await logError(
        destDir,
        'Network error for batch $batchName: ${e.message}',
      );
      await _writeLocalBackup(courseId, batchName, items, destDir);
      return 'Network down. Saved batch to local JSON.';
    } catch (e) {
      await logError(destDir, 'Unknown sync error for batch $batchName: $e');
      await _writeLocalBackup(courseId, batchName, items, destDir);
      return 'Server error. Saved batch to local JSON.';
    }
  }

  Future<void> _writeLocalBackup(
    int courseId,
    String batchName,
    List<Map<String, dynamic>> items,
    String dest,
  ) async {
    final fallbackFile = File(p.join(dest, 'offline_vault_backup.json'));
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
