import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/image_utils.dart';
import '../../core/widgets/app_bar_cart_button.dart';
import '../../core/widgets/loading_view.dart';
import '../../core/widgets/section_header.dart';
import '../../core/widgets/product_card.dart';
import '../../core/network/api_client.dart';
import 'buyer_cart_page.dart';
import 'buyer_main_page.dart';
import 'buyer_product_detail_page.dart';
import '../chat/chat_room_page.dart';

class BuyerStorePage extends StatefulWidget {
  final int sellerId;
  final int userId;
  final String? sellerName;

  const BuyerStorePage({
    super.key,
    required this.sellerId,
    required this.userId,
    this.sellerName,
  });

  @override
  State<BuyerStorePage> createState() => _BuyerStorePageState();
}

class _BuyerStorePageState extends State<BuyerStorePage> {
  final TextEditingController _searchController = TextEditingController();
  Map<String, dynamic> _seller = {};
  List<Map<String, dynamic>> _products = [];
  bool _isLoading = true;
  String? _error;
  String _searchQuery = '';
  int _selectedTab = 0;
  int _cartCount = 0;
  int? _selectedCategoryId;

  String get _storeName {
    final candidates = [
      _seller['name'],
      widget.sellerName,
      _products.firstOrNull?['seller_name'],
    ];
    for (final candidate in candidates) {
      final name = candidate?.toString().trim() ?? '';
      if (name.isNotEmpty) return name;
    }
    return 'ร้านค้า';
  }

  @override
  void initState() {
    super.initState();
    _loadStore();
    _loadCartCount();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadStore() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final results = await Future.wait<dynamic>([
        ApiClient.getUser(
          widget.sellerId,
        ).then<dynamic>((result) => result, onError: (Object _) => null),
        ApiClient.getProducts(sellerId: widget.sellerId).then<dynamic>(
          (products) => products,
          onError: (Object _) => null,
        ),
      ]);
      final profileResult = results[0] is Map
          ? Map<String, dynamic>.from(results[0] as Map)
          : null;
      final productResult = results[1] is List ? results[1] as List : null;
      final allProducts = (productResult ?? const <dynamic>[])
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .where(
            (item) =>
                int.tryParse(item['product_seller_id']?.toString() ?? '') ==
                widget.sellerId,
          )
          .toList();
      if (!mounted) return;

      setState(() {
        _seller = profileResult != null && profileResult['data'] is Map
            ? Map<String, dynamic>.from(profileResult['data'] as Map)
            : {};
        _products = allProducts;
        if (productResult == null) {
          _error = 'ไม่สามารถโหลดรายการสินค้าได้ กรุณาลองอีกครั้ง';
        } else if (profileResult?['success'] != true && allProducts.isEmpty) {
          _error =
              profileResult?['message']?.toString() ??
              'ไม่สามารถโหลดข้อมูลร้านค้าได้';
        }
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'เชื่อมต่อข้อมูลร้านค้าไม่ได้ กรุณาลองอีกครั้ง';
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _filteredProducts {
    final query = _searchQuery.trim().toLowerCase();
    var products = _products.where((product) {
      final name = product['product_name']?.toString().toLowerCase() ?? '';
      final categoryId = int.tryParse(product['category_id']?.toString() ?? '');

      return (query.isEmpty || name.contains(query)) &&
          (_selectedCategoryId == null || categoryId == _selectedCategoryId);
    }).toList();

    if (_selectedTab == 0 && _selectedCategoryId == null && query.isEmpty) {
      products = products.take(6).toList();
    }
    return products;
  }

  List<Map<String, dynamic>> get _categories {
    final categories = <int, String>{};
    for (final product in _products) {
      final id = int.tryParse(product['category_id']?.toString() ?? '');
      final name = product['category_name']?.toString().trim() ?? '';
      if (id != null && name.isNotEmpty) categories[id] = name;
    }
    return categories.entries
        .map(
          (entry) => {'category_id': entry.key, 'category_name': entry.value},
        )
        .toList();
  }

  void _showFollowUnavailable() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('ระบบติดตามร้านค้ายังไม่เชื่อมกับฐานข้อมูล'),
      ),
    );
  }

