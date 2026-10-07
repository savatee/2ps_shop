import 'package:flutter/material.dart';

class LoadingView extends StatelessWidget {
  const LoadingView({super.key});
  /// หน้าที่: สร้าง UI ของหน้าจอหรือวิดเจ็ตใน loading view (คลาส LoadingView).
  @override
  Widget build(BuildContext context) =>
      const Center(child: CircularProgressIndicator());
}
