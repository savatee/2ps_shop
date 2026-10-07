class ProductImageCache {
  static final Map<int, String?> _images = {};
  /// หน้าที่: ประมวลผลขั้นตอน lookup สำหรับส่วน product image cache (คลาส ProductImageCache).
  static String? lookup(int? productId) =>
      productId == null ? null : _images[productId];
  /// หน้าที่: ประมวลผลขั้นตอน remember สำหรับส่วน product image cache (คลาส ProductImageCache).
  static void remember(int? productId, String? imageUrl) {
    if (productId != null && imageUrl != null && imageUrl.isNotEmpty) {
      _images[productId] = imageUrl;
    }
  }
}
