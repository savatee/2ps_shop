import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'features/login/splash_screen.dart';

/// เริ่มต้น Flutter และเปิดแอป 2PS Shop.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const TwoPsShopApp());
}

class TwoPsShopApp extends StatelessWidget {
  const TwoPsShopApp({super.key});

  /// หน้าที่: สร้าง UI ของหน้าจอหรือวิดเจ็ตใน main (คลาส TwoPsShopApp).
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
