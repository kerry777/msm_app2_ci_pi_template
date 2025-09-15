import 'package:flutter/material.dart';

class DatePickerField extends StatelessWidget {
  final String label;
  final DateTime initialDate;
  final Function(DateTime) onDateSelected;

  const DatePickerField({
    super.key,
    required this.label,
    required this.initialDate,
    required this.onDateSelected,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final DateTime? picked = await showDatePicker(
          context: context,
          initialDate: initialDate,
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
        );
        if (picked != null) {
          onDateSelected(picked);
        }
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          suffixIcon: const Icon(Icons.calendar_today),
        ),
        child: Text(
          '${initialDate.year}-${initialDate.month.toString().padLeft(2, '0')}-${initialDate.day.toString().padLeft(2, '0')}',
        ),
      ),
    );
  }
} 