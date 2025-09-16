// Syncfusion XlsIO로 교체 완료
import 'dart:io';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xlsio;
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:universal_html/html.dart' as html;
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;

class InvoiceService {
  // 모든 기능 비활성화
  static const String _companyName = 'MEKICS';
  static const String _companyAddress = 'Seoul, South Korea';
  static const String _companyPhone = '+82-2-XXX-XXXX';
  static const String _companyEmail = 'info@mekics.com';

  /// 템플릿 Workbook 로드 (Syncfusion)
  static Future<xlsio.Workbook> _loadTemplate(String templateName) async {
    try {
      // Syncfusion은 바이트에서 로드를 지원하지 않으므로 새 워크북 생성
      debugPrint('새 워크북 생성: $templateName');
      return xlsio.Workbook();
    } catch (e) {
      debugPrint('템플릿 로드 실패, 새 워크북 생성: $e');
      return xlsio.Workbook();
    }
  }

  /// Proforma Invoice 생성 (Syncfusion)
  static Future<void> generateProformaInvoice({
    required String customerName,
    required String customerAddress,
    required String customerContact,
    required List<Map<String, dynamic>> items,
    required String invoiceNumber,
    required DateTime invoiceDate,
    required DateTime validUntil,
    String? remarks,
  }) async {
    final workbook = xlsio.Workbook();
    final worksheet = workbook.worksheets[0];
    worksheet.name = 'Proforma Invoice';
    
    await _buildInvoiceSheet(
      worksheet: worksheet,
      invoiceType: 'PROFORMA INVOICE',
      customerName: customerName,
      customerAddress: customerAddress,
      customerContact: customerContact,
      items: items,
      invoiceNumber: invoiceNumber,
      invoiceDate: invoiceDate,
      validUntil: validUntil,
      remarks: remarks,
      isProforma: true,
    );
    
    await _saveAndDownloadExcel(workbook, 'Proforma_Invoice_$invoiceNumber.xlsx');
  }

  /// Commercial Invoice 생성 (Syncfusion)
  static Future<void> generateCommercialInvoice({
    required String customerName,
    required String customerAddress,
    required String customerContact,
    required List<Map<String, dynamic>> items,
    required String invoiceNumber,
    required DateTime invoiceDate,
    required DateTime dueDate,
    String? paymentTerms,
    String? shippingTerms,
    String? remarks,
  }) async {
    final workbook = xlsio.Workbook();
    final worksheet = workbook.worksheets[0];
    worksheet.name = 'Commercial Invoice';
    
    await _buildInvoiceSheet(
      worksheet: worksheet,
      invoiceType: 'COMMERCIAL INVOICE',
      customerName: customerName,
      customerAddress: customerAddress,
      customerContact: customerContact,
      items: items,
      invoiceNumber: invoiceNumber,
      invoiceDate: invoiceDate,
      validUntil: dueDate,
      remarks: remarks,
      isProforma: false,
      paymentTerms: paymentTerms,
      shippingTerms: shippingTerms,
    );
    
    await _saveAndDownloadExcel(workbook, 'Commercial_Invoice_$invoiceNumber.xlsx');
  }

