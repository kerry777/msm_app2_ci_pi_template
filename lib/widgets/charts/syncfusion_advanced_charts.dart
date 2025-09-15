import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';
import 'package:syncfusion_flutter_treemap/treemap.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;

/// Syncfusion 모든 고급 차트 기능을 완전히 활용하는 위젯 모음
/// Excel, Power BI 수준의 모든 차트 타입 지원
class SyncfusionAdvancedCharts {

  /// 1. 퍼널 차트 (Funnel Chart) - 판매 프로세스 분석용
  static Widget buildFunnelChart({
    required List<FunnelData> data,
    String title = '판매 프로세스 분석',
    bool enableAnimation = true,
    bool showDataLabels = true,
    bool enableLegend = true,
    VoidCallback? onSelectionChanged,
  }) {
    return SfFunnelChart(
      title: ChartTitle(text: title),
      legend: Legend(isVisible: enableLegend, position: LegendPosition.right),
      tooltipBehavior: TooltipBehavior(enable: true),
      series: FunnelSeries<FunnelData, String>(
        dataSource: data,
        xValueMapper: (FunnelData data, _) => data.stage,
        yValueMapper: (FunnelData data, _) => data.value,
        dataLabelSettings: DataLabelSettings(isVisible: showDataLabels),
        animationDuration: enableAnimation ? 1000 : 0,
        explode: true,
        explodeAll: true,
        explodeOffset: '10%',
        gap: 0.1,
        onPointTap: onSelectionChanged != null ? (ChartPointDetails details) => onSelectionChanged() : null,
      ),
    );
  }

  /// 2. 피라미드 차트 (Pyramid Chart) - 계층 구조 분석용
  static Widget buildPyramidChart({
    required List<PyramidData> data,
    String title = '시장 계층 구조',
    bool enableAnimation = true,
    bool showDataLabels = true,
    PyramidMode mode = PyramidMode.linear,
    VoidCallback? onSelectionChanged,
  }) {
    return SfPyramidChart(
      title: ChartTitle(text: title),
      legend: Legend(isVisible: true, position: LegendPosition.bottom),
      tooltipBehavior: TooltipBehavior(enable: true),
      series: PyramidSeries<PyramidData, String>(
        dataSource: data,
        xValueMapper: (PyramidData data, _) => data.category,
        yValueMapper: (PyramidData data, _) => data.value,
        dataLabelSettings: DataLabelSettings(isVisible: showDataLabels),
        animationDuration: enableAnimation ? 1200 : 0,
        explode: true,
        explodeIndex: 0,
        explodeOffset: '15%',
        pyramidMode: mode,
        gap: 0.05,
        onPointTap: onSelectionChanged != null ? (ChartPointDetails details) => onSelectionChanged() : null,
      ),
    );
  }

