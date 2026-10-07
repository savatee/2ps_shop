import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/app_theme.dart';
import '../../core/network/session.dart';
import '../buyer/address_list_page.dart';
import '../buyer/change_password_page.dart';
import '../login/role_selection_screen.dart';
import '../../core/network/api_client.dart';
import '../seller/api/seller_api.dart';
import '../../core/utils/input_formatters.dart';

class ProfilePage extends StatefulWidget {
  final int? userId;

  const ProfilePage({super.key, this.userId});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  static const Color _navy = Color(0xFF0D356B);
  static const Color _background = Color(0xFFF4F6FA);

  Color get _roleHeader => _navy;

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _imagePicker = ImagePicker();

  bool _loading = true;
  bool _saving = false;
  bool _requiresReauthentication = false;
  String? _error;
  int? _userId;
  int _addressCount = 0;
  String _role = '';
  Map<String, dynamic> _profile = {};
  Uint8List? _newProfileImage;
  String? _newProfileImagePath;

  /// หน้าที่: เตรียมสถานะเริ่มต้นของหน้าจอและเริ่มโหลดข้อมูลที่จำเป็น (คลาส _ProfilePageState).
  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  /// หน้าที่: คืนทรัพยากรของหน้าจอ เช่น controller และ listener ก่อนปิดหน้า (คลาส _ProfilePageState).
  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  /// หน้าที่: โหลดข้อมูล load โปรไฟล์ และอัปเดตสถานะการแสดงผลของหน้าจอ (คลาส _ProfilePageState).
  Future<void> _loadProfile({bool showLoading = true}) async {
    if (showLoading && mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      if (Session.token.isEmpty) {
        Session.token = prefs.getString('api_token') ?? '';
      }
      final userId = widget.userId ?? prefs.getInt('current_admin_id');
      if (userId == null || userId <= 0) {
        throw Exception('ไม่พบข้อมูลผู้ใช้ที่เข้าสู่ระบบ');
      }

      final result = await ApiClient.getUser(userId);
      final data = result['data'];
      final user = data is Map
          ? Map<String, dynamic>.from(data)
          : result['user'] is Map
          ? Map<String, dynamic>.from(result['user'] as Map)
          : null;
      if (result['success'] != true || user == null) {
        throw Exception(result['message']?.toString() ?? 'โหลดข้อมูลไม่สำเร็จ');
      }

      if (!mounted) return;
      setState(() {
        _userId = userId;
        _profile = user;
        _role = user['role']?.toString().trim().toLowerCase() ?? '';
        _nameController.text = user['name']?.toString() ?? '';
        _emailController.text = user['email']?.toString() ?? '';
        _phoneController.text = user['user_phone']?.toString() ?? '';
        _loading = false;
        _requiresReauthentication = false;
        _error = null;
      });

      if (_role == 'buyer') {
        _loadAddressCount(userId);
      }
    } catch (error) {
      if (!mounted) return;
      final errorMessage = error.toString().replaceFirst('Exception: ', '');
      final requiresReauthentication =
          errorMessage.contains('token') ||
          errorMessage.contains('เซสชันบนเซิร์ฟเวอร์') ||
          errorMessage.contains('กรุณาเข้าสู่ระบบ');
      if (requiresReauthentication) {
        Session.token = '';
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('api_token');
        await prefs.remove('remember_login');
        await prefs.remove('remembered_user_id');
        await prefs.remove('remembered_role');
        await prefs.remove('current_admin_id');
      }
      setState(() {
        _loading = false;
        _requiresReauthentication = requiresReauthentication;
        _error = requiresReauthentication
            ? 'เซสชันหมดอายุ กรุณาเข้าสู่ระบบใหม่'
            : errorMessage;
      });
    }
  }

