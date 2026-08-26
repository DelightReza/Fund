import 'dart:io';
import 'file_helper.dart';

Future<FileSaveResult> saveAndDownloadFile({
  required String fileName,
  required String content,
  String mimeType = 'application/json',
}) async {
  try {
    Directory? targetDir;

    // 1. Android public Downloads directory
    if (Platform.isAndroid) {
      final downloadDir = Directory('/storage/emulated/0/Download');
      try {
        if (!downloadDir.existsSync()) {
          downloadDir.createSync(recursive: true);
        }
        targetDir = downloadDir;
      } catch (_) {}
    }

    // 2. Fallback to system temp directory
    targetDir ??= Directory.systemTemp;

    final targetFile = File('${targetDir.path}/$fileName');
    await targetFile.writeAsString(content, flush: true);

    return FileSaveResult(
      success: true,
      filePath: targetFile.path,
      message: Platform.isAndroid
          ? 'Saved to Downloads/$fileName'
          : 'Saved to ${targetFile.path}',
    );
  } catch (e) {
    return FileSaveResult(
      success: false,
      message: 'Failed to save file on device: $e',
    );
  }
}

Future<String?> pickAndReadFile({List<String>? allowedExtensions}) async {
  return null;
}
