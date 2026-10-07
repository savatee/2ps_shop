import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/utils/image_utils.dart';
import 'admin_api_service.dart';

class AdminProductsScreen extends StatefulWidget {
  final String initialStatus;

  const AdminProductsScreen({super.key, this.initialStatus = 'all'});

  @override
  State<AdminProductsScreen> createState() => _AdminProductsScreenState();
}

class _AdminProductsScreenState extends State<AdminProductsScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  bool _isLoading = true;
  List<dynamic> _products = [];
  List<dynamic> _categories = [];

  String _selectedStatus = 'all';
  final Set<int> _selectedCategoryIds = {};

  // Theme Design Tokens
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

  /// หน้าที่: เตรียมสถานะเริ่มต้นของหน้าจอและเริ่มโหลดข้อมูลที่จำเป็น (คลาส _AdminProductsScreenState).
  @override
  void initState() {
    super.initState();
    _selectedStatus = widget.initialStatus.isNotEmpty
        ? widget.initialStatus
        : 'all';
    _fetchProducts();
  }

  /// หน้าที่: คืนทรัพยากรของหน้าจอ เช่น controller และ listener ก่อนปิดหน้า (คลาส _AdminProductsScreenState).
  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  /// หน้าที่: โหลดข้อมูล fetch สินค้า และอัปเดตสถานะการแสดงผลของหน้าจอ (คลาส _AdminProductsScreenState).
  Future<void> _fetchProducts() async {
    setState(() => _isLoading = true);
    try {
      final res = await AdminApiService.getProducts(
        status: _selectedStatus,
        categoryIds: _selectedCategoryIds.toList(),
        search: _searchController.text,
      );

      if (mounted) {
        setState(() {
          _products = (res['products'] as List?) ?? [];
          final catList = (res['categories'] as List?) ?? [];
          if (_categories.isEmpty && catList.isNotEmpty) {
            _categories = catList;
          }
          _isLoading = false;
        });
      }
    } catch (e, stack) {
      debugPrint(">>> Error fetching products: $e");
      debugPrint(">>> StackTrace: $stack");
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// หน้าที่: จัดการเหตุการณ์ on การค้นหา ที่เปลี่ยน จากการกดหรือกรอกข้อมูลของผู้ใช้ (คลาส _AdminProductsScreenState).
  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _fetchProducts();
    });
  }

  /// หน้าที่: จัดการเหตุการณ์ handle Action จากการกดหรือกรอกข้อมูลของผู้ใช้ (คลาส _AdminProductsScreenState).
  Future<void> _handleAction(int productId, String action) async {
    final status = (action == 'approve') ? 'active' : 'rejected';
    final success = await AdminApiService.updateProductStatus(
      productId,
      status,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? (action == 'approve'
                      ? 'อนุมัติสินค้าเรียบร้อย'
                      : 'ปฏิเสธสินค้าแล้ว')
                : 'เกิดข้อผิดพลาด กรุณาลองใหม่',
          ),
          backgroundColor: action == 'approve' ? emerald500 : rose500,
          behavior: SnackBarBehavior.floating,
        ),
      );
      if (success) _fetchProducts();
    }
  }

  /// หน้าที่: จัดรูปแบบข้อมูล format จำนวนเงิน ก่อนนำไปแสดงผล (คลาส _AdminProductsScreenState).
  String _formatCurrency(num number) => NumberFormat('#,###').format(number);

  // คืนค่าป้ายสถานะ (ข้อความ, สีพื้นหลัง, สีตัวหนังสือ)
  Map<String, dynamic> _getStatusBadgeInfo(String rawStatus) {
    final status = rawStatus.toLowerCase();
    if (status == 'active') {
      return {
        'label': 'อนุมัติแล้ว',
        'bg': const Color(0xFFDCFCE7),
        'color': const Color(0xFF16A34A),
      };
    } else if (status == 'rejected') {
      return {
        'label': 'ปฏิเสธแล้ว',
        'bg': const Color(0xFFFEE2E2),
        'color': const Color(0xFFDC2626),
      };
    } else if (status == 'inactive' || status == 'closed') {
      return {
        'label': 'ปิดการขาย',
        'bg': const Color(0xFFF1F5F9),
        'color': const Color(0xFF64748B),
      };
    } else {
      return {
        'label': 'รอตรวจ',
        'bg': const Color(0xFFFEF3C7),
        'color': const Color(0xFFB45309),
      };
    }
  }

  // ฟังก์ชันแสดง Modal รายละเอียดสินค้าเต็ม
  void _openProductDetailModal(Map<String, dynamic> item) {
    final status = item['status']?.toString().toLowerCase() ?? 'pending';
    final isPending = status == 'pending';
    final isActive = status == 'active';
    final isRejected = status == 'rejected';

    final num price = num.tryParse(item['price']?.toString() ?? '0') ?? 0;
    final int stock = int.tryParse(item['stock']?.toString() ?? '0') ?? 0;
    final int productId =
        int.tryParse(item['product_id']?.toString() ?? '0') ?? 0;
    final String? imageUrl = buildImageUrl(item['product_image']?.toString());

    final badgeInfo = _getStatusBadgeInfo(status);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: slate400.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 4,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'รายละเอียดสินค้า',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: slate900,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: slate500),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    // รูปภาพสินค้าขนาดใหญ่
                    if (imageUrl != null) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          height: 200,
                          width: double.infinity,
                          color: slate100,
                          child: Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => const Center(
                              child: Icon(
                                Icons.image_not_supported_outlined,
                                color: slate400,
                                size: 40,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // ส่วนหัว: ชื่อสินค้า + สถานะ
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            item['product_name']?.toString() ?? '',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: slate900,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: badgeInfo['bg'],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            badgeInfo['label'],
                            style: TextStyle(
                              color: badgeInfo['color'],
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // ราคาและสต็อก
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: slate100,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Column(
                            children: [
                              const Text(
                                'ราคาจำหน่าย',
                                style: TextStyle(fontSize: 12, color: slate500),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '฿${_formatCurrency(price)}',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: navy900,
                                ),
                              ),
                            ],
                          ),
                          Container(width: 1, height: 35, color: border),
                          Column(
                            children: [
                              const Text(
                                'คงเหลือในคลัง',
                                style: TextStyle(fontSize: 12, color: slate500),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '$stock ชิ้น',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: navy900,
                                ),
                              ),
                            ],
                          ),
                          Container(width: 1, height: 35, color: border),
                          Column(
                            children: [
                              const Text(
                                'หมวดหมู่',
                                style: TextStyle(fontSize: 12, color: slate500),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                item['category_name'] ?? 'ทั่วไป',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: slate900,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    // ข้อมูลร้านค้า
                    const Text(
                      'ข้อมูลผู้ขาย',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: slate900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        border: Border.all(color: border),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const CircleAvatar(
                            radius: 20,
                            backgroundColor: slate100,
                            child: Icon(
                              Icons.person_outline_rounded,
                              color: slate600,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item['seller_name'] ?? 'ไม่ระบุชื่อ',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: slate900,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'ติดต่อ: ${item['seller_contact'] ?? '-'}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: slate500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    // คำอธิบาย
                    const Text(
                      'รายละเอียดสินค้า (Description)',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: slate900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: canvas,
                        border: Border.all(color: border),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        (item['product_description'] != null &&
                                item['product_description']
                                    .toString()
                                    .trim()
                                    .isNotEmpty)
                            ? item['product_description'].toString()
                            : 'ไม่มีรายละเอียดระบุไว้',
                        style: const TextStyle(
                          fontSize: 13.5,
                          color: slate600,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // ปุ่มกดอนุมัติ/ปฏิเสธ (จะแสดงเฉพาะสินค้าที่ยังรอตรวจ หรือสินค้าที่ยังต้องจัดการ)
              if (isPending || isActive || isRejected)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(top: BorderSide(color: border)),
                  ),
                  child: Row(
                    children: [
                      if (isPending || isActive)
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              Navigator.pop(ctx);
                              _handleAction(productId, 'reject');
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: rose500,
                              side: BorderSide(
                                color: rose500.withValues(alpha: 0.4),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text(
                              'ปฏิเสธสินค้า',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                      if (isPending) const SizedBox(width: 12),
                      if (isPending || isRejected)
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.pop(ctx);
                              _handleAction(productId, 'approve');
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: emerald500,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text(
                              'อนุมัติสินค้า',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  /// หน้าที่: เปิดหรือแสดงหน้าต่าง/ส่วน UI สำหรับ open หมวดหมู่สินค้า Filter Sheet (คลาส _AdminProductsScreenState).
  void _openCategoryFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.65,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: slate400.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'เลือกหมวดหมู่ที่ต้องการดู',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: slate900,
                          ),
                        ),
                        if (_selectedCategoryIds.isNotEmpty)
                          TextButton(
                            onPressed: () {
                              setSheetState(() => _selectedCategoryIds.clear());
                              setState(() {});
                            },
                            child: const Text(
                              'ล้างทั้งหมด',
                              style: TextStyle(color: rose500, fontSize: 13),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      itemCount: _categories.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, idx) {
                        final cat = _categories[idx];
                        final int id = cat['id'];
                        final isChecked = _selectedCategoryIds.contains(id);

                        return CheckboxListTile(
                          title: Text(
                            cat['name'],
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: isChecked
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: isChecked ? navy900 : slate600,
                            ),
                          ),
                          value: isChecked,
                          activeColor: navy900,
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.trailing,
                          onChanged: (bool? val) {
                            setSheetState(() {
                              if (val == true) {
                                _selectedCategoryIds.add(id);
                              } else {
                                _selectedCategoryIds.remove(id);
                              }
                            });
                            setState(() {});
                          },
                        );
                      },
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      border: Border(top: BorderSide(color: border)),
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _fetchProducts();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: navy900,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'กรองสินค้า (${_selectedCategoryIds.isEmpty ? 'ทุกหมวด' : '${_selectedCategoryIds.length} หมวด'})',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// หน้าที่: สร้าง UI ของหน้าจอหรือวิดเจ็ตใน admin products screen (คลาส _AdminProductsScreenState).
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: canvas,
      body: Column(
        children: [
          _buildAppHeader(),
          _buildControlBar(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _fetchProducts,
              color: navy900,
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _products.isEmpty
                  ? _buildEmptyState()
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
                      itemCount: _products.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final rawItem = _products[index];
                        final item = (rawItem is Map)
                            ? Map<String, dynamic>.from(rawItem)
                            : <String, dynamic>{};
                        return _buildProductCard(item);
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  /// หน้าที่: สร้าง UI ส่วน App Header เพื่อใช้ในหน้าจอนี้ (คลาส _AdminProductsScreenState).
  Widget _buildAppHeader() {
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
          padding: const EdgeInsets.fromLTRB(12, 6, 16, 18),
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(
                      Icons.arrow_back_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'คลังสินค้าทั้งหมด',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          'ตรวจสอบ ตรวจประวัติ และจัดการสินค้าของร้านค้า',
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
              const SizedBox(height: 10),
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
                    hintText: 'ค้นหาชื่อสินค้า หรือชื่อร้านผู้ขาย...',
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
                              _fetchProducts();
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

  /// หน้าที่: สร้าง UI ส่วน Control Bar เพื่อใช้ในหน้าจอนี้ (คลาส _AdminProductsScreenState).
  Widget _buildControlBar() {
    // แยก 5 สถานะชัดเจน: ทั้งหมด, รอตรวจ, อนุมัติแล้ว, ปฏิเสธ, ปิดการขาย
    final statusList = [
      {'key': 'all', 'label': 'ทั้งหมด'},
      {'key': 'pending', 'label': 'รอตรวจ'},
      {'key': 'active', 'label': 'อนุมัติแล้ว'},
      {'key': 'rejected', 'label': 'ปฏิเสธ'},
      {'key': 'inactive', 'label': 'ปิดการขาย'},
    ];

    final selectedCategories = _categories
        .where((c) => _selectedCategoryIds.contains(c['id']))
        .toList();

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // แถบแท็บสถานะแบบเลื่อนแนวนอน (รองรับ 5 แท็บไม่เบียดกัน)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: statusList.map((st) {
                final isSel = _selectedStatus == st['key'];
                return GestureDetector(
                  onTap: () {
                    setState(() => _selectedStatus = st['key']!);
                    _fetchProducts();
                  },
                  child: Container(
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isSel ? navy900 : slate100,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      st['label']!,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                        color: isSel ? Colors.white : slate600,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 10),

          // แถวแสดงจำนวนผลลัพธ์ และปุ่มตัวกรองหมวดหมู่
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'พบ ${_products.length} รายการ',
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: slate500,
                ),
              ),
              InkWell(
                onTap: _openCategoryFilterSheet,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _selectedCategoryIds.isEmpty
                        ? slate100
                        : const Color(0xFFEEF2FF),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _selectedCategoryIds.isEmpty
                          ? border
                          : const Color(0xFFC7D2FE),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.filter_list_rounded,
                        size: 15,
                        color: _selectedCategoryIds.isEmpty
                            ? slate600
                            : const Color(0xFF4338CA),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        _selectedCategoryIds.isEmpty
                            ? 'เลือกหมวดหมู่'
                            : 'หมวดหมู่ (${_selectedCategoryIds.length})',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _selectedCategoryIds.isEmpty
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
          if (selectedCategories.isNotEmpty) ...[
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ...selectedCategories.map((cat) {
                    final int catId = cat['id'];
                    final String catName = cat['name'] ?? '';
                    return Container(
                      margin: const EdgeInsets.only(right: 6),
                      padding: const EdgeInsets.fromLTRB(10, 4, 6, 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEEF2FF),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFC7D2FE)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            catName,
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF4338CA),
                            ),
                          ),
                          const SizedBox(width: 4),
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedCategoryIds.remove(catId);
                              });
                              _fetchProducts();
                            },
                            child: const Icon(
                              Icons.close_rounded,
                              size: 14,
                              color: Color(0xFF4338CA),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedCategoryIds.clear();
                      });
                      _fetchProducts();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      child: const Text(
                        'ล้างทั้งหมด',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: rose500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// หน้าที่: สร้าง UI ส่วน Product Card เพื่อใช้ในหน้าจอนี้ (คลาส _AdminProductsScreenState).
  Widget _buildProductCard(Map<String, dynamic> item) {
    final status = item['status']?.toString().toLowerCase() ?? 'pending';
    final isPending = status == 'pending';

    final num price = num.tryParse(item['price']?.toString() ?? '0') ?? 0;
    final int stock = int.tryParse(item['stock']?.toString() ?? '0') ?? 0;
    final int productId =
        int.tryParse(item['product_id']?.toString() ?? '0') ?? 0;

    final String? imageUrl = buildImageUrl(item['product_image']?.toString());
    final badgeInfo = _getStatusBadgeInfo(status);

    return InkWell(
      onTap: () => _openProductDetailModal(item),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: border),
          boxShadow: [
            BoxShadow(
              color: navy900.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // กล่องรูปสินค้า
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: slate100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: imageUrl != null
                          ? Image.network(
                              imageUrl,
                              width: 50,
                              height: 50,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => const Icon(
                                Icons.storefront_outlined,
                                color: slate600,
                                size: 24,
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
                          : const Icon(
                              Icons.storefront_outlined,
                              color: slate600,
                              size: 24,
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                item['product_name']?.toString() ?? '',
                                style: const TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w700,
                                  color: slate900,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: badgeInfo['bg'],
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                badgeInfo['label'],
                                style: TextStyle(
                                  color: badgeInfo['color'],
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'หมวดหมู่: ${item['category_name'] ?? 'ทั่วไป'}',
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: slate500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'ผู้ขาย: ${item['seller_name'] ?? '-'} (${item['seller_contact'] ?? '-'})',
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: slate600,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Divider(height: 1),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  RichText(
                    text: TextSpan(
                      text: '฿${_formatCurrency(price)} ',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: slate900,
                      ),
                      children: [
                        TextSpan(
                          text: '· สต็อก $stock ชิ้น',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.normal,
                            color: slate500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    item['time_ago']?.toString() ?? '',
                    style: const TextStyle(fontSize: 11, color: slate400),
                  ),
                ],
              ),
              if (isPending) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _handleAction(productId, 'reject'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: rose500,
                          side: BorderSide(
                            color: rose500.withValues(alpha: 0.4),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          'ปฏิเสธ',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _handleAction(productId, 'approve'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: emerald500,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          'อนุมัติ',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// หน้าที่: สร้าง UI ส่วน Empty State เพื่อใช้ในหน้าจอนี้ (คลาส _AdminProductsScreenState).
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: slate100,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.inventory_2_outlined,
              size: 40,
              color: slate400,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'ไม่พบรายการสินค้า',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: slate900,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'ลองปรับตัวกรองสถานะหรือหมวดหมู่ใหม่',
            style: TextStyle(fontSize: 12, color: slate500),
          ),
        ],
      ),
    );
  }
}
