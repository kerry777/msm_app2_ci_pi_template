// 웹 전용: 조건부 import로만 접근해야 함
import 'dart:html' as html;

void saveAndOpenExcelWeb(List<int> bytes, String fileName) {
  final blob = html.Blob([bytes]);
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..setAttribute('download', fileName)
    ..click();
  html.Url.revokeObjectUrl(url);
} 