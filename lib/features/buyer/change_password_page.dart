import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/network/api_client.dart';

class ChangePasswordPage extends StatefulWidget {
  final int userId;

  const ChangePasswordPage({super.key, required this.userId});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _oldPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _submitting = false;
  bool _showPasswords = false;

  /// หน้าที่: คืนทรัพยากรของหน้าจอ เช่น controller และ listener ก่อนปิดหน้า (คลาส _ChangePasswordPageState).
  @override
  void dispose() {
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  /// หน้าที่: ตรวจสอบและส่งข้อมูล submit ไปบันทึกผ่าน API (คลาส _ChangePasswordPageState).
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);
    final result = await ApiClient.changePassword(
      userId: widget.userId,
      oldPassword: _oldPasswordController.text,
      newPassword: _newPasswordController.text,
    );
    if (!mounted) return;

    setState(() => _submitting = false);
    final success = result['success'] == true;
    final responseMessage = result['message']?.toString();
    final message = responseMessage == 'Invalid user action'
        ? 'เซิร์ฟเวอร์ยังไม่รองรับการเปลี่ยนรหัสผ่าน กรุณาอัปเดตไฟล์ api/auth/change_password.php บนเซิร์ฟเวอร์ก่อน'
        : responseMessage ??
              (success ? 'เปลี่ยนรหัสผ่านสำเร็จ' : 'เปลี่ยนรหัสผ่านไม่สำเร็จ');
    showAppSnackBar(context, message, isError: !success);

    if (success) Navigator.pop(context);
  }

  /// หน้าที่: สร้าง UI ของหน้าจอหรือวิดเจ็ตใน change password page (คลาส _ChangePasswordPageState).
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('เปลี่ยนรหัสผ่าน')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppTextField(
                controller: _oldPasswordController,
                label: 'รหัสผ่านปัจจุบัน',
                icon: Icons.lock_outline,
                obscureText: !_showPasswords,
                validator: (value) => Validators.required(
                  value,
                  message: 'กรุณากรอกรหัสผ่านปัจจุบัน',
                ),
              ),
              const SizedBox(height: 14),
              AppTextField(
                controller: _newPasswordController,
                label: 'รหัสผ่านใหม่',
                icon: Icons.lock_reset_outlined,
                obscureText: !_showPasswords,
                validator: (value) => Validators.password(value),
              ),
              const SizedBox(height: 14),
              AppTextField(
                controller: _confirmPasswordController,
                label: 'ยืนยันรหัสผ่านใหม่',
                icon: Icons.check_circle_outline,
                obscureText: !_showPasswords,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'กรุณายืนยันรหัสผ่านใหม่';
                  }
                  if (value != _newPasswordController.text) {
                    return 'รหัสผ่านใหม่ไม่ตรงกัน';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () =>
                      setState(() => _showPasswords = !_showPasswords),
                  icon: Icon(
                    _showPasswords
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                  ),
                  label: Text(_showPasswords ? 'ซ่อนรหัสผ่าน' : 'แสดงรหัสผ่าน'),
                ),
              ),
              const SizedBox(height: 16),
              PrimaryButton(
                label: 'บันทึกรหัสผ่านใหม่',
                loading: _submitting,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
