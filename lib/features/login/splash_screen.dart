import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/app_router.dart';
import '../../core/network/api_client.dart';
import '../../core/network/session.dart';
import 'login_user_model.dart';
import 'role_selection_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  /// หน้าที่: เตรียมสถานะเริ่มต้นของหน้าจอและเริ่มโหลดข้อมูลที่จำเป็น (คลาส _SplashScreenState).
  @override
  void initState() {
    super.initState();
    Timer(const Duration(seconds: 2), () async {
      if (!mounted) return;

      try {
        final prefs = await SharedPreferences.getInstance();
        final rememberLogin = prefs.getBool('remember_login') ?? false;
        final userId = prefs.getInt('remembered_user_id');
        final rememberedRole = prefs.getString('remembered_role');
        final token = prefs.getString('api_token') ?? '';

        if (rememberLogin &&
            userId != null &&
            userId > 0 &&
            rememberedRole != null &&
            token.isNotEmpty) {
          Session.token = token;
          final userResult = await ApiClient.getUser(userId);
          final data = userResult['data'];
          final userMap = data is Map
              ? Map<String, dynamic>.from(data)
              : (userResult['user'] is Map
                    ? Map<String, dynamic>.from(userResult['user'] as Map)
                    : null);

          if (userMap != null && mounted) {
            final user = LoginUserModel.fromJson(userMap);
            if (user.userId > 0 && user.role.isNotEmpty) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => AppRouter.screenForUser(user),
                ),
              );
              return;
            }
          }
        }
      } catch (_) {
        // ถ้าไม่สามารถโหลดข้อมูลผู้ใช้กลับมา ให้กลับไปหน้าเลือกบทบาท
      }

      Session.token = '';
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const RoleSelectionScreen()),
      );
    });
  }

  /// หน้าที่: สร้าง UI ของหน้าจอหรือวิดเจ็ตใน splash screen (คลาส _SplashScreenState).
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Image.asset(
          'assets/images/2ps_shop_logo.png',
          width: 280,
          height: 280,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}
