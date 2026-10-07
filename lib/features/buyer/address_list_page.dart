import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/loading_view.dart';
import '../../core/network/api_client.dart';
import 'widgets/address_form_sheet.dart';

class AddressListPage extends StatefulWidget {
  final int userId;

  const AddressListPage({super.key, required this.userId});

  @override
  State<AddressListPage> createState() => _AddressListPageState();
}

class _AddressListPageState extends State<AddressListPage> {
  List<dynamic> _addresses = [];
  bool _loading = true;
  final Set<int> _busyIds = {};

  /// หน้าที่: เตรียมสถานะเริ่มต้นของหน้าจอและเริ่มโหลดข้อมูลที่จำเป็น (คลาส _AddressListPageState).
  @override
  void initState() {
    super.initState();
    _load();
  }

  /// หน้าที่: โหลดข้อมูล load และอัปเดตสถานะการแสดงผลของหน้าจอ (คลาส _AddressListPageState).
  Future<void> _load() async {
    setState(() => _loading = true);
    final result = await ApiClient.getAddresses(widget.userId);
    if (!mounted) return;
    setState(() {
      _addresses = result;
      _loading = false;
    });
  }

  /// หน้าที่: บันทึกหรือสร้างข้อมูล add ที่อยู่จัดส่ง แล้วจัดการผลที่เซิร์ฟเวอร์ตอบกลับ (คลาส _AddressListPageState).
  Future<void> _addAddress() async {
    final saved = await showAddressFormSheet(context, userId: widget.userId);
    if (saved == true) _load();
  }

  /// หน้าที่: ประมวลผลขั้นตอน รหัส Of สำหรับส่วน address list page (คลาส _AddressListPageState).
  int _idOf(dynamic a) => int.tryParse(a['address_id']?.toString() ?? '') ?? -1;

  /// หน้าที่: ตรวจสอบเงื่อนไข is ค่าเริ่มต้น Of และคืนผลเป็น true หรือ false (คลาส _AddressListPageState).
  bool _isDefaultOf(dynamic a) =>
      a['is_default'] == 1 || a['is_default'] == '1' || a['is_default'] == true;

  /// หน้าที่: ปรับปรุงข้อมูลหรือสถานะ edit ที่อยู่จัดส่ง ผ่าน API และอัปเดตหน้าจอ (คลาส _AddressListPageState).
  Future<void> _editAddress(dynamic a) async {
    final saved = await showAddressFormSheet(
      context,
      userId: widget.userId,
      existing: Map<String, dynamic>.from(a),
    );
    if (saved == true) _load();
  }

  /// หน้าที่: กำหนดค่า set ค่าเริ่มต้น และบันทึกหรืออัปเดตสถานะที่เกี่ยวข้อง (คลาส _AddressListPageState).
  Future<void> _setDefault(dynamic a) async {
    final id = _idOf(a);
    if (id == -1) return;

    setState(() => _busyIds.add(id));
    final result = await ApiClient.setDefaultAddress(
      userId: widget.userId,
      addressId: id,
    );
    if (!mounted) return;
    setState(() => _busyIds.remove(id));

    if (result['success'] == true) {
      _load();
    } else {
      showAppSnackBar(
        context,
        result['message']?.toString() ?? 'ตั้งเป็นที่อยู่หลักไม่สำเร็จ',
        isError: true,
      );
    }
  }

  /// หน้าที่: ลบข้อมูล delete ที่อยู่จัดส่ง และจัดการผลการลบที่ API ส่งกลับ (คลาส _AddressListPageState).
  Future<void> _deleteAddress(dynamic a) async {
    final id = _idOf(a);
    if (id == -1) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ลบที่อยู่'),
        content: Text(
          'ต้องการลบที่อยู่ของ "${a['recipient_name'] ?? 'ผู้รับ'}" ใช่หรือไม่?\n(ลบไม่ได้ถ้าที่อยู่นี้ถูกใช้ในคำสั่งซื้อแล้ว)',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ยกเลิก'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('ลบ', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busyIds.add(id));
    final result = await ApiClient.deleteAddress(
      userId: widget.userId,
      addressId: id,
    );
    if (!mounted) return;
    setState(() => _busyIds.remove(id));

    if (result['success'] == true) {
      _load();
    } else {
      showAppSnackBar(
        context,
        result['message']?.toString() ?? 'ลบที่อยู่ไม่สำเร็จ',
        isError: true,
      );
    }
  }

  /// หน้าที่: ประมวลผลขั้นตอน บรรทัด สำหรับส่วน address list page (คลาส _AddressListPageState).
  String _line(dynamic a) {
    final parts = [
      a['address_detail'],
      a['subdistrict'],
      a['district'],
      a['province'],
      a['postal_code'],
    ].where((e) => e != null && e.toString().trim().isNotEmpty);
    return parts.join(' ');
  }

  /// หน้าที่: สร้าง UI ของหน้าจอหรือวิดเจ็ตใน address list page (คลาส _AddressListPageState).
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('ที่อยู่จัดส่งของฉัน'),
        actions: [
          IconButton(onPressed: _addAddress, icon: const Icon(Icons.add)),
        ],
      ),
      body: _loading
          ? const LoadingView()
          : _addresses.isEmpty
          ? EmptyState(
              icon: Icons.location_on_outlined,
              title: 'ยังไม่มีที่อยู่จัดส่ง',
              actionLabel: 'เพิ่มที่อยู่',
              onAction: _addAddress,
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: _addresses.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final a = _addresses[index];
                  final id = _idOf(a);
                  final isDefault = _isDefaultOf(a);
                  final busy = _busyIds.contains(id);

                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  a['recipient_name']?.toString() ?? '-',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              if (isDefault)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryLight,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Text(
                                    'ที่อยู่หลัก',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            a['address_phone']?.toString() ?? '',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textGrey,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(_line(a), style: const TextStyle(fontSize: 13)),
                          const SizedBox(height: 4),
                          const Divider(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              if (busy)
                                const Padding(
                                  padding: EdgeInsets.all(10),
                                  child: SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                )
                              else ...[
                                if (!isDefault)
                                  TextButton.icon(
                                    onPressed: () => _setDefault(a),
                                    icon: const Icon(
                                      Icons.star_outline,
                                      size: 18,
                                    ),
                                    label: const Text('ตั้งเป็นหลัก'),
                                  ),
                                TextButton.icon(
                                  onPressed: () => _editAddress(a),
                                  icon: const Icon(
                                    Icons.edit_outlined,
                                    size: 18,
                                  ),
                                  label: const Text('แก้ไข'),
                                ),
                                TextButton.icon(
                                  onPressed: () => _deleteAddress(a),
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    size: 18,
                                    color: AppColors.danger,
                                  ),
                                  label: const Text(
                                    'ลบ',
                                    style: TextStyle(color: AppColors.danger),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
