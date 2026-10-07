import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../core/config/app_config.dart';
import '../../core/network/session.dart';

/// เรียก API ฝั่งผู้ดูแลระบบ (backend/api/admin/*.php)
class AdminApiService {
  static const String baseUrl = AppConfig.adminApiBaseUrl;
  static const Duration _timeout = Duration(seconds: 10);

  // ---------------------------------------------------------------
  // ตัวช่วยกลาง (แทนโค้ดที่เคยเขียนซ้ำในทุกเมธอด)
  // ---------------------------------------------------------------

  /// แปลงข้อความตอบกลับเป็น JSON (ตัดข้อความขยะก่อนเครื่องหมาย '{' ถ้ามี)
  static dynamic _decode(String body) {
    var text = body.trim();
    final start = text.indexOf('{');
    if (start > 0) text = text.substring(start);
    return json.decode(text);
  }

  static bool _isSuccess(dynamic decoded) =>
      decoded is Map &&
      (decoded['status'] == 'success' || decoded['success'] == true);

  /// GET แล้วคืนค่า JSON เมื่อสำเร็จ ไม่เช่นนั้นคืน null
  static Future<Map<String, dynamic>?> _get(
    String path, {
    Map<String, String> query = const {},
  }) async {
    final uri = Uri.parse(
      '$baseUrl/$path',
    ).replace(queryParameters: query.isEmpty ? null : query);
    final response = await http
        .get(uri, headers: Session.authorizationHeaders)
        .timeout(_timeout);
    if (response.statusCode != 200) return null;
    final decoded = _decode(response.body);
    return _isSuccess(decoded) ? Map<String, dynamic>.from(decoded) : null;
  }

  /// POST แบบ JSON แล้วคืน true เมื่อเซิร์ฟเวอร์ตอบสำเร็จ
  static Future<bool> _postJson(String path, Map<String, dynamic> body) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/$path'),
          headers: {
            ...Session.authorizationHeaders,
            'Content-Type': 'application/json',
          },
          body: json.encode(body),
        )
        .timeout(_timeout);
    if (response.statusCode != 200) return false;
    return _isSuccess(_decode(response.body));
  }

  // ---------------------------------------------------------------
  // Dashboard / รายงาน
  // ---------------------------------------------------------------

  /// ดึงสถิติหน้า Dashboard
  static Future<Map<String, dynamic>?> getDashboardStats() async {
    try {
      final res = await _get('dashboard.php');
      return res?['data'] as Map<String, dynamic>?;
    } catch (e) {
      debugPrint('>>> getDashboardStats error: $e');
      return null;
    }
  }

  /// ดึงรายงานสรุปยอดขายตามหมวดหมู่
  static Future<Map<String, dynamic>?> getSalesReport() async {
    try {
      final res = await _get('reports.php');
      return res?['data'] as Map<String, dynamic>?;
    } catch (e) {
      debugPrint('>>> getSalesReport error: $e');
      return null;
    }
  }

  // ---------------------------------------------------------------
  // สินค้า
  // ---------------------------------------------------------------

  /// ดึงรายการสินค้า รองรับกรอง status, หมวดหมู่ (categoryIds) และคำค้นหา
  static Future<Map<String, dynamic>> getProducts({
    String status = 'all',
    List<int> categoryIds = const [],
    String search = '',
  }) async {
    Map<String, dynamic> empty() => {'categories': [], 'products': []};
    try {
      final res = await _get(
        'products.php',
        query: {
          if (status.isNotEmpty && status != 'all') 'status': status,
          if (categoryIds.isNotEmpty) 'category_ids': categoryIds.join(','),
          if (search.trim().isNotEmpty) 'search': search.trim(),
        },
      );
      final data = res?['data'];
      return data is Map<String, dynamic> ? data : empty();
    } catch (e) {
      debugPrint('>>> getProducts error: $e');
      return empty();
    }
  }

  /// อนุมัติ / ปฏิเสธสินค้า
  /// status: 'approved' (หรือ 'active') / 'rejected'
  static Future<bool> updateProductStatus(int productId, String status) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/products.php'),
            headers: {
              ...Session.authorizationHeaders,
              'Accept': 'application/json',
            },
            body: {'product_id': productId.toString(), 'status': status},
          )
          .timeout(_timeout);
      if (response.statusCode != 200) return false;
      return _isSuccess(_decode(response.body));
    } catch (e) {
      debugPrint('>>> updateProductStatus error: $e');
      return false;
    }
  }

  // ---------------------------------------------------------------
  // ผู้ใช้งาน
  // ---------------------------------------------------------------

  /// ดึงรายชื่อผู้ใช้ พร้อมกรองบทบาท สถานะ และค้นหา
  static Future<List<dynamic>> getUsers({
    String role = 'all',
    String status = 'all',
    String search = '',
  }) async {
    try {
      final res = await _get(
        'users.php',
        query: {
          if (role != 'all') 'role': role,
          if (status != 'all') 'status': status,
          if (search.trim().isNotEmpty) 'search': search.trim(),
        },
      );
      return (res?['data'] as List<dynamic>?) ?? [];
    } catch (e) {
      debugPrint('>>> getUsers error: $e');
      return [];
    }
  }

  /// อัปเดตสถานะผู้ใช้ (active / suspended)
  static Future<bool> updateUserStatus(int userId, String newStatus) async {
    try {
      return await _postJson('users.php', {
        'user_id': userId,
        'action': 'update_status',
        'status': newStatus,
      });
    } catch (e) {
      debugPrint('>>> updateUserStatus error: $e');
      return false;
    }
  }

  /// เปลี่ยนบทบาทผู้ใช้
  static Future<bool> updateUserRole(int userId, String newRole) async {
    try {
      return await _postJson('users.php', {
        'user_id': userId,
        'action': 'update_role',
        'role': newRole,
      });
    } catch (e) {
      debugPrint('>>> updateUserRole error: $e');
      return false;
    }
  }
}
