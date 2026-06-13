import 'dart:io';
import 'dart:convert';
import 'dart:math';
import 'package:path/path.dart' as p;
import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';
import 'package:video_encryptor/src/rust/api/simple.dart';
import 'api_client.dart';
import 'dart:typed_data';

class CryptoEngine {
  final ApiClient apiClient = ApiClient();
  bool cancelRequested = false;
  final Uuid _uuidGenerator = const Uuid();

  void abort() => cancelRequested = true;
  void reset() => cancelRequested = false;

  List<int> generateSecureBytes(int length) {
    final random = Random.secure();
    return List<int>.generate(length, (_) => random.nextInt(256));
  }

  Future<Map<String, dynamic>?> processSingleFile({
    required File targetFile,
    required String destDir,
    required Function(double progress, String status) onProgress,
  }) async {
    final baseName = p.basenameWithoutExtension(targetFile.path);
    final outputPath = p.join(destDir, '$baseName.mp6');
    final outputFile = File(outputPath);

    try {
      final generatedKey = generateSecureBytes(32);
      final generatedIv = generateSecureBytes(12);
      final fileUuid = _uuidGenerator.v4();

      final reader = await targetFile.open(mode: FileMode.read);
      final writer = await outputFile.open(mode: FileMode.write);

      final dummyHeader = List<int>.filled(104, 0);
      await writer.writeFrom(dummyHeader);

      const int chunkSize = 2 * 1024 * 1024;
      final int totalBytes = await reader.length();
      int currentOffset = 0;

      Digest? finalDigest;
      final sink = ChunkedConversionSink<Digest>.withCallback((accumulated) {
        finalDigest = accumulated.single;
      });
      final hashInput = sha256.startChunkedConversion(sink);

      while (currentOffset < totalBytes) {
        if (cancelRequested) {
          await reader.close();
          await writer.close();
          if (await outputFile.exists()) await outputFile.delete();
          await apiClient.logError(destDir, 'Canceled by user: $baseName');
          return null;
        }

        final buffer = await reader.read(chunkSize);
        hashInput.add(buffer);

        final chunkPosition = currentOffset ~/ chunkSize;
        final encryptedData = await hardwareAcceleratedEncrypt(
          buffer: buffer,
          keyData: generatedKey,
          ivData: generatedIv,
          chunkPosition: chunkPosition,
        );

        await writer.writeFrom(encryptedData);
        currentOffset += buffer.length;

        onProgress(currentOffset / totalBytes, 'Encoding $baseName');
      }

      hashInput.close();
      final fileHash = finalDigest.toString();

      await writer.setPosition(0);
      final headerBuilder = BytesBuilder();
      headerBuilder.add(utf8.encode('DRM6'));
      headerBuilder.add(utf8.encode(fileUuid.padRight(36)));
      headerBuilder.add(utf8.encode(fileHash.padRight(64)));
      await writer.writeFrom(headerBuilder.toBytes());

      await reader.close();
      await writer.close();

      return {
        'uuid': fileUuid,
        'file_hash': fileHash,
        'aes_key': base64Encode(generatedKey),
        'aes_iv': base64Encode(generatedIv),
        'original_filename': baseName,
      };
    } on FileSystemException catch (e) {
      await apiClient.logError(destDir, 'IO Error on $baseName: $e');
      return null;
    } catch (e) {
      await apiClient.logError(destDir, 'Fatal error on $baseName: $e');
      return null;
    }
  }
}
