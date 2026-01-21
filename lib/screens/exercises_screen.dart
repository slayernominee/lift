import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lift/providers/workout_provider.dart';
import 'package:lift/models/exercise.dart';

class ExercisesScreen extends StatefulWidget {
  final void Function(Exercise)? onSelect;

  const ExercisesScreen({super.key, this.onSelect});

  @override
  State<ExercisesScreen> createState() => _ExercisesScreenState();
}

class _ExercisesScreenState extends State<ExercisesScreen> {
  String _searchQuery = '';

  void _showAddExerciseDialog(BuildContext context) {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    final muscleController = TextEditingController();
    final equipmentController = TextEditingController();

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
              controller: descriptionController,
              decoration: const InputDecoration(
                hintText: 'Description (optional)',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: muscleController,
              decoration: const InputDecoration(
                hintText: 'Muscle Group (e.g. Chest)',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: equipmentController,
              decoration: const InputDecoration(
                hintText: 'Equipment (e.g. Dumbbells, Barbell)',
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
                  description: descriptionController.text.isEmpty
                      ? null
                      : descriptionController.text,
                  muscleGroup: muscleController.text.isEmpty
                      ? null
                      : muscleController.text,
                  equipment: equipmentController.text.isEmpty
                      ? null
                      : equipmentController.text,
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

  void _showEditExerciseDialog(BuildContext context, Exercise exercise) {
    final nameController = TextEditingController(text: exercise.name);
    final descriptionController = TextEditingController(
      text: exercise.description ?? '',
    );
    final muscleController = TextEditingController(
      text: exercise.muscleGroup ?? '',
    );
    final equipmentController = TextEditingController(
      text: exercise.equipment ?? '',
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Exercise'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              autofocus: true,
              decoration: const InputDecoration(hintText: 'Exercise Name'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(hintText: 'Description'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: muscleController,
              decoration: const InputDecoration(hintText: 'Muscle Group'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: equipmentController,
              decoration: const InputDecoration(hintText: 'Equipment'),
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
                exercise.name = nameController.text;
                exercise.description = descriptionController.text.isEmpty
                    ? null
                    : descriptionController.text;
                exercise.muscleGroup = muscleController.text.isEmpty
                    ? null
                    : muscleController.text;
                exercise.equipment = equipmentController.text.isEmpty
                    ? null
                    : equipmentController.text;
                exercise.save();
                setState(() {});
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
        title: Text(
          widget.onSelect != null ? 'Select Exercise' : 'Exercise Pool',
        ),
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
                fillColor: Theme.of(
                  context,
                ).colorScheme.surfaceVariant.withOpacity(0.5),
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
                (e.muscleGroup?.toLowerCase().contains(_searchQuery) ??
                    false) ||
                (e.equipment?.toLowerCase().contains(_searchQuery) ?? false);
          }).toList();

          if (exercises.isEmpty && _searchQuery.isEmpty) {
            return const Center(child: Text('No exercises found. Add some!'));
          }

          if (exercises.isEmpty && _searchQuery.isNotEmpty) {
            return const Center(child: Text('No exercises match your search.'));
          }

          // Group exercises by muscle group
          final groupedExercises = <String, List<Exercise>>{};
          for (var exercise in exercises) {
            final group = exercise.muscleGroup ?? 'Other';
            groupedExercises.putIfAbsent(group, () => []).add(exercise);
          }

          final sortedKeys = groupedExercises.keys.toList()..sort();

          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 80),
            itemCount: sortedKeys.length,
            itemBuilder: (context, index) {
              final group = sortedKeys[index];
              final groupExercises = groupedExercises[group]!;
              groupExercises.sort((a, b) => a.name.compareTo(b.name));

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                    child: Text(
                      group.toUpperCase(),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                  ...groupExercises.map((exercise) {
                    final card = _ExerciseCard(
                      exercise: exercise,
                      onTap: () {
                        if (widget.onSelect != null) {
                          widget.onSelect!(exercise);
                        } else {
                          _showEditExerciseDialog(context, exercise);
                        }
                      },
                    );

                    if (widget.onSelect != null) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        child: card,
                      );
                    }

                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      child: Dismissible(
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
                              content: Text(
                                'Are you sure you want to delete "${exercise.name}"?',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, false),
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text(
                                    'Delete',
                                    style: TextStyle(color: Colors.redAccent),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                        onDismissed: (direction) {
                          exercise.delete();
                          setState(() {});
                        },
                        child: card,
                      ),
                    );
                  }),
                ],
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'exercises_fab',
        onPressed: () => _showAddExerciseDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _ExerciseCard extends StatelessWidget {
  final Exercise exercise;
  final VoidCallback? onTap;

  const _ExerciseCard({required this.exercise, this.onTap});

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
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Text(
          exercise.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle:
            (exercise.muscleGroup != null ||
                exercise.equipment != null ||
                (exercise.description != null &&
                    exercise.description!.isNotEmpty))
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (exercise.muscleGroup != null)
                    Text(
                      exercise.muscleGroup!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  if (exercise.equipment != null)
                    Text(
                      exercise.equipment!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withOpacity(0.7),
                        fontSize: 12,
                      ),
                    ),
                  if (exercise.description != null &&
                      exercise.description!.isNotEmpty)
                    Text(
                      exercise.description!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                ],
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
