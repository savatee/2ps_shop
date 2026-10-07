import 'package:flutter/material.dart';
import '../chat/chat_list_page.dart';
import '../wanted/wanted_feed_page.dart';
import 'seller_theme.dart';
import 'seller_add_product_screen.dart';
import 'seller_history_screen.dart';
import 'seller_orders_screen.dart';
import 'seller_products_screen.dart';
import '../profile/profile_page.dart';
import 'seller_sales_screen.dart';
import 'api/seller_api.dart';

class SellerHomeScreen extends StatefulWidget {
  final Map<String, dynamic> user;

  const SellerHomeScreen({super.key, required this.user});

  @override
  State<SellerHomeScreen> createState() => _SellerHomeScreenState();
}

class _SellerHomeScreenState extends State<SellerHomeScreen> {
  bool loading = true;

  double sales = 0;
  int orders = 0;
  int products = 0;

  int get sellerId {
    return int.tryParse('${widget.user['user_id']}') ?? 0;
  }

  /// หน้าที่: เตรียมสถานะเริ่มต้นของหน้าจอและเริ่มโหลดข้อมูลที่จำเป็น (คลาส _SellerHomeScreenState).
  @override
  void initState() {
    super.initState();
    loadDashboard();
  }

  /// หน้าที่: โหลดข้อมูล load ภาพรวมระบบ และอัปเดตสถานะการแสดงผลของหน้าจอ (คลาส _SellerHomeScreenState).
  Future<void> loadDashboard() async {
    try {
      final results = await Future.wait([
        SellerApi.products(sellerId),
        SellerApi.salesSummary(sellerId),
      ]);

      final p = results[0] as List;
      final s = results[1] as Map<String, dynamic>;

      if (!mounted) return;

      setState(() {
        products = p.length;
        sales = double.tryParse('${s['total_sales']}') ?? 0;
        orders = int.tryParse('${s['order_count']}') ?? 0;
        loading = false;
      });
    } catch (e) {
      debugPrint('Dashboard Error: $e');

      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  /// หน้าที่: นำทางไปยังหน้า go ตามบทบาทและข้อมูลที่เลือก (คลาส _SellerHomeScreenState).
  void go(Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page)).then((_) {
      loadDashboard();
    });
  }

  /// หน้าที่: สร้าง UI ของหน้าจอหรือวิดเจ็ตใน seller home screen (คลาส _SellerHomeScreenState).
  @override
  Widget build(BuildContext context) {
    final name = widget.user['name'] ?? 'ผู้ขาย';

    return Theme(
      data: SellerTheme.theme(),
      child: Scaffold(
        backgroundColor: SellerTheme.backgroundLight,
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: loadDashboard,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: SellerTheme.navy,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.shopping_bag_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      '2PS Shop',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0D356B),
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () {
                        go(ProfilePage(userId: sellerId));
                      },
                      icon: const Icon(
                        Icons.person_outline,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'สวัสดี, $name',
                            style: const TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'พร้อมดูแลทุกการขายของคุณ 😊',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 75,
                      height: 55,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE3F2FD),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.storefront_rounded,
                          size: 36,
                          color: Color(0xFF1976D2),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 18),

                Row(
                  children: [
                    Expanded(
                      child: statCard(
                        'ยอดขายรวม',
                        '฿${sales.toStringAsFixed(0)}',
                        Icons.account_balance_wallet_outlined,
                        const Color(0xFF1976D2),
                        const Color(0xFFE3F2FD),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: statCard(
                        'ออเดอร์',
                        '$orders',
                        Icons.receipt_long_outlined,
                        const Color(0xFF2E7D32),
                        const Color(0xFFE8F5E9),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: statCard(
                        'สินค้าทั้งหมด',
                        '$products',
                        Icons.inventory_2_outlined,
                        const Color(0xFF7B1FA2),
                        const Color(0xFFF3E5F5),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 4,
                          height: 16,
                          decoration: BoxDecoration(
                            color: SellerTheme.navy,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'เมนูหลัก',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Padding(
                      padding: EdgeInsets.only(left: 12),
                      child: Text(
                        'ตัวช่วยจัดการร้านของคุณ',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 0.95,
                  children: [
                    menu(
                      'สินค้าของฉัน',
                      Icons.shopping_bag_outlined,
                      const Color(0xFF1976D2),
                      const Color(0xFFE3F2FD),
                      () => go(SellerProductsScreen(sellerId: sellerId)),
                    ),
                    menu(
                      'โพสต์ขายสินค้า',
                      Icons.add_circle_outline,
                      const Color(0xFF2E7D32),
                      const Color(0xFFE8F5E9),
                      () => go(SellerAddProductScreen(sellerId: sellerId)),
                    ),
                    menu(
                      'ลูกค้าตามหาสินค้า',
                      Icons.search_outlined,
                      const Color(0xFF7B1FA2),
                      const Color(0xFFF3E5F5),
                      () =>
                          go(WantedFeedPage(userId: sellerId, isSeller: true)),
                    ),
                    menu(
                      'คำสั่งซื้อ',
                      Icons.receipt_long_outlined,
                      const Color(0xFFE65100),
                      const Color(0xFFFFF3E0),
                      () => go(SellerOrdersScreen(sellerId: sellerId)),
                    ),
                    menu(
                      'แชทกับลูกค้า',
                      Icons.chat_bubble_outline,
                      const Color(0xFFC2185B),
                      const Color(0xFFFCE4EC),
                      () => go(ChatListPage(userId: sellerId, isSeller: true)),
                    ),
                    menu(
                      'สรุปยอดขาย',
                      Icons.pie_chart_outline,
                      const Color(0xFF0288D1),
                      const Color(0xFFE1F5FE),
                      () => go(SellerSalesScreen(sellerId: sellerId)),
                    ),
                    menu(
                      'ประวัติการขาย',
                      Icons.bar_chart_outlined,
                      const Color(0xFF00796B),
                      const Color(0xFFE0F2F1),
                      () => go(SellerHistoryScreen(sellerId: sellerId)),
                    ),
                    menu(
                      'โปรไฟล์ร้าน',
                      Icons.person_outline,
                      const Color(0xFF512DA8),
                      const Color(0xFFEDE7F6),
                      () => go(ProfilePage(userId: sellerId)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// หน้าที่: ประมวลผลขั้นตอน stat Card สำหรับส่วน seller home screen (คลาส _SellerHomeScreenState).
  Widget statCard(
    String title,
    String value,
    IconData icon,
    Color iconColor,
    Color bgColor,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            blurRadius: 6,
            offset: Offset(0, 2),
            color: Color(0x0A000000),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: iconColor,
            ),
          ),
        ],
      ),
    );
  }

  /// หน้าที่: ประมวลผลขั้นตอน menu สำหรับส่วน seller home screen (คลาส _SellerHomeScreenState).
  Widget menu(
    String title,
    IconData icon,
    Color iconColor,
    Color bgColor,
    VoidCallback onTap,
  ) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFF0F0F0)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: bgColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 20, color: iconColor),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      title,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ),
                  const SizedBox(width: 2),
                  const Icon(
                    Icons.chevron_right,
                    size: 14,
                    color: Color(0xFF94A3B8),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
