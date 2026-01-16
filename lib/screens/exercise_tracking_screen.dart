import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:lift/models/exercise.dart';
import 'package:lift/models/workout.dart';
import 'package:lift/models/log.dart';
import 'package:lift/providers/workout_provider.dart';
import 'package:lift/widgets/timeline_chart.dart';

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
                _buildHistoryChart(),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
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

  Widget _buildHistoryChart() {
    return Consumer<WorkoutProvider>(
      builder: (context, provider, child) {
        final logs = provider.getLogsForExercise(widget.exercise.id, widget.workout.id);
        final points = logs.where((l) => l.sets.isNotEmpty).map((l) {
          int totalReps = l.sets.fold(0, (sum, s) => sum + s.reps);
          return ChartDataPoint(date: l.date, value: totalReps.toDouble());
        }).toList();

        return TimelineChart(
          points: points,
          label: 'Repetition History',
          subLabel: 'Total reps per session',
        );
      },
    );
  }
}
