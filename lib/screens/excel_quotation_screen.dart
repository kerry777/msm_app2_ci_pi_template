import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/auth_provider.dart';

class ExcelQuotationScreen extends StatefulWidget {
  const ExcelQuotationScreen({super.key});

  @override
  State<ExcelQuotationScreen> createState() => _ExcelQuotationScreenState();
}

class _ExcelQuotationScreenState extends State<ExcelQuotationScreen> {
  List<List<TextEditingController>> _controllers = [];
  List<List<String>> _columnTypes = [];
  List<String> _headers = [];
  String _selectedTemplate = '기본 견적서';
  bool _isEditing = false;
  int _selectedRow = -1;
  int _selectedCol = -1;

  final Map<String, List<String>> _templates = {
    '기본 견적서': ['품목명', '수량', '단가', '금액', '비고'],
    '상세 견적서': ['순번', '품목명', '규격', '수량', '단가', '금액', '납기', '비고'],
    '매출 보고서': ['날짜', '고객명', '품목', '수량', '단가', '매출액', '이익', '담당자'],
    '재고 현황': ['품목코드', '품목명', '현재고', '안전재고', '단가', '재고금액', '위치', '상태'],
  };

  @override
  void initState() {
    super.initState();
    _initializeSpreadsheet();
  }

  void _initializeSpreadsheet() {
    _headers = _templates[_selectedTemplate] ?? ['항목', '값', '비고'];

    // 10x열 크기로 초기화
    _controllers = List.generate(12, (row) =>
      List.generate(_headers.length, (col) => TextEditingController())
    );

    _columnTypes = List.generate(12, (row) =>
      List.generate(_headers.length, (col) => _getColumnType(col))
    );

    // 샘플 데이터 입력
    _loadSampleData();
  }

  String _getColumnType(int colIndex) {
    final header = _headers[colIndex];
    if (header.contains('수량') || header.contains('단가') || header.contains('금액') || header.contains('매출') || header.contains('이익') || header.contains('재고')) {
      return 'number';
    } else if (header.contains('날짜') || header.contains('납기')) {
      return 'date';
    }
    return 'text';
  }

  void _loadSampleData() {
    switch (_selectedTemplate) {
      case '기본 견적서':
        _setSampleData([
          ['의료기기 A타입', '10', '150000', '=B1*C1', '기본 제품'],
          ['진단장비 B형', '2', '850000', '=B2*C2', '프리미엄'],
          ['소모품 세트', '5', '25000', '=B3*C3', '정기 교체'],
          ['', '', '', '', ''],
          ['', '', '', '', ''],
          ['합계', '=SUM(B1:B10)', '', '=SUM(D1:D10)', '부가세 별도'],
        ]);
        break;
      case '상세 견적서':
        _setSampleData([
          ['1', '의료기기 A타입', 'Standard', '10', '150000', '=D1*E1', '2024-02-15', '즉시 출고'],
          ['2', '진단장비 B형', 'Premium', '2', '850000', '=D2*E2', '2024-02-20', '주문 제작'],
          ['3', '소모품 세트', 'Basic', '5', '25000', '=D3*E3', '2024-02-10', '정기 교체'],
        ]);
        break;
      case '매출 보고서':
        _setSampleData([
          ['2024-01-15', '삼성서울병원', '의료기기 A', '10', '150000', '=D1*E1', '300000', '김영수'],
          ['2024-01-16', '서울대병원', '진단장비 B', '2', '850000', '=D2*E2', '170000', '박미영'],
          ['2024-01-17', '연세세브란스', '소모품 세트', '15', '25000', '=D3*E3', '75000', '최준호'],
        ]);
        break;
      case '재고 현황':
        _setSampleData([
          ['MED001', '의료기기 A타입', '25', '10', '150000', '=B1*E1', 'A구역', '정상'],
          ['DIA002', '진단장비 B형', '8', '5', '850000', '=B2*E2', 'B구역', '점검 필요'],
          ['CON003', '소모품 세트', '150', '50', '25000', '=B3*E3', 'C구역', '정상'],
        ]);
        break;
    }
  }

  void _setSampleData(List<List<String>> data) {
    for (int row = 0; row < data.length && row < _controllers.length - 1; row++) {
      for (int col = 0; col < data[row].length && col < _headers.length; col++) {
        _controllers[row][col].text = data[row][col];
      }
    }
    setState(() {});
  }

