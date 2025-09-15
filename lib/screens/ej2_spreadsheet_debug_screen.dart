import 'package:flutter/material.dart';
import 'dart:html' as html;
import 'dart:ui_web' as ui;
import 'dart:convert';
import 'dart:js' as js;

class EJ2SpreadsheetDebugScreen extends StatefulWidget {
  const EJ2SpreadsheetDebugScreen({super.key});

  @override
  State<EJ2SpreadsheetDebugScreen> createState() => _EJ2SpreadsheetDebugScreenState();
}

class _EJ2SpreadsheetDebugScreenState extends State<EJ2SpreadsheetDebugScreen> {
  static const String _viewType = 'ej2-spreadsheet-debug-view';
  static bool _isRegistered = false;
  String _status = 'Initializing...';
  String? _selectedTemplate;
  final List<String> _debugLog = [];
  bool _showDebugPanel = true;
  
  final List<Map<String, String>> _templates = [
    {'value': 'MEK_SALES_TEMPLATE_PI.xlsx', 'label': 'Proforma Invoice Template (PI)'},
    {'value': 'MEK_SALES_TEMPLATE_CI.xlsx', 'label': 'Commercial Invoice Template (CI)'},
    {'value': 'MEK_SALES_TEMPLATE_PL.xlsx', 'label': 'Packing List Template (PL)'},
    {'value': 'MEK_SALES_TEMPLATE_QT_EN.xlsx', 'label': 'Quotation Template (English)'},
    {'value': 'MEK_SALES_TEMPLATE_QT_KR.xlsx', 'label': 'Quotation Template (Korean)'},
    {'value': 'MEK_SALES_TEMPLATE_QT_AS.xlsx', 'label': 'Quotation Template (Asian)'},
  ];

  @override
  void initState() {
    super.initState();
    _addDebugLog('🚀 Initializing EJ2 Spreadsheet Debug Screen');
    _registerViewFactory();
    _setupMessageListener();
    _setupConsoleCapture();
  }

  void _addDebugLog(String message) {
    setState(() {
      _debugLog.add('${DateTime.now().toIso8601String().substring(11, 19)} $message');
      if (_debugLog.length > 50) {
        _debugLog.removeAt(0);
      }
    });
    print('🐛 DEBUG: $message');
  }

  void _setupConsoleCapture() {
    // Capture JavaScript console messages
    js.context.callMethod('eval', ['''
      window.originalConsoleLog = console.log;
      window.originalConsoleError = console.error;
      window.originalConsoleWarn = console.warn;
      
      console.log = function(...args) {
        window.originalConsoleLog.apply(console, args);
        if (window.dartDebugLog) {
          window.dartDebugLog('📝 JS LOG: ' + args.join(' '));
        }
      };
      
      console.error = function(...args) {
        window.originalConsoleError.apply(console, args);
        if (window.dartDebugLog) {
          window.dartDebugLog('❌ JS ERROR: ' + args.join(' '));
        }
      };
      
      console.warn = function(...args) {
        window.originalConsoleWarn.apply(console, args);
        if (window.dartDebugLog) {
          window.dartDebugLog('⚠️ JS WARN: ' + args.join(' '));
        }
      };
    ''']);

    js.context['dartDebugLog'] = js.allowInterop((String message) {
      _addDebugLog(message);
    });
  }

