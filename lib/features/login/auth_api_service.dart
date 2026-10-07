import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../core/config/app_config.dart';
import 'login_user_model.dart';

class AuthResult {
  final bool success;
  final String message;
  final LoginUserModel? user;

  AuthResult({required this.success, required this.message, this.user});
}

class AuthApiService {
  // URL ต่อจาก AppConfig ที่เดียว (…/Final/backend/api/auth/…)
  static const String _loginUrl = '${AppConfig.authApiBaseUrl}/login.php';
  static const String _registerUrl = '${AppConfig.authApiBaseUrl}/register.php';
  static const Duration _timeout = Duration(seconds: 15);

  static const Map<String, String> _formHeaders = {
    'Content-Type': 'application/x-www-form-urlencoded',
    'Accept': 'application/json',
  };

  /// แปลงผลตอบกลับเป็น JSON Map
  /// ถ้าเซิร์ฟเวอร์ตอบเป็นหน้า HTML (เช่น 404/500) จะคืน null แทนที่จะ error
  static Map<String, dynamic>? _decodeJson(String body) {
    try {
      final dynamic decoded = jsonDecode(body);
      return decoded is Map<String, dynamic> ? decoded : null;
    } on FormatException {
      return null;
    }
  }

  static AuthResult _invalidResponse(http.Response response) {
    return AuthResult(
      success: false,
      message:
          'เซิร์ฟเวอร์ตอบกลับผิดรูปแบบ (รหัส ${response.statusCode}) '
          'ตรวจสอบที่อยู่ API และการตั้งค่าฐานข้อมูลบนเซิร์ฟเวอร์',
    );
  }

  Future<AuthResult> login({
    required String email,
    required String password,
    required String expectedRole,
  }) async {
    final Uri uri = Uri.parse(_loginUrl);

    try {
      final http.Response response = await http
          .post(
            uri,
            headers: _formHeaders,
            body: {'email': email, 'password': password},
          )
          .timeout(_timeout);

      debugPrint('Login URL: $uri');
      debugPrint('Login Status: ${response.statusCode}');

      if (response.body.isEmpty) {
        return AuthResult(
          success: false,
          message:
              'เซิร์ฟเวอร์ไม่ส่งข้อมูลกลับ (HTTP ${response.statusCode}) กรุณาตรวจสอบ PHP error log และการตั้งค่าฐานข้อมูล',
        );
      }

      final Map<String, dynamic>? decodedJson = _decodeJson(response.body);

      if (decodedJson == null) {
        return _invalidResponse(response);
      }

      final bool isSuccess = decodedJson['success'] == true;
      final String message =
          decodedJson['message']?.toString() ?? 'เกิดข้อผิดพลาด';

      if (!isSuccess) {
        return AuthResult(success: false, message: message);
      }

      if (decodedJson['user'] is! Map<String, dynamic>) {
        return AuthResult(success: false, message: 'ไม่พบข้อมูลผู้ใช้');
      }

      final LoginUserModel user = LoginUserModel.fromJson(
        decodedJson['user'] as Map<String, dynamic>,
      );

      if (user.apiToken.isEmpty) {
        return AuthResult(
          success: false,
          message:
              'เซิร์ฟเวอร์ยังไม่รองรับเซสชันที่ปลอดภัย กรุณาติดต่อผู้ดูแลระบบ',
        );
      }

      if (user.isBlocked) {
        return AuthResult(success: false, message: 'บัญชีนี้ถูกระงับการใช้งาน');
      }

      if (user.isInactive) {
        return AuthResult(
          success: false,
          message: 'บัญชีนี้ยังไม่ได้เปิดใช้งาน',
        );
      }

      // ตรวจสอบ Role ให้ตรงกับหน้าที่เลือกมา
      if (user.role.toLowerCase() != expectedRole.toLowerCase()) {
        return AuthResult(
          success: false,
          message:
              'บัญชีนี้ไม่ใช่สิทธิ์ของ $expectedRole (สิทธิ์จริงของคุณคือ: ${user.role})',
        );
      }

      return AuthResult(success: true, message: message, user: user);
    } on SocketException {
      return AuthResult(
        success: false,
        message: 'ไม่สามารถเชื่อมต่อเซิร์ฟเวอร์ได้ ตรวจสอบอินเทอร์เน็ต',
      );
    } on TimeoutException {
      return AuthResult(
        success: false,
        message: 'การเชื่อมต่อหมดเวลา (Timeout)',
      );
    } catch (e) {
      return AuthResult(success: false, message: 'เกิดข้อผิดพลาด: $e');
    }
  }

  Future<AuthResult> register({
    required String name,
    required String email,
    required String password,
    required String phone,
    required String role,
  }) async {
    final Uri uri = Uri.parse(_registerUrl);

    try {
      final http.Response response = await http
          .post(
            uri,
            headers: _formHeaders,
            body: {
              'name': name,
              'email': email,
              'password': password,
              'phone': phone,
              'role': role,
            },
          )
          .timeout(_timeout);

      debugPrint('Register URL: $uri');
      debugPrint('Register Status: ${response.statusCode}');
      debugPrint('Register Response: ${response.body}');

      if (response.body.isEmpty) {
        return AuthResult(
          success: false,
          message: 'ไม่ได้รับข้อมูลตอบกลับจากเซิร์ฟเวอร์',
        );
      }

      final Map<String, dynamic>? decodedJson = _decodeJson(response.body);

      if (decodedJson == null) {
        return _invalidResponse(response);
      }

      final bool isSuccess = decodedJson['success'] == true;
      final String message =
          decodedJson['message']?.toString() ?? 'เกิดข้อผิดพลาด';

      return AuthResult(success: isSuccess, message: message);
    } on SocketException {
      return AuthResult(
        success: false,
        message: 'ไม่สามารถเชื่อมต่อเซิร์ฟเวอร์ได้',
      );
    } on TimeoutException {
      return AuthResult(
        success: false,
        message: 'การเชื่อมต่อหมดเวลา (Timeout)',
      );
    } catch (e) {
      return AuthResult(success: false, message: 'เกิดข้อผิดพลาด: $e');
    }
  }
}
