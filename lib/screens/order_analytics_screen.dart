import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/auth_provider.dart';
import '../providers/sales_data_provider.dart';

class OrderAnalyticsScreen extends StatefulWidget {
  const OrderAnalyticsScreen({super.key});

  @override
  State<OrderAnalyticsScreen> createState() => _OrderAnalyticsScreenState();
}

class _OrderAnalyticsScreenState extends State<OrderAnalyticsScreen> {
  bool _isLoading = true;
  Map<String, dynamic> _analyticsData = {};
  String _selectedPeriod = '당해년도';
  String _selectedChart = 'orders'; // orders, revenue, customers
  bool _disposed = false;
  
  // 매출 데이터를 차트 데이터로 변환
  List<Map<String, dynamic>> _convertSalesDataToChartData(List<Map<String, dynamic>> salesData) {
    return salesData.take(12).map((item) => {
      'period': item['PERIOD'] ?? 'N/A',
      'orders': (item['ORDER_COUNT'] ?? 0),
      'revenue': (item['SUM_SALE_AMT_WON'] ?? 0.0),
      'customers': (item['CUSTOMER_COUNT'] ?? 0),
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _fetchAnalyticsData();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Future<void> _fetchAnalyticsData() async {
    final salesProvider = Provider.of<SalesDataProvider>(context, listen: false);
    
    if (mounted && !_disposed) {
      setState(() {
        _isLoading = true;
      });
    }
    
    try {
      // 통합매출분석 데이터 로드
      await salesProvider.loadSalesData();
      
      // 매출 데이터를 주문 분석 형태로 변환
      final salesData = salesProvider.salesSummaryData;
      final stats = salesProvider.getSummaryStats();
      
      if (mounted && !_disposed) {
        setState(() {
          _analyticsData = {
            'summary': {
              'total_orders': stats['totalOrders'],
              'total_revenue': stats['totalSales'],
              'average_order': stats['averageSales'],
              'data_count': stats['dataCount'],
            },
            'chart_data': _convertSalesDataToChartData(salesData),
            'period_info': {
              'from': DateFormat('yyyy-MM-dd').format(salesProvider.fromDate),
              'to': DateFormat('yyyy-MM-dd').format(salesProvider.toDate),
              'last_updated': salesProvider.lastUpdated?.toString() ?? 'N/A',
            }
          };
          _isLoading = false;
        });
      }
    } catch (e) {
      print('주문 분석 데이터 로드 실패: $e');
      if (mounted && !_disposed) {
        setState(() {
          _analyticsData = _getMockAnalyticsData();
          _isLoading = false;
        });
      }
    }
  }

  Map<String, dynamic> _getMockAnalyticsData() {
    return {
      'periodStats': [
        {'period': '2023-07', 'orders': 45, 'revenue': 12000000, 'customers': 15},
        {'period': '2023-08', 'orders': 52, 'revenue': 14500000, 'customers': 18},
        {'period': '2023-09', 'orders': 38, 'revenue': 10800000, 'customers': 14},
        {'period': '2023-10', 'orders': 61, 'revenue': 17200000, 'customers': 22},
        {'period': '2023-11', 'orders': 43, 'revenue': 12100000, 'customers': 16},
        {'period': '2023-12', 'orders': 39, 'revenue': 11000000, 'customers': 13},
      ],
      'statusDistribution': {
        'PENDING': 23,
        'COMPLETED': 133,
        'SHIPPED': 45,
        'CANCELLED': 8,
      },
      'orderTypeDistribution': {
        '주문': 156,
        '펀넬': 53,
      },
      'topProducts': [
        {'productName': '의료용품 A', 'orders': 45, 'revenue': 6750000},
        {'productName': '의료장비 B', 'orders': 38, 'revenue': 7600000},
        {'productName': '소모품 C', 'orders': 52, 'revenue': 3120000},
        {'productName': '검사용품 D', 'orders': 29, 'revenue': 4350000},
        {'productName': '치료용품 E', 'orders': 33, 'revenue': 4950000},
      ],
      'topCustomers': [
        {'customerName': '삼성병원', 'orders': 25, 'revenue': 8500000},
        {'customerName': '서울대병원', 'orders': 18, 'revenue': 6200000},
        {'customerName': '연세병원', 'orders': 15, 'revenue': 4800000},
        {'customerName': '가톨릭병원', 'orders': 12, 'revenue': 3600000},
        {'customerName': '아산병원', 'orders': 14, 'revenue': 4200000},
      ],
      'dailyOrders': List.generate(30, (index) {
        final date = DateTime.now().subtract(Duration(days: 29 - index));
        return {
          'date': DateFormat('MM-dd').format(date),
          'orders': (15 + (index % 7) * 3 + (index % 3)).toInt(),
        };
      }),
      'hourlyDistribution': [
        {'hour': '09:00', 'count': 12},
        {'hour': '10:00', 'count': 18},
        {'hour': '11:00', 'count': 25},
        {'hour': '12:00', 'count': 8},
        {'hour': '13:00', 'count': 15},
        {'hour': '14:00', 'count': 32},
        {'hour': '15:00', 'count': 28},
        {'hour': '16:00', 'count': 22},
        {'hour': '17:00', 'count': 14},
      ],
    };
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // 필터 및 설정
          _buildFilterSection(),
          const SizedBox(height: 20),
          
          // 통계 요약 카드
          _buildSummaryCards(),
          const SizedBox(height: 20),
          
          // 메인 차트
          _buildMainChart(),
          const SizedBox(height: 20),
          
          // 분포 차트들
          Row(
            children: [
              Expanded(child: _buildStatusDistributionChart()),
              const SizedBox(width: 16),
              Expanded(child: _buildOrderTypeChart()),
            ],
          ),
          const SizedBox(height: 20),
          
          // 상위 목록들
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildTopProducts()),
              const SizedBox(width: 16),
              Expanded(child: _buildTopCustomers()),
            ],
          ),
          const SizedBox(height: 20),
          
          // 시간대별 분석
          _buildTimeAnalysis(),
        ],
      ),
    );
  }

  Widget _buildFilterSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Text('기간 선택:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(width: 16),
            DropdownButton<String>(
              value: _selectedPeriod,
              items: ['최근 1개월', '최근 3개월', '최근 6개월', '최근 1년', '전체'].map((period) {
                return DropdownMenuItem(value: period, child: Text(period));
              }).toList(),
              onChanged: (value) {
                if (mounted && !_disposed) {
                  setState(() {
                    _selectedPeriod = value!;
                  });
                  _fetchAnalyticsData();
                }
              },
            ),
            const SizedBox(width: 32),
            const Text('차트 종류:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(width: 16),
            SegmentedButton<String>(
              selected: {_selectedChart},
              onSelectionChanged: (Set<String> selection) {
                if (mounted && !_disposed) {
                  setState(() {
                    _selectedChart = selection.first;
                  });
                }
              },
              segments: const [
                ButtonSegment(value: 'orders', label: Text('주문량')),
                ButtonSegment(value: 'revenue', label: Text('매출')),
                ButtonSegment(value: 'customers', label: Text('고객수')),
              ],
            ),
            const Spacer(),
            ElevatedButton.icon(
              onPressed: _fetchAnalyticsData,
              icon: const Icon(Icons.refresh),
              label: const Text('새로고침'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCards() {
    final periodStats = _analyticsData['periodStats'] as List<dynamic>? ?? [];
    final totalOrders = periodStats.fold<int>(0, (sum, item) => sum + (item['orders'] as int));
    final totalRevenue = periodStats.fold<int>(0, (sum, item) => sum + (item['revenue'] as int));
    final avgOrderValue = totalOrders > 0 ? totalRevenue / totalOrders : 0.0;
    
    return Row(
      children: [
        Expanded(
          child: _buildSummaryCard(
            '총 주문수',
            '$totalOrders건',
            Icons.shopping_cart,
            Colors.blue,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildSummaryCard(
            '총 매출액',
            NumberFormat.compactCurrency(locale: 'ko_KR', symbol: '₩').format(totalRevenue),
            Icons.attach_money,
            Colors.green,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildSummaryCard(
            '평균 주문액',
            NumberFormat.compactCurrency(locale: 'ko_KR', symbol: '₩').format(avgOrderValue),
            Icons.trending_up,
            Colors.orange,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildSummaryCard(
            '고객수',
            '${(_analyticsData['topCustomers'] as List?)?.length ?? 0}명',
            Icons.people,
            Colors.purple,
          ),
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
                      fontSize: 18,
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

  Widget _buildMainChart() {
    final periodStats = _analyticsData['periodStats'] as List<dynamic>? ?? [];
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${_getChartTitle(_selectedChart)} 추이',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 300,
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(show: true),
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: true, reservedSize: 60),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          if (value.toInt() < periodStats.length) {
                            final period = periodStats[value.toInt()]['period'] as String;
                            return Text(period.substring(5)); // MM만 표시
                          }
                          return const Text('');
                        },
                      ),
                    ),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: true),
                  lineBarsData: [
                    LineChartBarData(
                      spots: periodStats.asMap().entries.map((entry) {
                        final value = _getChartValue(entry.value, _selectedChart);
                        return FlSpot(entry.key.toDouble(), value);
                      }).toList(),
                      isCurved: true,
                      color: _getChartColor(_selectedChart),
                      barWidth: 3,
                      belowBarData: BarAreaData(
                        show: true,
                        color: _getChartColor(_selectedChart).withOpacity(0.1),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getChartTitle(String chartType) {
    switch (chartType) {
      case 'orders': return '주문량';
      case 'revenue': return '매출';
      case 'customers': return '고객수';
      default: return '주문량';
    }
  }

  double _getChartValue(Map<String, dynamic> data, String chartType) {
    switch (chartType) {
      case 'orders': return (data['orders'] as int).toDouble();
      case 'revenue': return (data['revenue'] as int).toDouble() / 1000000; // 백만원 단위
      case 'customers': return (data['customers'] as int).toDouble();
      default: return (data['orders'] as int).toDouble();
    }
  }

  Color _getChartColor(String chartType) {
    switch (chartType) {
      case 'orders': return Colors.blue;
      case 'revenue': return Colors.green;
      case 'customers': return Colors.orange;
      default: return Colors.blue;
    }
  }

  Widget _buildStatusDistributionChart() {
    final statusData = _analyticsData['statusDistribution'] as Map<String, dynamic>? ?? {};
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '주문 상태별 분포',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 200,
              child: PieChart(
                PieChartData(
                  sections: statusData.entries.map((entry) {
                    return PieChartSectionData(
                      value: entry.value.toDouble(),
                      title: '${entry.key}\n${entry.value}',
                      color: _getStatusChartColor(entry.key),
                      radius: 50,
                    );
                  }).toList(),
                  centerSpaceRadius: 40,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderTypeChart() {
    final orderTypeData = _analyticsData['orderTypeDistribution'] as Map<String, dynamic>? ?? {};
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '주문 유형별 분포',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 200,
              child: PieChart(
                PieChartData(
                  sections: orderTypeData.entries.map((entry) {
                    return PieChartSectionData(
                      value: entry.value.toDouble(),
                      title: '${entry.key}\n${entry.value}',
                      color: entry.key == '주문' ? Colors.blue : Colors.green,
                      radius: 50,
                    );
                  }).toList(),
                  centerSpaceRadius: 40,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusChartColor(String status) {
    switch (status) {
      case 'PENDING': return Colors.orange;
      case 'COMPLETED': return Colors.green;
      case 'SHIPPED': return Colors.blue;
      case 'CANCELLED': return Colors.red;
      default: return Colors.grey;
    }
  }

  Widget _buildTopProducts() {
    final topProducts = _analyticsData['topProducts'] as List<dynamic>? ?? [];
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '상위 제품',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...topProducts.take(5).map((product) {
              return ListTile(
                dense: true,
                leading: CircleAvatar(
                  backgroundColor: Colors.blue,
                  child: Text(
                    product['productName'].toString().substring(0, 1),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                title: Text(product['productName']),
                subtitle: Text('${product['orders']}건 주문'),
                trailing: Text(
                  NumberFormat.compactCurrency(locale: 'ko_KR', symbol: '₩')
                      .format(product['revenue']),
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
    final topCustomers = _analyticsData['topCustomers'] as List<dynamic>? ?? [];
    
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
                    customer['customerName'].toString().substring(0, 1),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                title: Text(customer['customerName']),
                subtitle: Text('${customer['orders']}건 주문'),
                trailing: Text(
                  NumberFormat.compactCurrency(locale: 'ko_KR', symbol: '₩')
                      .format(customer['revenue']),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeAnalysis() {
    final dailyOrders = _analyticsData['dailyOrders'] as List<dynamic>? ?? [];
    final hourlyDistribution = _analyticsData['hourlyDistribution'] as List<dynamic>? ?? [];
    
    return Row(
      children: [
        // 일별 주문량
        Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '최근 30일 주문량',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 200,
                    child: BarChart(
                      BarChartData(
                        alignment: BarChartAlignment.spaceAround,
                        maxY: dailyOrders.isEmpty ? 100 : 
                             dailyOrders.map((e) => e['orders'] as num).reduce((a, b) => a > b ? a : b).toDouble() * 1.2,
                        barGroups: dailyOrders.asMap().entries.take(15).map((entry) {
                          return BarChartGroupData(
                            x: entry.key,
                            barRods: [
                              BarChartRodData(
                                toY: (entry.value['orders'] as num).toDouble(),
                                color: Colors.blue,
                                width: 8,
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
                                if (value.toInt() < dailyOrders.length && value.toInt() % 5 == 0) {
                                  return Text(dailyOrders[value.toInt()]['date']);
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
          ),
        ),
        const SizedBox(width: 16),
        // 시간대별 주문 분포
        Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '시간대별 주문 분포',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 200,
                    child: BarChart(
                      BarChartData(
                        alignment: BarChartAlignment.spaceAround,
                        maxY: hourlyDistribution.isEmpty ? 100 : 
                             hourlyDistribution.map((e) => e['count'] as num).reduce((a, b) => a > b ? a : b).toDouble() * 1.2,
                        barGroups: hourlyDistribution.asMap().entries.map((entry) {
                          return BarChartGroupData(
                            x: entry.key,
                            barRods: [
                              BarChartRodData(
                                toY: (entry.value['count'] as num).toDouble(),
                                color: Colors.green,
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
                                if (value.toInt() < hourlyDistribution.length) {
                                  final hour = hourlyDistribution[value.toInt()]['hour'] as String;
                                  return Text(hour.substring(0, 2)); // HH만 표시
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
          ),
        ),
      ],
    );
  }
}