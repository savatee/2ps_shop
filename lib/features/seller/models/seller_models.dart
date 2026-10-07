// ============================================================
// PRODUCT IMAGE
// ============================================================

class ProductImage {
  final int imageId;
  final int productId;
  final String? imagePath;
  final String? imageUrl;

  ProductImage({
    required this.imageId,
    required this.productId,
    this.imagePath,
    this.imageUrl,
  });

  factory ProductImage.fromJson(Map<String, dynamic> json) {
    return ProductImage(
      imageId: int.tryParse('${json['image_id'] ?? 0}') ?? 0,
      productId:
          int.tryParse(
            '${json['image_product_id'] ?? json['product_id'] ?? 0}',
          ) ??
          0,
      imagePath: _nullableString(json['image_path'] ?? json['image_data']),
      imageUrl: _nullableString(json['image_url']),
    );
  }
}

// ============================================================
// PRODUCT VARIANT
// ============================================================

class ProductVariant {
  final int variantId;
  final int productId;
  final String? size;
  final String? color;
  final double price;
  final int stock;
  final String status;

  ProductVariant({
    required this.variantId,
    required this.productId,
    this.size,
    this.color,
    required this.price,
    required this.stock,
    required this.status,
  });

  factory ProductVariant.fromJson(Map<String, dynamic> j) {
    return ProductVariant(
      variantId: int.tryParse('${j['variant_id'] ?? 0}') ?? 0,
      productId:
          int.tryParse('${j['variant_product_id'] ?? j['product_id'] ?? 0}') ??
          0,
      size: _nullableString(j['variant_size'] ?? j['size']),
      color: _nullableString(j['variant_color'] ?? j['color']),
      price: double.tryParse('${j['variant_price'] ?? j['price'] ?? 0}') ?? 0,
      stock: int.tryParse('${j['variant_stock'] ?? j['stock'] ?? 0}') ?? 0,
      status: j['variant_status']?.toString() ?? 'active',
    );
  }
}

// ============================================================
// SELLER PRODUCT
// ============================================================

class SellerProduct {
  final int productId;
  final int sellerId;
  final int categoryId;
  final String name;
  final String description;
  final double price;
  final int stock;
  final String categoryName;
  final String productStatus;
  final String? imageUrl;
  final List<ProductImage> images;
  final List<ProductVariant> variants;

  SellerProduct({
    required this.productId,
    required this.sellerId,
    required this.categoryId,
    required this.name,
    required this.description,
    required this.price,
    required this.stock,
    required this.categoryName,
    required this.productStatus,
    required this.imageUrl,
    required this.images,
    this.variants = const [],
  });

