import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';

class CommonBottomAppBar extends StatelessWidget {
  final VoidCallback? onLoadData;
  final bool isLoading;
  const CommonBottomAppBar({super.key, this.onLoadData, this.isLoading = false});

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 900;
    return BottomAppBar(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: AppLocalizations.of(context).get('previous'),
            onPressed: () {
              if (Navigator.canPop(context)) {
                // 이전 화면이 로그인인지 확인
                final previousRoute = ModalRoute.of(context);
                if (previousRoute != null && previousRoute.settings.name == '/login') {
                  // 이전이 로그인이면 홈(대시보드)으로 이동
                  Navigator.of(context).pushNamedAndRemoveUntil('/main', (route) => false);
                } else {
                  Navigator.pop(context);
                }
              } else {
                // pop할 수 없으면 홈(대시보드)으로 이동
                Navigator.of(context).pushNamedAndRemoveUntil('/main', (route) => false);
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.home),
            tooltip: AppLocalizations.of(context).get('home_dashboard'),
            onPressed: () {
              Navigator.of(context).pushNamedAndRemoveUntil('/main', (route) => false);
            },
          ),
        ],
      ),
    );
  }
} 