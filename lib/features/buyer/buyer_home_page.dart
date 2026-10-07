import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/image_utils.dart';
import '../../core/utils/product_image_cache.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/loading_view.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../core/widgets/popular_product_card.dart';
import '../../core/widgets/product_card.dart';
import '../../core/widgets/section_header.dart';
import '../../core/network/api_client.dart';
import 'buyer_cart_page.dart';
import 'buyer_product_detail_page.dart';
import '../chat/chat_list_page.dart';

class BuyerHomePage extends StatefulWidget {
  final int userId;

  const BuyerHomePage({super.key, required this.userId});

  @override
  State<BuyerHomePage> createState() => _BuyerHomePageState();
}

class _BuyerHomePageState extends State<BuyerHomePage> {
  List<dynamic> _categories = [];
  List<dynamic> _products = [];
  List<dynamic> _popular = [];

  // แบ่งหน้าสินค้า: โหลดทีละ _pageSize แล้วโหลดเพิ่มเมื่อเลื่อนใกล้ท้ายรายการ
  static const int _pageSize = 20;
  int _nextOffset = 0;
  bool _hasMore = false;
  bool _isLoadingMore = false;
  int _loadGeneration = 0; // กันผลลัพธ์เก่าทับเมื่อเปลี่ยนหมวด/รีเฟรชระหว่างโหลด

  int _cartCount = 0;

  bool _isLoading = true;
  bool _isSearching = false;
  String _searchKeyword = '';
  int? _selectedCategoryId;
  String? _selectedCategoryName;

  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  final _searchHistoryLayerLink = LayerLink();
  final _searchFieldKey = GlobalKey();
  final _speech = SpeechToText();
  final _imagePicker = ImagePicker();
  List<String> _searchHistory = [];
  OverlayEntry? _searchHistoryOverlay;
  bool _speechInitialized = false;
  bool _isListening = false;

  String get _searchHistoryKey => 'buyer.search_history.${widget.userId}';

  static const _categoryIconKeywords = <String, IconData>{
    'อาหาร': Icons.restaurant_outlined,
    'เครื่องดื่ม': Icons.local_cafe_outlined,
    'กางเกง': Icons.airline_seat_legroom_normal_outlined,
    'กระเป๋า': Icons.shopping_bag_outlined,
    'รองเท้า': Icons.snowshoeing_outlined,
    'เสื้อ': Icons.checkroom_outlined,
    'แฟชั่น': Icons.checkroom_outlined,
    'ความงาม': Icons.face_retouching_natural_outlined,
    'เครื่องสำอาง': Icons.face_retouching_natural_outlined,
    'อิเล็กทรอนิกส์': Icons.devices_other_outlined,
    'มือถือ': Icons.smartphone_outlined,
    'หนังสือ': Icons.menu_book_outlined,
    'ของเล่น': Icons.toys_outlined,
    'กีฬา': Icons.sports_soccer_outlined,
    'บ้าน': Icons.chair_outlined,
    'เฟอร์นิเจอร์': Icons.chair_outlined,
    'สัตว์เลี้ยง': Icons.pets_outlined,
    'ยานยนต์': Icons.directions_car_filled_outlined,
  };

  IconData _iconForCategory(String name) {
    for (final entry in _categoryIconKeywords.entries) {
      if (name.contains(entry.key)) {
        return entry.value;
      }
    }
    return Icons.local_mall_outlined;
  }

  @override
  void initState() {
    super.initState();
    _searchFocusNode.addListener(_updateSearchHistoryVisibility);
    _loadAll();
    _loadCartCount();
    _loadSearchHistory();
  }

