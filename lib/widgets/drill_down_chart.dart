import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:intl/intl.dart';
import '../models/analytics_data.dart';
import '../providers/drill_down_provider.dart';

class DrillDownChart extends StatefulWidget {
  const DrillDownChart({super.key});

  @override
  State<DrillDownChart> createState() => _DrillDownChartState();
}

class _DrillDownChartState extends State<DrillDownChart> {
  late TooltipBehavior _tooltipBehavior;

  @override
  void initState() {
    super.initState();
    _tooltipBehavior = TooltipBehavior(enable: true);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DrillDownProvider>(
      builder: (context, drillDownProvider, child) {
        return Column(
          children: [
            // 브레드크럼 네비게이션
            _buildBreadcrumbNavigation(drillDownProvider),

            const SizedBox(height: 16),

            // 차트 영역
            Expanded(
              child: _buildChart(drillDownProvider),
            ),

            const SizedBox(height: 16),

            // 컨트롤 버튼들
            _buildControlButtons(drillDownProvider),
          ],
        );
      },
    );
  }

  Widget _buildBreadcrumbNavigation(DrillDownProvider provider) {
    final breadcrumbs = provider.currentState.breadcrumbPath;

    return Card(
      margin: const EdgeInsets.all(8.0),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Row(
          children: [
            const Icon(Icons.location_on, size: 20, color: Colors.blue),
            const SizedBox(width: 8),
            Expanded(
              child: Wrap(
                children: breadcrumbs.asMap().entries.map((entry) {
                  final index = entry.key;
                  final breadcrumb = entry.value;
                  final isLast = index == breadcrumbs.length - 1;

                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        onTap: () {
                          if (!isLast && !provider.isLoading) {
                            provider.navigateToLevel(index);
                          }
                        },
                        child: Text(
                          breadcrumb,
                          style: TextStyle(
                            color: isLast ? Colors.black87 : Colors.blue,
                            fontWeight: isLast ? FontWeight.bold : FontWeight.normal,
                            decoration: isLast ? null : TextDecoration.underline,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      if (!isLast) ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.arrow_forward_ios, size: 12, color: Colors.grey),
                        const SizedBox(width: 4),
                      ],
                    ],
                  );
                }).toList(),
              ),
            ),
            // 상위 레벨로 버튼
            if (breadcrumbs.length > 1)
              IconButton(
                icon: const Icon(Icons.arrow_back, size: 20),
                onPressed: provider.isLoading ? null : () => provider.drillUp(),
                tooltip: '상위 레벨로',
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildChart(DrillDownProvider provider) {
    if (provider.isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('데이터를 불러오는 중...', style: TextStyle(fontSize: 16)),
          ],
        ),
      );
    }

    if (provider.errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              provider.errorMessage!,
              style: const TextStyle(fontSize: 16, color: Colors.red),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => provider.refresh(),
              child: const Text('다시 시도'),
            ),
          ],
        ),
      );
    }

    final data = provider.currentState.currentData;
    if (data.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.bar_chart, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              '${_getLevelKoreanName(provider.currentState.currentLevel)} 데이터가 없습니다.',
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.all(8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 차트 제목
            Text(
              '${_getLevelKoreanName(provider.currentState.currentLevel)}별 매출 현황',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            // 차트
            Expanded(
              child: SfCartesianChart(
                tooltipBehavior: _tooltipBehavior,
                primaryXAxis: CategoryAxis(
                  labelRotation: data.length > 5 ? -45 : 0,
                  labelIntersectAction: AxisLabelIntersectAction.multipleRows,
                ),
                primaryYAxis: NumericAxis(
                  numberFormat: NumberFormat('#,##0'),
                  title: AxisTitle(text: '매출액 (원)'),
                ),
                series: <CartesianSeries<DrillDownData, String>>[
                  ColumnSeries<DrillDownData, String>(
                    dataSource: data,
                    xValueMapper: (DrillDownData item, _) => item.name,
                    yValueMapper: (DrillDownData item, _) => item.value,
                    name: '매출액',
                    color: _getColorForLevel(provider.currentState.currentLevel),
                    dataLabelSettings: const DataLabelSettings(
                      isVisible: true,
                      textStyle: TextStyle(fontSize: 10),
                      labelAlignment: ChartDataLabelAlignment.top,
                    ),
                    onPointTap: (ChartPointDetails details) {
                      if (!provider.isLoading) {
                        _handleChartTap(provider, details);
                      }
                    },
                  ),
                ],
                onTooltipRender: (TooltipArgs args) {
                  if (args.pointIndex != null && args.pointIndex! < data.length) {
                    final item = data[args.pointIndex! as int];
                    args.text = '${item.name}\n매출액: ${NumberFormat('#,##0').format(item.value)}원';
                  }
                },
              ),
            ),

            // 범례 및 안내
            const SizedBox(height: 8),
            _buildLegendAndGuide(provider),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendAndGuide(DrillDownProvider provider) {
    final level = provider.currentState.currentLevel;
    String guideText = '';

    switch (level) {
      case DrillDownLevel.region:
        guideText = '지역을 클릭하면 해당 지역의 병원별 매출을 확인할 수 있습니다.';
        break;
      case DrillDownLevel.hospital:
        guideText = '병원을 클릭하면 해당 병원의 상품별 매출을 확인할 수 있습니다.';
        break;
      case DrillDownLevel.product:
        guideText = '상품별 매출 상세 정보입니다.';
        break;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 16, color: Colors.blue.shade700),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              guideText,
              style: TextStyle(
                fontSize: 12,
                color: Colors.blue.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlButtons(DrillDownProvider provider) {
    return Card(
      margin: const EdgeInsets.all(8.0),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // 새로고침 버튼
            ElevatedButton.icon(
              onPressed: provider.isLoading ? null : () => provider.refresh(),
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('새로고침'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),

            // 최상위로 버튼
            ElevatedButton.icon(
              onPressed: provider.isLoading ||
                       provider.currentState.currentLevel == DrillDownLevel.region
                ? null
                : () => provider.resetToTop(),
              icon: const Icon(Icons.home, size: 18),
              label: const Text('전체보기'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),

            // 상위 레벨로 버튼
            ElevatedButton.icon(
              onPressed: provider.isLoading ||
                       provider.currentState.breadcrumbPath.length <= 1
                ? null
                : () => provider.drillUp(),
              icon: const Icon(Icons.arrow_upward, size: 18),
              label: const Text('상위 레벨'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleChartTap(DrillDownProvider provider, ChartPointDetails details) {
    if (details.pointIndex != null) {
      final data = provider.currentState.currentData;
      if (details.pointIndex! < data.length) {
        final selectedItem = data[details.pointIndex!];

        // 상품 레벨에서는 더 이상 드릴다운 불가
        if (provider.currentState.currentLevel == DrillDownLevel.product) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('상품 레벨에서는 더 이상 상세 정보를 볼 수 없습니다.'),
              duration: Duration(seconds: 2),
            ),
          );
          return;
        }

        // 드릴다운 실행
        provider.drillDown(selectedItem.id);

        // 피드백 제공
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${selectedItem.name}의 상세 정보를 불러오는 중...'),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    }
  }

  String _getLevelKoreanName(DrillDownLevel level) {
    switch (level) {
      case DrillDownLevel.region:
        return '지역';
      case DrillDownLevel.hospital:
        return '병원';
      case DrillDownLevel.product:
        return '상품';
    }
  }

  Color _getColorForLevel(DrillDownLevel level) {
    switch (level) {
      case DrillDownLevel.region:
        return Colors.blue;
      case DrillDownLevel.hospital:
        return Colors.green;
      case DrillDownLevel.product:
        return Colors.orange;
    }
  }
}