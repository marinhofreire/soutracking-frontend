// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter

import 'dart:convert';
import 'dart:html' as html;

Future<void> downloadTextFile({
  required String fileName,
  required String mimeType,
  required String content,
}) async {
  final body = html.document.body;
  if (body == null) {
    throw StateError('Documento sem body para iniciar download.');
  }

  final bytes = utf8.encode(content);
  final blob = html.Blob(
    [bytes],
    mimeType,
  );
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..style.display = 'none'
    ..rel = 'noopener'
    ..download = fileName;

  body.append(anchor);
  try {
    anchor.click();
    await Future<void>.delayed(const Duration(milliseconds: 350));
  } finally {
    anchor.remove();
    html.Url.revokeObjectUrl(url);
  }
}
