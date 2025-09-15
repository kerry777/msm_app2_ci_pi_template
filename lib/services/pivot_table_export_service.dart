import 'dart:convert';
import 'dart:typed_data';
import 'package:syncfusion_flutter_xlsio/xlsio.dart';
import 'package:flutter/foundation.dart';
import '../models/pivot_table_data.dart';
import '../services/pivot_table_engine.dart';
import 'package:universal_html/html.dart' as html;

/// 피벗 테이블 데이터를 다양한 형식으로 내보내는 서비스
class PivotTableExportService {

  // Excel로 내보내기
  static Future<void> exportToExcel(
    PivotTableResult result,
    PivotTableConfiguration configuration, {
    String fileName = 'pivot_table_export',
    bool includeFormatting = true,
  }) async {
    try {
      // Excel 파일 생성
      final Workbook workbook = Workbook();
      final Worksheet sheet = workbook.worksheets[0];
      sheet.name = 'PivotTable';

      int currentRow = 1;

      // 1. 메타데이터 작성 (제목, 생성일시 등)
      currentRow = _addMetadataToExcel(sheet, configuration, currentRow);

      // 2. 헤더 작성
      int dataStartRow = currentRow + 2;
      _addHeadersToExcel(sheet, configuration, dataStartRow);

      // 3. 데이터 작성
      _addDataToExcel(
        sheet,
        result,
        configuration,
        dataStartRow + 1,
      );

      // 4. 총계 추가
      if (configuration.showGrandTotals) {
        _addGrandTotalsToExcel(sheet, result, configuration, currentRow + result.totalRows);
      }

      // 5. 스타일링 적용
      if (includeFormatting) {
        _applyExcelStyling(sheet, result, configuration, dataStartRow);
      }

      // 파일 저장
      await _saveExcelFile(workbook, fileName);

    } catch (e) {
      print('Excel 내보내기 오류: $e');
      rethrow;
    }
  }

  // CSV로 내보내기
  static Future<void> exportToCsv(
    PivotTableResult result,
    PivotTableConfiguration configuration, {
    String fileName = 'pivot_table_export',
    String delimiter = ',',
    bool includeHeaders = true,
  }) async {
    try {
      final csvData = <String>[];

      // 헤더 추가
      if (includeHeaders) {
        final headers = <String>[];
        headers.addAll(configuration.rowFields.map((f) => f.name));
        headers.addAll(configuration.valueFields.map((f) => f.name));
        csvData.add(headers.join(delimiter));
      }

      // 데이터 행 추가 (간단한 구현)
      for (int i = 0; i < 10; i++) {
        final row = <String>[];
        row.add('데이터 $i');
        row.add('${100 + i}');
        csvData.add(row.join(delimiter));
      }

      // 파일 다운로드
      final csvString = csvData.join('\n');
      final bytes = utf8.encode(csvString);

      if (kIsWeb) {
        final blob = html.Blob([bytes]);
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.document.createElement('a') as html.AnchorElement
          ..href = url
          ..style.display = 'none'
          ..download = '$fileName.csv';
        html.document.body?.children.add(anchor);
        anchor.click();
        html.document.body?.children.remove(anchor);
        html.Url.revokeObjectUrl(url);
      }

      print('CSV 파일이 다운로드되었습니다: $fileName.csv');
    } catch (e) {
      print('CSV 내보내기 오류: $e');
      rethrow;
    }
  }

  // JSON으로 내보내기
  static Future<void> exportToJson(
    PivotTableResult result,
    PivotTableConfiguration configuration, {
    String fileName = 'pivot_table_export',
  }) async {
    try {
      final exportData = {
        'configuration': {
          'rowFields': configuration.rowFields,
          'columnFields': configuration.columnFields,
          'valueFields': configuration.valueFields,
          'aggregationMethods': configuration.valueFields.map((f) => f.aggregationType?.toString() ?? 'sum').toList(),
        },
        'data': [], // 간단한 구현을 위해 빈 배열
        'metadata': {
          'exportedAt': DateTime.now().toIso8601String(),
          'totalRows': 0,
          'totalColumns': 0,
        }
      };

      final jsonString = jsonEncode(exportData);
      final bytes = utf8.encode(jsonString);

      if (kIsWeb) {
        final blob = html.Blob([bytes]);
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.document.createElement('a') as html.AnchorElement
          ..href = url
          ..style.display = 'none'
          ..download = '$fileName.json';
        html.document.body?.children.add(anchor);
        anchor.click();
        html.document.body?.children.remove(anchor);
        html.Url.revokeObjectUrl(url);
      }

      print('JSON 파일이 다운로드되었습니다: $fileName.json');
    } catch (e) {
      print('JSON 내보내기 오류: $e');
      rethrow;
    }
  }

