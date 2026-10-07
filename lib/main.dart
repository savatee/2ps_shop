import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'features/login/splash_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const TwoPsShopApp());
}

class TwoPsShopApp extends StatelessWidget {
  const TwoPsShopApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '2PS Shop',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const SplashScreen(),
    );
  }
}
