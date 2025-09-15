import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../utils/dialog_utils.dart';
import '../widgets/common/bottom_app_bar.dart';
import '../l10n/app_localizations.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  bool _isLoading = false;
  bool _obscureCurrentPassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;

  // 반응형 디자인을 위한 헬퍼 메서드들
  double getFontSize(BuildContext context, double base) {
    final width = MediaQuery.of(context).size.width;
    if (width < 480) return base - 2;
    if (width < 800) return base;
    if (width < 1200) return base + 1;
    return base + 2;
  }

  EdgeInsets getPadding(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < 480) return const EdgeInsets.all(12.0);
    if (width < 800) return const EdgeInsets.all(16.0);
    if (width < 1200) return const EdgeInsets.all(20.0);
    return const EdgeInsets.all(24.0);
  }

  double getButtonHeight(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < 480) return 48;
    if (width < 800) return 52;
    return 56;
  }

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _showSuccessDialogAndLogout() async {
    await showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(AppLocalizations.of(context).get('change_password')),
          content: Text(AppLocalizations.of(context).get('password_changed_successfully_relogin')),
          actions: <Widget>[
            TextButton(
              child: Text(AppLocalizations.of(context).get('confirm')),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
    // 로그아웃 및 로그인 화면으로 이동
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    await authProvider.logout();
    if (mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
    }
  }

  Future<void> _showErrorDialog(String message) async {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(AppLocalizations.of(context).get('change_password_failed')),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              child: Text(AppLocalizations.of(context).get('confirm')),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _changePassword() async {
    if (_formKey.currentState!.validate()) {
      final confirmed = await DialogUtils.showConfirmDialog(
        context,
        title: AppLocalizations.of(context).get('change_password_confirm'),
        content: AppLocalizations.of(context).get('change_password_confirm_message'),
      );

      if (confirmed != true) {
        return;
      }

      setState(() {
        _isLoading = true;
      });

      try {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        final userInfo = authProvider.userInfo;
        
        if (userInfo == null || userInfo['MEK_EMP_CD'] == null) {
          throw Exception(AppLocalizations.of(context).get('user_info_not_found'));
        }

        final empCd = userInfo['MEK_EMP_CD'] as String;
        
        final response = await ApiService().changePassword(
          currentPassword: _currentPasswordController.text,
          newPassword: _newPasswordController.text,
          empCd: empCd,
        );

        if (response['status'] == 'success') {
          if (mounted) {
            await _showSuccessDialogAndLogout();
          }
        } else {
          if (mounted) {
            await _showErrorDialog(response['message'] ?? AppLocalizations.of(context).get('unknown_error_occurred'));
          }
        }
      } catch (e) {
        if (mounted) {
          await _showErrorDialog('${AppLocalizations.of(context).get('change_password_error')}: $e');
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  String? _validateCurrentPassword(String? value) {
    if (value == null || value.isEmpty) {
      return AppLocalizations.of(context).get('enter_current_password');
    }
    return null;
  }

  String? _validateNewPassword(String? value) {
    if (value == null || value.isEmpty) {
      return AppLocalizations.of(context).get('enter_new_password');
    }
    if (value.length < 4) {
      return AppLocalizations.of(context).get('password_min_length_4');
    }
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) {
      return AppLocalizations.of(context).get('enter_password_confirm');
    }
    if (value != _newPasswordController.text) {
      return AppLocalizations.of(context).get('passwords_do_not_match');
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          AppLocalizations.of(context).get('change_password'),
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: getPadding(context),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: getPadding(context).top),
              
              // 현재 비밀번호 입력 필드
              TextFormField(
                controller: _currentPasswordController,
                obscureText: _obscureCurrentPassword,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context).get('current_password'),
                  border: const OutlineInputBorder(),
                  labelStyle: TextStyle(fontSize: getFontSize(context, 14)),
                  suffixIcon: IconButton(
                    icon: Icon(
                      Icons.visibility,
                      size: 14,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscureCurrentPassword = !_obscureCurrentPassword;
                      });
                    },
                  ),
                ),
                style: TextStyle(fontSize: getFontSize(context, 14)),
                validator: _validateCurrentPassword,
              ),
              
              SizedBox(height: getPadding(context).vertical),
              
              // 새 비밀번호 입력 필드
              TextFormField(
                controller: _newPasswordController,
                obscureText: _obscureNewPassword,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context).get('new_password'),
                  border: const OutlineInputBorder(),
                  labelStyle: TextStyle(fontSize: getFontSize(context, 14)),
                  suffixIcon: IconButton(
                    icon: Icon(
                      Icons.visibility,
                      size: 14,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscureNewPassword = !_obscureNewPassword;
                      });
                    },
                  ),
                ),
                style: TextStyle(fontSize: getFontSize(context, 14)),
                validator: _validateNewPassword,
              ),
              
              SizedBox(height: getPadding(context).vertical / 2),
              
              // 비밀번호 규칙 안내
              Container(
                padding: getPadding(context),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalizations.of(context).get('password_rules'),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: getFontSize(context, 14),
                      ),
                    ),
                    SizedBox(height: getPadding(context).vertical / 4),
                    Text(
                      AppLocalizations.of(context).get('password_rule_min_length'),
                      style: TextStyle(fontSize: getFontSize(context, 12)),
                    ),
                    Text(
                      AppLocalizations.of(context).get('password_rule_alphanumeric'),
                      style: TextStyle(fontSize: getFontSize(context, 12)),
                    ),
                  ],
                ),
              ),
              
              SizedBox(height: getPadding(context).vertical),
              
              // 새 비밀번호 확인 입력 필드
              TextFormField(
                controller: _confirmPasswordController,
                obscureText: _obscureConfirmPassword,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context).get('confirm_new_password'),
                  border: const OutlineInputBorder(),
                  labelStyle: TextStyle(fontSize: getFontSize(context, 14)),
                  suffixIcon: IconButton(
                    icon: Icon(
                      Icons.visibility,
                      size: 14,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscureConfirmPassword = !_obscureConfirmPassword;
                      });
                    },
                  ),
                ),
                style: TextStyle(fontSize: getFontSize(context, 14)),
                validator: _validateConfirmPassword,
              ),
              
              SizedBox(height: getPadding(context).vertical * 2),
              
              // 비밀번호 변경 버튼
              SizedBox(
                height: getButtonHeight(context),
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _changePassword,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: getPadding(context).vertical),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_isLoading)
                        SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                      if (_isLoading) SizedBox(width: 12),
                      Text(
                        AppLocalizations.of(context).get('change_password'),
                        style: TextStyle(
                          fontSize: getFontSize(context, 14),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const CommonBottomAppBar(),
    );
  }
} 