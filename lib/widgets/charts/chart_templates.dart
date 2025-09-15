import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;

/// 🚀 MSM용 간단한 차트 템플릿 라이브러리 (Material Design 기반)
/// 
/// 사용법:
/// ```dart
/// ChartTemplates.buildPieChart(
///   data: [{'name': '대리점A', 'value': 1000000}],
///   title: '대리점별 매출 비율',
/// )
/// ```
class ChartTemplates {
  
  // ===== 📊 파이차트 템플릿 (Canvas 기반) =====
  
  /// 파이차트 - 기본형
  static Widget buildPieChart({
    required List<Map<String, dynamic>> data,
    required String title,
    String nameField = 'name',
    String valueField = 'value',
    bool showDataLabels = true,
    bool showLegend = true,
    double? radius,
    Color? backgroundColor,
  }) {
    return Card(
      elevation: 2,
      color: backgroundColor ?? Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (title.isNotEmpty) ...[
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
            ],
            Expanded(
              child: _SimplePieChart(
                data: data,
                nameField: nameField,
                valueField: valueField,
                showLegend: showLegend,
                showDataLabels: showDataLabels,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 도넛차트 - 중앙에 총합 표시
  static Widget buildDonutChart({
    required List<Map<String, dynamic>> data,
    required String title,
    String nameField = 'name',
    String valueField = 'value',
    String? centerText,
    bool showDataLabels = true,
    Color? backgroundColor,
  }) {
    final total = data.fold<double>(0, (sum, item) => 
      sum + ((item[valueField] as num?)?.toDouble() ?? 0));
    
    return Card(
      elevation: 2,
      color: backgroundColor ?? Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (title.isNotEmpty) ...[
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
            ],
            Expanded(
              child: Stack(
                children: [
                  _SimplePieChart(
                    data: data,
                    nameField: nameField,
                    valueField: valueField,
                    showLegend: false,
                    showDataLabels: showDataLabels,
                    isDonut: true,
                  ),
                  if (centerText != null)
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            centerText,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            NumberFormat('#,###').format(total),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                        ],
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

  // ===== 📊 바차트 템플릿 =====
  
  /// 세로 바차트 - 기본형
  static Widget buildColumnChart({
    required List<Map<String, dynamic>> data,
    required String title,
    String xField = 'x',
    String yField = 'y',
    String? yAxisTitle,
    bool enableZooming = false,
    Color? backgroundColor,
  }) {
    return Card(
      elevation: 2,
      color: backgroundColor ?? Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (title.isNotEmpty) ...[
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
            ],
            Expanded(
              child: _SimpleBarChart(
                data: data,
                xField: xField,
                yField: yField,
                isVertical: true,
                color: Colors.blue[400]!,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 가로 바차트
  static Widget buildBarChart({
    required List<Map<String, dynamic>> data,
    required String title,
    String xField = 'x',
    String yField = 'y',
    Color? backgroundColor,
  }) {
    return Card(
      elevation: 2,
      color: backgroundColor ?? Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (title.isNotEmpty) ...[
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
            ],
            Expanded(
              child: _SimpleBarChart(
                data: data,
                xField: xField,
                yField: yField,
                isVertical: false,
                color: Colors.green[400]!,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===== 📈 라인차트 템플릿 =====
  
  /// 라인차트 - 단일 시리즈
  static Widget buildLineChart({
    required List<Map<String, dynamic>> data,
    required String title,
    String xField = 'x',
    String yField = 'y',
    String? yAxisTitle,
    bool showMarkers = true,
    Color? lineColor,
    Color? backgroundColor,
  }) {
    return Card(
      elevation: 2,
      color: backgroundColor ?? Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (title.isNotEmpty) ...[
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
            ],
            Expanded(
              child: _SimpleLineChart(
                data: data,
                xField: xField,
                yField: yField,
                color: lineColor ?? Colors.purple[400]!,
                showMarkers: showMarkers,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 다중 라인차트 (간단 버전)
  static Widget buildMultiLineChart({
    required List<Map<String, dynamic>> data,
    required String title,
    required List<String> seriesFields,
    required List<String> seriesNames,
    String xField = 'x',
    String? yAxisTitle,
    List<Color>? seriesColors,
    Color? backgroundColor,
  }) {
    return Card(
      elevation: 2,
      color: backgroundColor ?? Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (title.isNotEmpty) ...[
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
            ],
            // 범례
            Wrap(
              children: seriesNames.asMap().entries.map((entry) {
                final index = entry.key;
                final name = entry.value;
                final color = seriesColors?[index] ?? generateColors(seriesNames.length)[index];
                
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        color: color,
                      ),
                      const SizedBox(width: 4),
                      Text(name, style: const TextStyle(fontSize: 10)),
                    ],
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _MultiLineChart(
                data: data,
                xField: xField,
                seriesFields: seriesFields,
                colors: seriesColors ?? generateColors(seriesFields.length),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===== 📊 영역차트 및 콤보차트 =====
  
  /// 영역차트 - 누적형 (간단 버전)
  static Widget buildAreaChart({
    required List<Map<String, dynamic>> data,
    required String title,
    String xField = 'x',
    String yField = 'y',
    Color? areaColor,
    Color? backgroundColor,
  }) {
    return Card(
      elevation: 2,
      color: backgroundColor ?? Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (title.isNotEmpty) ...[
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
            ],
            Expanded(
              child: _SimpleAreaChart(
                data: data,
                xField: xField,
                yField: yField,
                color: areaColor ?? Colors.cyan[300]!,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 콤보차트 - 바 + 라인 (간단 버전)
  static Widget buildComboChart({
    required List<Map<String, dynamic>> data,
    required String title,
    String xField = 'x',
    String columnField = 'column',
    String lineField = 'line',
    String columnName = 'Column',
    String lineName = 'Line',
    Color? backgroundColor,
  }) {
    return Card(
      elevation: 2,
      color: backgroundColor ?? Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (title.isNotEmpty) ...[
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
            ],
            // 범례
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Container(width: 12, height: 12, color: Colors.blue[400]),
                    const SizedBox(width: 4),
                    Text(columnName, style: const TextStyle(fontSize: 10)),
                  ],
                ),
                const SizedBox(width: 16),
                Row(
                  children: [
                    Container(width: 12, height: 2, color: Colors.red[400]),
                    const SizedBox(width: 4),
                    Text(lineName, style: const TextStyle(fontSize: 10)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _ComboChart(
                data: data,
                xField: xField,
                columnField: columnField,
                lineField: lineField,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===== 🎯 특수 차트 템플릿 (향후 확장용) =====
  
  // 게이지 차트는 패키지 의존성 때문에 비활성화됨 
  // 필요시 다른 패키지로 대체 가능

  // ===== 🔧 유틸리티 메서드 =====

  /// 데이터 검증 및 정리
  static List<Map<String, dynamic>> cleanData(List<Map<String, dynamic>> data) {
    return data.where((item) => item.isNotEmpty).toList();
  }

  /// 색상 팔레트 생성
  static List<Color> generateColors(int count) {
    final baseColors = [
      Colors.blue[400]!,
      Colors.red[400]!,
      Colors.green[400]!,
      Colors.orange[400]!,
      Colors.purple[400]!,
      Colors.cyan[400]!,
      Colors.pink[400]!,
      Colors.amber[400]!,
      Colors.indigo[400]!,
      Colors.teal[400]!,
    ];
    
    final colors = <Color>[];
    for (int i = 0; i < count; i++) {
      colors.add(baseColors[i % baseColors.length]);
    }
    return colors;
  }
}

// ===== 🎨 커스텀 차트 위젯들 =====

/// 간단한 파이차트 위젯
class _SimplePieChart extends StatelessWidget {
  final List<Map<String, dynamic>> data;
  final String nameField;
  final String valueField;
  final bool showLegend;
  final bool showDataLabels;
  final bool isDonut;

  const _SimplePieChart({
    required this.data,
    required this.nameField,
    required this.valueField,
    this.showLegend = true,
    this.showDataLabels = true,
    this.isDonut = false,
  });

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const Center(child: Text('데이터 없음', style: TextStyle(color: Colors.grey)));
    }

    final total = data.fold<double>(0, (sum, item) => 
      sum + ((item[valueField] as num?)?.toDouble() ?? 0));
    
    if (total == 0) {
      return const Center(child: Text('데이터 없음', style: TextStyle(color: Colors.grey)));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = math.min(constraints.maxWidth, constraints.maxHeight);
        final radius = size * 0.4;
        final colors = ChartTemplates.generateColors(data.length);

        return Row(
          children: [
            // 파이차트
            Expanded(
              flex: 2,
              child: SizedBox(
                width: size,
                height: size,
                child: CustomPaint(
                  painter: _PieChartPainter(
                    data: data,
                    nameField: nameField,
                    valueField: valueField,
                    colors: colors,
                    total: total,
                    radius: radius,
                    isDonut: isDonut,
                    showDataLabels: showDataLabels,
                  ),
                ),
              ),
            ),
            // 범례
            if (showLegend && !isDonut)
              Expanded(
                flex: 1,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: data.asMap().entries.map((entry) {
                    final index = entry.key;
                    final item = entry.value;
                    final name = item[nameField]?.toString() ?? '';
                    final value = (item[valueField] as num?)?.toDouble() ?? 0;
                    final percentage = (value / total * 100).toStringAsFixed(1);
                    
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            color: colors[index],
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '$name\n$percentage%',
                              style: const TextStyle(fontSize: 9),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
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
      },
    );
  }
}

/// 파이차트 페인터
class _PieChartPainter extends CustomPainter {
  final List<Map<String, dynamic>> data;
  final String nameField;
  final String valueField;
  final List<Color> colors;
  final double total;
  final double radius;
  final bool isDonut;
  final bool showDataLabels;

  _PieChartPainter({
    required this.data,
    required this.nameField,
    required this.valueField,
    required this.colors,
    required this.total,
    required this.radius,
    required this.isDonut,
    required this.showDataLabels,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()..style = PaintingStyle.fill;
    
    double startAngle = -math.pi / 2; // 12시 방향부터 시작
    
    for (int i = 0; i < data.length; i++) {
      final value = (data[i][valueField] as num?)?.toDouble() ?? 0;
      final sweepAngle = (value / total) * 2 * math.pi;
      
      paint.color = colors[i];
      
      if (isDonut) {
        // 도넛차트
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius),
          startAngle,
          sweepAngle,
          true,
          paint,
        );
        
        // 내부 원 제거
        paint.color = Colors.white;
        canvas.drawCircle(center, radius * 0.6, paint);
      } else {
        // 일반 파이차트
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius),
          startAngle,
          sweepAngle,
          true,
          paint,
        );
      }
      
      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// 간단한 바차트 위젯
class _SimpleBarChart extends StatelessWidget {
  final List<Map<String, dynamic>> data;
  final String xField;
  final String yField;
  final bool isVertical;
  final Color color;

  const _SimpleBarChart({
    required this.data,
    required this.xField,
    required this.yField,
    required this.isVertical,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const Center(child: Text('데이터 없음', style: TextStyle(color: Colors.grey)));
    }

    final maxValue = data.fold<double>(0, (max, item) {
      final value = (item[yField] as num?)?.toDouble() ?? 0;
      return math.max(max, value);
    });

    if (maxValue == 0) {
      return const Center(child: Text('데이터 없음', style: TextStyle(color: Colors.grey)));
    }

    return Column(
      children: [
        // Y축 제목
        Text('값: ${NumberFormat.compact().format(maxValue)}', 
             style: const TextStyle(fontSize: 10, color: Colors.grey)),
        const SizedBox(height: 8),
        Expanded(
          child: isVertical 
            ? _buildVerticalBars(maxValue)
            : _buildHorizontalBars(maxValue),
        ),
      ],
    );
  }

  Widget _buildVerticalBars(double maxValue) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: data.map((item) {
        final value = (item[yField] as num?)?.toDouble() ?? 0;
        final label = item[xField]?.toString() ?? '';
        final height = (value / maxValue) * 100;
        
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // 값 표시
                Text(
                  NumberFormat.compact().format(value),
                  style: const TextStyle(fontSize: 8),
                ),
                const SizedBox(height: 4),
                // 바
                Container(
                  height: height,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
                  ),
                ),
                const SizedBox(height: 4),
                // 라벨
                Text(
                  label,
                  style: const TextStyle(fontSize: 8),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildHorizontalBars(double maxValue) {
    return Column(
      children: data.map((item) {
        final value = (item[yField] as num?)?.toDouble() ?? 0;
        final label = item[xField]?.toString() ?? '';
        final widthPercent = value / maxValue;
        
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                // 라벨
                SizedBox(
                  width: 60,
                  child: Text(
                    label,
                    style: const TextStyle(fontSize: 9),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                // 바
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return Stack(
                        children: [
                          Container(
                            height: 20,
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          Container(
                            height: 20,
                            width: constraints.maxWidth * widthPercent,
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          Positioned(
                            right: 4,
                            top: 4,
                            child: Text(
                              NumberFormat.compact().format(value),
                              style: const TextStyle(fontSize: 8, color: Colors.white),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

/// 간단한 라인차트 위젯
class _SimpleLineChart extends StatelessWidget {
  final List<Map<String, dynamic>> data;
  final String xField;
  final String yField;
  final Color color;
  final bool showMarkers;

  const _SimpleLineChart({
    required this.data,
    required this.xField,
    required this.yField,
    required this.color,
    required this.showMarkers,
  });

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const Center(child: Text('데이터 없음', style: TextStyle(color: Colors.grey)));
    }

    final values = data.map((item) => (item[yField] as num?)?.toDouble() ?? 0).toList();
    final maxValue = values.reduce(math.max);
    final minValue = values.reduce(math.min);

    if (maxValue == minValue) {
      return const Center(child: Text('데이터 변화 없음', style: TextStyle(color: Colors.grey)));
    }

    return CustomPaint(
      painter: _LineChartPainter(
        data: data,
        xField: xField,
        yField: yField,
        color: color,
        showMarkers: showMarkers,
        maxValue: maxValue,
        minValue: minValue,
      ),
      child: Container(),
    );
  }
}

/// 라인차트 페인터
class _LineChartPainter extends CustomPainter {
  final List<Map<String, dynamic>> data;
  final String xField;
  final String yField;
  final Color color;
  final bool showMarkers;
  final double maxValue;
  final double minValue;

  _LineChartPainter({
    required this.data,
    required this.xField,
    required this.yField,
    required this.color,
    required this.showMarkers,
    required this.maxValue,
    required this.minValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final path = Path();
    final points = <Offset>[];

    for (int i = 0; i < data.length; i++) {
      final value = (data[i][yField] as num?)?.toDouble() ?? 0;
      final x = (i / (data.length - 1)) * size.width;
      final y = size.height - ((value - minValue) / (maxValue - minValue)) * size.height;
      
      final point = Offset(x, y);
      points.add(point);
      
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, paint);

    if (showMarkers) {
      paint.style = PaintingStyle.fill;
      for (final point in points) {
        canvas.drawCircle(point, 3, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// 다중 라인차트 위젯
class _MultiLineChart extends StatelessWidget {
  final List<Map<String, dynamic>> data;
  final String xField;
  final List<String> seriesFields;
  final List<Color> colors;

  const _MultiLineChart({
    required this.data,
    required this.xField,
    required this.seriesFields,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const Center(child: Text('데이터 없음', style: TextStyle(color: Colors.grey)));
    }

    // 모든 시리즈의 최대/최소값 계산
    double maxValue = double.negativeInfinity;
    double minValue = double.infinity;

    for (final field in seriesFields) {
      for (final item in data) {
        final value = (item[field] as num?)?.toDouble() ?? 0;
        maxValue = math.max(maxValue, value);
        minValue = math.min(minValue, value);
      }
    }

    if (maxValue == minValue) {
      return const Center(child: Text('데이터 변화 없음', style: TextStyle(color: Colors.grey)));
    }

    return CustomPaint(
      painter: _MultiLineChartPainter(
        data: data,
        xField: xField,
        seriesFields: seriesFields,
        colors: colors,
        maxValue: maxValue,
        minValue: minValue,
      ),
      child: Container(),
    );
  }
}

/// 다중 라인차트 페인터
class _MultiLineChartPainter extends CustomPainter {
  final List<Map<String, dynamic>> data;
  final String xField;
  final List<String> seriesFields;
  final List<Color> colors;
  final double maxValue;
  final double minValue;

  _MultiLineChartPainter({
    required this.data,
    required this.xField,
    required this.seriesFields,
    required this.colors,
    required this.maxValue,
    required this.minValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (int seriesIndex = 0; seriesIndex < seriesFields.length; seriesIndex++) {
      final field = seriesFields[seriesIndex];
      final color = colors[seriesIndex];
      
      final paint = Paint()
        ..color = color
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;

      final path = Path();

      for (int i = 0; i < data.length; i++) {
        final value = (data[i][field] as num?)?.toDouble() ?? 0;
        final x = (i / (data.length - 1)) * size.width;
        final y = size.height - ((value - minValue) / (maxValue - minValue)) * size.height;
        
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }

      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// 간단한 영역차트 위젯
class _SimpleAreaChart extends StatelessWidget {
  final List<Map<String, dynamic>> data;
  final String xField;
  final String yField;
  final Color color;

  const _SimpleAreaChart({
    required this.data,
    required this.xField,
    required this.yField,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const Center(child: Text('데이터 없음', style: TextStyle(color: Colors.grey)));
    }

    final values = data.map((item) => (item[yField] as num?)?.toDouble() ?? 0).toList();
    final maxValue = values.reduce(math.max);
    final minValue = values.reduce(math.min);

    return CustomPaint(
      painter: _AreaChartPainter(
        data: data,
        xField: xField,
        yField: yField,
        color: color,
        maxValue: maxValue,
        minValue: minValue,
      ),
      child: Container(),
    );
  }
}

/// 영역차트 페인터
class _AreaChartPainter extends CustomPainter {
  final List<Map<String, dynamic>> data;
  final String xField;
  final String yField;
  final Color color;
  final double maxValue;
  final double minValue;

  _AreaChartPainter({
    required this.data,
    required this.xField,
    required this.yField,
    required this.color,
    required this.maxValue,
    required this.minValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.5)
      ..style = PaintingStyle.fill;

    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final path = Path();
    final linePath = Path();

    // 시작점 (왼쪽 아래)
    path.moveTo(0, size.height);

    for (int i = 0; i < data.length; i++) {
      final value = (data[i][yField] as num?)?.toDouble() ?? 0;
      final x = (i / (data.length - 1)) * size.width;
      final y = size.height - ((value - minValue) / (maxValue - minValue)) * size.height;
      
      if (i == 0) {
        path.lineTo(x, y);
        linePath.moveTo(x, y);
      } else {
        path.lineTo(x, y);
        linePath.lineTo(x, y);
      }
    }

    // 끝점 (오른쪽 아래)
    path.lineTo(size.width, size.height);
    path.close();

    canvas.drawPath(path, paint);
    canvas.drawPath(linePath, linePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// 콤보차트 위젯
class _ComboChart extends StatelessWidget {
  final List<Map<String, dynamic>> data;
  final String xField;
  final String columnField;
  final String lineField;

  const _ComboChart({
    required this.data,
    required this.xField,
    required this.columnField,
    required this.lineField,
  });

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const Center(child: Text('데이터 없음', style: TextStyle(color: Colors.grey)));
    }

    final columnValues = data.map((item) => (item[columnField] as num?)?.toDouble() ?? 0).toList();
    final lineValues = data.map((item) => (item[lineField] as num?)?.toDouble() ?? 0).toList();
    
    final maxColumn = columnValues.reduce(math.max);
    final maxLine = lineValues.reduce(math.max);

    return CustomPaint(
      painter: _ComboChartPainter(
        data: data,
        xField: xField,
        columnField: columnField,
        lineField: lineField,
        maxColumn: maxColumn,
        maxLine: maxLine,
      ),
      child: Container(),
    );
  }
}

/// 콤보차트 페인터
class _ComboChartPainter extends CustomPainter {
  final List<Map<String, dynamic>> data;
  final String xField;
  final String columnField;
  final String lineField;
  final double maxColumn;
  final double maxLine;

  _ComboChartPainter({
    required this.data,
    required this.xField,
    required this.columnField,
    required this.lineField,
    required this.maxColumn,
    required this.maxLine,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final columnPaint = Paint()..color = Colors.blue[400]!;
    final linePaint = Paint()
      ..color = Colors.red[400]!
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final barWidth = size.width / data.length * 0.6;
    final linePath = Path();

    for (int i = 0; i < data.length; i++) {
      final columnValue = (data[i][columnField] as num?)?.toDouble() ?? 0;
      final lineValue = (data[i][lineField] as num?)?.toDouble() ?? 0;
      
      final x = (i + 0.5) * (size.width / data.length);
      
      // 바차트 그리기
      final barHeight = (columnValue / maxColumn) * size.height * 0.8;
      final barRect = Rect.fromLTWH(
        x - barWidth / 2,
        size.height - barHeight,
        barWidth,
        barHeight,
      );
      canvas.drawRect(barRect, columnPaint);
      
      // 라인차트 그리기
      final lineY = size.height - (lineValue / maxLine) * size.height * 0.8;
      if (i == 0) {
        linePath.moveTo(x, lineY);
      } else {
        linePath.lineTo(x, lineY);
      }
      
      // 라인 마커
      canvas.drawCircle(Offset(x, lineY), 4, Paint()..color = Colors.red[400]!);
    }

    canvas.drawPath(linePath, linePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
} 