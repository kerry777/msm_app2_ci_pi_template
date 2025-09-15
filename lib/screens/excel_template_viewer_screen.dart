import 'package:flutter/material.dart';

class ExcelTemplateViewerScreen extends StatefulWidget {
  const ExcelTemplateViewerScreen({super.key});

  @override
  State<ExcelTemplateViewerScreen> createState() => _ExcelTemplateViewerScreenState();
}

class _ExcelTemplateViewerScreenState extends State<ExcelTemplateViewerScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Excel Template Viewer'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.integration_instructions, size: 64, color: Colors.blue),
            SizedBox(height: 16),
            Text(
              'Excel Template Viewer가 Syncfusion Excel Viewer로 교체되었습니다.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 8),
            Text(
              '메뉴에서 "Syncfusion Excel Viewer"를 사용해주세요.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}