import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:lift/providers/workout_provider.dart';
import 'package:lift/models/exercise.dart';
import 'package:lift/widgets/multi_select_widgets.dart';

class ExercisesScreen extends StatefulWidget {
  final void Function(Exercise)? onSelect;

  const ExercisesScreen({super.key, this.onSelect});

  @override
  State<ExercisesScreen> createState() => _ExercisesScreenState();
}

class _ExercisesScreenState extends State<ExercisesScreen> {
  String _searchQuery = '';
  String? _selectedMuscleFilter;

  // List data from JSON files
  List<String> get _allMuscles => context.read<WorkoutProvider>().muscles;
  List<String> get _allBodyParts => context.read<WorkoutProvider>().bodyParts;
  List<String> get _allEquipment => context.read<WorkoutProvider>().equipment;
  bool get _isLoadingData => false;

  @override
  void initState() {
    super.initState();
  }

  void _showAddExerciseDialog(BuildContext context) {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    final gifAssetController = TextEditingController();
    List<String> selectedTargetMuscles = [];
    List<String> selectedEquipment = [];
    List<String> selectedBodyParts = [];
    List<String> selectedSecondaryMuscles = [];
    List<String> instructions = [];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('New Exercise'),
          content: SingleChildScrollView(
            child: Column(
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
                  maxLines: 2,
                  decoration: const InputDecoration(
                    hintText: 'Description (optional)',
                  ),
                ),
                const SizedBox(height: 8),
                MultiSelectField(
                  label: 'Target Muscles',
                  selectedItems: selectedTargetMuscles,
                  allItems: _allMuscles,
                  isLoading: _isLoadingData,
                  onSelectionChanged: (items) {
                    setState(() {
                      selectedTargetMuscles = items;
                    });
                  },
                ),
                const SizedBox(height: 8),
                MultiSelectField(
                  label: 'Equipment',
                  selectedItems: selectedEquipment,
                  allItems: _allEquipment,
                  isLoading: _isLoadingData,
                  onSelectionChanged: (items) {
                    setState(() {
                      selectedEquipment = items;
                    });
                  },
                ),
                const SizedBox(height: 8),
                MultiSelectField(
                  label: 'Body Parts',
                  selectedItems: selectedBodyParts,
                  allItems: _allBodyParts,
                  isLoading: _isLoadingData,
                  onSelectionChanged: (items) {
                    setState(() {
                      selectedBodyParts = items;
                    });
                  },
                ),
                const SizedBox(height: 8),
                MultiSelectField(
                  label: 'Secondary Muscles',
                  selectedItems: selectedSecondaryMuscles,
                  allItems: _allMuscles,
                  isLoading: _isLoadingData,
                  onSelectionChanged: (items) {
                    setState(() {
                      selectedSecondaryMuscles = items;
                    });
                  },
                ),
                const SizedBox(height: 8),
                InstructionsField(
                  instructions: instructions,
                  onChanged: (newInstructions) {
                    setState(() {
                      instructions.clear();
                      instructions.addAll(newInstructions);
                    });
                  },
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: gifAssetController,
                  decoration: const InputDecoration(
                    hintText: 'GIF Asset Path (optional)',
                  ),
                ),
              ],
            ),
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
                    targetMuscles: selectedTargetMuscles.isEmpty
                        ? ['Other']
                        : selectedTargetMuscles,
                    equipment: selectedEquipment,
                    bodyParts: selectedBodyParts,
                    secondaryMuscles: selectedSecondaryMuscles,
                    instructions: instructions,
                    gifAsset: gifAssetController.text.isEmpty
                        ? null
                        : gifAssetController.text,
                  );
                  context.read<WorkoutProvider>().addExercise(exercise);
                  Navigator.pop(context);
                }
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditExerciseDialog(BuildContext context, Exercise exercise) {
    final nameController = TextEditingController(text: exercise.name);
    final descriptionController = TextEditingController(
      text: exercise.description ?? '',
    );
    final gifAssetController = TextEditingController(
      text: exercise.gifAsset ?? '',
    );
    List<String> selectedTargetMuscles = List.from(exercise.targetMuscles);
    List<String> selectedEquipment = List.from(exercise.equipment);
    List<String> selectedBodyParts = List.from(exercise.bodyParts);
    List<String> selectedSecondaryMuscles = List.from(
      exercise.secondaryMuscles,
    );
    List<String> instructions = List.from(exercise.instructions);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Edit Exercise'),
          content: SingleChildScrollView(
            child: Column(
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
                  maxLines: 2,
                  decoration: const InputDecoration(hintText: 'Description'),
                ),
                const SizedBox(height: 8),
                MultiSelectField(
                  label: 'Target Muscles',
                  selectedItems: selectedTargetMuscles,
                  allItems: _allMuscles,
                  isLoading: _isLoadingData,
                  onSelectionChanged: (items) {
                    setState(() {
                      selectedTargetMuscles = items;
                    });
                  },
                ),
                const SizedBox(height: 8),
                MultiSelectField(
                  label: 'Equipment',
                  selectedItems: selectedEquipment,
                  allItems: _allEquipment,
                  isLoading: _isLoadingData,
                  onSelectionChanged: (items) {
                    setState(() {
                      selectedEquipment = items;
                    });
                  },
                ),
                const SizedBox(height: 8),
                MultiSelectField(
                  label: 'Body Parts',
                  selectedItems: selectedBodyParts,
                  allItems: _allBodyParts,
                  isLoading: _isLoadingData,
                  onSelectionChanged: (items) {
                    setState(() {
                      selectedBodyParts = items;
                    });
                  },
                ),
                const SizedBox(height: 8),
                MultiSelectField(
                  label: 'Secondary Muscles',
                  selectedItems: selectedSecondaryMuscles,
                  allItems: _allMuscles,
                  isLoading: _isLoadingData,
                  onSelectionChanged: (items) {
                    setState(() {
                      selectedSecondaryMuscles = items;
                    });
                  },
                ),
                const SizedBox(height: 8),
                InstructionsField(
                  instructions: instructions,
                  onChanged: (newInstructions) {
                    setState(() {
                      instructions.clear();
                      instructions.addAll(newInstructions);
                    });
                  },
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: gifAssetController,
                  decoration: const InputDecoration(hintText: 'GIF Asset Path'),
                ),
              ],
            ),
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
                  exercise.targetMuscles = selectedTargetMuscles.isEmpty
                      ? ['Other']
                      : selectedTargetMuscles;
                  exercise.equipment = selectedEquipment;
                  exercise.bodyParts = selectedBodyParts;
                  exercise.secondaryMuscles = selectedSecondaryMuscles;
                  exercise.instructions = instructions;
                  exercise.gifAsset = gifAssetController.text.isEmpty
                      ? null
                      : gifAssetController.text;
                  exercise.save();
                  setState(() {});
                  Navigator.pop(context);
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
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
          final availableMuscles = provider.exercises
              .map((e) => e.primaryTargetMuscle)
              .toSet();

          final exercises = provider.exercises.where((e) {
            final matchesFilter =
                _selectedMuscleFilter == null ||
                e.targetMuscles.contains(_selectedMuscleFilter);

            if (!matchesFilter) return false;

            return e.name.toLowerCase().contains(_searchQuery) ||
                e.targetMuscles.any(
                  (m) => m.toLowerCase().contains(_searchQuery),
                ) ||
                e.equipment.any(
                  (eq) => eq.toLowerCase().contains(_searchQuery),
                ) ||
                e.bodyParts.any(
                  (bp) => bp.toLowerCase().contains(_searchQuery),
                ) ||
                e.secondaryMuscles.any(
                  (sm) => sm.toLowerCase().contains(_searchQuery),
                );
          }).toList();

          // Group exercises by primary target muscle
          final groupedExercises = <String, List<Exercise>>{};
          for (var exercise in exercises) {
            final group = exercise.primaryTargetMuscle;
            groupedExercises.putIfAbsent(group, () => []).add(exercise);
          }

          final sortedKeys = groupedExercises.keys.toList()..sort();

          // Flatten the list for lazy loading
          final flatList = <dynamic>[];
          for (final key in sortedKeys) {
            flatList.add(key); // Header
            final groupExercises = groupedExercises[key]!;
            groupExercises.sort((a, b) => a.name.compareTo(b.name));
            flatList.addAll(groupExercises);
          }

          return Column(
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    FilterChip(
                      label: const Text('All'),
                      selected: _selectedMuscleFilter == null,
                      onSelected: (selected) {
                        setState(() {
                          _selectedMuscleFilter = null;
                        });
                      },
                    ),
                    const SizedBox(width: 8),
                    ...provider.muscles
                        .where((m) => availableMuscles.contains(m))
                        .map((muscle) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FilterChip(
                              label: Text(muscle),
                              selected: _selectedMuscleFilter == muscle,
                              onSelected: (selected) {
                                setState(() {
                                  _selectedMuscleFilter = selected
                                      ? muscle
                                      : null;
                                });
                              },
                            ),
                          );
                        }),
                  ],
                ),
              ),
              Expanded(
                child: exercises.isEmpty
                    ? Center(
                        child: Text(
                          _searchQuery.isEmpty && _selectedMuscleFilter == null
                              ? 'No exercises found. Add some!'
                              : 'No exercises match your criteria.',
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.only(bottom: 80),
                        itemCount: flatList.length,
                        itemBuilder: (context, index) {
                          final item = flatList[index];

                          if (item is String) {
                            return Padding(
                              padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                              child: Text(
                                item.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            );
                          } else if (item is Exercise) {
                            final card = _ExerciseCard(
                              exercise: item,
                              onTap: () {
                                if (widget.onSelect != null) {
                                  widget.onSelect!(item);
                                } else {
                                  _showEditExerciseDialog(context, item);
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
                                key: Key(item.id),
                                direction: DismissDirection.endToStart,
                                background: Container(
                                  alignment: Alignment.centerRight,
                                  padding: const EdgeInsets.only(right: 20),
                                  decoration: BoxDecoration(
                                    color: Colors.redAccent,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.delete,
                                    color: Colors.white,
                                  ),
                                ),
                                confirmDismiss: (direction) async {
                                  return await showDialog(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text('Delete Exercise'),
                                      content: Text(
                                        'Are you sure you want to delete "${item.name}"?',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context, false),
                                          child: const Text('Cancel'),
                                        ),
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context, true),
                                          child: const Text(
                                            'Delete',
                                            style: TextStyle(
                                              color: Colors.redAccent,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                                onDismissed: (direction) {
                                  item.delete();
                                  setState(() {});
                                },
                                child: card,
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
              ),
            ],
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
        leading: exercise.gifAsset != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset(
                  exercise.gifAsset!,
                  width: 60,
                  height: 60,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceVariant,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.fitness_center,
                      color: Theme.of(context).colorScheme.primary,
                      size: 30,
                    ),
                  ),
                ),
              )
            : null,
        title: Text(
          exercise.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (exercise.targetMuscles.isNotEmpty)
              Text(
                exercise.targetMuscles.join(', '),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontSize: 12,
                ),
              ),
            if (exercise.equipment.isNotEmpty)
              Text(
                exercise.equipment.join(', '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.7),
                  fontSize: 11,
                ),
              ),
            if (exercise.description != null &&
                exercise.description!.isNotEmpty)
              Text(
                exercise.description!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 11,
                ),
              ),
          ],
        ),
        trailing: Icon(
          Icons.chevron_right,
          color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
        ),
      ),
    );
  }
}
