import 'package:flutter/material.dart';
import 'package:msm_app/services/api_service.dart';
import 'package:msm_app/models/item_return.dart';

class ItemReturnProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  List<ItemReturn> _items = [];
  bool _isLoading = false;

  List<ItemReturn> get items => _items;
  bool get isLoading => _isLoading;

  Future<void> loadItems() async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _apiService.getItemReturns();
      _items = response.map((item) => ItemReturn.fromJson(item)).toList();
    } catch (e) {
      print('Error loading items: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> createItem(Map<String, dynamic> item) async {
    try {
      final response = await _apiService.createItemReturn(item);
      _items.add(ItemReturn.fromJson(response));
      notifyListeners();
    } catch (e) {
      print('Error creating item: $e');
    }
  }

  Future<void> updateItem(ItemReturn item) async {
    try {
      final response = await _apiService.updateItemReturn(item.toJson());
      final index = _items.indexWhere((i) => i.id == item.id);
      if (index != -1) {
        _items[index] = ItemReturn.fromJson(response);
        notifyListeners();
      }
    } catch (e) {
      print('Error updating item: $e');
    }
  }

  Future<void> deleteItem(int id) async {
    try {
      await _apiService.deleteItemReturn(id);
      _items.removeWhere((item) => item.id == id);
      notifyListeners();
    } catch (e) {
      print('Error deleting item: $e');
    }
  }
} 