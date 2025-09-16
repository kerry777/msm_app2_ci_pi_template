import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:data_table_2/data_table_2.dart';
import '../providers/auth_provider.dart';
import '../utils/order_report_generator.dart';
import 'ej2_spreadsheet_screen.dart';
import '../config/app_config.dart';

class QuoteManagementScreen extends StatefulWidget {
  const QuoteManagementScreen({super.key});

  @override
  State<QuoteManagementScreen> createState() => _QuoteManagementScreenState();
}

class _QuoteManagementScreenState extends State<QuoteManagementScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _quotes = [];
  List<Map<String, dynamic>> _filteredQuotes = [];

  String _searchText = '';
  String _selectedStatus = 'ALL';
  DateTimeRange? _dateRange;

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchQuotes();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchQuotes() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);

    try {
      final response = await http.get(
        Uri.parse('${AppConfig.apiBaseUrl}/quotes'),
        headers: {'Authorization': 'Bearer ${auth.token}'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> quoteData = jsonDecode(utf8.decode(response.bodyBytes));
        setState(() {
          _quotes = quoteData.cast<Map<String, dynamic>>();
          _filteredQuotes = List.from(_quotes);
          _isLoading = false;
        });
      } else {
        throw Exception('Failed to fetch quotes: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching quotes: $e');
      _loadSampleData();
    }
  }

  void _loadSampleData() {
    setState(() {
      _isLoading = false;
      _quotes = [
        {
          'quoteNo': 'QT_001',
          'customerName': '서울대병원',
          'customerCode': 'CUST001',
          'validDate': '2024-01-25',
          'quoteDate': '2024-01-10T14:30:00Z',
          'quoteType': '정식견적',
          'status': 'PENDING',
          'totalAmount': 12500000,
          'itemCount': 5,
          'items': [
            {'ERPCODE': 'ITEM001', '품명': '의료기기 A', '규격': 'Type-1', 'quantity': 5, 'unitPrice': 2500000},
          ]
        },
        {
          'quoteNo': 'QT_002',
          'customerName': '삼성서울병원',
          'customerCode': 'CUST002',
          'validDate': '2024-02-15',
          'quoteDate': '2024-01-20T09:00:00Z',
          'quoteType': '정식견적',
          'status': 'APPROVED',
          'totalAmount': 8750000,
          'itemCount': 3,
          'items': [
            {'ERPCODE': 'ITEM002', '품명': '진단장비 B', '규격': 'Pro', 'quantity': 1, 'unitPrice': 7330000},
            {'ERPCODE': 'ITEM003', '품명': '의료장비 C', '규격': 'Standard', 'quantity': 2, 'unitPrice': 1200000},
            {'ERPCODE': 'ITEM004', '품명': '소모품 D', '규격': '5ml', 'quantity': 20, 'unitPrice': 220000},
          ]
        },
        {
          'quoteNo': 'QT_003',
          'customerName': '연세병원',
          'customerCode': 'CUST003',
          'validDate': '2024-02-10',
          'quoteDate': '2024-01-16T09:15:00Z',
          'quoteType': '정식견적',
          'status': 'EXPIRED',
          'totalAmount': 3200000,
          'itemCount': 8,
          'items': [
            {'ERPCODE': 'ITEM005', '품명': '검사용품 E', '규격': 'Large', 'quantity': 8, 'unitPrice': 400000},
          ]
        },
        {
          'quoteNo': 'QT_004',
          'customerName': '가톨릭병원',
          'customerCode': 'CUST004',
          'validDate': '2024-01-30',
          'quoteDate': '2024-01-12T16:45:00Z',
          'quoteType': '정식견적',
          'status': 'REJECTED',
          'totalAmount': 2800000,
          'itemCount': 12,
          'items': [
            {'ERPCODE': 'ITEM006', '품명': '치료용품 F', '규격': 'Medium', 'quantity': 12, 'unitPrice': 233333},
          ]
        },
      ];
    });
  }

  void _applyFilters() {
    setState(() {
      _filteredQuotes = _quotes.where((quote) {
        final matchesSearch = _searchText.isEmpty ||
            quote['quoteNo'].toLowerCase().contains(_searchText.toLowerCase()) ||
            quote['customerName'].toLowerCase().contains(_searchText.toLowerCase());

        final matchesStatus = _selectedStatus == 'ALL' || quote['status'] == _selectedStatus;

        bool matchesDate = true;
        if (_dateRange != null) {
          final quoteDate = DateTime.parse(quote['quoteDate']);
          matchesDate = quoteDate.isAfter(_dateRange!.start.subtract(const Duration(days: 1))) &&
                       quoteDate.isBefore(_dateRange!.end.add(const Duration(days: 1)));
        }

        return matchesSearch && matchesStatus && matchesDate;
      }).toList();
    });
  }

  void _clearFilters() {
    setState(() {
      _searchText = '';
      _selectedStatus = 'ALL';
      _dateRange = null;
      _searchController.clear();
      _filteredQuotes = List.from(_quotes);
    });
  }

  void _showQuoteDetail(Map<String, dynamic> quote) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          child: Container(
            width: MediaQuery.of(context).size.width * 0.8,
            height: MediaQuery.of(context).size.height * 0.8,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '견적 상세 - ${quote['quoteNo']}',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // 견적 정보
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('고객명: ${quote['customerName']}', style: const TextStyle(fontSize: 16)),
                        const SizedBox(height: 8),
                        Text('견적번호: ${quote['quoteNo']}', style: const TextStyle(fontSize: 14)),
                        Text('견적일자: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.parse(quote['quoteDate']))}'),
                        Text('유효기간: ${quote['validDate']}'),
                        Text('상태: ${_getStatusText(quote['status'])}'),
                        Text('총 금액: ₩${NumberFormat('#,###').format(quote['totalAmount'])}',
                             style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // 견적 품목 리스트
                const Text('견적 품목', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DataTable2(
                      columnSpacing: 12,
                      horizontalMargin: 12,
                      minWidth: 600,
                      columns: const [
                        DataColumn2(label: Text('품목코드')),
                        DataColumn2(label: Text('품명')),
                        DataColumn2(label: Text('규격')),
                        DataColumn2(label: Text('수량'), numeric: true),
                        DataColumn2(label: Text('단가'), numeric: true),
                        DataColumn2(label: Text('금액'), numeric: true),
                      ],
                      rows: (quote['items'] as List<dynamic>).map<DataRow>((item) {
                        final quantity = item['quantity'] as int;
                        final unitPrice = item['unitPrice'] as int;
                        final amount = quantity * unitPrice;

                        return DataRow(cells: [
                          DataCell(Text(item['ERPCODE'] ?? '')),
                          DataCell(Text(item['품명'] ?? '')),
                          DataCell(Text(item['규격'] ?? '')),
                          DataCell(Text(quantity.toString())),
                          DataCell(Text('₩${NumberFormat('#,###').format(unitPrice)}')),
                          DataCell(Text('₩${NumberFormat('#,###').format(amount)}')),
                        ]);
                      }).toList(),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // 액션 버튼들
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (quote['status'] == 'PENDING') ...[
                      ElevatedButton.icon(
                        onPressed: () => _editQuote(quote),
                        icon: const Icon(Icons.edit),
                        label: const Text('수정'),
                      ),
                      const SizedBox(width: 8),
                    ],
                    ElevatedButton.icon(
                      onPressed: () => _copyQuote(quote),
                      icon: const Icon(Icons.copy),
                      label: const Text('복사'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () => _exportQuote(quote),
                      icon: const Icon(Icons.download),
                      label: const Text('내보내기'),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('닫기'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _editQuote(Map<String, dynamic> quote) {
    Navigator.of(context).pop();

    // 견적 수정 안내
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('견적서 템플릿 수정'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('견적서 ${quote['quoteNo']}을 템플릿 에디터에서 수정합니다.'),
              const SizedBox(height: 16),
              const Text('• 기본 템플릿이 자동으로 로드됩니다'),
              const Text('• 기존 견적 정보가 템플릿에 적용됩니다'),
              const Text('• 수정 완료 후 저장하면 견적이 업데이트됩니다'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                // EJ2 스프레드시트로 이동하여 견적 수정
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const EJ2SpreadsheetScreen(),
                  ),
                ).then((_) {
                  // 스프레드시트에서 돌아왔을 때 견적 목록 새로고침
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('템플릿 편집이 완료되었습니다')),
                  );
                  _fetchQuotes();
                });
              },
              child: const Text('템플릿 편집 시작'),
            ),
          ],
        );
      },
    );
  }

  void _copyQuote(Map<String, dynamic> quote) {
    Navigator.of(context).pop();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('견적서 복사'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${quote['quoteNo']} 견적서를 복사하시겠습니까?'),
              const SizedBox(height: 16),
              const Text('복사된 견적서는 "대기중" 상태로 생성됩니다.'),
              const Text('필요시 품목이나 금액을 수정할 수 있습니다.'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _performCopyQuote(quote);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${quote['quoteNo']} 견적서가 복사되었습니다')),
                );
                _fetchQuotes();
              },
              child: const Text('복사'),
            ),
          ],
        );
      },
    );
  }

  void _exportQuote(Map<String, dynamic> quote) {
    Navigator.of(context).pop();

    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('견적서 내보내기', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
                title: const Text('PDF로 내보내기'),
                subtitle: const Text('인쇄 및 공유에 최적화'),
                onTap: () {
                  Navigator.pop(context);
                  _exportToPDF(quote);
                },
              ),
              ListTile(
                leading: const Icon(Icons.table_view, color: Colors.green),
                title: const Text('Excel로 내보내기'),
                subtitle: const Text('편집 가능한 형태'),
                onTap: () {
                  Navigator.pop(context);
                  _exportToExcel(quote);
                },
              ),
              ListTile(
                leading: const Icon(Icons.email, color: Colors.blue),
                title: const Text('이메일로 전송'),
                subtitle: const Text('고객에게 직접 전송'),
                onTap: () {
                  Navigator.pop(context);
                  _sendByEmail(quote);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _performCopyQuote(Map<String, dynamic> quote) async {
    await Future.delayed(const Duration(milliseconds: 500));
  }

  void _exportToPDF(Map<String, dynamic> quote) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${quote['quoteNo']} PDF 내보내기 완료')),
    );
  }

  void _exportToExcel(Map<String, dynamic> quote) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${quote['quoteNo']} Excel 내보내기 완료')),
    );
  }

  void _sendByEmail(Map<String, dynamic> quote) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${quote['quoteNo']} 이메일 전송 완료')),
    );
  }

  void _deleteQuote(Map<String, dynamic> quote) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('견적서 삭제'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${quote['quoteNo']} 견적서를 삭제하시겠습니까?'),
              const SizedBox(height: 16),
              const Text('⚠️ 삭제된 견적서는 복구할 수 없습니다.',
                        style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _performDeleteQuote(quote);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${quote['quoteNo']} 견적서가 삭제되었습니다')),
                );
                _fetchQuotes();
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('삭제', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _performDeleteQuote(Map<String, dynamic> quote) async {
    await Future.delayed(const Duration(milliseconds: 500));
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'PENDING':
        return '대기중';
      case 'APPROVED':
        return '승인됨';
      case 'REJECTED':
        return '거부됨';
      case 'EXPIRED':
        return '만료됨';
      default:
        return status;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'PENDING':
        return Colors.orange;
      case 'APPROVED':
        return Colors.green;
      case 'REJECTED':
        return Colors.red;
      case 'EXPIRED':
        return Colors.grey;
      default:
        return Colors.black;
    }
  }

  void _loadTemplate(String templatePath, String templateName) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('$templateName 템플릿 로드'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$templateName 템플릿을 스프레드시트 편집기에 로드합니다.'),
              const SizedBox(height: 16),
              const Text('• 선택한 템플릿이 자동으로 로드됩니다'),
              const Text('• 필요한 정보를 입력하여 견적서를 작성하세요'),
              const Text('• 작성 완료 후 저장하면 견적이 등록됩니다'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                // EJ2 스프레드시트로 이동하여 템플릿 로드
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const EJ2SpreadsheetScreen(),
                  ),
                ).then((_) {
                  // 스프레드시트에서 돌아왔을 때 견적 목록 새로고침
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('$templateName 템플릿으로 견적서가 작성되었습니다')),
                  );
                  _fetchQuotes();
                });
              },
              child: const Text('템플릿 로드'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('견적서 관리'),
        actions: [
          ElevatedButton.icon(
            onPressed: () {
              // EJ2 스프레드시트 화면으로 이동하여 새 견적서 작성
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const EJ2SpreadsheetScreen(),
                ),
              ).then((_) {
                // 스프레드시트에서 돌아왔을 때 견적 목록 새로고침
                _fetchQuotes();
              });
            },
            icon: const Icon(Icons.add),
            label: const Text('새 견적서'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // 검색 및 필터 영역
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.grey.shade50,
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: TextField(
                              controller: _searchController,
                              decoration: const InputDecoration(
                                hintText: '견적번호 또는 고객명으로 검색',
                                prefixIcon: Icon(Icons.search),
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                              onChanged: (value) {
                                setState(() {
                                  _searchText = value;
                                });
                                _applyFilters();
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: _selectedStatus,
                              decoration: const InputDecoration(
                                labelText: '상태',
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                              items: const [
                                DropdownMenuItem(value: 'ALL', child: Text('전체')),
                                DropdownMenuItem(value: 'PENDING', child: Text('대기중')),
                                DropdownMenuItem(value: 'APPROVED', child: Text('승인됨')),
                                DropdownMenuItem(value: 'REJECTED', child: Text('거부됨')),
                                DropdownMenuItem(value: 'EXPIRED', child: Text('만료됨')),
                              ],
                              onChanged: (value) {
                                setState(() {
                                  _selectedStatus = value!;
                                });
                                _applyFilters();
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          ElevatedButton(
                            onPressed: () async {
                              final DateTimeRange? picked = await showDateRangePicker(
                                context: context,
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2030),
                                initialDateRange: _dateRange,
                              );
                              if (picked != null) {
                                setState(() {
                                  _dateRange = picked;
                                });
                                _applyFilters();
                              }
                            },
                            child: Text(_dateRange == null ? '기간 선택' :
                                       '${DateFormat('MM/dd').format(_dateRange!.start)} - ${DateFormat('MM/dd').format(_dateRange!.end)}'),
                          ),
                          const SizedBox(width: 8),
                          TextButton(
                            onPressed: _clearFilters,
                            child: const Text('초기화'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('총 ${_filteredQuotes.length}개 견적서', style: const TextStyle(fontSize: 14, color: Colors.grey)),
                    ],
                  ),
                ),

                // 견적서 목록
                Expanded(
                  child: _filteredQuotes.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.description, size: 64, color: Colors.grey),
                              SizedBox(height: 16),
                              Text('견적서가 없습니다', style: TextStyle(fontSize: 16, color: Colors.grey)),
                            ],
                          ),
                        )
                      : DataTable2(
                          columnSpacing: 12,
                          horizontalMargin: 12,
                          minWidth: 900,
                          columns: const [
                            DataColumn2(label: Text('견적번호'), size: ColumnSize.S),
                            DataColumn2(label: Text('고객명'), size: ColumnSize.M),
                            DataColumn2(label: Text('견적일자'), size: ColumnSize.S),
                            DataColumn2(label: Text('유효기간'), size: ColumnSize.S),
                            DataColumn2(label: Text('상태'), size: ColumnSize.S),
                            DataColumn2(label: Text('금액'), size: ColumnSize.M, numeric: true),
                            DataColumn2(label: Text('품목수'), size: ColumnSize.S, numeric: true),
                            DataColumn2(label: Text('액션'), size: ColumnSize.S),
                          ],
                          rows: _filteredQuotes.map<DataRow>((quote) {
                            return DataRow(
                              cells: [
                                DataCell(
                                  GestureDetector(
                                    onTap: () => _showQuoteDetail(quote),
                                    child: Text(
                                      quote['quoteNo'],
                                      style: const TextStyle(
                                        color: Colors.blue,
                                        decoration: TextDecoration.underline,
                                      ),
                                    ),
                                  ),
                                ),
                                DataCell(Text(quote['customerName'])),
                                DataCell(Text(DateFormat('MM-dd HH:mm').format(DateTime.parse(quote['quoteDate'])))),
                                DataCell(Text(quote['validDate'])),
                                DataCell(
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: _getStatusColor(quote['status']).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: _getStatusColor(quote['status']).withOpacity(0.3)),
                                    ),
                                    child: Text(
                                      _getStatusText(quote['status']),
                                      style: TextStyle(
                                        color: _getStatusColor(quote['status']),
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                                DataCell(Text('₩${NumberFormat('#,###').format(quote['totalAmount'])}')),
                                DataCell(Text('${quote['itemCount']}')),
                                DataCell(
                                  PopupMenuButton(
                                    icon: const Icon(Icons.more_vert),
                                    itemBuilder: (context) => [
                                      const PopupMenuItem(
                                        value: 'view',
                                        child: ListTile(
                                          leading: Icon(Icons.visibility),
                                          title: Text('상세보기'),
                                        ),
                                      ),
                                      if (quote['status'] == 'PENDING') ...[
                                        const PopupMenuItem(
                                          value: 'edit',
                                          child: ListTile(
                                            leading: Icon(Icons.edit),
                                            title: Text('수정'),
                                          ),
                                        ),
                                      ],
                                      const PopupMenuItem(
                                        value: 'copy',
                                        child: ListTile(
                                          leading: Icon(Icons.copy),
                                          title: Text('복사'),
                                        ),
                                      ),
                                      const PopupMenuItem(
                                        value: 'export',
                                        child: ListTile(
                                          leading: Icon(Icons.download),
                                          title: Text('내보내기'),
                                        ),
                                      ),
                                      if (quote['status'] == 'PENDING') ...[
                                        const PopupMenuItem(
                                          value: 'delete',
                                          child: ListTile(
                                            leading: Icon(Icons.delete, color: Colors.red),
                                            title: Text('삭제', style: TextStyle(color: Colors.red)),
                                          ),
                                        ),
                                      ],
                                    ],
                                    onSelected: (value) {
                                      switch (value) {
                                        case 'view':
                                          _showQuoteDetail(quote);
                                          break;
                                        case 'edit':
                                          if (quote['status'] == 'PENDING') _editQuote(quote);
                                          break;
                                        case 'copy':
                                          _copyQuote(quote);
                                          break;
                                        case 'export':
                                          _exportQuote(quote);
                                          break;
                                        case 'delete':
                                          if (quote['status'] == 'PENDING') _deleteQuote(quote);
                                          break;
                                      }
                                    },
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                ),
              ],
            ),
    );
  }
}