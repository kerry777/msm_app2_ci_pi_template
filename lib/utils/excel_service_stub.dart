import 'dart:typed_data';

class ExcelService {
  static Future<void> saveAndOpenExcel(Uint8List bytes, String fileName) async {
    throw UnimplementedError('이 플랫폼에서는 Excel 기능을 지원하지 않습니다.');
  }

  static Uint8List createAutoOrderHistoryExcel(List<Map<String, dynamic>> data) {
    throw UnimplementedError('이 플랫폼에서는 Excel 기능을 지원하지 않습니다.');
  }

  static Uint8List createExcelFromData({
    required List<Map<String, dynamic>> data,
    required List<String> headers,
    String sheetName = 'Data',
  }) {
    throw UnimplementedError('이 플랫폼에서는 Excel 기능을 지원하지 않습니다.');
  }
} 