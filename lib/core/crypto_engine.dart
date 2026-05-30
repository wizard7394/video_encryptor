import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:video_encryptor/src/rust/api/simple.dart';
import 'api_client.dart';
import 'dart:math';

class CryptoEngine {
  final ApiClient apiClient = ApiClient();
  bool cancelRequested = false;

  void abort() => cancelRequested = true;
  void reset() => cancelRequested = false;

  List<int> generateSecureBytes(int length) {
    final random = Random.secure();
    return List<int>.generate(length, (_) => random.nextInt(256));
  }

  Future<String?> processSingleFile({
    required File targetFile,
    required String destDir,
    required bool autoUpload,
    required Function(double progress, String status) onProgress,
  }) async {
    final baseName = p.basenameWithoutExtension(targetFile.path);
    final outputPath = p.join(destDir, '$baseName.mp6');
    final outputFile = File(outputPath);

    try {
      final generatedKey = generateSecureBytes(32);
      final generatedIv = generateSecureBytes(12);

      final reader = await targetFile.open(mode: FileMode.read);
      final writer = await outputFile.open(mode: FileMode.write);

      const int chunkSize = 32 * 1024 * 1024;
      final int totalBytes = await reader.length();
      int currentOffset = 0;

      while (currentOffset < totalBytes) {
        if (cancelRequested) {
          await reader.close();
          await writer.close();
          if (await outputFile.exists()) await outputFile.delete();
          await apiClient.logError(destDir, 'Canceled by user: $baseName');
          return 'Process aborted by user.';
        }

        final buffer = await reader.read(chunkSize);
        final chunkPosition = currentOffset ~/ chunkSize;

        final encryptedData = await hardwareAcceleratedEncrypt(
          buffer: buffer,
          keyData: generatedKey,
          ivData: generatedIv,
          chunkPosition: chunkPosition,
        );

        await writer.writeFrom(encryptedData);
        currentOffset += chunkSize;

        onProgress(currentOffset / totalBytes, 'Encoding $baseName');
      }

      await reader.close();
      await writer.close();

      final syncError = await apiClient.syncOrBackupKeys(
        baseName,
        generatedKey,
        generatedIv,
        destDir,
        autoUpload,
      );
      return syncError;
    } on FileSystemException catch (e) {
      await apiClient.logError(destDir, 'IO Error on $baseName: $e');
      return 'File read/write permission denied.';
    } catch (e) {
      await apiClient.logError(destDir, 'Fatal error on $baseName: $e');
      return 'Corrupted file or engine crash.';
    }
  }
}