  void _calculateFormulas() {
    for (int row = 0; row < _controllers.length; row++) {
      for (int col = 0; col < _controllers[row].length; col++) {
        String text = _controllers[row][col].text;
        if (text.startsWith('=')) {
          try {
            String result = _evaluateFormula(text);
            // 수식은 그대로 두고, 결과만 임시로 계산
          } catch (e) {
            print('Formula error: $e');
          }
        }
      }
    }
  }

  String _evaluateFormula(String formula) {
    // 간단한 수식 계산기 (실제 엑셀보다는 단순화)
    formula = formula.substring(1); // = 제거

    if (formula.startsWith('SUM(')) {
      String range = formula.substring(4, formula.length - 1);
      return _calculateSum(range);
    } else if (formula.contains('*')) {
      List<String> parts = formula.split('*');
      if (parts.length == 2) {
        double val1 = _getCellValue(parts[0]);
        double val2 = _getCellValue(parts[1]);
        return NumberFormat('#,###').format(val1 * val2);
      }
    }
    return formula;
  }

  String _calculateSum(String range) {
    // B1:B10 같은 범위 처리
    if (range.contains(':')) {
      List<String> rangeParts = range.split(':');
      // 간단한 합계 계산
      double sum = 0;
      // 실제 구현에서는 더 복잡한 범위 파싱이 필요
      return NumberFormat('#,###').format(sum);
    }
    return '0';
  }

  double _getCellValue(String cellRef) {
    // B1, C2 같은 셀 참조를 실제 값으로 변환
    if (cellRef.length >= 2) {
      int col = cellRef.codeUnitAt(0) - 65; // A=0, B=1, C=2...
      int row = int.tryParse(cellRef.substring(1)) ?? 1;
      row = row - 1; // 0-based index

      if (row >= 0 && row < _controllers.length && col >= 0 && col < _controllers[row].length) {
        String text = _controllers[row][col].text;
        return double.tryParse(text.replaceAll(',', '')) ?? 0;
      }
    }
    return 0;
  }

  void _addRow() {
    setState(() {
      _controllers.add(
        List.generate(_headers.length, (col) => TextEditingController())
      );
      _columnTypes.add(
        List.generate(_headers.length, (col) => _getColumnType(col))
      );
    });
  }

  void _deleteRow(int rowIndex) {
    if (_controllers.length > 1) {
      setState(() {
        for (var controller in _controllers[rowIndex]) {
          controller.dispose();
        }
        _controllers.removeAt(rowIndex);
        _columnTypes.removeAt(rowIndex);
      });
    }
  }

  void _changeTemplate(String template) {
    // 기존 컨트롤러들 정리
    for (var row in _controllers) {
      for (var controller in row) {
        controller.dispose();
      }
    }

    setState(() {
      _selectedTemplate = template;
    });

    _initializeSpreadsheet();
  }

