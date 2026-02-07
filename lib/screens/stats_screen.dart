import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:lift/providers/workout_provider.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  DateTime _selectedMonth = DateTime.now();

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

        // Calculate stats
        int totalSets = 0;
        int completedExercises = 0;
        final workoutsAttempted = <String, Set<DateTime>>{};

        // Cache workouts for faster lookup
        final workoutMap = {for (var w in provider.workouts) w.id: w};

        for (final log in monthlyLogs) {
          final validSets = log.sets.where((s) => s.reps > 0).length;
          totalSets += validSets;

          // Check completed exercises
          final workout = workoutMap[log.workoutId];
          if (workout != null) {
            try {
              final workoutExercise = workout.exercises.firstWhere(
                (e) => e.exerciseId == log.exerciseId,
              );
              if (validSets >= workoutExercise.targetSets) {
                completedExercises++;
              }
            } catch (_) {
              // Exercise might have been removed from workout
            }
          }

          // Track unique workout days
          if (!workoutsAttempted.containsKey(log.workoutId)) {
            workoutsAttempted[log.workoutId] = <DateTime>{};
          }
          final dateKey = DateTime(log.date.year, log.date.month, log.date.day);
          workoutsAttempted[log.workoutId]!.add(dateKey);
        }

        // Calculate completed workouts
        int completedWorkouts = 0;
        workoutsAttempted.forEach((workoutId, dates) {
          for (final date in dates) {
            if (provider.isWorkoutCompleted(workoutId, date)) {
              completedWorkouts++;
            }
          }
        });

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _buildStatCard(
                title: 'Total Sets',
                value: totalSets.toString(),
                icon: Icons.layers,
                color: Colors.blue,
              ),
              const SizedBox(height: 12),
              _buildStatCard(
                title: 'Completed Exercises',
                value: completedExercises.toString(),
                icon: Icons.fitness_center,
                color: Colors.orange,
              ),
              const SizedBox(height: 12),
              _buildStatCard(
                title: 'Finished Workouts',
                value: completedWorkouts.toString(),
                icon: Icons.check_circle,
                color: Colors.green,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
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
        child: Row(
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
      ),
    );
  }
}
