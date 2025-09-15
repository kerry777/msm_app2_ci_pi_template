import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';

Widget getApkDownloadWidget(BuildContext context) {
  return Center(
    child: Text(AppLocalizations.of(context).get('not_supported_on_mobile') ?? '이 화면은 모바일 빌드에서는 지원되지 않습니다.'),
  );
} 