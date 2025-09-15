import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

class HelpService {
  static const Map<String, String> _helpFileMap = {
    'all': 'assets/msm_all_help.md',
    'stock_status': 'assets/msm_stock_status_help.md',
    'stock_manage': 'assets/msm_stock_manage_help.md',
    'stock_close': 'assets/msm_stock_close_help.md',
    'charts': 'assets/msm_charts_help.md',
    'stock_settings': 'assets/msm_stock_settings_help.md',
    'faq': 'assets/msm_faq.md',
    'contact': 'assets/msm_contact.md',
  };

  /// 도움말 파일 내용을 읽어옵니다.
  static Future<String> getHelpContent(String helpType) async {
    try {
      final filePath = _helpFileMap[helpType];
      if (filePath == null) {
        return '도움말 파일을 찾을 수 없습니다.';
      }

      final content = await rootBundle.loadString(filePath);
      return content;
    } catch (e) {
      debugPrint('Help file read error: $e');
      return '도움말을 불러오는 중 오류가 발생했습니다.\n\n오류: $e';
    }
  }

  /// FAQ 내용을 읽어옵니다.
  static Future<String> getFAQContent() async {
    return await getHelpContent('faq');
  }

  /// 연락처 정보를 읽어옵니다.
  static Future<String> getContactContent() async {
    return await getHelpContent('contact');
  }

  /// 사용 가능한 도움말 타입 목록을 반환합니다.
  static List<String> getAvailableHelpTypes() {
    return _helpFileMap.keys.toList();
  }

  /// 도움말 파일 경로를 반환합니다.
  static String? getHelpFilePath(String helpType) {
    return _helpFileMap[helpType];
  }
} 