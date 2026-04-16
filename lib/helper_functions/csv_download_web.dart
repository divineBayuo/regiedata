import 'dart:html' as html;
import 'dart:convert';

void downloadCsvWeb(String csvContent, String filename) {
  final bytes = utf8.encode(csvContent);

  final blob = html.Blob([bytes], 'text/csv');
  final url = html.Url.createObjectUrlFromBlob(blob);

  final anchor = html.AnchorElement(href: url)
    ..setAttribute('download', filename)
    ..style.display = 'none';

  html.document.body!.append(anchor);
  anchor.click();
  anchor.remove();

  html.Url.revokeObjectUrl(url);
}