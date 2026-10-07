import 'package:flutter/material.dart';
import '../utils/image_utils.dart';

/// รูปจากเครือข่ายที่ไม่ "หายเงียบ" เมื่อโหลดไม่ได้
/// - ระหว่างโหลดแสดง loading
/// - โหลดไม่สำเร็จแสดงไอคอนรูปเสีย (เห็นได้ทันทีว่า URL/ไฟล์มีปัญหา)
class SafeNetworkImage extends StatelessWidget {
  final String? source;
  final double? width;
  final double? height;
  final BoxFit fit;

  const SafeNetworkImage({
    super.key,
    required this.source,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
  });

  /// หน้าที่: ประมวลผลขั้นตอน box สำหรับส่วน safe network image (คลาส SafeNetworkImage).
  Widget _box(Widget child) => Container(
    width: width,
    height: height,
    color: const Color(0xFFF1F5F9),
    alignment: Alignment.center,
    child: child,
  );

  /// หน้าที่: สร้าง UI ของหน้าจอหรือวิดเจ็ตใน safe network image (คลาส SafeNetworkImage).
  @override
  Widget build(BuildContext context) {
    final url = buildImageUrl(source);
    if (url == null) {
      return _box(
        const Icon(Icons.image_outlined, color: Color(0xFF94A3B8), size: 32),
      );
    }
    return Image.network(
      url,
      width: width,
      height: height,
      fit: fit,
      loadingBuilder: (context, child, progress) => progress == null
          ? child
          : _box(
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
      errorBuilder: (_, error, _) {
        debugPrint('โหลดรูปไม่สำเร็จ: $url ($error)');
        return _box(
          const Icon(
            Icons.broken_image_outlined,
            color: Color(0xFF94A3B8),
            size: 32,
          ),
        );
      },
    );
  }
}