  @override
  void dispose() {
    _searchFocusNode.removeListener(_updateSearchHistoryVisibility);
    _hideSearchHistoryDropdown();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadSearchHistory() async {
    final history = await SharedPreferencesAsync().getStringList(
      _searchHistoryKey,
    );
    if (!mounted) return;
    setState(() => _searchHistory = history ?? []);
    _updateSearchHistoryVisibility();
  }

  void _updateSearchHistoryVisibility() {
    if (!mounted) return;
    final shouldShow =
        _searchFocusNode.hasFocus &&
        _searchController.text.trim().isEmpty &&
        _searchHistory.isNotEmpty;
    if (!shouldShow) {
      _hideSearchHistoryDropdown();
      return;
    }

    if (_searchHistoryOverlay == null) {
      _showSearchHistoryDropdown();
    } else {
      _searchHistoryOverlay!.markNeedsBuild();
    }
  }

  void _showSearchHistoryDropdown() {
    if (_searchHistoryOverlay != null || _searchHistory.isEmpty) return;

    _searchHistoryOverlay = OverlayEntry(
      builder: (overlayContext) {
        final renderObject = _searchFieldKey.currentContext?.findRenderObject();
        final width = renderObject is RenderBox && renderObject.hasSize
            ? renderObject.size.width
            : MediaQuery.sizeOf(overlayContext).width - 32;

        return Positioned.fill(
          child: Stack(
            children: [
              GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () {
                  FocusScope.of(context).unfocus();
                  _hideSearchHistoryDropdown();
                },
                child: const SizedBox.expand(),
              ),
              CompositedTransformFollower(
                link: _searchHistoryLayerLink,
                showWhenUnlinked: false,
                targetAnchor: Alignment.bottomLeft,
                followerAnchor: Alignment.topLeft,
                offset: const Offset(0, 8),
                child: Material(
                  color: Colors.white,
                  elevation: 10,
                  borderRadius: BorderRadius.circular(14),
                  clipBehavior: Clip.antiAlias,
                  child: SizedBox(width: width, child: _buildSearchHistory()),
                ),
              ),
            ],
          ),
        );
      },
    );

    Overlay.of(context, rootOverlay: true).insert(_searchHistoryOverlay!);
  }

  void _hideSearchHistoryDropdown() {
    final overlay = _searchHistoryOverlay;
    if (overlay == null) return;
    overlay.remove();
    overlay.dispose();
    _searchHistoryOverlay = null;
  }

  Future<void> _saveSearchHistory(String keyword) async {
    final value = keyword.trim();
    if (value.isEmpty) return;

    final history = _searchHistory
        .where((item) => item.toLowerCase() != value.toLowerCase())
        .toList();
    history.insert(0, value);
    if (history.length > 10) history.removeRange(10, history.length);

    try {
      await SharedPreferencesAsync().setStringList(_searchHistoryKey, history);
      if (!mounted) return;
      setState(() => _searchHistory = history);
      _updateSearchHistoryVisibility();
    } catch (_) {
      if (mounted) {
        showAppSnackBar(
          context,
          'บันทึกประวัติการค้นหาไม่สำเร็จ',
          isError: true,
        );
      }
    }
  }

  Future<void> _deleteSearchHistory(String keyword) async {
    final history = _searchHistory.where((item) => item != keyword).toList();
    try {
      await SharedPreferencesAsync().setStringList(_searchHistoryKey, history);
      if (!mounted) return;
      setState(() => _searchHistory = history);
      _updateSearchHistoryVisibility();
    } catch (_) {
      if (mounted) {
        showAppSnackBar(context, 'ลบประวัติการค้นหาไม่สำเร็จ', isError: true);
      }
    }
  }

  /// ดึงสินค้า 1 หน้า: ถ้าเลือกหมวดให้กรองจากเซิร์ฟเวอร์
  /// ถ้าไม่ได้เลือกใช้สินค้าแนะนำตามประวัติการซื้อ (ถ้าเรียกไม่สำเร็จ/ไม่มีข้อมูล
  /// จะถอยกลับไปใช้สินค้าใหม่ล่าสุด)
  Future<List<dynamic>> _fetchProductsPage(int offset) async {
    final categoryId = _selectedCategoryId;
    if (categoryId != null) {
      return ApiClient.getProducts(
        limit: _pageSize,
        offset: offset,
        categoryId: categoryId,
        inStock: true,
      );
    }

    try {
      final recommended = await ApiClient.getRecommendedProducts(
        limit: _pageSize,
        offset: offset,
      );
      if (recommended.isNotEmpty || offset > 0) return recommended;
    } catch (_) {
      // ใช้สินค้าใหม่ล่าสุดแทน
    }
    return ApiClient.getProducts(
      limit: _pageSize,
      offset: offset,
      inStock: true,
    );
  }

  void _applyFirstPage(List<dynamic> rawProducts) {
    final products = _dedupeById(rawProducts).where(_isInStock).toList();

    for (final product in products) {
      ProductImageCache.remember(
        int.tryParse(product['product_id'].toString()),
        pickProductImage(product),
      );
    }

    _products = products;
    _nextOffset = rawProducts.length;
    _hasMore = rawProducts.length >= _pageSize;
    _isLoadingMore = false;
  }

