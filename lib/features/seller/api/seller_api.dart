import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../../core/config/app_config.dart';
import '../../../core/network/session.dart';
import '../../../core/utils/image_utils.dart';

class SellerApi {
  // ============================================================
  // BASE URL
  // ============================================================

  static const String baseUrl = AppConfig.sellerApiUrl;

  static const Duration _timeout = Duration(seconds: 15);

  // ============================================================
  // PARSE RESPONSE
  // ============================================================

  static Map<String, dynamic> _parse(String body) {
    final cleanBody = body.trim();

    if (cleanBody.isEmpty) {
      throw Exception('Server ไม่ส่งข้อมูลกลับมา');
    }

    dynamic decoded;

    try {
      decoded = jsonDecode(cleanBody);
    } catch (e) {
      debugPrint('==========================================');
      debugPrint('JSON PARSE ERROR');
      debugPrint('ERROR: $e');
      debugPrint('BODY: $cleanBody');
      debugPrint('==========================================');

      throw Exception('Server ส่งข้อมูลไม่ใช่ JSON');
    }

    if (decoded is! Map) {
      throw Exception('รูปแบบข้อมูลจาก Server ไม่ถูกต้อง');
    }

    final result = Map<String, dynamic>.from(decoded);

    // ----------------------------------------------------------
    // ถ้ามี data เป็น Map ให้รวมเข้ากับ result
    // ----------------------------------------------------------

    final inner = result['data'];

    if (inner is Map) {
      result.addAll(Map<String, dynamic>.from(inner));
    }

    return result;
  }

  // ============================================================
  // CHECK SUCCESS
  // ============================================================

  static void _ensureSuccess(Map<String, dynamic> r, String fallback) {
    if (r['success'] != true) {
      final message = r['message']?.toString().trim();

      if (message != null && message.isNotEmpty) {
        throw Exception(message);
      }

      throw Exception(fallback);
    }
  }

  // ============================================================
  // IMAGE URL
  // ============================================================

  static String? imageUrl(dynamic path) {
    return buildImageUrl(path?.toString());
  }

  // ============================================================
  // POST
  // ============================================================

  static Future<Map<String, dynamic>> _post(Map<String, String> data) async {
    debugPrint('------------------------------------------');
    debugPrint('SELLER API ACTION: ${data['action']}');
    debugPrint('SELLER API DATA: $data');

    try {
      final response = await http
          .post(
            Uri.parse(baseUrl),
            headers: Session.authorizationHeaders,
            body: data,
          )
          .timeout(_timeout);

      debugPrint(
        'SELLER API ${data['action']} STATUS: '
        '${response.statusCode}',
      );

      debugPrint('SELLER API BODY: ${response.body}');

      if (response.statusCode != 200) {
        throw Exception(
          'HTTP ${response.statusCode}: '
          '${response.body}',
        );
      }

      return _parse(response.body);
    } catch (e) {
      debugPrint('SELLER API ERROR [${data['action']}]: $e');

      rethrow;
    }
  }

  // ============================================================
  // PRODUCTS
  // ============================================================

  static Future<List<dynamic>> products(int sellerId) async {
    final r = await _post({
      'action': 'seller_products',
      'seller_id': '$sellerId',
    });

    _ensureSuccess(r, 'โหลดสินค้าไม่สำเร็จ');

    return (r['products'] as List?) ?? [];
  }

  // ============================================================
  // CATEGORIES
  // ============================================================

  static Future<List<dynamic>> categories() async {
    final r = await _post({'action': 'categories'});

    _ensureSuccess(r, 'โหลดหมวดหมู่ไม่สำเร็จ');

    return (r['categories'] as List?) ?? [];
  }

  // ============================================================
  // PRODUCT VARIANTS
  // ============================================================

  static Future<List<dynamic>> productVariants(int productId) async {
    final r = await _post({
      'action': 'product_variants',
      'product_id': '$productId',
    });

    _ensureSuccess(r, 'โหลดรายละเอียดตัวเลือกสินค้าไม่สำเร็จ');

    return (r['variants'] as List?) ?? [];
  }

