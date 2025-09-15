import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

class LanguageData {
  final String code;
  final String name;
  final String flag;
  const LanguageData({
    required this.code,
    required this.name,
    required this.flag,
  });
}

class LanguageProvider with ChangeNotifier {
  String _currentLanguage = 'ko';
  static const String _languageKey = 'selected_language';
  bool _isInitialized = false;

  LanguageProvider() {
    _initialize();
  }

  String get currentLanguage => _currentLanguage;
  Map<String, LanguageData> get supportedLanguages => _supportedLanguages;
  bool get isInitialized => _isInitialized;

  Future<void> _initialize() async {
    try {
      await _loadSavedLanguage();
      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint('LanguageProvider 초기화 오류: $e');
      _isInitialized = true;
      notifyListeners();
    }
  }

  Future<void> _loadSavedLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    // 강제로 한국어로 설정 (임시)
    String saved = 'ko';
    await prefs.setString(_languageKey, saved);
    _currentLanguage = saved;
  }

  Future<void> setLanguage(String languageCode) async {
    _currentLanguage = languageCode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languageKey, languageCode);
    notifyListeners();
  }

  void toggleLanguage() {
    setLanguage(_currentLanguage == 'ko' ? 'en' : 'ko');
  }
}

final Map<String, LanguageData> _supportedLanguages = {
  'ko': LanguageData(code: 'ko', name: '한국어', flag: '🇰🇷'),
  'en': LanguageData(code: 'en', name: 'English', flag: '🇺🇸'),
}; 