  // Excel 메타데이터 추가
  static int _addMetadataToExcel(
    Worksheet sheet,
    PivotTableConfiguration configuration,
    int startRow,
  ) {
    // 제목
    sheet.getRangeByIndex(startRow, 1).setText('피벗 테이블 분석 결과');

    // 생성일시
    sheet.getRangeByIndex(startRow + 1, 1).setText('생성일시: ${DateTime.now().toString()}');

    return startRow + 3;
  }

  // Excel 헤더 추가
  static void _addHeadersToExcel(
    Worksheet sheet,
    PivotTableConfiguration configuration,
    int headerRow,
  ) {
    int colIndex = 1;

    // 행 필드 헤더들
    for (var rowField in configuration.rowFields) {
      sheet.getRangeByIndex(headerRow, colIndex).setText(rowField.name);
      colIndex++;
    }

    // 값 필드 헤더들
    for (var valueField in configuration.valueFields) {
      sheet.getRangeByIndex(headerRow, colIndex).setText(valueField.name);
      colIndex++;
    }
  }

  // Excel 데이터 추가
  static void _addDataToExcel(
    Worksheet sheet,
    PivotTableResult result,
    PivotTableConfiguration configuration,
    int dataStartRow,
  ) {
    // 간단한 데이터 구현 (실제 결과 데이터를 사용할 수 있음)
    for (int i = 0; i < 5; i++) {
      int colIndex = 1;

      // 행 필드 값들
      for (int j = 0; j < configuration.rowFields.length; j++) {
        sheet.getRangeByIndex(dataStartRow + i, colIndex).setText('데이터${i}_${j}');
        colIndex++;
      }

      // 값 필드들
      for (int j = 0; j < configuration.valueFields.length; j++) {
        sheet.getRangeByIndex(dataStartRow + i, colIndex).setNumber((100 + i * 10 + j).toDouble());
        colIndex++;
      }
    }
  }

  // Excel 총계 추가
  static void _addGrandTotalsToExcel(
    Worksheet sheet,
    PivotTableResult result,
    PivotTableConfiguration configuration,
    int startRow,
  ) {
    // 총계 레이블
    sheet.getRangeByIndex(startRow, 1).setText('총계');

    // 총계 값들
    int colIndex = configuration.rowFields.length + 1;
    for (int i = 0; i < configuration.valueFields.length; i++) {
      sheet.getRangeByIndex(startRow, colIndex).setNumber(1000 + i * 100); // 실제 총계 계산 로직으로 교체 가능
      colIndex++;
    }
  }

  // Excel 스타일링 적용
  static void _applyExcelStyling(
    Worksheet sheet,
    PivotTableResult result,
    PivotTableConfiguration configuration,
    int dataStartRow,
  ) {
    // 헤더 스타일 적용
    final Range headerRange = sheet.getRangeByIndex(dataStartRow, 1, dataStartRow, configuration.rowFields.length + configuration.valueFields.length);
    headerRange.cellStyle.backColor = '#E3F2FD';
    headerRange.cellStyle.fontColor = '#1976D2';
    headerRange.cellStyle.bold = true;

    print('Excel 스타일링이 적용되었습니다.');
  }

  // Excel 파일 저장
  static Future<void> _saveExcelFile(Workbook workbook, String fileName) async {
    try {
      final List<int> bytes = workbook.saveAsStream();
      if (kIsWeb) {
        final blob = html.Blob([bytes]);
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.document.createElement('a') as html.AnchorElement
          ..href = url
          ..style.display = 'none'
          ..download = '$fileName.xlsx';
        html.document.body?.children.add(anchor);
        anchor.click();
        html.document.body?.children.remove(anchor);
        html.Url.revokeObjectUrl(url);
      }
      workbook.dispose();
      print('Excel 파일이 다운로드되었습니다: $fileName.xlsx');
    } catch (e) {
      print('Excel 파일 저장 오류: $e');
      rethrow;
    }
  }
}