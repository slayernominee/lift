import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lift/providers/workout_provider.dart';
import 'package:lift/models/exercise.dart';

class ExercisesScreen extends StatefulWidget {
  const ExercisesScreen({super.key});

  @override
  State<ExercisesScreen> createState() => _ExercisesScreenState();
}

class _ExercisesScreenState extends State<ExercisesScreen> {
  String _searchQuery = '';

  void _showAddExerciseDialog(BuildContext context) {
    final nameController = TextEditingController();
    final muscleController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New Exercise'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Exercise Name (e.g. Bench Press)',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: muscleController,
              decoration: const InputDecoration(
                hintText: 'Muscle Group (e.g. Chest)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.isNotEmpty) {
                final exercise = Exercise.create(
                  name: nameController.text,
                  muscleGroup: muscleController.text.isEmpty ? null : muscleController.text,
                );
                context.read<WorkoutProvider>().addExercise(exercise);
                Navigator.pop(context);
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Exercise Pool'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search exercises...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
                contentPadding: EdgeInsets.zero,
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
            ),
          ),
        ),
      ),
      body: Consumer<WorkoutProvider>(
        builder: (context, provider, child) {
          final exercises = provider.exercises.where((e) {
            return e.name.toLowerCase().contains(_searchQuery) ||
                (e.muscleGroup?.toLowerCase().contains(_searchQuery) ?? false);
          }).toList();

          if (exercises.isEmpty && _searchQuery.isEmpty) {
            return const Center(
              child: Text('No exercises found. Add some!'),
            );
          }

          if (exercises.isEmpty && _searchQuery.isNotEmpty) {
            return const Center(
              child: Text('No exercises match your search.'),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: exercises.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final exercise = exercises[index];
              return Dismissible(
                key: Key(exercise.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  decoration: BoxDecoration(
                    color: Colors.redAccent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                confirmDismiss: (direction) async {
                  return await showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Delete Exercise'),
                      content: Text('Are you sure you want to delete "${exercise.name}"?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
                        ),
                      ],
                    ),
                  );
                },
                onDismissed: (direction) {
                  exercise.delete();
                  setState(() {});
                },
                child: _ExerciseCard(exercise: exercise),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddExerciseDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _ExerciseCard extends StatelessWidget {
  final Exercise exercise;

  const _ExerciseCard({required this.exercise});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Theme.of(context).dividerColor.withOpacity(0.1),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Text(
          exercise.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: exercise.muscleGroup != null
            ? Text(
                exercise.muscleGroup!,
                style: TextStyle(color: Theme.of(context).colorScheme.primary),
              )
            : null,
        trailing: Icon(
          Icons.chevron_right,
          color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
        ),
      ),
    );
  }
}
