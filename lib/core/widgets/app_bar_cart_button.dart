import 'package:flutter/material.dart';

/// ปุ่มตะกร้าบน AppBar หน้าตาเดียวกับหน้าหลัก (ไอคอน + Badge สีชมพูแดง)
/// ใช้ร่วมกันทุกหน้าเพื่อให้รูปแบบตรงกัน
class AppBarCartButton extends StatelessWidget {
  final int count;
  final VoidCallback onPressed;

  const AppBarCartButton({
    super.key,
    required this.count,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: IconButton(
        tooltip: 'ตะกร้าสินค้า',
        splashRadius: 21,
        onPressed: onPressed,
        icon: Badge(
          label: Text(
            '$count',
            style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700),
          ),
          isLabelVisible: count > 0,
          backgroundColor: const Color(0xFFF94C66),
          child: const Icon(
            Icons.shopping_cart_outlined,
            color: Colors.white,
            size: 22,
          ),
        ),
      ),
    );
  }
}
