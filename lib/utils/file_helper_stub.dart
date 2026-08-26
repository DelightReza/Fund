import 'file_helper.dart';

Future<FileSaveResult> saveAndDownloadFile({
  required String fileName,
  required String content,
  String mimeType = 'application/json',
}) async {
  return FileSaveResult(
    success: false,
    message: 'File downloading is not supported on this platform.',
  );
}

Future<String?> pickAndReadFile({List<String>? allowedExtensions}) async {
  return null;
}
