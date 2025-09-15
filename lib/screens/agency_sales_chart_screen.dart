import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import '../services/api_service.dart';
import '../providers/auth_provider.dart';
import '../l10n/app_localizations.dart';

class AgencySalesChartScreen extends StatefulWidget {
  const AgencySalesChartScreen({super.key});

  @override
  State<AgencySalesChartScreen> createState() => _AgencySalesChartScreenState();
}

class _AgencySalesChartScreenState extends State<AgencySalesChartScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<String> _tabTitles = [
    'comprehensive_chart',
    'agency_sales',
    'item_sales',
    'monthly_by_hospital',
    'monthly_by_item',
    'daily_by_hospital',
    'daily_by_item',
  ];

  bool _isLoading = true;
  String _errorMessage = '';
  List<Map<String, dynamic>> _salesData = [];
  DateTime _fromDate = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _toDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabTitles.length, vsync: this);
    _loadSalesData();
  }

  Future<void> _selectFromDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fromDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _fromDate) {
      setState(() {
        _fromDate = picked;
      });
    }
  }

  Future<void> _selectToDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _toDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _toDate) {
      setState(() {
        _toDate = picked;
      });
    }
  }

  Future<void> _loadSalesData() async {
    setState(() { _isLoading = true; _errorMessage = ''; });
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final trCd = auth.userInfo?['MEK_TR_CD']?.toString() ?? '';
      final salesData = await ApiService().getAgencySalesData(
        fromDate: _fromDate,
        toDate: _toDate,
        hospitalIds: [],
        warehouseIds: [],
        itemIds: [],
        agencyIds: [],
        trCd: trCd,
      );
      setState(() {
        _salesData = salesData;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = '매출 데이터 로드 실패: $e';
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).get('sales_analysis_chart'), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tabController,
          tabs: _tabTitles.map((t) => Tab(text: AppLocalizations.of(context).get(t))).toList(),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.calendar_today, size: 18),
                  label: Text('${AppLocalizations.of(context).get('start')}: ${DateFormat('yyyy-MM-dd').format(_fromDate)}'),
                  onPressed: () => _selectFromDate(context),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  icon: const Icon(Icons.calendar_today, size: 18),
                  label: Text('${AppLocalizations.of(context).get('end')}: ${DateFormat('yyyy-MM-dd').format(_toDate)}'),
                  onPressed: () => _selectToDate(context),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  icon: const Icon(Icons.search),
                  label: Text(AppLocalizations.of(context).get('search')),
                  onPressed: _loadSalesData,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage.isNotEmpty
                    ? Center(child: Text(_errorMessage, style: const TextStyle(color: Colors.red)))
                    : TabBarView(
                        controller: _tabController,
                        children: [
                          _buildComprehensiveChartTab(),
                          _buildAgencySalesChart(),
                          _buildItemSalesChart(),
                          _buildMonthlyHospitalTrendChart(),
                          _buildMonthlyItemTrendChart(),
                          _buildDailyHospitalTrendChart(),
                          _buildDailyItemTrendChart(),
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildAgencySalesChart() {
    // 병원명별 IO_QT 합계로 막대차트
    final Map<String, num> hospitalMap = {};
    for (final row in _salesData) {
      final name = row['HOSPITAL_NAME'] ?? row['병원명'] ?? '';
      final qty = row['IO_QT'] ?? row['수량'] ?? 0;
      if (name != '') {
        hospitalMap[name] = (hospitalMap[name] ?? 0) + (qty is num ? qty : num.tryParse(qty.toString()) ?? 0);
      }
    }
    final data = hospitalMap.entries.map((e) => _BarData(e.key, e.value, '')).toList();
    return SfCartesianChart(
      primaryXAxis: CategoryAxis(),
      title: ChartTitle(text: AppLocalizations.of(context).get('agency_sales_qty_sum')),
      series: <ColumnSeries<_BarData, String>>[
        ColumnSeries<_BarData, String>(
          dataSource: data,
          xValueMapper: (_BarData d, _) => d.label,
          yValueMapper: (_BarData d, _) => d.value,
          dataLabelSettings: DataLabelSettings(isVisible: true),
        ),
      ],
    );
  }

  Widget _buildItemSalesChart() {
    // 품목명별 IO_QT 합계로 파이차트
    final Map<String, _PieData> itemMap = {};
    for (final row in _salesData) {
      final name = row['ITEM_NAME'] ?? row['품목명'] ?? '';
      final code = row['ITEM_CD'] ?? row['품목코드'] ?? '';
      final qty = row['IO_QT'] ?? row['수량'] ?? 0;
      if (name != '') {
        // (2N-P)Micro-Premature Nioflo → 2N-P 추출
        final reg = RegExp(r'^\(([^)]+)\)');
        final match = reg.firstMatch(name);
        final shortCode = match != null ? match.group(1) ?? '' : '';
        final legendLabel = '($shortCode) $name ($code)';
        if (itemMap.containsKey(legendLabel)) {
          itemMap[legendLabel] = _PieData(
            legendLabel,
            shortCode,
            itemMap[legendLabel]!.value + (qty is num ? qty : num.tryParse(qty.toString()) ?? 0),
          );
        } else {
          itemMap[legendLabel] = _PieData(
            legendLabel,
            shortCode,
            (qty is num ? qty : num.tryParse(qty.toString()) ?? 0),
          );
        }
      }
    }
    final data = itemMap.values.toList();
    final formatter = NumberFormat('#,###');
    return SfCircularChart(
      title: ChartTitle(text: AppLocalizations.of(context).get('item_sales_qty_sum')),
      legend: Legend(isVisible: true, overflowMode: LegendItemOverflowMode.wrap),
      series: <PieSeries<_PieData, String>>[
        PieSeries<_PieData, String>(
          dataSource: data,
          xValueMapper: (_PieData d, _) => d.legendLabel,
          yValueMapper: (_PieData d, _) => d.value,
          dataLabelSettings: DataLabelSettings(
            isVisible: true,
            labelPosition: ChartDataLabelPosition.inside,
          ),
          dataLabelMapper: (_PieData d, _) => '${d.shortCode}\n${formatter.format(d.value)}',
        ),
      ],
    );
  }

  Widget _buildMonthlyHospitalTrendChart() {
    final Map<String, Map<String, num>> monthHospitalMap = {};
    for (final row in _salesData) {
      final date = row['CHECK_DT'] ?? row['매출일'] ?? '';
      final hospital = row['HOSPITAL_NAME'] ?? row['병원명'] ?? '';
      final qty = row['IO_QT'] ?? row['수량'] ?? 0;
      String ym = '';
      if (date is String && date.length >= 7) {
        ym = date.substring(0, 7); // yyyy-MM
      } else if (date is DateTime) {
        ym = DateFormat('yyyy-MM').format(date);
      }
      if (ym != '' && hospital != '') {
        monthHospitalMap.putIfAbsent(hospital, () => {});
        monthHospitalMap[hospital]![ym] = (monthHospitalMap[hospital]?[ym] ?? 0) + (qty is num ? qty : num.tryParse(qty.toString()) ?? 0);
      }
    }
    final months = <String>{};
    for (var m in monthHospitalMap.values) {
      months.addAll(m.keys);
    }
    final sortedMonths = months.toList()..sort();
    if (monthHospitalMap.isEmpty) {
      return Center(child: Text(AppLocalizations.of(context).get('monthly_agency_sales_no_data')));
    }
    // BarSeries로 각 병원별 월별 IO_QT 표시
    return SfCartesianChart(
      primaryXAxis: CategoryAxis(),
      title: ChartTitle(text: AppLocalizations.of(context).get('monthly_agency_sales_qty_sum')),
      legend: Legend(isVisible: true, overflowMode: LegendItemOverflowMode.wrap),
      series: monthHospitalMap.entries.map((e) {
        final hospital = e.key;
        final data = sortedMonths.map((m) => _BarData(m, e.value[m] ?? 0, hospital)).toList();
        return BarSeries<_BarData, String>(
          name: hospital,
          dataSource: data,
          xValueMapper: (_BarData d, _) => d.label,
          yValueMapper: (_BarData d, _) => d.value,
          dataLabelSettings: DataLabelSettings(isVisible: true),
        );
      }).toList(),
    );
  }

  Widget _buildMonthlyItemTrendChart() {
    final Map<String, Map<String, num>> monthItemMap = {};
    for (final row in _salesData) {
      final date = row['CHECK_DT'] ?? row['매출일'] ?? '';
      final item = row['ITEM_NAME'] ?? row['품목명'] ?? '';
      final code = row['ITEM_CD'] ?? row['품목코드'] ?? '';
      final qty = row['IO_QT'] ?? row['수량'] ?? 0;
      String ym = '';
      if (date is String && date.length >= 7) {
        ym = date.substring(0, 7); // yyyy-MM
      } else if (date is DateTime) {
        ym = DateFormat('yyyy-MM').format(date);
      }
      // (2N-P)Micro-Premature Nioflo → 2N-P 추출
      final reg = RegExp(r'^\(([^)]+)\)');
      final match = reg.firstMatch(item);
      final shortCode = match != null ? match.group(1) ?? '' : '';
      final legendLabel = shortCode.isNotEmpty ? shortCode : item;
      if (ym != '' && legendLabel != '') {
        monthItemMap.putIfAbsent(legendLabel, () => {});
        monthItemMap[legendLabel]![ym] = (monthItemMap[legendLabel]![ym] ?? 0) + (qty is num ? qty : num.tryParse(qty.toString()) ?? 0);
      }
    }
    final months = <String>{};
    for (var m in monthItemMap.values) {
      months.addAll(m.keys);
    }
    final sortedMonths = months.toList()..sort();
    if (monthItemMap.isEmpty) {
      return Center(child: Text(AppLocalizations.of(context).get('monthly_item_sales_no_data')));
    }
    // 각 월별로 품목별 수량을 내림차순 정렬
    final List<_BarData> barData = [];
    for (final m in sortedMonths) {
      final monthList = monthItemMap.entries.map((e) => _BarData(e.key, e.value[m] ?? 0, m)).toList();
      monthList.sort((a, b) => b.value.compareTo(a.value));
      barData.addAll(monthList);
    }
    return SfCartesianChart(
      primaryXAxis: CategoryAxis(),
      title: ChartTitle(text: AppLocalizations.of(context).get('monthly_item_sales_qty_sum')),
      legend: Legend(isVisible: true, overflowMode: LegendItemOverflowMode.wrap),
      series: <BarSeries<_BarData, String>>[
        BarSeries<_BarData, String>(
          dataSource: barData,
          xValueMapper: (_BarData d, _) => '${d.month}\n${d.label}',
          yValueMapper: (_BarData d, _) => d.value,
          dataLabelSettings: DataLabelSettings(isVisible: true),
        ),
      ],
    );
  }

  Widget _buildDailyHospitalTrendChart() {
    final Map<String, Map<String, num>> dayHospitalMap = {};
    for (final row in _salesData) {
      final date = row['CHECK_DT'] ?? row['매출일'] ?? '';
      final hospital = row['HOSPITAL_NAME'] ?? row['병원명'] ?? '';
      final qty = row['IO_QT'] ?? row['수량'] ?? 0;
      String ymd = '';
      if (date is String && date.length >= 10) {
        ymd = date.substring(0, 10); // yyyy-MM-dd
      } else if (date is DateTime) {
        ymd = DateFormat('yyyy-MM-dd').format(date);
      }
      if (ymd != '' && hospital != '') {
        dayHospitalMap.putIfAbsent(hospital, () => {});
        dayHospitalMap[hospital]![ymd] = (dayHospitalMap[hospital]![ymd] ?? 0) + (qty is num ? qty : num.tryParse(qty.toString()) ?? 0);
      }
    }
    final days = <String>{};
    for (var m in dayHospitalMap.values) {
      days.addAll(m.keys);
    }
    final sortedDays = days.toList()..sort();
    if (dayHospitalMap.isEmpty) {
      return Center(child: Text(AppLocalizations.of(context).get('daily_agency_sales_no_data')));
    }
    return SfCartesianChart(
      primaryXAxis: CategoryAxis(),
      title: ChartTitle(text: AppLocalizations.of(context).get('daily_agency_sales_qty_sum')),
      legend: Legend(isVisible: true, overflowMode: LegendItemOverflowMode.wrap),
      series: dayHospitalMap.entries.map((e) {
        return LineSeries<_LineData, String>(
          name: e.key,
          dataSource: sortedDays.map((d) => _LineData(d, e.value[d] ?? 0)).toList(),
          xValueMapper: (_LineData d, _) => d.label,
          yValueMapper: (_LineData d, _) => d.value,
          dataLabelSettings: DataLabelSettings(isVisible: false),
        );
      }).toList(),
    );
  }

  Widget _buildDailyItemTrendChart() {
    final Map<String, Map<String, num>> dayItemMap = {};
    for (final row in _salesData) {
      final date = row['CHECK_DT'] ?? row['매출일'] ?? '';
      final item = row['ITEM_NAME'] ?? row['품목명'] ?? '';
      final code = row['ITEM_CD'] ?? row['품목코드'] ?? '';
      final qty = row['IO_QT'] ?? row['수량'] ?? 0;
      String ymd = '';
      if (date is String && date.length >= 10) {
        ymd = date.substring(0, 10); // yyyy-MM-dd
      } else if (date is DateTime) {
        ymd = DateFormat('yyyy-MM-dd').format(date);
      }
      // (2N-P)Micro-Premature Nioflo → 2N-P 추출
      final reg = RegExp(r'^\(([^)]+)\)');
      final match = reg.firstMatch(item);
      final shortCode = match != null ? match.group(1) ?? '' : '';
      final legendLabel = shortCode.isNotEmpty ? shortCode : item;
      if (ymd != '' && legendLabel != '') {
        dayItemMap.putIfAbsent(legendLabel, () => {});
        dayItemMap[legendLabel]![ymd] = (dayItemMap[legendLabel]![ymd] ?? 0) + (qty is num ? qty : num.tryParse(qty.toString()) ?? 0);
      }
    }
    final days = <String>{};
    for (var m in dayItemMap.values) {
      days.addAll(m.keys);
    }
    final sortedDays = days.toList()..sort();
    if (dayItemMap.isEmpty) {
      return Center(child: Text(AppLocalizations.of(context).get('daily_item_sales_no_data')));
    }
    return SfCartesianChart(
      primaryXAxis: CategoryAxis(),
      title: ChartTitle(text: AppLocalizations.of(context).get('daily_item_sales_qty_sum')),
      legend: Legend(isVisible: true, overflowMode: LegendItemOverflowMode.wrap),
      series: dayItemMap.entries.map((e) {
        return LineSeries<_LineData, String>(
          name: e.key,
          dataSource: sortedDays.map((d) => _LineData(d, e.value[d] ?? 0)).toList(),
          xValueMapper: (_LineData d, _) => d.label,
          yValueMapper: (_LineData d, _) => d.value,
          dataLabelSettings: DataLabelSettings(isVisible: false),
        );
      }).toList(),
    );
  }

  Widget _buildComprehensiveChartTab() {
    // 매출 통계 요약 카드
    final statCards = Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _buildStatCard(AppLocalizations.of(context).get('total_sales_amount'), '₩${NumberFormat('#,###').format(_salesData.fold<int>(0, (sum, e) => sum + ((e['IO_AMT'] ?? 0) as int)))}', Colors.blue),
        _buildStatCard(AppLocalizations.of(context).get('total_quantity'), '${NumberFormat('#,###').format(_salesData.fold<int>(0, (sum, e) => sum + ((e['IO_QT'] ?? 0) as int)))}${AppLocalizations.of(context).get('unit_ea')}', Colors.green),
        _buildStatCard(AppLocalizations.of(context).get('average_sales'), _salesData.isNotEmpty ? '₩${NumberFormat('#,###').format((_salesData.fold<int>(0, (sum, e) => sum + ((e['IO_AMT'] ?? 0) as int)) ~/ _salesData.length))}' : '₩0', Colors.orange),
        _buildStatCard(AppLocalizations.of(context).get('transaction_count'), '${_salesData.length}${AppLocalizations.of(context).get('unit_cnt')}', Colors.purple),
      ],
    );
    // 트렌드 차트 및 인사이트
    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: 16),
          statCards,
          const SizedBox(height: 24),
          ExpansionTile(
            title: Text(AppLocalizations.of(context).get('sales_trend_analysis'), style: Theme.of(context).textTheme.titleMedium),
            initiallyExpanded: false,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTrendChart(),
                    const SizedBox(height: 16),
                    Text(AppLocalizations.of(context).get('key_insights'), style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 8),
                    ..._buildInsights(),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, Color color) {
    return Card(
      color: color.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 8),
            Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _buildTrendChart() {
    // TODO: 실제 트렌드 차트 구현 필요 (예시)
    return Container(
      height: 200,
      color: Colors.grey.shade200,
      alignment: Alignment.center,
      child: Text(AppLocalizations.of(context).get('trend_chart_area')),
    );
  }

  List<Widget> _buildInsights() {
    // TODO: 실제 인사이트 데이터 구현 필요 (예시)
    return [
      Text(AppLocalizations.of(context).get('example_insight_1')),
      Text(AppLocalizations.of(context).get('example_insight_2')),
    ];
  }
}

class _BarData {
  final String label;
  final num value;
  final String month;
  _BarData(this.label, this.value, this.month);
}

class _PieData {
  final String legendLabel;
  final String shortCode;
  final num value;
  _PieData(this.legendLabel, this.shortCode, this.value);
}

class _LineData {
  final String label;
  final num value;
  _LineData(this.label, this.value);
} 