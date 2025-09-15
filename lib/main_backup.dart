import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'providers/auth_provider.dart';
import 'providers/language_provider.dart';
import 'providers/favorites_provider.dart';
import 'providers/menu_display_provider.dart';
import 'screens/login_screen.dart';
import 'l10n/app_localizations.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final authProvider = AuthProvider();
  await authProvider.initialize();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
        ChangeNotifierProvider(create: (_) => LanguageProvider()),
        ChangeNotifierProvider(create: (_) => FavoritesProvider()),
        ChangeNotifierProvider(create: (_) => MenuDisplayProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => LanguageProvider()),
        ChangeNotifierProvider(create: (_) => FavoritesProvider()),
        ChangeNotifierProvider(create: (_) => MenuDisplayProvider()),
      ],
      child: Consumer2<AuthProvider, LanguageProvider>(
        builder: (context, authProvider, languageProvider, child) {
          return MaterialApp(
            title: 'MSM App',
            theme: ThemeData(
              primarySwatch: Colors.blue,
              visualDensity: VisualDensity.adaptivePlatformDensity,
              textTheme: const TextTheme(
                displayLarge: TextStyle(fontSize: 14.0),
                displayMedium: TextStyle(fontSize: 14.0),
                displaySmall: TextStyle(fontSize: 14.0),
                headlineLarge: TextStyle(fontSize: 14.0),
                headlineMedium: TextStyle(fontSize: 14.0),
                headlineSmall: TextStyle(fontSize: 14.0),
                titleLarge: TextStyle(fontSize: 14.0),
                titleMedium: TextStyle(fontSize: 14.0),
                titleSmall: TextStyle(fontSize: 14.0),
                bodyLarge: TextStyle(fontSize: 14.0),
                bodyMedium: TextStyle(fontSize: 14.0),
                bodySmall: TextStyle(fontSize: 12.0),
                labelLarge: TextStyle(fontSize: 14.0),
                labelMedium: TextStyle(fontSize: 12.0),
                labelSmall: TextStyle(fontSize: 10.0),
              ),
            ),
            localizationsDelegates: [
              const AppLocalizationsDelegate(),
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [
              Locale('ko', ''),
              Locale('en', ''),
            ],
            locale: Locale(languageProvider.currentLanguage, ''),
            home: const LoginScreen(),
          );
        },
      ),
    );
  }
}
