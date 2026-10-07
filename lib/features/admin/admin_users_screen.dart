import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/utils/image_utils.dart';
import 'admin_api_service.dart';
import '../profile/profile_page.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  final TextEditingController _searchController = TextEditingController();

  List<dynamic> _users = [];
  bool _isLoading = true;
  Timer? _debounce;
  final int _currentIndex = 0;

  String _selectedRole = 'all';
  String _selectedStatus = 'all'; // all, active, inactive

  // Design tokens
  static const Color navy900 = Color(0xFF0B2545);
  static const Color navy700 = Color(0xFF14375F);
  static const Color slate900 = Color(0xFF0F172A);
  static const Color slate600 = Color(0xFF475569);
  static const Color slate500 = Color(0xFF64748B);
  static const Color slate400 = Color(0xFF94A3B8);
  static const Color slate100 = Color(0xFFF1F5F9);
  static const Color canvas = Color(0xFFF8FAFC);
  static const Color border = Color(0xFFE2E8F0);
  static const Color emerald500 = Color(0xFF10B981);
  static const Color rose500 = Color(0xFFF43F5E);
  static const Color sky600 = Color(0xFF0284C7);
  static const Color sky100 = Color(0xFFE0F2FE);

  // สีสำหรับผู้ซื้อ (ส้ม/แอมเบอร์)
  static const Color amber600 = Color(0xFFD97706);
  static const Color amber100 = Color(0xFFFEF3C7);

  /// หน้าที่: เตรียมสถานะเริ่มต้นของหน้าจอและเริ่มโหลดข้อมูลที่จำเป็น (คลาส _AdminUsersScreenState).
  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  /// หน้าที่: คืนทรัพยากรของหน้าจอ เช่น controller และ listener ก่อนปิดหน้า (คลาส _AdminUsersScreenState).
  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  /// หน้าที่: โหลดข้อมูล fetch ผู้ใช้ และอัปเดตสถานะการแสดงผลของหน้าจอ (คลาส _AdminUsersScreenState).
  Future<void> _fetchUsers() async {
    setState(() => _isLoading = true);
    try {
      final data = await AdminApiService.getUsers(
        role: _selectedRole,
        status: _selectedStatus,
        search: _searchController.text,
      );
      if (mounted) {
        setState(() {
          _users = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// หน้าที่: จัดการเหตุการณ์ on การค้นหา ที่เปลี่ยน จากการกดหรือกรอกข้อมูลของผู้ใช้ (คลาส _AdminUsersScreenState).
  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _fetchUsers();
    });
  }

  /// หน้าที่: อ่านหรือคำนวณค่า get ผู้ใช้ รูปภาพ URL จากข้อมูลปัจจุบัน (คลาส _AdminUsersScreenState).
  String? _getUserImageUrl(Map<String, dynamic> user) {
    final raw =
        user['profile_image'] ??
        user['user_image'] ??
        user['image'] ??
        user['avatar'] ??
        user['user_img'];

    if (raw != null && raw.toString().trim().isNotEmpty) {
      return buildImageUrl(raw.toString());
    }
    return null;
  }

  /// หน้าที่: เปิดหรือแสดงหน้าต่าง/ส่วน UI สำหรับ show ผู้ใช้ รายละเอียด Dialog (คลาส _AdminUsersScreenState).
  void _showUserDetailsDialog(Map<String, dynamic> user) {
    final int userId = user['user_id'] ?? 0;
    final String name = user['name'] ?? user['username'] ?? 'ผู้ใช้งาน';
    final String email = user['email'] ?? '-';
    final String phone = user['user_phone'] ?? user['phone'] ?? '-';
    final String role = user['role'] ?? 'buyer';
    final String userStatus = user['user_status'] ?? 'active';
    final bool isSuspended =
        (userStatus == 'inactive' || userStatus == 'suspended');
    final String initials =
        user['initials'] ?? (name.isNotEmpty ? name[0] : 'U');
    final String? imageUrl = _getUserImageUrl(user);
    final String createdAt = user['created_at'] ?? user['register_date'] ?? '-';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
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
                  color: border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 18),
              CircleAvatar(
                radius: 44,
                backgroundColor: isSuspended ? slate100 : amber100,
                child: ClipOval(
                  child: imageUrl != null
                      ? Image.network(
                          imageUrl,
                          width: 88,
                          height: 88,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Text(
                            initials,
                            style: TextStyle(
                              color: isSuspended ? slate400 : amber600,
                              fontSize: 30,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        )
                      : Text(
                          initials,
                          style: TextStyle(
                            color: isSuspended ? slate400 : amber600,
                            fontSize: 30,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                name,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: slate900,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildRoleChip(role),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: isSuspended
                          ? const Color(0xFFFEE2E2)
                          : const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      isSuspended ? 'ถูกระงับบัญชี' : 'สถานะปกติ',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isSuspended ? rose500 : emerald500,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: canvas,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: border),
                ),
                child: Column(
                  children: [
                    _buildDetailRow(
                      Icons.tag_rounded,
                      'รหัสสมาชิก (ID)',
                      '#$userId',
                    ),
                    const Divider(height: 18, color: border),
                    _buildDetailRow(Icons.email_outlined, 'อีเมล', email),
                    const Divider(height: 18, color: border),
                    _buildDetailRow(
                      Icons.phone_outlined,
                      'เบอร์โทรศัพท์',
                      phone,
                    ),
                    if (createdAt != '-') ...[
                      const Divider(height: 18, color: border),
                      _buildDetailRow(
                        Icons.calendar_today_outlined,
                        'วันที่สมัคร',
                        createdAt,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: navy900,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text(
                    'ปิด',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// หน้าที่: สร้าง UI ส่วน Detail Row เพื่อใช้ในหน้าจอนี้ (คลาส _AdminUsersScreenState).
  Widget _buildDetailRow(IconData icon, String title, String value) {
    return Row(
      children: [
        Icon(icon, size: 17, color: slate500),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            fontSize: 13,
            color: slate500,
            fontWeight: FontWeight.w500,
          ),
        ),
        const Spacer(),
        Expanded(
          flex: 2,
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: slate900,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  /// หน้าที่: สลับค่า toggle ผู้ใช้ สถานะ และอัปเดตหน้าจอตามสถานะใหม่ (คลาส _AdminUsersScreenState).
  Future<void> _toggleUserStatus(int userId, String currentStatus) async {
    final bool isCurrentlySuspended =
        (currentStatus == 'inactive' || currentStatus == 'suspended');
    final String newStatus = isCurrentlySuspended ? 'active' : 'inactive';
    final String actionName = isCurrentlySuspended
        ? 'เปิดใช้งานบัญชี'
        : 'ระงับบัญชี';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'ยืนยัน$actionName',
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        content: Text('คุณต้องการ$actionNameของผู้ใช้นี้ใช่หรือไม่?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('ยกเลิก', style: TextStyle(color: slate500)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isCurrentlySuspended ? emerald500 : rose500,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('ยืนยัน', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final success = await AdminApiService.updateUserStatus(userId, newStatus);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? '$actionNameสำเร็จ'
                : 'เกิดข้อผิดพลาด กรุณาลองใหม่อีกครั้ง',
          ),
          backgroundColor: success ? emerald500 : rose500,
          behavior: SnackBarBehavior.floating,
        ),
      );
      if (success) _fetchUsers();
    }
  }

  /// หน้าที่: เปิดหรือแสดงหน้าต่าง/ส่วน UI สำหรับ show Role Selection Dialog (คลาส _AdminUsersScreenState).
  void _showRoleSelectionDialog(int userId, String currentRole) {
    final roles = [
      {'key': 'buyer', 'label': 'ผู้ซื้อ'},
      {'key': 'seller', 'label': 'ผู้ขาย'},
      {'key': 'admin', 'label': 'แอดมิน'},
    ];

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'เปลี่ยนสิทธิ์การใช้งาน',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                ...roles.map((r) {
                  final isCurrent = r['key'] == currentRole;
                  return ListTile(
                    title: Text(
                      r['label']!,
                      style: TextStyle(
                        fontWeight: isCurrent
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: isCurrent ? navy900 : slate900,
                      ),
                    ),
                    trailing: isCurrent
                        ? const Icon(Icons.check_circle_rounded, color: navy900)
                        : null,
                    onTap: () async {
                      Navigator.pop(ctx);
                      if (isCurrent) return;

                      final ok = await AdminApiService.updateUserRole(
                        userId,
                        r['key']!,
                      );
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              ok
                                  ? 'เปลี่ยนสิทธิ์เป็น ${r['label']} สำเร็จ'
                                  : 'เปลี่ยนสิทธิ์ไม่สำเร็จ',
                            ),
                            backgroundColor: ok ? emerald500 : rose500,
                          ),
                        );
                        if (ok) _fetchUsers();
                      }
                    },
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  /// หน้าที่: สร้าง UI ของหน้าจอหรือวิดเจ็ตใน admin users screen (คลาส _AdminUsersScreenState).
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: canvas,
      body: Column(
        children: [
          _buildHeader(),
          _buildRoleFilterBar(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _fetchUsers,
              color: navy900,
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _users.isEmpty
                  ? const Center(
                      child: Text(
                        'ไม่พบข้อมูลผู้ใช้งาน',
                        style: TextStyle(color: slate400),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                      itemCount: _users.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final user = _users[index];
                        return _buildUserCard(user);
                      },
                    ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  /// หน้าที่: สร้าง UI ส่วน Header เพื่อใช้ในหน้าจอนี้ (คลาส _AdminUsersScreenState).
  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [navy900, navy700],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(
                      Icons.arrow_back_rounded,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'จัดการผู้ใช้งาน',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'แตะที่รายชื่อเพื่อดูข้อมูล หรือกด 3 จุดเพื่อจัดการ',
                        style: TextStyle(
                          color: Color(0xFFB8C6D9),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  style: const TextStyle(fontSize: 13.5, color: slate900),
                  decoration: InputDecoration(
                    hintText: 'ค้นหาชื่อ, เบอร์ หรืออีเมล...',
                    hintStyle: const TextStyle(color: slate400, fontSize: 13),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: slate400,
                      size: 20,
                    ),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(
                              Icons.close_rounded,
                              size: 18,
                              color: slate400,
                            ),
                            onPressed: () {
                              _searchController.clear();
                              _fetchUsers();
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// หน้าที่: สร้าง UI ส่วน Role Filter Bar เพื่อใช้ในหน้าจอนี้ (คลาส _AdminUsersScreenState).
  Widget _buildRoleFilterBar() {
    final roles = [
      {'key': 'all', 'label': 'ทั้งหมด'},
      {'key': 'buyer', 'label': 'ผู้ซื้อ'},
      {'key': 'seller', 'label': 'ผู้ขาย'},
      {'key': 'admin', 'label': 'แอดมิน'},
    ];

    String statusLabel = 'สถานะ: ทั้งหมด';
    if (_selectedStatus == 'active') statusLabel = 'สถานะ: ปกติ';
    if (_selectedStatus == 'inactive') statusLabel = 'สถานะ: ถูกระงับ';

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        children: [
          Row(
            children: roles.map((r) {
              final isSel = _selectedRole == r['key'];
              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() => _selectedRole = r['key']!);
                    _fetchUsers();
                  },
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: isSel ? navy900 : slate100,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      r['label']!,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                        color: isSel ? Colors.white : slate600,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'พบ ${_users.length} รายชื่อ',
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: slate500,
                ),
              ),
              PopupMenuButton<String>(
                initialValue: _selectedStatus,
                onSelected: (val) {
                  setState(() => _selectedStatus = val);
                  _fetchUsers();
                },
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'all',
                    child: Text('สถานะทั้งหมด', style: TextStyle(fontSize: 13)),
                  ),
                  const PopupMenuItem(
                    value: 'active',
                    child: Text('ใช้งานปกติ', style: TextStyle(fontSize: 13)),
                  ),
                  const PopupMenuItem(
                    value: 'inactive',
                    child: Text(
                      'ถูกระงับบัญชี',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ],
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: _selectedStatus == 'all'
                        ? slate100
                        : const Color(0xFFEEF2FF),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _selectedStatus == 'all'
                          ? border
                          : const Color(0xFFC7D2FE),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.shield_outlined,
                        size: 14,
                        color: _selectedStatus == 'all'
                            ? slate600
                            : const Color(0xFF4338CA),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        statusLabel,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: _selectedStatus == 'all'
                              ? slate600
                              : const Color(0xFF4338CA),
                        ),
                      ),
                      const SizedBox(width: 2),
                      const Icon(
                        Icons.arrow_drop_down_rounded,
                        size: 18,
                        color: slate600,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// หน้าที่: สร้าง UI ส่วน User Card เพื่อใช้ในหน้าจอนี้ (คลาส _AdminUsersScreenState).
  Widget _buildUserCard(Map<String, dynamic> user) {
    final int userId = user['user_id'] ?? 0;
    final String name = user['name'] ?? 'ผู้ใช้งาน';
    final String email = user['email'] ?? '';
    final String role = user['role'] ?? 'buyer';
    final String userStatus = user['user_status'] ?? 'active';
    final bool isSuspended =
        (userStatus == 'inactive' || userStatus == 'suspended');
    final String initials =
        user['initials'] ?? (name.isNotEmpty ? name[0] : 'U');
    final String? imageUrl = _getUserImageUrl(user);

    Color avatarBg = amber100;
    Color avatarText = amber600;
    if (role == 'seller') {
      avatarBg = const Color(0xFFE0E7FF);
      avatarText = const Color(0xFF4338CA);
    } else if (role == 'admin') {
      avatarBg = sky100;
      avatarText = sky600;
    }

    if (isSuspended) {
      avatarBg = slate100;
      avatarText = slate400;
    }

    return Material(
      color: isSuspended ? const Color(0xFFFAFAFA) : Colors.white,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isSuspended ? const Color(0xFFFECDD3) : border,
          width: 1.2,
        ),
      ),
      child: ListTile(
        onTap: () => _showUserDetailsDialog(user),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: CircleAvatar(
          backgroundColor: avatarBg,
          radius: 20,
          child: ClipOval(
            child: (imageUrl != null)
                ? Image.network(
                    imageUrl,
                    width: 40,
                    height: 40,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Center(
                        child: Text(
                          initials,
                          style: TextStyle(
                            color: avatarText,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      );
                    },
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return const Center(
                        child: SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(strokeWidth: 1.8),
                        ),
                      );
                    },
                  )
                : Text(
                    initials,
                    style: TextStyle(
                      color: avatarText,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
          ),
        ),
        title: Row(
          children: [
            Flexible(
              child: Text(
                name,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: isSuspended ? slate500 : slate900,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            _buildRoleChip(role),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  email.isNotEmpty ? email : (user['user_phone'] ?? '-'),
                  style: const TextStyle(fontSize: 11.5, color: slate500),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 7,
                  vertical: 2.5,
                ),
                decoration: BoxDecoration(
                  color: isSuspended
                      ? const Color(0xFFFEE2E2)
                      : const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isSuspended
                          ? Icons.cancel_rounded
                          : Icons.check_circle_rounded,
                      size: 11,
                      color: isSuspended ? rose500 : emerald500,
                    ),
                    const SizedBox(width: 3.5),
                    Text(
                      isSuspended ? 'ถูกระงับ' : 'ปกติ',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: isSuspended ? rose500 : emerald500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert_rounded, color: slate400, size: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          onSelected: (val) {
            if (val == 'view') {
              _showUserDetailsDialog(user);
            } else if (val == 'role') {
              _showRoleSelectionDialog(userId, role);
            } else if (val == 'status') {
              _toggleUserStatus(userId, userStatus);
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'view',
              child: Row(
                children: [
                  Icon(Icons.visibility_outlined, size: 18, color: navy900),
                  SizedBox(width: 10),
                  Text('ดูข้อมูลผู้ใช้งาน', style: TextStyle(fontSize: 13)),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'role',
              child: Row(
                children: [
                  Icon(Icons.badge_outlined, size: 18, color: navy900),
                  SizedBox(width: 10),
                  Text('เปลี่ยนสิทธิ์/บทบาท', style: TextStyle(fontSize: 13)),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'status',
              child: Row(
                children: [
                  Icon(
                    isSuspended
                        ? Icons.check_circle_outline_rounded
                        : Icons.block_flipped,
                    size: 18,
                    color: isSuspended ? emerald500 : rose500,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    isSuspended ? 'เปิดใช้งานบัญชี' : 'ระงับบัญชีนี้',
                    style: TextStyle(
                      fontSize: 13,
                      color: isSuspended ? emerald500 : rose500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// หน้าที่: สร้าง UI ส่วน Role Chip เพื่อใช้ในหน้าจอนี้ (คลาส _AdminUsersScreenState).
  Widget _buildRoleChip(String role) {
    String label = 'ผู้ซื้อ';
    Color bg = amber100;
    Color color = amber600;

    if (role == 'seller') {
      label = 'ผู้ขาย';
      bg = const Color(0xFFE0E7FF);
      color = const Color(0xFF4338CA);
    } else if (role == 'admin') {
      label = 'แอดมิน';
      bg = sky100;
      color = sky600;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  /// หน้าที่: สร้าง UI ส่วน Bottom Nav เพื่อใช้ในหน้าจอนี้ (คลาส _AdminUsersScreenState).
  Widget _buildBottomNav() {
    return BottomNavigationBar(
      currentIndex: _currentIndex,
      onTap: (index) {
        if (index == _currentIndex) return;

        if (index == 0) {
          Navigator.pop(context);
        } else if (index == 1) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const ProfilePage()),
          );
        }
      },
      selectedItemColor: navy900,
      unselectedItemColor: slate400,
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.dashboard_rounded),
          label: 'หน้าหลัก',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person_rounded),
          label: 'โปรไฟล์',
        ),
      ],
    );
  }
}
