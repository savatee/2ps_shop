class ProductImageCache {
  static final Map<int, String?> _images = {};
  static String? lookup(int? productId) =>
      productId == null ? null : _images[productId];
  static void remember(int? productId, String? imageUrl) {
    if (productId != null && imageUrl != null && imageUrl.isNotEmpty) {
      _images[productId] = imageUrl;
    }
  }
}
