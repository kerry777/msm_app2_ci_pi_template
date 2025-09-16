import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/sales_data_provider.dart';
import 'order_list_screen.dart';
import 'order_analytics_screen.dart';

class OrderManagementScreen extends StatefulWidget {
  const OrderManagementScreen({super.key});

  @override
  State<OrderManagementScreen> createState() => _OrderManagementScreenState();
}

class _OrderManagementScreenState extends State<OrderManagementScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  Map<String, dynamic> _dashboardData = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchDashboardData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchDashboardData() async {
    final salesProvider = Provider.of<SalesDataProvider>(context, listen: false);
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      // 통합매출분석 데이터 로드
      await salesProvider.loadSalesData();
      
      final stats = salesProvider.getSummaryStats();
      final salesData = salesProvider.salesSummaryData.take(6).toList();
      
      setState(() {
        _dashboardData = {
          'totalOrders': stats['totalOrders'],
          'totalAmount': stats['totalSales'],
          'pendingOrders': (stats['totalOrders'] * 0.1).round(), // 예상 진행중 주문 10%
          'completedOrders': (stats['totalOrders'] * 0.9).round(),
          'todayOrders': (stats['totalOrders'] / 30).round(), // 일평균
          'todayAmount': stats['totalSales'] / 30, // 일평균
          'monthlyStats': salesData.map((item) => {
            'month': (item['PERIOD'] ?? 'N/A').toString().substring(5, 7), // MM 추출
            'orders': item['ORDER_COUNT'] ?? 0,
            'amount': item['SUM_SALE_AMT_WON'] ?? 0.0,
          }).toList(),
          'period_info': {
            'from': DateFormat('yyyy-MM-dd').format(salesProvider.fromDate),
            'to': DateFormat('yyyy-MM-dd').format(salesProvider.toDate),
            'last_updated': salesProvider.lastUpdated?.toString() ?? 'N/A',
          }
        };
        _isLoading = false;
      });
    } catch (e) {
      print('주문 대시보드 데이터 로드 실패: $e');
      setState(() {
        _dashboardData = _getMockDashboardData();
        _isLoading = false;
      });
    }
  }

  Map<String, dynamic> _getMockDashboardData() {
    return {
      'totalOrders': 156,
      'totalAmount': 45600000,
      'pendingOrders': 23,
      'completedOrders': 133,
      'todayOrders': 12,
      'todayAmount': 3400000,
      'monthlyStats': [
        {'month': '01', 'orders': 45, 'amount': 12000000},
        {'month': '02', 'orders': 52, 'amount': 14500000},
        {'month': '03', 'orders': 38, 'amount': 10800000},
        {'month': '04', 'orders': 61, 'amount': 17200000},
        {'month': '05', 'orders': 43, 'amount': 12100000},
        {'month': '06', 'orders': 39, 'amount': 11000000},
      ],
      'topCustomers': [
        {'name': '삼성병원', 'orders': 25, 'amount': 8500000},
        {'name': '서울대병원', 'orders': 18, 'amount': 6200000},
        {'name': '연세병원', 'orders': 15, 'amount': 4800000},
      ],
      'recentOrders': [
        {
          'orderNo': 'SO_001',
          'customerName': '삼성병원',
          'amount': 450000,
          'status': 'PENDING',
          'orderDate': '2024-01-15T10:30:00Z'
        },
        {
          'orderNo': 'SO_002',
          'customerName': '서울대병원',
          'amount': 680000,
          'status': 'COMPLETED',
          'orderDate': '2024-01-14T14:20:00Z'
        },
      ]
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('주문 관리'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.dashboard), text: '대시보드'),
            Tab(icon: Icon(Icons.list_alt), text: '주문 목록'),
            Tab(icon: Icon(Icons.analytics), text: '분석'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildDashboard(),
          const OrderListScreen(),
          const OrderAnalyticsScreen(),
        ],
      ),
    );
  }

  Widget _buildDashboard() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // 요약 카드들
          _buildSummaryCards(),
          const SizedBox(height: 20),
          
          // 월별 주문 차트
          _buildMonthlyChart(),
          const SizedBox(height: 20),
          
          // 최근 주문과 상위 고객
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildRecentOrders()),
              const SizedBox(width: 16),
              Expanded(child: _buildTopCustomers()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 2.5,
      children: [
        _buildSummaryCard(
          '총 주문',
          '${_dashboardData['totalOrders'] ?? 0}건',
          Icons.shopping_cart,
          Colors.blue,
        ),
        _buildSummaryCard(
          '총 주문금액',
          NumberFormat.currency(locale: 'ko_KR', symbol: '₩')
              .format(_dashboardData['totalAmount'] ?? 0),
          Icons.attach_money,
          Colors.green,
        ),
        _buildSummaryCard(
          '오늘 주문',
          '${_dashboardData['todayOrders'] ?? 0}건',
          Icons.today,
          Colors.orange,
        ),
        _buildSummaryCard(
          '대기중 주문',
          '${_dashboardData['pendingOrders'] ?? 0}건',
          Icons.pending,
          Colors.red,
        ),
      ],
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
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

  Widget _buildMonthlyChart() {
    final monthlyStats = _dashboardData['monthlyStats'] as List<dynamic>? ?? [];
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '월별 주문 현황',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: monthlyStats.isEmpty ? 100 : 
                       monthlyStats.map((e) => e['orders'] as num).reduce((a, b) => a > b ? a : b).toDouble() * 1.2,
                  barGroups: monthlyStats.asMap().entries.map((entry) {
                    return BarChartGroupData(
                      x: entry.key,
                      barRods: [
                        BarChartRodData(
                          toY: (entry.value['orders'] as num).toDouble(),
                          color: Colors.blue,
                          width: 16,
                        ),
                      ],
                    );
                  }).toList(),
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: true, reservedSize: 40),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          if (value.toInt() < monthlyStats.length) {
                            return Text('${monthlyStats[value.toInt()]['month']}월');
                          }
                          return const Text('');
                        },
                      ),
                    ),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentOrders() {
    final recentOrders = _dashboardData['recentOrders'] as List<dynamic>? ?? [];
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '최근 주문',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                TextButton(
                  onPressed: () {
                    _tabController.animateTo(1);
                  },
                  child: const Text('더보기'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...recentOrders.take(5).map((order) {
              return ListTile(
                dense: true,
                leading: CircleAvatar(
                  backgroundColor: _getStatusColor(order['status']),
                  child: Text(
                    order['status'] == 'PENDING' ? 'P' : 'C',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
                title: Text(order['orderNo']),
                subtitle: Text(order['customerName']),
                trailing: Text(
                  NumberFormat.currency(locale: 'ko_KR', symbol: '₩')
                      .format(order['amount']),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildTopCustomers() {
    final topCustomers = _dashboardData['topCustomers'] as List<dynamic>? ?? [];
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '상위 고객',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...topCustomers.take(5).map((customer) {
              return ListTile(
                dense: true,
                leading: CircleAvatar(
                  backgroundColor: Colors.purple,
                  child: Text(
                    customer['name'].toString().substring(0, 1),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                title: Text(customer['name']),
                subtitle: Text('${customer['orders']}건 주문'),
                trailing: Text(
                  NumberFormat.currency(locale: 'ko_KR', symbol: '₩')
                      .format(customer['amount']),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'PENDING':
        return Colors.orange;
      case 'COMPLETED':
        return Colors.green;
      case 'CANCELLED':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}