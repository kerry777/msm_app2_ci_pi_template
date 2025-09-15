import 'package:flutter/material.dart';
import 'apk_download_web.dart'
    if (dart.library.io) 'apk_download_mobile_stub.dart';

class ApkDownloadScreen extends StatelessWidget {
  const ApkDownloadScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return getApkDownloadWidget(context);
  }
} 