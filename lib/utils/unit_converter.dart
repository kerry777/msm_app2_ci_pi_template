import 'dart:math';

class UnitConverter {
  static const Map<String, double> _currencyRates = {
    'KRW': 1.0,
    'USD': 0.00076,
    'EUR': 0.00070,
    'JPY': 0.11,
    'CNY': 0.0054,
  };

  static const Map<String, double> _weightUnits = {
    'g': 1.0,
    'kg': 1000.0,
    't': 1000000.0,
    'oz': 28.3495,
    'lb': 453.592,
  };

  static const Map<String, double> _volumeUnits = {
    'ml': 1.0,
    'l': 1000.0,
    'gallon': 3785.41,
    'fl_oz': 29.5735,
  };

  static const Map<String, double> _lengthUnits = {
    'mm': 1.0,
    'cm': 10.0,
    'm': 1000.0,
    'km': 1000000.0,
    'inch': 25.4,
    'ft': 304.8,
  };

  static double convertCurrency(double amount, String from, String to) {
    if (!_currencyRates.containsKey(from) || !_currencyRates.containsKey(to)) {
      throw ArgumentError('Unsupported currency code');
    }

    final fromRate = _currencyRates[from]!;
    final toRate = _currencyRates[to]!;

    return amount * (toRate / fromRate);
  }

  static double convertWeight(double amount, String from, String to) {
    if (!_weightUnits.containsKey(from) || !_weightUnits.containsKey(to)) {
      throw ArgumentError('Unsupported weight unit');
    }

    final fromRate = _weightUnits[from]!;
    final toRate = _weightUnits[to]!;

    return amount * fromRate / toRate;
  }

  static double convertVolume(double amount, String from, String to) {
    if (!_volumeUnits.containsKey(from) || !_volumeUnits.containsKey(to)) {
      throw ArgumentError('Unsupported volume unit');
    }

    final fromRate = _volumeUnits[from]!;
    final toRate = _volumeUnits[to]!;

    return amount * fromRate / toRate;
  }

  static double convertLength(double amount, String from, String to) {
    if (!_lengthUnits.containsKey(from) || !_lengthUnits.containsKey(to)) {
      throw ArgumentError('Unsupported length unit');
    }

    final fromRate = _lengthUnits[from]!;
    final toRate = _lengthUnits[to]!;

    return amount * fromRate / toRate;
  }

  static String formatCurrency(double amount, {String currency = 'KRW', int decimals = 0}) {
    final symbols = {
      'KRW': '₩',
      'USD': '\$',
      'EUR': '€',
      'JPY': '¥',
      'CNY': '¥',
    };

    final symbol = symbols[currency] ?? currency;
    final formatted = _formatNumber(amount, decimals: decimals);

    if (currency == 'KRW' || currency == 'JPY') {
      return '$symbol$formatted';
    } else {
      return '$symbol$formatted';
    }
  }

  static String formatWeight(double amount, String unit, {int decimals = 2}) {
    final formatted = _formatNumber(amount, decimals: decimals);
    return '$formatted$unit';
  }

  static String formatVolume(double amount, String unit, {int decimals = 2}) {
    final formatted = _formatNumber(amount, decimals: decimals);
    return '$formatted$unit';
  }

  static String formatLength(double amount, String unit, {int decimals = 2}) {
    final formatted = _formatNumber(amount, decimals: decimals);
    return '$formatted$unit';
  }

  static String formatPercentage(double ratio, {int decimals = 1}) {
    final percentage = ratio * 100;
    return '${_formatNumber(percentage, decimals: decimals)}%';
  }

  static String formatNumberWithSuffix(double number, {int decimals = 1}) {
    if (number.abs() >= 1e12) {
      return '${_formatNumber(number / 1e12, decimals: decimals)}조';
    } else if (number.abs() >= 1e8) {
      return '${_formatNumber(number / 1e8, decimals: decimals)}억';
    } else if (number.abs() >= 1e4) {
      return '${_formatNumber(number / 1e4, decimals: decimals)}만';
    } else if (number.abs() >= 1e3) {
      return '${_formatNumber(number / 1e3, decimals: decimals)}천';
    } else {
      return _formatNumber(number, decimals: decimals);
    }
  }

  static String _formatNumber(double number, {int decimals = 0}) {
    if (decimals == 0) {
      return number.round().toString().replaceAllMapped(
        RegExp(r'\B(?=(\d{3})+(?!\d))'),
        (match) => ',',
      );
    } else {
      final formatted = number.toStringAsFixed(decimals);
      final parts = formatted.split('.');
      final integerPart = parts[0].replaceAllMapped(
        RegExp(r'\B(?=(\d{3})+(?!\d))'),
        (match) => ',',
      );
      return '$integerPart.${parts[1]}';
    }
  }

