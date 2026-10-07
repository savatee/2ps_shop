import 'package:flutter/material.dart';

class QuantitySelector extends StatelessWidget {
  final int quantity;
  final int maxQuantity;
  final ValueChanged<int> onChanged;
  final double iconSize;
  const QuantitySelector({
    super.key,
    required this.quantity,
    required this.onChanged,
    this.maxQuantity = 999,
    this.iconSize = 20,
  });
  /// หน้าที่: สร้าง UI ของหน้าจอหรือวิดเจ็ตใน quantity selector (คลาส QuantitySelector).
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      IconButton(
        onPressed: quantity > 1 ? () => onChanged(quantity - 1) : null,
        icon: Icon(Icons.remove_circle_outline, size: iconSize),
      ),
      Text('$quantity'),
      IconButton(
        onPressed: quantity < maxQuantity
            ? () => onChanged(quantity + 1)
            : null,
        icon: Icon(Icons.add_circle_outline, size: iconSize),
      ),
    ],
  );
}
