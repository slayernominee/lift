import 'package:flutter/material.dart';

class MultiSelectField extends StatelessWidget {
  final String label;
  final List<String> selectedItems;
  final List<String> allItems;
  final bool isLoading;
  final Function(List<String>) onSelectionChanged;

  const MultiSelectField({
    super.key,
    required this.label,
    required this.selectedItems,
    required this.allItems,
    required this.onSelectionChanged,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: isLoading
          ? null
          : () async {
              final result = await showDialog<List<String>>(
                context: context,
                builder: (context) => MultiSelectDialog(
                  title: label,
                  items: allItems,
                  selectedItems: selectedItems,
                ),
              );
              if (result != null) {
                onSelectionChanged(result);
              }
            },
      child: InputDecorator(
        decoration: InputDecoration(
          hintText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: Theme.of(
            context,
          ).colorScheme.surfaceVariant.withOpacity(0.3),
        ),
        child: isLoading
            ? const SizedBox(
                height: 48,
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            : selectedItems.isEmpty
            ? Text(
                'Select $label',
                style: TextStyle(
                  color: Theme.of(context).hintColor,
                  fontSize: 16,
                ),
              )
            : Wrap(
                spacing: 6,
                runSpacing: 6,
                children: selectedItems.map((item) {
                  return Chip(
                    label: Text(item, style: const TextStyle(fontSize: 12)),
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.primaryContainer,
                    deleteIcon: Icon(
                      Icons.close,
                      size: 16,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                    onDeleted: () {
                      onSelectionChanged(
                        selectedItems.where((e) => e != item).toList(),
                      );
                    },
                  );
                }).toList(),
              ),
      ),
    );
  }
}

class MultiSelectDialog extends StatefulWidget {
  final String title;
  final List<String> items;
  final List<String> selectedItems;

  const MultiSelectDialog({
    super.key,
    required this.title,
    required this.items,
    required this.selectedItems,
  });

  @override
  State<MultiSelectDialog> createState() => _MultiSelectDialogState();
}

class _MultiSelectDialogState extends State<MultiSelectDialog> {
  late Set<String> _selected;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selected = widget.selectedItems.toSet();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<String> get _filteredItems {
    final query = _searchController.text.toLowerCase();
    if (query.isEmpty) {
      return widget.items;
    }
    return widget.items
        .where((item) => item.toLowerCase().contains(query))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Select ${widget.title}'),
          const SizedBox(height: 12),
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
            ),
            onChanged: (value) {
              setState(() {});
            },
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: ListView.builder(
          itemCount: _filteredItems.length,
          itemBuilder: (context, index) {
            final item = _filteredItems[index];
            final isSelected = _selected.contains(item);
            return CheckboxListTile(
              title: Text(item, style: const TextStyle(fontSize: 14)),
              value: isSelected,
              onChanged: (value) {
                setState(() {
                  if (value == true) {
                    _selected.add(item);
                  } else {
                    _selected.remove(item);
                  }
                });
              },
              controlAffinity: ListTileControlAffinity.leading,
              dense: true,
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _selected.toList()),
          child: Text('Done (${_selected.length})'),
        ),
      ],
    );
  }
}

class InstructionsField extends StatelessWidget {
  final List<String> instructions;
  final Function(List<String>) onChanged;

  const InstructionsField({
    super.key,
    required this.instructions,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final controller = TextEditingController(text: instructions.join('\n'));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () {
            // Focus on text field when tapped
            FocusScope.of(context).requestFocus();
          },
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: 'Instructions',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Theme.of(
                context,
              ).colorScheme.surfaceVariant.withOpacity(0.3),
              suffixIcon: instructions.isEmpty ? const Icon(Icons.add) : null,
              hintText: 'Add instructions...',
              helperText: 'One instruction per line',
            ),
            child: TextField(
              controller: controller,
              maxLines: null,
              keyboardType: TextInputType.multiline,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(8),
              ),
              onChanged: (value) {
                final newInstructions = value
                    .split('\n')
                    .map((line) => line.trim())
                    .where((line) => line.isNotEmpty)
                    .toList();
                onChanged(newInstructions);
              },
            ),
          ),
        ),
      ],
    );
  }
}
