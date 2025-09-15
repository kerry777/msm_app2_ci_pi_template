import 'package:flutter/material.dart';

class CenterNotice extends StatelessWidget {
  final String message;
  final String? subMessage;
  final IconData? icon;
  final double iconSize;
  final Color? iconColor;
  final Color? textColor;
  final Widget? action;

  const CenterNotice({
    super.key,
    required this.message,
    this.subMessage,
    this.icon,
    this.iconSize = 44,
    this.iconColor,
    this.textColor,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null)
            Icon(icon, size: iconSize, color: iconColor ?? Colors.grey[400]),
          if (icon != null) SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: textColor ?? Colors.grey[600],
              fontWeight: FontWeight.w500,
              decoration: TextDecoration.none,
            ),
          ),
          if (subMessage != null) ...[
            SizedBox(height: 8),
            Text(
              subMessage!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
          if (action != null) ...[
            SizedBox(height: 16),
            action!,
          ],
        ],
      ),
    );
  }
} 