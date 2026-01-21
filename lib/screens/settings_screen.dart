import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import 'package:lift/providers/workout_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _resetApp(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset App'),
        content: const Text(
          'This will delete all your data including workouts, exercises, logs, and weight entries. This action cannot be undone.\n\nAre you sure you want to continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete All Data'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        await context.read<WorkoutProvider>().resetAllData();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('All data has been reset successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to reset data: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _exportAllWorkouts(BuildContext context) async {
    final provider = context.read<WorkoutProvider>();
    final result = await provider.exportWorkouts();

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

  Future<void> _importAllWorkouts(BuildContext context) async {
    final provider = context.read<WorkoutProvider>();
    final result = await provider.importWorkouts();

    if (context.mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(
            result['success'] ?? false ? 'Import Successful' : 'Import Failed',
          ),
          content: Text(result['message'] as String? ?? 'Unknown error'),
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

  Future<void> _exportLogs(BuildContext context) async {
    final provider = context.read<WorkoutProvider>();
    final result = await provider.exportLogs();

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

  Future<void> _launchURL(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url)) {
      throw Exception('Could not launch $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const SizedBox(height: 20),

            // Data Management Section
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Data Management',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 16),

            // Export Workouts
            Card(
              child: ListTile(
                leading: const Icon(Icons.file_download, color: Colors.blue),
                title: const Text('Export All Workouts'),
                subtitle: const Text('Backup your workout configurations'),
                trailing: const Icon(Icons.chevron_right, size: 20),
                onTap: () => _exportAllWorkouts(context),
              ),
            ),

            const SizedBox(height: 12),

            // Import Workouts
            Card(
              child: ListTile(
                leading: const Icon(Icons.file_upload, color: Colors.green),
                title: const Text('Import Workouts'),
                subtitle: const Text('Restore workout configurations'),
                trailing: const Icon(Icons.chevron_right, size: 20),
                onTap: () => _importAllWorkouts(context),
              ),
            ),

            const SizedBox(height: 12),

            // Export Logs
            Card(
              child: ListTile(
                leading: const Icon(Icons.table_chart, color: Colors.purple),
                title: const Text('Export Exercise Logs'),
                subtitle: const Text('Export logs to CSV'),
                trailing: const Icon(Icons.chevron_right, size: 20),
                onTap: () => _exportLogs(context),
              ),
            ),

            const SizedBox(height: 12),

            // Reset App
            Card(
              child: ListTile(
                leading: const Icon(Icons.restore_rounded, color: Colors.red),
                title: const Text(
                  'Reset App',
                  style: TextStyle(color: Colors.red),
                ),
                subtitle: const Text(
                  'Delete all data and restore defaults',
                  style: TextStyle(color: Colors.red),
                ),
                trailing: const Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: Colors.red,
                ),
                onTap: () => _resetApp(context),
              ),
            ),

            const SizedBox(height: 48),

            // About Section
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'About',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 16),

            // App Logo
            Center(
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withOpacity(0.2),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Image.asset(
                    'assets/images/logo.png',
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: Theme.of(context).colorScheme.surfaceVariant,
                      child: const Icon(Icons.fitness_center, size: 60),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Center(
              child: Text(
                'LIFT',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 4,
                ),
              ),
            ),
            const Center(
              child: Text(
                'Version 1.3.0',
                style: TextStyle(color: Colors.grey),
              ),
            ),
            const SizedBox(height: 32),

            // App Description
            const Text(
              'Your modern companion for fitness and strength tracking. Built with focus on speed, data visualization, and a clean user experience.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, height: 1.5),
            ),
            const SizedBox(height: 32),

            // Source Code Card
            Card(
              child: ListTile(
                leading: const Icon(Icons.code),
                title: const Text('Source Code'),
                subtitle: const Text('View on GitHub'),
                trailing: const Icon(Icons.open_in_new, size: 20),
                onTap: () =>
                    _launchURL('https://github.com/slayernominee/lift'),
              ),
            ),

            const SizedBox(height: 12),

            // Issues Card
            Card(
              child: ListTile(
                leading: const Icon(Icons.bug_report_outlined),
                title: const Text('Report Issues'),
                subtitle: const Text('Submit feedback or bugs'),
                trailing: const Icon(Icons.open_in_new, size: 20),
                onTap: () =>
                    _launchURL('https://github.com/slayernominee/lift/issues'),
              ),
            ),

            const SizedBox(height: 12),

            // License Info
            Card(
              child: ListTile(
                leading: const Icon(Icons.description_outlined),
                title: const Text('Licenses'),
                onTap: () => showLicensePage(
                  context: context,
                  applicationName: 'Lift',
                  applicationVersion: '1.3.0',
                ),
              ),
            ),

            const SizedBox(height: 48),

            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'If you enjoy using Lift, consider starring the project on GitHub to support its development!',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ),
            ),

            const SizedBox(height: 48),

            const Center(
              child: Text(
                'Keep Lifting.',
                style: TextStyle(
                  fontStyle: FontStyle.italic,
                  color: Colors.grey,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