  void _registerViewFactory() {
    if (!_isRegistered) {
      try {
        _addDebugLog('📦 Registering view factory');
        _defineGlobalFunctions();
        
        final htmlContent = _createSpreadsheetHTML();
        
        final html.DivElement container = html.DivElement()
          ..style.width = '100%'
          ..style.height = '100%'
          ..style.border = 'none'
          ..setInnerHtml(htmlContent, treeSanitizer: html.NodeTreeSanitizer.trusted);

        ui.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
          _addDebugLog('🏭 Creating view instance with ID: $viewId');
          return container;
        });
        
        _isRegistered = true;
        _addDebugLog('✅ View factory registered successfully');
      } catch (error) {
        _addDebugLog('❌ Error registering view factory: $error');
      }
    }
  }

  void _defineGlobalFunctions() {
    _addDebugLog('🔧 Defining global JavaScript functions');

    js.context['testAssetAccess'] = js.allowInterop(() {
      _addDebugLog('🧪 Testing asset access...');
      
      for (var template in _templates) {
        final templateFile = template['value']!;
      final testPaths = [
        'assets/$templateFile',
        '/assets/$templateFile',
        './assets/$templateFile',
        '../assets/$templateFile',
      ];
        
        for (var path in testPaths) {
          js.context.callMethod('eval', ['''
            fetch('$path')
              .then(response => {
                console.log('✅ Asset accessible at: $path (Status: ' + response.status + ')');
                if (window.dartDebugLog) {
                  window.dartDebugLog('✅ Found $templateFile at: $path');
                }
              })
              .catch(error => {
                console.log('❌ Asset not found at: $path');
              });
          ''']);
        }
      }
    });

    js.context['loadTemplate'] = js.allowInterop(() async {
      final select = html.document.getElementById('templateSelect') as html.SelectElement?;
      final templateFile = select?.value ?? '';
      
      if (templateFile.isEmpty) {
        _addDebugLog('❌ No template selected');
        return;
      }
      
      _addDebugLog('📂 Attempting to load: $templateFile');
      _updateStatus('Loading template: $templateFile');
      
      final testPaths = [
        'assets/$templateFile',
        '/assets/$templateFile',
        './assets/$templateFile',
        '../assets/$templateFile',
      ];
      
      for (var path in testPaths) {
        try {
          _addDebugLog('🔍 Trying path: $path');
          final response = await html.window.fetch(path);
          
          if (response.ok) {
            _addDebugLog('✅ Template found at: $path');
            final blob = await response.blob();
            final file = html.File([blob], templateFile);
            
            js.context['tempExcelFile'] = file;
            
            js.context.callMethod('eval', ['''
              try {
                console.log('📊 Loading Excel file into spreadsheet...');
                if (window.spreadsheet) {
                  if (typeof window.spreadsheet.open === 'function') {
                    window.spreadsheet.open({file: window.tempExcelFile});
                    console.log('✅ Template loaded successfully');
                  } else if (typeof window.spreadsheet.openFromUrl === 'function') {
                    window.spreadsheet.openFromUrl('$path');
                    console.log('✅ Template loaded via URL');
                  } else {
                    console.log('❌ No open method available on spreadsheet object');
                    console.log('Available methods:', Object.keys(window.spreadsheet));
                  }
                } else {
                  console.log('❌ Spreadsheet object not available');
                }
              } catch (jsError) {
                console.error('❌ JavaScript error in template loading:', jsError);
              }
            ''']);
            
            _updateStatus('Template loaded: $templateFile');
            _addDebugLog('✅ Template loading completed');
            return;
          } else {
            _addDebugLog('❌ Response not OK for: $path (Status: ${response.status})');
          }
        } catch (error) {
          _addDebugLog('❌ Error loading from $path: $error');
        }
      }
      
      _addDebugLog('❌ Template not found in any location');
      _updateStatus('Error: Template not found');
      _createDefaultTemplate(templateFile);
    });

    js.context['checkSpreadsheetStatus'] = js.allowInterop(() {
      js.context.callMethod('eval', ['''
        try {
          console.log('🔍 Checking spreadsheet status...');
          if (typeof ej !== 'undefined') {
            console.log('✅ EJ2 library loaded:', ej);
            if (ej.spreadsheet) {
              console.log('✅ EJ2 Spreadsheet module available');
            } else {
              console.log('❌ EJ2 Spreadsheet module not available');
            }
          } else {
            console.log('❌ EJ2 library not loaded');
          }
          
          if (window.spreadsheet) {
            console.log('✅ Spreadsheet instance available');
            console.log('Spreadsheet methods:', Object.keys(window.spreadsheet));
          } else {
            console.log('❌ Spreadsheet instance not available');
          }
          
          const spreadsheetElement = document.getElementById('spreadsheet');
          if (spreadsheetElement) {
            console.log('✅ Spreadsheet DOM element found');
          } else {
            console.log('❌ Spreadsheet DOM element not found');
          }
        } catch (error) {
          console.error('❌ Error checking spreadsheet status:', error);
        }
      ''']);
    });

    js.context['updateStatus'] = js.allowInterop((String message) {
      _updateStatus(message);
    });

    _addDebugLog('✅ Global functions defined');
  }

  void _updateStatus(String message) {
    setState(() {
      _status = message;
    });
    _addDebugLog('📊 Status: $message');
    
    final statusEl = html.document.getElementById('status');
    statusEl?.text = message;
  }

  void _createDefaultTemplate(String templateType) {
    _addDebugLog('🏗️ Creating default template for: $templateType');
    // Keep existing implementation
    _updateStatus('Default template created: $templateType');
  }

  void _setupMessageListener() {
    html.window.addEventListener('message', (html.Event event) {
      final html.MessageEvent messageEvent = event as html.MessageEvent;
      
      try {
        final data = json.decode(messageEvent.data.toString());
        _addDebugLog('📨 Received message: ${data.toString()}');
        
        if (data['action'] == 'statusUpdate') {
          setState(() {
            _status = data['message'] ?? 'Status updated';
          });
        }
      } catch (error) {
        _addDebugLog('❌ Error parsing message: $error');
      }
    });
  }

  void _testAssetAccess() {
    _addDebugLog('🧪 Starting asset access test');
    js.context.callMethod('testAssetAccess');
  }

  void _checkSpreadsheetStatus() {
    _addDebugLog('🔍 Checking spreadsheet status');
    js.context.callMethod('checkSpreadsheetStatus');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.bug_report, color: Colors.white),
            SizedBox(width: 8),
            Text(
              'EJ2 Spreadsheet Debug',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        backgroundColor: Colors.red.shade700,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            tooltip: 'Test Asset Access',
            onPressed: _testAssetAccess,
          ),
          IconButton(
            icon: Icon(Icons.info),
            tooltip: 'Check Spreadsheet Status',
            onPressed: _checkSpreadsheetStatus,
          ),
          IconButton(
            icon: Icon(_showDebugPanel ? Icons.visibility_off : Icons.visibility),
            tooltip: 'Toggle Debug Panel',
            onPressed: () => setState(() => _showDebugPanel = !_showDebugPanel),
          ),
        ],
      ),
      
      body: Column(
        children: [
          // Status Bar
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
            ),
            child: Text(
              'Status: $_status',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            ),
          ),
          
          // Main Content
          Expanded(
            child: Row(
              children: [
                // Spreadsheet
                Expanded(
                  flex: _showDebugPanel ? 3 : 1,
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    margin: EdgeInsets.all(8),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: HtmlElementView(viewType: _viewType),
                    ),
                  ),
                ),
                
                // Debug Panel
                if (_showDebugPanel)
                  Expanded(
                    flex: 1,
                    child: Container(
                      margin: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(4),
                        color: Colors.grey.shade50,
                      ),
                      child: Column(
                        children: [
                          Container(
                            padding: EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.red.shade100,
                              borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.bug_report, size: 16),
                                SizedBox(width: 8),
                                Text('Debug Log', style: TextStyle(fontWeight: FontWeight.bold)),
                                Spacer(),
                                IconButton(
                                  icon: Icon(Icons.clear, size: 16),
                                  onPressed: () => setState(() => _debugLog.clear()),
                                  tooltip: 'Clear Log',
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: ListView.builder(
                              itemCount: _debugLog.length,
                              itemBuilder: (context, index) {
                                final log = _debugLog[index];
                                Color textColor = Colors.black87;
                                if (log.contains('❌')) {
                                  textColor = Colors.red;
                                } else if (log.contains('⚠️')) textColor = Colors.orange;
                                else if (log.contains('✅')) textColor = Colors.green;
                                
                                return Container(
                                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  child: Text(
                                    log,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontFamily: 'Courier New',
                                      color: textColor,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _createSpreadsheetHTML() {
    return '''
    <div style="width: 100%; height: 100%; font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;">
      <!-- CSS -->
      <link href="https://cdn.syncfusion.com/ej2/material.css" rel="stylesheet" />
      <link href="https://cdn.syncfusion.com/ej2/27.1.48/ej2-spreadsheet/styles/material.css" rel="stylesheet" />
      
      <!-- JavaScript -->
      <script src="https://cdn.syncfusion.com/ej2/27.1.48/dist/ej2.min.js"></script>
      
      <!-- Debug Toolbar -->
      <div style="background: #f0f8ff; border-bottom: 1px solid #e0e0e0; padding: 10px; display: flex; gap: 10px; align-items: center; flex-wrap: wrap;">
        <div style="display: flex; gap: 10px; align-items: center;">
          <label for="templateSelect">Template:</label>
          <select id="templateSelect" style="padding: 6px 12px; border: 1px solid #ccc; border-radius: 4px; font-size: 14px;">
            <option value="">Select Template...</option>
            <option value="MEK_SALES_TEMPLATE_PI.xlsx">Proforma Invoice (PI)</option>
            <option value="MEK_SALES_TEMPLATE_CI.xlsx">Commercial Invoice (CI)</option>
            <option value="MEK_SALES_TEMPLATE_PL.xlsx">Packing List (PL)</option>
            <option value="MEK_SALES_TEMPLATE_QT_EN.xlsx">Quotation (English)</option>
            <option value="MEK_SALES_TEMPLATE_QT_KR.xlsx">Quotation (Korean)</option>
            <option value="MEK_SALES_TEMPLATE_QT_AS.xlsx">Quotation (Asian)</option>
          </select>
          <button onclick="loadTemplate()" style="padding: 8px 16px; border: 1px solid #007ACC; background: #007ACC; color: white; border-radius: 4px; cursor: pointer; font-size: 14px;">Load Template</button>
        </div>
        
        <button onclick="checkSpreadsheetStatus()" style="padding: 8px 16px; border: 1px solid #28a745; background: #28a745; color: white; border-radius: 4px; cursor: pointer; font-size: 14px;">Check Status</button>
        <button onclick="testAssetAccess()" style="padding: 8px 16px; border: 1px solid #ffc107; background: #ffc107; color: black; border-radius: 4px; cursor: pointer; font-size: 14px;">Test Assets</button>
        
        <div id="status" style="margin-left: auto; color: #666; font-size: 12px;">Ready</div>
      </div>
      
      <!-- Spreadsheet Container -->
      <div id="spreadsheet" style="height: calc(100% - 70px); width: 100%;"></div>
      
      <script>
        function initializeSpreadsheet() {
          try {
            console.log('🚀 Initializing Syncfusion EJ2 Spreadsheet...');
            
            // Check if EJ2 is loaded
            if (typeof ej === 'undefined') {
              console.error('❌ EJ2 library not loaded');
              if (window.updateStatus) window.updateStatus('Error: EJ2 library not loaded');
              return;
            }
            
            if (!ej.spreadsheet || !ej.spreadsheet.Spreadsheet) {
              console.error('❌ EJ2 Spreadsheet module not available');
              if (window.updateStatus) window.updateStatus('Error: EJ2 Spreadsheet module not available');
              return;
            }
            
            console.log('✅ EJ2 library and Spreadsheet module loaded');
            
            window.spreadsheet = new ej.spreadsheet.Spreadsheet({
              height: '100%',
              width: '100%',
              allowOpen: true,
              allowSave: true,
              allowEditing: true,
              allowFormatting: true,
              allowDataValidation: true,
              allowConditionalFormat: true,
              allowHyperlink: true,
              allowMerge: true,
              allowWrap: true,
              allowSorting: true,
              allowFiltering: true,
              allowInsert: true,
              allowDelete: true,
              allowFreeze: true,
              allowFind: true,
              allowResize: true,
              allowChart: true,
              allowImage: true,
              
              sheets: [{
                name: 'Sheet1',
                ranges: [{ dataSource: [] }]
              }],
              
              created: function() {
                console.log('✅ EJ2 Spreadsheet created successfully');
                if (window.updateStatus) window.updateStatus('EJ2 Spreadsheet initialized');
              },
              
              actionBegin: function(args) {
                console.log('⚡ Action begin:', args.action);
                if (args.action === 'save' && window.updateStatus) {
                  window.updateStatus('Saving document...');
                }
              },
              
              actionComplete: function(args) {
                console.log('✅ Action complete:', args.action);
                if (window.updateStatus) {
                  if (args.action === 'save') {
                    window.updateStatus('Document saved');
                  } else if (args.action === 'open') {
                    window.updateStatus('Template loaded successfully');
                  }
                }
              },
              
              openComplete: function(args) {
                console.log('📂 Open complete:', args);
                if (window.updateStatus) {
                  window.updateStatus('File opened successfully');
                }
              },
              
              openFailure: function(args) {
                console.error('❌ Open failure:', args);
                if (window.updateStatus) {
                  window.updateStatus('Error opening file: ' + (args.response || 'Unknown error'));
                }
              }
            });
            
            window.spreadsheet.appendTo('#spreadsheet');
            console.log('✅ Spreadsheet appended to DOM');
            
          } catch (error) {
            console.error('❌ Error initializing spreadsheet:', error);
            if (window.updateStatus) {
              window.updateStatus('Error initializing spreadsheet: ' + error.message);
            }
          }
        }
        
        // Wait for DOM and EJ2 to be ready
        function waitForEJ2AndInit() {
          if (typeof ej !== 'undefined' && ej.spreadsheet && ej.spreadsheet.Spreadsheet) {
            console.log('✅ EJ2 ready, initializing spreadsheet');
            initializeSpreadsheet();
          } else {
            console.log('⏳ Waiting for EJ2 to load...');
            setTimeout(waitForEJ2AndInit, 100);
          }
        }
        
        document.addEventListener('DOMContentLoaded', function() {
          console.log('📄 DOM loaded, starting initialization');
          waitForEJ2AndInit();
        });
        
        // Fallback initialization
        if (document.readyState !== 'loading') {
          console.log('📄 DOM already ready, starting initialization');
          waitForEJ2AndInit();
        }
      </script>
    </div>
    ''';
  }

  @override
  void dispose() {
    // Restore original console functions
    js.context.callMethod('eval', ['''
      if (window.originalConsoleLog) {
        console.log = window.originalConsoleLog;
        console.error = window.originalConsoleError;
        console.warn = window.originalConsoleWarn;
      }
    ''']);
    super.dispose();
  }
}