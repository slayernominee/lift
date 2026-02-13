import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:lift/models/log.dart';
import 'package:lift/providers/workout_provider.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);

  void _updateMonth(DateTime date) {
    setState(() {
      _selectedMonth = DateTime(date.year, date.month);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Statistics')),
      body: Column(
        children: [
          _buildMonthSwitcher(),
          Expanded(child: _buildStatsContent()),
        ],
      ),
    );
  }

  Widget _buildMonthSwitcher() {
    final now = DateTime.now();
    final isCurrentMonth =
        _selectedMonth.year == now.year && _selectedMonth.month == now.month;

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
            onPressed: () => _updateMonth(
              DateTime(_selectedMonth.year, _selectedMonth.month - 1),
            ),
          ),
          InkWell(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _selectedMonth,
                firstDate: DateTime(2020),
                lastDate: DateTime(2101),
              );
              if (picked != null) _updateMonth(picked);
            },
            child: Column(
              children: [
                Text(
                  DateFormat('MMMM yyyy').format(_selectedMonth),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  isCurrentMonth ? 'Current Month' : 'Change Month',
                  style: TextStyle(
                    color: isCurrentMonth
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey,
                    fontSize: 12,
                    fontWeight: isCurrentMonth
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () => _updateMonth(
              DateTime(_selectedMonth.year, _selectedMonth.month + 1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsContent() {
    return Consumer<WorkoutProvider>(
      builder: (context, provider, child) {
        final logs = provider.logs;

        // Filter logs for selected month
        final monthlyLogs = logs.where((log) {
          return log.date.year == _selectedMonth.year &&
              log.date.month == _selectedMonth.month;
        }).toList();

        // Stats calculation
        int totalSets = 0;
        int completedExercises = 0;
        final workoutsAttempted = <String, Set<DateTime>>{};
        final setsPerExercise = <String, int>{};
        final completedExercisesPerId = <String, int>{};
        final completedWorkoutsPerId = <String, int>{};
        final trainingDays = <int>{};

        final workoutMap = {for (var w in provider.workouts) w.id: w};

        for (final log in monthlyLogs) {
          final validSets = log.validSetCount;
          totalSets += validSets;
          trainingDays.add(log.date.day);

          if (validSets > 0) {
            setsPerExercise[log.exerciseId] =
                (setsPerExercise[log.exerciseId] ?? 0) + validSets;
          }

          final workout = workoutMap[log.workoutId];
          if (workout != null) {
            try {
              final workoutExercise = workout.exercises.firstWhere(
                (e) => e.exerciseId == log.exerciseId,
              );
              if (validSets >= workoutExercise.targetSets) {
                completedExercises++;
                completedExercisesPerId[log.exerciseId] =
                    (completedExercisesPerId[log.exerciseId] ?? 0) + 1;
              }
            } catch (_) {}
          }

          if (!workoutsAttempted.containsKey(log.workoutId)) {
            workoutsAttempted[log.workoutId] = <DateTime>{};
          }
          final dateKey = DateTime(log.date.year, log.date.month, log.date.day);
          workoutsAttempted[log.workoutId]!.add(dateKey);
        }

        int completedWorkouts = 0;
        workoutsAttempted.forEach((workoutId, dates) {
          for (final date in dates) {
            if (provider.isWorkoutCompleted(workoutId, date)) {
              completedWorkouts++;
              completedWorkoutsPerId[workoutId] =
                  (completedWorkoutsPerId[workoutId] ?? 0) + 1;
            }
          }
        });

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _buildMonthMinimap(trainingDays),
              const SizedBox(height: 16),
              _buildStatCard(
                title: 'Finished Workouts',
                value: completedWorkouts.toString(),
                icon: Icons.check_circle,
                color: Colors.green,
                children: _buildTopList(
                  completedWorkoutsPerId,
                  (id) => workoutMap[id]?.name ?? 'Unknown',
                ),
              ),
              const SizedBox(height: 12),
              _buildStatCard(
                title: 'Completed Exercises',
                value: completedExercises.toString(),
                icon: Icons.fitness_center,
                color: Colors.orange,
                children: _buildTopList(
                  completedExercisesPerId,
                  (id) => provider.getExerciseById(id)?.name ?? 'Unknown',
                ),
              ),
              const SizedBox(height: 12),
              _buildStatCard(
                title: 'Total Sets',
                value: totalSets.toString(),
                icon: Icons.layers,
                color: Colors.blue,
                children: _buildTopList(
                  setsPerExercise,
                  (id) => provider.getExerciseById(id)?.name ?? 'Unknown',
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMonthMinimap(Set<int> trainingDays) {
    final daysInMonth = DateTime(
      _selectedMonth.year,
      _selectedMonth.month + 1,
      0,
    ).day;
    final firstDayWeekday = DateTime(
      _selectedMonth.year,
      _selectedMonth.month,
      1,
    ).weekday;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Theme.of(context).dividerColor.withOpacity(0.1),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              'Training Days',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: ['M', 'T', 'W', 'T', 'F', 'S', 'S'].map((day) {
                return Expanded(
                  child: Center(
                    child: Text(
                      day,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisSpacing: 4,
                crossAxisSpacing: 4,
              ),
              itemCount: daysInMonth + (firstDayWeekday - 1),
              itemBuilder: (context, index) {
                if (index < firstDayWeekday - 1) {
                  return const SizedBox.shrink();
                }
                final day = index - (firstDayWeekday - 2);
                final isTrained = trainingDays.contains(day);
                return Container(
                  decoration: BoxDecoration(
                    color: isTrained
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(
                            context,
                          ).colorScheme.surfaceVariant.withOpacity(0.3),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      day.toString(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: isTrained
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: isTrained ? Colors.white : Colors.grey,
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    List<Widget>? children,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Theme.of(context).dividerColor.withOpacity(0.1),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (children != null && children.isNotEmpty) ...[
              const SizedBox(height: 16),
              Divider(color: Theme.of(context).dividerColor.withOpacity(0.1)),
              const SizedBox(height: 8),
              ...children,
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _buildTopList(
    Map<String, int> counts,
    String Function(String id) getName,
  ) {
    if (counts.isEmpty) return [];
    final sortedEntries = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top3 = sortedEntries.take(3);
    return top3.map((entry) {
      final name = getName(entry.key);
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                name,
                style: const TextStyle(fontSize: 13),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${entry.value}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      );
    }).toList();
  }
}
