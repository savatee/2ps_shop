import '../config/app_config.dart';

String? pickProductImage(dynamic product) {
  if (product is! Map) return null;
  for (final key in [
    'product_image',
    'image_data',
    'image_url',
    'image',
    'product_image_url',
  ]) {
    final value = product[key]?.toString().trim();
    if (value != null && value.isNotEmpty && value != 'null') return value;
  }
  return null;
}

String? buildImageUrl(String? path) {
  if (path == null || path.trim().isEmpty) return null;
  final value = path.trim();
  if (value.startsWith('http://') ||
      value.startsWith('https://') ||
      value.startsWith('data:')) {
    return value;
  }

  final relativePath = value.replaceFirst(RegExp(r'^/+'), '');

  if (relativePath.startsWith('uploads/')) {
    return '${AppConfig.uploadsBaseUrl}${relativePath.substring('uploads/'.length)}';
  }

  return '${AppConfig.appBaseUrl}/$relativePath';
}

bool isImagePath(String? value) {
  if (value == null || value.isEmpty) return false;
  if (value.startsWith('data:image/')) return true;
  final path = value.split('?').first.toLowerCase();
  return ['.png', '.jpg', '.jpeg', '.gif', '.webp'].any(path.endsWith);
}

/// เลือกรูปประกอบโพสต์ตามหาสินค้า: ใช้ URL เต็มจาก API ก่อน ถ้าไม่มีค่อยใช้ path ใน DB
String? pickWantedImage(dynamic post) {
  if (post is! Map) return null;
  for (final key in ['wanted_image_url', 'wanted_image']) {
    final value = post[key]?.toString().trim();
    if (value != null && value.isNotEmpty && value != 'null') return value;
  }
  return null;
}
