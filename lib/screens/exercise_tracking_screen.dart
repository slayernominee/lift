import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:lift/models/exercise.dart';
import 'package:lift/models/workout.dart';
import 'package:lift/models/log.dart';
import 'package:lift/providers/workout_provider.dart';

class ExerciseTrackingScreen extends StatefulWidget {
  final Workout workout;
  final WorkoutExercise workoutExercise;
  final Exercise exercise;

  const ExerciseTrackingScreen({
    super.key,
    required this.workout,
    required this.workoutExercise,
    required this.exercise,
  });

  @override
  State<ExerciseTrackingScreen> createState() => _ExerciseTrackingScreenState();
}

class _ExerciseTrackingScreenState extends State<ExerciseTrackingScreen> {
  DateTime _selectedDate = DateTime.now();
  ExerciseLog? _currentLog;
  ExerciseLog? _lastLog;
  String _selectedRange = 'All';
  int _chartOffsetDays = 0;

  @override
  void initState() {
    super.initState();
    _loadLog();
  }

  void _loadLog() {
    final provider = context.read<WorkoutProvider>();
    final log = provider.getLog(widget.exercise.id, widget.workout.id, _selectedDate);
    _lastLog = provider.getLastLog(widget.exercise.id, widget.workout.id);

    setState(() {
      if (log != null) {
        _currentLog = log;
      } else {
        _currentLog = ExerciseLog.create(
          exerciseId: widget.exercise.id,
          workoutId: widget.workout.id,
          date: _selectedDate,
        );

        if (_lastLog != null && _lastLog!.sets.isNotEmpty) {
          for (int i = 0; i < _lastLog!.sets.length; i++) {
            _currentLog!.sets.add(ExerciseSet(weight: 0, reps: 0));
          }
        } else {
          for (int i = 0; i < widget.workoutExercise.targetSets; i++) {
            _currentLog!.sets.add(ExerciseSet(weight: 0, reps: 0));
          }
        }
      }
    });
  }

  void _saveLog() {
    if (_currentLog != null) {
      context.read<WorkoutProvider>().saveLog(_currentLog!);
    }
  }

