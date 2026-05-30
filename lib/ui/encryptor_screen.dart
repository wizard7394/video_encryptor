import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import '../core/crypto_engine.dart';

class EncryptorScreen extends StatefulWidget {
  const EncryptorScreen({super.key});

  @override
  State<EncryptorScreen> createState() => _EncryptorScreenState();
}

class _EncryptorScreenState extends State<EncryptorScreen> {
  String? sourceDir;
  String? destDir;
  bool processing = false;
  bool autoUploadKeys = true;
  String currentStatus = 'Ready to encode';
  double progressValue = 0.0;

  final CryptoEngine _engine = CryptoEngine();

  Future<void> pickSource() async {
    final result = await FilePicker.getDirectoryPath();
    if (result != null) setState(() => sourceDir = result);
  }

  Future<void> pickDest() async {
    final result = await FilePicker.getDirectoryPath();
    if (result != null) setState(() => destDir = result);
  }

  void stopProcess() {
    _engine.abort();
    setState(() => currentStatus = 'Aborting... Please wait.');
  }

  Future<void> startProcess() async {
    if (sourceDir == null || destDir == null) {
      setState(() => currentStatus = 'Select both directories first.');
      return;
    }

    setState(() {
      processing = true;
      progressValue = 0.0;
    });
    _engine.reset();

    final directory = Directory(sourceDir!);
    final entities = await directory.list().toList();
    final targetFiles = entities
        .whereType<File>()
        .where((f) => p.extension(f.path).toLowerCase() == '.mp4')
        .toList();

    int successCount = 0;
    int failCount = 0;
    String lastError = '';

    for (int i = 0; i < targetFiles.length; i++) {
      if (_engine.cancelRequested) break;

      final resultMsg = await _engine.processSingleFile(
        targetFile: targetFiles[i],
        destDir: destDir!,
        autoUpload: autoUploadKeys,
        onProgress: (prog, status) {
          setState(() {
            progressValue = prog;
            currentStatus = 'File ${i + 1} of ${targetFiles.length} | $status';
          });
        },
      );

      if (resultMsg == null) {
        successCount++;
      } else {
        failCount++;
        lastError = resultMsg;
      }
    }

    setState(() {
      processing = false;
      if (_engine.cancelRequested) {
        currentStatus = 'Process aborted by user.';
        progressValue = 0.0;
      } else if (failCount > 0) {
        currentStatus =
            'Finished with issues: $failCount failed.\nLast Notice: $lastError\nCheck encryptor_error_log.txt';
        progressValue = 1.0;
      } else {
        currentStatus = 'Success: $successCount files encoded securely.';
        progressValue = 1.0;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('DRM Offline Encryptor')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton(
              onPressed: processing ? null : pickSource,
              child: Text(sourceDir ?? 'Set Source Directory'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: processing ? null : pickDest,
              child: Text(destDir ?? 'Set Output Directory'),
            ),
            const SizedBox(height: 24),
            CheckboxListTile(
              title: const Text('Automatically upload keys to server'),
              subtitle: const Text(
                'Uncheck to force offline mode (saves local JSON)',
              ),
              value: autoUploadKeys,
              activeColor: Colors.blueAccent,
              onChanged: processing
                  ? null
                  : (bool? val) {
                      if (val != null) setState(() => autoUploadKeys = val);
                    },
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      backgroundColor: Colors.blueAccent,
                    ),
                    onPressed: processing ? null : startProcess,
                    child: const Text(
                      'Start Encoding',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      backgroundColor: Colors.redAccent,
                    ),
                    onPressed: processing ? stopProcess : null,
                    child: const Text(
                      'Abort Process',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 40),
            if (processing || progressValue > 0)
              LinearProgressIndicator(
                value: progressValue,
                minHeight: 12,
                borderRadius: BorderRadius.circular(8),
              ),
            const SizedBox(height: 24),
            Text(
              currentStatus,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                height: 1.5,
                color:
                    currentStatus.contains('failed') ||
                        currentStatus.contains('issues')
                    ? Colors.orangeAccent
                    : Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
