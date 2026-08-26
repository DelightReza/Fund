export 'file_helper_stub.dart'
    if (dart.library.html) 'file_helper_web.dart'
    if (dart.library.io) 'file_helper_io.dart';

class FileSaveResult {
  final bool success;
  final String? filePath;
  final String message;

  FileSaveResult({
    required this.success,
    this.filePath,
    required this.message,
  });
}