  /// Invoice Sheet 구성 (Syncfusion)
  static Future<void> _buildInvoiceSheet({
    required xlsio.Worksheet worksheet,
    required String invoiceType,
    required String customerName,
    required String customerAddress,
    required String customerContact,
    required List<Map<String, dynamic>> items,
    required String invoiceNumber,
    required DateTime invoiceDate,
    required DateTime validUntil,
    String? remarks,
    bool isProforma = true,
    String? paymentTerms,
    String? shippingTerms,
  }) async {
    int currentRow = 1; // Syncfusion은 1-based 인덱스
    
    // 1. 회사 헤더
    _setMergedCell(worksheet, currentRow, 1, currentRow, 6, _companyName, 
      fontSize: 24, isBold: true);
    
    currentRow++;
    _setCell(worksheet, currentRow, 1, _companyAddress, fontSize: 12);
    currentRow++;
    _setCell(worksheet, currentRow, 1, 'Tel: $_companyPhone | Email: $_companyEmail', fontSize: 12);
    
    currentRow += 2;
    
    // 2. Invoice 타이틀
    _setMergedCell(worksheet, currentRow, 1, currentRow, 6, invoiceType,
      fontSize: 20, isBold: true);
    
    currentRow += 2;
    
    // 3. Invoice 정보
    _setCell(worksheet, currentRow, 1, 'Invoice Number:', isBold: true);
    _setCell(worksheet, currentRow, 2, invoiceNumber);
    _setCell(worksheet, currentRow, 4, 'Invoice Date:', isBold: true);
    _setCell(worksheet, currentRow, 5, DateFormat('yyyy-MM-dd').format(invoiceDate));
    
    currentRow++;
    
    String validLabel = isProforma ? 'Valid Until:' : 'Due Date:';
    _setCell(worksheet, currentRow, 1, validLabel, isBold: true);
    _setCell(worksheet, currentRow, 2, DateFormat('yyyy-MM-dd').format(validUntil));
    
    if (!isProforma && paymentTerms != null) {
      _setCell(worksheet, currentRow, 4, 'Payment Terms:', isBold: true);
      _setCell(worksheet, currentRow, 5, paymentTerms);
    }
    
    currentRow += 2;
    
    // 4. 고객 정보
    _setCell(worksheet, currentRow, 1, 'Bill To:', isBold: true, fontSize: 14);
    currentRow++;
    _setCell(worksheet, currentRow, 1, customerName, isBold: true);
    currentRow++;
    _setCell(worksheet, currentRow, 1, customerAddress);
    currentRow++;
    _setCell(worksheet, currentRow, 1, customerContact);
    
    currentRow += 2;
    
    // 5. 상품 테이블 헤더
    final headers = ['Item', 'Description', 'Qty', 'Unit Price', 'Amount'];
    for (int i = 0; i < headers.length; i++) {
      _setCell(worksheet, currentRow, i + 1, headers[i], isBold: true);
    }
    
    currentRow++;
    
    // 6. 상품 목록
    double subtotal = 0.0;
    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      final qty = (item['quantity'] ?? 0).toDouble();
      final unitPrice = (item['unitPrice'] ?? 0).toDouble();
      final amount = qty * unitPrice;
      subtotal += amount;
      
      _setCell(worksheet, currentRow, 1, item['ERPCODE'] ?? '');
      _setCell(worksheet, currentRow, 2, item['itemName'] ?? '');
      _setCell(worksheet, currentRow, 3, qty.toStringAsFixed(0));
      _setCell(worksheet, currentRow, 4, _formatCurrency(unitPrice));
      _setCell(worksheet, currentRow, 5, _formatCurrency(amount));
      
      currentRow++;
    }
    
    // 7. 합계 섹션
    currentRow++;
    _setCell(worksheet, currentRow, 4, 'Subtotal:', isBold: true);
    _setCell(worksheet, currentRow, 5, _formatCurrency(subtotal));
    
    currentRow++;
    final taxRate = 0.1; // 10% VAT
    final taxAmount = subtotal * taxRate;
    _setCell(worksheet, currentRow, 4, 'VAT (10%):', isBold: true);
    _setCell(worksheet, currentRow, 5, _formatCurrency(taxAmount));
    
    currentRow++;
    final total = subtotal + taxAmount;
    _setCell(worksheet, currentRow, 4, 'Total:', isBold: true);
    _setCell(worksheet, currentRow, 5, _formatCurrency(total), isBold: true);
    
    // 8. 추가 조건 (Commercial Invoice용)
    if (!isProforma) {
      currentRow += 2;
      if (shippingTerms != null) {
        _setCell(worksheet, currentRow, 1, 'Shipping Terms:', isBold: true);
        _setCell(worksheet, currentRow, 2, shippingTerms);
        currentRow++;
      }
    }
    
    // 9. 비고
    if (remarks != null && remarks.isNotEmpty) {
      currentRow += 2;
      _setCell(worksheet, currentRow, 1, 'Remarks:', isBold: true);
      currentRow++;
      _setCell(worksheet, currentRow, 1, remarks);
    }
    
    // 10. 하단 서명 공간
    currentRow += 3;
    _setCell(worksheet, currentRow, 1, 'Authorized Signature:', isBold: true);
    _setCell(worksheet, currentRow, 4, 'Customer Signature:', isBold: true);
    
