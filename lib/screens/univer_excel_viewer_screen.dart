import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'dart:html' as html;
import 'dart:ui_web' as ui;

class UniverExcelViewerScreen extends StatefulWidget {
  final String? excelFilePath;
  final String title;

  const UniverExcelViewerScreen({
    super.key,
    this.excelFilePath,
    this.title = 'Excel 뷰어',
  });

  @override
  State<UniverExcelViewerScreen> createState() => _UniverExcelViewerScreenState();
}

class _UniverExcelViewerScreenState extends State<UniverExcelViewerScreen> {
  late final WebViewController? _controller;
  bool _isReady = false;
  String _status = '초기화 중...';
  final String _iframeId = 'univer-iframe-${DateTime.now().millisecondsSinceEpoch}';

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      _initializeWebIframe();
    } else {
      _initializeWebView();
    }
  }

  void _initializeWebIframe() {
    // 웹용 iframe 등록
    ui.platformViewRegistry.registerViewFactory(
      _iframeId,
      (int viewId) {
        final iframe = html.IFrameElement()
          ..src = 'http://localhost/msm/univer_final_solution.html'
          ..style.border = 'none'
          ..style.width = '100%'
          ..style.height = '100%'
          ..allowFullscreen = true;

        // 메시지 리스너 추가
        html.window.addEventListener('message', (event) {
          final messageEvent = event as html.MessageEvent;
          if (messageEvent.data is String) {
            _handleWebViewMessage(messageEvent.data as String);
          }
        });

        return iframe;
      },
    );

    setState(() {
      _isReady = true;
      _status = '준비 완료';
    });
  }

  void _initializeWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..addJavaScriptChannel(
        'FlutterChannel',
        onMessageReceived: (JavaScriptMessage message) {
          _handleWebViewMessage(message.message);
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            if (progress < 100) {
              setState(() {
                _status = '로딩 중... ($progress%)';
              });
            }
          },
          onPageStarted: (String url) {
            setState(() {
              _status = '페이지 로딩 중...';
            });
          },
          onPageFinished: (String url) {
            setState(() {
              _status = 'Univer 초기화 중...';
            });

            // 페이지 로드 완료 후 잠시 기다린 후 Excel 파일 로드
            if (widget.excelFilePath != null) {
              Future.delayed(const Duration(seconds: 2), () {
                _loadExcelFile(widget.excelFilePath!);
              });
            }
          },
          onWebResourceError: (WebResourceError error) {
            setState(() {
              _status = '로딩 오류: ${error.description}';
            });
          },
        ),
      )
      ..loadRequest(Uri.parse('http://localhost/msm/univer_final_solution.html'));
  }

  void _handleWebViewMessage(String message) {
    debugPrint('📨 WebView 메시지: $message');

    if (message == 'univer_ready') {
      setState(() {
        _isReady = true;
        _status = '준비 완료';
      });
    } else if (message.startsWith('excel_loaded:')) {
      setState(() {
        _status = 'Excel 파일 로드 완료';
      });
      _showSnackBar('Excel 파일이 성공적으로 로드되었습니다', Colors.green);
    } else if (message.startsWith('excel_error:')) {
      final error = message.substring('excel_error:'.length);
      setState(() {
        _status = 'Excel 로드 실패';
      });
      _showSnackBar('Excel 로드 실패: $error', Colors.red);
    } else if (message == 'pdf_export_initiated') {
      _showSnackBar('PDF 내보내기를 시작했습니다', Colors.blue);
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

  Future<void> _loadExcelFile(String filePath) async {
    if (!_isReady) {
      _showSnackBar('Univer가 아직 준비되지 않았습니다', Colors.orange);
      return;
    }

    try {
      setState(() {
        _status = 'Excel 파일 로드 중...';
      });

      await _controller?.runJavaScript('''
        window.postMessage({
          action: 'loadExcel',
          data: { filePath: '$filePath' }
        }, '*');
      ''');
    } catch (e) {
      _showSnackBar('Excel 로드 요청 실패: $e', Colors.red);
      setState(() {
        _status = '준비 완료';
      });
    }
  }

  Future<void> _exportToPDF() async {
    if (!_isReady) {
      _showSnackBar('Univer가 아직 준비되지 않았습니다', Colors.orange);
      return;
    }

    try {
      await _controller?.runJavaScript('''
        window.postMessage({
          action: 'exportPDF'
        }, '*');
      ''');
    } catch (e) {
      _showSnackBar('PDF 내보내기 실패: $e', Colors.red);
    }
  }

  Future<void> _pingWebView() async {
    try {
      await _controller?.runJavaScript('''
        window.postMessage({
          action: 'ping'
        }, '*');
      ''');
    } catch (e) {
      _showSnackBar('통신 테스트 실패: $e', Colors.red);
    }
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
          // PDF 내보내기 버튼
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'PDF로 내보내기',
            onPressed: _isReady ? _exportToPDF : null,
          ),
          // 새로고침 버튼
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '새로고침',
            onPressed: () {
              _controller?.reload();
              setState(() {
                _isReady = false;
                _status = '새로고침 중...';
              });
            },
          ),
          // 메뉴 버튼
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'ping':
                  _pingWebView();
                  break;
                case 'reload_excel':
                  if (widget.excelFilePath != null) {
                    _loadExcelFile(widget.excelFilePath!);
                  }
                  break;
              }
            },
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem(
                value: 'ping',
                child: Row(
                  children: [
                    Icon(Icons.network_ping),
                    SizedBox(width: 8),
                    Text('통신 테스트'),
                  ],
                ),
              ),
              if (widget.excelFilePath != null)
                const PopupMenuItem(
                  value: 'reload_excel',
                  child: Row(
                    children: [
                      Icon(Icons.file_open),
                      SizedBox(width: 8),
                      Text('Excel 다시 로드'),
                    ],
                  ),
                ),
            ],
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
              color: _isReady ? Colors.green[50] : Colors.orange[50],
              border: Border(
                bottom: BorderSide(
                  color: _isReady ? Colors.green[200]! : Colors.orange[200]!,
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _isReady ? Icons.check_circle : Icons.hourglass_empty,
                  color: _isReady ? Colors.green[600] : Colors.orange[600],
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  _status,
                  style: TextStyle(
                    color: _isReady ? Colors.green[700] : Colors.orange[700],
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          // WebView
          Expanded(
            child: _controller != null ? WebViewWidget(controller: _controller!) : const Center(child: CircularProgressIndicator()),
          ),
        ],
      ),
      floatingActionButton: widget.excelFilePath == null
          ? FloatingActionButton(
              onPressed: _isReady
                  ? () {
                      // 샘플 Excel 파일 로드 (테스트용)
                      _loadExcelFile('assets/excel_templates/sample.xlsx');
                    }
                  : null,
              backgroundColor: _isReady ? Colors.blue[600] : Colors.grey,
              child: const Icon(Icons.file_open, color: Colors.white),
            )
          : null,
    );
  }
}