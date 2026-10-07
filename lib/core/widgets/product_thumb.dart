import 'dart:convert';
import 'package:flutter/material.dart';
import '../utils/image_utils.dart';

class ProductThumb extends StatelessWidget {
  final String? imageUrl;
  final double iconSize;
  final bool dimmed;
  final BoxFit fit;
  const ProductThumb({
    super.key,
    this.imageUrl,
    this.iconSize = 42,
    this.dimmed = false,
    this.fit = BoxFit.contain,
  });
  /// หน้าที่: สร้าง UI ของหน้าจอหรือวิดเจ็ตใน product thumb (คลาส ProductThumb).
  @override
  Widget build(BuildContext context) {
    final resolvedUrl = buildImageUrl(imageUrl);
    final Widget image;
    if (resolvedUrl == null || resolvedUrl.isEmpty) {
      image = Icon(Icons.image_outlined, size: iconSize, color: Colors.grey);
    } else if (resolvedUrl.startsWith('data:image/')) {
      final separator = resolvedUrl.indexOf(',');
      image = separator < 0
          ? Icon(Icons.image_outlined, size: iconSize, color: Colors.grey)
          : Image.memory(
              base64Decode(resolvedUrl.substring(separator + 1)),
              fit: fit,
              errorBuilder: (_, _, _) => Icon(
                Icons.image_outlined,
                size: iconSize,
                color: Colors.grey,
              ),
            );
    } else {
      image = Image.network(
        resolvedUrl,
        fit: fit,
        errorBuilder: (_, _, _) =>
            Icon(Icons.image_outlined, size: iconSize, color: Colors.grey),
      );
    }
    return Container(
      color: Colors.white,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(6),
      child: SizedBox.expand(child: image),
    );
  }
}