    // 11. 컬럼 너비 조정
    worksheet.setColumnWidthInPixels(1, 120); // Item
    worksheet.setColumnWidthInPixels(2, 200); // Description
    worksheet.setColumnWidthInPixels(3, 80);  // Qty
    worksheet.setColumnWidthInPixels(4, 120); // Unit Price
    worksheet.setColumnWidthInPixels(5, 120); // Amount
  }

  /// Excel 셀 설정 헬퍼 메서드 (Syncfusion)
  static void _setCell(xlsio.Worksheet worksheet, int row, int col, dynamic value, {
    bool isBold = false,
    int fontSize = 11,
    String? backgroundColor,
  }) {
    try {
      final range = worksheet.getRangeByIndex(row, col);
      range.setText(value.toString());
      
      // 스타일 적용
      if (isBold) {
        range.cellStyle.bold = true;
      }
      
      if (fontSize != 11) {
        range.cellStyle.fontSize = fontSize.toDouble();
      }
      
      // 배경색 적용 (간단한 색상만)
      if (backgroundColor != null) {
        // Syncfusion에서 지원하는 기본 색상들
        if (backgroundColor == '#E8F4FD' || backgroundColor == '#D9E2F3') {
          range.cellStyle.backColor = '#E8F4FD';
        } else if (backgroundColor == '#FFE699') {
          range.cellStyle.backColor = '#FFE699';
        }
      }
    } catch (e) {
      debugPrint('셀 설정 실패 ($row,$col): $e');
    }
  }

  /// 병합 셀 설정 (Syncfusion)
  static void _setMergedCell(xlsio.Worksheet worksheet, int startRow, int startCol, int endRow, int endCol, String value, {
    bool isBold = false,
    int fontSize = 11,
  }) {
    try {
      final range = worksheet.getRangeByIndex(startRow, startCol, endRow, endCol);
      range.merge();
      range.setText(value);
      
      // 스타일 적용
      if (isBold) {
        range.cellStyle.bold = true;
      }
      
      if (fontSize != 11) {
        range.cellStyle.fontSize = fontSize.toDouble();
      }
      
      // 중앙 정렬
      range.cellStyle.hAlign = xlsio.HAlignType.center;
      range.cellStyle.vAlign = xlsio.VAlignType.center;
      
    } catch (e) {
      debugPrint('병합 셀 설정 실패: $e');
      // 병합 실패 시 일반 셀로 설정
      _setCell(worksheet, startRow, startCol, value, isBold: isBold, fontSize: fontSize);
    }
  }

  /// 통화 형식 포맷팅
  static String _formatCurrency(double amount) {
    return NumberFormat.currency(locale: 'en_US', symbol: '\$').format(amount);
  }

  /// Excel 파일 저장 및 다운로드 (Syncfusion)
  static Future<void> _saveAndDownloadExcel(xlsio.Workbook workbook, String filename) async {
    try {
      final List<int> bytes = workbook.saveAsStream();
      
      if (kIsWeb) {
        // 웹에서는 직접 다운로드
        final blob = html.Blob([bytes]);
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.AnchorElement()
          ..href = url
          ..style.display = 'none'
          ..download = filename;
        html.document.body?.children.add(anchor);
        anchor.click();
        html.document.body?.children.remove(anchor);
        html.Url.revokeObjectUrl(url);
      } else {
        // 모바일/데스크톱에서는 파일 시스템에 저장
        final directory = await getApplicationDocumentsDirectory();
        final file = File('${directory.path}/$filename');
        await file.writeAsBytes(bytes);
      }
      
      // 워크북 정리
      workbook.dispose();
    } catch (e) {
      debugPrint('Excel 저장 실패: $e');
      workbook.dispose(); // 오류 발생 시에도 리소스 정리
    }
  }

  /// 주문 데이터로부터 Invoice 아이템 변환
  static List<Map<String, dynamic>> convertCartToInvoiceItems(List<Map<String, dynamic>> cartItems) {
    return cartItems.map((item) => {
      'ERPCODE': item['ERPCODE'] ?? '',
      'itemName': item['itemName'] ?? '',
      'quantity': item['quantity'] ?? 0,
      'unitPrice': item['unitPrice'] ?? 0.0,
      'specification': item['specification'] ?? '',
    }).toList();
  }

  /// Invoice 번호 생성
  static String generateInvoiceNumber({bool isProforma = true}) {
    final prefix = isProforma ? 'PI' : 'CI';
    final timestamp = DateTime.now();
    final dateStr = DateFormat('yyyyMMdd').format(timestamp);
    final timeStr = DateFormat('HHmmss').format(timestamp);
    return '$prefix-$dateStr-$timeStr';
  }
}