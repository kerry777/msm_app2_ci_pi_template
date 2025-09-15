import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';

class AuthProvider extends ChangeNotifier {
  static const String _tokenKey = 'token';
  static const String _userInfoKey = 'userInfo';

  final ApiService _apiService = ApiService();
  bool _isAuthenticated = false;
  String? _token;
  Map<String, dynamic>? _userInfo;
  bool _isLoading = false;
  String? _error;
  String? _empCd;
  Map<String, dynamic>? _user;
  bool _isInitialized = false;

  bool get isAuthenticated => _isAuthenticated;
  String? get token => _token;
  Map<String, dynamic>? get userInfo => _userInfo;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get empCd => _empCd;
  Map<String, dynamic>? get user => _user;
  bool get isInitialized => _isInitialized;

  AuthProvider() {
    initialize();
  }

  Future<void> initialize() async {
    try {
      await _loadToken();
      debugPrint('[AuthProvider.initialize] token= [32m$_token [0m, userInfo= [32m$_userInfo [0m');
      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint('AuthProvider 초기화 오류: $e');
      _isInitialized = true;
      notifyListeners();
    }
  }

  void setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  Future<void> _loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(_tokenKey);
    debugPrint('[AuthProvider._loadToken] prefs.token=$_token');
    // userInfo도 함께 로드
    final userInfoStr = prefs.getString(_userInfoKey);
    debugPrint('[AuthProvider._loadToken] prefs.userInfo=$userInfoStr');
    if (userInfoStr != null) {
      final userInfo = Map<String, dynamic>.from(jsonDecode(userInfoStr));
      userInfo['MEK_EMP_CD'] = userInfo['MEK_EMP_CD'] ??
                               userInfo['EMP_CD'] ??
                               userInfo['empCd'] ??
                               userInfo['mekEmpCd'] ??
                               userInfo['LOGINID'] ??
                               '';
      _userInfo = userInfo;
      debugPrint('[AuthProvider._loadToken] loaded userInfo=$_userInfo');
      notifyListeners();
    }
  }

  Future<void> _saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', token);
    _token = token;
    debugPrint('[AuthProvider._saveToken] token=$token');
    notifyListeners();
  }

  Future<void> _clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    _token = null;
    debugPrint('[AuthProvider._clearToken] token cleared');
    notifyListeners();
  }

  Future<bool> login(String empCd, String password) async {
    try {
      setLoading(true);
      debugPrint('[AuthProvider.login] empCd=$empCd, password=${password.isNotEmpty ? "***" : "empty"}');
      final response = await _apiService.login(empCd, password);
      debugPrint('[AuthProvider.login] response=$response');
      final token = response['accessToken'] ?? response['token'];
      if ((response['status'] == 'success' || response['success'] == true) && token != null) {
        _isAuthenticated = true;
        _token = token;
        await ApiService.setToken(token); // 메모리와 SharedPreferences 동기화
        if (response['userInfo'] != null) {
          final userInfo = Map<String, dynamic>.from(response['userInfo']);
          userInfo['MEK_EMP_CD'] = userInfo['MEK_EMP_CD'] ??
                                   userInfo['EMP_CD'] ??
                                   userInfo['empCd'] ??
                                   userInfo['mekEmpCd'] ??
                                   userInfo['LOGINID'] ??
                                   '';
          _userInfo = userInfo;
          _empCd = userInfo['MEK_EMP_CD']?.toString() ?? '';
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('empCd', _empCd ?? '');
          debugPrint('[AuthProvider.login] userInfo 저장: $_userInfo, empCd=$_empCd');
        } else {
          _userInfo = null;
          _empCd = null;
        }
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_userInfoKey, jsonEncode(_userInfo));
        debugPrint('[AuthProvider.login] userInfo SharedPreferences 저장: ${jsonEncode(_userInfo)}');
        await _saveToken(_token!);
        return true;
      } else {
        debugPrint('[AuthProvider.login] 로그인 실패');
        return false;
      }
    } catch (e) {
      debugPrint('AuthProvider.login 오류: $e');
      return false;
    } finally {
      setLoading(false);
    }
  }

  Future<bool> checkAuth() async {
    return _token != null;
  }

  Future<void> logout() async {
    try {
      debugPrint('=== AuthProvider.logout 시작 ===');
      _isAuthenticated = false;
      _token = null;
      _userInfo = null;
      _user = null;
      _empCd = null;
      _error = null;
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tokenKey);
      await prefs.remove(_userInfoKey);
      await prefs.remove('empCd');
      debugPrint('=== AuthProvider.logout 완료: token, userInfo, empCd 모두 삭제 ===');
      notifyListeners();
    } catch (e) {
      debugPrint('=== AuthProvider.logout 오류 ===');
      debugPrint('오류: $e');
    }
  }

  void updateUserInfo(Map<String, String?> newInfo) {
    try {
      debugPrint('updateUserInfo: Received newInfo=$newInfo');
      if (_userInfo != null) {
        _userInfo!.addAll(newInfo);
      }
      SharedPreferences.getInstance().then((prefs) {
        prefs.setString(_userInfoKey, jsonEncode(_userInfo));
        debugPrint('Updated userInfo saved to SharedPreferences: $_userInfo');
      });
      debugPrint('Updated userInfo: $_userInfo');
      notifyListeners();
    } catch (e) {
      debugPrint('updateUserInfo error: $e');
      rethrow;
    }
  }
}

