import 'package:flutter/material.dart';
import 'package:lift/widgets/exercise_timer.dart';
import 'package:flutter/cupertino.dart';
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
  bool _showDetails = false;
  late TextEditingController _notesController;

  @override
  void initState() {
    super.initState();
    _notesController = TextEditingController(text: widget.exercise.notes);
    _loadLog();
  }

  @override
  void dispose() {
    if (widget.exercise.notes != _notesController.text) {
      widget.exercise.notes = _notesController.text;
      widget.exercise.save();
    }
    _notesController.dispose();
    super.dispose();
  }

  void _loadLog() {
    final provider = context.read<WorkoutProvider>();
    final log = provider.getLog(
      widget.exercise.id,
      widget.workout.id,
      _selectedDate,
    );
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
        title: GestureDetector(
          onTap: () => setState(() => _showDetails = !_showDetails),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.exercise.gifAsset != null)
                Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Image.asset(
                      widget.exercise.gifAsset!,
                      width: 32,
                      height: 32,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              Flexible(
                child: Text(
                  widget.exercise.name,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                _showDetails ? Icons.expand_less : Icons.expand_more,
                size: 16,
              ),
            ],
          ),
        ),
        actions: const [ExerciseTimer(), SizedBox(width: 8)],
      ),
      body: Column(
        children: [
          _buildDateSwitcher(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildExerciseDetails(),
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
          bottom: BorderSide(
            color: Theme.of(context).dividerColor.withOpacity(0.1),
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () =>
                _updateDate(_selectedDate.subtract(const Duration(days: 1))),
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
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  isToday ? 'Today' : 'Change Date',
                  style: TextStyle(
                    color: isToday
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey,
                    fontSize: 12,
                    fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () =>
                _updateDate(_selectedDate.add(const Duration(days: 1))),
          ),
        ],
      ),
    );
  }

  Widget _buildExerciseDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Notes Section
        Container(
          padding: const EdgeInsets.only(bottom: 16),
          child: TextField(
            controller: _notesController,
            maxLines: null,
            decoration: InputDecoration(
              labelText: 'Notes',
              hintText: 'Add notes for this exercise...',
              prefixIcon: const Icon(Icons.note_alt_outlined),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onChanged: (value) {
              widget.exercise.notes = value;
              widget.exercise.save();
            },
          ),
        ),

        if (_showDetails) ...[
          // GIF if available
          if (widget.exercise.gifAsset != null)
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset(
                  widget.exercise.gifAsset!,
                  height: 200,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    height: 200,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceVariant,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.fitness_center,
                      color: Theme.of(context).colorScheme.primary,
                      size: 60,
                    ),
                  ),
                ),
              ),
            ),

          if (widget.exercise.gifAsset != null) const SizedBox(height: 16),

          // Description
          if (widget.exercise.description != null &&
              widget.exercise.description!.isNotEmpty) ...[
            Text(
              widget.exercise.description!,
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Target Muscles
          if (widget.exercise.targetMuscles.isNotEmpty)
            _buildInfoSection(
              'Target Muscles',
              Icons.adjust,
              widget.exercise.targetMuscles,
            ),

          // Secondary Muscles
          if (widget.exercise.secondaryMuscles.isNotEmpty)
            _buildInfoSection(
              'Secondary Muscles',
              Icons.fitness_center,
              widget.exercise.secondaryMuscles,
            ),

          // Equipment
          if (widget.exercise.equipment.isNotEmpty)
            _buildInfoSection(
              'Equipment',
              Icons.sports_gymnastics,
              widget.exercise.equipment,
            ),

          // Body Parts
          if (widget.exercise.bodyParts.isNotEmpty)
            _buildInfoSection(
              'Body Parts',
              Icons.accessibility,
              widget.exercise.bodyParts,
            ),

          // Instructions
          if (widget.exercise.instructions.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.edit,
                  size: 20,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Instructions',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: TextEditingController(
                  text: widget.exercise.instructionsAsText,
                ),
                maxLines: null,
                keyboardType: TextInputType.multiline,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Theme.of(context).dividerColor.withOpacity(0.1),
                    ),
                  ),
                  filled: true,
                  fillColor: Theme.of(
                    context,
                  ).colorScheme.surfaceVariant.withOpacity(0.3),
                ),
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
                readOnly: true,
              ),
            ),
          ],
        ],

        const Divider(height: 24),
      ],
    );
  }

  Widget _buildInfoSection(String title, IconData icon, List<String> items) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.adjust,
                size: 20,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 28),
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: items.map((item) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    item,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                );
              }).toList(),
            ),
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
          Expanded(
            flex: 1,
            child: Text(
              'SET',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              'REPS',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              'WEIGHT (KG)',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(flex: 2, child: SizedBox()),
        ],
      ),
    );
  }

  void _showSetPicker(int index, ExerciseSet set) {
    int tempReps = set.reps;
    double tempWeight = set.weight;

    // Default to last session values if current is zero
    if (tempReps == 0 && _lastLog != null && _lastLog!.sets.length > index) {
      tempReps = _lastLog!.sets[index].reps;
    }
    if (tempWeight == 0 && _lastLog != null && _lastLog!.sets.length > index) {
      tempWeight = _lastLog!.sets[index].weight;
    }

    int weightInt = tempWeight.floor();
    int weightFractionIdx = [
      0,
      25,
      50,
      75,
    ].indexOf(((tempWeight - weightInt) * 100).round()).clamp(0, 3);

    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          height: 350,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  Text(
                    'Set ${index + 1}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        set.reps = tempReps;
                        set.weight = tempWeight;
                        set.completed = true;
                        _saveLog();
                      });
                      Navigator.pop(context);
                    },
                    child: const Text(
                      'Done',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              Expanded(
                child: Row(
                  children: [
                    // Reps Wheel
                    Expanded(
                      flex: 1,
                      child: Column(
                        children: [
                          const Text(
                            'REPS',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Expanded(
                            child: CupertinoPicker(
                              itemExtent: 40,
                              scrollController: FixedExtentScrollController(
                                initialItem: tempReps,
                              ),
                              onSelectedItemChanged: (val) => tempReps = val,
                              children: List.generate(
                                101,
                                (i) => Center(child: Text('$i')),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const VerticalDivider(),
                    // Weight Double Wheel (Integer + Fraction)
                    Expanded(
                      flex: 2,
                      child: Column(
                        children: [
                          const Text(
                            'WEIGHT (KG)',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Expanded(
                            child: Row(
                              children: [
                                Expanded(
                                  child: CupertinoPicker(
                                    itemExtent: 40,
                                    scrollController:
                                        FixedExtentScrollController(
                                          initialItem: weightInt,
                                        ),
                                    onSelectedItemChanged: (val) {
                                      weightInt = val;
                                      tempWeight =
                                          weightInt +
                                          ([0, 25, 50, 75][weightFractionIdx] /
                                              100.0);
                                    },
                                    children: List.generate(
                                      501,
                                      (i) => Center(child: Text('$i')),
                                    ),
                                  ),
                                ),
                                const Text(
                                  '.',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Expanded(
                                  child: CupertinoPicker(
                                    itemExtent: 40,
                                    scrollController:
                                        FixedExtentScrollController(
                                          initialItem: weightFractionIdx,
                                        ),
                                    onSelectedItemChanged: (idx) {
                                      weightFractionIdx = idx;
                                      tempWeight =
                                          weightInt +
                                          ([0, 25, 50, 75][idx] / 100.0);
                                    },
                                    children: [0, 25, 50, 75]
                                        .map(
                                          (f) => Center(
                                            child: Text(
                                              f.toString().padLeft(2, '0'),
                                            ),
                                          ),
                                        )
                                        .toList(),
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
            ],
          ),
        );
      },
    );
  }

  Widget _buildSetRow(int index, ExerciseSet set) {
    String weightDisplay = (set.weight == 0 && !set.completed)
        ? '-'
        : set.weight.toString();
    String repsDisplay = (set.reps == 0 && !set.completed)
        ? '-'
        : set.reps.toString();

    String weightPlaceholder = '';
    String repsPlaceholder = '';
    if (set.weight == 0 &&
        !set.completed &&
        _lastLog != null &&
        _lastLog!.sets.length > index) {
      weightPlaceholder = '(${_lastLog!.sets[index].weight})';
    }
    if (set.reps == 0 &&
        !set.completed &&
        _lastLog != null &&
        _lastLog!.sets.length > index) {
      repsPlaceholder = '(${_lastLog!.sets[index].reps})';
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
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: InkWell(
          onTap: () => _showSetPicker(index, set),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
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
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        repsDisplay,
                        style: TextStyle(
                          fontSize: 16,
                          color: (set.reps == 0 && !set.completed)
                              ? Colors.grey
                              : null,
                          fontWeight: (set.reps == 0 && !set.completed)
                              ? FontWeight.normal
                              : FontWeight.bold,
                        ),
                      ),
                      if (repsPlaceholder.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: Text(
                            repsPlaceholder,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        weightDisplay,
                        style: TextStyle(
                          fontSize: 16,
                          color: (set.weight == 0 && !set.completed)
                              ? Colors.grey
                              : null,
                          fontWeight: (set.weight == 0 && !set.completed)
                              ? FontWeight.normal
                              : FontWeight.bold,
                        ),
                      ),
                      if (weightPlaceholder.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: Text(
                            weightPlaceholder,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Center(
                    child: IconButton(
                      icon: const Icon(
                        Icons.refresh,
                        size: 20,
                        color: Colors.grey,
                      ),
                      onPressed: () {
                        setState(() {
                          set.reps = 0;
                          set.weight = 0;
                          set.completed = false;
                          _saveLog();
                        });
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
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
            final lastSet = _currentLog!.sets.isNotEmpty
                ? _currentLog!.sets.last
                : null;
            _currentLog!.sets.add(
              ExerciseSet(
                weight: lastSet?.weight ?? 0,
                reps: lastSet?.reps ?? 0,
              ),
            );
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
        final logs = provider.getLogsForExercise(
          widget.exercise.id,
          widget.workout.id,
        );
        final points = logs.where((l) => l.validSetCount > 0).map((l) {
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
