import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/utils/image_utils.dart';
import 'admin_api_service.dart';
import 'admin_products_screen.dart';
import '../profile/profile_page.dart';
import 'admin_reports_screen.dart';
import 'admin_users_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  bool isLoading = true;
  Map<String, dynamic>? dashboardData;
  int _currentIndex = 0;

  // ── Design tokens ────────────────────────────────────────────────
  final Color navy900 = const Color(0xFF0B2545);
  final Color navy700 = const Color(0xFF14375F);
  final Color slate900 = const Color(0xFF0F172A);
  final Color slate600 = const Color(0xFF475569);
  final Color slate500 = const Color(0xFF64748B);
  final Color slate400 = const Color(0xFF94A3B8);
  final Color slate100 = const Color(0xFFF1F5F9);
  final Color border = const Color(0xFFE6EBF2);
  final Color canvas = const Color(0xFFF4F6FA);
  final Color emerald500 = const Color(0xFF10B981);
  final Color rose500 = const Color(0xFFF43F5E);
  final Color amber500 = const Color(0xFFF59E0B);
  final Color indigo600 = const Color(0xFF4F46E5);
  final Color sky500 = const Color(0xFF0EA5E9);

  /// หน้าที่: เตรียมสถานะเริ่มต้นของหน้าจอและเริ่มโหลดข้อมูลที่จำเป็น (คลาส _AdminDashboardScreenState).
  @override
  void initState() {
    super.initState();
    fetchDashboardData();
  }

  /// หน้าที่: โหลดข้อมูล fetch ภาพรวมระบบ ข้อมูล และอัปเดตสถานะการแสดงผลของหน้าจอ (คลาส _AdminDashboardScreenState).
  Future<void> fetchDashboardData() async {
    setState(() => isLoading = true);
    final data = await AdminApiService.getDashboardStats();
    if (mounted) {
      setState(() {
        dashboardData = data;
        isLoading = false;
      });
    }
  }

  /// หน้าที่: จัดการเหตุการณ์ handle สินค้า Action จากการกดหรือกรอกข้อมูลของผู้ใช้ (คลาส _AdminDashboardScreenState).
  Future<void> handleProductAction(int productId, String action) async {
    final status = (action == 'approve') ? 'active' : 'rejected';
    final success = await AdminApiService.updateProductStatus(
      productId,
      status,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                success ? Icons.check_circle_rounded : Icons.error_rounded,
                color: Colors.white,
                size: 18,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  success
                      ? (action == 'approve'
                            ? 'อนุมัติสินค้าสำเร็จ'
                            : 'ปฏิเสธสินค้าแล้ว')
                      : 'เกิดข้อผิดพลาด กรุณาลองใหม่อีกครั้ง',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: action == 'approve' && success
              ? emerald500
              : rose500,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      if (success) fetchDashboardData();
    }
  }

  /// หน้าที่: จัดรูปแบบข้อมูล format จำนวนเงิน ก่อนนำไปแสดงผล (คลาส _AdminDashboardScreenState).
  String formatCurrency(num number) => NumberFormat('#,###').format(number);

  /// หน้าที่: สร้าง UI ของหน้าจอหรือวิดเจ็ตใน admin dashboard screen (คลาส _AdminDashboardScreenState).
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: canvas,
      body: Column(
        children: [
          // 1. ส่วนหัว Header สีกรมท่า + การ์ดยอดขาย
          _buildHeroHeader(dashboardData?['sales_overview']),

          // 2. เนื้อหาหลักที่เลื่อนได้
          Expanded(
            child: RefreshIndicator(
              onRefresh: fetchDashboardData,
              color: navy900,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // สถิติย่อ 2 ช่อง
                    _buildQuickMetrics(),
                    const SizedBox(height: 24),

                    // เมนูปุ่มลัดการจัดการระบบ
                    _buildSectionTitle('การจัดการระบบ'),
                    const SizedBox(height: 12),
                    _buildActionGrid(),
                    const SizedBox(height: 12),

                    // รายการคิวสินค้ารอตรวจสอบ
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            _buildSectionTitle('สินค้ารอตรวจสอบ'),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF3C7),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '${dashboardData?['pending_approval']?['count'] ?? 0}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFFB45309),
                                ),
                              ),
                            ),
                          ],
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const AdminProductsScreen(
                                  initialStatus: 'pending',
                                ),
                              ),
                            ).then((_) => fetchDashboardData());
                          },
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(50, 30),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(
                            'ดูทั้งหมด',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: indigo600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildPendingProductSection(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  /// หน้าที่: สร้าง UI ส่วน Section Title เพื่อใช้ในหน้าจอนี้ (คลาส _AdminDashboardScreenState).
  Widget _buildSectionTitle(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w800,
        color: slate900,
        letterSpacing: -0.2,
      ),
    );
  }

  // ── Header สีกรมท่า + ยอดขายรวม ─────────────────────────────────
  Widget _buildHeroHeader(Map<String, dynamic>? sales) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [navy900, navy700],
        ),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: navy900.withValues(alpha: 0.18),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                color: emerald500,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: emerald500.withValues(alpha: 0.6),
                                    blurRadius: 6,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 7),
                            Text(
                              '2PS SHOP · ADMIN CONSOLE',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: Colors.white.withValues(alpha: 0.72),
                                letterSpacing: 1.0,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        const Text(
                          'ภาพรวมระบบ',
                          style: TextStyle(
                            fontSize: 23,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ProfilePage(),
                        ),
                      );
                    },
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.22),
                        ),
                      ),
                      child: const Icon(
                        Icons.person_rounded,
                        size: 21,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.14),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'ยอดขายรวมทั้งระบบ',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.72),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            sales?['month_label'] ?? 'กันยายน 2026',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    isLoading
                        ? Container(
                            width: 150,
                            height: 34,
                            margin: const EdgeInsets.symmetric(vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                          )
                        : Text(
                            '฿${formatCurrency(sales?['total_sales'] ?? 0)}',
                            style: const TextStyle(
                              fontSize: 34,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -1,
                            ),
                          ),
                    const SizedBox(height: 14),
                    Divider(
                      color: Colors.white.withValues(alpha: 0.14),
                      height: 1,
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _buildHeroStat(
                            icon: Icons.check_rounded,
                            tint: emerald500,
                            label: 'คำสั่งซื้อสำเร็จ',
                            value: '${sales?['completed_orders'] ?? 0} รายการ',
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 32,
                          color: Colors.white.withValues(alpha: 0.12),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildHeroStat(
                            icon: Icons.sync_alt_rounded,
                            tint: sky500,
                            label: 'คำขอที่เปิดอยู่',
                            value: '${sales?['open_requests'] ?? 0} รายการ',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// หน้าที่: สร้าง UI ส่วน Hero Stat เพื่อใช้ในหน้าจอนี้ (คลาส _AdminDashboardScreenState).
  Widget _buildHeroStat({
    required IconData icon,
    required Color tint,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: tint.withValues(alpha: 0.22),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 14, color: tint),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.62),
                  fontSize: 10.5,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 1),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── สถิติย่อ 2 ช่อง ─────────────────────────────────────────────
  Widget _buildQuickMetrics() {
    return Row(
      children: [
        Expanded(
          child: InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      const AdminProductsScreen(initialStatus: 'pending'),
                ),
              ).then((_) => fetchDashboardData());
            },
            borderRadius: BorderRadius.circular(18),
            child: _buildMetricTile(
              icon: Icons.pending_actions_rounded,
              title: 'สินค้าค้างอนุมัติ',
              value: '${dashboardData?['pending_approval']?['count'] ?? 0}',
              unit: 'รายการ',
              tint: amber500,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AdminUsersScreen(),
                ),
              );
            },
            borderRadius: BorderRadius.circular(18),
            child: _buildMetricTile(
              icon: Icons.groups_rounded,
              title: 'ผู้ใช้งานทั้งหมด',
              value: formatCurrency(
                dashboardData?['users_summary']?['total_users'] ?? 0,
              ),
              unit: 'คน',
              tint: emerald500,
            ),
          ),
        ),
      ],
    );
  }

  /// หน้าที่: สร้าง UI ส่วน Metric Tile เพื่อใช้ในหน้าจอนี้ (คลาส _AdminDashboardScreenState).
  Widget _buildMetricTile({
    required IconData icon,
    required String title,
    required String value,
    required String unit,
    required Color tint,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0B2545).withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: tint.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 15, color: tint),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: slate500,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: slate900,
                  letterSpacing: -0.6,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                unit,
                style: TextStyle(
                  fontSize: 12,
                  color: slate500,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── ปุ่มลัด 3 ช่อง ──────────────────────────────────────────────
  Widget _buildActionGrid() {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _buildQuickActionBtn(
              icon: Icons.inventory_2_rounded,
              tint: indigo600,
              label: 'คลังสินค้า',
              badge: '${dashboardData?['pending_approval']?['count'] ?? 0}',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        const AdminProductsScreen(initialStatus: 'all'),
                  ),
                ).then((_) => fetchDashboardData());
              },
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildQuickActionBtn(
              icon: Icons.manage_accounts_rounded,
              tint: indigo600,
              label: 'จัดการผู้ใช้',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AdminUsersScreen(),
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildQuickActionBtn(
              icon: Icons.insert_chart_rounded,
              tint: sky500,
              label: 'รายงานยอดขาย',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AdminReportsScreen(),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// หน้าที่: สร้าง UI ส่วน Quick Action Btn เพื่อใช้ในหน้าจอนี้ (คลาส _AdminDashboardScreenState).
  Widget _buildQuickActionBtn({
    required IconData icon,
    required Color tint,
    required String label,
    String? badge,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: border),
          ),
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: tint.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(icon, size: 21, color: tint),
                  ),
                  const SizedBox(height: 9),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: slate900,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
              if (badge != null && badge != '0')
                Positioned(
                  top: -4,
                  right: 2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: rose500,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: Text(
                      badge,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ── รายการคิวสินค้ารออนุมัติ ─────────────────────────────────────
  Widget _buildPendingProductSection() {
    if (isLoading) {
      return Column(children: List.generate(2, (_) => _buildSkeletonCard()));
    }

    final list = dashboardData?['pending_products'] as List?;
    if (list == null || list.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 34, horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: border),
        ),
        child: Column(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: emerald500.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.task_alt_rounded, size: 26, color: emerald500),
            ),
            const SizedBox(height: 12),
            Text(
              'ตรวจสอบครบแล้ว',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: slate900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'ไม่มีสินค้ารออนุมัติในระบบ',
              style: TextStyle(color: slate500, fontSize: 12.5),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: list.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final item = list[index];
        return _buildProductListItem(item);
      },
    );
  }

  /// หน้าที่: สร้าง UI ส่วน Skeleton Card เพื่อใช้ในหน้าจอนี้ (คลาส _AdminDashboardScreenState).
  Widget _buildSkeletonCard() {
    return Container(
      height: 96,
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: slate100,
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(height: 12, width: 140, color: slate100),
                  const SizedBox(height: 8),
                  Container(height: 10, width: 90, color: slate100),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// หน้าที่: สร้าง UI ส่วน Product List Item เพื่อใช้ในหน้าจอนี้ (คลาส _AdminDashboardScreenState).
  Widget _buildProductListItem(Map<String, dynamic> item) {
    final String? imageUrl = buildImageUrl(item['product_image']?.toString());

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0B2545).withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              // กล่องแสดงรูปสินค้า
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: slate100,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: imageUrl != null
                      ? Image.network(
                          imageUrl,
                          width: 48,
                          height: 48,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Icon(
                            Icons.storefront_outlined,
                            color: slate600,
                            size: 22,
                          ),
                          loadingBuilder: (context, child, progress) {
                            if (progress == null) return child;
                            return const Center(
                              child: SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 1.8,
                                ),
                              ),
                            );
                          },
                        )
                      : Icon(
                          Icons.storefront_outlined,
                          color: slate600,
                          size: 22,
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['product_name'] ?? '',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: slate900,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Icon(
                          Icons.storefront_outlined,
                          size: 12,
                          color: slate400,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            '${item['seller_name'] ?? '-'}',
                            style: TextStyle(fontSize: 11.5, color: slate500),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Text(
                          '฿${formatCurrency(item['price'] ?? 0)}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: slate900,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '· ${item['time_ago'] ?? ''}',
                          style: TextStyle(fontSize: 11, color: slate400),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => handleProductAction(item['id'], 'reject'),
                  icon: Icon(Icons.close_rounded, size: 17, color: rose500),
                  label: Text(
                    'ปฏิเสธ',
                    style: TextStyle(
                      color: rose500,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    side: BorderSide(color: rose500.withValues(alpha: 0.35)),
                    backgroundColor: rose500.withValues(alpha: 0.05),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => handleProductAction(item['id'], 'approve'),
                  icon: const Icon(
                    Icons.check_rounded,
                    size: 17,
                    color: Colors.white,
                  ),
                  label: const Text(
                    'อนุมัติ',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: emerald500,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// หน้าที่: สร้าง UI ส่วน Bottom Nav เพื่อใช้ในหน้าจอนี้ (คลาส _AdminDashboardScreenState).
  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: border)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0B2545).withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: _currentIndex,
        elevation: 0,
        backgroundColor: Colors.transparent,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: navy900,
        unselectedItemColor: slate400,
        selectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 11.5,
        ),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 11.5,
        ),
        onTap: (index) {
          setState(() => _currentIndex = index);
          if (index == 1) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ProfilePage()),
            ).then((_) {
              if (mounted) setState(() => _currentIndex = 0);
            });
          }
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.grid_view_rounded),
            label: 'แดชบอร์ด',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline_rounded),
            label: 'โปรไฟล์',
          ),
        ],
      ),
    );
  }
}
