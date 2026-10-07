import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const primary = Color(0xFF1554B8);
  static const primaryDark = Color(0xFF0B2A55);
  static const primaryLight = Color(0xFFEAF2FC);
  static const accent = Color(0xFFF59E0B);
  static const background = Color(0xFFF5F6F8);
  static const border = Color(0xFFE2E8F0);
  static const textDark = Color(0xFF172033);
  static const textGrey = Color(0xFF64748B);
  static const danger = Color(0xFFDC2626);
  static const dangerBg = Color(0xFFFEE2E2);

  static const sellerNavy = Color(0xFF0D356B);
  static const sellerNavyDark = Color(0xFF172554);
  static const sellerNavyLight = Color(0xFFEAF1FA);
  static const sellerBackground = Color(0xFFF5F6FA);
  static const sellerBackgroundLight = Color(0xFFF8FAFC);
  static const sellerTextPrimary = Color(0xFF0F172A);
  static const sellerTextSecondary = Color(0xFF64748B);
  static const sellerTextLight = Color(0xFF94A3B8);
  static const sellerBorder = Color(0xFFE2E8F0);
  static const sellerSuccess = Color(0xFF16A34A);
  static const sellerSuccessLight = Color(0xFFE8F5E9);
  static const sellerWarning = Color(0xFFF59E0B);
  static const sellerWarningLight = Color(0xFFFFF3E0);
  static const sellerDangerLight = Color(0xFFFEE2E2);
  static const sellerPurple = Color(0xFF7C3AED);
  static const sellerPurpleLight = Color(0xFFF3E5F5);
  static const sellerBlue = Color(0xFF1976D2);
  static const sellerBlueLight = Color(0xFFE3F2FD);
  static const sellerOrange = Color(0xFFEA580C);
  static const sellerPink = Color(0xFFC2185B);
}

class AppRadius {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 18;
  static const double pill = 999;
  static const double compact = 10;
  static const double card = 14;
  static const double large = 16;
  static const double xl = 20;
}

class AppBreakpoints {
  static const double tablet = 700;
  static const double desktop = 1100;
  /// หน้าที่: คำนวณระยะขอบแนวนอนตามความกว้างหน้าจอเพื่อปรับ layout ให้เหมาะกับอุปกรณ์ (คลาส AppBreakpoints).
  static double horizontalPadding(double width) => width >= desktop
      ? 32
      : width >= tablet
      ? 24
      : 16;
  /// หน้าที่: เลือกจำนวนคอลัมน์สินค้าให้เหมาะกับความกว้างหน้าจอ (คลาส AppBreakpoints).
  static int gridColumns(double width) => width >= desktop
      ? 5
      : width >= tablet
      ? 4
      : 2;
}

class AppTheme {
  static ThemeData get light {
    final baseTheme = ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
      scaffoldBackgroundColor: AppColors.background,
      useMaterial3: true,
    );
    return baseTheme.copyWith(
      textTheme: GoogleFonts.promptTextTheme(baseTheme.textTheme),
      primaryTextTheme: GoogleFonts.promptTextTheme(baseTheme.primaryTextTheme),
    );
  }

  static ThemeData get seller {
    return light.copyWith(
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.sellerNavy,
        primary: AppColors.sellerNavy,
      ),
      scaffoldBackgroundColor: AppColors.sellerBackground,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.sellerNavy,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppRadius.md)),
          borderSide: BorderSide(color: AppColors.sellerBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppRadius.md)),
          borderSide: BorderSide(color: AppColors.sellerBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppRadius.md)),
          borderSide: BorderSide(color: AppColors.sellerNavy, width: 1.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.sellerNavy,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
      ),
    );
  }
}

class Validators {
  /// หน้าที่: ตรวจว่าช่องกรอกข้อมูลไม่ว่าง และคืนข้อความเตือนหากไม่ได้กรอก (คลาส Validators).
  static String? required(
    String? value, {
    String message = 'กรุณากรอกข้อมูล',
  }) => value == null || value.trim().isEmpty ? message : null;

  /// หน้าที่: ตรวจชื่อผู้รับให้มีเฉพาะตัวอักษรและเครื่องหมายที่อนุญาต (คลาส Validators).
  static String? recipientName(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'กรุณากรอกชื่อ-นามสกุลผู้รับ';
    if (!RegExp(r"^[ก-ฮะ-ฺเ-๎A-Za-z .'-]+$").hasMatch(text)) {
      return 'ชื่อผู้รับกรอกได้เฉพาะตัวอักษร';
    }
    return null;
  }

  /// หน้าที่: ตรวจข้อความที่อยู่ให้มีเฉพาะตัวอักษรและเครื่องหมายที่อนุญาต (คลาส Validators).
  static String? addressText(String? value, {required String label}) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'กรุณากรอก$label';
    if (!RegExp(r"^[ก-ฮะ-ฺเ-๎A-Za-z .'-]+$").hasMatch(text)) {
      return '$labelกรอกได้เฉพาะตัวอักษร';
    }
    return null;
  }

  /// หน้าที่: ตรวจรูปแบบที่อยู่และกำหนดให้มีเลขที่บ้าน (คลาส Validators).
  static String? addressLine(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'กรุณากรอกที่อยู่ (บ้านเลขที่, ถนน)';
    if (!RegExp(r"^[\u0E00-\u0E7FA-Za-z0-9 .,#/\-]+$").hasMatch(text)) {
      return 'ที่อยู่กรอกได้เฉพาะตัวอักษร ตัวเลข และเครื่องหมาย / , . - #';
    }
    if (!RegExp(r'[0-9]').hasMatch(text)) {
      return 'กรุณาระบุบ้านเลขที่เป็นตัวเลขด้วย';
    }
    return null;
  }

  /// หน้าที่: ตรวจว่าเบอร์โทรศัพท์ขึ้นต้นด้วย 0 และมีตัวเลขครบ 10 หลัก (คลาส Validators).
  static String? thaiPhone(String? value) {
    final phone = value?.trim() ?? '';
    if (!RegExp(r'^0[0-9]{9}$').hasMatch(phone)) {
      return 'เบอร์โทรศัพท์ต้องเป็นตัวเลข 10 หลักและขึ้นต้นด้วย 0';
    }
    return null;
  }

  /// หน้าที่: ตรวจว่ารหัสไปรษณีย์เป็นตัวเลข 5 หลัก (คลาส Validators).
  static String? postalCode(String? value) {
    final code = value?.trim() ?? '';
    if (!RegExp(r'^[0-9]{5}$').hasMatch(code)) {
      return 'รหัสไปรษณีย์ต้องเป็นตัวเลข 5 หลัก';
    }
    return null;
  }

  /// หน้าที่: ตรวจว่ารหัสผ่านมีความยาวอย่างน้อย 6 ตัวอักษร (คลาส Validators).
  static String? password(String? value) => value == null || value.length < 6
      ? 'รหัสผ่านต้องมีอย่างน้อย 6 ตัวอักษร'
      : null;
  /// หน้าที่: ตรวจว่าค่าที่กรอกเป็นตัวเลขมากกว่า 0 (คลาส Validators).
  static String? positiveNumber(
    String? value, {
    String message = 'กรุณากรอกตัวเลขที่มากกว่า 0',
  }) {
    final number = double.tryParse(value ?? '');
    return number == null || number <= 0 ? message : null;
  }
}