  factory SellerProduct.fromJson(Map<String, dynamic> j) {
    return SellerProduct(
      productId: int.tryParse('${j['product_id'] ?? 0}') ?? 0,
      sellerId: int.tryParse('${j['product_seller_id'] ?? 0}') ?? 0,
      categoryId: int.tryParse('${j['category_id'] ?? 0}') ?? 0,

      name: '${j['product_name'] ?? ''}',

      description: '${j['product_description'] ?? ''}',

      price: double.tryParse('${j['product_price'] ?? 0}') ?? 0,

      stock: int.tryParse('${j['stock'] ?? 0}') ?? 0,

      categoryName: '${j['category_name'] ?? ''}',

      productStatus: '${j['product_status'] ?? 'active'}',

      imageUrl: j['image_url']?.toString(),

      images: ((j['images'] as List?) ?? [])
          .whereType<Map>()
          .map((e) => ProductImage.fromJson(Map<String, dynamic>.from(e)))
          .toList(),

      variants: ((j['variants'] as List?) ?? [])
          .whereType<Map>()
          .map((e) => ProductVariant.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}

// ============================================================
// SELLER CATEGORY
// ============================================================

class SellerCategory {
  final int id;
  final String name;

  SellerCategory({required this.id, required this.name});

  factory SellerCategory.fromJson(Map<String, dynamic> j) {
    return SellerCategory(
      id: int.tryParse('${j['category_id'] ?? 0}') ?? 0,

      name: j['category_name']?.toString() ?? '',
    );
  }
}

// ============================================================
// WANTED POST
// ============================================================

class WantedPost {
  final int id;
  final int buyerId;

  final String buyerName;
  final String title;
  final String description;
  final String status;
  final String createdAt;

  final double budget;

  WantedPost({
    required this.id,
    required this.buyerId,
    required this.buyerName,
    required this.title,
    required this.description,
    required this.budget,
    required this.status,
    required this.createdAt,
  });

  int get wantedPostId => id;

  factory WantedPost.fromJson(Map<String, dynamic> j) {
    return WantedPost(
      id: int.tryParse('${j['wanted_post_id'] ?? 0}') ?? 0,

      buyerId: int.tryParse('${j['wanted_buyer_id'] ?? 0}') ?? 0,

      buyerName: j['buyer_name']?.toString() ?? 'ลูกค้า',

      title: j['title']?.toString() ?? '',

      description: j['wanted_description']?.toString() ?? '',

      budget: double.tryParse('${j['budget'] ?? 0}') ?? 0,

      status: j['wanted_status']?.toString() ?? 'open',

      createdAt: j['wanted_created_at']?.toString() ?? '',
    );
  }
}

// ============================================================
// WANTED COMMENT
// ============================================================

class WantedComment {
  final int commentId;
  final int wantedPostId;
  final int userId;

  final String sellerName;
  final String role;
  final String commentText;
  final String createdAt;

  final double offerPrice;

  WantedComment({
    required this.commentId,
    required this.wantedPostId,
    required this.userId,
    required this.sellerName,
    required this.role,
    required this.offerPrice,
    required this.commentText,
    required this.createdAt,
  });

  factory WantedComment.fromJson(Map<String, dynamic> j) {
    return WantedComment(
      commentId: int.tryParse('${j['comment_id'] ?? 0}') ?? 0,

      wantedPostId: int.tryParse('${j['wanted_post_id'] ?? 0}') ?? 0,

      userId: int.tryParse('${j['user_id'] ?? 0}') ?? 0,

      sellerName: j['seller_name']?.toString() ?? 'ผู้ขาย',

      role: j['role']?.toString() ?? 'seller',

      offerPrice: double.tryParse('${j['offer_price'] ?? 0}') ?? 0,

      commentText: j['comment_text']?.toString() ?? '',

      createdAt: j['comment_created_at']?.toString() ?? '',
    );
  }
}

// ============================================================
// SELLER ORDER
// ============================================================

class SellerOrder {
  final int orderId;
  final int buyerId;
  final int quantity;

  final String buyerName;
  final String productName;
  final String? itemSize;
  final String? itemColor;
  final String status;
  final String createdAt;

  final double subtotal;
  final double totalAmount;

  final String? productImagePath;
  final String? productImageUrl;

  // ---------------- PAYMENT / SLIP ----------------
  final String paymentMethod;
  final String paymentStatus;
  final String? paymentSlipPath;
  final String? paymentSlipUrl;
  final String? paymentSubmittedAt;
  final bool hasOtherSellers;

  SellerOrder({
    required this.orderId,
    required this.buyerId,
    required this.buyerName,
    required this.productName,
    required this.quantity,
    required this.subtotal,
    required this.totalAmount,
    required this.status,
    required this.createdAt,
    this.itemSize,
    this.itemColor,
    this.productImagePath,
    this.productImageUrl,
    this.paymentMethod = '',
    this.paymentStatus = '',
    this.paymentSlipPath,
    this.paymentSlipUrl,
    this.paymentSubmittedAt,
    this.hasOtherSellers = false,
  });

  /// ลูกค้าแนบสลิปมาแล้วหรือไม่
  bool get hasSlip =>
      (paymentSlipUrl != null && paymentSlipUrl!.isNotEmpty) ||
      (paymentSlipPath != null && paymentSlipPath!.isNotEmpty);

  String get variantLabel => [
    if (itemColor?.isNotEmpty ?? false) 'สี $itemColor',
    if (itemSize?.isNotEmpty ?? false) 'ไซส์ $itemSize',
  ].join(' · ');

  factory SellerOrder.fromJson(Map<String, dynamic> j) {
    String? imagePath;
    String? imageUrl;

    final possibleUrlKeys = ['product_image_url', 'image_url'];

    for (final key in possibleUrlKeys) {
      final value = j[key];

      if (value == null) continue;

      final text = value.toString().trim();

      if (text.isEmpty) continue;

      if (text.startsWith('http://') || text.startsWith('https://')) {
        imageUrl = text;
        break;
      }
    }

    final possiblePathKeys = [
      'product_image_path',
      'image_path',
      'product_image',
      'image',
      'image_data',
    ];

    for (final key in possiblePathKeys) {
      final value = j[key];

      if (value == null) continue;

      final text = value.toString().trim();

      if (text.isEmpty) continue;

      if (text == 'null') continue;

      if (text.startsWith('http://') || text.startsWith('https://')) {
        imageUrl ??= text;
      } else {
        imagePath = text;
      }

      break;
    }

    return SellerOrder(
      orderId: int.tryParse('${j['order_id'] ?? 0}') ?? 0,

      buyerId:
          int.tryParse('${j['order_buyer_id'] ?? j['buyer_id'] ?? 0}') ?? 0,

      buyerName: j['buyer_name']?.toString() ?? 'ลูกค้า',

      productName: j['product_name']?.toString() ?? '',

      itemSize: _nullableString(j['item_size']),

      itemColor: _nullableString(j['item_color']),

      quantity:
          int.tryParse('${j['item_quantity'] ?? j['quantity'] ?? 0}') ?? 0,

      subtotal: double.tryParse('${j['subtotal'] ?? 0}') ?? 0,

      totalAmount: double.tryParse('${j['total_amount'] ?? 0}') ?? 0,

      status: j['order_status']?.toString() ?? 'pending',

      createdAt: j['order_created_at']?.toString() ?? '',

      productImagePath: imagePath,
      productImageUrl: imageUrl,

      paymentMethod: j['payment_method']?.toString() ?? '',
      paymentStatus: j['payment_status']?.toString() ?? '',
      paymentSlipPath: _nullableString(j['payment_slip_path']),
      paymentSlipUrl: _nullableString(j['payment_slip_url']),
      paymentSubmittedAt: _nullableString(j['payment_submitted_at']),
      hasOtherSellers:
          j['has_other_sellers'] == true ||
          j['has_other_sellers']?.toString() == '1',
    );
  }
}

// ============================================================
// SELLER CHAT ROOM
// ============================================================

class SellerChatRoom {
  final int roomId;
  final int buyerId;

  final String buyerName;
  final String updatedAt;

  final String? lastMessage;

  SellerChatRoom({
    required this.roomId,
    required this.buyerId,
    required this.buyerName,
    this.lastMessage,
    required this.updatedAt,
  });

  factory SellerChatRoom.fromJson(Map<String, dynamic> j) {
    return SellerChatRoom(
      roomId: int.tryParse('${j['room_id'] ?? 0}') ?? 0,

      buyerId: int.tryParse('${j['room_buyer_id'] ?? 0}') ?? 0,

      buyerName: j['buyer_name']?.toString() ?? 'ลูกค้า',

      lastMessage: j['last_message']?.toString(),

      updatedAt: j['room_updated_at']?.toString() ?? '',
    );
  }
}

// ============================================================
// SELLER MESSAGE
// ============================================================

class SellerMessage {
  final int messageId;
  final int senderId;

  final String message;
  final String type;
  final String createdAt;

  final String? imagePath;
  final String? imageUrl;

  SellerMessage({
    required this.messageId,
    required this.senderId,
    required this.message,
    required this.type,
    required this.createdAt,
    this.imagePath,
    this.imageUrl,
  });

  factory SellerMessage.fromJson(Map<String, dynamic> j) {
    return SellerMessage(
      messageId: int.tryParse('${j['message_id'] ?? 0}') ?? 0,

      senderId: int.tryParse('${j['sender_id'] ?? 0}') ?? 0,

      message: j['message']?.toString() ?? '',

      type: j['message_type']?.toString() ?? 'text',

      createdAt: j['message_created_at']?.toString() ?? '',

      imagePath: _nullableString(j['message_image'] ?? j['image_path']),

      imageUrl: _nullableString(j['message_image_url'] ?? j['image_url']),
    );
  }
}

// ============================================================
// SELLER SALE SUMMARY
// ============================================================

class SellerSaleSummary {
  final double totalSales;
  final int orderCount;
  final int itemCount;

  final List<Map<String, dynamic>> categories;

  // ยอดขายต่อวัน
  final List<Map<String, dynamic>> dailySales;

  SellerSaleSummary({
    required this.totalSales,
    required this.orderCount,
    required this.itemCount,
    required this.categories,
    required this.dailySales,
  });

  factory SellerSaleSummary.fromJson(Map<String, dynamic> j) {
    return SellerSaleSummary(
      totalSales: double.tryParse('${j['total_sales'] ?? 0}') ?? 0,

      orderCount: int.tryParse('${j['order_count'] ?? 0}') ?? 0,

      itemCount: int.tryParse('${j['item_count'] ?? 0}') ?? 0,

      categories: ((j['categories'] as List?) ?? [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList(),

      dailySales: ((j['daily_sales'] as List?) ?? [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList(),
    );
  }
}

// ============================================================
// HELPER
// ============================================================

String? _nullableString(dynamic value) {
  if (value == null) {
    return null;
  }

  final text = value.toString().trim();

  if (text.isEmpty || text == 'null') {
    return null;
  }

  return text;
}
