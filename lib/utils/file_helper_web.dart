import 'dart:convert';
import 'dart:html' as html;
import 'file_helper.dart';

Future<FileSaveResult> saveAndDownloadFile({
  required String fileName,
  required String content,
  String mimeType = 'application/json',
}) async {
  try {
    final bytes = utf8.encode(content);
    final blob = html.Blob([bytes], mimeType);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', fileName)
      ..style.display = 'none';
    html.document.body?.children.add(anchor);
    anchor.click();
    html.document.body?.children.remove(anchor);
    html.Url.revokeObjectUrl(url);
    return FileSaveResult(
      success: true,
      message: 'Downloaded "$fileName" to your browser downloads.',
    );
  } catch (e) {
    return FileSaveResult(
      success: false,
      message: 'Failed to download file: $e',
    );
  }
}

Future<String?> pickAndReadFile({List<String>? allowedExtensions}) async {
  try {
    final uploadInput = html.FileUploadInputElement();
    if (allowedExtensions != null && allowedExtensions.isNotEmpty) {
      uploadInput.accept =
          allowedExtensions.map((e) => e.startsWith('.') ? e : '.$e').join(',');
    }
    uploadInput.click();
    await uploadInput.onChange.first;
    final files = uploadInput.files;
    if (files == null || files.isEmpty) return null;
    final file = files[0];
    final reader = html.FileReader();
    reader.readAsText(file);
    await reader.onLoad.first;
    return reader.result as String?;
  } catch (_) {
    return null;
  }
}
