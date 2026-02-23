import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lift/models/workout.dart';
import 'package:lift/providers/workout_provider.dart';
import 'package:lift/screens/exercise_tracking_screen.dart';

class ExercisePager extends StatefulWidget {
  final Workout workout;
  final int initialIndex;

  const ExercisePager({
    super.key,
    required this.workout,
    required this.initialIndex,
  });

  @override
  State<ExercisePager> createState() => _ExercisePagerState();
}

class _ExercisePagerState extends State<ExercisePager> {
  late PageController _pageController;
  int _currentIndex = 0;
  bool _isNavigating = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _navigateToNext() {
    if (_isNavigating) return;
    if (_currentIndex < widget.workout.exercises.length - 1) {
      setState(() => _isNavigating = true);
      _pageController
          .nextPage(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          )
          .then((_) {
            if (mounted) setState(() => _isNavigating = false);
          });
    }
  }

  void _navigateToPrevious() {
    if (_isNavigating) return;
    if (_currentIndex > 0) {
      setState(() => _isNavigating = true);
      _pageController
          .previousPage(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          )
          .then((_) {
            if (mounted) setState(() => _isNavigating = false);
          });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Consumer<WorkoutProvider>(
        builder: (context, provider, child) {
          final workoutExercises = widget.workout.exercises;

          if (workoutExercises.isEmpty) {
            return const Center(child: Text('No exercises in this workout'));
          }

          return PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: workoutExercises.length,
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            itemBuilder: (context, index) {
              final workoutExercise = workoutExercises[index];
              final exercise = provider.getExerciseById(
                workoutExercise.exerciseId,
              );

              if (exercise == null) {
                return Center(
                  child: Text(
                    'Exercise not found',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                );
              }

              return ExerciseTrackingScreen(
                key: ValueKey(workoutExercise.id),
                workout: widget.workout,
                workoutExercise: workoutExercise,
                exercise: exercise,
                onOverscrollNext: _navigateToNext,
                onOverscrollPrevious: _navigateToPrevious,
              );
            },
          );
        },
      ),
    );
  }
}
