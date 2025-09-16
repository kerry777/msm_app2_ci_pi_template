import 'package:flutter/material.dart';
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

class SimpleUniverTestScreen extends StatefulWidget {
  final String? excelFilePath;
  final String title;

  const SimpleUniverTestScreen({
    super.key,
    this.excelFilePath,
    this.title = 'Excel 뷰어 테스트',
  });

  @override
  State<SimpleUniverTestScreen> createState() => _SimpleUniverTestScreenState();
}

class _SimpleUniverTestScreenState extends State<SimpleUniverTestScreen> {
  late String _iframeId;
  String _status = '초기화 중...';

  @override
  void initState() {
    super.initState();
    _iframeId = 'univer-iframe-${DateTime.now().millisecondsSinceEpoch}';
    _createIframe();
  }

  void _createIframe() {
    // iframe 요소 생성
    final iframe = html.IFrameElement()
      ..src = 'assets/univer/index.html'
      ..style.border = 'none'
      ..style.width = '100%'
      ..style.height = '100%'
      ..allowFullscreen = true;

    // Flutter에 iframe 등록
    ui_web.platformViewRegistry.registerViewFactory(
      _iframeId,
      (int viewId) => iframe,
    );

    // 메시지 리스너 설정
    html.window.addEventListener('message', _handleMessage);

    setState(() {
      _status = 'iframe 준비 완료';
    });

    // Excel 파일 로딩 (지연)
    if (widget.excelFilePath != null) {
      Future.delayed(const Duration(seconds: 3), () {
        _loadExcelFile(widget.excelFilePath!);
      });
    }
  }

  void _handleMessage(html.Event event) {
    final messageEvent = event as html.MessageEvent;
    final data = messageEvent.data;

    if (data is String) {
      if (data.contains('univer_ready')) {
        setState(() {
          _status = 'Univer 준비 완료';
        });
      } else if (data.contains('excel_loaded')) {
        setState(() {
          _status = 'Excel 파일 로드 완료';
        });
        _showSnackBar('Excel 파일이 성공적으로 로드되었습니다', Colors.green);
      } else if (data.contains('excel_error')) {
        setState(() {
          _status = 'Excel 로드 실패';
        });
        _showSnackBar('Excel 로드 실패', Colors.red);
      }
    }
  }

  void _showSnackBar(String message, Color color) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: color,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _loadExcelFile(String filePath) {
    final iframe = html.document.getElementById(_iframeId) as html.IFrameElement?;
    if (iframe?.contentWindow != null) {
      iframe!.contentWindow!.postMessage({
        'action': 'loadExcel',
        'data': {'filePath': filePath}
      }, '*');

      setState(() {
        _status = 'Excel 파일 로딩 중...';
      });
    }
  }

  @override
  void dispose() {
    html.window.removeEventListener('message', _handleMessage);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
        elevation: 2,
        actions: [
          // 새로고침 버튼
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '새로고침',
            onPressed: () {
              _createIframe();
            },
          ),
          // 테스트 버튼
          IconButton(
            icon: const Icon(Icons.play_arrow),
            tooltip: 'Excel 로드 테스트',
            onPressed: () {
              if (widget.excelFilePath != null) {
                _loadExcelFile(widget.excelFilePath!);
              } else {
                _loadExcelFile('assets/excel_templates/quotation_kr.xlsx');
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // 상태 표시줄
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              border: Border(
                bottom: BorderSide(
                  color: Colors.blue[200]!,
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline,
                  color: Colors.blue,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  _status,
                  style: TextStyle(
                    color: Colors.blue[700],
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          // iframe 컨테이너
          Expanded(
            child: HtmlElementView(
              viewType: _iframeId,
            ),
          ),
        ],
      ),
    );
  }
}