  Future<void> _loadAll() async {
    final generation = ++_loadGeneration;

    if (mounted) {
      setState(() => _isLoading = true);
    }

    final categories = await ApiClient.getCategories();
    final rawProducts = await _fetchProductsPage(0);
    final rawPopular = await ApiClient.getPopularProducts(
      limit: 10,
      inStock: true,
    );

    final popular = _dedupeById(rawPopular).where(_isInStock).toList();

    if (!mounted || generation != _loadGeneration) return;

    setState(() {
      _categories = categories;
      _applyFirstPage(rawProducts);
      _popular = popular;
      _isLoading = false;
    });
  }

  /// โหลดสินค้าหน้าแรกใหม่ (ใช้ตอนเปลี่ยนหมวดหมู่) โดยไม่แตะรายการยอดนิยม
  Future<void> _reloadProducts() async {
    final generation = ++_loadGeneration;

    if (mounted) {
      setState(() => _isLoading = true);
    }

    List<dynamic> rawProducts;
    try {
      rawProducts = await _fetchProductsPage(0);
    } catch (_) {
      rawProducts = <dynamic>[];
    }

    if (!mounted || generation != _loadGeneration) return;

    setState(() {
      _applyFirstPage(rawProducts);
      _isLoading = false;
    });
  }

  /// โหลดสินค้าหน้าถัดไปต่อท้ายรายการ
  Future<void> _loadMore() async {
    if (_isLoading || _isLoadingMore || !_hasMore || _isSearching) return;

    final generation = _loadGeneration;
    setState(() => _isLoadingMore = true);

    try {
      final raw = await _fetchProductsPage(_nextOffset);
      if (!mounted || generation != _loadGeneration) return;

      final known = _products.map((p) => p['product_id']?.toString()).toSet();
      final fresh = _dedupeById(raw)
          .where(_isInStock)
          .where((p) => !known.contains(p['product_id']?.toString()))
          .toList();

      for (final product in fresh) {
        ProductImageCache.remember(
          int.tryParse(product['product_id'].toString()),
          pickProductImage(product),
        );
      }

      setState(() {
        _products = [..._products, ...fresh];
        _nextOffset += raw.length;
        _hasMore = raw.length >= _pageSize;
      });
    } catch (_) {
      // โหลดเพิ่มไม่สำเร็จ: ปล่อยให้ผู้ใช้กดปุ่ม "โหลดเพิ่มเติม" ลองใหม่
    } finally {
      if (mounted && generation == _loadGeneration) {
        setState(() => _isLoadingMore = false);
      }
    }
  }

  List<dynamic> _dedupeById(List<dynamic> items) {
    final seen = <int>{};
    final result = <dynamic>[];

    for (final item in items) {
      final id = int.tryParse(item['product_id']?.toString() ?? '');

      if (id == null || seen.add(id)) {
        result.add(item);
      }
    }

    return result;
  }

  bool _isInStock(dynamic product) {
    return (int.tryParse(product['stock']?.toString() ?? '0') ?? 0) > 0;
  }

  List<dynamic> _filterBySelectedCategory(List<dynamic> products) {
    final categoryId = _selectedCategoryId;
    if (categoryId == null) return products;

    return products.where((product) {
      return int.tryParse(product['category_id']?.toString() ?? '') ==
          categoryId;
    }).toList();
  }

  Future<void> _loadCartCount() async {
    final cart = await ApiClient.getCart(widget.userId);

    if (!mounted) return;

    setState(() {
      _cartCount = cart.length;
    });
  }

  Future<void> _search(String keyword) async {
    _searchKeyword = keyword.trim();

    if (_searchKeyword.isEmpty) {
      if (!mounted) return;
      setState(() {
        _isSearching = false;
      });
      _updateSearchHistoryVisibility();
      return;
    }

    if (!mounted) return;
    setState(() => _isSearching = true);
    _updateSearchHistoryVisibility();

    final result = await ApiClient.searchProducts(_searchKeyword);

    if (!mounted || _searchController.text.trim() != _searchKeyword) {
      return;
    }

    setState(() {
      _products = result.where(_isInStock).toList();
      _hasMore = false;
      _isLoadingMore = false;
    });
  }

