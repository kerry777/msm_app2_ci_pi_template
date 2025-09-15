import 'package:flutter/material.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;

  const CustomAppBar({
    super.key,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
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
      title: Text(title),
      centerTitle: true,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
} 