  /// หน้าที่: ประมวลผลขั้นตอน start เข้าสู่ระบบ Again สำหรับส่วน profile page (คลาส _ProfilePageState).
  Future<void> _startLoginAgain() async {
    final prefs = await SharedPreferences.getInstance();
    Session.token = '';
    await prefs.remove('api_token');
    await prefs.remove('remember_login');
    await prefs.remove('remembered_user_id');
    await prefs.remove('remembered_role');
    await prefs.remove('current_admin_id');
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const RoleSelectionScreen()),
      (_) => false,
    );
  }

  /// หน้าที่: โหลดข้อมูล load ที่อยู่จัดส่ง Count และอัปเดตสถานะการแสดงผลของหน้าจอ (คลาส _ProfilePageState).
  Future<void> _loadAddressCount(int userId) async {
    try {
      final addresses = await ApiClient.getAddresses(userId);
      if (mounted) setState(() => _addressCount = addresses.length);
    } catch (_) {
      // The profile remains usable if address loading is temporarily unavailable.
    }
  }

  /// หน้าที่: เลือกรับข้อมูล pick โปรไฟล์ รูปภาพ จากผู้ใช้หรืออุปกรณ์ (คลาส _ProfilePageState).
  Future<void> _pickProfileImage() async {
    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 1000,
        maxHeight: 1000,
      );
      if (image == null) return;

      final bytes = await image.readAsBytes();
      if (mounted) {
        setState(() {
          _newProfileImage = bytes;
          _newProfileImagePath = image.path;
        });
      }
    } catch (error) {
      _showMessage('เลือกรูปไม่สำเร็จ: $error', isError: true);
    }
  }

  /// หน้าที่: บันทึกหรือสร้างข้อมูล save โปรไฟล์ แล้วจัดการผลที่เซิร์ฟเวอร์ตอบกลับ (คลาส _ProfilePageState).
  Future<void> _saveProfile() async {
    final userId = _userId;
    if (userId == null) return;
    if (_nameController.text.trim().isEmpty ||
        _emailController.text.trim().isEmpty) {
      _showMessage('กรุณากรอกชื่อและอีเมล', isError: true);
      return;
    }

    setState(() => _saving = true);
    try {
      final result = await ApiClient.updateUser(
        userId: userId,
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim(),
      );
      if (result['success'] != true) {
        throw Exception(
          result['message']?.toString() ?? 'บันทึกข้อมูลไม่สำเร็จ',
        );
      }

      if (_newProfileImage != null) {
        if (_role == 'seller') {
          await SellerApi.updateProfile(
            userId: userId,
            name: _nameController.text.trim(),
            phone: _phoneController.text.trim(),
            imageBytes: _newProfileImage,
          );
        } else if (_newProfileImagePath != null) {
          final avatarResult = await ApiClient.updateAvatar(
            userId: userId,
            name: _nameController.text.trim(),
            phone: _phoneController.text.trim(),
            avatarPath: _newProfileImagePath!,
          );
          if (avatarResult['success'] != true) {
            throw Exception(
              avatarResult['message']?.toString() ??
                  'อัปโหลดรูปโปรไฟล์ไม่สำเร็จ',
            );
          }
        }
      }

      if (!mounted) return;
      setState(() {
        _newProfileImage = null;
        _newProfileImagePath = null;
      });
      _showMessage('บันทึกข้อมูลแล้ว');
      await _loadProfile(showLoading: false);
    } catch (error) {
      _showMessage('บันทึกไม่สำเร็จ: $error', isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// หน้าที่: ปรับปรุงข้อมูลหรือสถานะ edit โปรไฟล์ ผ่าน API และอัปเดตหน้าจอ (คลาส _ProfilePageState).
  Future<void> _editProfile() async {
    final values = await Navigator.push<Map<String, String>>(
      context,
      MaterialPageRoute(
        builder: (_) => EditProfilePage(
          name: _nameController.text,
          email: _emailController.text,
          phone: _phoneController.text,
        ),
      ),
    );

    if (values == null || !mounted) return;

    _nameController.text = values['name'] ?? _nameController.text;
    _emailController.text = values['email'] ?? _emailController.text;
    _phoneController.text = values['phone'] ?? _phoneController.text;
    await _saveProfile();
  }

  /// หน้าที่: ประมวลผลขั้นตอน change รหัสผ่าน สำหรับส่วน profile page (คลาส _ProfilePageState).
  Future<void> _changePassword() async {
    if (_userId == null || _userId! <= 0) {
      _showMessage('ไม่พบข้อมูลผู้ใช้', isError: true);
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ChangePasswordPage(userId: _userId!)),
    );
  }

  /// หน้าที่: ประมวลผลขั้นตอน logout สำหรับส่วน profile page (คลาส _ProfilePageState).
  Future<void> _logout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('ออกจากระบบ'),
        content: const Text('ต้องการออกจากระบบหรือไม่?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('ออกจากระบบ'),
          ),
        ],
      ),
    );
    if (shouldLogout != true) return;

    final prefs = await SharedPreferences.getInstance();
    await ApiClient.logout();
    await prefs.remove('current_admin_id');
    await prefs.remove('remember_login');
    await prefs.remove('remembered_user_id');
    await prefs.remove('remembered_role');
    await prefs.remove('api_token');
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const RoleSelectionScreen()),
      (_) => false,
    );
  }

  /// หน้าที่: เปิดหรือแสดงหน้าต่าง/ส่วน UI สำหรับ show ข้อความ (คลาส _ProfilePageState).
  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade700 : null,
      ),
    );
  }

  String get _roleLabel => switch (_role) {
    'seller' => 'ผู้ขาย',
    'buyer' => 'ผู้ซื้อ',
    'admin' => 'ผู้ดูแลระบบ',
    _ => 'ไม่ระบุบทบาท',
  };

  /// หน้าที่: สร้าง UI ส่วน Profile Header เพื่อใช้ในหน้าจอนี้ (คลาส _ProfilePageState).
  Widget _buildProfileHeader(ImageProvider<Object>? avatarImage) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 36,
                backgroundColor: _navy.withValues(alpha: 0.08),
                backgroundImage: avatarImage,
                child: avatarImage == null
                    ? Icon(
                        _role == 'admin'
                            ? Icons.shield_rounded
                            : Icons.person_rounded,
                        size: 38,
                        color: _navy,
                      )
                    : null,
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: IconButton.filled(
                  onPressed: _saving ? null : _pickProfileImage,
                  style: IconButton.styleFrom(
                    backgroundColor: _navy,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(30, 30),
                    maximumSize: const Size(30, 30),
                    padding: EdgeInsets.zero,
                  ),
                  icon: const Icon(Icons.camera_alt, size: 15),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _profile['name']?.toString() ?? _roleLabel,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 3),
          Text(
            _emailController.text,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFDCFCE7),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _role == 'admin' ? 'สิทธิ์ผู้ดูแลระบบ (Super Admin)' : _roleLabel,
              style: TextStyle(
                color: _role == 'admin' ? const Color(0xFF16A34A) : _navy,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// หน้าที่: สร้าง UI ส่วน Profile Menu เพื่อใช้ในหน้าจอนี้ (คลาส _ProfilePageState).
  Widget _buildProfileMenu({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color iconColor = _navy,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        child: ListTile(
          onTap: onTap,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 4,
          ),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          title: Text(
            title,
            style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
          ),
          subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
          trailing: const Icon(
            Icons.arrow_forward_ios_rounded,
            color: Color(0xFF94A3B8),
            size: 14,
          ),
        ),
      ),
    );
  }

  /// หน้าที่: เปิดหรือแสดงหน้าต่าง/ส่วน UI สำหรับ show โปรไฟล์ รายละเอียด (คลาส _ProfilePageState).
  void _showProfileDetails() {
    // ลบ "รหัสผู้ใช้ (ID)" ออกแล้ว ใช้ร่วมกันทั้ง buyer / seller / admin
    final details = [
      ('อีเมล', _profile['email']?.toString() ?? '-'),
      ('เบอร์โทรศัพท์', _profile['user_phone']?.toString() ?? '-'),
      ('วันที่สร้างบัญชี', _profile['user_created_at']?.toString() ?? '-'),
    ];

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'ข้อมูล$_roleLabel',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    for (var index = 0; index < details.length; index++) ...[
                      if (index > 0)
                        const Divider(height: 18, color: Color(0xFFE2E8F0)),
                      _buildInfoRow(
                        Icons.badge_outlined,
                        details[index].$1,
                        details[index].$2,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _navy,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => Navigator.pop(sheetContext),
                  child: const Text(
                    'ปิด',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// หน้าที่: สร้าง UI ส่วน Info Row เพื่อใช้ในหน้าจอนี้ (คลาส _ProfilePageState).
  Widget _buildInfoRow(IconData icon, String title, String value) {
    return Row(
      children: [
        Icon(icon, size: 17, color: const Color(0xFF64748B)),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
        ),
        const Spacer(),
        Expanded(
          flex: 2,
          child: Text(
            value,
            textAlign: TextAlign.right,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }

  /// หน้าที่: สร้าง UI ของหน้าจอหรือวิดเจ็ตใน profile page (คลาส _ProfilePageState).
  @override
  Widget build(BuildContext context) {
    final imageUrl = SellerApi.imageUrl(_profile['profile_image']);
    final ImageProvider<Object>? avatarImage = _newProfileImage != null
        ? MemoryImage(_newProfileImage!)
        : imageUrl == null
        ? null
        : NetworkImage(imageUrl);

    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _roleHeader,
        foregroundColor: Colors.white,
        title: Text(_role == 'admin' ? 'โปรไฟล์ผู้ดูแลระบบ' : 'โปรไฟล์'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.person_off_outlined, size: 42),
                    const SizedBox(height: 12),
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _requiresReauthentication
                          ? _startLoginAgain
                          : _loadProfile,
                      icon: Icon(
                        _requiresReauthentication
                            ? Icons.login_rounded
                            : Icons.refresh,
                      ),
                      label: Text(
                        _requiresReauthentication
                            ? 'เข้าสู่ระบบใหม่'
                            : 'ลองอีกครั้ง',
                      ),
                    ),
                  ],
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildProfileHeader(avatarImage),
                if (_newProfileImage != null) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 44,
                    child: OutlinedButton.icon(
                      onPressed: _saving ? null : _saveProfile,
                      icon: const Icon(Icons.save_outlined),
                      label: const Text('บันทึกรูปโปรไฟล์'),
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                const Text(
                  'การจัดการบัญชี',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 10),
                _buildProfileMenu(
                  icon: Icons.badge_outlined,
                  title: 'ดูข้อมูลส่วนตัว',
                  subtitle: 'อีเมล เบอร์โทรศัพท์ และรายละเอียดบัญชี',
                  onTap: _showProfileDetails,
                ),
                _buildProfileMenu(
                  icon: Icons.edit_outlined,
                  title: 'แก้ไขข้อมูลส่วนตัว',
                  subtitle: 'ชื่อ-นามสกุล อีเมล และเบอร์โทรศัพท์',
                  onTap: _saving ? () {} : _editProfile,
                ),
                _buildProfileMenu(
                  icon: Icons.lock_outline_rounded,
                  title: 'เปลี่ยนรหัสผ่าน',
                  subtitle: 'อัปเดตรหัสผ่านใหม่สำหรับเข้าใช้งาน',
                  onTap: _changePassword,
                ),
                if (_role == 'buyer') ...[
                  const SizedBox(height: 14),
                  const Text(
                    'การใช้งาน',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildProfileMenu(
                    icon: Icons.location_on_outlined,
                    title: 'ที่อยู่จัดส่ง',
                    subtitle: _addressCount > 0
                        ? 'บันทึกไว้ $_addressCount ที่อยู่'
                        : 'ยังไม่มีที่อยู่จัดส่ง',
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AddressListPage(userId: _userId!),
                        ),
                      );
                      _loadAddressCount(_userId!);
                    },
                  ),
                ],
                const SizedBox(height: 4),
                _buildProfileMenu(
                  icon: Icons.logout,
                  title: 'ออกจากระบบ',
                  subtitle: 'ออกจากบัญชีผู้ใช้นี้',
                  iconColor: Colors.red,
                  onTap: _logout,
                ),
              ],
            ),
    );
  }
}