  Future<void> _submitSearch(String keyword) async {
    final value = keyword.trim();
    if (value.isEmpty) {
      _updateSearchHistoryVisibility();
      return;
    }

    _searchController.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
    _searchFocusNode.unfocus();
    await _search(value);
    await _saveSearchHistory(value);
  }

  Future<void> _selectSearchHistory(String keyword) async {
    await _submitSearch(keyword);
  }

  Future<void> _toggleVoiceSearch() async {
    if (_isListening) {
      await _speech.stop();
      if (mounted) setState(() => _isListening = false);
      return;
    }

    try {
      if (!_speechInitialized) {
        final available = await _speech.initialize(
          onStatus: (status) {
            if (!mounted) return;
            if (status == 'done' || status == 'notListening') {
              setState(() => _isListening = false);
            }
          },
        );
        if (!available) {
          if (mounted) {
            showAppSnackBar(
              context,
              'อุปกรณ์นี้ไม่รองรับการค้นหาด้วยเสียง',
              isError: true,
            );
          }
          return;
        }
        _speechInitialized = true;
      }

      final locales = await _speech.locales();
      String? localeId;
      for (final locale in locales) {
        if (locale.localeId.toLowerCase().startsWith('th')) {
          localeId = locale.localeId;
          break;
        }
      }

      _searchFocusNode.unfocus();
      if (mounted) setState(() => _isListening = true);
      await _speech.listen(
        listenOptions: SpeechListenOptions(
          localeId: localeId,
          listenFor: const Duration(seconds: 30),
          pauseFor: const Duration(seconds: 4),
        ),
        onResult: (SpeechRecognitionResult result) {
          final words = result.recognizedWords.trim();
          if (words.isEmpty || !mounted) return;
          _searchController.value = TextEditingValue(
            text: words,
            selection: TextSelection.collapsed(offset: words.length),
          );
          if (result.finalResult) _submitSearch(words);
        },
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _isListening = false);
      showAppSnackBar(context, 'ไม่สามารถเปิดใช้งานไมโครโฟนได้', isError: true);
    }
  }

  Future<void> _captureSearchImage() async {
    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
        maxWidth: 1600,
      );
      if (image == null) return;

