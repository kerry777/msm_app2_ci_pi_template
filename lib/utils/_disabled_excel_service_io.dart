// Syncfusion XlsIO로 교체 완료
import 'dart:typed_data';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xlsio;
import 'package:open_file/open_file.dart';

class ExcelService {
  /// Syncfusion을 사용한 Excel 파일 저장 및 열기 (모바일/데스크톱)
  static Future<void> saveAndOpenExcel(Uint8List bytes, String fileName) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/$fileName');
      await file.writeAsBytes(bytes);
      
      // 파일 열기 시도 (사용자 디바이스의 기본 앱으로)
      try {
        await OpenFile.open(file.path);
      } catch (openError) {
        print('파일 열기 실패 (저장은 성공): $openError');
        // 파일은 저장되었으나 열기만 실패한 경우
      }
    } catch (e) {
      print('Excel 파일 저장 실패: $e');
      rethrow;
    }
  }

  /// Syncfusion을 사용한 자동주문이력 Excel 생성
  static Uint8List createAutoOrderHistoryExcel(List<Map<String, dynamic>> data) {
    try {
      final workbook = xlsio.Workbook();
      final worksheet = workbook.worksheets[0];
      worksheet.name = '자동주문이력';
      
      // 헤더 설정
      final headers = [
        '마감일자', '재고마감상태', '자동주문번호', '자동주문상태', '전체품목수',
        '부족품목수', '총주문수량', '예상도착일', '실제도착일', '생성자', '비고',
      ];
      
      // 헤더 추가
      for (int i = 0; i < headers.length; i++) {
        final range = worksheet.getRangeByIndex(1, i + 1);
        range.setText(headers[i]);
        range.cellStyle.bold = true;
        range.cellStyle.backColor = '#E8F4FD';
        range.cellStyle.hAlign = xlsio.HAlignType.center;
      }
      
      // 데이터 추가
      for (int row = 0; row < data.length; row++) {
        final item = data[row];
        int col = 1; // Syncfusion은 1-based 인덱스
        
        worksheet.getRangeByIndex(row + 2, col++).setText(item['closeDate']?.toString() ?? '');
        worksheet.getRangeByIndex(row + 2, col++).setText(item['closeStatus']?.toString() ?? '');
        worksheet.getRangeByIndex(row + 2, col++).setText(item['id']?.toString() ?? '');
        worksheet.getRangeByIndex(row + 2, col++).setText(item['status']?.toString() ?? '');
        worksheet.getRangeByIndex(row + 2, col++).setNumber((item['totalItems'] ?? 0).toDouble());
        worksheet.getRangeByIndex(row + 2, col++).setNumber((item['shortageItems'] ?? 0).toDouble());
        worksheet.getRangeByIndex(row + 2, col++).setNumber((item['totalOrderQty'] ?? 0).toDouble());
        worksheet.getRangeByIndex(row + 2, col++).setText(item['expectedArrivalDate']?.toString() ?? '');
        worksheet.getRangeByIndex(row + 2, col++).setText(item['actualArrivalDate']?.toString() ?? '');
        worksheet.getRangeByIndex(row + 2, col++).setText(item['createdBy']?.toString() ?? '');
        worksheet.getRangeByIndex(row + 2, col++).setText(item['remark']?.toString() ?? '');
      }
      
      // 컬럼 너비 자동 조정
      for (int i = 1; i <= headers.length; i++) {
        worksheet.autoFitColumn(i);
      }
      
      // 테두리 추가
      if (data.isNotEmpty) {
        final range = worksheet.getRangeByIndex(1, 1, data.length + 1, headers.length);
        range.cellStyle.borders.all.lineStyle = xlsio.LineStyle.thin;
        range.cellStyle.borders.all.color = '#000000';
      }
      
      final bytes = workbook.saveAsStream();
      workbook.dispose();
      
      return Uint8List.fromList(bytes);
    } catch (e) {
      print('자동주문이력 Excel 생성 실패: $e');
      return Uint8List(0);
    }
  }

  /// 일반적인 데이터를 Excel로 변환
  static Uint8List createExcelFromData({
    required List<Map<String, dynamic>> data,
    required List<String> headers,
    String sheetName = 'Data',
  }) {
    try {
      final workbook = xlsio.Workbook();
      final worksheet = workbook.worksheets[0];
      worksheet.name = sheetName;
      
      // 헤더 추가
      for (int i = 0; i < headers.length; i++) {
        final range = worksheet.getRangeByIndex(1, i + 1);
        range.setText(headers[i]);
        range.cellStyle.bold = true;
        range.cellStyle.backColor = '#E8F4FD';
        range.cellStyle.hAlign = xlsio.HAlignType.center;
      }
      
      // 데이터 추가 (키 기반)
      for (int row = 0; row < data.length; row++) {
        final item = data[row];
        for (int col = 0; col < headers.length; col++) {
          final key = _getKeyFromHeader(headers[col]);
          final value = item[key];
          final range = worksheet.getRangeByIndex(row + 2, col + 1);
          
          if (value == null) {
            range.setText('');
          } else if (value is String) {
            range.setText(value);
          } else if (value is num) {
            range.setNumber(value.toDouble());
          } else if (value is DateTime) {
            range.setDateTime(value);
          } else {
            range.setText(value.toString());
          }
        }
      }
      
      // 컬럼 너비 자동 조정
      for (int i = 1; i <= headers.length; i++) {
        worksheet.autoFitColumn(i);
      }
      
      // 테두리 추가
      if (data.isNotEmpty) {
        final range = worksheet.getRangeByIndex(1, 1, data.length + 1, headers.length);
        range.cellStyle.borders.all.lineStyle = xlsio.LineStyle.thin;
        range.cellStyle.borders.all.color = '#000000';
      }
      
      final bytes = workbook.saveAsStream();
      workbook.dispose();
      
      return Uint8List.fromList(bytes);
    } catch (e) {
      print('Excel 생성 실패: $e');
      return Uint8List(0);
    }
  }

  /// 헤더에서 데이터 키 추출 (간단한 매핑)
  static String _getKeyFromHeader(String header) {
    final headerToKey = {
      '품목코드': 'ERPCODE',
      '품목명': 'itemName',
      '규격': 'specification',
      '현재고': 'currentStock',
      '안전재고': 'safetyStock',
      '주문필요수량': 'orderRequired',
      '마감일자': 'closeDate',
      '재고마감상태': 'closeStatus',
      '자동주문번호': 'id',
      '자동주문상태': 'status',
      '전체품목수': 'totalItems',
      '부족품목수': 'shortageItems',
      '총주문수량': 'totalOrderQty',
      '예상도착일': 'expectedArrivalDate',
      '실제도착일': 'actualArrivalDate',
      '생성자': 'createdBy',
      '비고': 'remark',
    };
    
    return headerToKey[header] ?? header.toLowerCase().replaceAll(' ', '_');
  }
}