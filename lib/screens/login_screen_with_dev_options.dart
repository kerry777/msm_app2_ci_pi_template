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
import '../utils/auto_test_system.dart';

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
  bool _saveCredentials = false;
  bool _isNavigating = false;
  final _formKey = GlobalKey<FormState>();
  String? _error;
  
  // 🤖 자동 테스트 관련
  bool _enableAutoTest = false;
  final AutoTestSystem _autoTestSystem = AutoTestSystem();
  
  // 🆕 자동 로그인 관련 (완전 비활성화)
  bool _enableAutoLogin = false;

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
    // _loadDeveloperSettings(); // 자동 로그인 방지를 위해 비활성화
  }

  Future<void> _loadSavedCredentials() async {
    // ✨ 자동 로그인 방지를 위해 저장된 자격증명 로드 비활성화
    try {
      final prefs = await SharedPreferences.getInstance();

      // 🚨 자동 로그인 관련 모든 설정 완전 제거
      await prefs.remove('enable_auto_login');
      await prefs.remove('enable_auto_test');
      await prefs.remove('saved_id');
      await prefs.remove('saved_password');
      await prefs.remove('save_credentials');

      print('🧹 자동 로그인 설정 완전 제거됨');

      // 기본값으로 초기화 (저장된 자격증명 무시)
      setState(() {
        _saveCredentials = false;
        _enableAutoLogin = false;  // 강제로 false 설정
        _enableAutoTest = false;   // 강제로 false 설정
        _idController.text = '';
        _passwordController.text = '';
      });
    } catch (e) {
      print('자격증명 초기화 실패: $e');
    }
  }

  // 🆕 개발자 설정 로드
  Future<void> _loadDeveloperSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _enableAutoLogin = prefs.getBool('enable_auto_login') ?? false;
        _enableAutoTest = prefs.getBool('enable_auto_test') ?? false;
      });
    } catch (e) {
      print('개발자 설정 로드 실패: $e');
    }
  }

  // 🆕 개발자 설정 저장
  Future<void> _saveDeveloperSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('enable_auto_login', _enableAutoLogin);
      await prefs.setBool('enable_auto_test', _enableAutoTest);
    } catch (e) {
      print('개발자 설정 저장 실패: $e');
    }
  }

  // 🆕 사용자 권한별 자동 로그인 (IT/HM만 가능)
  Future<void> _tryAutoLogin() async {
    try {
      // 개발 모드에서만 자동 로그인 (kDebugMode 체크 + 사용자 설정)
      if (kDebugMode && _enableAutoLogin) {
        // 저장된 사용자 정보에서 권한 확인
        final prefs = await SharedPreferences.getInstance();
        final savedUserInfo = prefs.getString('userInfo');
        
        if (savedUserInfo != null) {
          final userInfo = Map<String, dynamic>.from(jsonDecode(savedUserInfo));
          final accessType = userInfo['MEK_ACCESS_TYPE']?.toString() ?? '';
          
          // IT 또는 HM 권한이 있는 경우에만 자동 로그인 실행
          if (accessType == 'IT' || accessType == 'HM') {
            print('🔐 자동 로그인 권한 확인: $accessType');
            
            // 이미 저장된 자격증명이 있으면 자동 로그인 시도
            if (_idController.text.isNotEmpty && _passwordController.text.isNotEmpty) {
              print('🔄 저장된 자격증명으로 자동 로그인 시도...');
              await Future.delayed(const Duration(seconds: 1));
              if (mounted) {
                await _performLogin();
              }
            }
          } else {
            print('🔐 자동 로그인 권한 없음: $accessType - 기능 비활성화');
            setState(() {
              _enableAutoLogin = false;
            });
            await prefs.setBool('enable_auto_login', false);
          }
        }
      }
    } catch (e) {
      print('자동 로그인 실패: $e');
    }
  }

  // 🆕 사용자 권한별 자동 로그인 옵션 확인
  Future<void> _checkAutoLoginPermission() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedUserInfo = prefs.getString('userInfo');
      
      if (savedUserInfo != null) {
        final userInfo = Map<String, dynamic>.from(jsonDecode(savedUserInfo));
        final accessType = userInfo['MEK_ACCESS_TYPE']?.toString() ?? '';
        
        // IT(개발자) 또는 HM(본사관리자)만 자동 로그인 옵션 표시
        if (accessType == 'IT' || accessType == 'HM') {
          print('🔐 권한 확인: $accessType - 자동 로그인 옵션 사용 가능');
          // 자동 로그인 옵션이 활성화되어 있다면 자동 실행
          if (_enableAutoLogin) {
            await _tryAutoLogin();
          }
        } else {
          print('🔐 권한 확인: $accessType - 자동 로그인 옵션 사용 불가');
          // 권한이 없으면 자동 로그인 비활성화
          setState(() {
            _enableAutoLogin = false;
          });
          await prefs.setBool('enable_auto_login', false);
        }
      }
    } catch (e) {
      print('권한 확인 실패: $e');
    }
  }

  // 🆕 관리자 권한 확인 (IT 또는 HM)
  bool _hasAdminPermission() {
    try {
      // 현재 로그인된 사용자 정보에서 권한 확인 (향후 확장 가능)
      // 일단 개발 모드에서는 모든 옵션 표시
      return true;
    } catch (e) {
      return false;
    }
  }

  // 🆕 개발자 기능 사용 여부 확인 팝업
  Future<void> _showDeveloperOptionsDialog(String accessType, String userName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final alreadyAsked = prefs.getBool('developer_options_asked_$accessType') ?? false;
      
      // 이미 물어봤으면 스킵
      if (alreadyAsked) return;
      
      if (!mounted) return;
      
      final result = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Row(
              children: [
                Icon(Icons.admin_panel_settings, color: Colors.orange),
                SizedBox(width: 8),
                Text('개발자 기능 사용'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('안녕하세요, $userName님!'),
                SizedBox(height: 8),
                Text('귀하의 권한: ${accessType == 'IT' ? 'IT 개발자' : '본사 관리자'}'),
                SizedBox(height: 12),
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('사용 가능한 개발자 기능:', 
                        style: TextStyle(fontWeight: FontWeight.bold)),
                      SizedBox(height: 4),
                      Text('• 자동 로그인 (테스트 계정 자동 입력)'),
                      Text('• 자동 테스트 (화면 자동 테스트 실행)'),
                      Text('• 디버그 로그 (상세 로그 출력)'),
                    ],
                  ),
                ),
                SizedBox(height: 12),
                Text('개발자 기능을 활성화하시겠습니까?'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text('나중에'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(null),
                child: Text('다시 묻지 않기'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text('활성화'),
              ),
            ],
          );
        },
      );
      
      // 사용자 선택에 따른 처리
      if (result == true) {
        // 개발자 기능 활성화
        setState(() {
          _enableAutoLogin = true;
          _enableAutoTest = true;
        });
        await _saveDeveloperSettings();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🚀 개발자 기능이 활성화되었습니다!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      } else if (result == null) {
        // 다시 묻지 않기
        await prefs.setBool('developer_options_asked_$accessType', true);
      }
      
    } catch (e) {
      print('개발자 옵션 팝업 오류: $e');
    }
  }

  Future<void> _saveLoginCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_saveCredentials) {
        await prefs.setString('saved_emp_cd', _idController.text);
        await prefs.setString('saved_password', _passwordController.text);
        await prefs.setBool('save_credentials', true);
      } else {
        await prefs.remove('saved_emp_cd');
        await prefs.remove('saved_password');
        await prefs.setBool('save_credentials', false);
      }
    } catch (e) {
      // 예외 처리는 필요에 따라 추가할 수 있습니다.
    }
  }

  @override
  void dispose() {
    _idController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && ScaffoldMessenger.of(context).mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    });
  }

  Future<bool> _performLogin() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final favoritesProvider = Provider.of<FavoritesProvider>(context, listen: false);
    final currentLanguage = Provider.of<LanguageProvider>(context, listen: false).currentLanguage;
    final empCd = _idController.text.trim();
    final password = _passwordController.text.trim();

    if (empCd.isEmpty || password.isEmpty) {
      if (!mounted) return false;
      _showErrorSnackBar(AppLocalizations.of(context).get('empty_credentials'));
      return false;
    }

    setState(() => _isNavigating = true);

    try {
      final success = await auth.login(empCd, password);
      
      if (success) {
        // 즐겨찾기 초기화
        await favoritesProvider.initialize();
        
        if (_saveCredentials) {
          await _saveLoginCredentials();
        }
        if (!mounted) return false;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const MainScreen()),
          (route) => false,
        );
        ScaffoldMessenger.of(context).clearSnackBars();
        
        // 🔐 로그인 성공 후 권한별 개발자 기능 확인
        if (kDebugMode && mounted) {
          final authProvider = Provider.of<AuthProvider>(context, listen: false);
          final accessType = authProvider.userInfo?['MEK_ACCESS_TYPE']?.toString() ?? '';
          final userName = authProvider.userInfo?['KOR_NM']?.toString() ?? '';
          
          // IT 또는 HM 권한 사용자에게 개발자 기능 사용 여부 묻기
          if (accessType == 'IT' || accessType == 'HM') {
            WidgetsBinding.instance.addPostFrameCallback((_) async {
              await Future.delayed(const Duration(milliseconds: 500)); // 화면 로딩 대기
              if (mounted) {
                await _showDeveloperOptionsDialog(accessType, userName);
              }
            });
          }
          
          // 이미 활성화된 자동 테스트가 있으면 실행
          if (_enableAutoTest && (accessType == 'IT' || accessType == 'HM')) {
            WidgetsBinding.instance.addPostFrameCallback((_) async {
              await Future.delayed(const Duration(seconds: 2)); // 화면 로딩 대기
              if (mounted) {
                print('🤖 자동 테스트 시작! (권한: $accessType)');
                await _autoTestSystem.startAutoTest(context);
              }
            });
          }
        }
        
        return true;
      } else {
        if (!mounted) return false;
        _showErrorSnackBar(AppLocalizations.of(context).get('login_failed'));
        return false;
      }
    } catch (e) {
      if (!mounted) return false;
      _showErrorSnackBar(AppLocalizations.of(context).get('login_error') + e.toString());
      return false;
    } finally {
      if (mounted) {
        setState(() => _isNavigating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final languageProvider = Provider.of<LanguageProvider>(context);
    final currentLanguage = languageProvider.currentLanguage;
    
    // 로딩 상태 처리
    if (auth.isLoading) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(AppLocalizations.of(context).get('logging_in')),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: Center(
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 로고
              Image.asset(
                'assets/msm_app_logo.png',
                height: 80,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 24),
              Text(
                AppLocalizations.of(context).get('app_title') ?? 'MDM',
                style: TextStyle(
                  fontSize: AppFontSizes.title,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                AppLocalizations.of(context).get('app_subtitle') ?? 'MEKICS Delivery Manager',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 32),
              // 언어 선택
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButton<String>(
                  value: languageProvider.currentLanguage,
                  isExpanded: true,
                  underline: const SizedBox(),
                  items: languageProvider.supportedLanguages.entries.map((entry) {
                    return DropdownMenuItem<String>(
                      value: entry.key,
                      child: Row(
                        children: [
                          Text(entry.value.flag),
                          const SizedBox(width: 8),
                          Text(entry.value.name),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    if (newValue != null && newValue != languageProvider.currentLanguage) {
                      languageProvider.setLanguage(newValue);
                    }
                  },
                ),
              ),
              const SizedBox(height: 24),
              // 로그인 폼
              TextField(
                controller: _idController,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context).get('id'),
                  prefixIcon: const Icon(Icons.person),
                  border: const OutlineInputBorder(),
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
                ],
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                textCapitalization: TextCapitalization.none,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                obscureText: _isObscure,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context).get('password'),
                  prefixIcon: const Icon(Icons.lock),
                  suffixIcon: IconButton(
                    icon: Icon(_isObscure ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setState(() => _isObscure = !_isObscure),
                  ),
                  border: const OutlineInputBorder(),
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9!@#\$%^&*()_+\-=\[\]{};:\"\|,.<>\/?]')),
                ],
                keyboardType: TextInputType.visiblePassword,
                textInputAction: TextInputAction.done,
                textCapitalization: TextCapitalization.none,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Checkbox(
                    value: _saveCredentials,
                    onChanged: (value) => setState(() => _saveCredentials = value ?? false),
                  ),
                  Text(
                    AppLocalizations.of(context).get('save_credentials'),
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
              ),
              
              // 🤖 권한이 있는 사용자만 자동 테스트 옵션 표시 (IT/HM)
              if (kDebugMode && _hasAdminPermission()) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.smart_toy, size: 20, color: Colors.blue[700]),
                          const SizedBox(width: 8),
                          Text(
                            '🤖 개발자 옵션',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue[700],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Checkbox(
                            value: _enableAutoLogin,
                            onChanged: (value) {
                              setState(() => _enableAutoLogin = value ?? false);
                              _saveDeveloperSettings();
                            },
                          ),
                          Expanded(
                            child: Text(
                              '자동 로그인 활성화 (IT/HM 권한 필요)',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Checkbox(
                            value: _enableAutoTest,
                            onChanged: (value) {
                              setState(() => _enableAutoTest = value ?? false);
                              _saveDeveloperSettings();
                            },
                          ),
                          Expanded(
                            child: Text(
                              '자동 테스트 실행 (IT/HM 권한 필요)',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                      if (_enableAutoTest) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.info_outline, size: 14, color: Colors.orange[700]),
                              const SizedBox(width: 4),
                              Text(
                                '총 ${AutoTestSystem.testScreens.length}개 화면 테스트 예정',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.orange[700],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _isNavigating ? null : () async {
                            // 수동으로 자동 테스트 실행 (로그인 없이)
                            await _autoTestSystem.startAutoTest(context);
                          },
                          icon: const Icon(Icons.play_arrow, size: 16),
                          label: const Text('수동 테스트 실행', style: TextStyle(fontSize: 12)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green[600],
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade800,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: _isNavigating ? null : () async {
                    debugPrint('Login button pressed');
                    setState(() {
                      _isNavigating = true;
                    });
                    await _performLogin();
                  },
                  child: _isNavigating
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          AppLocalizations.of(context).get('login'),
                          style: TextStyle(
                            fontSize: AppFontSizes.body,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
