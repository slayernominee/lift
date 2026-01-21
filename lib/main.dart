import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'package:lift/models/exercise.dart';
import 'package:lift/models/workout.dart';

import 'package:lift/models/weight.dart';
import 'package:lift/providers/workout_provider.dart';
import 'package:lift/screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive
  await Hive.initFlutter();

  // Database Migration for version 1.4.0 - MUST be done before registering adapters
  await _migrateDatabase();

  // Register Hive Adapters
  Hive.registerAdapter(ExerciseAdapter());
  Hive.registerAdapter(WorkoutAdapter());
  Hive.registerAdapter(WorkoutExerciseAdapter());
  Hive.registerAdapter(WeightEntryAdapter());

  // Open Hive Boxes
  await Hive.openBox<Exercise>('exercises');
  await Hive.openBox<Workout>('workouts');
  await Hive.openBox<WeightEntry>('weights');
  runApp(
    MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => WorkoutProvider())],
      child: const LiftApp(),
    ),
  );
}

Future<void> _migrateDatabase() async {
  const _versionKey = 'db_version';
  const _currentVersion = '1.4.0';

  try {
    // Open settings box to check version
    await Hive.openBox<dynamic>('settings');
    final settingsBox = Hive.box<dynamic>('settings');
    final version = settingsBox.get(_versionKey, defaultValue: '');

    // Migration from < 1.4.0 to 1.4.0 - completely reset database due to schema change
    if (version != _currentVersion) {
      try {
        // Delete all old boxes with old schema
        await Hive.deleteBoxFromDisk('exercises');
        await Hive.deleteBoxFromDisk('workouts');
        await Hive.deleteBoxFromDisk('weights');
      } catch (e) {
        // Boxes don't exist or can't be deleted - that's okay
      }

      // Update version
      await settingsBox.put(_versionKey, _currentVersion);
    }
  } catch (e) {
    // If settings box can't be opened, try to delete it and start fresh
    try {
      await Hive.deleteBoxFromDisk('settings');
    } catch (_) {}
  }
}

class LiftApp extends StatelessWidget {
  const LiftApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lift',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6366F1), // Modern Indigo
          brightness: Brightness.dark,
          surface: const Color(0xFF0F172A),
        ),
        scaffoldBackgroundColor: const Color(0xFF020617),
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
          backgroundColor: Color(0xFF020617),
          surfaceTintColor: Colors.transparent,
          titleTextStyle: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFF1E293B),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFF334155), width: 1),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF1E293B),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF334155)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF334155)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF6366F1), width: 2),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF6366F1),
            foregroundColor: Colors.white,
            minimumSize: const Size(0, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            textStyle: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
