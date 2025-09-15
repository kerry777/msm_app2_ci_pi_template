import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xlsio;
import 'package:universal_html/html.dart' as html;
import 'package:flutter/foundation.dart' show kIsWeb;

class SyncfusionExcelViewerScreen extends StatefulWidget {
  const SyncfusionExcelViewerScreen({super.key});

  @override
  State<SyncfusionExcelViewerScreen> createState() => _SyncfusionExcelViewerScreenState();
}

class _SyncfusionExcelViewerScreenState extends State<SyncfusionExcelViewerScreen> {
  xlsio.Workbook? _workbook;
  xlsio.Worksheet? _worksheet;
  String? _selectedTemplate;
  bool _isLoading = false;
  String? _error;
  
  // 편집 관련
  int? _selectedRow;
  int? _selectedCol;
  bool _isEditingMode = false;
  final TextEditingController _cellController = TextEditingController();
  
  // 셀 데이터 캐시
  final Map<String, String> _cellData = {};
  
  final List<Map<String, String>> _availableTemplates = [
    {
      'name': 'Commercial Invoice (CI)',
      'file': 'MEK_SALES_TEMPLATE_CI.xlsx',
      'description': '상업 인보이스 - Syncfusion 버전'
    },
    {
      'name': 'Proforma Invoice (PI)',
      'file': 'MEK_SALES_TEMPLATE_PI.xlsx',
      'description': '견적 인보이스 - Syncfusion 버전'
    },
    {
      'name': 'Packing List (PL)',
      'file': 'MEK_SALES_TEMPLATE_PL.xlsx',
      'description': '포장 명세서 - Syncfusion 버전'
    },
    {
      'name': 'Quote Korean (QT-KR)',
      'file': 'MEK_SALES_TEMPLATE_QT_KR.xlsx',
      'description': '견적서 - 한국어 버전'
    },
    {
      'name': 'Quote English (QT-EN)',
      'file': 'MEK_SALES_TEMPLATE_QT_EN.xlsx',
      'description': '견적서 - 영어 버전'
    },
    {
      'name': 'Quote After Service (QT-AS)',
      'file': 'MEK_SALES_TEMPLATE_QT_AS.xlsx',
      'description': '견적서 - 애프터서비스'
    },
  ];

  Future<void> _loadTemplate(String templateFile) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      print('Syncfusion 실제 템플릿 로드 시작: $templateFile');
      
