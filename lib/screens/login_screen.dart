import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../providers/auth_provider.dart';
import '../providers/favorites_provider.dart';
import 'main_screen.dart';
import '../providers/language_provider.dart';
import '../translations.dart';
import '../l10n/app_localizations.dart';
import 'package:flutter/services.dart';

// 공통 폰트 크기 상수 정의
class AppFontSizes {
  static const double topMenu = 14.0;  // Top menu 폰트 크기 (최대값)
  static const double title = 14.0;    // 제목 폰트 크기
  static const double body = 12.0;     // 본문 폰트 크기
  static const double caption = 10.0;  // 캡션 폰트 크기
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  LoginScreenState createState() => LoginScreenState();
}

class LoginScreenState extends State<LoginScreen> {
  final TextEditingController _idController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isObscure = true;
  bool _saveCredentialsCheckbox = false;
  bool _isNavigating = false;
  final _formKey = GlobalKey<FormState>();
  String? _error;
  String _selectedCountry = 'ko'; // Default to Korean

  @override
  void initState() {
    super.initState();
    _initializeDefaultCredentials();
  }

  Future<void> _initializeDefaultCredentials() async {
    // Set default credentials as requested
    setState(() {
      _idController.text = 'msmtest';
      _passwordController.text = '0001';
      _saveCredentialsCheckbox = true;
    });

    // Also load any previously saved credentials if they exist
    _loadSavedCredentials();
  }

  Future<void> _loadSavedCredentials() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final savedCredentials = prefs.getString('saved_credentials');

      if (savedCredentials != null) {
        final credentials = jsonDecode(savedCredentials);
        if (mounted) {
          setState(() {
            _idController.text = credentials['id'] ?? '';
            _passwordController.text = credentials['password'] ?? '';
            _saveCredentialsCheckbox = credentials['save'] ?? false;
          });
        }
      }
    } catch (e) {
      print('저장된 인증정보 로드 실패: $e');
    }
  }

  Future<void> _saveCredentials() async {
    if (_saveCredentialsCheckbox) {
      try {
        final SharedPreferences prefs = await SharedPreferences.getInstance();
        final credentials = {
          'id': _idController.text,
          'password': _passwordController.text,
          'save': _saveCredentialsCheckbox,
        };
        await prefs.setString('saved_credentials', jsonEncode(credentials));
      } catch (e) {
        print('인증정보 저장 실패: $e');
      }
    }
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate() || _isNavigating) return;

    if (_isNavigating) return; // 이중 네비게이션 방지

    setState(() {
      _error = null;
      _isNavigating = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final success = await authProvider.login(
        _idController.text,
        _passwordController.text,
      );

      if (!mounted) return;

      if (success) {
        await _saveCredentials();

        // Set the selected language
        final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
        languageProvider.setLanguage(_selectedCountry);

        // FavoritesProvider 초기화 (필요시)
        // final favoritesProvider = Provider.of<FavoritesProvider>(context, listen: false);

        if (!mounted) return;

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const MainScreen()),
        );
      } else {
        setState(() {
          _error = 'Login failed';
          _isNavigating = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Network error: ${e.toString()}';
          _isNavigating = false;
        });
      }
    }
  }

  String? _validateId(String? value) {
    if (value == null || value.isEmpty) {
      return '아이디를 입력해주세요';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return '비밀번호를 입력해주세요';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // 국가/언어 선택 - 상단에 배치
                    Container(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.public, color: Colors.grey[600], size: 20),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey[300]!),
                              borderRadius: BorderRadius.circular(8),
                              color: Colors.white,
                            ),
                            child: DropdownButton<String>(
                              value: _selectedCountry,
                              underline: const SizedBox(),
                              isDense: true,
                              items: const [
                                DropdownMenuItem(
                                  value: 'ko',
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text('🇰🇷', style: TextStyle(fontSize: 16)),
                                      SizedBox(width: 8),
                                      Text('한국어'),
                                    ],
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: 'en',
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text('🇺🇸', style: TextStyle(fontSize: 16)),
                                      SizedBox(width: 8),
                                      Text('English'),
                                    ],
                                  ),
                                ),
                              ],
                              onChanged: (String? newValue) {
                                if (newValue != null) {
                                  setState(() {
                                    _selectedCountry = newValue;
                                  });
                                  // 즉시 언어 변경 (로그인 전에도 적용)
                                  final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
                                  languageProvider.setLanguage(newValue);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ),

                    // 로고 섹션
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.3),
                            spreadRadius: 3,
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.medical_services,
                        size: 60,
                        color: Color(0xFF1976D2),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // 타이틀
                    Text(
                      'MSM System',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1976D2),
                      ),
                    ),

                    const SizedBox(height: 8),

                    Text(
                      'Medical Supply Management',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),

                    const SizedBox(height: 40),

                    // 로그인 폼 카드
                    Card(
                      elevation: 8,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Login',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[800],
                              ),
                            ),

                            const SizedBox(height: 24),

                            // 아이디 입력
                            TextFormField(
                              controller: _idController,
                              validator: _validateId,
                              decoration: InputDecoration(
                                labelText: '아이디',
                                hintText: '아이디를 입력하세요',
                                prefixIcon: const Icon(Icons.person),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                filled: true,
                                fillColor: Colors.grey[50],
                              ),
                              textInputAction: TextInputAction.next,
                            ),

                            const SizedBox(height: 16),

                            // 비밀번호 입력
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _isObscure,
                              validator: _validatePassword,
                              decoration: InputDecoration(
                                labelText: '비밀번호',
                                hintText: '비밀번호를 입력하세요',
                                prefixIcon: const Icon(Icons.lock),
                                suffixIcon: IconButton(
                                  icon: Icon(_isObscure ? Icons.visibility : Icons.visibility_off),
                                  onPressed: () => setState(() => _isObscure = !_isObscure),
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                filled: true,
                                fillColor: Colors.grey[50],
                              ),
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) => _login(),
                            ),

                            const SizedBox(height: 16),

                            // 비밀번호 저장 체크박스
                            Row(
                              children: [
                                Checkbox(
                                  value: _saveCredentialsCheckbox,
                                  onChanged: (value) => setState(() => _saveCredentialsCheckbox = value ?? false),
                                ),
                                const Text('로그인 정보 저장'),
                              ],
                            ),

                            const SizedBox(height: 24),

                            // 로그인 버튼
                            ElevatedButton(
                              onPressed: _isNavigating ? null : _login,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1976D2),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 3,
                              ),
                              child: _isNavigating
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text(
                                    '로그인',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                            ),

                            if (_error != null) ...[
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.red[50],
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.red[300]!),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.error, color: Colors.red[600], size: 20),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _error!,
                                        style: TextStyle(
                                          color: Colors.red[600],
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // 버전 정보
                    Text(
                      'Version 3.0.0',
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _idController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}