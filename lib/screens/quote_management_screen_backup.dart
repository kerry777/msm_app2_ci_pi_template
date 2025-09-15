import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:data_table_2/data_table_2.dart';
import '../providers/auth_provider.dart';
import '../utils/order_report_generator.dart';
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
        setState(() {
          _quotes = _getMockQuotes();
          _filteredQuotes = List.from(_quotes);
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _quotes = _getMockQuotes();
        _filteredQuotes = List.from(_quotes);
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> _getMockQuotes() {
    return [
      {
        'quoteNo': 'QT_001',
        'customerName': '삼성병원',
        'customerCode': 'CUST001',
        'validDate': '2024-02-15',
        'quoteDate': '2024-01-15T10:30:00Z',
        'quoteType': '정식견적',
        'status': 'PENDING',
        'totalAmount': 4500000,
        'itemCount': 15,
        'items': [
          {'ERPCODE': 'ITEM001', '품명': '의료용품 A', '규격': '10cm', 'quantity': 5, 'unitPrice': 150000},
          {'ERPCODE': 'ITEM002', '품명': '의료용품 B', '규격': '20cm', 'quantity': 10, 'unitPrice': 300000},
        ]
      },
      {
        'quoteNo': 'QT_002',
        'customerName': '서울대병원',
        'customerCode': 'CUST002',
        'validDate': '2024-02-20',
        'quoteDate': '2024-01-14T14:20:00Z',
        'quoteType': '간이견적',
        'status': 'APPROVED',
        'totalAmount': 6800000,
        'itemCount': 22,
        'items': [
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
                        const Text('견적 정보', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Text('고객명: ${quote['customerName']}'),
                        Text('고객코드: ${quote['customerCode']}'),
                        Text('견적일: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.parse(quote['quoteDate']))}'),
                        Text('유효기한: ${quote['validDate']}'),
                        Text('견적구분: ${quote['quoteType']}'),
                        Text('상태: ${_getStatusText(quote['status'])}'),
                        Text('총액: ${NumberFormat.currency(locale: 'ko_KR', symbol: '₩').format(quote['totalAmount'])}'),
                        Text('품목수: ${quote['itemCount']}건'),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),
                const Text('견적 품목', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                
                // 품목 리스트
                Expanded(
                  child: Card(
                    child: DataTable2(
                      columnSpacing: 12,
                      horizontalMargin: 12,
                      minWidth: 600,
                      columns: const [
                        DataColumn2(label: Text('품번'), size: ColumnSize.M),
                        DataColumn2(label: Text('품명'), size: ColumnSize.L),
                        DataColumn2(label: Text('규격'), size: ColumnSize.M),
                        DataColumn2(label: Text('수량'), size: ColumnSize.S, numeric: true),
                        DataColumn2(label: Text('단가'), size: ColumnSize.M, numeric: true),
                        DataColumn2(label: Text('금액'), size: ColumnSize.M, numeric: true),
                      ],
                      rows: (quote['items'] as List<dynamic>).map((item) {
                        final itemTotal = item['quantity'] * item['unitPrice'];
                        return DataRow(cells: [
                          DataCell(Text('${item['ERPCODE'] ?? ''}')),
                          DataCell(Text('${item['품명'] ?? ''}')),
                          DataCell(Text('${item['규격'] ?? ''}')),
                          DataCell(Text('${item['quantity']}')),
                          DataCell(Text(NumberFormat.currency(locale: 'ko_KR', symbol: '₩').format(item['unitPrice']))),
                          DataCell(Text(NumberFormat.currency(locale: 'ko_KR', symbol: '₩').format(itemTotal))),
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
                      onPressed: () => _generateQuotePDF(quote),
                      icon: const Icon(Icons.picture_as_pdf),
                      label: const Text('PDF'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () => _generateQuoteExcel(quote),
                      icon: const Icon(Icons.table_chart),
                      label: const Text('Excel'),
                    ),
                    if (quote['status'] == 'APPROVED') ...[
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: () => _convertToOrder(quote),
                        icon: const Icon(Icons.shopping_cart),
                        label: const Text('주문변환'),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                      ),
                    ],
                    if (quote['status'] == 'PENDING') ...[
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: () => _deleteQuote(quote),
                        icon: const Icon(Icons.delete),
                        label: const Text('삭제'),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      ),
                    ],
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
    _showStatusChangeDialog(quote);
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

  void _convertToOrder(Map<String, dynamic> quote) {
    Navigator.of(context).pop();
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('주문으로 변환'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${quote['quoteNo']} 견적서를 주문으로 변환하시겠습니까?'),
              const SizedBox(height: 16),
              const Text('승인된 견적서는 주문으로 변환할 수 있습니다.'),
              const Text('변환 후 주문 관리에서 확인하실 수 있습니다.'),
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
                await _performConvertToOrder(quote);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('견적서가 주문으로 변환되었습니다')),
                );
                _fetchQuotes();
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: const Text('변환'),
            ),
          ],
        );
      },
    );
  }

  void _deleteQuote(Map<String, dynamic> quote) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('견적서 삭제'),
          content: Text('${quote['quoteNo']} 견적서를 삭제하시겠습니까?\n이 작업은 되돌릴 수 없습니다.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                Navigator.of(context).pop();
                
                await _performDeleteQuote(quote['quoteNo']);
                
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${quote['quoteNo']} 견적서가 삭제되었습니다')),
                );
                
                _fetchQuotes();
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('삭제'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _performDeleteQuote(String quoteNo) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    
    try {
      await http.delete(
        Uri.parse('http://localhost:4100/api/v1/quotes/$quoteNo'),
        headers: {'Authorization': 'Bearer ${auth.token}'},
      );
    } catch (e) {
      print('Delete quote error: $e');
    }
  }

  Future<void> _performCopyQuote(Map<String, dynamic> quote) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    
    try {
      final timestamp = DateFormat('yyyyMMddHHmm').format(DateTime.now());
      final newQuoteNo = '${quote['quoteNo']}_COPY_$timestamp';
      
      final newQuote = Map<String, dynamic>.from(quote);
      newQuote['quoteNo'] = newQuoteNo;
      newQuote['status'] = 'PENDING';
      newQuote['quoteDate'] = DateTime.now().toIso8601String();
      
      // 유효기한을 현재 날짜로부터 30일 후로 설정
      final validDate = DateTime.now().add(const Duration(days: 30));
      newQuote['validDate'] = DateFormat('yyyy-MM-dd').format(validDate);
      
      await http.post(
        Uri.parse('${AppConfig.apiBaseUrl}/quotes'),
        headers: {
          'Authorization': 'Bearer ${auth.token}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(newQuote),
      );
    } catch (e) {
      print('Copy quote error: $e');
    }
  }

  Future<void> _performConvertToOrder(Map<String, dynamic> quote) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    
    try {
      final timestamp = DateFormat('yyyyMMddHHmm').format(DateTime.now());
      final orderNo = 'SO_FROM_${quote['quoteNo']}_$timestamp';
      
      final order = {
        'orderNo': orderNo,
        'customerName': quote['customerName'],
        'customerCode': quote['customerCode'],
        'deliveryDate': DateFormat('yyyy-MM-dd').format(DateTime.now().add(const Duration(days: 7))),
        'orderDate': DateTime.now().toIso8601String(),
        'orderType': '주문',
        'status': 'PENDING',
        'totalAmount': quote['totalAmount'],
        'itemCount': quote['itemCount'],
        'items': quote['items'],
        'sourceQuote': quote['quoteNo'],
      };
      
      await http.post(
        Uri.parse('${AppConfig.apiBaseUrl}/orders'),
        headers: {
          'Authorization': 'Bearer ${auth.token}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(order),
      );
    } catch (e) {
      print('Convert to order error: $e');
    }
  }

  void _showStatusChangeDialog(Map<String, dynamic> quote) {
    String selectedStatus = quote['status'];
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('${quote['quoteNo']} 상태 변경'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('견적서 상태를 변경하시겠습니까?'),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: selectedStatus,
                    decoration: const InputDecoration(
                      labelText: '새 상태',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      {'value': 'PENDING', 'label': '대기중', 'color': Colors.orange},
                      {'value': 'APPROVED', 'label': '승인', 'color': Colors.green},
                      {'value': 'REJECTED', 'label': '거부', 'color': Colors.red},
                      {'value': 'EXPIRED', 'label': '만료', 'color': Colors.grey},
                    ].map((status) {
                      return DropdownMenuItem<String>(
                        value: status['value'] as String,
                        child: Row(
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: status['color'] as Color,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(status['label'] as String),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setDialogState(() {
                        selectedStatus = value!;
                      });
                    },
                  ),
                  if (selectedStatus != quote['status']) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.blue.shade700),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _getStatusChangeMessage(quote['status'], selectedStatus),
                              style: TextStyle(color: Colors.blue.shade700),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('취소'),
                ),
                ElevatedButton(
                  onPressed: selectedStatus != quote['status'] 
                    ? () async {
                        Navigator.of(context).pop();
                        await _performStatusChange(quote['quoteNo'], selectedStatus);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('${quote['quoteNo']} 상태가 ${_getStatusText(selectedStatus)}로 변경되었습니다')),
                        );
                        _fetchQuotes();
                      }
                    : null,
                  child: const Text('변경'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _getStatusChangeMessage(String currentStatus, String newStatus) {
    if (currentStatus == 'PENDING' && newStatus == 'APPROVED') {
      return '견적서가 승인됩니다. 주문으로 변환할 수 있습니다.';
    } else if (newStatus == 'REJECTED') {
      return '견적서가 거부됩니다. 이 작업은 신중하게 검토해주세요.';
    } else if (newStatus == 'EXPIRED') {
      return '견적서가 만료 처리됩니다.';
    } else if (currentStatus == 'EXPIRED' && newStatus == 'PENDING') {
      return '만료된 견적서를 다시 활성화하고 유효기한을 연장합니다.';
    }
    return '상태가 변경됩니다.';
  }

  Future<void> _performStatusChange(String quoteNo, String newStatus) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    
    try {
      await http.patch(
        Uri.parse('http://localhost:4100/api/v1/quotes/$quoteNo/status'),
        headers: {
          'Authorization': 'Bearer ${auth.token}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'status': newStatus}),
      );
    } catch (e) {
      print('Status change error: $e');
    }
  }

  Future<void> _generateQuotePDF(Map<String, dynamic> quote) async {
    try {
      final pdfData = await OrderReportGenerator.generateQuotePDF(
        quoteNumber: quote['quoteNo'],
        customerName: quote['customerName'],
        customerCode: quote['customerCode'],
        validDate: quote['validDate'],
        quoteType: quote['quoteType'],
        items: List<Map<String, dynamic>>.from(quote['items']),
      );
      
      await OrderReportGenerator.previewPDF(pdfData);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('PDF 생성 중 오류가 발생했습니다: $e')),
      );
    }
  }

  Future<void> _generateQuoteExcel(Map<String, dynamic> quote) async {
    try {
      final excelPath = await OrderReportGenerator.generateQuoteExcel(
        quoteNumber: quote['quoteNo'],
        customerName: quote['customerName'],
        customerCode: quote['customerCode'],
        validDate: quote['validDate'],
        quoteType: quote['quoteType'],
        items: List<Map<String, dynamic>>.from(quote['items']),
      );
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Excel 파일이 생성되었습니다: $excelPath')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Excel 생성 중 오류가 발생했습니다: $e')),
      );
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'PENDING':
        return '대기중';
      case 'APPROVED':
        return '승인';
      case 'REJECTED':
        return '거부';
      case 'EXPIRED':
        return '만료';
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
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('견적서 관리'),
        actions: [
          ElevatedButton.icon(
            onPressed: () {
              // 새 견적서 작성 기능 (향후 구현)
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('새 견적서 작성 기능은 곧 추가됩니다')),
              );
            },
            icon: const Icon(Icons.add),
            label: const Text('새 견적서'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // 검색 및 필터 영역
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: TextField(
                            controller: _searchController,
                            decoration: const InputDecoration(
                              labelText: '견적번호 또는 고객명 검색',
                              prefixIcon: Icon(Icons.search),
                              border: OutlineInputBorder(),
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
                          flex: 2,
                          child: DropdownButtonFormField<String>(
                            initialValue: _selectedStatus,
                            decoration: const InputDecoration(
                              labelText: '상태',
                              border: OutlineInputBorder(),
                            ),
                            items: [
                              {'value': 'ALL', 'label': '전체'},
                              {'value': 'PENDING', 'label': '대기중'},
                              {'value': 'APPROVED', 'label': '승인'},
                              {'value': 'REJECTED', 'label': '거부'},
                              {'value': 'EXPIRED', 'label': '만료'},
                            ].map((status) {
                              return DropdownMenuItem<String>(
                                value: status['value'],
                                child: Text(status['label']!),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() {
                                _selectedStatus = value!;
                              });
                              _applyFilters();
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        ElevatedButton.icon(
                          onPressed: () async {
                            final DateTimeRange? picked = await showDateRangePicker(
                              context: context,
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now().add(const Duration(days: 365)),
                              initialDateRange: _dateRange,
                            );
                            if (picked != null) {
                              setState(() {
                                _dateRange = picked;
                              });
                              _applyFilters();
                            }
                          },
                          icon: const Icon(Icons.date_range),
                          label: Text(_dateRange == null 
                            ? '기간 선택' 
                            : '${DateFormat('MM/dd').format(_dateRange!.start)} - ${DateFormat('MM/dd').format(_dateRange!.end)}'
                          ),
                        ),
                        const SizedBox(width: 8),
                        TextButton.icon(
                          onPressed: _clearFilters,
                          icon: const Icon(Icons.clear),
                          label: const Text('초기화'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text('총 ${_filteredQuotes.length}건의 견적서'),
                        const Spacer(),
                        ElevatedButton.icon(
                          onPressed: _fetchQuotes,
                          icon: const Icon(Icons.refresh),
                          label: const Text('새로고침'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // 견적서 목록 테이블
            Expanded(
              child: Card(
                child: DataTable2(
                  columnSpacing: 12,
                  horizontalMargin: 12,
                  minWidth: 900,
                  columns: const [
                    DataColumn2(label: Text('견적번호'), size: ColumnSize.M),
                    DataColumn2(label: Text('고객명'), size: ColumnSize.L),
                    DataColumn2(label: Text('견적일'), size: ColumnSize.M),
                    DataColumn2(label: Text('유효기한'), size: ColumnSize.M),
                    DataColumn2(label: Text('구분'), size: ColumnSize.S),
                    DataColumn2(label: Text('상태'), size: ColumnSize.S),
                    DataColumn2(label: Text('품목수'), size: ColumnSize.S, numeric: true),
                    DataColumn2(label: Text('금액'), size: ColumnSize.M, numeric: true),
                    DataColumn2(label: Text('액션'), size: ColumnSize.S),
                  ],
                  rows: _filteredQuotes.map((quote) {
                    final isExpired = DateTime.now().isAfter(DateTime.parse(quote['validDate']));
                    return DataRow(
                      onSelectChanged: (_) => _showQuoteDetail(quote),
                      cells: [
                        DataCell(Text(quote['quoteNo'])),
                        DataCell(Text(quote['customerName'])),
                        DataCell(Text(DateFormat('MM-dd HH:mm').format(DateTime.parse(quote['quoteDate'])))),
                        DataCell(
                          Text(
                            quote['validDate'],
                            style: TextStyle(
                              color: isExpired ? Colors.red : Colors.black,
                              fontWeight: isExpired ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ),
                        DataCell(Text(quote['quoteType'])),
                        DataCell(
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _getStatusColor(quote['status']),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _getStatusText(quote['status']),
                              style: const TextStyle(color: Colors.white, fontSize: 12),
                            ),
                          ),
                        ),
                        DataCell(Text('${quote['itemCount']}')),
                        DataCell(Text(NumberFormat.compactCurrency(locale: 'ko_KR', symbol: '₩').format(quote['totalAmount']))),
                        DataCell(
                          PopupMenuButton<String>(
                            onSelected: (value) {
                              switch (value) {
                                case 'detail':
                                  _showQuoteDetail(quote);
                                  break;
                                case 'edit':
                                  if (quote['status'] == 'PENDING') _editQuote(quote);
                                  break;
                                case 'copy':
                                  _copyQuote(quote);
                                  break;
                                case 'pdf':
                                  _generateQuotePDF(quote);
                                  break;
                                case 'excel':
                                  _generateQuoteExcel(quote);
                                  break;
                                case 'convert':
                                  if (quote['status'] == 'APPROVED') _convertToOrder(quote);
                                  break;
                                case 'delete':
                                  if (quote['status'] == 'PENDING') _deleteQuote(quote);
                                  break;
                              }
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(value: 'detail', child: Text('상세보기')),
                              if (quote['status'] == 'PENDING')
                                const PopupMenuItem(value: 'edit', child: Text('수정')),
                              const PopupMenuItem(value: 'copy', child: Text('복사')),
                              const PopupMenuItem(value: 'pdf', child: Text('PDF 출력')),
                              const PopupMenuItem(value: 'excel', child: Text('Excel 출력')),
                              if (quote['status'] == 'APPROVED')
                                const PopupMenuItem(value: 'convert', child: Text('주문변환')),
                              if (quote['status'] == 'PENDING')
                                const PopupMenuItem(value: 'delete', child: Text('삭제')),
                            ],
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}