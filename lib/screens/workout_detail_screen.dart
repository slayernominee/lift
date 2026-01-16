import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lift/models/workout.dart';
import 'package:lift/models/exercise.dart';
import 'package:lift/providers/workout_provider.dart';
import 'package:lift/screens/exercise_tracking_screen.dart';

class WorkoutDetailScreen extends StatefulWidget {
  final Workout workout;

  const WorkoutDetailScreen({super.key, required this.workout});

  @override
  State<WorkoutDetailScreen> createState() => _WorkoutDetailScreenState();
}

class _WorkoutDetailScreenState extends State<WorkoutDetailScreen> {
  void _showAddExerciseBottomSheet() {
    final provider = context.read<WorkoutProvider>();
    final availableExercises = provider.exercises;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'Add Exercise',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: availableExercises.length,
                    itemBuilder: (context, index) {
                      final exercise = availableExercises[index];
                      return ListTile(
                        title: Text(exercise.name),
                        subtitle: Text(exercise.muscleGroup ?? ''),
                        onTap: () {
                          setState(() {
                            widget.workout.exercises.add(
                              WorkoutExercise.create(exerciseId: exercise.id),
                            );
                            provider.updateWorkout(widget.workout);
                          });
                          Navigator.pop(context);
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _editSets(WorkoutExercise workoutExercise) {
    final controller = TextEditingController(text: workoutExercise.targetSets.toString());
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onTap: _showRenameWorkoutDialog,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(widget.workout.name),
              const SizedBox(width: 8),
              const Icon(Icons.edit, size: 16, color: Colors.grey),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showAddExerciseBottomSheet,
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

          return ReorderableListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: widget.workout.exercises.length,
            onReorder: (oldIndex, newIndex) {
              provider.reorderWorkoutExercise(widget.workout, oldIndex, newIndex);
            },
            itemBuilder: (context, index) {
              final workoutExercise = widget.workout.exercises[index];
              final exercise = provider.getExerciseById(workoutExercise.exerciseId);

              return Card(
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
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
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
                        if (exercise?.muscleGroup != null) ...[
                          const SizedBox(width: 8),
                          Text(
                            exercise!.muscleGroup!,
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ],
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.settings_outlined, size: 20),
                        onPressed: () => _editSets(workoutExercise),
                        tooltip: 'Edit sets',
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                        onPressed: () {
                          setState(() {
                            widget.workout.exercises.removeAt(index);
                            provider.updateWorkout(widget.workout);
                          });
                        },
                        tooltip: 'Remove exercise',
                      ),
                      const Icon(Icons.drag_handle, color: Colors.grey),
                    ],
                  ),
                  onTap: () {
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
              );
            },
          );
        },
      ),
    );
  }
}