  static double parseNumberWithSuffix(String value) {
    final cleanValue = value.replaceAll(RegExp(r'[^\d.조억만천kmgtlbozKMGT-]'), '');

    if (cleanValue.contains('조')) {
      final number = double.tryParse(cleanValue.replaceAll('조', '')) ?? 0;
      return number * 1e12;
    } else if (cleanValue.contains('억')) {
      final number = double.tryParse(cleanValue.replaceAll('억', '')) ?? 0;
      return number * 1e8;
    } else if (cleanValue.contains('만')) {
      final number = double.tryParse(cleanValue.replaceAll('만', '')) ?? 0;
      return number * 1e4;
    } else if (cleanValue.contains('천')) {
      final number = double.tryParse(cleanValue.replaceAll('천', '')) ?? 0;
      return number * 1e3;
    } else if (cleanValue.toUpperCase().contains('K')) {
      final number = double.tryParse(cleanValue.toUpperCase().replaceAll('K', '')) ?? 0;
      return number * 1e3;
    } else if (cleanValue.toUpperCase().contains('M')) {
      final number = double.tryParse(cleanValue.toUpperCase().replaceAll('M', '')) ?? 0;
      return number * 1e6;
    } else if (cleanValue.toUpperCase().contains('G')) {
      final number = double.tryParse(cleanValue.toUpperCase().replaceAll('G', '')) ?? 0;
      return number * 1e9;
    } else if (cleanValue.toUpperCase().contains('T')) {
      final number = double.tryParse(cleanValue.toUpperCase().replaceAll('T', '')) ?? 0;
      return number * 1e12;
    }

    return double.tryParse(cleanValue.replaceAll(',', '')) ?? 0;
  }

  static String autoFormatNumber(double number, {String? preferredUnit}) {
    if (preferredUnit != null) {
      switch (preferredUnit.toLowerCase()) {
        case 'currency':
        case 'money':
          return formatCurrency(number);
        case 'percentage':
        case 'percent':
          return formatPercentage(number);
        case 'weight':
          if (number >= 1000) {
            return formatWeight(convertWeight(number, 'g', 'kg'), 'kg');
          }
          return formatWeight(number, 'g');
        case 'volume':
          if (number >= 1000) {
            return formatVolume(convertVolume(number, 'ml', 'l'), 'l');
          }
          return formatVolume(number, 'ml');
      }
    }

    return formatNumberWithSuffix(number);
  }

  static List<String> getSupportedCurrencies() {
    return _currencyRates.keys.toList();
  }

  static List<String> getSupportedWeightUnits() {
    return _weightUnits.keys.toList();
  }

  static List<String> getSupportedVolumeUnits() {
    return _volumeUnits.keys.toList();
  }

  static List<String> getSupportedLengthUnits() {
    return _lengthUnits.keys.toList();
  }

  static Map<String, String> getUnitDisplayNames() {
    return {
      // Currency
      'KRW': '원 (₩)',
      'USD': '달러 (\$)',
      'EUR': '유로 (€)',
      'JPY': '엔 (¥)',
      'CNY': '위안 (¥)',

      // Weight
      'g': '그램 (g)',
      'kg': '킬로그램 (kg)',
      't': '톤 (t)',
      'oz': '온스 (oz)',
      'lb': '파운드 (lb)',

      // Volume
      'ml': '밀리리터 (ml)',
      'l': '리터 (l)',
      'gallon': '갤런 (gallon)',
      'fl_oz': '플루이드 온스 (fl oz)',

      // Length
      'mm': '밀리미터 (mm)',
      'cm': '센티미터 (cm)',
      'm': '미터 (m)',
      'km': '킬로미터 (km)',
      'inch': '인치 (inch)',
      'ft': '피트 (ft)',
    };
  }
}

class UnitConversionHistory {
  final List<UnitConversion> _history = [];

  void addConversion(UnitConversion conversion) {
    _history.add(conversion);
    if (_history.length > 100) {
      _history.removeAt(0);
    }
  }

  List<UnitConversion> getHistory() {
    return List.unmodifiable(_history.reversed);
  }

  void clearHistory() {
    _history.clear();
  }
}

class UnitConversion {
  final double originalValue;
  final String originalUnit;
  final double convertedValue;
  final String convertedUnit;
  final String conversionType;
  final DateTime timestamp;

  UnitConversion({
    required this.originalValue,
    required this.originalUnit,
    required this.convertedValue,
    required this.convertedUnit,
    required this.conversionType,
    required this.timestamp,
  });

  @override
  String toString() {
    return '$originalValue $originalUnit → $convertedValue $convertedUnit';
  }
}