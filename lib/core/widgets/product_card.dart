import 'package:flutter/material.dart';
import 'product_thumb.dart';

class ProductCard extends StatelessWidget {
  final String name;
  final double price;
  final int stock;
  final int? soldCount;
  final String? sellerName;
  final String? imageUrl;
  final VoidCallback onTap;
  const ProductCard({
    super.key,
    required this.name,
    required this.price,
    required this.stock,
    this.soldCount,
    this.sellerName,
    this.imageUrl,
    required this.onTap,
  });
  /// หน้าที่: สร้าง UI ของหน้าจอหรือวิดเจ็ตใน product card (คลาส ProductCard).
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: Card(
      color: const Color(0xFFF4F2F8),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE3E0E9)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: SizedBox(
              width: double.infinity,
              child: ProductThumb(imageUrl: imageUrl, fit: BoxFit.cover),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(9),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                if (soldCount != null)
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '฿${price.toStringAsFixed(2)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF1554B8),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'ขายแล้ว $soldCount',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF737B89),
                        ),
                      ),
                    ],
                  )
                else ...[
                  Text(
                    '฿${price.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  if (sellerName != null)
                    Text(
                      sellerName!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  Text(stock > 0 ? 'คงเหลือ $stock' : 'สินค้าหมด'),
                ],
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
