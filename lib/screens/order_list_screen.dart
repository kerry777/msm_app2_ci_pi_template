import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:data_table_2/data_table_2.dart';
import '../providers/auth_provider.dart';
import '../utils/order_report_generator.dart';
import '../config/app_config.dart';

class OrderListScreen extends StatefulWidget {
  const OrderListScreen({super.key});

  @override
  State<OrderListScreen> createState() => _OrderListScreenState();
}

class _OrderListScreenState extends State<OrderListScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _orders = [];
  List<Map<String, dynamic>> _filteredOrders = [];
  
  String _searchText = '';
  String _selectedStatus = 'ALL';
  DateTimeRange? _dateRange;
  
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchOrders();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchOrders() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    
    try {
      final response = await http.get(
        Uri.parse('${AppConfig.apiBaseUrl}/orders'),
        headers: {'Authorization': 'Bearer ${auth.token}'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> orderData = jsonDecode(utf8.decode(response.bodyBytes));
        setState(() {
          _orders = orderData.cast<Map<String, dynamic>>();
          _filteredOrders = List.from(_orders);
          _isLoading = false;
        });
      } else {
        // 모의 데이터로 대체
        setState(() {
          _orders = _getMockOrders();
          _filteredOrders = List.from(_orders);
          _isLoading = false;
        });
      }
    } catch (e) {
      // 모의 데이터로 대체
      setState(() {
        _orders = _getMockOrders();
        _filteredOrders = List.from(_orders);
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> _getMockOrders() {
    return [
      {
        'orderNo': 'SO_001',
        'customerName': '삼성병원',
        'customerCode': 'CUST001',
        'deliveryDate': '2024-01-20',
        'orderDate': '2024-01-15T10:30:00Z',
        'orderType': '주문',
        'status': 'PENDING',
        'totalAmount': 4500000,
        'itemCount': 15,
        'items': [
          {'ERPCODE': 'ITEM001', '품명': '의료용품 A', '규격': '10cm', 'quantity': 5, 'unitPrice': 150000},
          {'ERPCODE': 'ITEM002', '품명': '의료용품 B', '규격': '20cm', 'quantity': 10, 'unitPrice': 300000},
        ]
      },
      {
        'orderNo': 'SO_002',
        'customerName': '서울대병원',
        'customerCode': 'CUST002',
        'deliveryDate': '2024-01-18',
        'orderDate': '2024-01-14T14:20:00Z',
        'orderType': '펀넬',
        'status': 'COMPLETED',
        'totalAmount': 6800000,
        'itemCount': 22,
        'items': [
          {'ERPCODE': 'ITEM003', '품명': '의료장비 C', '규격': 'Standard', 'quantity': 2, 'unitPrice': 1200000},
          {'ERPCODE': 'ITEM004', '품명': '소모품 D', '규격': '5ml', 'quantity': 20, 'unitPrice': 220000},
        ]
      },
      {
        'orderNo': 'SO_003',
        'customerName': '연세병원',
        'customerCode': 'CUST003',
        'deliveryDate': '2024-01-22',
        'orderDate': '2024-01-16T09:15:00Z',
        'orderType': '주문',
        'status': 'SHIPPED',
        'totalAmount': 3200000,
        'itemCount': 8,
        'items': [
          {'ERPCODE': 'ITEM005', '품명': '검사용품 E', '규격': 'Large', 'quantity': 8, 'unitPrice': 400000},
        ]
      },
      {
        'orderNo': 'SO_004',
        'customerName': '가톨릭병원',
        'customerCode': 'CUST004',
        'deliveryDate': '2024-01-16',
        'orderDate': '2024-01-12T16:45:00Z',
        'orderType': '주문',
        'status': 'CANCELLED',
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
      _filteredOrders = _orders.where((order) {
        // 검색 텍스트 필터
        final matchesSearch = _searchText.isEmpty ||
            order['orderNo'].toLowerCase().contains(_searchText.toLowerCase()) ||
            order['customerName'].toLowerCase().contains(_searchText.toLowerCase());
        
        // 상태 필터
        final matchesStatus = _selectedStatus == 'ALL' || order['status'] == _selectedStatus;
        
        // 날짜 범위 필터
        bool matchesDate = true;
        if (_dateRange != null) {
          final orderDate = DateTime.parse(order['orderDate']);
          matchesDate = orderDate.isAfter(_dateRange!.start.subtract(const Duration(days: 1))) &&
                       orderDate.isBefore(_dateRange!.end.add(const Duration(days: 1)));
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
      _filteredOrders = List.from(_orders);
    });
  }

  void _showOrderDetail(Map<String, dynamic> order) {
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
                      '주문 상세 - ${order['orderNo']}',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // 주문 정보
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('주문 정보', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Text('고객명: ${order['customerName']}'),
                        Text('고객코드: ${order['customerCode']}'),
                        Text('주문일: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.parse(order['orderDate']))}'),
                        Text('출고요청일: ${order['deliveryDate']}'),
                        Text('주문구분: ${order['orderType']}'),
                        Text('상태: ${_getStatusText(order['status'])}'),
                        Text('총액: ${NumberFormat.currency(locale: 'ko_KR', symbol: '₩').format(order['totalAmount'])}'),
                        Text('품목수: ${order['itemCount']}건'),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),
                const Text('주문 품목', style: TextStyle(fontWeight: FontWeight.bold)),
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
                      rows: (order['items'] as List<dynamic>).map((item) {
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
                    if (order['status'] == 'PENDING') ...[
                      ElevatedButton.icon(
                        onPressed: () => _editOrder(order),
                        icon: const Icon(Icons.edit),
                        label: const Text('수정'),
                      ),
                      const SizedBox(width: 8),
                    ],
                    ElevatedButton.icon(
                      onPressed: () => _copyOrder(order),
                      icon: const Icon(Icons.copy),
                      label: const Text('복사'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () => _generateOrderPDF(order),
                      icon: const Icon(Icons.picture_as_pdf),
                      label: const Text('PDF'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () => _generateOrderExcel(order),
                      icon: const Icon(Icons.table_chart),
                      label: const Text('Excel'),
                    ),
                    if (order['status'] == 'PENDING') ...[
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: () => _deleteOrder(order),
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

  void _editOrder(Map<String, dynamic> order) {
    Navigator.of(context).pop(); // 상세 다이얼로그 닫기
    _showStatusChangeDialog(order);
  }

  void _copyOrder(Map<String, dynamic> order) {
    Navigator.of(context).pop(); // 상세 다이얼로그 닫기
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('주문 복사'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${order['orderNo']} 주문을 복사하시겠습니까?'),
              const SizedBox(height: 16),
              const Text('복사된 주문은 "대기중" 상태로 생성됩니다.'),
              const Text('필요시 품목이나 수량을 수정할 수 있습니다.'),
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
                await _performCopyOrder(order);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${order['orderNo']} 주문이 복사되었습니다')),
                );
                _fetchOrders(); // 목록 새로고침
              },
              child: const Text('복사'),
            ),
          ],
        );
      },
    );
  }

  void _deleteOrder(Map<String, dynamic> order) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('주문 삭제'),
          content: Text('${order['orderNo']} 주문을 삭제하시겠습니까?\n이 작업은 되돌릴 수 없습니다.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop(); // 삭제 확인 다이얼로그 닫기
                Navigator.of(context).pop(); // 상세 다이얼로그 닫기
                
                // 실제로는 서버 API 호출
                await _performDeleteOrder(order['orderNo']);
                
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${order['orderNo']} 주문이 삭제되었습니다')),
                );
                
                // 목록 새로고침
                _fetchOrders();
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('삭제'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _performDeleteOrder(String orderNo) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    
    try {
      await http.delete(
        Uri.parse('${AppConfig.apiBaseUrl}/orders/$orderNo'),
        headers: {'Authorization': 'Bearer ${auth.token}'},
      );
    } catch (e) {
      print('Delete order error: $e');
    }
  }

  Future<void> _performCopyOrder(Map<String, dynamic> order) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    
    try {
      // 새 주문번호 생성 (기존 주문번호 + _COPY_타임스탬프)
      final timestamp = DateFormat('yyyyMMddHHmm').format(DateTime.now());
      final newOrderNo = '${order['orderNo']}_COPY_$timestamp';
      
      final newOrder = Map<String, dynamic>.from(order);
      newOrder['orderNo'] = newOrderNo;
      newOrder['status'] = 'PENDING';
      newOrder['orderDate'] = DateTime.now().toIso8601String();
      
      await http.post(
        Uri.parse('${AppConfig.apiBaseUrl}/orders'),
        headers: {
          'Authorization': 'Bearer ${auth.token}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(newOrder),
      );
    } catch (e) {
      print('Copy order error: $e');
    }
  }

  void _showStatusChangeDialog(Map<String, dynamic> order) {
    String selectedStatus = order['status'];
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('${order['orderNo']} 상태 변경'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('주문 상태를 변경하시겠습니까?'),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: selectedStatus,
                    decoration: const InputDecoration(
                      labelText: '새 상태',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      {'value': 'PENDING', 'label': '대기중', 'color': Colors.orange},
                      {'value': 'COMPLETED', 'label': '완료', 'color': Colors.green},
                      {'value': 'SHIPPED', 'label': '배송중', 'color': Colors.blue},
                      {'value': 'CANCELLED', 'label': '취소됨', 'color': Colors.red},
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
                  if (selectedStatus != order['status']) ...[
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
                              _getStatusChangeMessage(order['status'], selectedStatus),
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
                  onPressed: selectedStatus != order['status'] 
                    ? () async {
                        Navigator.of(context).pop();
                        await _performStatusChange(order['orderNo'], selectedStatus);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('${order['orderNo']} 상태가 ${_getStatusText(selectedStatus)}로 변경되었습니다')),
                        );
                        _fetchOrders();
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
    if (currentStatus == 'PENDING' && newStatus == 'COMPLETED') {
      return '주문이 완료 처리됩니다. 재고가 차감될 수 있습니다.';
    } else if (currentStatus == 'PENDING' && newStatus == 'SHIPPED') {
      return '주문이 배송 중 상태로 변경됩니다.';
    } else if (newStatus == 'CANCELLED') {
      return '주문이 취소됩니다. 이 작업은 신중하게 검토해주세요.';
    } else if (currentStatus == 'CANCELLED' && newStatus != 'CANCELLED') {
      return '취소된 주문을 다시 활성화합니다.';
    }
    return '상태가 변경됩니다.';
  }

  Future<void> _performStatusChange(String orderNo, String newStatus) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    
    try {
      await http.patch(
        Uri.parse('${AppConfig.apiBaseUrl}/orders/$orderNo/status'),
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

  Future<void> _generateOrderPDF(Map<String, dynamic> order) async {
    try {
      final pdfData = await OrderReportGenerator.generatePDF(
        orderNumber: order['orderNo'],
        customerName: order['customerName'],
        customerCode: order['customerCode'],
        deliveryDate: order['deliveryDate'],
        orderType: order['orderType'],
        items: List<Map<String, dynamic>>.from(order['items']),
      );
      
      await OrderReportGenerator.previewPDF(pdfData);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('PDF 생성 중 오류가 발생했습니다: $e')),
      );
    }
  }

  Future<void> _generateOrderExcel(Map<String, dynamic> order) async {
    try {
      final excelPath = await OrderReportGenerator.generateExcel(
        orderNumber: order['orderNo'],
        customerName: order['customerName'],
        customerCode: order['customerCode'],
        deliveryDate: order['deliveryDate'],
        orderType: order['orderType'],
        items: List<Map<String, dynamic>>.from(order['items']),
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
      case 'COMPLETED':
        return '완료';
      case 'SHIPPED':
        return '배송중';
      case 'CANCELLED':
        return '취소됨';
      default:
        return status;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'PENDING':
        return Colors.orange;
      case 'COMPLETED':
        return Colors.green;
      case 'SHIPPED':
        return Colors.blue;
      case 'CANCELLED':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Padding(
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
                            labelText: '주문번호 또는 고객명 검색',
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
                            {'value': 'COMPLETED', 'label': '완료'},
                            {'value': 'SHIPPED', 'label': '배송중'},
                            {'value': 'CANCELLED', 'label': '취소됨'},
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
                      Text('총 ${_filteredOrders.length}건의 주문'),
                      const Spacer(),
                      ElevatedButton.icon(
                        onPressed: _fetchOrders,
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
          
          // 주문 목록 테이블
          Expanded(
            child: Card(
              child: DataTable2(
                columnSpacing: 12,
                horizontalMargin: 12,
                minWidth: 800,
                columns: const [
                  DataColumn2(label: Text('주문번호'), size: ColumnSize.M),
                  DataColumn2(label: Text('고객명'), size: ColumnSize.L),
                  DataColumn2(label: Text('주문일'), size: ColumnSize.M),
                  DataColumn2(label: Text('출고요청일'), size: ColumnSize.M),
                  DataColumn2(label: Text('구분'), size: ColumnSize.S),
                  DataColumn2(label: Text('상태'), size: ColumnSize.S),
                  DataColumn2(label: Text('품목수'), size: ColumnSize.S, numeric: true),
                  DataColumn2(label: Text('금액'), size: ColumnSize.M, numeric: true),
                  DataColumn2(label: Text('액션'), size: ColumnSize.S),
                ],
                rows: _filteredOrders.map((order) {
                  return DataRow(
                    onSelectChanged: (_) => _showOrderDetail(order),
                    cells: [
                      DataCell(Text(order['orderNo'])),
                      DataCell(Text(order['customerName'])),
                      DataCell(Text(DateFormat('MM-dd HH:mm').format(DateTime.parse(order['orderDate'])))),
                      DataCell(Text(order['deliveryDate'])),
                      DataCell(Text(order['orderType'])),
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _getStatusColor(order['status']),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _getStatusText(order['status']),
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        ),
                      ),
                      DataCell(Text('${order['itemCount']}')),
                      DataCell(Text(NumberFormat.compactCurrency(locale: 'ko_KR', symbol: '₩').format(order['totalAmount']))),
                      DataCell(
                        PopupMenuButton<String>(
                          onSelected: (value) {
                            switch (value) {
                              case 'detail':
                                _showOrderDetail(order);
                                break;
                              case 'edit':
                                if (order['status'] == 'PENDING') _editOrder(order);
                                break;
                              case 'copy':
                                _copyOrder(order);
                                break;
                              case 'pdf':
                                _generateOrderPDF(order);
                                break;
                              case 'excel':
                                _generateOrderExcel(order);
                                break;
                              case 'delete':
                                if (order['status'] == 'PENDING') _deleteOrder(order);
                                break;
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(value: 'detail', child: Text('상세보기')),
                            if (order['status'] == 'PENDING')
                              const PopupMenuItem(value: 'edit', child: Text('수정')),
                            const PopupMenuItem(value: 'copy', child: Text('복사')),
                            const PopupMenuItem(value: 'pdf', child: Text('PDF 출력')),
                            const PopupMenuItem(value: 'excel', child: Text('Excel 출력')),
                            if (order['status'] == 'PENDING')
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
    );
  }
}