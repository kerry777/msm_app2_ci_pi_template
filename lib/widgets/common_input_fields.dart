import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class QuantityInputField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String label;
  final VoidCallback onNext;
  final Function(String) onChanged;

  const QuantityInputField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.label,
    required this.onNext,
    required this.onChanged,
  });

  String _formatNumber(String value) {
    if (value.isEmpty || value == '-') return value;
    final isNegative = value.startsWith('-');
    final digits = isNegative ? value.substring(1) : value;
    final number = int.tryParse(digits.replaceAll(',', ''));
    if (number == null) return value;
    final formatted = number.toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
    return isNegative ? '-$formatted' : formatted;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label),
        TextFormField(
          controller: controller,
          focusNode: focusNode,
          keyboardType: const TextInputType.numberWithOptions(signed: true),
          textInputAction: TextInputAction.next,
          onFieldSubmitted: (_) => onNext(),
          decoration: const InputDecoration(
            isDense: true,
            contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          ),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^-?\d*')), // -와 숫자만 허용
            _NegativeNumberInputFormatter(),
          ],
          onTap: () {
            if (controller.text == '0') {
              controller.clear();
            }
          },
          onChanged: (value) {
            // 콤마 없는 값으로 콜백
            final raw = value.replaceAll(',', '');
            onChanged(raw);
            // 콤마 적용된 값으로 표시
            final formatted = _formatNumber(raw);
            if (controller.text != formatted) {
              final selectionIndex = formatted.length;
              controller.value = TextEditingValue(
                text: formatted,
                selection: TextSelection.collapsed(offset: selectionIndex),
              );
            }
          },
        ),
      ],
    );
  }
}

/// 첫 글자만 - 허용, 그 외에는 숫자만 허용하는 Formatter
class _NegativeNumberInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    String text = newValue.text;
    if (text.isEmpty) return newValue;
    // 첫 글자만 - 허용, 나머지는 숫자만
    final isNegative = text.startsWith('-');
    final digits = isNegative ? text.substring(1).replaceAll(RegExp(r'[^0-9]'), '') : text.replaceAll(RegExp(r'[^0-9]'), '');
    final result = isNegative ? '-$digits' : digits;
    return TextEditingValue(
      text: result,
      selection: TextSelection.collapsed(offset: result.length),
    );
  }
}

class CardItem extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final EdgeInsetsGeometry? margin;

  const CardItem({
    super.key,
    required this.title,
    required this.children,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: margin ?? const EdgeInsets.only(bottom: 8.0),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      ),
    );
  }
}

class NextTextField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String label;
  final VoidCallback onNext;
  final Function(String) onChanged;
  final TextInputType? keyboardType;

  const NextTextField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.label,
    required this.onNext,
    required this.onChanged,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      keyboardType: keyboardType ?? TextInputType.text,
      textInputAction: TextInputAction.next,
      onFieldSubmitted: (_) => onNext(),
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      ),
      onChanged: onChanged,
    );
  }
} 