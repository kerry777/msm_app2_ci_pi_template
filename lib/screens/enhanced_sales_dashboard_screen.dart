import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import '../services/api_service.dart';
import '../providers/auth_provider.dart';

class EnhancedSalesDashboardScreen extends StatefulWidget {
  const EnhancedSalesDashboardScreen({super.key});

  @override
  State<EnhancedSalesDashboardScreen> createState() => _EnhancedSalesDashboardScreenState();
}

class _EnhancedSalesDashboardScreenState extends State<EnhancedSalesDashboardScreen> {
  bool _isLoading = true;
  String _errorMessage = '';
  DateTime _fromDate = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _toDate = DateTime.now();

  // 대시보드 데이터
  List<SalesDataPoint> _monthlySalesData = [];
  List<SalesDataPoint> _dailySalesData = [];
  List<TopSellerData> _topSellersData = [];
  List<RegionSalesData> _regionSalesData = [];

  // 통계 요약 데이터
  double _totalSales = 0;
  double _totalTarget = 0;
  int _totalOrders = 0;
  double _averageOrderValue = 0;
  double _salesGrowth = 0;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final apiService = ApiService();

      // 영업 데이터 로드
      final salesResponse = await apiService.get('/api/sales/dashboard', params: {
        'fromDate': DateFormat('yyyy-MM-dd').format(_fromDate),
        'toDate': DateFormat('yyyy-MM-dd').format(_toDate),
      });