  // ============================================================
  // ADD PRODUCT
  // ============================================================

  static Future<Map<String, dynamic>> addProduct({
    required int sellerId,
    required int categoryId,
    required String name,
    required String description,
    required double price,
    required int stock,
    List<Uint8List> imageBytesList = const [],
    List<Map<String, dynamic>> variants = const [],
  }) async {
    final request = http.MultipartRequest('POST', Uri.parse(baseUrl));
    request.headers.addAll(Session.authorizationHeaders);

    request.fields.addAll({
      'action': 'add_product',
      'seller_id': '$sellerId',
      'category_id': '$categoryId',
      'product_name': name,
      'product_description': description,
      'product_price': '$price',
      'stock': '$stock',
      'variants': jsonEncode(variants),
    });

    for (int i = 0; i < imageBytesList.length; i++) {
      request.files.add(
        http.MultipartFile.fromBytes(
          'images[]',
          imageBytesList[i],
          filename: 'product_$i.jpg',
        ),
      );
    }

    final response = await request.send().timeout(const Duration(seconds: 60));
    final body = await response.stream.bytesToString();

    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}: $body');
    }

    final result = _parse(body);
    _ensureSuccess(result, 'เพิ่มสินค้าไม่สำเร็จ');
    return result;
  }

  // ============================================================
  // UPDATE PRODUCT
  // ============================================================

  static Future<Map<String, dynamic>> updateProduct({
    required int sellerId,
    required int productId,
    required int categoryId,
    required String name,
    required String description,
    required double price,
    required int stock,
    String status = 'active',
    List<Uint8List> imageBytesList = const [],
    List<int> deletedImageIds = const [],
    List<Map<String, dynamic>> variants = const [],
  }) async {
    final request = http.MultipartRequest('POST', Uri.parse(baseUrl));
    request.headers.addAll(Session.authorizationHeaders);

    request.fields.addAll({
      'action': 'update_product',
      'seller_id': '$sellerId',
      'product_id': '$productId',
      'category_id': '$categoryId',
      'product_name': name,
      'product_description': description,
      'product_price': '$price',
      'stock': '$stock',
      'product_status': status,
      'deleted_image_ids': jsonEncode(deletedImageIds),
      'variants': jsonEncode(variants),
    });

    for (int i = 0; i < imageBytesList.length; i++) {
      request.files.add(
        http.MultipartFile.fromBytes(
          'images[]',
          imageBytesList[i],
          filename: 'product_new_$i.jpg',
        ),
      );
    }

    final response = await request.send().timeout(const Duration(seconds: 60));
    final body = await response.stream.bytesToString();

    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}: $body');
    }

    final result = _parse(body);
    _ensureSuccess(result, 'แก้ไขสินค้าไม่สำเร็จ');
    return result;
  }

  // ============================================================
  // DELETE PRODUCT
  // ============================================================

  static Future<Map<String, dynamic>> deleteProduct(
    int sellerId,
    int productId,
  ) async {
    final r = await _post({
      'action': 'delete_product',
      'seller_id': '$sellerId',
      'product_id': '$productId',
    });

    _ensureSuccess(r, 'ลบสินค้าไม่สำเร็จ');
    return r;
  }

  // ============================================================
  // WANTED POSTS
  // ============================================================

  static Future<List<dynamic>> wantedPosts() async {
    final r = await _post({'action': 'wanted_posts'});
    _ensureSuccess(r, 'โหลดรายการสินค้าที่ต้องการไม่สำเร็จ');
    return (r['posts'] as List?) ?? [];
  }

  // ============================================================
  // ADD WANTED COMMENT
  // ============================================================

  static Future<Map<String, dynamic>> addWantedComment({
    required int sellerId,
    required int wantedPostId,
    required double offerPrice,
    required String commentText,
  }) async {
    final r = await _post({
      'action': 'add_wanted_comment',
      'seller_id': '$sellerId',
      'wanted_post_id': '$wantedPostId',
      'offer_price': '$offerPrice',
      'comment_text': commentText,
    });
    _ensureSuccess(r, 'เสนอราคาไม่สำเร็จ');
    return r;
  }

  // ============================================================
  // CHAT ROOMS
  // ============================================================

  static Future<List<dynamic>> chatRooms(int sellerId) async {
    final r = await _post({'action': 'chat_rooms', 'seller_id': '$sellerId'});
    _ensureSuccess(r, 'โหลดห้องแชตไม่สำเร็จ');
    return (r['rooms'] as List?) ?? [];
  }

  // ============================================================
  // ORDERS
  // ============================================================

  static Future<List<dynamic>> orders(int sellerId) async {
    final r = await _post({
      'action': 'seller_orders',
      'seller_id': '$sellerId',
    });
    _ensureSuccess(r, 'โหลดคำสั่งซื้อไม่สำเร็จ');
    return (r['orders'] as List?) ?? [];
  }

  // ============================================================
  // UPDATE ORDER STATUS
  // ============================================================

  static Future<Map<String, dynamic>> updateOrderStatus({
    required int sellerId,
    required int orderId,
    required String status,
  }) async {
    final r = await _post({
      'action': 'update_order_status',
      'seller_id': '$sellerId',
      'order_id': '$orderId',
      'order_status': status,
    });
    _ensureSuccess(r, 'เปลี่ยนสถานะคำสั่งซื้อไม่สำเร็จ');
    return r;
  }

  static Future<Map<String, dynamic>> cancelOrder({
    required int sellerId,
    required int orderId,
  }) async {
    final r = await _post({
      'action': 'seller_cancel_order',
      'seller_id': '$sellerId',
      'order_id': '$orderId',
    });
    _ensureSuccess(r, 'ยกเลิกคำสั่งซื้อไม่สำเร็จ');
    return r;
  }

  // ============================================================
  // SALES SUMMARY
  // ============================================================

  static Future<Map<String, dynamic>> salesSummary(int sellerId) async {
    final r = await _post({
      'action': 'sales_summary',
      'seller_id': '$sellerId',
    });
    _ensureSuccess(r, 'โหลดข้อมูลยอดขายไม่สำเร็จ');
    return r;
  }

  // ============================================================
  // UPDATE PROFILE
  // ============================================================

  static Future<Map<String, dynamic>> updateProfile({
    required int userId,
    required String name,
    required String phone,
    Uint8List? imageBytes,
  }) async {
    if (userId <= 0) {
      throw Exception('ไม่พบรหัสผู้ขาย');
    }

    final cleanName = name.trim();
    final cleanPhone = phone.trim();

    if (cleanName.isEmpty) {
      throw Exception('กรุณากรอกชื่อ');
    }

    if (imageBytes == null) {
      final r = await _post({
        'action': 'update_profile',
        'user_id': '$userId',
        'seller_id': '$userId',
        'name': cleanName,
        'user_phone': cleanPhone,
      });
      _ensureSuccess(r, 'แก้ไขโปรไฟล์ไม่สำเร็จ');
      return r;
    }

    final request = http.MultipartRequest('POST', Uri.parse(baseUrl));
    request.headers.addAll(Session.authorizationHeaders);
    request.fields.addAll({
      'action': 'update_profile',
      'user_id': '$userId',
      'seller_id': '$userId',
      'name': cleanName,
      'user_phone': cleanPhone,
    });

    request.files.add(
      http.MultipartFile.fromBytes(
        'profile_image',
        imageBytes,
        filename:
            'profile_${userId}_${DateTime.now().millisecondsSinceEpoch}.jpg',
      ),
    );

    final response = await request.send().timeout(const Duration(seconds: 60));
    final body = await response.stream.bytesToString();

    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}: $body');
    }

    final result = _parse(body);
    _ensureSuccess(result, 'แก้ไขโปรไฟล์ไม่สำเร็จ');
    return result;
  }
}
