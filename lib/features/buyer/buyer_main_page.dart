import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'buyer_home_page.dart';
import '../wanted/wanted_feed_page.dart';
import 'buyer_orders_page.dart';
import '../profile/profile_page.dart';

class BuyerMainPage extends StatefulWidget {
  final int userId;
  final int initialTab;

  const BuyerMainPage({super.key, required this.userId, this.initialTab = 0});

  @override
  State<BuyerMainPage> createState() => _BuyerMainPageState();
}

class _BuyerMainPageState extends State<BuyerMainPage> {
  late int _currentIndex;

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();

    // กำหนดแท็บเริ่มต้น
    _currentIndex = widget.initialTab;

    // ป้องกันกรณีส่งค่าแท็บที่ไม่มีอยู่
    if (_currentIndex < 0 || _currentIndex > 3) {
      _currentIndex = 0;
    }

    // รายการหน้าหลักของ Buyer
    _pages = [
      // 0 = หน้าแรก
      BuyerHomePage(userId: widget.userId),

      // 1 = ตามหาสินค้า
      WantedFeedPage(userId: widget.userId),

      // 2 = คำสั่งซื้อ
      BuyerOrderPage(userId: widget.userId),

      // 3 = โปรไฟล์
      ProfilePage(userId: widget.userId),
    ];
  }

  // =========================================================
  // เปลี่ยนหน้า
  // =========================================================

  void _changePage(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        colorScheme: Theme.of(context).colorScheme.copyWith(
          primary: AppColors.primary,
          secondary: AppColors.accent,
        ),
        scaffoldBackgroundColor: AppColors.background,
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.primaryDark,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
          ),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: AppColors.primaryDark,
          foregroundColor: Colors.white,
        ),
      ),
      child: Scaffold(
        backgroundColor: AppColors.background,

        // =====================================================
        // เนื้อหาของแต่ละหน้า
        // =====================================================
        body: IndexedStack(index: _currentIndex, children: _pages),

        // =====================================================
        // Bottom Navigation Bar
        // =====================================================
        bottomNavigationBar: SafeArea(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,

              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),

            child: BottomNavigationBar(
              currentIndex: _currentIndex,

              onTap: _changePage,

              type: BottomNavigationBarType.fixed,

              backgroundColor: Colors.white,

              elevation: 0,

              selectedItemColor: AppColors.primary,

              unselectedItemColor: const Color(0xFF9AA4B2),

              selectedFontSize: 11,

              unselectedFontSize: 10,

              selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),

              unselectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.normal,
              ),

              items: const [
                // =================================================
                // หน้าแรก
                // =================================================
                BottomNavigationBarItem(
                  icon: Icon(Icons.home_outlined),

                  activeIcon: Icon(Icons.home),

                  label: 'หน้าแรก',
                ),

                // =================================================
                // ตามหาสินค้า
                // =================================================
                BottomNavigationBarItem(
                  icon: Icon(Icons.find_in_page_outlined),

                  activeIcon: Icon(Icons.find_in_page),

                  label: 'ตามหาสินค้า',
                ),

                // =================================================
                // คำสั่งซื้อ
                // =================================================
                BottomNavigationBarItem(
                  icon: Icon(Icons.inventory_2_outlined),

                  activeIcon: Icon(Icons.inventory_2),

                  label: 'คำสั่งซื้อ',
                ),

                // =================================================
                // โปรไฟล์
                // =================================================
                BottomNavigationBarItem(
                  icon: Icon(Icons.person_outline),

                  activeIcon: Icon(Icons.person),

                  label: 'โปรไฟล์',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
