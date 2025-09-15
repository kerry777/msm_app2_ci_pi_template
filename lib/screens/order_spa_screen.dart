import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class OrderSpaScreen extends StatefulWidget {
  const OrderSpaScreen({Key? key}) : super(key: key);

  @override
  State<OrderSpaScreen> createState() => _OrderSpaScreenState();
}

class _OrderSpaScreenState extends State<OrderSpaScreen> {
  String _status = 'Order System Ready';
  bool _hasUnsavedChanges = false;
  List<Map<String, dynamic>> _orderItems = [];

  @override
  void initState() {
    super.initState();
    _initializeOrder();
  }

  void _initializeOrder() {
    _orderItems = [
      {
        'product': '제품 A',
        'quantity': 10,
        'price': 1000,
        'total': 10000,
        'notes': '기본 제품'
      },
      {
        'product': '제품 B',
        'quantity': 5,
        'price': 2000,
        'total': 10000,
        'notes': '프리미엄 제품'
      },
    ];
  }

  void _addOrderItem() {
    setState(() {
      _orderItems.add({
        'product': '새 제품',
        'quantity': 1,
        'price': 1000,
        'total': 1000,
        'notes': ''
      });
      _hasUnsavedChanges = true;
      _status = 'Order in Progress...';
    });
  }

  void _removeOrderItem(int index) {
    setState(() {
      _orderItems.removeAt(index);
      _hasUnsavedChanges = true;
      _status = 'Order in Progress...';
    });
  }

  void _saveOrder({bool isDraft = false}) {
    setState(() {
      _hasUnsavedChanges = !isDraft;
      _status = isDraft ? 'Order Draft Saved' : 'Order Saved';
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(isDraft ? '주문이 임시저장되었습니다' : '주문이 저장되었습니다'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _completeOrder() {
    setState(() {
      _status = 'Order Completed Successfully';
      _hasUnsavedChanges = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🎉 주문이 성공적으로 완료되었습니다!'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 3),
      ),
    );
  }

  int get _totalAmount {
    return _orderItems.fold(0, (sum, item) => sum + (item['total'] as int));
  }

  Future<bool> _onWillPop() async {
    if (_hasUnsavedChanges) {
      final result = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('⚠️ 저장되지 않은 변경사항'),
          content: const Text('작성 중인 주문이 있습니다. 정말로 나가시겠습니까?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('나가기'),
            ),
          ],
        ),
      );
      return result ?? false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              const Text('🛒 주문등록'),
              if (_hasUnsavedChanges) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.orange,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    '작성중',
                    style: TextStyle(fontSize: 10, color: Colors.white),
                  ),
                ),
              ],
            ],
          ),
          backgroundColor: const Color(0xFF667EEA),
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                setState(() {
                  _status = 'Refreshing...';
                });
                Future.delayed(const Duration(seconds: 1), () {
                  setState(() {
                    _status = 'Order System Ready';
                  });
                });
              },
              tooltip: '새로고침',
            ),
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: () => _saveOrder(isDraft: true),
              tooltip: '임시저장',
            ),
          ],
        ),
        body: Column(
          children: [
            // 상태 표시
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                ),
                color: _hasUnsavedChanges ? Colors.orange : null,
              ),
              child: Row(
                children: [
                  Expanded(
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
                  if (_hasUnsavedChanges) ...[
                    const Icon(
                      Icons.edit,
                      color: Colors.white,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      '변경사항 있음',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // 사용자 정보 및 주문 정보
            Container(
              margin: const EdgeInsets.all(16.0),
              child: Consumer<AuthProvider>(
                builder: (context, authProvider, child) {
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.shopping_cart, size: 24, color: Colors.blue[600]),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '주문 등록',
                                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                    ),
                                    Text(
                                      '주문자: ${authProvider.userInfo?['KOR_NM']?.toString() ?? 'Unknown'}',
                                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                '총 금액: ₩${_totalAmount.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}',
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '주문일: ${DateTime.now().toString().substring(0, 16)}',
                            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            // 주문 항목 리스트
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          '주문 항목',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        ElevatedButton.icon(
                          onPressed: _addOrderItem,
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('항목 추가'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF667EEA),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ListView.builder(
                        itemCount: _orderItems.length,
                        itemBuilder: (context, index) {
                          final item = _orderItems[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: const Color(0xFF667EEA),
                                child: Text('${index + 1}', style: const TextStyle(color: Colors.white)),
                              ),
                              title: Text(
                                item['product'],
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Text(
                                '수량: ${item['quantity']} | 단가: ₩${item['price']} | ${item['notes']}',
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '₩${item['total'].toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}',
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                                    onPressed: () => _removeOrderItem(index),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
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
                    onPressed: () async {
                      if (await _onWillPop()) {
                        Navigator.pop(context);
                      }
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
                    onPressed: _hasUnsavedChanges ? () {
                      _saveOrder(isDraft: true);
                      Navigator.pop(context);
                    } : () {
                      Navigator.pop(context);
                    },
                    icon: Icon(
                      _hasUnsavedChanges ? Icons.save : Icons.home,
                      size: 16
                    ),
                    label: Text(_hasUnsavedChanges ? '저장 후 메인' : '메인'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _hasUnsavedChanges
                          ? Colors.orange
                          : const Color(0xFF667EEA),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _completeOrder,
                    icon: const Icon(Icons.check_circle, size: 16),
                    label: const Text('주문 완료'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}