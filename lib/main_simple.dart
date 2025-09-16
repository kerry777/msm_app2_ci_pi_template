import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const SimpleApp());
}

class SimpleApp extends StatelessWidget {
  const SimpleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Simple Test App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const TestScreen(),
    );
  }
}

class TestScreen extends StatefulWidget {
  const TestScreen({super.key});

  @override
  State<TestScreen> createState() => _TestScreenState();
}

class _TestScreenState extends State<TestScreen> {
  String _status = 'Ready';

  Future<void> _testApi() async {
    setState(() {
      _status = 'Testing API...';
    });

    try {
      final response = await http.post(
        Uri.parse('http://localhost:4100/api/v1/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: '{"empCd":"msmtest","password":"0001"}',
      );
      print('API Response: ${response.statusCode}');
      print('API Body: ${response.body}');

      setState(() {
        _status = 'API Response: ${response.statusCode}';
      });
    } catch (e) {
      print('API Error: $e');
      setState(() {
        _status = 'API Error: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Test App'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Flutter Test App',
              style: TextStyle(fontSize: 24),
            ),
            const SizedBox(height: 20),
            const Text(
              'API Backend: http://localhost:4100',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 20),
            Text(
              _status,
              style: const TextStyle(fontSize: 14, color: Colors.green),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _testApi,
              child: const Text('Test API'),
            ),
          ],
        ),
      ),
    );
  }
}