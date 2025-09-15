// Syncfusion XlsIO로 교체 완료
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xlsio;

class ExcelUtils {
  static List<String> getItemExportHeaders() {
    return ['품목코드', '품목명', '수량', '비고'];
  }

  static List<String> getStockCloseHeaders() {
    return ['기준일', '품목코드', '품목명', '현재고', '안전재고', '주문필요수량', '월기초', '입고', '반출', '반납'];
  }

  /// Syncfusion Worksheet에 헤더 추가
  static void addHeadersToSheet(xlsio.Worksheet worksheet, List<String> headers) {
    try {
      for (int i = 0; i < headers.length; i++) {
        final range = worksheet.getRangeByIndex(1, i + 1); // Syncfusion은 1-based 인덱스
        range.setText(headers[i]);
        
        // 헤더 스타일 적용
        range.cellStyle.bold = true;
        range.cellStyle.backColor = '#E8F4FD';
        range.cellStyle.hAlign = xlsio.HAlignType.center;
        range.cellStyle.vAlign = xlsio.VAlignType.center;
      }
    } catch (e) {
      print('헤더 추가 실패: $e');
    }
  }

  /// Syncfusion Worksheet에 데이터 행 추가  
  static void addDataRowToSheet(xlsio.Worksheet worksheet, List<dynamic> data, int rowIndex) {
    try {
      for (int i = 0; i < data.length; i++) {
        final range = worksheet.getRangeByIndex(rowIndex + 1, i + 1); // Syncfusion은 1-based 인덱스
        final value = data[i];
        
        if (value == null) {
          range.setText('');
        } else if (value is String) {
          range.setText(value);
        } else if (value is int) {
          range.setNumber(value.toDouble());
        } else if (value is double) {
          range.setNumber(value);
        } else if (value is DateTime) {
          range.setDateTime(value);
        } else {
          range.setText(value.toString());
        }
      }
    } catch (e) {
      print('데이터 행 추가 실패 (row $rowIndex): $e');
    }
  }

  /// Syncfusion Workbook 생성 (기본 워크시트 포함)
  static xlsio.Workbook createWorkbook({String? sheetName}) {
    final workbook = xlsio.Workbook();
    if (sheetName != null) {
      workbook.worksheets[0].name = sheetName;
    }
    return workbook;
  }

  /// 컬럼 너비 자동 조정
  static void autoFitColumns(xlsio.Worksheet worksheet, {int? maxColumns}) {
    try {
      // Syncfusion XlsIO에서는 usedRange 대신 직접 범위 지정
      final columns = maxColumns ?? 10; // 기본 10개 컬럼 - usedRange 미지원으로 인한 대안
      for (int i = 1; i <= columns; i++) {
        try {
          worksheet.autoFitColumn(i);
        } catch (e) {
          // 개별 컬럼 자동 조정 실패 시 무시
        }
      }
    } catch (e) {
      print('컬럼 너비 자동 조정 실패: $e');
    }
  }

  /// 워크시트에 테두리 추가
  static void addBorders(xlsio.Worksheet worksheet, int startRow, int startCol, int endRow, int endCol) {
    try {
      final range = worksheet.getRangeByIndex(startRow, startCol, endRow, endCol);
      range.cellStyle.borders.all.lineStyle = xlsio.LineStyle.thin;
      range.cellStyle.borders.all.color = '#000000';
    } catch (e) {
      print('테두리 추가 실패: $e');
    }
  }

  /// 날짜 형식 적용
  static void applyDateFormat(xlsio.Worksheet worksheet, int row, int col, {String format = 'yyyy-mm-dd'}) {
    try {
      final range = worksheet.getRangeByIndex(row, col);
      range.numberFormat = format;
    } catch (e) {
      print('날짜 형식 적용 실패: $e');
    }
  }

  /// 숫자 형식 적용 (천 단위 구분자 등)
  static void applyNumberFormat(xlsio.Worksheet worksheet, int row, int col, {String format = '#,##0'}) {
    try {
      final range = worksheet.getRangeByIndex(row, col);
      range.numberFormat = format;
    } catch (e) {
      print('숫자 형식 적용 실패: $e');
    }
  }
} 