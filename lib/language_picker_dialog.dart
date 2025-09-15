import 'package:flutter/material.dart';
import 'providers/language_provider.dart';

class LanguagePickerDialog extends StatefulWidget {
  final String currentLanguage;
  final Map<String, LanguageData> supportedLanguages;
  final void Function(String) onSelected;

  const LanguagePickerDialog({
    super.key,
    required this.currentLanguage,
    required this.supportedLanguages,
    required this.onSelected,
  });

  @override
  State<LanguagePickerDialog> createState() => _LanguagePickerDialogState();
}

class _LanguagePickerDialogState extends State<LanguagePickerDialog> {
  String _search = '';
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = widget.supportedLanguages.entries
        .where((entry) =>
            entry.value.name.toLowerCase().contains(_search.toLowerCase()) ||
            entry.value.flag.contains(_search) ||
            entry.key.toLowerCase().contains(_search.toLowerCase()))
        .toList();
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SizedBox(
        width: 350,
        height: 420,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search language...',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  isDense: true,
                ),
                onChanged: (v) => setState(() => _search = v),
              ),
            ),
            Expanded(
              child: Scrollbar(
                controller: _scrollController,
                child: ListView.builder(
                  controller: _scrollController,
                  itemCount: filtered.length,
                  itemBuilder: (context, idx) {
                    final entry = filtered[idx];
                    final selected = entry.key == widget.currentLanguage;
                    return ListTile(
                      leading: Text(entry.value.flag, style: TextStyle(fontSize: 14)),
                      title: Text(entry.value.name),
                      selected: selected,
                      selectedTileColor: Colors.blue.withOpacity(0.08),
                      onTap: () {
                        widget.onSelected(entry.key);
                        Navigator.of(context).pop();
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
} 