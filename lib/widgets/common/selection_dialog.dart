import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../l10n/app_localizations.dart';

class SelectionDialog extends StatefulWidget {
  final String title;
  final List<Map<String, dynamic>> items;
  final String displayKey;
  final String valueKey;
  final Set<String> selectedValues;
  final String type; // 'hospital', 'warehouse', 'item'
  final Function(Set<String>) onConfirm;

  const SelectionDialog({
    super.key,
    required this.title,
    required this.items,
    required this.displayKey,
    required this.valueKey,
    required this.selectedValues,
    required this.type,
    required this.onConfirm,
  });

  @override
  State<SelectionDialog> createState() => _SelectionDialogState();
}

class _SelectionDialogState extends State<SelectionDialog> {
  late Set<String> _selectedValues;
  late List<Map<String, dynamic>> _filteredItems;
  final TextEditingController _searchController = TextEditingController();
  Set<String> _favorites = {};
  bool _showFavoritesOnly = false;

  @override
  void initState() {
    super.initState();
    _selectedValues = Set.from(widget.selectedValues);
    _filteredItems = List.from(widget.items);
    _loadFavorites();
    _loadSavedSelections();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final favoritesKey = 'favorites_${widget.type}';
    final favoritesJson = prefs.getString(favoritesKey);
    if (favoritesJson != null) {
      try {
        final decoded = jsonDecode(favoritesJson);
        final list = decoded is List ? decoded : [];
        setState(() {
          _favorites = Set<String>.from(list.map((e) => e.toString()));
        });
      } catch (_) {
        _favorites = {};
      }
    }
  }

  Future<void> _saveFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final favoritesKey = 'favorites_${widget.type}';
    await prefs.setString(favoritesKey, jsonEncode(_favorites.toList()));
  }

  Future<void> _loadSavedSelections() async {
    final prefs = await SharedPreferences.getInstance();
    final selectionsKey = 'selections_${widget.type}';
    final selectionsJson = prefs.getString(selectionsKey);
    if (selectionsJson != null) {
      Set<String> savedSelections;
      try {
        final decoded = jsonDecode(selectionsJson);
        final list = decoded is List ? decoded : [];
        savedSelections = Set<String>.from(list.map((e) => e.toString()));
      } catch (_) {
        savedSelections = {};
      }
      setState(() {
        _selectedValues.addAll(savedSelections);
      });
    }
  }

  Future<void> _saveSelections() async {
    final prefs = await SharedPreferences.getInstance();
    final selectionsKey = 'selections_${widget.type}';
    await prefs.setString(selectionsKey, jsonEncode(_selectedValues.toList()));
  }

  void _toggleFavorite(String value) {
    setState(() {
      if (_favorites.contains(value)) {
        _favorites.remove(value);
      } else {
        _favorites.add(value);
      }
    });
    _saveFavorites();
  }

  void _toggleSelection(String value) {
    setState(() {
      if (_selectedValues.contains(value)) {
        _selectedValues.remove(value);
      } else {
        _selectedValues.add(value);
      }
    });
  }

  void _selectAll() {
    setState(() {
      _selectedValues.addAll(_filteredItems.map((item) => item[widget.valueKey].toString()));
    });
  }

  void _deselectAll() {
    setState(() {
      _selectedValues.clear();
    });
  }

  void _filterItems(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredItems = List.from(widget.items);
      } else {
        _filteredItems = widget.items.where((item) {
          final displayValue = item[widget.displayKey]?.toString().toLowerCase() ?? '';
          return displayValue.contains(query.toLowerCase());
        }).toList();
      }
    });
  }

  void _toggleFavoritesOnly() {
    setState(() {
      _showFavoritesOnly = !_showFavoritesOnly;
      if (_showFavoritesOnly) {
        _filteredItems = widget.items.where((item) {
          return _favorites.contains(item[widget.valueKey].toString());
        }).toList();
      } else {
        _filteredItems = List.from(widget.items);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: SizedBox(
        width: MediaQuery.of(context).size.width * 0.8,
        height: MediaQuery.of(context).size.height * 0.8,
        child: Column(
          children: [
            // 헤더
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(8),
                  topRight: Radius.circular(8),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            
            // 검색 및 필터
            Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // 검색
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: AppLocalizations.of(context).get('search'),
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onChanged: _filterItems,
                  ),
                  const SizedBox(height: 8),
                  
                  // 버튼들
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: Icon(_showFavoritesOnly ? Icons.favorite : Icons.favorite_border),
                          label: Text(_showFavoritesOnly ? '전체보기' : '즐겨찾기'),
                          onPressed: _toggleFavoritesOnly,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _showFavoritesOnly ? Colors.red : null,
                            foregroundColor: _showFavoritesOnly ? Colors.white : null,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.select_all),
                          label: Text(AppLocalizations.of(context).get('select_all') ?? '전체선택'),
                          onPressed: _selectAll,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.clear_all),
                          label: Text(AppLocalizations.of(context).get('deselect_all') ?? '전체해제'),
                          onPressed: _deselectAll,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            // 선택된 항목 수 표시
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Text(
                    '선택된 항목: ${_selectedValues.length}개',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  Text(
                    '전체: ${_filteredItems.length}개',
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
            
            const Divider(),
            
            // 리스트
            Expanded(
              child: ListView.builder(
                itemCount: _filteredItems.length,
                itemBuilder: (context, index) {
                  final item = _filteredItems[index];
                  final value = item[widget.valueKey].toString();
                  final display = item[widget.displayKey]?.toString() ?? '';
                  final isSelected = _selectedValues.contains(value);
                  final isFavorite = _favorites.contains(value);
                  
                  return ListTile(
                    leading: Checkbox(
                      value: isSelected,
                      onChanged: (bool? value) {
                        if (value != null) {
                          _toggleSelection(item[widget.valueKey].toString());
                        }
                      },
                    ),
                    title: Text(display),
                    subtitle: item['address'] != null && item['address'].toString().isNotEmpty
                        ? Text(item['address'].toString())
                        : null,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(
                            isFavorite ? Icons.favorite : Icons.favorite_border,
                            color: isFavorite ? Colors.red : null,
                          ),
                          onPressed: () => _toggleFavorite(value),
                        ),
                      ],
                    ),
                    onTap: () => _toggleSelection(value),
                  );
                },
              ),
            ),
            
            // 하단 버튼들
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(AppLocalizations.of(context).get('cancel') ?? '취소'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        _saveSelections();
                        widget.onConfirm(_selectedValues);
                        Navigator.of(context).pop();
                      },
                      child: Text(AppLocalizations.of(context).get('confirm') ?? '확인'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
} 