  /// 3. 게이지 차트 (Gauge Chart) - KPI 및 성과 측정용
  static Widget buildRadialGauge({
    required double value,
    required double maximum,
    String title = 'KPI 성과',
    String unit = '%',
    List<GaugeRange>? ranges,
    bool showNeedle = true,
    bool enableAnimation = true,
  }) {
    ranges ??= [
      GaugeRange(startValue: 0, endValue: maximum * 0.3, color: Colors.red),
      GaugeRange(startValue: maximum * 0.3, endValue: maximum * 0.7, color: Colors.orange),
      GaugeRange(startValue: maximum * 0.7, endValue: maximum, color: Colors.green),
    ];

    return SfRadialGauge(
      title: GaugeTitle(text: title),
      enableLoadingAnimation: enableAnimation,
      animationDuration: 1500,
      axes: <RadialAxis>[
        RadialAxis(
          minimum: 0,
          maximum: maximum,
          ranges: ranges,
          pointers: showNeedle ? <GaugePointer>[
            NeedlePointer(
              value: value,
              enableAnimation: enableAnimation,
              animationDuration: 1200,
              needleStartWidth: 1,
              needleEndWidth: 5,
              needleColor: Colors.blue,
              knobStyle: const KnobStyle(
                knobRadius: 0.08,
                color: Colors.white,
                borderColor: Colors.blue,
                borderWidth: 0.02,
              ),
            ),
          ] : [],
          annotations: <GaugeAnnotation>[
            GaugeAnnotation(
              widget: Text(
                '${value.toStringAsFixed(1)}$unit',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              positionFactor: 0.5,
              angle: 90,
            ),
          ],
        ),
      ],
    );
  }

  /// 4. 트리맵 차트 (TreeMap) - 계층적 데이터 시각화
  static Widget buildTreeMap({
    required List<TreeMapData> data,
    String title = '계층적 데이터 분석',
    bool enableTooltip = true,
    bool enableLegend = true,
    TreeMapLayoutType layoutType = TreeMapLayoutType.squarified,
  }) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(
          child: SfTreemap(
            dataCount: data.length,
            weightValueMapper: (int index) => data[index].value,
            colorValueMapper: (int index) => data[index].value,
            layoutType: layoutType,
            tooltipSettings: TreemapTooltipSettings(
              enable: enableTooltip,
            ),
            legend: TreemapLegend.bar(
              TreemapColorMapper.range,
              showPointerOnHover: true,
            ),
            levels: [
              TreemapLevel(
                color: Colors.blue[100],
                labelBuilder: (BuildContext context, TreemapTile tile) {
                  return Text(
                    data[tile.indices[0]].label,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  );
                },
                tooltipBuilder: (BuildContext context, TreemapTile tile) {
                  return Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      '${data[tile.indices[0]].label}: ${NumberFormat('#,###').format(data[tile.indices[0]].value)}',
                      style: const TextStyle(color: Colors.white),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 5. 히트맵 차트 (Heatmap) - 매트릭스 데이터 시각화
  static Widget buildHeatmapChart({
    required List<HeatmapData> data,
    String title = '데이터 히트맵',
    bool enableTooltip = true,
    bool showColorBar = true,
  }) {
    // 데이터를 매트릭스 형태로 변환
    final Set<String> xCategories = data.map((d) => d.xCategory).toSet();
    final Set<String> yCategories = data.map((d) => d.yCategory).toSet();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(
          child: SfCartesianChart(
            primaryXAxis: CategoryAxis(
              title: AxisTitle(text: 'X 축'),
            ),
            primaryYAxis: CategoryAxis(
              title: AxisTitle(text: 'Y 축'),
            ),
            tooltipBehavior: TooltipBehavior(enable: enableTooltip),
            series: <HeatmapSeries<HeatmapData, String>>[
              HeatmapSeries<HeatmapData, String>(
                dataSource: data,
                xValueMapper: (HeatmapData data, _) => data.xCategory,
                yValueMapper: (HeatmapData data, _) => data.yCategory,
                colorValueMapper: (HeatmapData data, _) => data.value,
                colorMap: const <TreemapColorMapper>[
                  TreemapColorMapper.range(0, 100, Colors.blue),
                  TreemapColorMapper.range(100, 200, Colors.green),
                  TreemapColorMapper.range(200, 300, Colors.orange),
                  TreemapColorMapper.range(300, 400, Colors.red),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 6. 폴라 차트 (Polar Chart) - 방향성 데이터 시각화
  static Widget buildPolarChart({
    required List<PolarData> data,
    String title = '방향성 데이터 분석',
    PolarChartType chartType = PolarChartType.line,
    bool enableAnimation = true,
    bool showDataLabels = false,
  }) {
    return SfCircularChart(
      title: ChartTitle(text: title),
      legend: Legend(isVisible: true, position: LegendPosition.bottom),
      tooltipBehavior: TooltipBehavior(enable: true),
      series: _buildPolarSeries(data, chartType, enableAnimation, showDataLabels),
    );
  }

  static List<CircularSeries> _buildPolarSeries(
    List<PolarData> data,
    PolarChartType chartType,
    bool enableAnimation,
    bool showDataLabels,
  ) {
    switch (chartType) {
      case PolarChartType.area:
        return <RadialBarSeries<PolarData, String>>[
          RadialBarSeries<PolarData, String>(
            dataSource: data,
            xValueMapper: (PolarData data, _) => data.category,
            yValueMapper: (PolarData data, _) => data.value,
            dataLabelSettings: DataLabelSettings(isVisible: showDataLabels),
            animationDuration: enableAnimation ? 1000 : 0,
            maximumValue: data.isNotEmpty ? data.map((d) => d.value).reduce(math.max) : 100,
          ),
        ];
      case PolarChartType.line:
      default:
        return <PieSeries<PolarData, String>>[
          PieSeries<PolarData, String>(
            dataSource: data,
            xValueMapper: (PolarData data, _) => data.category,
            yValueMapper: (PolarData data, _) => data.value,
            dataLabelSettings: DataLabelSettings(isVisible: showDataLabels),
            animationDuration: enableAnimation ? 1000 : 0,
            radius: '80%',
            innerRadius: '40%', // 도넛 차트로 만들어 polar 느낌 연출
          ),
        ];
    }
  }

  /// 7. 워터폴 차트 (Waterfall Chart) - 증감 분석용
  static Widget buildWaterfallChart({
    required List<WaterfallData> data,
    String title = '수익 증감 분석',
    bool enableAnimation = true,
    bool showDataLabels = true,
  }) {
    return SfCartesianChart(
      title: ChartTitle(text: title),
      primaryXAxis: CategoryAxis(),
      primaryYAxis: NumericAxis(numberFormat: NumberFormat.compact()),
      tooltipBehavior: TooltipBehavior(enable: true),
      series: <WaterfallSeries<WaterfallData, String>>[
        WaterfallSeries<WaterfallData, String>(
          dataSource: data,
          xValueMapper: (WaterfallData data, _) => data.category,
          yValueMapper: (WaterfallData data, _) => data.value,
          intermediateSumPredicate: (WaterfallData data, _) => data.isIntermediate,
          totalSumPredicate: (WaterfallData data, _) => data.isTotal,
          dataLabelSettings: DataLabelSettings(isVisible: showDataLabels),
          animationDuration: enableAnimation ? 1200 : 0,
          connectorLineSettings: const WaterfallConnectorLineSettings(
            width: 2,
            color: Colors.grey,
            dashArray: <double>[2, 3],
          ),
        ),
      ],
    );
  }

  /// 8. 박스 플롯 차트 (Box Plot) - 통계적 분석용
  static Widget buildBoxPlotChart({
    required List<BoxPlotData> data,
    String title = '통계 분포 분석',
    bool enableAnimation = true,
    bool showMean = true,
    bool showOutliers = true,
  }) {
    return SfCartesianChart(
      title: ChartTitle(text: title),
      primaryXAxis: CategoryAxis(),
      primaryYAxis: NumericAxis(),
      tooltipBehavior: TooltipBehavior(enable: true),
      series: <BoxAndWhiskerSeries<BoxPlotData, String>>[
        BoxAndWhiskerSeries<BoxPlotData, String>(
          dataSource: data,
          xValueMapper: (BoxPlotData data, _) => data.category,
          yValueMapper: (BoxPlotData data, _) => data.values,
          animationDuration: enableAnimation ? 1000 : 0,
          showMean: showMean,
          showOutliers: showOutliers,
          boxPlotMode: BoxPlotMode.normal,
        ),
      ],
    );
  }

  /// 9. 히스토그램 차트 (Histogram) - 분포 분석용
  static Widget buildHistogramChart({
    required List<double> rawData,
    String title = '데이터 분포 분석',
    int binInterval = 10,
    bool enableAnimation = true,
    bool showNormalDistribution = true,
  }) {
    return SfCartesianChart(
      title: ChartTitle(text: title),
      primaryXAxis: NumericAxis(),
      primaryYAxis: NumericAxis(),
      tooltipBehavior: TooltipBehavior(enable: true),
      series: <HistogramSeries<double, double>>[
        HistogramSeries<double, double>(
          dataSource: rawData,
          yValueMapper: (double data, _) => data,
          animationDuration: enableAnimation ? 1000 : 0,
          binInterval: binInterval,
          showNormalDistributionCurve: showNormalDistribution,
          curveColor: Colors.red,
          curveWidth: 2,
          curveDashArray: const <double>[3, 3],
        ),
      ],
    );
  }

  /// 10. 에러 바 차트 (Error Bar Chart) - 불확실성 표시용
  static Widget buildErrorBarChart({
    required List<ErrorBarData> data,
    String title = '데이터 신뢰구간',
    ErrorBarType errorBarType = ErrorBarType.fixed,
    bool enableAnimation = true,
  }) {
    return SfCartesianChart(
      title: ChartTitle(text: title),
      primaryXAxis: CategoryAxis(),
      primaryYAxis: NumericAxis(),
      tooltipBehavior: TooltipBehavior(enable: true),
      series: <LineSeries<ErrorBarData, String>>[
        LineSeries<ErrorBarData, String>(
          dataSource: data,
          xValueMapper: (ErrorBarData data, _) => data.category,
          yValueMapper: (ErrorBarData data, _) => data.value,
          animationDuration: enableAnimation ? 1000 : 0,
          markerSettings: const MarkerSettings(isVisible: true),
          errorBarSettings: ErrorBarSettings(
            isVisible: true,
            type: errorBarType,
            direction: ErrorBarDirection.both,
            mode: RenderingMode.both,
            color: Colors.red,
            width: 2,
            capLength: 5,
            verticalErrorValue: 5,
            horizontalErrorValue: 2,
          ),
        ),
      ],
    );
  }

  /// 11. 다중 축 차트 (Multi-Axis Chart) - 서로 다른 단위 비교용
  static Widget buildMultiAxisChart({
    required List<MultiAxisData> salesData,
    required List<MultiAxisData> quantityData,
    String title = '매출-수량 이중축 분석',
    bool enableAnimation = true,
  }) {
    return SfCartesianChart(
      title: ChartTitle(text: title),
      primaryXAxis: CategoryAxis(),
      primaryYAxis: NumericAxis(
        name: 'primaryYAxis',
        title: AxisTitle(text: '매출액 (₩)'),
        numberFormat: NumberFormat.compact(),
      ),
      axes: <ChartAxis>[
        NumericAxis(
          name: 'secondaryYAxis',
          opposedPosition: true,
          title: AxisTitle(text: '수량 (개)'),
          numberFormat: NumberFormat('#,###'),
        ),
      ],
      tooltipBehavior: TooltipBehavior(enable: true),
      series: <CartesianSeries>[
        ColumnSeries<MultiAxisData, String>(
          dataSource: salesData,
          xValueMapper: (MultiAxisData data, _) => data.category,
          yValueMapper: (MultiAxisData data, _) => data.value,
          name: '매출액',
          yAxisName: 'primaryYAxis',
          animationDuration: enableAnimation ? 1000 : 0,
        ),
        LineSeries<MultiAxisData, String>(
          dataSource: quantityData,
          xValueMapper: (MultiAxisData data, _) => data.category,
          yValueMapper: (MultiAxisData data, _) => data.value,
          name: '수량',
          yAxisName: 'secondaryYAxis',
          animationDuration: enableAnimation ? 1200 : 0,
          markerSettings: const MarkerSettings(isVisible: true),
        ),
      ],
    );
  }

  /// 12. 100% 스택 차트 (100% Stacked Chart) - 구성비 분석용
  static Widget buildStackedPercentChart({
    required List<StackedData> data,
    String title = '구성비 분석',
    bool enableAnimation = true,
    bool showDataLabels = true,
  }) {
    // 데이터를 시리즈별로 그룹화
    final Map<String, List<StackedData>> groupedData = {};
    for (final item in data) {
      groupedData[item.series] ??= [];
      groupedData[item.series]!.add(item);
    }

    return SfCartesianChart(
      title: ChartTitle(text: title),
      primaryXAxis: CategoryAxis(),
      primaryYAxis: NumericAxis(numberFormat: NumberFormat.percentPattern()),
      tooltipBehavior: TooltipBehavior(enable: true),
      series: groupedData.entries.map((entry) =>
        StackedColumn100Series<StackedData, String>(
          dataSource: entry.value,
          xValueMapper: (StackedData data, _) => data.category,
          yValueMapper: (StackedData data, _) => data.value,
          name: entry.key,
          dataLabelSettings: DataLabelSettings(isVisible: showDataLabels),
          animationDuration: enableAnimation ? 1000 : 0,
        ),
      ).toList(),
    );
  }

  /// 13. 스플라인 영역 차트 (Spline Area Chart) - 부드러운 트렌드 분석용
  static Widget buildSplineAreaChart({
    required List<ChartData> data,
    String title = '부드러운 트렌드 분석',
    bool enableAnimation = true,
    bool showMarkers = false,
    double opacity = 0.7,
  }) {
    return SfCartesianChart(
      title: ChartTitle(text: title),
      primaryXAxis: CategoryAxis(),
      primaryYAxis: NumericAxis(numberFormat: NumberFormat.compact()),
      tooltipBehavior: TooltipBehavior(enable: true),
      series: <SplineAreaSeries<ChartData, String>>[
        SplineAreaSeries<ChartData, String>(
          dataSource: data,
          xValueMapper: (ChartData data, _) => data.category,
          yValueMapper: (ChartData data, _) => data.value,
          animationDuration: enableAnimation ? 1200 : 0,
          markerSettings: MarkerSettings(isVisible: showMarkers),
          opacity: opacity,
          gradient: LinearGradient(
            colors: [
              Colors.blue.withOpacity(0.8),
              Colors.blue.withOpacity(0.2),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
      ],
    );
  }

  /// 14. 레인지 영역 차트 (Range Area Chart) - 범위 데이터 시각화
  static Widget buildRangeAreaChart({
    required List<RangeData> data,
    String title = '데이터 범위 분석',
    bool enableAnimation = true,
    Color? fillColor,
  }) {
    return SfCartesianChart(
      title: ChartTitle(text: title),
      primaryXAxis: CategoryAxis(),
      primaryYAxis: NumericAxis(numberFormat: NumberFormat.compact()),
      tooltipBehavior: TooltipBehavior(enable: true),
      series: <RangeAreaSeries<RangeData, String>>[
        RangeAreaSeries<RangeData, String>(
          dataSource: data,
          xValueMapper: (RangeData data, _) => data.category,
          highValueMapper: (RangeData data, _) => data.high,
          lowValueMapper: (RangeData data, _) => data.low,
          animationDuration: enableAnimation ? 1000 : 0,
          color: fillColor ?? Colors.blue.withOpacity(0.5),
          borderColor: Colors.blue,
          borderWidth: 2,
        ),
      ],
    );
  }

  /// 15. 캔들스틱 차트 (Candlestick Chart) - 금융 데이터용
  static Widget buildCandlestickChart({
    required List<CandlestickData> data,
    String title = '금융 데이터 분석',
    bool enableAnimation = true,
    bool showVolume = true,
  }) {
    return SfCartesianChart(
      title: ChartTitle(text: title),
      primaryXAxis: DateTimeAxis(
        dateFormat: DateFormat('MM/dd'),
      ),
      primaryYAxis: NumericAxis(
        name: 'priceAxis',
        title: AxisTitle(text: '가격'),
      ),
      axes: showVolume ? <ChartAxis>[
        NumericAxis(
          name: 'volumeAxis',
          opposedPosition: true,
          title: AxisTitle(text: '거래량'),
        ),
      ] : null,
      tooltipBehavior: TooltipBehavior(enable: true),
      trackballBehavior: TrackballBehavior(
        enable: true,
        activationMode: ActivationMode.singleTap,
      ),
      series: <CartesianSeries>[
        CandleSeries<CandlestickData, DateTime>(
          dataSource: data,
          xValueMapper: (CandlestickData data, _) => data.date,
          lowValueMapper: (CandlestickData data, _) => data.low,
          highValueMapper: (CandlestickData data, _) => data.high,
          openValueMapper: (CandlestickData data, _) => data.open,
          closeValueMapper: (CandlestickData data, _) => data.close,
          yAxisName: 'priceAxis',
          animationDuration: enableAnimation ? 1000 : 0,
          bearColor: Colors.red,
          bullColor: Colors.green,
        ),
        if (showVolume)
          ColumnSeries<CandlestickData, DateTime>(
            dataSource: data,
            xValueMapper: (CandlestickData data, _) => data.date,
            yValueMapper: (CandlestickData data, _) => data.volume,
            yAxisName: 'volumeAxis',
            animationDuration: enableAnimation ? 800 : 0,
            opacity: 0.7,
          ),
      ],
    );
  }
}

// 데이터 클래스들
class FunnelData {
  final String stage;
  final double value;
  FunnelData(this.stage, this.value);
}

class PyramidData {
  final String category;
  final double value;
  PyramidData(this.category, this.value);
}

class TreeMapData {
  final String label;
  final double value;
  TreeMapData(this.label, this.value);
}

class HeatmapData {
  final String xCategory;
  final String yCategory;
  final double value;
  HeatmapData(this.xCategory, this.yCategory, this.value);
}

class PolarData {
  final String category;
  final double value;
  PolarData(this.category, this.value);
}

class WaterfallData {
  final String category;
  final double value;
  final bool isIntermediate;
  final bool isTotal;
  WaterfallData(this.category, this.value, {this.isIntermediate = false, this.isTotal = false});
}

class BoxPlotData {
  final String category;
  final List<double> values;
  BoxPlotData(this.category, this.values);
}

class ErrorBarData {
  final String category;
  final double value;
  final double error;
  ErrorBarData(this.category, this.value, this.error);
}

class MultiAxisData {
  final String category;
  final double value;
  MultiAxisData(this.category, this.value);
}

class StackedData {
  final String category;
  final String series;
  final double value;
  StackedData(this.category, this.series, this.value);
}

class ChartData {
  final String category;
  final double value;
  ChartData(this.category, this.value);
}

class RangeData {
  final String category;
  final double high;
  final double low;
  RangeData(this.category, this.high, this.low);
}

class CandlestickData {
  final DateTime date;
  final double open;
  final double high;
  final double low;
  final double close;
  final double volume;
  CandlestickData(this.date, this.open, this.high, this.low, this.close, this.volume);
}

enum PolarChartType { line, area }
enum ErrorBarType { fixed, percentage, standardDeviation, standardError, custom }