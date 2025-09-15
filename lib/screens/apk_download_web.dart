import 'package:flutter/material.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'package:http/http.dart' as http;
import '../l10n/app_localizations.dart';
import '../config/app_config.dart';

class ApkDownloadWidget extends StatefulWidget {
  const ApkDownloadWidget({super.key});

  @override
  State<ApkDownloadWidget> createState() => _ApkDownloadWidgetState();
}

class _ApkDownloadWidgetState extends State<ApkDownloadWidget> {
  bool _isLoading = false;
  String? _message;

  Future<void> _downloadApk() async {
    setState(() {
      _isLoading = true;
      _message = null;
    });

    const apkUrl = AppConfig.apkDownloadUrl;


    try {
      final response = await http.head(Uri.parse(apkUrl));
      if (response.statusCode == 200) {
        html.window.open(apkUrl, '_blank');
        setState(() {
          _isLoading = false;
          _message = AppLocalizations.of(context).get('apk_download_success');
        });
      } else {
        setState(() {
          _isLoading = false;
          _message = AppLocalizations.of(context).get('apk_download_not_found');
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _message = AppLocalizations.of(context).get('apk_download_network_error');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context).get('apk_download_title'))),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                AppLocalizations.of(context).get('apk_download_guide'),
                style: const TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              _isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton.icon(
                      icon: const Icon(Icons.download),
                      label: Text(AppLocalizations.of(context).get('apk_download_button')),
                      onPressed: _downloadApk,
                    ),
              if (_message != null) ...[
                const SizedBox(height: 24),
                Text(
                  _message!,
                  style: const TextStyle(color: Colors.blue),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

Widget getApkDownloadWidget(BuildContext context) {
  return ApkDownloadWidget();
} 