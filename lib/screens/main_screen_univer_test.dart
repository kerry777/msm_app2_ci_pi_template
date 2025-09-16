import 'package:flutter/material.dart';
import 'test_univer_screen.dart';

class MainScreenUniverTest extends StatelessWidget {
  const MainScreenUniverTest({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MSM - Univer 테스트'),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
      ),
      body: TestUniverScreen(),
    );
  }
}

// main.dart에 추가할 임시 앱
class UniverTestApp extends StatelessWidget {
  const UniverTestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MSM Univer Test',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const MainScreenUniverTest(),
      debugShowCheckedModeBanner: false,
    );
  }
}