      // 실제 assets 파일에서 Excel 로드 시도
      try {
        print('🔍 assets/$templateFile 파일 로드 시도...');
        final byteData = await rootBundle.load('assets/$templateFile');
        final bytes = byteData.buffer.asUint8List();
        print('✅ 파일 로드 성공! 크기: ${bytes.length} bytes');
        
        // Syncfusion으로 실제 파일 로드
        _workbook = xlsio.Workbook.fromBytes(bytes);
        print('✅ Syncfusion Workbook 생성 성공!');
        
        // 첫 번째 워크시트 선택
        if (_workbook!.worksheets.count > 0) {
          _worksheet = _workbook!.worksheets[0];
          print('✅ 워크시트 선택: ${_worksheet!.name} (총 ${_workbook!.worksheets.count}개 시트)');
          
          // 실제 데이터를 캐시에 로드
          _loadActualDataToCache();
        } else {
          throw Exception('워크시트가 없습니다');
        }
        
      } catch (assetError) {
        print('실제 파일 로드 실패, 대체 템플릿 생성: $assetError');
        
        // 실제 파일 로드 실패 시 대체 템플릿 생성
        _workbook = xlsio.Workbook();
        _worksheet = _workbook!.worksheets[0];
      
      // 워크시트 이름 설정
      _worksheet!.name = _getTemplateSheetName(templateFile);
      
      // 템플릿별 데이터 생성
      _createSyncfusionTemplate(templateFile);
      
      print('✅ Syncfusion Workbook 생성 성공! 워크시트: ${_worksheet!.name}');
      
      setState(() {
        _selectedTemplate = templateFile;
        _isLoading = false;
      });
      
      print('Syncfusion 템플릿 로드 완료: $templateFile');
      
    } catch (e) {
      print('Syncfusion 템플릿 로드 실패: $e');
      setState(() {
        _error = '템플릿 로드 실패: $e';
        _isLoading = false;
      });
    }
  }
  
  String _getTemplateSheetName(String templateFile) {
    switch (templateFile) {
      case 'MEK_SALES_TEMPLATE_CI.xlsx':
        return 'Commercial Invoice';
      case 'MEK_SALES_TEMPLATE_PI.xlsx':
        return 'Proforma Invoice';
      case 'MEK_SALES_TEMPLATE_PL.xlsx':
        return 'Packing List';
      case 'MEK_SALES_TEMPLATE_QT_KR.xlsx':
        return 'Quote Korean';
      case 'MEK_SALES_TEMPLATE_QT_EN.xlsx':
        return 'Quote English';
      case 'MEK_SALES_TEMPLATE_QT_AS.xlsx':
        return 'Quote After Service';
      default:
        return 'Syncfusion Template';
    }
  }
  
  void _createSyncfusionTemplate(String templateFile) {
    if (_worksheet == null) return;
    
    // 캐시 초기화
    _cellData.clear();
    
    switch (templateFile) {
      case 'MEK_SALES_TEMPLATE_CI.xlsx':
        _createCommercialInvoiceSyncfusion();
        break;
      case 'MEK_SALES_TEMPLATE_PI.xlsx':
        _createProformaInvoiceSyncfusion();
        break;
      case 'MEK_SALES_TEMPLATE_PL.xlsx':
        _createPackingListSyncfusion();
        break;
      case 'MEK_SALES_TEMPLATE_QT_KR.xlsx':
        _createQuoteKoreanSyncfusion();
        break;
      case 'MEK_SALES_TEMPLATE_QT_EN.xlsx':
        _createQuoteEnglishSyncfusion();
        break;
      case 'MEK_SALES_TEMPLATE_QT_AS.xlsx':
        _createQuoteAfterServiceSyncfusion();
        break;
      default:
        _createGenericTemplateSyncfusion(templateFile);
    }
  }
  
  void _createCommercialInvoiceSyncfusion() {
    // 회사 정보
    _setCellValue(1, 1, 'MEKICS CO., LTD.');
    _setCellValue(2, 1, 'Seoul, South Korea');
    _setCellValue(3, 1, 'Tel: +82-2-XXX-XXXX');
    
    // 제목
    _setCellValue(5, 1, 'COMMERCIAL INVOICE');
    
    // 인보이스 정보
    _setCellValue(7, 1, 'Invoice No:');
    _setCellValue(7, 3, 'CI-${DateTime.now().toString().substring(0, 10).replaceAll('-', '')}');
    _setCellValue(8, 1, 'Date:');
    _setCellValue(8, 3, DateTime.now().toString().substring(0, 10));
    _setCellValue(9, 1, 'Due Date:');
    
    // 고객 정보
    _setCellValue(11, 1, 'Bill To:');
    _setCellValue(12, 1, '[Customer Name]');
    _setCellValue(13, 1, '[Customer Address]');
    
    // 테이블 헤더
    _setCellValue(15, 1, 'Item Code');
    _setCellValue(15, 2, 'Description');
    _setCellValue(15, 3, 'Quantity');
    _setCellValue(15, 4, 'Unit Price');
    _setCellValue(15, 5, 'Total Amount');
    
    // 샘플 데이터
    _setCellValue(16, 1, 'SAMPLE001');
    _setCellValue(16, 2, 'Sample Product Description');
    _setCellValue(16, 3, '1');
    _setCellValue(16, 4, '\$100.00');
    _setCellValue(16, 5, '\$100.00');
    
    // 합계
    _setCellValue(18, 4, 'Subtotal:');
    _setCellValue(18, 5, '\$100.00');
    _setCellValue(19, 4, 'VAT (10%):');
    _setCellValue(19, 5, '\$10.00');
    _setCellValue(20, 4, 'Total:');
    _setCellValue(20, 5, '\$110.00');
  }
  
  void _createProformaInvoiceSyncfusion() {
    // 회사 정보
    _setCellValue(1, 1, 'MEKICS CO., LTD.');
    _setCellValue(2, 1, 'Seoul, South Korea');
    _setCellValue(3, 1, 'Tel: +82-2-XXX-XXXX');
    
    // 제목
    _setCellValue(5, 1, 'PROFORMA INVOICE');
    
    // 인보이스 정보
    _setCellValue(7, 1, 'Invoice No:');
    _setCellValue(7, 3, 'PI-${DateTime.now().toString().substring(0, 10).replaceAll('-', '')}');
    _setCellValue(8, 1, 'Date:');
    _setCellValue(8, 3, DateTime.now().toString().substring(0, 10));
    _setCellValue(9, 1, 'Valid Until:');
    
    // 고객 정보
    _setCellValue(11, 1, 'Quote To:');
    _setCellValue(12, 1, '[Customer Name]');
    _setCellValue(13, 1, '[Customer Address]');
    
    // 테이블 헤더
    _setCellValue(15, 1, 'Item Code');
    _setCellValue(15, 2, 'Description');
    _setCellValue(15, 3, 'Quantity');
    _setCellValue(15, 4, 'Unit Price');
    _setCellValue(15, 5, 'Total Amount');
  }
  
  void _createPackingListSyncfusion() {
    _setCellValue(1, 1, 'MEKICS CO., LTD.');
    _setCellValue(2, 1, 'PACKING LIST');
    _setCellValue(4, 1, 'Item');
    _setCellValue(4, 2, 'Description');
    _setCellValue(4, 3, 'Quantity');
    _setCellValue(4, 4, 'Weight');
  }
  
  void _createQuoteKoreanSyncfusion() {
    _setCellValue(1, 1, '메키스 주식회사');
    _setCellValue(2, 1, '견 적 서');
    _setCellValue(4, 1, '품목');
    _setCellValue(4, 2, '규격');
    _setCellValue(4, 3, '수량');
    _setCellValue(4, 4, '단가');
    _setCellValue(4, 5, '금액');
  }
  
  void _createQuoteEnglishSyncfusion() {
    _setCellValue(1, 1, 'MEKICS CO., LTD.');
    _setCellValue(2, 1, 'QUOTATION');
    _setCellValue(4, 1, 'Item');
    _setCellValue(4, 2, 'Specification');
    _setCellValue(4, 3, 'Quantity');
    _setCellValue(4, 4, 'Unit Price');
    _setCellValue(4, 5, 'Amount');
  }
  
  void _createQuoteAfterServiceSyncfusion() {
    _setCellValue(1, 1, 'MEKICS CO., LTD.');
    _setCellValue(2, 1, 'AFTER SERVICE QUOTATION');
    _setCellValue(4, 1, 'Service Item');
    _setCellValue(4, 2, 'Description');
    _setCellValue(4, 3, 'Hours');
    _setCellValue(4, 4, 'Rate');
    _setCellValue(4, 5, 'Amount');
  }
  
  void _createGenericTemplateSyncfusion(String templateFile) {
    _setCellValue(1, 1, 'MEKICS CO., LTD.');
    _setCellValue(2, 1, templateFile.replaceAll('.xlsx', ''));
    _setCellValue(3, 1, 'Syncfusion XlsIO Generated: ${DateTime.now()}');
  }
  
  void _loadActualDataToCache() {
    if (_worksheet == null) return;
    
    // 캐시 초기화
    _cellData.clear();
    
    try {
      // 생성된 템플릿 데이터를 캐시에 로드 (기본 30x15 범위)
      final maxRows = 30;
      final maxCols = 15;
      print('📋 템플릿 데이터 로드 범위: $maxRows행 x $maxCols열');
      
      for (int row = 1; row <= maxRows; row++) {
        for (int col = 1; col <= maxCols; col++) {
          try {
            final cellValue = _worksheet!.getRangeByIndex(row, col).text;
            if (cellValue != null && cellValue.isNotEmpty) {
              // Syncfusion은 1-based, 캐시는 0-based
              _cellData['${row-1},${col-1}'] = cellValue;
            }
          } catch (e) {
            // 개별 셀 로드 실패 시 무시하고 계속
            // print('셀 ($row,$col) 로드 실패: $e');
          }
        }
      }
      
      print('🎯 템플릿 데이터 ${_cellData.length}개 셀을 캐시에 로드 완료!');
      
      // 로드된 데이터 샘플 출력
      if (_cellData.isNotEmpty) {
        print('📝 샘플 데이터:');
        _cellData.entries.take(5).forEach((entry) {
          print('   셀 ${entry.key}: "${entry.value}"');
        });
      }
    } catch (e) {
      print('템플릿 데이터 로드 중 오류: $e');
      // 오류 발생 시 기본 템플릿 데이터라도 유지
    }
  }
  
  void _setCellValue(int row, int col, String value) {
    try {
      // Syncfusion은 1부터 시작하는 인덱스 사용
      if (_worksheet != null) {
        _worksheet!.getRangeByIndex(row, col).setText(value);
        // 캐시에 저장
        _cellData['${row-1},${col-1}'] = value;
      }
    } catch (e) {
      print('셀 값 설정 오류 ($row,$col): $e');
    }
  }
  
  String _getCellValue(int row, int col) {
    // 0-based 인덱스를 캐시 키로 사용
    return _cellData['$row,$col'] ?? '';
  }
  
  void _updateCellValue(int row, int col, String value) {
    try {
      // Syncfusion은 1-based 인덱스 사용
      if (_worksheet != null) {
        _worksheet!.getRangeByIndex(row + 1, col + 1).setText(value);
        // 캐시 업데이트
        _cellData['$row,$col'] = value;
      }
    } catch (e) {
      print('셀 값 업데이트 오류: $e');
    }
  }
  
  // 키보드 이벤트 처리
  bool _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      final key = event.logicalKey;
      
      if (_selectedRow != null && _selectedCol != null) {
        // 편집 모드 토글 (F2 키)
        if (key == LogicalKeyboardKey.f2) {
          _toggleEditMode();
          return true;
        }
        
        // 편집 모드가 아닐 때만 셀 이동
        if (!_isEditingMode) {
          return _handleCellNavigation(key);
        }
      }
    }
    return false;
  }
  
  bool _handleCellNavigation(LogicalKeyboardKey key) {
    if (_selectedRow == null || _selectedCol == null) return false;
    
    int newRow = _selectedRow!;
    int newCol = _selectedCol!;
    
    // 동적 그리드 크기 계산
    int maxRow = 29; // 기본값
    int maxCol = 14; // 기본값
    
    // 캐시된 데이터를 기반으로 네비게이션 범위 설정
    if (_cellData.isNotEmpty) {
      int dataMaxRow = 0;
      int dataMaxCol = 0;
      
      for (String key in _cellData.keys) {
        final parts = key.split(',');
        if (parts.length == 2) {
          final row = int.tryParse(parts[0]) ?? 0;
          final col = int.tryParse(parts[1]) ?? 0;
          if (row > dataMaxRow) dataMaxRow = row;
          if (col > dataMaxCol) dataMaxCol = col;
        }
      }
      
      maxRow = (dataMaxRow + 10).clamp(19, 49);
      maxCol = (dataMaxCol + 5).clamp(9, 24);
    }
    
    // 키에 따른 이동
    switch (key) {
      case LogicalKeyboardKey.arrowUp:
        newRow = (newRow - 1).clamp(0, maxRow);
        break;
      case LogicalKeyboardKey.arrowDown:
        newRow = (newRow + 1).clamp(0, maxRow);
        break;
      case LogicalKeyboardKey.arrowLeft:
        newCol = (newCol - 1).clamp(0, maxCol);
        break;
      case LogicalKeyboardKey.arrowRight:
        newCol = (newCol + 1).clamp(0, maxCol);
        break;
      case LogicalKeyboardKey.enter:
        newRow = (newRow + 1).clamp(0, maxRow);
        break;
      case LogicalKeyboardKey.tab:
        newCol = (newCol + 1).clamp(0, maxCol);
        break;
      default:
        return false;
    }

    // 셀 이동
    setState(() {
      _selectedRow = newRow;
      _selectedCol = newCol;
      _updateCellController();
    });
    
    return true;
  }

  void _toggleEditMode() {
    setState(() {
      _isEditingMode = !_isEditingMode;
    });
    
    if (_isEditingMode) {
      _showCellEditor(_selectedRow!, _selectedCol!, _cellController.text);
    }
  }

  void _updateCellController() {
    if (_selectedRow != null && _selectedCol != null) {
      _cellController.text = _getCellValue(_selectedRow!, _selectedCol!);
    }
  }

  void _showCellEditor(int row, int col, String currentValue) {
    showDialog(
      context: context,
      builder: (context) {
        final controller = TextEditingController(text: currentValue);
        return AlertDialog(
          title: Text('셀 편집 (${String.fromCharCode(65 + col)}${row + 1})'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: '값을 입력하세요',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: () {
                _updateCellValue(row, col, controller.text);
                setState(() {
                  _isEditingMode = false;
                });
                Navigator.pop(context);
              },
              child: const Text('저장'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _downloadExcel() async {
    if (_workbook == null) return;
    
    try {
      final List<int> bytes = _workbook!.saveAsStream();
      final String fileName = '${_selectedTemplate?.replaceAll('.xlsx', '') ?? 'syncfusion_template'}_${DateTime.now().toString().substring(0, 10)}.xlsx';
      
      if (kIsWeb) {
        // 웹에서는 직접 다운로드
        final blob = html.Blob([bytes]);
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.AnchorElement()
          ..href = url
          ..style.display = 'none'
          ..download = fileName;
        html.document.body?.children.add(anchor);
        anchor.click();
        html.document.body?.children.remove(anchor);
        html.Url.revokeObjectUrl(url);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Excel 파일이 다운로드되었습니다: $fileName')),
        );
      }
    } catch (e) {
      print('Excel 다운로드 실패: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Excel 다운로드 실패: $e')),
      );
    }
  }

  Widget _buildTemplateSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.integration_instructions, color: Colors.orange),
                const SizedBox(width: 8),
                Text(
                  'Syncfusion Excel 템플릿 선택',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _availableTemplates.map((template) {
                final isSelected = _selectedTemplate == template['file'];
                return SizedBox(
                  width: 280,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : () => _loadTemplate(template['file']!),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isSelected ? Colors.orange : Colors.grey[100],
                      foregroundColor: isSelected ? Colors.white : Colors.black87,
                      padding: const EdgeInsets.all(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          template['name']!,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          template['description']!,
                          style: TextStyle(
                            fontSize: 12,
                            color: isSelected ? Colors.white70 : Colors.grey[600],
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSyncfusionExcelGrid() {
    if (_worksheet == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Center(
            child: Text('템플릿을 선택하세요'),
          ),
        ),
      );
    }

    // 동적 그리드 크기 계산 (실제 데이터 기반)
    int maxRows = 30; // 기본값
    int maxCols = 15; // 기본값
    
    // 캐시된 데이터를 기반으로 실제 필요한 크기 계산
    if (_cellData.isNotEmpty) {
      int dataMaxRow = 0;
      int dataMaxCol = 0;
      
      for (String key in _cellData.keys) {
        final parts = key.split(',');
        if (parts.length == 2) {
          final row = int.tryParse(parts[0]) ?? 0;
          final col = int.tryParse(parts[1]) ?? 0;
          if (row > dataMaxRow) dataMaxRow = row;
          if (col > dataMaxCol) dataMaxCol = col;
        }
      }
      
      // 실제 데이터 크기에 여유분 추가
      maxRows = (dataMaxRow + 10).clamp(20, 50);
      maxCols = (dataMaxCol + 5).clamp(10, 25);
      
      print('동적 그리드 크기: ${maxRows}x$maxCols (데이터 기반: ${dataMaxRow+1}x${dataMaxCol+1})');
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Syncfusion Excel 뷰어: ${_worksheet!.name}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                ElevatedButton.icon(
                  onPressed: _downloadExcel,
                  icon: const Icon(Icons.download),
                  label: const Text('Excel 다운로드'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SingleChildScrollView(
                  child: Table(
                    border: TableBorder.all(color: Colors.grey[300]!),
                    columnWidths: Map.fromEntries(
                      List.generate(maxCols + 1, (index) => 
                        MapEntry(index, const FixedColumnWidth(120))),
                    ),
                    children: [
                      // 헤더 행
                      TableRow(
                        decoration: BoxDecoration(color: Colors.grey[100]),
                        children: [
                          const TableCell(
                            child: SizedBox(
                              height: 30,
                              child: Center(child: Text('')),
                            ),
                          ),
                          ...List.generate(maxCols, (col) =>
                            TableCell(
                              child: SizedBox(
                                height: 30,
                                child: Center(
                                  child: Text(
                                    String.fromCharCode(65 + col),
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      // 데이터 행들
                      ...List.generate(maxRows, (row) =>
                        TableRow(
                          children: [
                            TableCell(
                              child: Container(
                                height: 30,
                                decoration: BoxDecoration(color: Colors.grey[100]),
                                child: Center(
                                  child: Text(
                                    '${row + 1}',
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                            ),
                            ...List.generate(maxCols, (col) {
                              final isSelected = _selectedRow == row && _selectedCol == col;
                              final cellValue = _getCellValue(row, col);
                              
                              return TableCell(
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _selectedRow = row;
                                      _selectedCol = col;
                                      _updateCellController();
                                    });
                                  },
                                  onDoubleTap: () {
                                    setState(() {
                                      _selectedRow = row;
                                      _selectedCol = col;
                                      _updateCellController();
                                    });
                                    _toggleEditMode();
                                  },
                                  child: Container(
                                    height: 30,
                                    padding: const EdgeInsets.symmetric(horizontal: 4),
                                    decoration: BoxDecoration(
                                      color: isSelected ? Colors.blue[100] : Colors.white,
                                      border: isSelected 
                                        ? Border.all(color: Colors.blue, width: 2)
                                        : null,
                                    ),
                                    child: Center(
                                      child: Text(
                                        cellValue,
                                        style: const TextStyle(fontSize: 12),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (_selectedRow != null && _selectedCol != null) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Text(
                    '선택된 셀: ${String.fromCharCode(65 + _selectedCol!)}${_selectedRow! + 1}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      controller: _cellController,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        hintText: '셀 값',
                      ),
                      onSubmitted: (value) {
                        _updateCellValue(_selectedRow!, _selectedCol!, value);
                        setState(() {});
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      _updateCellValue(_selectedRow!, _selectedCol!, _cellController.text);
                      setState(() {});
                    },
                    child: const Text('적용'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: FocusNode(),
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Syncfusion Excel 템플릿 뷰어'),
          backgroundColor: Colors.orange,
          foregroundColor: Colors.white,
          actions: [
            if (_workbook != null) ...[
              IconButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Syncfusion 키보드 단축키'),
                      content: const Text(
                        '• 화살표 키: 셀 이동\n'
                        '• Enter: 아래로 이동\n'
                        '• Tab: 오른쪽으로 이동\n'
                        '• F2: 편집 모드\n'
                        '• 더블클릭: 셀 편집\n'
                        '• 단순클릭: 셀 선택\n\n'
                        '🟠 Syncfusion XlsIO 사용',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('확인'),
                        ),
                      ],
                    ),
                  );
                },
                icon: const Icon(Icons.help),
                tooltip: '키보드 단축키',
              ),
              IconButton(
                onPressed: _downloadExcel,
                icon: const Icon(Icons.download),
                tooltip: 'Excel 다운로드',
              ),
            ],
          ],
        ),
        body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.orange),
                  SizedBox(height: 16),
                  Text('Syncfusion 템플릿 생성 중...'),
                ],
              ),
            )
          : _error != null
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error, size: 64, color: Colors.red),
                    const SizedBox(height: 16),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _error = null;
                        });
                      },
                      child: const Text('다시 시도'),
                    ),
                  ],
                ),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTemplateSelector(),
                    const SizedBox(height: 16),
                    _buildSyncfusionExcelGrid(),
                  ],
                ),
              ),
      ),
    );
  }

  @override
  void dispose() {
    _workbook?.dispose();
    _cellController.dispose();
    super.dispose();
  }
}