  void _openChat() {
    if (widget.userId == widget.sellerId) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('นี่คือร้านค้าของคุณเอง')));
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatRoomPage(
          postId: 0,
          buyerId: widget.userId,
          sellerId: widget.sellerId,
          sellerName: _storeName,
        ),
      ),
    );
  }

  Future<void> _openCategories() async {
    if (_categories.isEmpty) return;
    final selected = await showModalBottomSheet<int?>(
      context: context,
      backgroundColor: Colors.white,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              title: const Text('ทุกหมวดหมู่'),
              trailing: _selectedCategoryId == null
                  ? const Icon(Icons.check, color: AppColors.primary)
                  : null,
              onTap: () => Navigator.pop(context, -1),
            ),
            for (final category in _categories)
              ListTile(
                title: Text(category['category_name'] as String),
                trailing: _selectedCategoryId == category['category_id']
                    ? const Icon(Icons.check, color: AppColors.primary)
                    : null,
                onTap: () =>
                    Navigator.pop(context, category['category_id'] as int),
              ),
          ],
        ),
      ),
    );

    if (!mounted || selected == null) return;
    setState(() {
      _selectedCategoryId = selected == -1 ? null : selected;
      _selectedTab = 1;
    });
  }

  void _openProduct(Map<String, dynamic> product) {
    final productId = int.tryParse(product['product_id']?.toString() ?? '');
    if (productId == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            BuyerProductDetailPage(productId: productId, userId: widget.userId),
      ),
    );
  }

  Future<void> _loadCartCount() async {
    final cart = await ApiClient.getCart(widget.userId);
    if (!mounted) return;
    setState(() => _cartCount = cart.length);
  }

  Future<void> _openCart() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => BuyerCartPage(userId: widget.userId)),
    );
    await _loadCartCount();
  }

  void _openMainTab(int index) {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => BuyerMainPage(userId: widget.userId, initialTab: index),
      ),
      (route) => false,
    );
  }

  Widget _buildSearchBar() {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          const Icon(Icons.search, size: 19, color: Color(0xFF8A93A3)),
          const SizedBox(width: 7),
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _searchQuery = value),
              style: const TextStyle(fontSize: 12),
              decoration: const InputDecoration(
                hintText: 'ค้นหาในร้านค้า',
                hintStyle: TextStyle(fontSize: 12, color: Color(0xFF8A93A3)),
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStoreHeader() {
    final profileImage = _seller['profile_image_url']?.toString() ?? '';
    final createdAt = DateTime.tryParse(
      _seller['user_created_at']?.toString() ?? '',
    );
    final memberSince = createdAt == null
        ? 'ร้านค้าบน 2PS Shop'
        : 'สมาชิกตั้งแต่ ${createdAt.year}';

    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
      child: Column(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: const BoxDecoration(
              color: Color(0xFF15213B),
              shape: BoxShape.circle,
            ),
            clipBehavior: Clip.antiAlias,
            child: profileImage.isEmpty
                ? Center(
                    child: Text(
                      _storeName.trim().isEmpty
                          ? 'S'
                          : _storeName.trim()[0].toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                  )
                : Image.network(
                    profileImage,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Center(
                      child: Text(
                        _storeName.trim().isEmpty
                            ? 'S'
                            : _storeName.trim()[0].toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),
                    ),
                  ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  _storeName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
              const SizedBox(width: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'ร้านค้า',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            memberSince,
            style: const TextStyle(fontSize: 11, color: Color(0xFF858D9A)),
          ),
          const SizedBox(height: 3),
          Text(
            'สินค้า ${_products.length} รายการ',
            style: const TextStyle(fontSize: 11, color: Color(0xFF596170)),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 38,
                  child: ElevatedButton.icon(
                    onPressed: _showFollowUnavailable,
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('ติดตาม'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(7),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SizedBox(
                  height: 38,
                  child: OutlinedButton.icon(
                    onPressed: _openChat,
                    icon: const Icon(Icons.chat_bubble_outline, size: 15),
                    label: const Text('แชทเลย'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF26344D),
                      side: const BorderSide(color: Color(0xFF26344D)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(7),
                      ),
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

  Widget _buildStoreTabs() {
    final tabs = ['แนะนำ', 'สินค้าทั้งหมด (${_products.length})'];
    return Container(
      height: 44,
      color: Colors.white,
      child: Row(
        children: [
          for (var index = 0; index < tabs.length; index++)
            Expanded(
              child: InkWell(
                onTap: () => setState(() => _selectedTab = index),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Center(
                        child: Text(
                          tabs[index],
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: _selectedTab == index
                                ? AppColors.primaryDark
                                : const Color(0xFF596170),
                            fontWeight: _selectedTab == index
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                    ),
                    Container(
                      height: 2,
                      color: _selectedTab == index
                          ? AppColors.primary
                          : Colors.transparent,
                    ),
                  ],
                ),
              ),
            ),
          IconButton(
            tooltip: 'เลือกหมวดหมู่',
            onPressed: _openCategories,
            icon: Icon(
              Icons.tune,
              color: _selectedCategoryId == null
                  ? const Color(0xFF596170)
                  : AppColors.primary,
              size: 19,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProducts() {
    final products = _filteredProducts;
    final sectionTitle = _selectedCategoryId != null
        ? _selectedCategoryTitle
        : switch (_selectedTab) {
            0 => 'สินค้าแนะนำสำหรับคุณ',
            _ => 'สินค้าทั้งหมด',
          };

    if (products.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 20),
        child: Center(
          child: Column(
            children: [
              const Icon(
                Icons.inventory_2_outlined,
                size: 42,
                color: Color(0xFFABB3C0),
              ),
              const SizedBox(height: 9),
              Text(
                _searchQuery.isNotEmpty
                    ? 'ไม่พบสินค้าที่ค้นหา'
                    : 'ยังไม่มีสินค้าในหมวดนี้',
                style: const TextStyle(color: Color(0xFF737D8D)),
              ),
            ],
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        // ใช้ค่าเดียวกับหน้าหลัก (buyer_home_page.dart)
        final hPad = width >= 1100
            ? 28.0
            : width >= 800
            ? 22.0
            : width >= 600
            ? 18.0
            : 16.0;
        final columns = width >= 1100
            ? 5
            : width >= 800
            ? 4
            : width >= 600
            ? 3
            : 2;
        const crossAxisSpacing = 9.0;
        final availableWidth = width - hPad * 2;
        final itemWidth =
            (availableWidth - crossAxisSpacing * (columns - 1)) / columns;
        final textScale = MediaQuery.textScalerOf(context).scale(1);
        final itemHeight = itemWidth + 64 * textScale;

        return Padding(
          padding: EdgeInsets.fromLTRB(hPad, 14, hPad, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionHeader(title: sectionTitle, icon: Icons.grid_view_rounded),
              const SizedBox(height: 8),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                itemCount: products.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  crossAxisSpacing: crossAxisSpacing,
                  mainAxisSpacing: 9,
                  childAspectRatio: itemWidth / itemHeight,
                ),
                itemBuilder: (context, index) {
                  final product = products[index];
                  return ProductCard(
                    name:
                        product['product_name']?.toString() ??
                        'ไม่มีชื่อสินค้า',
                    price:
                        double.tryParse(
                          product['product_price']?.toString() ?? '0',
                        ) ??
                        0,
                    stock:
                        int.tryParse(product['stock']?.toString() ?? '0') ?? 0,
                    // จำนวนที่ขายแล้วมาจากฐานข้อมูลจริง (sold_count ใน products.php)
                    soldCount:
                        int.tryParse(
                          product['sold_count']?.toString() ?? '0',
                        ) ??
                        0,
                    imageUrl: pickProductImage(product),
                    onTap: () => _openProduct(product),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  String get _selectedCategoryTitle {
    final selectedId = _selectedCategoryId;
    for (final category in _categories) {
      if (category['category_id'] == selectedId) {
        return category['category_name']?.toString() ?? 'สินค้าในหมวดหมู่';
      }
    }
    return 'สินค้าในหมวดหมู่';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primaryDark,
        foregroundColor: Colors.white,
        leading: IconButton(
          tooltip: 'ย้อนกลับ',
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_new, size: 19),
        ),
        title: _buildSearchBar(),
        actions: [
          IconButton(
            tooltip: 'แชร์ร้านค้า',
            onPressed: () => SharePlus.instance.share(
              ShareParams(text: 'ดูร้าน $_storeName บน 2PS Shop'),
            ),
            icon: const Icon(Icons.share_outlined, size: 20),
          ),
          AppBarCartButton(count: _cartCount, onPressed: _openCart),
          const SizedBox(width: 4),
        ],
      ),
      body: _isLoading
          ? const LoadingView()
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: _loadStore,
                      icon: const Icon(Icons.refresh),
                      label: const Text('ลองอีกครั้ง'),
                    ),
                  ],
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadStore,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(child: _buildStoreHeader()),
                  SliverToBoxAdapter(child: _buildStoreTabs()),
                  SliverToBoxAdapter(child: _buildProducts()),
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(12, 6, 12, 24),
                      child: Center(
                        child: Text(
                          '2PS SHOP · BUY SELL TOGETHER',
                          style: TextStyle(
                            fontSize: 9,
                            color: Color(0xFF9AA4B2),
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
      bottomNavigationBar: SafeArea(
        child: BottomNavigationBar(
          currentIndex: 0,
          onTap: _openMainTab,
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: AppColors.primary,
          unselectedItemColor: const Color(0xFF9AA4B2),
          selectedFontSize: 10,
          unselectedFontSize: 10,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              label: 'หน้าแรก',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.search),
              label: 'ตามหาสินค้า',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.inventory_2_outlined),
              label: 'คำสั่งซื้อ',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              label: 'โปรไฟล์',
            ),
          ],
        ),
      ),
    );
  }
}
