import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/font_size_provider.dart';

class FontTestScreen extends StatelessWidget {
  const FontTestScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('폰트 크기 조절 테스트'),
        backgroundColor: Colors.blue,
        actions: [
          // 폰트 크기 조절 버튼
          Consumer<FontSizeProvider>(
            builder: (context, fontProvider, child) {
              return PopupMenuButton<int>(
                icon: Icon(Icons.text_fields, color: Colors.white),
                tooltip: '글자 크기 조절',
                onSelected: (percentage) {
                  fontProvider.setScalePercentage(percentage);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('글자 크기: $percentage%'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 70,
                    child: Row(
                      children: [
                        if (fontProvider.scalePercentage == 70) 
                          Icon(Icons.check, size: 16, color: Colors.blue)
                        else 
                          SizedBox(width: 16),
                        SizedBox(width: 8),
                        Text('작게 (70%)'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 85,
                    child: Row(
                      children: [
                        if (fontProvider.scalePercentage == 85) 
                          Icon(Icons.check, size: 16, color: Colors.blue)
                        else 
                          SizedBox(width: 16),
                        SizedBox(width: 8),
                        Text('약간 작게 (85%)'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 100,
                    child: Row(
                      children: [
                        if (fontProvider.scalePercentage == 100) 
                          Icon(Icons.check, size: 16, color: Colors.blue)
                        else 
                          SizedBox(width: 16),
                        SizedBox(width: 8),
                        Text('보통 (100%)'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 115,
                    child: Row(
                      children: [
                        if (fontProvider.scalePercentage == 115) 
                          Icon(Icons.check, size: 16, color: Colors.blue)
                        else 
                          SizedBox(width: 16),
                        SizedBox(width: 8),
                        Text('약간 크게 (115%)'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 130,
                    child: Row(
                      children: [
                        if (fontProvider.scalePercentage == 130) 
                          Icon(Icons.check, size: 16, color: Colors.blue)
                        else 
                          SizedBox(width: 16),
                        SizedBox(width: 8),
                        Text('크게 (130%)'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 150,
                    child: Row(
                      children: [
                        if (fontProvider.scalePercentage == 150) 
                          Icon(Icons.check, size: 16, color: Colors.blue)
                        else 
                          SizedBox(width: 16),
                        SizedBox(width: 8),
                        Text('매우 크게 (150%)'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 200,
                    child: Row(
                      children: [
                        if (fontProvider.scalePercentage == 200) 
                          Icon(Icons.check, size: 16, color: Colors.blue)
                        else 
                          SizedBox(width: 16),
                        SizedBox(width: 8),
                        Text('거대하게 (200%)'),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
      body: Consumer<FontSizeProvider>(
        builder: (context, fontProvider, child) {
          return Padding(
            padding: EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '현재 폰트 크기: ${fontProvider.scalePercentage}%',
                  style: TextStyle(
                    fontSize: 18.0,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
                SizedBox(height: 20),
                Text(
                  '이것은 제목입니다',
                  style: TextStyle(
                    fontSize: 24.0,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  '이것은 본문 텍스트입니다. 폰트 크기 조절 기능이 정상적으로 작동하는지 테스트해보세요.',
                  style: TextStyle(fontSize: 16.0),
                ),
                SizedBox(height: 10),
                Text(
                  '작은 텍스트 예시입니다.',
                  style: TextStyle(fontSize: 12.0),
                ),
                SizedBox(height: 20),
                Card(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '카드 제목',
                          style: TextStyle(
                            fontSize: 18.0,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          '카드 내용입니다. 여러 종류의 텍스트가 모두 동일한 비율로 크기가 조절되는지 확인해보세요.',
                          style: TextStyle(fontSize: 14.0),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 20),
                Row(
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        fontProvider.decreaseFontSize();
                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.text_decrease, size: 16),
                          SizedBox(width: 4),
                          Text('축소'),
                        ],
                      ),
                    ),
                    SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: () {
                        fontProvider.resetFontSize();
                      },
                      child: Text('기본값'),
                    ),
                    SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: () {
                        fontProvider.increaseFontSize();
                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.text_increase, size: 16),
                          SizedBox(width: 4),
                          Text('확대'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}