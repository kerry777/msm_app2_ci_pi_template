import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/font_size_provider.dart';

class SimpleFontControl extends StatelessWidget {
  const SimpleFontControl({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<FontSizeProvider>(
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
                    Icon(Icons.check, size: 16)
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
                    Icon(Icons.check, size: 16)
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
                    Icon(Icons.check, size: 16)
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
                    Icon(Icons.check, size: 16)
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
                    Icon(Icons.check, size: 16)
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
                    Icon(Icons.check, size: 16)
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
                    Icon(Icons.check, size: 16)
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
    );
  }
}