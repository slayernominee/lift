import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:lift/models/workout.dart';
import 'package:lift/models/exercise.dart';
import 'package:lift/providers/workout_provider.dart';
import 'package:lift/screens/exercise_tracking_screen.dart';
import 'package:lift/screens/exercises_screen.dart';

class WorkoutDetailScreen extends StatefulWidget {
  final Workout workout;

  const WorkoutDetailScreen({super.key, required this.workout});

  @override
  State<WorkoutDetailScreen> createState() => _WorkoutDetailScreenState();
}

class _WorkoutDetailScreenState extends State<WorkoutDetailScreen> {
  bool _isReorderMode = false;

  void _showAddExerciseScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ExercisesScreen(
          onSelect: (exercise) {
            setState(() {
              widget.workout.exercises.add(
                WorkoutExercise.create(exerciseId: exercise.id),
              );
              context.read<WorkoutProvider>().updateWorkout(widget.workout);
            });
            Navigator.pop(context);
          },
        ),
      ),
    );
  }

  void _editSets(WorkoutExercise workoutExercise) {
    final controller = TextEditingController(
      text: workoutExercise.targetSets.toString(),
    );
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Target Sets'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Number of sets'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final sets = int.tryParse(controller.text);
              if (sets != null && sets > 0) {
                setState(() {
                  workoutExercise.targetSets = sets;
                  context.read<WorkoutProvider>().updateWorkout(widget.workout);
                });
                Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showRenameWorkoutDialog() {
    final controller = TextEditingController(text: widget.workout.name);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Workout'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Workout Name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                setState(() {
                  widget.workout.name = controller.text;
                  context.read<WorkoutProvider>().updateWorkout(widget.workout);
                });
                Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _exportWorkout(BuildContext context) async {
    final provider = context.read<WorkoutProvider>();
    final result = await provider.exportWorkout(widget.workout);

    if (context.mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Export Result'),
          content: Text(result),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  void _duplicateWorkout(BuildContext context) {
    final controller = TextEditingController(
      text: '${widget.workout.name} (copy)',
    );
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Duplicate Workout'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'New workout name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                final provider = context.read<WorkoutProvider>();
                final newWorkout = Workout.create(name: controller.text);

                // Copy exercises with new IDs
                newWorkout.exercises.addAll(
                  widget.workout.exercises.map(
                    (e) => WorkoutExercise(
                      id: const Uuid().v4(),
                      exerciseId: e.exerciseId,
                      targetSets: e.targetSets,
                    ),
                  ),
                );

                provider.addWorkout(newWorkout);
                Navigator.pop(context);
                Navigator.pop(context); // Go back to workouts list
              }
            },
            child: const Text('Duplicate'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onTap: _showRenameWorkoutDialog,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  widget.workout.name,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.edit, size: 16, color: Colors.grey),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(_isReorderMode ? Icons.check : Icons.swap_vert),
            color: _isReorderMode
                ? Theme.of(context).colorScheme.primary
                : null,
            onPressed: () {
              setState(() {
                _isReorderMode = !_isReorderMode;
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showAddExerciseScreen,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) async {
              switch (value) {
                case 'export':
                  await _exportWorkout(context);
                  break;
                case 'duplicate':
                  _duplicateWorkout(context);
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'export',
                child: Row(
                  children: [
                    Icon(Icons.file_download, color: Colors.blue),
                    SizedBox(width: 12),
                    Text('Export Workout'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'duplicate',
                child: Row(
                  children: [
                    Icon(Icons.content_copy),
                    SizedBox(width: 12),
                    Text('Duplicate Workout'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Consumer<WorkoutProvider>(
        builder: (context, provider, child) {
          if (widget.workout.exercises.isEmpty) {
            return const Center(
              child: Text('No exercises in this workout yet.'),
            );
          }

          if (_isReorderMode) {
            return ReorderableListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: widget.workout.exercises.length,
              onReorder: (oldIndex, newIndex) {
                provider.reorderWorkoutExercise(
                  widget.workout,
                  oldIndex,
                  newIndex,
                );
              },
              itemBuilder: (context, index) {
                final workoutExercise = widget.workout.exercises[index];
                final exercise = provider.getExerciseById(
                  workoutExercise.exerciseId,
                );
                return _buildExerciseCard(
                  workoutExercise,
                  exercise,
                  provider,
                  index,
                );
              },
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: widget.workout.exercises.length,
            itemBuilder: (context, index) {
              final workoutExercise = widget.workout.exercises[index];
              final exercise = provider.getExerciseById(
                workoutExercise.exerciseId,
              );
              return _buildExerciseCard(
                workoutExercise,
                exercise,
                provider,
                index,
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildExerciseCard(
    WorkoutExercise workoutExercise,
    Exercise? exercise,
    WorkoutProvider provider,
    int index,
  ) {
    return Dismissible(
      key: ValueKey(workoutExercise.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.redAccent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (direction) async {
        return await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Remove Exercise'),
            content: Text(
              'Are you sure you want to remove "${exercise?.name ?? 'this exercise'}" from the workout?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  'Remove',
                  style: TextStyle(color: Colors.redAccent),
                ),
              ),
            ],
          ),
        );
      },
      onDismissed: (direction) {
        setState(() {
          widget.workout.exercises.removeAt(index);
          provider.updateWorkout(widget.workout);
        });
      },
      child: Card(
        key: ValueKey(workoutExercise.id),
        margin: const EdgeInsets.only(bottom: 12),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
            width: 1,
          ),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
          title: Text(
            exercise?.name ?? 'Unknown Exercise',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => _editSets(workoutExercise),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${workoutExercise.targetSets} sets',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    if (exercise?.targetMuscles.isNotEmpty ?? false) ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          exercise!.targetMuscles.join(', '),
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
                if (exercise?.description != null &&
                    exercise!.description!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    exercise.description!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_isReorderMode)
                const Icon(Icons.drag_handle, color: Colors.grey)
              else
                Icon(
                  Icons.chevron_right,
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
                ),
            ],
          ),
          onTap: () {
            if (_isReorderMode) return;
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ExerciseTrackingScreen(
                  workout: widget.workout,
                  workoutExercise: workoutExercise,
                  exercise: exercise!,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
