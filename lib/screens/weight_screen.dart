import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:lift/models/weight.dart';
import 'package:lift/providers/workout_provider.dart';
import 'package:lift/widgets/timeline_chart.dart';

class WeightScreen extends StatelessWidget {
  const WeightScreen({super.key});

  void _showAddWeightDialog(BuildContext context) {
    final weightController = TextEditingController();
    final provider = context.read<WorkoutProvider>();
    DateTime selectedDate = DateTime.now();

    if (provider.weightEntries.isNotEmpty) {
      weightController.text = provider.weightEntries.first.weight.toString();
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Log Body Weight'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: weightController,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    hintText: 'Weight (kg)',
                    suffixText: 'kg',
                  ),
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (date != null) {
                      final time = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.fromDateTime(selectedDate),
                      );
                      if (time != null) {
                        setDialogState(() {
                          selectedDate = DateTime(
                            date.year,
                            date.month,
                            date.day,
                            time.hour,
                            time.minute,
                          );
                        });
                      }
                    }
                  },
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                      const SizedBox(width: 8),
                      Text(
                        DateFormat('MMM d, yyyy HH:mm').format(selectedDate),
                        style: const TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                    ],
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
                  final weight = double.tryParse(weightController.text);
                  if (weight != null) {
                    final entry = WeightEntry.create(
                      weight: weight,
                      date: selectedDate,
                    );
                    provider.addWeightEntry(entry);
                    Navigator.pop(context);
                  }
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Weight Tracker'),
      ),
      body: Consumer<WorkoutProvider>(
        builder: (context, provider, child) {
          final entries = provider.weightEntries;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildWeightChart(entries),
              const SizedBox(height: 32),
              const Text(
                'History',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              if (entries.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32.0),
                    child: Text('No weight entries yet', style: TextStyle(color: Colors.grey)),
                  ),
                )
              else
                ...entries.map((entry) => _buildWeightTile(context, entry, provider)),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'weight_fab',
        onPressed: () => _showAddWeightDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildWeightChart(List<WeightEntry> entries) {
    final points = entries.map((e) => ChartDataPoint(date: e.date, value: e.weight)).toList();

    return TimelineChart(
      points: points,
      label: 'Weight Progress',
      subLabel: 'Body weight over time (kg)',
      color: Colors.tealAccent,
    );
  }

  Widget _buildWeightTile(BuildContext context, WeightEntry entry, WorkoutProvider provider) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(
          '${entry.weight} kg',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(DateFormat('MMM d, yyyy HH:mm').format(entry.date)),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
          onPressed: () => provider.deleteWeightEntry(entry.id),
        ),
      ),
    );
  }
}
