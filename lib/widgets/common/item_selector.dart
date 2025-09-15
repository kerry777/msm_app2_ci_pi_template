import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:provider/provider.dart';
import '../../config/api_config.dart';
import '../../services/api_service.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/favorites_provider.dart';

class ItemSelector extends StatefulWidget {
  final Function(String code, String name) onSelected;
  final bool showFavorites;

  const ItemSelector({
    super.key,
    required this.onSelected,
    this.showFavorites = true,
  });

  @override
  State<ItemSelector> createState() => _ItemSelectorState();
}

class _ItemSelectorState extends State<ItemSelector> {
  List<Map<String, dynamic>> _items = [];
  bool _isLoading = false;
  String? _error;
  String? _selectedItemCode;

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final items = await ApiService.getItems(trCd: 'DEFAULT');
      setState(() {
        _items = items.map((item) => {
          'code': item['itemCd'] ?? '',
          'name': item['itemName'] ?? '',
        }).toList();
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> _getSortedItems() {
    if (!widget.showFavorites) return _items;
    
    final favoritesProvider = Provider.of<FavoritesProvider>(context, listen: false);
    final List<Map<String, dynamic>> sortedItems = [];
    final List<Map<String, dynamic>> regularItems = [];
    
    for (final item in _items) {
      if (favoritesProvider.isItemFavorite(item['code'])) {
        sortedItems.add({...item, 'isFavorite': true});
      } else {
        regularItems.add({...item, 'isFavorite': false});
      }
    }
    
    sortedItems.addAll(regularItems);
    return sortedItems;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(child: Text(_error!, style: const TextStyle(color: Colors.red)));
    }

    return Consumer<FavoritesProvider>(
      builder: (context, favoritesProvider, child) {
        final sortedItems = _getSortedItems();
        
        return DropdownButtonFormField<String>(
          decoration: InputDecoration(
            labelText: AppLocalizations.of(context).get('item'),
            border: const OutlineInputBorder(),
          ),
          initialValue: _selectedItemCode,
          items: sortedItems.isNotEmpty
              ? sortedItems.map((item) => DropdownMenuItem<String>(
                  value: item['code'],
                  child: Row(
                    children: [
                      if (widget.showFavorites)
                        GestureDetector(
                          onTap: () {
                            favoritesProvider.toggleItemFavorite(item['code']);
                          },
                          child: Icon(
                            item['isFavorite'] ? Icons.star : Icons.star_border,
                            color: item['isFavorite'] ? Colors.amber : Colors.grey,
                            size: 20,
                          ),
                        ),
                      if (widget.showFavorites) const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          AppLocalizations.of(context).get('item_name_code') ?? '${item['name']} (${item['code']})',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                )).toList()
              : [],
          onChanged: sortedItems.isNotEmpty ? (value) {
            if (value != null) {
              setState(() {
                _selectedItemCode = value;
              });
              final item = sortedItems.firstWhere((i) => i['code'] == value);
              widget.onSelected(item['code'], item['name']);
            }
          } : null,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return '품목을 선택해주세요';
            }
            return null;
          },
          hint: sortedItems.isNotEmpty ? null : Text(AppLocalizations.of(context).get('no_item') ?? '선택 가능한 품목 없음'),
        );
      },
    );
  }
} 