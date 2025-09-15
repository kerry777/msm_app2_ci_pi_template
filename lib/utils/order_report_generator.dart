import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
// import 'package:excel/excel.dart';  // 주석 처리
import 'package:printing/printing.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';

class OrderReportGenerator {
  // 한글 폰트 로딩 함수
  static Future<pw.Font> _loadKoreanFont() async {
    try {
      // 웹에서는 Google Fonts 사용
      if (kIsWeb) {
        return await PdfGoogleFonts.notoSansKRRegular();
      }
      // 네이티브에서는 로컬 폰트 파일 사용
      else {
        // 시스템 폰트 사용 시도
        return await PdfGoogleFonts.notoSansKRRegular();
      }
    } catch (e) {
      // 폰트 로딩 실패 시 기본 폰트 사용
      print('한글 폰트 로딩 실패: $e');
      return pw.Font.helvetica();
    }
  }

  static Future<pw.Font> _loadKoreanBoldFont() async {
    try {
      // 웹에서는 Google Fonts 사용
      if (kIsWeb) {
        return await PdfGoogleFonts.notoSansKRBold();
      }
      // 네이티브에서는 로컬 폰트 파일 사용
      else {
        return await PdfGoogleFonts.notoSansKRBold();
      }
    } catch (e) {
      // 폰트 로딩 실패 시 기본 폰트 사용
      print('한글 볼드 폰트 로딩 실패: $e');
      return pw.Font.helveticaBold();
    }
  }

