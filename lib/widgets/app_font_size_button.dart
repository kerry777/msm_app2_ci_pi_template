import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/font_size_provider.dart';

/// AppBar에서 사용할 간단한 폰트 크기 조절 버튼
class AppFontSizeButton extends StatelessWidget {
  final Color iconColor;
  
  const AppFontSizeButton({
    super.key,
    this.iconColor = Colors.white,
  });
  
  @override
  Widget build(BuildContext context) {
    return Consumer<FontSizeProvider>(
      builder: (context, fontProvider, child) {
        return PopupMenuButton<int>(
          icon: Icon(Icons.text_fields, color: iconColor),
          tooltip: '글자 크기 조절',
          onSelected: (percentage) {
            fontProvider.setScalePercentage(percentage);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('글자 크기가 $percentage%로 변경되었습니다'),
                duration: Duration(seconds: 2),
                backgroundColor: Colors.blue,
              ),
            );
          },
          itemBuilder: (context) => [
            _buildMenuItem(fontProvider, 70, '작게 (70%)'),
            _buildMenuItem(fontProvider, 85, '약간 작게 (85%)'),
            _buildMenuItem(fontProvider, 100, '보통 (100%)'),
            _buildMenuItem(fontProvider, 115, '약간 크게 (115%)'),
            _buildMenuItem(fontProvider, 130, '크게 (130%)'),
            _buildMenuItem(fontProvider, 150, '매우 크게 (150%)'),
            _buildMenuItem(fontProvider, 200, '거대하게 (200%)'),
            PopupMenuDivider(),
            PopupMenuItem(
              value: -1, // 특별한 값으로 리셋을 구분
              child: Row(
                children: [
                  Icon(Icons.refresh, size: 16, color: Colors.grey[600]),
                  SizedBox(width: 8),
                  Text('기본값으로 리셋'),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
  
  PopupMenuItem<int> _buildMenuItem(FontSizeProvider fontProvider, int percentage, String label) {
    final isSelected = fontProvider.scalePercentage == percentage;
    
    return PopupMenuItem(
      value: percentage,
      child: Row(
        children: [
          SizedBox(
            width: 20,
            child: isSelected 
                ? Icon(Icons.check, size: 16, color: Colors.blue)
                : null,
          ),
          SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? Colors.blue : null,
            ),
          ),
        ],
      ),
    );
  }
}