  void _updateDate(DateTime date) {
    setState(() {
      _selectedDate = date;
    });
    _loadLog();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.exercise.name),
      ),
      body: Column(
        children: [
          _buildDateSwitcher(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildSetsHeader(),
                const SizedBox(height: 8),
                if (_currentLog != null) ...[
                  ..._currentLog!.sets.asMap().entries.map((entry) {
                    return _buildSetRow(entry.key, entry.value);
                  }),
                  const SizedBox(height: 16),
                  _buildAddSetButton(),
                ],
                const SizedBox(height: 40),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Repetition History',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Total reps per session',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
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
                          _getRangeText(),
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
                _buildRepetitionChart(),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }

  int _getRangeDays() {
    if (_selectedRange == '1W') return 7;
    if (_selectedRange == '1M') return 30;
    if (_selectedRange == '3M') return 90;
    return 0;
  }

  String _getRangeText() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final end = today.subtract(Duration(days: _chartOffsetDays));
    final start = end.subtract(Duration(days: _getRangeDays()));
    return '${DateFormat('MMM d').format(start)} - ${DateFormat('MMM d').format(end)}';
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

  Widget _buildDateSwitcher() {
    final isToday = DateUtils.isSameDay(_selectedDate, DateTime.now());
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.2),
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.1)),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () => _updateDate(_selectedDate.subtract(const Duration(days: 1))),
          ),
          InkWell(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _selectedDate,
                firstDate: DateTime(2020),
                lastDate: DateTime(2101),
              );
              if (picked != null) _updateDate(picked);
            },
            child: Column(
              children: [
                Text(
                  DateFormat('EEEE, MMM d').format(_selectedDate),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Text(
                  isToday ? 'Today' : 'Change Date',
                  style: TextStyle(
                    color: isToday ? Theme.of(context).colorScheme.primary : Colors.grey,
                    fontSize: 12,
                    fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () => _updateDate(_selectedDate.add(const Duration(days: 1))),
          ),
        ],
      ),
    );
  }

  Widget _buildSetsHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Row(
        children: const [
          Expanded(flex: 1, child: Text('SET', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey))),
          Expanded(flex: 3, child: Text('WEIGHT (KG)', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey))),
          Expanded(flex: 3, child: Text('REPS', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey))),
          Expanded(flex: 1, child: SizedBox()),
        ],
      ),
    );
  }

  Widget _buildSetRow(int index, ExerciseSet set) {
    String weightPlaceholder = '0';
    String repsPlaceholder = '0';
    if (_lastLog != null && _lastLog!.sets.length > index) {
      weightPlaceholder = _lastLog!.sets[index].weight.toString();
      repsPlaceholder = _lastLog!.sets[index].reps.toString();
    }

    return Dismissible(
      key: UniqueKey(),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.redAccent,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) {
        setState(() {
          _currentLog!.sets.removeAt(index);
          _saveLog();
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 4),
        child: Row(
          children: [
            Expanded(
              flex: 1,
              child: Center(
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: TextFormField(
                  key: ValueKey('weight-$index-${_selectedDate.toIso8601String()}'),
                  initialValue: set.weight == 0 ? '' : set.weight.toString(),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    fillColor: Theme.of(context).colorScheme.surface,
                    filled: true,
                    hintText: weightPlaceholder,
                    hintStyle: const TextStyle(color: Colors.grey, fontWeight: FontWeight.normal),
                  ),
                  onChanged: (val) {
                    set.weight = double.tryParse(val) ?? 0;
                    _saveLog();
                  },
                ),
              ),
            ),
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: TextFormField(
                  key: ValueKey('reps-$index-${_selectedDate.toIso8601String()}'),
                  initialValue: set.reps == 0 ? '' : set.reps.toString(),
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    fillColor: Theme.of(context).colorScheme.surface,
                    filled: true,
                    hintText: repsPlaceholder,
                    hintStyle: const TextStyle(color: Colors.grey, fontWeight: FontWeight.normal),
                  ),
                  onChanged: (val) {
                    set.reps = int.tryParse(val) ?? 0;
                    _saveLog();
                  },
                ),
              ),
            ),
            const Expanded(
              flex: 1,
              child: SizedBox(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddSetButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: OutlinedButton(
        onPressed: () {
          setState(() {
            final lastSet = _currentLog!.sets.isNotEmpty ? _currentLog!.sets.last : null;
            _currentLog!.sets.add(ExerciseSet(
              weight: lastSet?.weight ?? 0,
              reps: lastSet?.reps ?? 0,
            ));
            _saveLog();
          });
        },
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.add, size: 20),
            SizedBox(width: 8),
            Text('ADD SET'),
          ],
        ),
      ),
    );
  }

  Widget _buildRepetitionChart() {
    return Consumer<WorkoutProvider>(
      builder: (context, provider, child) {
        final allLogs = provider.getLogsForExercise(widget.exercise.id, widget.workout.id).reversed.toList();
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);

        final endPoint = today.subtract(Duration(days: _chartOffsetDays));
        DateTime? minDate;
        if (_selectedRange == '1W') minDate = endPoint.subtract(const Duration(days: 7));
        else if (_selectedRange == '1M') minDate = endPoint.subtract(const Duration(days: 30));
        else if (_selectedRange == '3M') minDate = endPoint.subtract(const Duration(days: 90));

        final filteredLogs = allLogs.where((log) {
          if (log.sets.isEmpty) return false;
          final logDate = DateTime(log.date.year, log.date.month, log.date.day);
          if (minDate != null && (logDate.isBefore(minDate) || logDate.isAfter(endPoint))) return false;
          return true;
        }).toList();

        if (allLogs.isEmpty) {
          return Container(
            height: 200,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: Text('No progress data yet', style: TextStyle(color: Colors.grey)),
            ),
          );
        }

        final oldestLogDate = DateTime(allLogs.first.date.year, allLogs.first.date.month, allLogs.first.date.day);
        DateTime chartStart;
        if (_selectedRange == 'All') {
          chartStart = oldestLogDate;
        } else {
          chartStart = minDate ?? oldestLogDate;
        }

        final firstTime = chartStart.millisecondsSinceEpoch;
        const msPerDay = 24 * 60 * 60 * 1000;

        double maxX = (_selectedRange == 'All')
            ? (today.millisecondsSinceEpoch - firstTime) / msPerDay
            : (endPoint.millisecondsSinceEpoch - firstTime) / msPerDay;
        if (maxX <= 0) maxX = 7.0;

        List<FlSpot> spots = [];
        for (var log in filteredLogs) {
          final logDate = DateTime(log.date.year, log.date.month, log.date.day);
          final x = (logDate.millisecondsSinceEpoch - firstTime) / msPerDay;
          int totalReps = log.sets.fold(0, (sum, s) => sum + s.reps);
          if (x >= 0 && x <= maxX) {
            spots.add(FlSpot(x.toDouble(), totalReps.toDouble()));
          }
        }

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
                            reservedSize: 35,
                            getTitlesWidget: (value, meta) => Text(
                              value.toInt().toString(),
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
                          color: Theme.of(context).colorScheme.primary,
                          barWidth: 3,
                          isStrokeCapRound: true,
                          dotData: FlDotData(
                            show: true,
                            getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                              radius: 4,
                              color: Theme.of(context).colorScheme.primary,
                              strokeWidth: 2,
                              strokeColor: Theme.of(context).scaffoldBackgroundColor,
                            ),
                          ),
                          belowBarData: BarAreaData(
                            show: true,
                            gradient: LinearGradient(
                              colors: [
                                Theme.of(context).colorScheme.primary.withOpacity(0.3),
                                Theme.of(context).colorScheme.primary.withOpacity(0.0),
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
      },
    );
  }
}
