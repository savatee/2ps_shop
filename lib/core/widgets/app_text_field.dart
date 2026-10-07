import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
export '../theme/app_theme.dart' show Validators;

class AppTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final String? prefixText;
  final IconData? icon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final int maxLines;
  final List<TextInputFormatter>? inputFormatters;
  final String? Function(String?)? validator;
  const AppTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.prefixText,
    this.icon,
    this.obscureText = false,
    this.keyboardType,
    this.maxLines = 1,
    this.inputFormatters,
    this.validator,
  });
  @override
  Widget build(BuildContext context) => TextFormField(
    controller: controller,
    decoration: InputDecoration(
      labelText: label,
      hintText: hint,
      prefixText: prefixText,
      prefixIcon: icon == null ? null : Icon(icon),
      border: const OutlineInputBorder(),
    ),
    obscureText: obscureText,
    keyboardType: keyboardType,
    inputFormatters: inputFormatters,
    maxLines: obscureText ? 1 : maxLines,
    validator: validator,
  );
}
