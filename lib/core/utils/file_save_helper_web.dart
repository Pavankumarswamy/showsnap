import 'dart:html' as html;
import 'dart:typed_data';

Future<void> saveAndDownloadPng(Uint8List bytes, String filename) async {
  final blob = html.Blob([bytes], 'image/png');
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..setAttribute("download", filename)
    ..click();
  html.Url.revokeObjectUrl(url);
}

Future<void> saveAndDownloadFile(Uint8List bytes, String filename) async {
  final blob = html.Blob([bytes]); // Mime-type inferred or empty for generic
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..setAttribute("download", filename)
    ..click();
  html.Url.revokeObjectUrl(url);
}
