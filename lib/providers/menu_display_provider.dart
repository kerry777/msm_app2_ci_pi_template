import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MenuDisplayProvider with ChangeNotifier {
  bool _showCompletedOnly = false;
  bool _showAllMenus = true;

  bool get showCompletedOnly => _showCompletedOnly;
  bool get showAllMenus => _showAllMenus;

  MenuDisplayProvider() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _showCompletedOnly = prefs.getBool('show_completed_only') ?? false;
    _showAllMenus = prefs.getBool('show_all_menus') ?? true;
    notifyListeners();
  }

  Future<void> toggleShowCompletedOnly() async {
    _showCompletedOnly = !_showCompletedOnly;
    if (_showCompletedOnly) {
      _showAllMenus = false;
    }
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('show_completed_only', _showCompletedOnly);
    await prefs.setBool('show_all_menus', _showAllMenus);
    notifyListeners();
  }

  Future<void> toggleShowAllMenus() async {
    _showAllMenus = !_showAllMenus;
    if (_showAllMenus) {
      _showCompletedOnly = false;
    }
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('show_all_menus', _showAllMenus);
    await prefs.setBool('show_completed_only', _showCompletedOnly);
    notifyListeners();
  }

  bool shouldShowMenu(String subKey, Map<String, bool> menuCompletionStatus) {
    if (_showAllMenus) {
      return true;
    }
    
    if (_showCompletedOnly) {
      return menuCompletionStatus[subKey] ?? false;
    }
    
    return true;
  }

  String getDisplayModeText() {
    if (_showCompletedOnly) {
      return '완료된 메뉴만';
    } else if (_showAllMenus) {
      return '전체 메뉴';
    } else {
      return '전체 메뉴';
    }
  }
} 