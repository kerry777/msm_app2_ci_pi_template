import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class EJ2SpreadsheetScreen extends StatefulWidget {
  const EJ2SpreadsheetScreen({super.key});

  @override
  State<EJ2SpreadsheetScreen> createState() => _EJ2SpreadsheetScreenState();
}

class _EJ2SpreadsheetScreenState extends State<EJ2SpreadsheetScreen> {
  String _status = 'Template Editor Ready';
  List<List<String>> _spreadsheetData = [];
  String _selectedTemplate = '';

  final List<String> _availableTemplates = [
    '기본 견적서',
    '상세 견적서',
    '주문서 템플릿',
    '납품서 템플릿',
    '매출 보고서',
  ];

  @override
  void initState() {
    super.initState();
    _initializeSpreadsheet();
  }

  void _initializeSpreadsheet() {
    // 기본 스프레드시트 데이터 초기화
    _spreadsheetData = [
      ['항목', '수량', '단가', '금액', '비고'],
      ['', '', '', '', ''],
      ['', '', '', '', ''],
      ['', '', '', '', ''],
      ['', '', '', '', ''],
      ['합계', '', '', '0', ''],
    ];
  }

  void _loadTemplate(String templateName) {
    setState(() {
      _selectedTemplate = templateName;
      _status = 'Loading $templateName...';
    });

    // 템플릿별 데이터 로드 시뮬레이션
    Future.delayed(const Duration(seconds: 1), () {
      setState(() {
        switch (templateName) {
          case '기본 견적서':
            _spreadsheetData = [
              ['품목명', '수량', '단가', '금액', '비고'],
              ['제품 A', '10', '1000', '10000', '기본 제품'],
              ['제품 B', '5', '2000', '10000', '프리미엄 제품'],
              ['', '', '', '', ''],
              ['', '', '', '', ''],
              ['합계', '15', '', '20000', '부가세 별도'],
            ];
            break;
          case '상세 견적서':
            _spreadsheetData = [
              ['순번', '품목명', '규격', '수량', '단가', '금액', '납기', '비고'],
              ['1', '제품 A', 'Standard', '10', '1000', '10000', '2024-01-15', '즉시 출고 가능'],
              ['2', '제품 B', 'Premium', '5', '2000', '10000', '2024-01-20', '주문 제작'],
              ['3', '', '', '', '', '', '', ''],
              ['4', '', '', '', '', '', '', ''],
              ['', '합계', '', '15', '', '20000', '', '부가세 포함'],
            ];
            break;
          default:
            _initializeSpreadsheet();
        }
        _status = '$templateName Loaded Successfully';
      });
    });
  }

  void _saveTemplate() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('템플릿이 저장되었습니다: $_selectedTemplate'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _exportTemplate() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('템플릿이 Excel 형식으로 내보내기 되었습니다'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('📋 Template Editor'),
        backgroundColor: const Color(0xFF667EEA),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveTemplate,
            tooltip: '저장',
          ),
          IconButton(
            icon: const Icon(Icons.file_download),
            onPressed: _exportTemplate,
            tooltip: '내보내기',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _status = 'Refreshing...';
              });
              Future.delayed(const Duration(seconds: 1), () {
                setState(() {
                  _status = 'Template Editor Ready';
                });
              });
            },
            tooltip: '새로고침',
          ),
        ],
      ),
      body: Column(
        children: [
          // 상태 표시
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
              ),
            ),
            child: Text(
              _status,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          // 템플릿 선택 영역
          Container(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '템플릿 선택',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: _availableTemplates.map((template) {
                    final isSelected = template == _selectedTemplate;
                    return ChoiceChip(
                      label: Text(template),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) {
                          _loadTemplate(template);
                        }
                      },
                      selectedColor: const Color(0xFF667EEA),
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : Colors.black,
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          // 스프레드시트 영역
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(8.0),
              ),
              child: Column(
                children: [
                  // 사용자 정보 헤더
                  Consumer<AuthProvider>(
                    builder: (context, authProvider, child) {
                      return Container(
                        padding: const EdgeInsets.all(12.0),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(8.0),
                            topRight: Radius.circular(8.0),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.person, size: 20, color: Colors.blue[600]),
                            const SizedBox(width: 8),
                            Text(
                              '작성자: ${authProvider.userInfo?['KOR_NM']?.toString() ?? 'Unknown'}',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                            const Spacer(),
                            Text(
                              '작성일: ${DateTime.now().toString().substring(0, 10)}',
                              style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  // 스프레드시트 테이블
                  Expanded(
                    child: SingleChildScrollView(
                      child: Table(
                        border: TableBorder.all(color: Colors.grey[300]!),
                        children: _spreadsheetData.asMap().entries.map((entry) {
                          final rowIndex = entry.key;
                          final rowData = entry.value;
                          final isHeader = rowIndex == 0;
                          final isTotal = rowData[0].contains('합계');

                          return TableRow(
                            decoration: BoxDecoration(
                              color: isHeader
                                ? const Color(0xFF667EEA).withOpacity(0.1)
                                : isTotal
                                  ? Colors.yellow.withOpacity(0.1)
                                  : null,
                            ),
                            children: rowData.map((cellData) {
                              return Container(
                                padding: const EdgeInsets.all(8.0),
                                child: Text(
                                  cellData,
                                  style: TextStyle(
                                    fontWeight: isHeader || isTotal ? FontWeight.bold : FontWeight.normal,
                                    fontSize: 12,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              );
                            }).toList(),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // 하단 컨트롤
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              border: Border(top: BorderSide(color: Colors.grey[300]!)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.arrow_back, size: 16),
                  label: const Text('뒤로'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[600],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _saveTemplate,
                  icon: const Icon(Icons.save, size: 16),
                  label: const Text('저장'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _exportTemplate,
                  icon: const Icon(Icons.file_download, size: 16),
                  label: const Text('내보내기'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF667EEA),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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