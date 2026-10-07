import 'package:flutter/material.dart';

/// เปิดหรือแสดงส่วนติดต่อผู้ใช้สำหรับ show App Snack Bar.
void showAppSnackBar(
  BuildContext context,
  String message, {
  bool isError = false,
}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: isError ? Colors.red : null,
    ),
  );
}
