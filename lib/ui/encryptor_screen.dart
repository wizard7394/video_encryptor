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
  String currentStatus = 'Ready to encode';
  double progressValue = 0.0;

  final CryptoEngine _engine = CryptoEngine();
  final TextEditingController courseIdController = TextEditingController();
  final TextEditingController batchNameController = TextEditingController();

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

    final int? courseId = int.tryParse(courseIdController.text);
    if (courseId == null) {
      setState(() => currentStatus = 'Please enter a valid numeric Course ID.');
      return;
    }

    final String batchName = batchNameController.text.trim().isEmpty
        ? 'Auto_Batch'
        : batchNameController.text.trim();

    setState(() {
      processing = true;
      progressValue = 0.0;
      currentStatus = 'Scanning files recursively...';
    });

    _engine.reset();

    final directory = Directory(sourceDir!);
    final entities = await directory.list(recursive: true).toList();
    final targetFiles = entities
        .whereType<File>()
        .where((f) => p.extension(f.path).toLowerCase() == '.mp4')
        .toList();

    if (targetFiles.isEmpty) {
      setState(() {
        processing = false;
        currentStatus =
            'No .mp4 files found in source directory or its sub-folders.';
      });
      return;
    }

    int successCount = 0;
    int failCount = 0;
    List<Map<String, dynamic>> processedItems = [];

    for (int i = 0; i < targetFiles.length; i++) {
      if (_engine.cancelRequested) break;

      final String relativePath = p.relative(
        targetFiles[i].path,
        from: sourceDir!,
      );

      final resultMap = await _engine.processSingleFile(
        targetFile: targetFiles[i],
        destDir: destDir!,
        relativePath: relativePath,
        onProgress: (prog, status) {
          setState(() {
            progressValue = prog;
            currentStatus = 'File ${i + 1} of ${targetFiles.length} | $status';
          });
        },
      );

      if (resultMap != null) {
        successCount++;
        processedItems.add(resultMap);
      } else {
        failCount++;
      }
    }

    if (_engine.cancelRequested) {
      setState(() {
        processing = false;
        currentStatus = 'Process aborted by user.';
        progressValue = 0.0;
      });
      return;
    }

    if (processedItems.isNotEmpty) {
      setState(() {
        currentStatus = 'Saving keys to local JSON...';
      });

      await _engine.apiClient.saveLocalBackup(
        courseId: courseId,
        batchName: batchName,
        items: processedItems,
        destDir: destDir!,
      );
    }

    setState(() {
      processing = false;
      progressValue = 1.0;

      String finalReport = failCount > 0
          ? 'Finished: $successCount encoded, $failCount failed.'
          : 'Success: $successCount files encoded.';

      finalReport +=
          '\nJSON file saved in output folder! Import it manually in admin panel.';

      currentStatus = finalReport;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text('DRM Batch Encryptor (Offline Mode)'),
        backgroundColor: const Color(0xFF1E1E1E),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: courseIdController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Global Course ID',
                      labelStyle: const TextStyle(color: Colors.white54),
                      filled: true,
                      fillColor: const Color(0xFF1E1E1E),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: batchNameController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Batch Name (e.g., Python_Updates)',
                      labelStyle: const TextStyle(color: Colors.white54),
                      filled: true,
                      fillColor: const Color(0xFF1E1E1E),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.folder_open),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      backgroundColor: const Color(0xFF2C2C2C),
                    ),
                    onPressed: processing ? null : pickSource,
                    label: Text(
                      sourceDir != null
                          ? 'SRC: ...${p.basename(sourceDir!)}'
                          : 'Select MP4 Folder',
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.save_alt),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      backgroundColor: const Color(0xFF2C2C2C),
                    ),
                    onPressed: processing ? null : pickDest,
                    label: Text(
                      destDir != null
                          ? 'OUT: ...${p.basename(destDir!)}'
                          : 'Select Output Folder',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      backgroundColor: const Color(0xFF00E676),
                      foregroundColor: Colors.black,
                    ),
                    onPressed: processing ? null : startProcess,
                    child: const Text(
                      'ENCODE & SAVE JSON',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      backgroundColor: Colors.redAccent,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: processing ? stopProcess : null,
                    child: const Text(
                      'ABORT',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 40),
            if (processing || progressValue > 0)
              LinearProgressIndicator(
                value: progressValue,
                minHeight: 8,
                backgroundColor: const Color(0xFF1E1E1E),
                color: const Color(0xFF00E676),
                borderRadius: BorderRadius.circular(8),
              ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF333333)),
              ),
              child: Text(
                currentStatus,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  fontFamily: 'monospace',
                  color: Colors.white70,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
