import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'admin_api_service.dart';
import '../profile/profile_page.dart';

class AdminReportsScreen extends StatefulWidget {
  const AdminReportsScreen({super.key});

  @override
  State<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends State<AdminReportsScreen> {
  bool _isLoading = true;
  List<dynamic> _categories = [];
  int _totalCategories = 0;
  int _currentIndex = 0;

  // Design tokens
  static const Color navy900 = Color(0xFF0B2545);
  static const Color navy700 = Color(0xFF14375F);
  static const Color slate900 = Color(0xFF0F172A);
  static const Color slate500 = Color(0xFF64748B);
  static const Color slate400 = Color(0xFF94A3B8);
  static const Color slate100 = Color(0xFFF1F5F9);
  static const Color border = Color(0xFFE6EBF2);
  static const Color canvas = Color(0xFFF4F6FA);

  /// หน้าที่: เตรียมสถานะเริ่มต้นของหน้าจอและเริ่มโหลดข้อมูลที่จำเป็น (คลาส _AdminReportsScreenState).
  @override
  void initState() {
    super.initState();
    _fetchReportData();
  }

  /// หน้าที่: โหลดข้อมูล fetch รายงาน ข้อมูล และอัปเดตสถานะการแสดงผลของหน้าจอ (คลาส _AdminReportsScreenState).
  Future<void> _fetchReportData() async {
    setState(() => _isLoading = true);

    final data = await AdminApiService.getSalesReport();

    if (mounted) {
      if (data != null) {
        setState(() {
          _categories = data['categories'] ?? [];
          _totalCategories = data['total_categories'] ?? 0;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    }
  }

  /// หน้าที่: จัดรูปแบบข้อมูล format จำนวนเงิน ก่อนนำไปแสดงผล (คลาส _AdminReportsScreenState).
  String formatCurrency(num number) {
    return NumberFormat('#,###').format(number);
  }

  /// หน้าที่: แปลงค่าเป็นจำนวนเต็ม และใช้ค่าเริ่มต้นเมื่อแปลงไม่ได้ (คลาส _AdminReportsScreenState).
  int _asInt(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
  }

  num _asNum(dynamic value) {
    if (value is num) return value;
    return num.tryParse(value.toString()) ?? 0;
  }

  /// หน้าที่: แปลงข้อมูลเป็นสี หากแปลงไม่ได้ให้ใช้สีเริ่มต้น (คลาส _AdminReportsScreenState).
  Color _asColor(dynamic value) {
    final parsed = int.tryParse(value.toString());
    return parsed == null ? slate400 : Color(parsed);
  }

  num get _totalSales {
    num sum = 0;
    for (final c in _categories) {
      sum += _asNum(c['sales']);
    }
    return sum;
  }

  /// หน้าที่: สร้าง UI ของหน้าจอหรือวิดเจ็ตใน admin reports screen (คลาส _AdminReportsScreenState).
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: canvas,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _fetchReportData,
              color: navy900,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
                child: _isLoading
                    ? _buildSkeleton()
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildTotalCard(),
                          const SizedBox(height: 16),
                          _buildBreakdownCard(),
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

  /// หน้าที่: สร้าง UI ส่วน Header เพื่อใช้ในหน้าจอนี้ (คลาส _AdminReportsScreenState).
  Widget _buildHeader() {
    return Container(
      width: double.infinity,
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
          padding: const EdgeInsets.fromLTRB(12, 8, 16, 18),
          child: Row(
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(
                  Icons.arrow_back_rounded,
                  color: Colors.white,
                  size: 22,
                ),
                tooltip: 'กลับหน้าหลัก',
              ),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'รายงานยอดขาย',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'สรุปยอดขายทั้งระบบตามหมวดหมู่',
                      style: TextStyle(
                        color: Color(0xFFB8C6D9),
                        fontSize: 11.5,
                      ),
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

  /// หน้าที่: สร้าง UI ส่วน Total Card เพื่อใช้ในหน้าจอนี้ (คลาส _AdminReportsScreenState).
  Widget _buildTotalCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: navy900.withValues(alpha: 0.04),
            blurRadius: 12,
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
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: navy900.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.payments_rounded,
                  size: 17,
                  color: navy900,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'ยอดขายรวมทุกหมวด',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: slate500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '฿${formatCurrency(_totalSales)}',
            style: const TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              color: slate900,
              letterSpacing: -0.8,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'แบ่งเป็น $_totalCategories หมวดหมู่',
            style: const TextStyle(fontSize: 12, color: slate400),
          ),
        ],
      ),
    );
  }

  /// หน้าที่: สร้าง UI ส่วน Breakdown Card เพื่อใช้ในหน้าจอนี้ (คลาส _AdminReportsScreenState).
  Widget _buildBreakdownCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: navy900.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'สัดส่วนตามหมวดหมู่',
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w800,
              color: slate900,
            ),
          ),
          const SizedBox(height: 14),
          if (_categories.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                height: 12,
                child: Row(
                  children: _categories.map((cat) {
                    final percent = _asInt(cat['percentage']);
                    return Expanded(
                      flex: percent > 0 ? percent : 1,
                      child: Container(color: _asColor(cat['color'])),
                    );
                  }).toList(),
                ),
              ),
            )
          else
            Container(
              height: 12,
              decoration: BoxDecoration(
                color: slate100,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          const SizedBox(height: 18),
          if (_categories.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 26),
              child: Center(
                child: Column(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: const BoxDecoration(
                        color: slate100,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.bar_chart_rounded,
                        color: slate400,
                        size: 24,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'ยังไม่มีข้อมูลยอดขาย',
                      style: TextStyle(
                        color: slate900,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    const Text(
                      'ข้อมูลจะแสดงเมื่อมีคำสั่งซื้อในระบบ',
                      style: TextStyle(color: slate500, fontSize: 12),
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _categories.length,
              separatorBuilder: (_, _) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                final item = _categories[index];
                final color = _asColor(item['color']);
                final percent = _asInt(item['percentage']);

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Text(
                            '${item['name']}',
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF334155),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '฿${formatCurrency(_asNum(item['sales']))}',
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: slate900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: (percent.clamp(0, 100)) / 100,
                              minHeight: 6,
                              backgroundColor: slate100,
                              valueColor: AlwaysStoppedAnimation<Color>(color),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        SizedBox(
                          width: 38,
                          child: Text(
                            '$percent%',
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: slate500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  /// หน้าที่: สร้าง UI ส่วน Skeleton เพื่อใช้ในหน้าจอนี้ (คลาส _AdminReportsScreenState).
  Widget _buildSkeleton() {
    return Column(
      children: [
        Container(
          height: 130,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: border),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          height: 260,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: border),
          ),
          child: const Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.4),
            ),
          ),
        ),
      ],
    );
  }

  /// หน้าที่: สร้าง UI ส่วน Bottom Nav เพื่อใช้ในหน้าจอนี้ (คลาส _AdminReportsScreenState).
  Widget _buildBottomNav() {
    return BottomNavigationBar(
      currentIndex: _currentIndex,
      onTap: (index) {
        if (index == 0) {
          // กดหน้าหลัก -> ปิดหน้ารายงานกลับหน้า Dashboard
          Navigator.pop(context);
        } else if (index == 1) {
          setState(() => _currentIndex = 1);
          // สลับเปิดไปหน้าโปรไฟล์ทันที
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
