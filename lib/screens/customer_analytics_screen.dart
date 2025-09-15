import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:intl/intl.dart';
import '../models/analytics_data.dart';

class CustomerAnalyticsScreen extends StatefulWidget {
  const CustomerAnalyticsScreen({super.key});

  @override
  State<CustomerAnalyticsScreen> createState() => _CustomerAnalyticsScreenState();
}

class _CustomerAnalyticsScreenState extends State<CustomerAnalyticsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<CustomerAnalyticsData> _customerData = [];
  bool _isLoading = true;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _disposed = true;
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted && !_disposed) {
      setState(() {
        _customerData = AnalyticsMockData.getCustomerAnalyticsData();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('고객 중심 분석'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '고객 개요'),
            Tab(text: '구매 행동'),
            Tab(text: '고객 트렌드'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildCustomerOverviewTab(),
                _buildPurchaseBehaviorTab(),
                _buildCustomerTrendTab(),
              ],
            ),
    );
  }

  Widget _buildCustomerOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSummaryCards(),
          const SizedBox(height: 24),
          _buildCustomerRankingChart(),
          const SizedBox(height: 24),
          _buildCustomerTypeDistributionChart(),
        ],
      ),
    );
  }

  Widget _buildPurchaseBehaviorTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('구매 패턴 분석', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _buildAverageOrderValueChart(),
          const SizedBox(height: 24),
          _buildOrderFrequencyChart(),
        ],
      ),
    );
  }

  Widget _buildCustomerTrendTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('고객 매출 추이', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _buildMonthlySalesTrendChart(),
        ],
      ),
    );
  }

  Widget _buildSummaryCards() {
    final totalSales = _customerData.fold(0.0, (sum, customer) => sum + customer.totalSales);
    final totalOrders = _customerData.fold(0, (sum, customer) => sum + customer.orderCount);
    final avgOrderValue = totalSales / totalOrders;

    return Row(
      children: [
        Expanded(child: _buildSummaryCard('총 매출', '₩${NumberFormat('#,###').format(totalSales)}', Icons.account_balance_wallet, Colors.blue)),
        const SizedBox(width: 16),
        Expanded(child: _buildSummaryCard('총 주문수', '${NumberFormat('#,###').format(totalOrders)}건', Icons.shopping_cart, Colors.green)),
        const SizedBox(width: 16),
        Expanded(child: _buildSummaryCard('평균 주문액', '₩${NumberFormat('#,###').format(avgOrderValue)}', Icons.trending_up, Colors.orange)),
      ],
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color),
                const SizedBox(width: 8),
                Text(title, style: const TextStyle(fontSize: 14, color: Colors.grey)),
              ],
            ),
            const SizedBox(height: 8),
            Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerRankingChart() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('고객별 매출 순위', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            SizedBox(
              height: 300,
              child: SfCartesianChart(
                primaryXAxis: CategoryAxis(),
                primaryYAxis: NumericAxis(
                  numberFormat: NumberFormat.compact(),
                  title: AxisTitle(text: '매출액 (원)'),
                ),
                series: <CartesianSeries>[
                  ColumnSeries<CustomerAnalyticsData, String>(
                    dataSource: _customerData,
                    xValueMapper: (CustomerAnalyticsData data, _) => data.customerName,
                    yValueMapper: (CustomerAnalyticsData data, _) => data.totalSales,
                    color: Colors.blue,
                    dataLabelSettings: const DataLabelSettings(isVisible: true),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerTypeDistributionChart() {
    final typeDistribution = <String, double>{};
    for (var customer in _customerData) {
      typeDistribution[customer.customerType] =
          (typeDistribution[customer.customerType] ?? 0) + customer.totalSales;
    }

    final pieData = typeDistribution.entries
        .map((entry) => _PieChartData(entry.key, entry.value))
        .toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('고객 유형별 매출 분포', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            SizedBox(
              height: 300,
              child: SfCircularChart(
                legend: const Legend(isVisible: true, position: LegendPosition.right),
                series: <CircularSeries>[
                  PieSeries<_PieChartData, String>(
                    dataSource: pieData,
                    xValueMapper: (_PieChartData data, _) => data.category,
                    yValueMapper: (_PieChartData data, _) => data.value,
                    dataLabelSettings: const DataLabelSettings(
                      isVisible: true,
                      labelPosition: ChartDataLabelPosition.outside,
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

  Widget _buildAverageOrderValueChart() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('평균 주문액', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            SizedBox(
              height: 300,
              child: SfCartesianChart(
                primaryXAxis: CategoryAxis(),
                primaryYAxis: NumericAxis(
                  numberFormat: NumberFormat.compact(),
                  title: AxisTitle(text: '평균 주문액 (원)'),
                ),
                series: <CartesianSeries>[
                  BarSeries<CustomerAnalyticsData, String>(
                    dataSource: _customerData,
                    xValueMapper: (CustomerAnalyticsData data, _) => data.customerName,
                    yValueMapper: (CustomerAnalyticsData data, _) => data.averageOrderValue,
                    color: Colors.green,
                    dataLabelSettings: const DataLabelSettings(isVisible: true),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderFrequencyChart() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('주문 빈도', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            SizedBox(
              height: 300,
              child: SfCartesianChart(
                primaryXAxis: CategoryAxis(),
                primaryYAxis: NumericAxis(
                  title: AxisTitle(text: '주문 건수'),
                ),
                series: <CartesianSeries>[
                  LineSeries<CustomerAnalyticsData, String>(
                    dataSource: _customerData,
                    xValueMapper: (CustomerAnalyticsData data, _) => data.customerName,
                    yValueMapper: (CustomerAnalyticsData data, _) => data.orderCount,
                    color: Colors.purple,
                    markerSettings: const MarkerSettings(isVisible: true),
                    dataLabelSettings: const DataLabelSettings(isVisible: true),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthlySalesTrendChart() {
    // 모든 고객의 월별 데이터를 합산
    final monthlyData = <String, double>{};
    for (var customer in _customerData) {
      for (var monthlyTrend in customer.monthlyTrend) {
        monthlyData[monthlyTrend.month] =
            (monthlyData[monthlyTrend.month] ?? 0) + monthlyTrend.sales;
      }
    }

    final trendData = monthlyData.entries
        .map((entry) => _TrendData(entry.key, entry.value))
        .toList()
      ..sort((a, b) => a.month.compareTo(b.month));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('월별 매출 추이', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            SizedBox(
              height: 300,
              child: SfCartesianChart(
                primaryXAxis: CategoryAxis(),
                primaryYAxis: NumericAxis(
                  numberFormat: NumberFormat.compact(),
                  title: AxisTitle(text: '매출액 (원)'),
                ),
                series: <CartesianSeries>[
                  AreaSeries<_TrendData, String>(
                    dataSource: trendData,
                    xValueMapper: (_TrendData data, _) => data.month,
                    yValueMapper: (_TrendData data, _) => data.sales,
                    color: Colors.blue.withOpacity(0.3),
                    borderColor: Colors.blue,
                    borderWidth: 2,
                    dataLabelSettings: const DataLabelSettings(isVisible: true),
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

class _PieChartData {
  final String category;
  final double value;

  _PieChartData(this.category, this.value);
}

class _TrendData {
  final String month;
  final double sales;

  _TrendData(this.month, this.sales);
}