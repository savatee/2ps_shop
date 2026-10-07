import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

class SellerTheme {
  static const Color navy = AppColors.sellerNavy;
  static const Color navyDark = AppColors.sellerNavyDark;
  static const Color navyLight = AppColors.sellerNavyLight;
  static const Color background = AppColors.sellerBackground;
  static const Color backgroundLight = AppColors.sellerBackgroundLight;
  static const Color white = Colors.white;
  static const Color textPrimary = AppColors.sellerTextPrimary;
  static const Color textSecondary = AppColors.sellerTextSecondary;
  static const Color textLight = AppColors.sellerTextLight;
  static const Color border = AppColors.sellerBorder;
  static const Color success = AppColors.sellerSuccess;
  static const Color successLight = AppColors.sellerSuccessLight;
  static const Color warning = AppColors.sellerWarning;
  static const Color warningLight = AppColors.sellerWarningLight;
  static const Color danger = Color(0xFFDC2626);
  static const Color dangerLight = AppColors.sellerDangerLight;
  static const Color purple = AppColors.sellerPurple;
  static const Color purpleLight = AppColors.sellerPurpleLight;
  static const Color blue = AppColors.sellerBlue;
  static const Color blueLight = AppColors.sellerBlueLight;
  static const Color orange = AppColors.sellerOrange;
  static const Color pink = AppColors.sellerPink;

  static const double radiusSmall = AppRadius.sm;
  static const double radiusMedium = AppRadius.compact;
  static const double radiusLarge = AppRadius.md;
  static const double radiusCard = AppRadius.card;
  static const double radiusBig = AppRadius.large;
  static const double radiusXLarge = AppRadius.xl;

  static const TextStyle title = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    color: textPrimary,
  );

  static const TextStyle sectionTitle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: textPrimary,
  );

  static const TextStyle body = TextStyle(fontSize: 14, color: textPrimary);
  static const TextStyle bodySecondary = TextStyle(
    fontSize: 13,
    color: textSecondary,
  );
  static const TextStyle small = TextStyle(fontSize: 12, color: textSecondary);
  static const TextStyle buttonText = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: Colors.white,
  );

  /// หน้าที่: ประมวลผลขั้นตอน theme สำหรับส่วน seller theme (คลาส SellerTheme).
  static ThemeData theme() {
    return AppTheme.seller;
  }

  static AppBar appBar(
    String title, {
    List<Widget>? actions,
    bool centerTitle = false,
  }) {
    return AppBar(
      backgroundColor: navy,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: centerTitle,
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
      actions: actions,
    );
  }

  /// หน้าที่: ประมวลผลขั้นตอน card Decoration สำหรับส่วน seller theme (คลาส SellerTheme).
  static BoxDecoration cardDecoration({
    Color color = Colors.white,
    double radius = radiusCard,
    bool shadow = true,
    Color? borderColor,
  }) {
    return BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(radius),
      border: borderColor == null ? null : Border.all(color: borderColor),
      boxShadow: shadow
          ? [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ]
          : null,
    );
  }

  /// หน้าที่: ประมวลผลขั้นตอน input Decoration สำหรับส่วน seller theme (คลาส SellerTheme).
  static InputDecoration inputDecoration(
    String label, {
    String? hint,
    Widget? prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }

  /// หน้าที่: ประมวลผลขั้นตอน primary Button สำหรับส่วน seller theme (คลาส SellerTheme).
  static Widget primaryButton({
    required String text,
    required VoidCallback? onPressed,
    IconData? icon,
    bool loading = false,
    double height = 48,
  }) {
    final child = loading
        ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white,
            ),
          )
        : Text(text, style: buttonText);

    return SizedBox(
      width: double.infinity,
      height: height,
      child: icon != null && !loading
          ? ElevatedButton.icon(
              onPressed: onPressed,
              icon: Icon(icon),
              label: child,
            )
          : ElevatedButton(onPressed: loading ? null : onPressed, child: child),
    );
  }

  static ButtonStyle outlinedButton() {
    return OutlinedButton.styleFrom(
      foregroundColor: navy,
      side: const BorderSide(color: navy),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusLarge),
      ),
    );
  }

  /// หน้าที่: ค้นหาหรือกรองข้อมูล filter Chip ตามเงื่อนไขที่ผู้ใช้เลือก (คลาส SellerTheme).
  static Widget filterChip({
    required String text,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return ChoiceChip(
      label: Text(text),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: navy,
      backgroundColor: const Color(0xFFF1F5F9),
      side: BorderSide.none,
      labelStyle: TextStyle(
        color: selected ? Colors.white : textSecondary,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  /// หน้าที่: ประมวลผลขั้นตอน สถานะ Badge สำหรับส่วน seller theme (คลาส SellerTheme).
  static Widget statusBadge(String text, {required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  /// หน้าที่: ประมวลผลขั้นตอน สถานะ สี สำหรับส่วน seller theme (คลาส SellerTheme).
  static Color statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return warning;
      case 'paid':
        return blue;
      case 'processing':
        return navyDark;
      case 'shipping':
        return purple;
      case 'completed':
        return success;
      case 'cancelled':
        return danger;
      case 'active':
        return success;
      case 'rejected':
        return danger;
      case 'inactive':
        return textSecondary;
      case 'open':
        return success;
      case 'closed':
        return textSecondary;
      default:
        return textSecondary;
    }
  }

  /// หน้าที่: ประมวลผลขั้นตอน รูปภาพ Placeholder สำหรับส่วน seller theme (คลาส SellerTheme).
  static Widget imagePlaceholder({
    double width = 80,
    double height = 80,
    IconData icon = Icons.image_outlined,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(radiusMedium),
      ),
      child: Icon(icon, size: 30, color: textLight),
    );
  }

  /// หน้าที่: ประมวลผลขั้นตอน loading สำหรับส่วน seller theme (คลาส SellerTheme).
  static Widget loading() =>
      const Center(child: CircularProgressIndicator(color: navy));

  /// หน้าที่: ประมวลผลขั้นตอน empty สำหรับส่วน seller theme (คลาส SellerTheme).
  static Widget empty({
    required String message,
    IconData icon = Icons.inventory_2_outlined,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 55, color: textLight),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center, style: bodySecondary),
          ],
        ),
      ),
    );
  }

  static SnackBar snackBar(String message) {
    return SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusMedium),
      ),
    );
  }
}