class EditProfilePage extends StatefulWidget {
  final String name;
  final String email;
  final String phone;

  const EditProfilePage({
    super.key,
    required this.name,
    required this.email,
    required this.phone,
  });

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;

  /// หน้าที่: เตรียมสถานะเริ่มต้นของหน้าจอและเริ่มโหลดข้อมูลที่จำเป็น (คลาส _EditProfilePageState).
  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.name);
    _emailController = TextEditingController(text: widget.email);
    _phoneController = TextEditingController(text: widget.phone);
  }

  /// หน้าที่: คืนทรัพยากรของหน้าจอ เช่น controller และ listener ก่อนปิดหน้า (คลาส _EditProfilePageState).
  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  /// หน้าที่: บันทึกหรือสร้างข้อมูล save แล้วจัดการผลที่เซิร์ฟเวอร์ตอบกลับ (คลาส _EditProfilePageState).
  void _save() {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();

    if (name.isEmpty || email.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('กรุณากรอกชื่อและอีเมล')));
      return;
    }

    Navigator.pop(context, {
      'name': name,
      'email': email,
      'phone': _phoneController.text.trim(),
    });
  }

  /// หน้าที่: สร้าง UI ของหน้าจอหรือวิดเจ็ตใน profile page (คลาส _EditProfilePageState).
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('แก้ไขข้อมูลส่วนตัว')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _nameController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'ชื่อ-นามสกุล',
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'อีเมล',
                prefixIcon: Icon(Icons.email_outlined),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              inputFormatters: AppInputFormatters.phone(),
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                labelText: 'เบอร์โทรศัพท์',
                prefixIcon: Icon(Icons.phone_outlined),
              ),
            ),
            const SizedBox(height: 22),
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: _save,
                child: const Text('บันทึกข้อมูล'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
