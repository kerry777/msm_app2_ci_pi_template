import 'package:flutter/material.dart';

Future<void> saveFile(BuildContext context, List<int> bytes, String fileName) async {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(AppLocalizations.of(context)?.get('web_only_feature') ?? '이 기능은 웹에서만 지원됩니다.')),
  );
} 