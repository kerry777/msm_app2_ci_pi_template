import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FontSizeProvider with ChangeNotifier {
  double _scaleFactor = 1.0; // 기본 100%
  
  double get scaleFactor => _scaleFactor;
  
  // 스케일 퍼센트 (50% ~ 300%)
  int get scalePercentage => (_scaleFactor * 100).round();
  
  FontSizeProvider() {
    _loadFontSize();
  }
  
  // 저장된 폰트 크기 불러오기
  void _loadFontSize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedScale = prefs.getDouble('font_scale_factor') ?? 1.0;
      // 범위 제한 (0.5 ~ 3.0)
      _scaleFactor = savedScale.clamp(0.5, 3.0);
      notifyListeners();
    } catch (e) {
      print('폰트 크기 로드 실패: $e');
    }
  }
  
  // 폰트 크기 저장하기
  void _saveFontSize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('font_scale_factor', _scaleFactor);
    } catch (e) {
      print('폰트 크기 저장 실패: $e');
    }
  }
  
  // 폰트 크기 설정 (퍼센트로)
  void setScalePercentage(int percentage) {
    final newScale = percentage / 100.0;
    if (newScale >= 0.5 && newScale <= 3.0) {
      _scaleFactor = newScale;
      _saveFontSize();
      notifyListeners();
    }
  }
  
  // 폰트 크기 증가 (+10%)
  void increaseFontSize() {
    final newScale = (_scaleFactor * 100 + 10) / 100;
    if (newScale <= 3.0) {
      _scaleFactor = newScale;
      _saveFontSize();
      notifyListeners();
    }
  }
  
  // 폰트 크기 감소 (-10%)
  void decreaseFontSize() {
    final newScale = (_scaleFactor * 100 - 10) / 100;
    if (newScale >= 0.5) {
      _scaleFactor = newScale;
      _saveFontSize();
      notifyListeners();
    }
  }
  
  // 기본 크기로 리셋 (100%)
  void resetFontSize() {
    _scaleFactor = 1.0;
    _saveFontSize();
    notifyListeners();
  }
  
  // 특정 폰트 크기에 스케일 적용
  double scaledFontSize(double baseFontSize) {
    return baseFontSize * _scaleFactor;
  }
  
  // TextStyle에 스케일 적용
  TextStyle scaleTextStyle(TextStyle baseStyle) {
    return baseStyle.copyWith(
      fontSize: baseStyle.fontSize != null 
          ? baseStyle.fontSize! * _scaleFactor 
          : 14.0 * _scaleFactor,
    );
  }
  
  // 사용 가능한 스케일 옵션들
  List<int> get availableScaleOptions {
    return List.generate(26, (index) => 50 + (index * 10)); // 50% ~ 300%
  }
}