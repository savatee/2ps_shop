import 'package:flutter/material.dart';
import 'login_screen.dart';

class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  String? _selectedRole;

  static const Color primaryBlue = Color(0xFF0F3B82);
  static const Color navyDark = Color(0xFF0C2340);
  static const Color slate600 = Color(0xFF5A6E85);
  static const Color canvasBg = Color(0xFFF9FBFC);

  final List<Map<String, dynamic>> _roles = [
    {
      'code': 'buyer',
      'title': 'ผู้ซื้อสินค้า',
      'desc': 'สำหรับลูกค้าที่ต้องการเลือกซื้อสินค้า\nและสั่งซื้อจากร้านค้า',
      'icon': Icons.shopping_cart_outlined,
      'cardBg': const Color(0xFFF1F7FD),
      'borderColor': const Color(0xFFDCEAF8),
      'iconBoxBg': const Color(0xFFE1EFFB),
      'iconColor': const Color(0xFF1D5C96),
      'btnColor': const Color(0xFF3886E7),
    },
    {
      'code': 'seller',
      'title': 'ผู้ขายสินค้า',
      'desc': 'สำหรับร้านค้าที่ต้องการจัดการร้าน\nและสินค้า',
      'icon': Icons.storefront_rounded,
      'cardBg': const Color(0xFFFFF8F0),
      'borderColor': const Color(0xFFFCECDA),
      'iconBoxBg': const Color(0xFFFDECD8),
      'iconColor': const Color(0xFFD47A1E),
      'btnColor': const Color(0xFFF59E2B),
    },
    {
      'code': 'admin',
      'title': 'ผู้ดูแลระบบ',
      'desc': 'สำหรับผู้ดูแลระบบและจัดการ\nความเรียบร้อย',
      'icon': Icons.verified_user_outlined,
      'cardBg': const Color(0xFFF0FAF5),
      'borderColor': const Color(0xFFDDF3E7),
      'iconBoxBg': const Color(0xFFDDF1E6),
      'iconColor': const Color(0xFF1C8C5E),
      'btnColor': const Color(0xFF28A774),
    },
  ];

  /// หน้าที่: สร้าง UI ส่วน Role Card เพื่อใช้ในหน้าจอนี้ (คลาส _RoleSelectionScreenState).
  Widget _buildRoleCard(Map<String, dynamic> role) {
    final String code = role['code'];
    final String title = role['title'];
    final String desc = role['desc'];
    final IconData icon = role['icon'];
    final Color cardBg = role['cardBg'];
    final Color borderColor = role['borderColor'];
    final Color iconBoxBg = role['iconBoxBg'];
    final Color iconColor = role['iconColor'];
    final Color btnColor = role['btnColor'];

    final bool isSelected = _selectedRole == code;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: MouseRegion(
        onEnter: (_) => setState(() => _selectedRole = code),
        onExit: (_) => setState(() => _selectedRole = null),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(24),
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onHighlightChanged: (pressed) {
              setState(() => _selectedRole = pressed ? code : null);
            },
            onTap: () {
              setState(() => _selectedRole = code);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      LoginScreen(roleCode: code, roleTitle: title),
                ),
              ).then((_) {
                if (mounted) setState(() => _selectedRole = null);
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isSelected ? primaryBlue : borderColor,
                  width: isSelected ? 2.0 : 1.2,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: primaryBlue.withValues(alpha: 0.08),
                          blurRadius: 14,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : [],
              ),
              child: Row(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: iconBoxBg,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(icon, size: 36, color: iconColor),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            color: navyDark,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          desc,
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: slate600,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: btnColor,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: btnColor.withValues(alpha: 0.35),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.arrow_forward_rounded,
                      size: 20,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// หน้าที่: สร้าง UI ของหน้าจอหรือวิดเจ็ตใน role selection screen (คลาส _RoleSelectionScreenState).
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: canvasBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: navyDark,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.shopping_bag_outlined,
                          size: 22,
                          color: Colors.white,
                        ),
                        const SizedBox(height: 1),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 0.5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: const Text(
                            '2PS',
                            style: TextStyle(
                              fontSize: 7.5,
                              fontWeight: FontWeight.w900,
                              color: navyDark,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '2PS SHOP',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: navyDark,
                          letterSpacing: 0.5,
                        ),
                      ),
                      SizedBox(height: 1),
                      Text(
                        'ซื้อขายง่าย ได้ของชัวร์',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: slate600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 32),
              const Text(
                'เข้าสู่ระบบด้วยบทบาทของคุณ',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: navyDark,
                  letterSpacing: -0.6,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'เลือกประเภทบัญชีเพื่อเข้าสู่หน้าจอ\nการทำงานที่เหมาะสม',
                style: TextStyle(fontSize: 14, color: slate600, height: 1.35),
              ),
              const SizedBox(height: 14),
              Container(
                width: 42,
                height: 4.5,
                decoration: BoxDecoration(
                  color: const Color(0xFF2C7BE5),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(height: 28),
              ..._roles.map((r) => _buildRoleCard(r)),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
