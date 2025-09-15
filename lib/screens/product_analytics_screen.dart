import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:intl/intl.dart';
import '../models/analytics_data.dart';

class ProductAnalyticsScreen extends StatefulWidget {
  const ProductAnalyticsScreen({super.key});

  @override
  State<ProductAnalyticsScreen> createState() => _ProductAnalyticsScreenState();
}

class _ProductAnalyticsScreenState extends State<ProductAnalyticsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<ProductSalesData> _productData = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) {
      setState(() {
        _productData = AnalyticsMockData.getProductAnalyticsData();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('상품 중심 분석'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '상품 개요'),
            Tab(text: '고객 분포'),
            Tab(text: '판매 트렌드'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildProductOverviewTab(),
                _buildCustomerDistributionTab(),
                _buildSalesTrendTab(),
              ],
            ),
    );
  }

  Widget _buildProductOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSummaryCards(),
          const SizedBox(height: 24),
          _buildProductSalesRankingChart(),
          const SizedBox(height: 24),
          _buildCategoryDistributionChart(),
        ],
      ),
    );
  }

  Widget _buildCustomerDistributionTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('상품별 주요 고객', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          ..._productData.map((product) => _buildProductCustomerCard(product)),
        ],
      ),
    );
  }

  Widget _buildSalesTrendTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('판매 트렌드', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _buildQuantityVsSalesChart(),
        ],
      ),
    );
  }

  Widget _buildSummaryCards() {
    final totalSales = _productData.fold(0.0, (sum, product) => sum + product.totalSales);
    final totalQuantity = _productData.fold(0, (sum, product) => sum + product.quantity);
    final avgPrice = totalSales / totalQuantity;

    return Row(
      children: [
        Expanded(child: _buildSummaryCard('총 매출', '₩${NumberFormat('#,###').format(totalSales)}', Icons.monetization_on, Colors.blue)),
        const SizedBox(width: 16),
        Expanded(child: _buildSummaryCard('총 판매량', '${NumberFormat('#,###').format(totalQuantity)}개', Icons.inventory, Colors.green)),
        const SizedBox(width: 16),
        Expanded(child: _buildSummaryCard('평균 단가', '₩${NumberFormat('#,###').format(avgPrice)}', Icons.price_check, Colors.orange)),
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

  Widget _buildProductSalesRankingChart() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('상품별 매출 순위', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
                  ColumnSeries<ProductSalesData, String>(
                    dataSource: _productData,
                    xValueMapper: (ProductSalesData data, _) => data.productName,
                    yValueMapper: (ProductSalesData data, _) => data.totalSales,
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

  Widget _buildCategoryDistributionChart() {
    final categoryDistribution = <String, double>{};
    for (var product in _productData) {
      categoryDistribution[product.category] =
          (categoryDistribution[product.category] ?? 0) + product.totalSales;
    }

    final pieData = categoryDistribution.entries
        .map((entry) => _PieChartData(entry.key, entry.value))
        .toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('카테고리별 매출 분포', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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

  Widget _buildProductCustomerCard(ProductSalesData product) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(product.productName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text('카테고리: ${product.category}', style: const TextStyle(color: Colors.grey)),
                      Text('총 매출: ₩${NumberFormat('#,###').format(product.totalSales)}',
                           style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text('주요 고객', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...product.topCustomers.map((customer) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(child: Text(customer.customerName)),
                  Text('${customer.quantity}개'),
                  const SizedBox(width: 16),
                  Text('₩${NumberFormat('#,###').format(customer.salesAmount)}',
                       style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildQuantityVsSalesChart() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('판매량 vs 매출', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            SizedBox(
              height: 300,
              child: SfCartesianChart(
                primaryXAxis: NumericAxis(
                  title: AxisTitle(text: '판매량'),
                ),
                primaryYAxis: NumericAxis(
                  numberFormat: NumberFormat.compact(),
                  title: AxisTitle(text: '매출액 (원)'),
                ),
                series: <CartesianSeries>[
                  ScatterSeries<ProductSalesData, num>(
                    dataSource: _productData,
                    xValueMapper: (ProductSalesData data, _) => data.quantity,
                    yValueMapper: (ProductSalesData data, _) => data.totalSales,
                    color: Colors.purple,
                    markerSettings: const MarkerSettings(
                      isVisible: true,
                      height: 10,
                      width: 10,
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

class _PieChartData {
  final String category;
  final double value;

  _PieChartData(this.category, this.value);
}