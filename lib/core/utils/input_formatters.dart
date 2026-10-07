import 'package:flutter/services.dart';

/// ตัวกรองการกรอกข้อมูลที่ใช้ร่วมกันทั้งแอป
class AppInputFormatters {
  AppInputFormatters._();

  /// เฉพาะตัวเลข 0-9 (เช่น จำนวนสินค้า, สต็อก)
  static List<TextInputFormatter> digitsOnly({int? maxLength}) => [
    FilteringTextInputFormatter.digitsOnly,
    if (maxLength != null) LengthLimitingTextInputFormatter(maxLength),
  ];

  /// เบอร์โทรศัพท์: ตัวเลขเท่านั้น สูงสุด 10 หลัก
  static List<TextInputFormatter> phone() => digitsOnly(maxLength: 10);

  /// รหัสไปรษณีย์: ตัวเลขเท่านั้น 5 หลัก
  static List<TextInputFormatter> postalCode() => digitsOnly(maxLength: 5);

  /// ชื่อ/ตำบล/อำเภอ/จังหวัด: ตัวอักษรไทยหรืออังกฤษ และเครื่องหมายชื่อที่พบบ่อย
  static List<TextInputFormatter> textOnly() => [
    FilteringTextInputFormatter.allow(RegExp(r"[ก-ฮะ-ฺเ-๎A-Za-z .'-]")),
  ];

  /// บ้านเลขที่/ถนน: ตัวอักษร ตัวเลข ช่องว่าง และเครื่องหมายที่ใช้เขียนที่อยู่
  static List<TextInputFormatter> addressLine() => [
    FilteringTextInputFormatter.allow(
      RegExp(r"[\u0E00-\u0E7FA-Za-z0-9 .,#/\-]"),
    ),
  ];

  /// จำนวนเงิน (เช่น ราคา, งบประมาณ): ตัวเลข และจุดทศนิยมได้ไม่เกิน 1 จุด
  /// ทศนิยมสูงสุด [decimalDigits] หลัก
  static List<TextInputFormatter> money({int decimalDigits = 2}) => [
    _MoneyInputFormatter(decimalDigits),
  ];
}

class _MoneyInputFormatter extends TextInputFormatter {
  final RegExp _pattern;

  _MoneyInputFormatter(int decimalDigits)
    : _pattern = RegExp('^\\d*(\\.\\d{0,$decimalDigits})?\$');

  @override
  /// จัดรูปแบบข้อมูล format Edit Update ก่อนนำไปแสดงผล (คลาส _MoneyInputFormatter).
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // อนุญาตให้ลบจนว่างได้
    if (newValue.text.isEmpty) return newValue;
    // ถ้ารูปแบบไม่ถูกต้อง (มีตัวอักษร, จุดซ้ำ, ทศนิยมเกิน) ให้คงค่าเดิมไว้
    return _pattern.hasMatch(newValue.text) ? newValue : oldValue;
  }
}
