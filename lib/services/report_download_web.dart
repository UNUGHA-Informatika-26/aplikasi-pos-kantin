import 'dart:convert';

import 'package:web/web.dart' as web;

Future<void> downloadReportFile({
  required String fileName,
  required String contents,
}) async {
  final data = base64Encode(utf8.encode(contents));
  final anchor = web.HTMLAnchorElement()
    ..href = 'data:text/csv;charset=utf-8;base64,$data'
    ..download = fileName
    ..style.display = 'none';
  web.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
}
