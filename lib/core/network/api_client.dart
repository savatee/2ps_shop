import 'dart:convert';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import 'session.dart';

/// HTTP adapter for the PHP endpoints shipped under backend/api.
class ApiClient {
  static const String _root = AppConfig.apiBaseUrl;
  static Uri _uri(String path, [Map<String, dynamic> query = const {}]) =>
      Uri.parse(
        '$_root/$path',
      ).replace(queryParameters: query.map((k, v) => MapEntry(k, '$v')));
  static Map<String, dynamic> _decode(String body) {
    final value = jsonDecode(body);
    if (value is Map<String, dynamic>) return value;
    return {'success': true, 'data': value};
  }

  static Future<Map<String, dynamic>> _get(
    String path,
    Map<String, dynamic> query,
  ) async {
    final response = await http
        .get(_uri(path, query), headers: Session.authorizationHeaders)
        .timeout(const Duration(seconds: 20));
    return _decode(response.body);
  }

  static Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> data,
  ) async {
    final response = await http
        .post(
          _uri(path),
          headers: Session.authorizationHeaders,
          body: data.map((k, v) => MapEntry(k, '$v')),
        )
        .timeout(const Duration(seconds: 30));
    return _decode(response.body);
  }

  static List<dynamic> _list(Map<String, dynamic> result) {
    final data = result['data'];
    if (data is List) return data;
    if (data is Map) {
      for (final value in data.values) {
        if (value is List) return value;
      }
    }
    return <dynamic>[];
  }

  /// รายการสินค้า (ใหม่สุดก่อน) ไม่ส่ง [limit] = ได้ทั้งหมดเหมือนเดิม
  /// ส่ง [limit]/[offset] เพื่อแบ่งหน้า และกรองด้วย [categoryId], [sellerId],
  /// [excludeId], [inStock] ได้จากฝั่งเซิร์ฟเวอร์
  static Future<List<dynamic>> getProducts({
    int? limit,
    int offset = 0,
    int? categoryId,
    int? sellerId,
    int? excludeId,
    bool inStock = false,
  }) async => _list(
    await _get('shop/products.php', {
      'action': 'read_products',
      'limit': ?limit,
      if (limit != null && offset > 0) 'offset': offset,
      'category_id': ?categoryId,
      'seller_id': ?sellerId,
      'exclude_id': ?excludeId,
      if (inStock) 'in_stock': 1,
    }),
  );

  /// สินค้ายอดนิยม: เฉพาะสินค้าที่เคยขายได้จริง
  static Future<List<dynamic>> getPopularProducts({
    int limit = 10,
    bool inStock = false,
  }) async => _list(
    await _get('shop/products.php', {
      'action': 'popular_products',
      'limit': limit,
      if (inStock) 'in_stock': 1,
    }),
  );

  /// สินค้าแนะนำตามหมวดที่ผู้ใช้เคยซื้อ (ต้องมี token)
  static Future<List<dynamic>> getRecommendedProducts({
    int limit = 20,
    int offset = 0,
  }) async => _list(
    await _get('shop/products.php', {
      'action': 'recommended_products',
      'limit': limit,
      if (offset > 0) 'offset': offset,
    }),
  );

  static Future<List<dynamic>> getCategories() async =>
      _list(await _get('shop/products.php', {'action': 'read_categories'}));
  static Future<List<dynamic>> getProductsByCategory(int categoryId) async =>
      _list(
        await _get('shop/products.php', {
          'action': 'products_by_category',
          'category_id': categoryId,
        }),
      );
  static Future<List<dynamic>> searchProducts(String keyword) async => _list(
    await _get('shop/products.php', {
      'action': 'search_products',
      'keyword': keyword,
    }),
  );
  static Future<Map<String, dynamic>> getProduct(int productId) async => _get(
    'shop/products.php',
    {'action': 'get_product', 'product_id': productId},
  );

  static Future<List<dynamic>> getCart(int userId) async => _list(
    await _get('shop/cart.php', {'action': 'get_cart', 'user_id': userId}),
  );
  static Future<Map<String, dynamic>> addToCart({
    required int userId,
    required int productId,
    int quantity = 1,
    int? variantId,
  }) => _post('shop/cart.php', {
    'action': 'add_to_cart',
    'user_id': userId,
    'product_id': productId,
    'quantity': quantity,
    'variant_id': ?variantId,
  });
  static Future<Map<String, dynamic>> updateCart({
    required int userId,
    required int cartId,
    required int quantity,
  }) => _post('shop/cart.php', {
    'action': 'update_cart',
    'user_id': userId,
    'cart_id': cartId,
    'quantity': quantity,
  });
  static Future<Map<String, dynamic>> deleteCart({
    required int userId,
    required int cartId,
  }) => _post('shop/cart.php', {
    'action': 'delete_cart',
    'user_id': userId,
    'cart_id': cartId,
  });

  static Future<List<dynamic>> getAddresses(int userId) async => _list(
    await _get('shop/address.php', {
      'action': 'get_addresses',
      'user_id': userId,
    }),
  );
  static Map<String, dynamic> _addressFields(
    int userId,
    String recipientName,
    String phone,
    String details,
    String subdistrict,
    String district,
    String province,
    String postalCode,
    bool isDefault,
  ) => {
    'user_id': userId,
    'recipient_name': recipientName,
    'phone': phone,
    'details': details,
    'subdistrict': subdistrict,
    'district': district,
    'province': province,
    'postal_code': postalCode,
    'is_default': isDefault ? 1 : 0,
  };
  static Future<Map<String, dynamic>> addAddress({
    required int userId,
    required String recipientName,
    required String phone,
    required String details,
    required String subdistrict,
    required String district,
    required String province,
    required String postalCode,
    required bool isDefault,
  }) => _post('shop/address.php', {
    'action': 'add_address',
    ..._addressFields(
      userId,
      recipientName,
      phone,
      details,
      subdistrict,
      district,
      province,
      postalCode,
      isDefault,
    ),
  });
  static Future<Map<String, dynamic>> updateAddress({
    required int userId,
    required int addressId,
    required String recipientName,
    required String phone,
    required String details,
    required String subdistrict,
    required String district,
    required String province,
    required String postalCode,
    required bool isDefault,
  }) => _post('shop/address.php', {
    'action': 'update_address',
    'address_id': addressId,
    ..._addressFields(
      userId,
      recipientName,
      phone,
      details,
      subdistrict,
      district,
      province,
      postalCode,
      isDefault,
    ),
  });
  static Future<Map<String, dynamic>> setDefaultAddress({
    required int userId,
    required int addressId,
  }) => _post('shop/address.php', {
    'action': 'set_default_address',
    'user_id': userId,
    'address_id': addressId,
  });
  static Future<Map<String, dynamic>> deleteAddress({
    required int userId,
    required int addressId,
  }) => _post('shop/address.php', {
    'action': 'delete_address',
    'user_id': userId,
    'address_id': addressId,
  });

  static Future<List<dynamic>> getOrders(int userId) async => _list(
    await _get('shop/orders.php', {'action': 'get_orders', 'user_id': userId}),
  );
  static Future<Map<String, dynamic>> getOrderDetail(
    int orderId, {
    int? userId,
  }) => _get('shop/orders.php', {
    'action': 'get_order_detail',
    'order_id': orderId,
    'user_id': ?userId,
  });
  static Future<Map<String, dynamic>> createOrder({
    required int userId,
    required int addressId,
    required String paymentMethod,
    List<int>? cartIds,
    int? productId,
    int? quantity,
    int? variantId,
  }) => _post('shop/orders.php', {
    'action': 'create_order',
    'user_id': userId,
    'address_id': addressId,
    'payment_method': paymentMethod,
    if (cartIds != null) 'cart_ids': cartIds.join(','),
    'product_id': ?productId,
    'quantity': ?quantity,
    'variant_id': ?variantId,
  });
  static Future<Map<String, dynamic>> cancelOrder({
    required int orderId,
    required int userId,
  }) => _post('shop/orders.php', {
    'action': 'cancel_order',
    'order_id': orderId,
    'user_id': userId,
  });

  static Future<Map<String, dynamic>> getUser(int userId) =>
      _get('auth/user.php', {'action': 'get_user', 'user_id': userId});
  static Future<void> logout() async {
    final token = Session.token;
    if (token.isEmpty) return;

    try {
      await http
          .post(
            _uri('auth/logout.php'),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(const Duration(seconds: 5));
    } catch (_) {
      // Clear the local session even when the server cannot be reached.
    } finally {
      Session.token = '';
    }
  }

  static Future<Map<String, dynamic>> updateUser({
    required int userId,
    required String name,
    required String email,
    required String phone,
  }) => _post('auth/user.php', {
    'action': 'update_user',
    'user_id': userId,
    'name': name,
    'email': email,
    'phone': phone,
  });
  static Future<Map<String, dynamic>> changePassword({
    required int userId,
    required String oldPassword,
    required String newPassword,
  }) => _post('auth/change_password.php', {
    'user_id': userId,
    'old_password': oldPassword,
    'new_password': newPassword,
  });
  static Future<Map<String, dynamic>> updateAvatar({
    required int userId,
    required String name,
    required String phone,
    required String avatarPath,
  }) async {
    final request =
        http.MultipartRequest('POST', _uri('auth/update_profile.php'))
          ..headers.addAll(Session.authorizationHeaders)
          ..fields['user_id'] = '$userId'
          ..fields['name'] = name
          ..fields['user_phone'] = phone;
    request.files.add(
      await http.MultipartFile.fromPath('profile_image', avatarPath),
    );
    final response = await http.Response.fromStream(
      await request.send().timeout(const Duration(seconds: 30)),
    );
    return _decode(response.body);
  }

  static Future<List<dynamic>> getBuyerRequests(int buyerId) async => _list(
    await _get('shop/wanted_posts.php', {
      'action': 'get_buyer_requests',
      'buyer_id': buyerId,
    }),
  );
  static Future<List<dynamic>> getAllWantedPosts(int viewerId) async => _list(
    await _get('shop/wanted_posts.php', {
      'action': 'get_buyer_requests',
      'viewer_id': viewerId,
    }),
  );

  /// ดึงโพสต์ตามหาสินค้า 1 โพสต์จากฐานข้อมูล (ใช้เปิดจากแชท)
  static Future<Map<String, dynamic>> getWantedPost(
    int postId, {
    int? viewerId,
  }) => _get('shop/wanted_posts.php', {
    'action': 'get_wanted_post',
    'wanted_post_id': postId,
    'viewer_id': viewerId ?? 0,
  });
  static Future<Map<String, dynamic>> createBuyerRequest({
    required int userId,
    required String title,
    required String description,
    required double budget,
    required int categoryId,
    String? imagePath,
  }) => _sendWantedRequest({
    'action': 'create_buyer_request',
    'buyer_id': '$userId',
    'category_id': '$categoryId',
    'title': title,
    'description': description,
    'budget': '$budget',
  }, imagePath: imagePath);
  static Future<Map<String, dynamic>> updateBuyerRequest({
    required int userId,
    required int postId,
    required String title,
    required String description,
    required double budget,
    required int categoryId,
    String? imagePath,
    bool removeImage = false,
  }) => _sendWantedRequest({
    'action': 'update_buyer_request',
    'user_id': '$userId',
    'wanted_post_id': '$postId',
    'category_id': '$categoryId',
    'title': title,
    'description': description,
    'budget': '$budget',
    'remove_image': removeImage ? '1' : '0',
  }, imagePath: imagePath);

  static Future<Map<String, dynamic>> _sendWantedRequest(
    Map<String, String> fields, {
    String? imagePath,
  }) async {
    final request = http.MultipartRequest('POST', _uri('shop/wanted_posts.php'))
      ..headers.addAll(Session.authorizationHeaders);
    request.fields.addAll(fields);
    if (imagePath != null) {
      request.files.add(
        await http.MultipartFile.fromPath('wanted_image', imagePath),
      );
    }
    final response = await http.Response.fromStream(
      await request.send().timeout(const Duration(seconds: 60)),
    );
    return _decode(response.body);
  }

  static Future<Map<String, dynamic>> deleteBuyerRequest({
    required int userId,
    required int postId,
  }) => _post('shop/wanted_posts.php', {
    'action': 'delete_buyer_request',
    'user_id': userId,
    'wanted_post_id': postId,
  });
  static Future<Map<String, dynamic>> setBuyerRequestStatus({
    required int userId,
    required int postId,
    required String status,
  }) => _post('shop/wanted_posts.php', {
    'action': 'set_buyer_request_status',
    'user_id': userId,
    'wanted_post_id': postId,
    'status': status,
  });
  static Future<List<dynamic>> getOffers(int postId, {int? viewerId}) async =>
      _list(
        await _get('shop/wanted_posts.php', {
          'action': 'get_comments',
          'wanted_post_id': postId,
          'viewer_id': viewerId ?? 0,
        }),
      );

  static Future<List<dynamic>> getBuyerChats(int userId) async => _list(
    await _get('shop/chat.php', {
      'action': 'get_buyer_chats',
      'buyer_id': userId,
    }),
  );
  static Future<Map<String, dynamic>> getOrCreateChat({
    required int postId,
    required int buyerId,
    required int sellerId,
  }) => _post('shop/chat.php', {
    'action': 'get_or_create_chat',
    'post_id': postId,
    'buyer_id': buyerId,
    'seller_id': sellerId,
  });
  static Future<List<dynamic>> getMessages(int chatId, {int? readerId}) async =>
      _list(
        await _get('shop/chat.php', {
          'action': 'get_messages',
          'chat_id': chatId,
          'reader_id': ?readerId,
        }),
      );
  static Future<Map<String, dynamic>> sendMessage({
    required int chatId,
    required int senderId,
    required String? message,
    String? imageBase64,
    int? productId,
  }) async {
    final fields = <String, String>{
      'action': 'send_message',
      'chat_id': '$chatId',
      'sender_id': '$senderId',
      'message': message ?? '',
      if (productId != null) 'product_id': '$productId',
    };

    if (imageBase64 == null || imageBase64.isEmpty) {
      return _post('shop/chat.php', fields);
    }

    final request = http.MultipartRequest('POST', _uri('shop/chat.php'))
      ..headers.addAll(Session.authorizationHeaders)
      ..fields.addAll(fields)
      ..files.add(
        http.MultipartFile.fromBytes(
          'message_image',
          base64Decode(imageBase64),
          filename: 'chat_${DateTime.now().millisecondsSinceEpoch}.jpg',
        ),
      );

    final streamed = await request.send().timeout(const Duration(seconds: 60));
    final body = await streamed.stream.bytesToString();
    final result = _decode(body);
    final serverMessage = result['message']?.toString() ?? '';

    // รองรับ API server รุ่นเก่าที่ยังรับ image_base64 แทน multipart file
    // ถ้า server ไม่เห็นไฟล์แนบ ให้ลองส่งรูปด้วยรูปแบบเดิมอีกครั้ง
    if (result['success'] != true &&
        serverMessage.contains('แนบรูปภาพ') &&
        imageBase64.isNotEmpty) {
      return _post('shop/chat.php', {
        'action': 'send_message',
        'chat_id': chatId,
        'sender_id': senderId,
        'message': message ?? '',
        'image_base64': imageBase64,
        'product_id': ?productId,
      });
    }

    return result;
  }

  static Future<Map<String, dynamic>> getPaymentQr({
    required int userId,
    required int paymentId,
  }) =>
      _get('shop/qr_payment.php', {'user_id': userId, 'payment_id': paymentId});
  static Future<Map<String, dynamic>> confirmPaymentTransfer({
    required int userId,
    required int paymentId,
  }) => _post('shop/payment_confirm.php', {
    'action': 'confirm_transfer',
    'user_id': userId,
    'payment_id': paymentId,
  });
}
