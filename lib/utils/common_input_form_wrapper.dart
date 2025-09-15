import 'package:flutter/material.dart';

class CommonInputFormWrapper extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  const CommonInputFormWrapper({
    required this.child,
    this.padding,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: (padding ?? EdgeInsets.zero).add(
        EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      ),
      child: child,
    );
  }
}

// safeString: null/type 오류, 콘솔 추적, 안전 문자열 변환
String safeString(dynamic value, [String fieldName = '']) {
  if (value == null) {
    if (fieldName.isNotEmpty) print('DEBUG: $fieldName is null');
    return '';
  }
  try {
    return value.toString();
  } catch (e) {
    if (fieldName.isNotEmpty) print('DEBUG: $fieldName 변환 오류: $e, value=$value');
    return '';
  }
} 