      final bytes = await image.readAsBytes();
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('ภาพที่ถ่าย'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 360),
                child: Image.memory(bytes, fit: BoxFit.contain),
              ),
              const SizedBox(height: 12),
              const Text('ขณะนี้ยังไม่รองรับการค้นหาสินค้าจากรูปภาพ'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('ปิด'),
            ),
          ],
        ),
      );
    } catch (_) {
      if (mounted) {
        showAppSnackBar(context, 'ไม่สามารถเปิดกล้องได้', isError: true);
      }
    }
  }

  Future<void> _openProduct(int productId) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            BuyerProductDetailPage(productId: productId, userId: widget.userId),
      ),
    );

    _loadCartCount();
  }

  Future<void> _openCart() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => BuyerCartPage(userId: widget.userId)),
    );

    _loadCartCount();
  }

  // เลือกหมวดหมู่แบบกรองในหน้านี้เลย (ไม่เด้งไปหน้าอื่น)
  // ใช้ร่วมกันทั้งแถบหมวดหมู่ที่เลื่อนได้และเมนูตัวกรอง ให้พฤติกรรมตรงกัน
  Future<void> _selectCategory(int id, String name) async {
    if (_isSearching) {
      _searchFocusNode.unfocus();
      _searchController.clear();
      _hideSearchHistoryDropdown();
    }
    setState(() {
      _searchKeyword = '';
      _isSearching = false;
      _selectedCategoryId = id;
      _selectedCategoryName = name;
    });
    await _reloadProducts();
  }

  Future<void> _showAllHome() async {
    _searchFocusNode.unfocus();
    _searchController.clear();
    _hideSearchHistoryDropdown();

    setState(() {
      _searchKeyword = '';
      _isSearching = false;
      _selectedCategoryId = null;
      _selectedCategoryName = null;
    });

    await _loadAll();
    await _loadCartCount();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        color: AppColors.primary,
        backgroundColor: Colors.white,
        onRefresh: () async {
          await _loadAll();
          await _loadCartCount();
        },
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;

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

            return NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                if (notification.metrics.axis == Axis.vertical &&
                    notification.metrics.extentAfter < 400) {
                  _loadMore();
                }
                return false;
              },
              child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                _buildAppBar(hPad),

                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(hPad, 8, hPad, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildCategoryRow(),

                        if (_isSearching) ...[
                          const SizedBox(height: 6),

                          SectionHeader(
                            title: 'ผลการค้นหา "$_searchKeyword"',
                            icon: Icons.search_rounded,
                          ),

                          const SizedBox(height: 8),

                          _buildProductGrid(columns, width - hPad * 2),
                        ] else ...[
                          // ซ่อนโซน "สินค้ายอดนิยม" ไปเลยเมื่อกำลังดูเฉพาะหมวดหมู่ใดหมวดหมู่หนึ่ง
                          // เพื่อไม่ให้ปนกับสินค้าของหมวดอื่น และไม่เหลือพื้นที่ว่างเปล่า
                          if (_selectedCategoryId == null) ...[
                            const SizedBox(height: 14),
                            _buildPopularSection(width - hPad * 2),
                            const SizedBox(height: 20),
                          ] else
                            const SizedBox(height: 6),

                          SectionHeader(
                            title: _selectedCategoryName ?? 'สินค้าแนะนำ',
                            icon: Icons.grid_view_rounded,
                          ),

                          const SizedBox(height: 6),

                          _buildProductGrid(columns, width - hPad * 2),
                        ],
                      ],
                    ),
                  ),
                ),

                if (!_isLoading && !_isSearching && _hasMore)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: Center(
                        child: _isLoadingMore
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : TextButton(
                                onPressed: _loadMore,
                                child: const Text('โหลดเพิ่มเติม'),
                              ),
                      ),
                    ),
                  ),
              ],
              ),
            );
          },
        ),
      ),
    );
  }

  SliverAppBar _buildAppBar(double hPad) {
    return SliverAppBar(
      pinned: true,
      floating: true,
      automaticallyImplyLeading: false,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: AppColors.primaryDark,
      toolbarHeight: 65,
      titleSpacing: hPad,
      title: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            clipBehavior: Clip.antiAlias,
            child: Image.asset(
              'lib/uploads/profile/image.png', // รูปโลโก้ของแอป
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const Icon(
                Icons.storefront_rounded,
                color: AppColors.primaryDark,
                size: 22,
              ),
            ),
          ),
          const SizedBox(width: 10),
          const Text(
            '2PS Shop',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
      actions: [
        _AppBarIconButton(
          tooltip: 'แชท',
          icon: Icons.chat_bubble_outline_rounded,
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ChatListPage(userId: widget.userId),
              ),
            );
          },
        ),
        const SizedBox(width: 2),
        _AppBarIconButton(
          tooltip: 'ตะกร้าสินค้า',
          icon: Icons.shopping_cart_outlined,
          badgeCount: _cartCount,
          onPressed: _openCart,
        ),
        SizedBox(width: hPad - 8),
      ],
      bottom: PreferredSize(
        preferredSize: Size.fromHeight(60),
        child: Padding(
          padding: EdgeInsets.fromLTRB(hPad, 0, hPad, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [_buildSearchField()],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchField() {
    return CompositedTransformTarget(
      link: _searchHistoryLayerLink,
      child: SizedBox(
        key: _searchFieldKey,
        height: 44,
        child: TextField(
          controller: _searchController,
          focusNode: _searchFocusNode,
          onChanged: _search,
          onSubmitted: _submitSearch,
          onTap: _updateSearchHistoryVisibility,
          textInputAction: TextInputAction.search,
          style: const TextStyle(fontSize: 14, color: Color(0xFF202735)),
          decoration: InputDecoration(
            hintText: 'ค้นหาสินค้า, หมวดหมู่, แบรนด์...',
            hintStyle: const TextStyle(
              color: Color(0xFF9AA1AE),
              fontSize: 13.5,
            ),
            prefixIcon: const Icon(
              Icons.search_rounded,
              color: Color(0xFF9AA1AE),
              size: 22,
            ),
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_searchController.text.isNotEmpty)
                  IconButton(
                    tooltip: 'ล้างคำค้นหา',
                    constraints: const BoxConstraints.tightFor(width: 32),
                    padding: EdgeInsets.zero,
                    icon: const Icon(
                      Icons.clear_rounded,
                      color: Color(0xFF9299A8),
                      size: 18,
                    ),
                    onPressed: () async {
                      _searchController.clear();
                      setState(() {
                        _searchKeyword = '';
                        _isSearching = false;
                      });
                      _updateSearchHistoryVisibility();
                      await _loadAll();
                    },
                  ),
                IconButton(
                  tooltip: _isListening ? 'หยุดฟังเสียง' : 'ค้นหาด้วยเสียง',
                  constraints: const BoxConstraints.tightFor(width: 34),
                  padding: EdgeInsets.zero,
                  icon: Icon(
                    _isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
                    color: _isListening
                        ? const Color(0xFFE5484D)
                        : const Color(0xFF9AA1AE),
                    size: 22,
                  ),
                  onPressed: _toggleVoiceSearch,
                ),
                Container(
                  width: 1,
                  height: 20,
                  color: const Color(0xFFE1E5EB),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                ),
                IconButton(
                  tooltip: 'ถ่ายรูป',
                  constraints: const BoxConstraints.tightFor(width: 34),
                  padding: EdgeInsets.zero,
                  icon: const Icon(
                    Icons.camera_alt_outlined,
                    color: Color(0xFF9AA1AE),
                    size: 21,
                  ),
                  onPressed: _captureSearchImage,
                ),
                const SizedBox(width: 6),
              ],
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              vertical: 0,
              horizontal: 16,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchHistory() {
    final history = _searchHistory.take(5).toList();
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var index = 0; index < history.length; index++) ...[
            SizedBox(
              height: 44,
              child: Row(
                children: [
                  const SizedBox(
                    width: 42,
                    child: Icon(
                      Icons.history_rounded,
                      color: Color(0xFF9299A8),
                      size: 19,
                    ),
                  ),
                  Expanded(
                    child: InkWell(
                      onTap: () => _selectSearchHistory(history[index]),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          history[index],
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF202735),
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 42,
                    child: IconButton(
                      tooltip: 'ลบประวัติ ${history[index]}',
                      onPressed: () => _deleteSearchHistory(history[index]),
                      padding: EdgeInsets.zero,
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Color(0xFF9299A8),
                        size: 18,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (index < history.length - 1)
              const Divider(height: 1, indent: 42, endIndent: 42),
          ],
        ],
      ),
    );
  }

  Widget _buildCategoryRow() {
    final quickCategories = _categories.take(6).toList();

    return SizedBox(
      height: 38,
      child: Row(
        children: [
          Expanded(
            child: ListView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _categoryChip(
                    icon: Icons.apps_rounded,
                    label: 'ทั้งหมด',
                    selected: _selectedCategoryId == null,
                    onTap: _showAllHome,
                  ),
                ),
                ...quickCategories.map((category) {
                  final id = int.tryParse(
                    category['category_id']?.toString() ?? '',
                  );
                  final name = category['category_name']?.toString() ?? '';

                  if (id == null) {
                    return const SizedBox();
                  }

                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _categoryChip(
                      icon: _iconForCategory(name),
                      label: name,
                      selected: _selectedCategoryId == id,
                      onTap: () => _selectCategory(id, name),
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 42,
            height: 38,
            child: PopupMenuButton<int>(
              tooltip: 'กรองหมวดหมู่',
              padding: EdgeInsets.zero,
              onSelected: (categoryId) {
                if (categoryId == -1) {
                  _showAllHome();
                  return;
                }
                final name = _categories
                    .firstWhere(
                      (category) =>
                          int.tryParse(
                            category['category_id']?.toString() ?? '',
                          ) ==
                          categoryId,
                    )['category_name']
                    ?.toString();
                _selectCategory(categoryId, name ?? '');
              },
              itemBuilder: (context) {
                final items = <PopupMenuEntry<int>>[
                  const PopupMenuItem<int>(
                    value: -1,
                    child: Text('ทุกหมวดหมู่'),
                  ),
                  const PopupMenuDivider(),
                ];

                for (final category in _categories) {
                  final id = int.tryParse(
                    category['category_id']?.toString() ?? '',
                  );
                  if (id == null) continue;

                  items.add(
                    PopupMenuItem<int>(
                      value: id,
                      child: Text(
                        category['category_name']?.toString() ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  );
                }

                return items;
              },
              child: Container(
                decoration: BoxDecoration(
                  color: _selectedCategoryId == null
                      ? Colors.white
                      : const Color(0xFFEAF1FF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _selectedCategoryId == null
                        ? const Color(0xFFE1E5EB)
                        : const Color(0xFF264C9E),
                  ),
                ),
                child: Icon(
                  Icons.filter_list_rounded,
                  size: 20,
                  color: _selectedCategoryId == null
                      ? const Color(0xFF4A5568)
                      : const Color(0xFF264C9E),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _categoryChip({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool selected = false,
  }) {
    return Material(
      color: selected ? const Color(0xFF264C9E) : Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? const Color(0xFF264C9E)
                  : const Color(0xFFE1E5EB),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: selected ? Colors.white : const Color(0xFF7B8497),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? Colors.white : const Color(0xFF4A5568),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // แสดงผลสินค้ายอดนิยมแบบแนวนอน
  Widget _buildPopularSection(double availableWidth) {
    final popularProducts = _filterBySelectedCategory(_popular);
    final cardWidth = (availableWidth * .46).clamp(160.0, 210.0).toDouble();
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final cardHeight = cardWidth + 68 * textScale;

    if (_isLoading) {
      return const Padding(padding: EdgeInsets.all(8), child: LoadingView());
    }

    if (popularProducts.isEmpty) {
      return const SizedBox();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 27,
              height: 27,
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(7),
              ),
              child: const Icon(
                Icons.diamond,
                size: 19,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 4),
            const Expanded(
              child: Text(
                'สินค้ายอดนิยม',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF202735),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 8),

        SizedBox(
          height: cardHeight,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: popularProducts.length,
            separatorBuilder: (context, index) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final product = popularProducts[index];
              final productId = int.tryParse(product['product_id'].toString());

              return SizedBox(
                width: cardWidth,
                child: PopularProductCard(
                  name:
                      product['product_name']?.toString() ?? 'ไม่มีชื่อสินค้า',
                  price:
                      double.tryParse(
                        product['product_price']?.toString() ?? '0',
                      ) ??
                      0,
                  stock: int.tryParse(product['stock']?.toString() ?? '0') ?? 0,
                  soldCount:
                      int.tryParse(product['sold_count']?.toString() ?? '0') ??
                      0,
                  imageUrl: pickProductImage(product),
                  onTap: productId == null
                      ? () {}
                      : () => _openProduct(productId),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildProductGrid(int columns, double availableWidth) {
    if (_isLoading) {
      return const Padding(padding: EdgeInsets.all(24), child: LoadingView());
    }

    final filteredProducts = _filterBySelectedCategory(_products);

    if (filteredProducts.isEmpty) {
      return const EmptyState(
        icon: Icons.inventory_2_outlined,
        title: 'ไม่พบสินค้าในหมวดหมู่นี้',
      );
    }

    final displayedProducts = filteredProducts;

    const crossAxisSpacing = 9.0;
    final itemWidth =
        (availableWidth - crossAxisSpacing * (columns - 1)) / columns;
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    // เดิมเผื่อ 84px สำหรับชื่อสินค้า 2 บรรทัด ทำให้สินค้าที่ชื่อสั้น (1 บรรทัด)
    // เหลือพื้นที่ว่างด้านล่างการ์ดเยอะเกินไป ปรับชื่อให้แสดงแค่ 1 บรรทัด (ดู product_card.dart)
    // แล้วลดพื้นที่ที่เผื่อไว้ให้พอดีกับเนื้อหาจริง
    final itemHeight = itemWidth + 64 * textScale;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: displayedProducts.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        crossAxisSpacing: crossAxisSpacing,
        mainAxisSpacing: 9,
        childAspectRatio: itemWidth / itemHeight,
      ),
      itemBuilder: (context, index) {
        final product = displayedProducts[index];
        final productId = int.tryParse(product['product_id'].toString());

        return ProductCard(
          name: product['product_name']?.toString() ?? 'ไม่มีชื่อสินค้า',
          price:
              double.tryParse(product['product_price']?.toString() ?? '0') ?? 0,
          stock: int.tryParse(product['stock']?.toString() ?? '0') ?? 0,
          soldCount:
              int.tryParse(product['sold_count']?.toString() ?? '0') ?? 0,
          imageUrl: pickProductImage(product),
          onTap: productId == null ? () {} : () => _openProduct(productId),
        );
      },
    );
  }
}

class _AppBarIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final int badgeCount;

  const _AppBarIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.badgeCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: IconButton(
        tooltip: tooltip,
        splashRadius: 21,
        onPressed: onPressed,
        icon: Badge(
          label: Text(
            '$badgeCount',
            style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700),
          ),
          isLabelVisible: badgeCount > 0,
          backgroundColor: const Color(0xFFF94C66),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}
