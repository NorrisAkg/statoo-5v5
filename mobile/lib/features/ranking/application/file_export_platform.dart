import 'dart:convert';
import 'dart:io' as io;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Interface d'abstraction multi-plateforme pour l'export et le partage de fichiers.
abstract class FileExportPlatform {
  Future<void> exportFile({
    required String fileName,
    required String content,
    required String mimeType,
  });
}

/// Implémentation concrète gérant Flutter Web (via FilePicker.saveFile)
/// et Mobile (iOS/Android via stockage temporaire et SharePlus.instance.share).
class DefaultFileExportPlatform implements FileExportPlatform {
  const DefaultFileExportPlatform();

  @override
  Future<void> exportFile({
    required String fileName,
    required String content,
    required String mimeType,
  }) async {
    if (kIsWeb) {
      final bytes = utf8.encode(content);
      await FilePicker.saveFile(
        fileName: fileName,
        bytes: Uint8List.fromList(bytes),
        mimeType: mimeType,
      );
      return;
    }

    final tempDir = await getTemporaryDirectory();
    final file = io.File('${tempDir.path}/$fileName');
    await file.writeAsString(content);

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: mimeType)],
        subject: fileName,
      ),
    );
  }
}

final fileExportPlatformProvider = Provider<FileExportPlatform>((ref) {
  return const DefaultFileExportPlatform();
});