      if (salesResponse['success']) {
        final data = salesResponse['data'];

        // 월별 매출 데이터
        _monthlySalesData = (data['monthlySales'] as List)
            .map((item) => SalesDataPoint(
                  period: item['month'],
                  sales: (item['sales'] as num).toDouble(),
                  target: (item['target'] as num).toDouble(),
                ))
            .toList();

        // 일별 매출 데이터 (최근 30일)
        _dailySalesData = (data['dailySales'] as List)
            .map((item) => SalesDataPoint(
                  period: item['date'],
                  sales: (item['sales'] as num).toDouble(),
                  target: (item['target'] as num).toDouble(),
                ))
            .toList();

        // 톱 세일러 데이터
        _topSellersData = (data['topSellers'] as List)
            .map((item) => TopSellerData(
                  name: item['name'],
                  sales: (item['sales'] as num).toDouble(),
                  achievement: (item['achievement'] as num).toDouble(),
                ))
            .toList();

        // 지역별 매출 데이터
        _regionSalesData = (data['regionSales'] as List)
            .map((item) => RegionSalesData(
                  region: item['region'],
                  sales: (item['sales'] as num).toDouble(),
                  percentage: (item['percentage'] as num).toDouble(),
                ))
            .toList();

        // 통계 요약
        _totalSales = (data['summary']['totalSales'] as num).toDouble();
        _totalTarget = (data['summary']['totalTarget'] as num).toDouble();
        _totalOrders = data['summary']['totalOrders'] as int;
        _averageOrderValue = (data['summary']['averageOrderValue'] as num).toDouble();
        _salesGrowth = (data['summary']['salesGrowth'] as num).toDouble();
      } else {
        // 데모 데이터 사용 (API가 없을 경우)
        _generateDemoData();
      }
    } catch (e) {
      print('대시보드 데이터 로드 오류: $e');
      _generateDemoData();
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _generateDemoData() {
    // 데모 데이터 생성
    final random = DateTime.now().millisecondsSinceEpoch;

    _monthlySalesData = List.generate(12, (index) {
      final month = DateTime(DateTime.now().year, index + 1);
      return SalesDataPoint(
        period: DateFormat('MM월').format(month),
        sales: 50000000 + (random % 30000000),
        target: 60000000,
      );
    });

    _dailySalesData = List.generate(30, (index) {
      final date = DateTime.now().subtract(Duration(days: 29 - index));
      return SalesDataPoint(
        period: DateFormat('MM/dd').format(date),
        sales: 1500000 + (random % 1000000),
        target: 2000000,
      );
    });

    _topSellersData = [
      TopSellerData(name: '김영업', sales: 25000000, achievement: 125.5),
      TopSellerData(name: '박매니저', sales: 23000000, achievement: 115.2),
      TopSellerData(name: '이팀장', sales: 21000000, achievement: 105.8),
      TopSellerData(name: '최과장', sales: 19000000, achievement: 95.3),
      TopSellerData(name: '정대리', sales: 18000000, achievement: 90.1),
    ];

    _regionSalesData = [
      RegionSalesData(region: '서울', sales: 85000000, percentage: 35.4),
      RegionSalesData(region: '경기', sales: 62000000, percentage: 25.8),
      RegionSalesData(region: '부산', sales: 43000000, percentage: 17.9),
      RegionSalesData(region: '대구', sales: 28000000, percentage: 11.7),
      RegionSalesData(region: '기타', sales: 22000000, percentage: 9.2),
    ];

    _totalSales = 240000000;
    _totalTarget = 300000000;
    _totalOrders = 1250;
    _averageOrderValue = 192000;
    _salesGrowth = 15.8;
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
        title: const Row(
          children: [
            Icon(Icons.analytics, color: Colors.white),
            SizedBox(width: 8),
            Text('📊 강화된 영업 대시보드'),
          ],
        ),
        backgroundColor: const Color(0xFF667EEA),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range),
            onPressed: _showDateRangePicker,
            tooltip: '기간 선택',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _loadDashboardData(),
            tooltip: '새로고침',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadDashboardData,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 기간 표시
              _buildPeriodHeader(),
              const SizedBox(height: 16),

              // 통계 요약 카드들
              _buildSummaryCards(),
              const SizedBox(height: 24),

              // 차트 섹션
              _buildChartsSection(),
              const SizedBox(height: 24),

              // 데이터 테이블 섹션
              _buildDataTablesSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPeriodHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.calendar_today, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          Text(
            '분석 기간: ${DateFormat('yyyy.MM.dd').format(_fromDate)} ~ ${DateFormat('yyyy.MM.dd').format(_toDate)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '📈 성과 요약',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildSummaryCard(
                '총 매출',
                '₩${NumberFormat('#,###').format(_totalSales)}',
                '목표 달성률: ${(_totalSales / _totalTarget * 100).toStringAsFixed(1)}%',
                Icons.attach_money,
                Colors.green,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSummaryCard(
                '전년 대비',
                '${_salesGrowth >= 0 ? '+' : ''}${_salesGrowth.toStringAsFixed(1)}%',
                _salesGrowth >= 0 ? '성장' : '감소',
                _salesGrowth >= 0 ? Icons.trending_up : Icons.trending_down,
                _salesGrowth >= 0 ? Colors.blue : Colors.red,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildSummaryCard(
                '총 주문',
                NumberFormat('#,###').format(_totalOrders),
                '건수',
                Icons.shopping_cart,
                Colors.orange,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSummaryCard(
                '평균 주문액',
                '₩${NumberFormat('#,###').format(_averageOrderValue)}',
                '1건당',
                Icons.receipt,
                Colors.purple,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSummaryCard(String title, String value, String subtitle, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '📊 차트 분석',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),

        // 월별 매출 추이 차트
        _buildChartCard(
          '월별 매출 추이',
          _buildMonthlySalesChart(),
        ),
        const SizedBox(height: 16),

        Row(
          children: [
            Expanded(
              child: _buildChartCard(
                '지역별 매출 분포',
                _buildRegionPieChart(),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildChartCard(
                '최근 30일 매출',
                _buildDailySalesChart(),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildChartCard(String title, Widget chart) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: chart,
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlySalesChart() {
    return SfCartesianChart(
      primaryXAxis: CategoryAxis(
        labelStyle: const TextStyle(fontSize: 10),
      ),
      primaryYAxis: NumericAxis(
        numberFormat: NumberFormat.compact(),
        labelStyle: const TextStyle(fontSize: 10),
      ),
      legend: Legend(
        isVisible: true,
        position: LegendPosition.top,
        textStyle: const TextStyle(fontSize: 10),
      ),
      tooltipBehavior: TooltipBehavior(enable: true),
      series: <CartesianSeries<SalesDataPoint, String>>[
        ColumnSeries<SalesDataPoint, String>(
          dataSource: _monthlySalesData,
          xValueMapper: (SalesDataPoint sales, _) => sales.period,
          yValueMapper: (SalesDataPoint sales, _) => sales.sales,
          name: '실제 매출',
          color: const Color(0xFF667EEA),
        ),
        LineSeries<SalesDataPoint, String>(
          dataSource: _monthlySalesData,
          xValueMapper: (SalesDataPoint sales, _) => sales.period,
          yValueMapper: (SalesDataPoint sales, _) => sales.target,
          name: '목표',
          color: Colors.red,
          dashArray: <double>[5, 5],
        ),
      ],
    );
  }

  Widget _buildRegionPieChart() {
    return SfCircularChart(
      legend: Legend(
        isVisible: true,
        position: LegendPosition.right,
        textStyle: const TextStyle(fontSize: 10),
      ),
      tooltipBehavior: TooltipBehavior(enable: true),
      series: <PieSeries<RegionSalesData, String>>[
        PieSeries<RegionSalesData, String>(
          dataSource: _regionSalesData,
          xValueMapper: (RegionSalesData data, _) => data.region,
          yValueMapper: (RegionSalesData data, _) => data.sales,
          dataLabelMapper: (RegionSalesData data, _) => '${data.percentage.toStringAsFixed(1)}%',
          dataLabelSettings: const DataLabelSettings(
            isVisible: true,
            labelPosition: ChartDataLabelPosition.outside,
            textStyle: TextStyle(fontSize: 10),
          ),
          enableTooltip: true,
        ),
      ],
    );
  }

  Widget _buildDailySalesChart() {
    return SfCartesianChart(
      primaryXAxis: CategoryAxis(
        labelStyle: const TextStyle(fontSize: 8),
        interval: 7, // 7일 간격으로 표시
      ),
      primaryYAxis: NumericAxis(
        numberFormat: NumberFormat.compact(),
        labelStyle: const TextStyle(fontSize: 10),
      ),
      tooltipBehavior: TooltipBehavior(enable: true),
      series: <CartesianSeries<SalesDataPoint, String>>[
        SplineAreaSeries<SalesDataPoint, String>(
          dataSource: _dailySalesData,
          xValueMapper: (SalesDataPoint sales, _) => sales.period,
          yValueMapper: (SalesDataPoint sales, _) => sales.sales,
          name: '일별 매출',
          gradient: LinearGradient(
            colors: [
              const Color(0xFF667EEA).withOpacity(0.3),
              const Color(0xFF667EEA).withOpacity(0.1),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderColor: const Color(0xFF667EEA),
          borderWidth: 2,
        ),
      ],
    );
  }

  Widget _buildDataTablesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '🏆 톱 세일즈',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                spreadRadius: 1,
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            children: _topSellersData.asMap().entries.map((entry) {
              final index = entry.key;
              final seller = entry.value;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: index == 0 ? Colors.gold :
                               index == 1 ? Colors.grey[400] :
                               index == 2 ? Colors.brown[300] :
                               Colors.blue[100],
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Center(
                        child: Text(
                          '${index + 1}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            seller.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            '₩${NumberFormat('#,###').format(seller.sales)}',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: seller.achievement >= 100 ? Colors.green[100] : Colors.orange[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${seller.achievement.toStringAsFixed(1)}%',
                        style: TextStyle(
                          color: seller.achievement >= 100 ? Colors.green[700] : Colors.orange[700],
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  void _showDateRangePicker() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _fromDate, end: _toDate),
    );

    if (picked != null) {
      setState(() {
        _fromDate = picked.start;
        _toDate = picked.end;
      });
      _loadDashboardData();
    }
  }
}

// 데이터 모델들
class SalesDataPoint {
  final String period;
  final double sales;
  final double target;

  SalesDataPoint({required this.period, required this.sales, required this.target});
}

class TopSellerData {
  final String name;
  final double sales;
  final double achievement;

  TopSellerData({required this.name, required this.sales, required this.achievement});
}

class RegionSalesData {
  final String region;
  final double sales;
  final double percentage;

  RegionSalesData({required this.region, required this.sales, required this.percentage});
}