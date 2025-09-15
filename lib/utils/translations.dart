
class Translations {
  static const Map<String, Map<String, String>> _translations = {
    'ko': {
      'tab_1': '목록',
      'tab_2': '등록',
      'tab_3': '조회',
      'tab_4': '설정',
      'item.release.hospital': '병원',
      'item.release.cell': '셀',
      'item.release.date': '출고일',
      'item.release.item': '품목',
      'item.release.quantity': '수량',
      'item.release.note': '비고',
      'item.release.register': '등록',
      'funnel_analysis': 'Funnel 분석',
    },
    'en': {
      'tab_1': 'List',
      'tab_2': 'Register',
      'tab_3': 'Search',
      'tab_4': 'Settings',
      'item.release.hospital': 'Hospital',
      'item.release.cell': 'Cell',
      'item.release.date': 'Release Date',
      'item.release.item': 'Item',
      'item.release.quantity': 'Quantity',
      'item.release.note': 'Note',
      'item.release.register': 'Register',
      'funnel_analysis': 'Funnel Analysis',
    }
  };

  static String get(String key, String language) {
    return _translations[language]?[key] ?? key;
  }
} 