  // PDF 견적서 생성
  static Future<Uint8List> generateQuotePDF({
    required String quoteNumber,
    required String customerName,
    required String customerCode,
    required String validDate,
    required String quoteType,
    required List<Map<String, dynamic>> items,
    String? companyName = 'MEKICS',
    String? companyAddress = '서울시 강남구',
    String? companyPhone = '02-1234-5678',
  }) async {
    final pdf = pw.Document();
    
    final font = await _loadKoreanFont();
    final fontBold = await _loadKoreanBoldFont();
    
    final totalAmount = items.fold<double>(
      0.0, 
      (sum, item) => sum + (item['quantity'] * item['unitPrice']),
    );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            // 헤더
            pw.Container(
              alignment: pw.Alignment.center,
              child: pw.Column(
                children: [
                  pw.Text(
                    '견 적 서',
                    style: pw.TextStyle(
                      font: fontBold,
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 20),
                ],
              ),
            ),
            
            // 회사 정보 및 견적 정보
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // 회사 정보
                pw.Expanded(
                  child: pw.Container(
                    padding: const pw.EdgeInsets.all(16),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('공급자', style: pw.TextStyle(font: fontBold, fontSize: 12)),
                        pw.SizedBox(height: 8),
                        pw.Text('회사명: $companyName', style: pw.TextStyle(font: font, fontSize: 10)),
                        pw.Text('주소: $companyAddress', style: pw.TextStyle(font: font, fontSize: 10)),
                        pw.Text('전화: $companyPhone', style: pw.TextStyle(font: font, fontSize: 10)),
                      ],
                    ),
                  ),
                ),
                pw.SizedBox(width: 16),
                // 견적 정보
                pw.Expanded(
                  child: pw.Container(
                    padding: const pw.EdgeInsets.all(16),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('견적 정보', style: pw.TextStyle(font: fontBold, fontSize: 12)),
                        pw.SizedBox(height: 8),
                        pw.Text('견적번호: $quoteNumber', style: pw.TextStyle(font: font, fontSize: 10)),
                        pw.Text('고객명: $customerName', style: pw.TextStyle(font: font, fontSize: 10)),
                        pw.Text('고객코드: $customerCode', style: pw.TextStyle(font: font, fontSize: 10)),
                        pw.Text('유효기한: $validDate', style: pw.TextStyle(font: font, fontSize: 10)),
                        pw.Text('구분: $quoteType', style: pw.TextStyle(font: font, fontSize: 10)),
                        pw.Text('견적일: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}', 
                               style: pw.TextStyle(font: font, fontSize: 10)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            
            pw.SizedBox(height: 20),
            
            // 견적 품목 테이블
            pw.Table(
              border: pw.TableBorder.all(),
              columnWidths: {
                0: const pw.FixedColumnWidth(60),  // 순번
                1: const pw.FlexColumnWidth(2),    // 품번
                2: const pw.FlexColumnWidth(3),    // 품명
                3: const pw.FlexColumnWidth(2),    // 규격
                4: const pw.FixedColumnWidth(60),  // 수량
                5: const pw.FlexColumnWidth(1.5),  // 단가
                6: const pw.FlexColumnWidth(1.5),  // 금액
              },
              children: [
                // 헤더
                pw.TableRow(
                  decoration: const pw.BoxDecoration(
                    color: PdfColors.grey300,
                  ),
                  children: [
                    pw.Container(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text('순번', style: pw.TextStyle(font: fontBold, fontSize: 9)),
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text('품번', style: pw.TextStyle(font: fontBold, fontSize: 9)),
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text('품명', style: pw.TextStyle(font: fontBold, fontSize: 9)),
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text('규격', style: pw.TextStyle(font: fontBold, fontSize: 9)),
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text('수량', style: pw.TextStyle(font: fontBold, fontSize: 9)),
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text('단가', style: pw.TextStyle(font: fontBold, fontSize: 9)),
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text('금액', style: pw.TextStyle(font: fontBold, fontSize: 9)),
                    ),
                  ],
                ),
                
                // 품목 데이터
                ...items.asMap().entries.map((entry) {
                  final index = entry.key + 1;
                  final item = entry.value;
                  final itemTotal = item['quantity'] * item['unitPrice'];
                  
                  return pw.TableRow(
                    children: [
                      pw.Container(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('$index', style: pw.TextStyle(font: font, fontSize: 8)),
                      ),
                      pw.Container(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('${item['ERPCODE'] ?? ''}', style: pw.TextStyle(font: font, fontSize: 8)),
                      ),
                      pw.Container(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('${item['품명'] ?? ''}', style: pw.TextStyle(font: font, fontSize: 8)),
                      ),
                      pw.Container(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('${item['규격'] ?? ''}', style: pw.TextStyle(font: font, fontSize: 8)),
                      ),
                      pw.Container(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('${item['quantity']}', style: pw.TextStyle(font: font, fontSize: 8)),
                      ),
                      pw.Container(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                          NumberFormat.currency(locale: 'ko_KR', symbol: '₩').format(item['unitPrice']),
                          style: pw.TextStyle(font: font, fontSize: 8),
                        ),
                      ),
                      pw.Container(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                          NumberFormat.currency(locale: 'ko_KR', symbol: '₩').format(itemTotal),
                          style: pw.TextStyle(font: font, fontSize: 8),
                        ),
                      ),
                    ],
                  );
                }),
                
                // 합계
                pw.TableRow(
                  decoration: const pw.BoxDecoration(
                    color: PdfColors.grey200,
                  ),
                  children: [
                    pw.Container(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text('', style: pw.TextStyle(font: font, fontSize: 8)),
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text('', style: pw.TextStyle(font: font, fontSize: 8)),
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text('', style: pw.TextStyle(font: font, fontSize: 8)),
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text('', style: pw.TextStyle(font: font, fontSize: 8)),
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text('총 견적가', style: pw.TextStyle(font: fontBold, fontSize: 9)),
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text('', style: pw.TextStyle(font: font, fontSize: 8)),
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(
                        NumberFormat.currency(locale: 'ko_KR', symbol: '₩').format(totalAmount),
                        style: pw.TextStyle(font: fontBold, fontSize: 9),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            
            pw.SizedBox(height: 20),
            
            // 견적 조건
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('견적 조건:', style: pw.TextStyle(font: fontBold, fontSize: 10)),
                  pw.SizedBox(height: 8),
                  pw.Text('• 위 견적가는 VAT 포함 금액입니다.', style: pw.TextStyle(font: font, fontSize: 9)),
                  pw.Text('• 견적 유효기간: $validDate까지', style: pw.TextStyle(font: font, fontSize: 9)),
                  pw.Text('• 납기: 주문 후 7-10일 (협의 가능)', style: pw.TextStyle(font: font, fontSize: 9)),
                  pw.Text('• 결제 조건: 월말 정산 (기존 거래 고객)', style: pw.TextStyle(font: font, fontSize: 9)),
                  pw.SizedBox(height: 20),
                ],
              ),
            ),
            
            pw.SizedBox(height: 20),
            
            // 하단 서명란
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
              children: [
                pw.Container(
                  width: 150,
                  child: pw.Column(
                    children: [
                      pw.Text('견적 요청', style: pw.TextStyle(font: fontBold, fontSize: 10)),
                      pw.SizedBox(height: 30),
                      pw.Container(
                        height: 1,
                        decoration: const pw.BoxDecoration(
                          border: pw.Border(
                            bottom: pw.BorderSide(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                pw.Container(
                  width: 150,
                  child: pw.Column(
                    children: [
                      pw.Text('견적 제공', style: pw.TextStyle(font: fontBold, fontSize: 10)),
                      pw.SizedBox(height: 30),
                      pw.Container(
                        height: 1,
                        decoration: const pw.BoxDecoration(
                          border: pw.Border(
                            bottom: pw.BorderSide(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  // PDF 주문서 생성
  static Future<Uint8List> generatePDF({
    required String orderNumber,
    required String customerName,
    required String customerCode,
    required String deliveryDate,
    required String orderType,
    required List<Map<String, dynamic>> items,
    String? companyName = 'MEKICS',
    String? companyAddress = '서울시 강남구',
    String? companyPhone = '02-1234-5678',
  }) async {
    final pdf = pw.Document();
    
    // 한글 폰트 로드 (개선된 로딩)
    final font = await _loadKoreanFont();
    final fontBold = await _loadKoreanBoldFont();
    
    final totalAmount = items.fold<double>(
      0.0, 
      (sum, item) => sum + (item['quantity'] * item['unitPrice']),
    );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            // 헤더
            pw.Container(
              alignment: pw.Alignment.center,
              child: pw.Column(
                children: [
                  pw.Text(
                    '주 문 서',
                    style: pw.TextStyle(
                      font: fontBold,
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 20),
                ],
              ),
            ),
            
            // 회사 정보 및 주문 정보
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // 회사 정보
                pw.Expanded(
                  child: pw.Container(
                    padding: const pw.EdgeInsets.all(16),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('공급자', style: pw.TextStyle(font: fontBold, fontSize: 12)),
                        pw.SizedBox(height: 8),
                        pw.Text('회사명: $companyName', style: pw.TextStyle(font: font, fontSize: 10)),
                        pw.Text('주소: $companyAddress', style: pw.TextStyle(font: font, fontSize: 10)),
                        pw.Text('전화: $companyPhone', style: pw.TextStyle(font: font, fontSize: 10)),
                      ],
                    ),
                  ),
                ),
                pw.SizedBox(width: 16),
                // 주문 정보
                pw.Expanded(
                  child: pw.Container(
                    padding: const pw.EdgeInsets.all(16),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('주문 정보', style: pw.TextStyle(font: fontBold, fontSize: 12)),
                        pw.SizedBox(height: 8),
                        pw.Text('주문번호: $orderNumber', style: pw.TextStyle(font: font, fontSize: 10)),
                        pw.Text('고객명: $customerName', style: pw.TextStyle(font: font, fontSize: 10)),
                        pw.Text('고객코드: $customerCode', style: pw.TextStyle(font: font, fontSize: 10)),
                        pw.Text('출고요청일: $deliveryDate', style: pw.TextStyle(font: font, fontSize: 10)),
                        pw.Text('구분: $orderType', style: pw.TextStyle(font: font, fontSize: 10)),
                        pw.Text('주문일: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}', 
                               style: pw.TextStyle(font: font, fontSize: 10)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            
            pw.SizedBox(height: 20),
            
            // 주문 품목 테이블
            pw.Table(
              border: pw.TableBorder.all(),
              columnWidths: {
                0: const pw.FixedColumnWidth(60),  // 순번
                1: const pw.FlexColumnWidth(2),    // 품번
                2: const pw.FlexColumnWidth(3),    // 품명
                3: const pw.FlexColumnWidth(2),    // 규격
                4: const pw.FixedColumnWidth(60),  // 수량
                5: const pw.FlexColumnWidth(1.5),  // 단가
                6: const pw.FlexColumnWidth(1.5),  // 금액
              },
              children: [
                // 헤더
                pw.TableRow(
                  decoration: const pw.BoxDecoration(
                    color: PdfColors.grey300,
                  ),
                  children: [
                    pw.Container(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text('순번', style: pw.TextStyle(font: fontBold, fontSize: 9)),
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text('품번', style: pw.TextStyle(font: fontBold, fontSize: 9)),
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text('품명', style: pw.TextStyle(font: fontBold, fontSize: 9)),
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text('규격', style: pw.TextStyle(font: fontBold, fontSize: 9)),
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text('수량', style: pw.TextStyle(font: fontBold, fontSize: 9)),
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text('단가', style: pw.TextStyle(font: fontBold, fontSize: 9)),
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text('금액', style: pw.TextStyle(font: fontBold, fontSize: 9)),
                    ),
                  ],
                ),
                
                // 품목 데이터
                ...items.asMap().entries.map((entry) {
                  final index = entry.key + 1;
                  final item = entry.value;
                  final itemTotal = item['quantity'] * item['unitPrice'];
                  
                  return pw.TableRow(
                    children: [
                      pw.Container(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('$index', style: pw.TextStyle(font: font, fontSize: 8)),
                      ),
                      pw.Container(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('${item['ERPCODE'] ?? ''}', style: pw.TextStyle(font: font, fontSize: 8)),
                      ),
                      pw.Container(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('${item['품명'] ?? ''}', style: pw.TextStyle(font: font, fontSize: 8)),
                      ),
                      pw.Container(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('${item['규격'] ?? ''}', style: pw.TextStyle(font: font, fontSize: 8)),
                      ),
                      pw.Container(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('${item['quantity']}', style: pw.TextStyle(font: font, fontSize: 8)),
                      ),
                      pw.Container(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                          NumberFormat.currency(locale: 'ko_KR', symbol: '₩').format(item['unitPrice']),
                          style: pw.TextStyle(font: font, fontSize: 8),
                        ),
                      ),
                      pw.Container(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                          NumberFormat.currency(locale: 'ko_KR', symbol: '₩').format(itemTotal),
                          style: pw.TextStyle(font: font, fontSize: 8),
                        ),
                      ),
                    ],
                  );
                }),
                
                // 합계
                pw.TableRow(
                  decoration: const pw.BoxDecoration(
                    color: PdfColors.grey200,
                  ),
                  children: [
                    pw.Container(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text('', style: pw.TextStyle(font: font, fontSize: 8)),
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text('', style: pw.TextStyle(font: font, fontSize: 8)),
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text('', style: pw.TextStyle(font: font, fontSize: 8)),
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text('', style: pw.TextStyle(font: font, fontSize: 8)),
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text('합계', style: pw.TextStyle(font: fontBold, fontSize: 9)),
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text('', style: pw.TextStyle(font: font, fontSize: 8)),
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(
                        NumberFormat.currency(locale: 'ko_KR', symbol: '₩').format(totalAmount),
                        style: pw.TextStyle(font: fontBold, fontSize: 9),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            
            pw.SizedBox(height: 20),
            
            // 특이사항
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('특이사항:', style: pw.TextStyle(font: fontBold, fontSize: 10)),
                  pw.SizedBox(height: 30),
                ],
              ),
            ),
            
            pw.SizedBox(height: 20),
            
            // 하단 서명란
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
              children: [
                pw.Container(
                  width: 150,
                  child: pw.Column(
                    children: [
                      pw.Text('주문자', style: pw.TextStyle(font: fontBold, fontSize: 10)),
                      pw.SizedBox(height: 30),
                      pw.Container(
                        height: 1,
                        decoration: const pw.BoxDecoration(
                          border: pw.Border(
                            bottom: pw.BorderSide(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                pw.Container(
                  width: 150,
                  child: pw.Column(
                    children: [
                      pw.Text('공급자', style: pw.TextStyle(font: fontBold, fontSize: 10)),
                      pw.SizedBox(height: 30),
                      pw.Container(
                        height: 1,
                        decoration: const pw.BoxDecoration(
                          border: pw.Border(
                            bottom: pw.BorderSide(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  // Excel 견적서 생성 - Excel 패키지 제거로 인한 임시 비활성화
  // TODO: Syncfusion으로 교체 예정
  static Future<String> generateQuoteExcel({
    required String quoteNumber,
    required String customerName,
    required String customerCode,
    required String validDate,
    required String quoteType,
    required List<Map<String, dynamic>> items,
  }) async {
    // Excel 패키지 제거로 인한 임시 비활성화
    throw UnimplementedError('Excel 기능이 임시로 비활성화되었습니다. Syncfusion으로 교체 예정입니다.');
    
    /*
    final excel = Excel.createExcel();
    final sheet = excel['견적서'];
    
    final headerStyle = CellStyle(
      backgroundColorHex: ExcelColor.fromHexString('#4F81BD'),
      fontColorHex: ExcelColor.white,
      fontFamily: getFontFamily(FontFamily.Calibri),
    );
    
    final titleStyle = CellStyle(
      fontColorHex: ExcelColor.black,
      fontSize: 18,
      bold: true,
      horizontalAlign: HorizontalAlign.Center,
    );
    
    // 제목
    sheet.cell(CellIndex.indexByString('A1')).value = TextCellValue('견적서');
    sheet.cell(CellIndex.indexByString('A1')).cellStyle = titleStyle;
    sheet.merge(CellIndex.indexByString('A1'), CellIndex.indexByString('G1'));
    
    // 견적 정보
    sheet.cell(CellIndex.indexByString('A3')).value = TextCellValue('견적번호:');
    sheet.cell(CellIndex.indexByString('B3')).value = TextCellValue(quoteNumber);
    sheet.cell(CellIndex.indexByString('D3')).value = TextCellValue('고객명:');
    sheet.cell(CellIndex.indexByString('E3')).value = TextCellValue(customerName);
    
    sheet.cell(CellIndex.indexByString('A4')).value = TextCellValue('고객코드:');
    sheet.cell(CellIndex.indexByString('B4')).value = TextCellValue(customerCode);
    sheet.cell(CellIndex.indexByString('D4')).value = TextCellValue('유효기한:');
    sheet.cell(CellIndex.indexByString('E4')).value = TextCellValue(validDate);
    
    sheet.cell(CellIndex.indexByString('A5')).value = TextCellValue('구분:');
    sheet.cell(CellIndex.indexByString('B5')).value = TextCellValue(quoteType);
    sheet.cell(CellIndex.indexByString('D5')).value = TextCellValue('견적일:');
    sheet.cell(CellIndex.indexByString('E5')).value = TextCellValue(DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now()));
    
    // 테이블 헤더
    const headers = ['순번', '품번', '품명', '규격', '수량', '단가', '금액'];
    for (int i = 0; i < headers.length; i++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 6));
      cell.value = TextCellValue(headers[i]);
      cell.cellStyle = headerStyle;
    }
    
    // 품목 데이터
    double totalAmount = 0;
    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      final itemTotal = item['quantity'] * item['unitPrice'];
      totalAmount += itemTotal;
      
      final rowIndex = 7 + i;
      
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex)).value = IntCellValue(i + 1);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex)).value = TextCellValue(item['ERPCODE'] ?? '');
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIndex)).value = TextCellValue(item['품명'] ?? '');
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: rowIndex)).value = TextCellValue(item['규격'] ?? '');
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: rowIndex)).value = IntCellValue(item['quantity']);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: rowIndex)).value = DoubleCellValue(item['unitPrice'].toDouble());
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: rowIndex)).value = DoubleCellValue(itemTotal);
    }
    
    // 합계
    final totalRowIndex = 7 + items.length;
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: totalRowIndex)).value = TextCellValue('총 견적가:');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: totalRowIndex)).value = DoubleCellValue(totalAmount);
    
    // 견적 조건 추가
    final conditionRowIndex = totalRowIndex + 2;
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: conditionRowIndex)).value = TextCellValue('견적 조건:');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: conditionRowIndex + 1)).value = TextCellValue('• 위 견적가는 VAT 포함 금액입니다.');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: conditionRowIndex + 2)).value = TextCellValue('• 견적 유효기간: $validDate까지');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: conditionRowIndex + 3)).value = TextCellValue('• 납기: 주문 후 7-10일 (협의 가능)');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: conditionRowIndex + 4)).value = TextCellValue('• 결제 조건: 월말 정산 (기존 거래 고객)');
    
    // 파일 저장
    final directory = await getApplicationDocumentsDirectory();
    final fileName = '견적서_${quoteNumber}_${DateFormat('yyyyMMdd').format(DateTime.now())}.xlsx';
    final file = File('${directory.path}/$fileName');
    
    final fileBytes = excel.save()!;
    await file.writeAsBytes(fileBytes);
    
    return file.path;
    */
  }

  // Excel 주문서 생성 - Excel 패키지 제거로 인한 임시 비활성화
  // TODO: Syncfusion으로 교체 예정
  static Future<String> generateExcel({
    required String orderNumber,
    required String customerName,
    required String customerCode,
    required String deliveryDate,
    required String orderType,
    required List<Map<String, dynamic>> items,
  }) async {
    // Excel 패키지 제거로 인한 임시 비활성화
    throw UnimplementedError('Excel 기능이 임시로 비활성화되었습니다. Syncfusion으로 교체 예정입니다.');
    
    /*
    final excel = Excel.createExcel();
    final sheet = excel['주문서'];
    
    // 헤더 스타일
    final headerStyle = CellStyle(
      backgroundColorHex: ExcelColor.fromHexString('#4F81BD'),
      fontColorHex: ExcelColor.white,
      fontFamily: getFontFamily(FontFamily.Calibri),
    );
    
    final titleStyle = CellStyle(
      fontColorHex: ExcelColor.black,
      fontSize: 18,
      bold: true,
      horizontalAlign: HorizontalAlign.Center,
    );
    
    // 제목
    sheet.cell(CellIndex.indexByString('A1')).value = TextCellValue('주문서');
    sheet.cell(CellIndex.indexByString('A1')).cellStyle = titleStyle;
    sheet.merge(CellIndex.indexByString('A1'), CellIndex.indexByString('G1'));
    
    // 주문 정보
    sheet.cell(CellIndex.indexByString('A3')).value = TextCellValue('주문번호:');
    sheet.cell(CellIndex.indexByString('B3')).value = TextCellValue(orderNumber);
    sheet.cell(CellIndex.indexByString('D3')).value = TextCellValue('고객명:');
    sheet.cell(CellIndex.indexByString('E3')).value = TextCellValue(customerName);
    
    sheet.cell(CellIndex.indexByString('A4')).value = TextCellValue('고객코드:');
    sheet.cell(CellIndex.indexByString('B4')).value = TextCellValue(customerCode);
    sheet.cell(CellIndex.indexByString('D4')).value = TextCellValue('출고요청일:');
    sheet.cell(CellIndex.indexByString('E4')).value = TextCellValue(deliveryDate);
    
    sheet.cell(CellIndex.indexByString('A5')).value = TextCellValue('구분:');
    sheet.cell(CellIndex.indexByString('B5')).value = TextCellValue(orderType);
    sheet.cell(CellIndex.indexByString('D5')).value = TextCellValue('주문일:');
    sheet.cell(CellIndex.indexByString('E5')).value = TextCellValue(DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now()));
    
    // 테이블 헤더
    const headers = ['순번', '품번', '품명', '규격', '수량', '단가', '금액'];
    for (int i = 0; i < headers.length; i++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 6));
      cell.value = TextCellValue(headers[i]);
      cell.cellStyle = headerStyle;
    }
    
    // 품목 데이터
    double totalAmount = 0;
    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      final itemTotal = item['quantity'] * item['unitPrice'];
      totalAmount += itemTotal;
      
      final rowIndex = 7 + i;
      
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex)).value = IntCellValue(i + 1);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex)).value = TextCellValue(item['ERPCODE'] ?? '');
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIndex)).value = TextCellValue(item['품명'] ?? '');
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: rowIndex)).value = TextCellValue(item['규격'] ?? '');
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: rowIndex)).value = IntCellValue(item['quantity']);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: rowIndex)).value = DoubleCellValue(item['unitPrice'].toDouble());
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: rowIndex)).value = DoubleCellValue(itemTotal);
    }
    
    // 합계
    final totalRowIndex = 7 + items.length;
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: totalRowIndex)).value = TextCellValue('합계:');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: totalRowIndex)).value = DoubleCellValue(totalAmount);
    
    // 파일 저장
    final directory = await getApplicationDocumentsDirectory();
    final fileName = '주문서_${orderNumber}_${DateFormat('yyyyMMdd').format(DateTime.now())}.xlsx';
    final file = File('${directory.path}/$fileName');
    
    final fileBytes = excel.save()!;
    await file.writeAsBytes(fileBytes);
    
    return file.path;
    */
  }

  // PDF 미리보기
  static Future<void> previewPDF(Uint8List pdfData) async {
    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdfData);
  }

  // PDF 공유
  static Future<void> sharePDF(Uint8List pdfData, String fileName) async {
    await Printing.sharePdf(bytes: pdfData, filename: fileName);
  }
}