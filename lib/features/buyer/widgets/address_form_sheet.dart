import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/network/api_client.dart';
import '../../../core/utils/input_formatters.dart';

/// เปิดเป็น bottom sheet เพื่อเพิ่มหรือแก้ไขที่อยู่จัดส่ง
/// คืนค่า true กลับไปถ้าบันทึกสำเร็จ เพื่อให้หน้าที่เรียกไปโหลดที่อยู่ใหม่
Future<bool?> showAddressFormSheet(
  BuildContext context, {
  required int userId,
  Map<String, dynamic>? existing,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _AddressFormSheet(userId: userId, existing: existing),
  );
}

class _AddressFormSheet extends StatefulWidget {
  final int userId;
  final Map<String, dynamic>? existing;
  const _AddressFormSheet({required this.userId, this.existing});

  @override
  State<_AddressFormSheet> createState() => _AddressFormSheetState();
}

class _AddressFormSheetState extends State<_AddressFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _details = TextEditingController();
  final _subdistrict = TextEditingController();
  final _district = TextEditingController();
  final _province = TextEditingController();
  final _postalCode = TextEditingController();
  bool _isDefault = false;
  bool _saving = false;

  bool get _isEditing => widget.existing != null;

  int? get _addressId {
    final raw = widget.existing?['address_id']?.toString();
    if (raw == null || raw.isEmpty) return null;
    return int.tryParse(raw);
  }

  /// หน้าที่: เตรียมสถานะเริ่มต้นของหน้าจอและเริ่มโหลดข้อมูลที่จำเป็น (คลาส _AddressFormSheetState).
  @override
  void initState() {
    super.initState();
    final a = widget.existing;
    if (a == null) return;
    _name.text = a['recipient_name']?.toString() ?? '';
    _phone.text = a['address_phone']?.toString() ?? '';
    _details.text = a['address_detail']?.toString() ?? '';
    _subdistrict.text = a['subdistrict']?.toString() ?? '';
    _district.text = a['district']?.toString() ?? '';
    _province.text = a['province']?.toString() ?? '';
    _postalCode.text = a['postal_code']?.toString() ?? '';
    _isDefault = a['is_default'] == 1 || a['is_default'] == '1';
  }

  /// หน้าที่: คืนทรัพยากรของหน้าจอ เช่น controller และ listener ก่อนปิดหน้า (คลาส _AddressFormSheetState).
  @override
  void dispose() {
    for (final c in [
      _name,
      _phone,
      _details,
      _subdistrict,
      _district,
      _province,
      _postalCode,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  /// หน้าที่: บันทึกหรือสร้างข้อมูล save แล้วจัดการผลที่เซิร์ฟเวอร์ตอบกลับ (คลาส _AddressFormSheetState).
  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final addressId = _addressId;
    if (_isEditing && addressId == null) {
      showAppSnackBar(context, 'ไม่พบ Address ID', isError: true);
      return;
    }

    setState(() => _saving = true);
    final result = _isEditing
        ? await ApiClient.updateAddress(
            userId: widget.userId,
            addressId: addressId!,
            recipientName: _name.text.trim(),
            phone: _phone.text.trim(),
            details: _details.text.trim(),
            subdistrict: _subdistrict.text.trim(),
            district: _district.text.trim(),
            province: _province.text.trim(),
            postalCode: _postalCode.text.trim(),
            isDefault: _isDefault,
          )
        : await ApiClient.addAddress(
            userId: widget.userId,
            recipientName: _name.text.trim(),
            phone: _phone.text.trim(),
            details: _details.text.trim(),
            subdistrict: _subdistrict.text.trim(),
            district: _district.text.trim(),
            province: _province.text.trim(),
            postalCode: _postalCode.text.trim(),
            isDefault: _isDefault,
          );

    if (!mounted) return;
    setState(() => _saving = false);

    if (result['success'] == true) {
      Navigator.pop(context, true);
    } else {
      showAppSnackBar(
        context,
        result['message']?.toString() ??
            (_isEditing ? 'แก้ไขที่อยู่ไม่สำเร็จ' : 'เพิ่มที่อยู่ไม่สำเร็จ'),
        isError: true,
      );
    }
  }

  /// หน้าที่: สร้าง UI ของหน้าจอหรือวิดเจ็ตใน address form sheet (คลาส _AddressFormSheetState).
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.lg),
          ),
        ),
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                Text(
                  _isEditing ? 'แก้ไขที่อยู่จัดส่ง' : 'เพิ่มที่อยู่จัดส่ง',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                AppTextField(
                  controller: _name,
                  label: 'ชื่อ-นามสกุลผู้รับ',
                  icon: Icons.person_outline,
                  inputFormatters: AppInputFormatters.textOnly(),
                  validator: Validators.recipientName,
                ),
                const SizedBox(height: 12),
                AppTextField(
                  controller: _phone,
                  label: 'เบอร์โทรศัพท์',
                  icon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                  inputFormatters: AppInputFormatters.phone(),
                  validator: Validators.thaiPhone,
                ),
                const SizedBox(height: 12),
                AppTextField(
                  controller: _details,
                  label: 'ที่อยู่ (บ้านเลขที่, ถนน)',
                  icon: Icons.home_outlined,
                  maxLines: 2,
                  inputFormatters: AppInputFormatters.addressLine(),
                  validator: Validators.addressLine,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: AppTextField(
                        controller: _subdistrict,
                        label: 'ตำบล/แขวง',
                        inputFormatters: AppInputFormatters.textOnly(),
                        validator: (value) => Validators.addressText(
                          value,
                          label: 'ตำบล/แขวง',
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: AppTextField(
                        controller: _district,
                        label: 'อำเภอ/เขต',
                        inputFormatters: AppInputFormatters.textOnly(),
                        validator: (value) => Validators.addressText(
                          value,
                          label: 'อำเภอ/เขต',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: AppTextField(
                        controller: _province,
                        label: 'จังหวัด',
                        inputFormatters: AppInputFormatters.textOnly(),
                        validator: (value) => Validators.addressText(
                          value,
                          label: 'จังหวัด',
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: AppTextField(
                        controller: _postalCode,
                        label: 'รหัสไปรษณีย์',
                        keyboardType: TextInputType.number,
                        inputFormatters: AppInputFormatters.postalCode(),
                        validator: Validators.postalCode,
                      ),
                    ),
                  ],
                ),
                CheckboxListTile(
                  value: _isDefault,
                  onChanged: (v) => setState(() => _isDefault = v ?? false),
                  title: const Text('ตั้งเป็นที่อยู่หลัก'),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                ),
                const SizedBox(height: 8),
                PrimaryButton(
                  label: _isEditing ? 'บันทึกการแก้ไข' : 'บันทึกที่อยู่',
                  loading: _saving,
                  onPressed: _save,
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
