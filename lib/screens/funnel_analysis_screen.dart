import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/language_provider.dart';
import '../utils/translations.dart';

class FunnelAnalysisScreen extends StatefulWidget {
  const FunnelAnalysisScreen({super.key});

  @override
  State<FunnelAnalysisScreen> createState() => _FunnelAnalysisScreenState();
}

class _FunnelAnalysisScreenState extends State<FunnelAnalysisScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Consumer<LanguageProvider>(
          builder: (context, languageProvider, child) {
            return Text(
              Translations.get('funnel_analysis', languageProvider.currentLanguage) ?? 'Funnel 분석',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            );
          },
        ),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.filter_list,
              size: 100,
              color: Colors.grey,
            ),
            SizedBox(height: 20),
            Text(
              'Funnel 분석',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            SizedBox(height: 10),
            Text(
              '기능 구현 예정',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}