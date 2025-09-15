import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';

class DialogUtils {
  static Future<bool?> showConfirmDialog(
    BuildContext context, {
    required String title,
    required String content,
    String? confirmText,
    String? cancelText,
  }) async {
    final localizations = AppLocalizations.of(context);
    
    return await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(content),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(cancelText ?? localizations.get('cancel')),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(confirmText ?? localizations.get('confirm')),
            ),
          ],
        );
      },
    );
  }

  static void showErrorDialog(
    BuildContext context,
    String title,
    String message,
  ) {
    final localizations = AppLocalizations.of(context);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(localizations.get('confirm')),
            ),
          ],
        );
      },
    );
  }

  static void showInfoDialog(
    BuildContext context,
    String title,
    String message,
  ) {
    final localizations = AppLocalizations.of(context);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(localizations.get('confirm')),
            ),
          ],
        );
      },
    );
  }

  static Future<bool?> showConfirmDialogWithCustomText(
    BuildContext context, {
    required String title,
    required String content,
    String? confirmText,
    String? cancelText,
  }) async {
    final localizations = AppLocalizations.of(context);
    
    return await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(content),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(cancelText ?? localizations.get('cancel')),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(confirmText ?? localizations.get('confirm')),
            ),
          ],
        );
      },
    );
  }
} 