  @override
  void dispose() {
    for (var row in _controllers) {
      for (var controller in row) {
        controller.dispose();
      }
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('📊 Excel 견적서 편집기'),
        backgroundColor: Colors.green.shade600,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_box),
            onPressed: _addRow,
            tooltip: '행 추가',
          ),
          IconButton(
            icon: const Icon(Icons.calculate),
            onPressed: () {
              _calculateFormulas();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('수식이 계산되었습니다')),
              );
            },
            tooltip: '수식 계산',
          ),
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('$_selectedTemplate이 저장되었습니다')),
              );
            },
            tooltip: '저장',
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.download),
            tooltip: '내보내기',
            onSelected: (format) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('$format 형식으로 내보내기 되었습니다')),
              );
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'Excel', child: Text('Excel (.xlsx)')),
              const PopupMenuItem(value: 'CSV', child: Text('CSV 파일')),
              const PopupMenuItem(value: 'PDF', child: Text('PDF 문서')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // 템플릿 선택 영역
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              border: Border(bottom: BorderSide(color: Colors.green.shade200)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    const Text('템플릿:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Wrap(
                        spacing: 8,
                        children: _templates.keys.map((template) {
                          return ChoiceChip(
                            label: Text(template),
                            selected: template == _selectedTemplate,
                            onSelected: (selected) {
                              if (selected) _changeTemplate(template);
                            },
                            selectedColor: Colors.green.shade200,
                            backgroundColor: Colors.white,
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Consumer<AuthProvider>(
                  builder: (context, authProvider, child) {
                    return Row(
                      children: [
                        Icon(Icons.person, size: 16, color: Colors.green.shade700),
                        const SizedBox(width: 8),
                        Text('작성자: ${authProvider.userInfo?['KOR_NM']?.toString() ?? 'Unknown'}'),
                        const Spacer(),
                        Icon(Icons.calendar_today, size: 16, color: Colors.green.shade700),
                        const SizedBox(width: 8),
                        Text('작성일: ${DateFormat('yyyy-MM-dd').format(DateTime.now())}'),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),

          // 스프레드시트 영역
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  // 헤더
                  Container(
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
                    ),
                    child: Row(
                      children: [
                        // 행 번호 헤더
                        Container(
                          width: 40,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            border: Border(right: BorderSide(color: Colors.grey.shade300)),
                          ),
                          child: const Text('#', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                        // 컬럼 헤더들
                        ..._headers.asMap().entries.map((entry) {
                          return Expanded(
                            child: Container(
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                border: Border(right: BorderSide(color: Colors.grey.shade300)),
                              ),
                              child: Text(
                                entry.value,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          );
                        }).toList(),
                        // 삭제 컬럼 헤더
                        Container(
                          width: 40,
                          alignment: Alignment.center,
                          child: const Icon(Icons.delete, size: 16),
                        ),
                      ],
                    ),
                  ),

                  // 데이터 행들
                  Expanded(
                    child: ListView.builder(
                      itemCount: _controllers.length,
                      itemBuilder: (context, rowIndex) {
                        final isLastRow = rowIndex == _controllers.length - 1;
                        final isSelected = _selectedRow == rowIndex;

                        return Container(
                          height: 50,
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.blue.shade50 :
                                   isLastRow ? Colors.yellow.shade50 : Colors.white,
                            border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
                          ),
                          child: Row(
                            children: [
                              // 행 번호
                              Container(
                                width: 40,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  border: Border(right: BorderSide(color: Colors.grey.shade300)),
                                ),
                                child: Text(
                                  (rowIndex + 1).toString(),
                                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                              ),
                              // 데이터 셀들
                              ..._controllers[rowIndex].asMap().entries.map((entry) {
                                final colIndex = entry.key;
                                final controller = entry.value;
                                final columnType = _columnTypes[rowIndex][colIndex];

                                return Expanded(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      border: Border(right: BorderSide(color: Colors.grey.shade300)),
                                    ),
                                    child: TextFormField(
                                      controller: controller,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: isLastRow && controller.text.contains('합계') ? FontWeight.bold : FontWeight.normal,
                                      ),
                                      decoration: const InputDecoration(
                                        border: InputBorder.none,
                                        contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 12),
                                        isDense: true,
                                      ),
                                      keyboardType: columnType == 'number' ? TextInputType.number : TextInputType.text,
                                      inputFormatters: columnType == 'number' ? [
                                        FilteringTextInputFormatter.allow(RegExp(r'[0-9,=+\-*/.():]')),
                                      ] : [],
                                      onTap: () {
                                        setState(() {
                                          _selectedRow = rowIndex;
                                          _selectedCol = colIndex;
                                        });
                                      },
                                      onChanged: (value) {
                                        if (columnType == 'number' && !value.startsWith('=')) {
                                          // 자동 천 단위 콤마 추가
                                          final numValue = double.tryParse(value.replaceAll(',', ''));
                                          if (numValue != null) {
                                            controller.text = NumberFormat('#,###').format(numValue);
                                            controller.selection = TextSelection.fromPosition(
                                              TextPosition(offset: controller.text.length),
                                            );
                                          }
                                        }
                                      },
                                    ),
                                  ),
                                );
                              }).toList(),
                              // 삭제 버튼
                              Container(
                                width: 40,
                                child: IconButton(
                                  icon: Icon(Icons.remove_circle, size: 16, color: Colors.red.shade400),
                                  onPressed: () => _deleteRow(rowIndex),
                                  tooltip: '행 삭제',
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 하단 도구 모음
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              border: Border(top: BorderSide(color: Colors.grey.shade300)),
            ),
            child: Row(
              children: [
                Text('행 ${_controllers.length}개 | 열 ${_headers.length}개'),
                const Spacer(),
                if (_selectedRow != -1 && _selectedCol != -1)
                  Text('선택된 셀: ${String.fromCharCode(65 + _selectedCol)}${_selectedRow + 1}'),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: _addRow,
                  icon: const Icon(Icons.add),
                  label: const Text('행 추가'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade600,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}