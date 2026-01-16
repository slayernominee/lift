import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

class ChartDataPoint {
  final DateTime date;
  final double value;

  ChartDataPoint({required this.date, required this.value});
}

class TimelineChart extends StatefulWidget {
  final List<ChartDataPoint> points;
  final String label;
  final String subLabel;
  final Color? color;

  const TimelineChart({
    super.key,
    required this.points,
    required this.label,
    required this.subLabel,
    this.color,
  });

  @override
  State<TimelineChart> createState() => _TimelineChartState();
}

class _TimelineChartState extends State<TimelineChart> {
  String _selectedRange = 'All';
  int _chartOffsetDays = 0;

  int _getRangeDays() {
    if (_selectedRange == '1W') return 7;
    if (_selectedRange == '1M') return 30;
    if (_selectedRange == '3M') return 90;
    return 0;
  }

  String _getRangeText(DateTime endPoint) {
    if (_selectedRange == 'All') return 'All Time';
    final start = endPoint.subtract(Duration(days: _getRangeDays()));
    return '${DateFormat('MMM d').format(start)} - ${DateFormat('MMM d').format(endPoint)}';
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final endPoint = today.subtract(Duration(days: _chartOffsetDays));

    DateTime? minDate;
    if (_selectedRange == '1W') minDate = endPoint.subtract(const Duration(days: 7));
    else if (_selectedRange == '1M') minDate = endPoint.subtract(const Duration(days: 30));
    else if (_selectedRange == '3M') minDate = endPoint.subtract(const Duration(days: 90));

    final filteredPoints = widget.points.where((p) {
      final pDate = DateTime(p.date.year, p.date.month, p.date.day);
      if (minDate != null && (pDate.isBefore(minDate!) || pDate.isAfter(endPoint))) return false;
      return true;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.label,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  widget.subLabel,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            _buildRangeSwitcher(),
          ],
        ),
        if (_selectedRange != 'All')
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.chevron_left, size: 20),
                  onPressed: () => setState(() => _chartOffsetDays += _getRangeDays()),
                ),
                Text(
                  _getRangeText(endPoint),
                  style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.chevron_right, size: 20),
                  onPressed: _chartOffsetDays <= 0 ? null : () => setState(() {
                    _chartOffsetDays -= _getRangeDays();
                    if (_chartOffsetDays < 0) _chartOffsetDays = 0;
                  }),
                ),
              ],
            ),
          ),
        const SizedBox(height: 24),
        _buildChart(filteredPoints, minDate, endPoint, today),
      ],
    );
  }

  Widget _buildRangeSwitcher() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: ['1W', '1M', '3M', 'All'].map((range) {
          bool isSelected = _selectedRange == range;
          return GestureDetector(
            onTap: () => setState(() {
              _selectedRange = range;
              _chartOffsetDays = 0;
            }),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected ? Theme.of(context).colorScheme.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                range,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : Colors.grey,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildChart(List<ChartDataPoint> filteredPoints, DateTime? minDate, DateTime endPoint, DateTime today) {
    if (widget.points.isEmpty) {
      return Container(
        height: 200,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Text('No data recorded yet', style: TextStyle(color: Colors.grey)),
        ),
      );
    }

    final oldestPoint = widget.points.map((p) => p.date).reduce((a, b) => a.isBefore(b) ? a : b);
    final oldestDate = DateTime(oldestPoint.year, oldestPoint.month, oldestPoint.day);

    DateTime chartStart;
    if (_selectedRange == 'All') {
      chartStart = oldestDate;
    } else {
      chartStart = minDate ?? oldestDate;
    }

    final firstTime = chartStart.millisecondsSinceEpoch;
    const msPerDay = 24 * 60 * 60 * 1000;

    double maxX = (_selectedRange == 'All')
        ? (today.millisecondsSinceEpoch - firstTime) / msPerDay
        : (endPoint.millisecondsSinceEpoch - firstTime) / msPerDay;
    if (maxX <= 0) maxX = 7.0;

    List<FlSpot> spots = [];
    for (var p in filteredPoints) {
      final pDate = DateTime(p.date.year, p.date.month, p.date.day);
      final x = (pDate.millisecondsSinceEpoch - firstTime) / msPerDay;
      if (x >= 0 && x <= maxX) {
        spots.add(FlSpot(x.toDouble(), p.value));
      }
    }

    final themeColor = widget.color ?? Theme.of(context).colorScheme.primary;

    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          onHorizontalDragEnd: (details) {
            if (_selectedRange == 'All') return;
            if (details.primaryVelocity! > 0) {
              setState(() => _chartOffsetDays += _getRangeDays());
            } else if (details.primaryVelocity! < 0) {
              if (_chartOffsetDays > 0) {
                setState(() {
                  _chartOffsetDays -= _getRangeDays();
                  if (_chartOffsetDays < 0) _chartOffsetDays = 0;
                });
              }
            }
          },
          child: Container(
            height: 220,
            padding: const EdgeInsets.only(right: 20, top: 10, bottom: 10),
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: maxX,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: true,
                  getDrawingVerticalLine: (value) => FlLine(
                    color: Theme.of(context).dividerColor.withOpacity(0.05),
                    strokeWidth: 1,
                  ),
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: Theme.of(context).dividerColor.withOpacity(0.1),
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) => Text(
                        value.toStringAsFixed(0),
                        style: const TextStyle(color: Colors.grey, fontSize: 10),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        final date = DateTime.fromMillisecondsSinceEpoch(
                          (value * msPerDay + firstTime).toInt(),
                        );
                        bool showLabel = true;
                        if (_selectedRange == '1M') showLabel = value % 5 == 0;
                        else if (_selectedRange == '3M') showLabel = value % 10 == 0;
                        else if (_selectedRange == 'All') showLabel = value % 30 == 0;
                        if (!showLabel && value != maxX) return const SizedBox();
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            DateFormat('MM/dd').format(date),
                            style: const TextStyle(color: Colors.grey, fontSize: 8),
                          ),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: false,
                    color: themeColor,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                        radius: 4,
                        color: themeColor,
                        strokeWidth: 2,
                        strokeColor: Theme.of(context).scaffoldBackgroundColor,
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          themeColor.withOpacity(0.3),
                          themeColor.withOpacity(0.0),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
