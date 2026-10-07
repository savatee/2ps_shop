import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/image_utils.dart';
import '../../core/utils/product_image_cache.dart';
import '../../core/widgets/app_bar_cart_button.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/product_card.dart';
import '../../core/widgets/section_header.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../core/widgets/loading_view.dart';
import '../../core/widgets/product_thumb.dart';
import '../../core/widgets/quantity_selector.dart';
import '../../core/network/api_client.dart';
import 'buyer_checkout_page.dart';
import '../chat/chat_room_page.dart';
import 'buyer_cart_page.dart';
import 'buyer_store_page.dart';

class _BuyerProductSearchDelegate extends SearchDelegate<void> {
  final int userId;
  String _searchedQuery = '';
  Future<List<dynamic>>? _searchFuture;

  _BuyerProductSearchDelegate({required this.userId});

  @override
  List<Widget> buildActions(BuildContext context) => [
    if (query.isNotEmpty)
      IconButton(
        tooltip: 'ล้างคำค้นหา',
        onPressed: () => query = '',
        icon: const Icon(Icons.clear_rounded),
      ),
  ];

  @override
  Widget buildLeading(BuildContext context) => IconButton(
    tooltip: 'กลับ',
    onPressed: () => close(context, null),
    icon: const Icon(Icons.arrow_back_rounded),
  );

  @override
  Widget buildResults(BuildContext context) => _buildMatches(context);

  @override
  Widget buildSuggestions(BuildContext context) => _buildMatches(context);

  Widget _buildMatches(BuildContext context) {
    final searchTerm = query.trim();
    if (searchTerm.isEmpty) {
      return const Center(child: Text('ค้นหาสินค้าที่ต้องการ'));
    }

    if (_searchedQuery != searchTerm) {
      _searchedQuery = searchTerm;
      _searchFuture = ApiClient.searchProducts(searchTerm).then(
        (products) => products.where((product) {
          return (int.tryParse(product['stock']?.toString() ?? '0') ?? 0) > 0;
        }).toList(),
      );
    }

    return FutureBuilder<List<dynamic>>(
      future: _searchFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingView();
        }
        if (snapshot.hasError) {
          return const Center(child: Text('ค้นหาไม่สำเร็จ กรุณาลองใหม่'));
        }

        final products = snapshot.data ?? [];
        if (products.isEmpty) {
          return const Center(child: Text('ไม่พบสินค้าที่ตรงกับคำค้นหา'));
        }

        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: products.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final product = products[index];
            final productId = int.tryParse(
              product['product_id']?.toString() ?? '',
            );
            final name =
                product['product_name']?.toString() ?? 'ไม่มีชื่อสินค้า';
            final price =
                double.tryParse(product['product_price']?.toString() ?? '0') ??
                0;

            return ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 4,
              ),
              leading: SizedBox(
                width: 52,
                height: 52,
                child: ProductThumb(imageUrl: pickProductImage(product)),
              ),
              title: Text(name, maxLines: 2, overflow: TextOverflow.ellipsis),
              subtitle: Text('฿${price.toStringAsFixed(2)}'),
              onTap: productId == null
                  ? null
                  : () {
                      final navigator = Navigator.of(context);
                      close(context, null);
                      navigator.push(
                        MaterialPageRoute(
                          builder: (_) => BuyerProductDetailPage(
                            productId: productId,
                            userId: userId,
                          ),
                        ),
                      );
                    },
            );
          },
        );
      },
    );
  }
}

class BuyerProductDetailPage extends StatefulWidget {
  final int productId;
  final int userId;

  const BuyerProductDetailPage({
    super.key,
    required this.productId,
    required this.userId,
  });

  @override
  State<BuyerProductDetailPage> createState() => _BuyerProductDetailPageState();
}

class _BuyerProductDetailPageState extends State<BuyerProductDetailPage> {
  Map<String, dynamic>? _product;

  bool _isLoading = true;
  bool _isSubmitting = false;

  int _quantity = 1;
  int _cartCount = 0;
  int _currentImageIndex = 0;

  List<dynamic> _categoryProducts = [];
  List<dynamic> _otherProducts = [];

  bool _isLoadingRelated = false;

  @override
  void initState() {
    super.initState();
    _loadProduct();
    _loadCartCount();
  }

  Future<void> _loadProduct() async {
    if (mounted) {
      setState(() => _isLoading = true);
    }

    try {
      final result = await ApiClient.getProduct(widget.productId);

      if (!mounted) return;

      final data = result['data'] ?? result['product'];

      setState(() {
        _product = (result['success'] == true && data is Map)
            ? Map<String, dynamic>.from(data)
            : null;
        _currentImageIndex = 0;

        _isLoading = false;
      });

      if (_product != null) {
        ProductImageCache.remember(
          widget.productId,
          pickProductImage(_product),
        );

        _loadRelatedProducts();
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _product = null;
        _isLoading = false;
      });
    }
  }

  Future<void> _loadCartCount() async {
    try {
      final cart = await ApiClient.getCart(widget.userId);
      if (mounted) setState(() => _cartCount = cart.length);
    } catch (_) {
      // Cart count is supplementary; keep the detail page usable offline.
    }
  }

  Future<void> _loadRelatedProducts() async {
    final categoryId = int.tryParse(_product?['category_id']?.toString() ?? '');

    if (mounted) {
      setState(() => _isLoadingRelated = true);
    }

    try {
      // ดึงเฉพาะที่ต้องใช้ (ไม่โหลดสินค้าทั้งร้านอีกต่อไป)
      // sold_count ของสินค้านี้ได้จาก get_product อยู่แล้ว
      final results = await Future.wait<List<dynamic>>([
        categoryId == null
            ? Future.value(<dynamic>[])
            : ApiClient.getProducts(
                limit: 12,
                categoryId: categoryId,
                excludeId: widget.productId,
                inStock: true,
              ),
        ApiClient.getProducts(
          limit: 24,
          excludeId: widget.productId,
          inStock: true,
        ),
      ]);

      final sameCategory = results[0];
      final sameCategoryIds = sameCategory
          .map((p) => p['product_id']?.toString())
          .toSet();

      final others = results[1]
          .where((p) => !sameCategoryIds.contains(p['product_id']?.toString()))
          .take(12)
          .toList();

      if (!mounted) return;
      setState(() {
        _categoryProducts = sameCategory;
        _otherProducts = others;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _categoryProducts = [];
        _otherProducts = [];
      });
    } finally {
      if (mounted) setState(() => _isLoadingRelated = false);
    }
  }

  Widget _buildRelatedSection(double hPad, int columns, String? categoryName) {
    if (_isLoadingRelated) {
      return const Padding(padding: EdgeInsets.all(32), child: LoadingView());
    }

    if (_categoryProducts.isEmpty && _otherProducts.isEmpty) {
      return const SizedBox();
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(hPad, 8, hPad, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_categoryProducts.isNotEmpty) ...[
            SectionHeader(
              title: categoryName == null
                  ? 'สินค้าในหมวดหมู่เดียวกัน'
                  : 'สินค้าในหมวดหมู่ $categoryName',
              icon: Icons.grid_view_rounded,
            ),
            const SizedBox(height: 8),
            _relatedGrid(_categoryProducts, columns),
            const SizedBox(height: 26),
          ],
          if (_otherProducts.isNotEmpty) ...[
            const SectionHeader(
              title: 'สินค้าอื่นๆ ที่คุณอาจสนใจ',
              icon: Icons.grid_view_rounded,
            ),
            const SizedBox(height: 8),
            _relatedGrid(_otherProducts, columns),
          ],
        ],
      ),
    );
  }

  Widget _relatedGrid(List<dynamic> items, int columns) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // สูตรขนาดการ์ดเดียวกับหน้าหลัก (buyer_home_page.dart)
        const crossAxisSpacing = 9.0;
        final itemWidth =
            (constraints.maxWidth - crossAxisSpacing * (columns - 1)) / columns;
        final textScale = MediaQuery.textScalerOf(context).scale(1);
        final itemHeight = itemWidth + 64 * textScale;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          itemCount: items.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: crossAxisSpacing,
            mainAxisSpacing: 9,
            childAspectRatio: itemWidth / itemHeight,
          ),
          itemBuilder: (context, index) {
            final product = items[index];
            final productId = int.tryParse(product['product_id'].toString());

            return ProductCard(
              name: product['product_name']?.toString() ?? 'ไม่มีชื่อสินค้า',
              price:
                  double.tryParse(
                    product['product_price']?.toString() ?? '0',
                  ) ??
                  0,
              stock: int.tryParse(product['stock']?.toString() ?? '0') ?? 0,
              // ขายแล้วจากฐานข้อมูลจริง (sold_count) แสดงรูปแบบเดียวกับหน้าหลัก
              soldCount:
                  int.tryParse(product['sold_count']?.toString() ?? '0') ?? 0,
              imageUrl: pickProductImage(product),
              onTap: productId == null
                  ? () {}
                  : () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => BuyerProductDetailPage(
                          productId: productId,
                          userId: widget.userId,
                        ),
                      ),
                    ),
            );
          },
        );
      },
    );
  }

  int get _stock {
    return int.tryParse(_product?['stock']?.toString() ?? '0') ?? 0;
  }

  List<Map<String, dynamic>> get _variants {
    final variants = _product?['variants'];
    if (variants is! List) return [];

    return variants
        .whereType<Map>()
        .map((variant) => Map<String, dynamic>.from(variant))
        .toList();
  }

  bool get _hasVariants => _variants.isNotEmpty;

  double get _price {
    return double.tryParse(_product?['product_price']?.toString() ?? '0') ?? 0;
  }

  int? get _sellerId {
    return int.tryParse(_product?['product_seller_id']?.toString() ?? '');
  }

  Future<bool> _addToCart({int? variantId, int? quantity}) async {
    if (_product == null || _stock <= 0) {
      return false;
    }

    final selectedQuantity = quantity ?? _quantity;
    if (selectedQuantity > _stock) {
      showAppSnackBar(context, 'จำนวนสินค้าเกินสต็อก', isError: true);
      return false;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final result = await ApiClient.addToCart(
        userId: widget.userId,
        productId: widget.productId,
        quantity: selectedQuantity,
        variantId: variantId,
      );
      if (!mounted) return false;

      final success = result['success'] == true;
      showAppSnackBar(
        context,
        result['message']?.toString() ??
            (success
                ? 'เพิ่มสินค้าลงตะกร้าสำเร็จ'
                : 'ไม่สามารถเพิ่มสินค้าลงตะกร้าได้'),
        isError: !success,
      );
      if (success) _loadCartCount();
      return success;
    } catch (_) {
      if (mounted) {
        showAppSnackBar(
          context,
          'เชื่อมต่อไม่สำเร็จ กรุณาลองใหม่',
          isError: true,
        );
      }
      return false;
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _buyNow({
    int? variantId,
    int? quantity,
    double? unitPrice,
  }) async {
    if (_product == null || _stock <= 0) {
      return;
    }

    final selectedQuantity = quantity ?? _quantity;
    if (selectedQuantity > _stock) {
      showAppSnackBar(context, 'จำนวนสินค้าเกินสต็อก', isError: true);
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => BuyerCheckoutPage(
            userId: widget.userId,
            total: (unitPrice ?? _price) * selectedQuantity,
            cartIds: const [],
            productId: widget.productId,
            quantity: selectedQuantity,
            variantId: variantId,
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _onAddToCart() async {
    if (!_hasVariants) {
      await _addToCart();
      return;
    }
    await _showVariantPicker();
  }

  Future<void> _onBuyNow() async {
    if (!_hasVariants) {
      await _buyNow();
      return;
    }
    await _showVariantPicker();
  }

  Future<void> _showVariantPicker() async {
    final variants = _variants;
    if (variants.isEmpty || _product == null) return;

    final choice = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        var selectedVariant = variants.firstWhere(
          (variant) =>
              (int.tryParse(variant['variant_stock']?.toString() ?? '0') ?? 0) >
              0,
          orElse: () => variants.first,
        );
        var quantity = 1;

        String? optionValue(Map<String, dynamic> variant, String key) {
          final value = variant[key]?.toString().trim();
          return value == null || value.isEmpty ? null : value;
        }

        final colors = variants
            .map((variant) => optionValue(variant, 'variant_color'))
            .whereType<String>()
            .toSet()
            .toList();

        return StatefulBuilder(
          builder: (context, setSheetState) {
            final selectedColor = optionValue(selectedVariant, 'variant_color');
            final sizes = variants
                .where(
                  (variant) =>
                      selectedColor == null ||
                      optionValue(variant, 'variant_color') == selectedColor,
                )
                .map((variant) => optionValue(variant, 'variant_size'))
                .whereType<String>()
                .toSet()
                .toList();
            final variantStock =
                int.tryParse(
                  selectedVariant['variant_stock']?.toString() ?? '0',
                ) ??
                0;
            final variantPrice =
                double.tryParse(
                  selectedVariant['variant_price']?.toString() ?? '',
                ) ??
                _price;

            void selectVariant(Map<String, dynamic> variant) {
              setSheetState(() {
                selectedVariant = variant;
                final stock =
                    int.tryParse(variant['variant_stock']?.toString() ?? '0') ??
                    0;
                if (quantity > stock) quantity = stock;
                if (quantity < 1 && stock > 0) quantity = 1;
              });
            }

            Widget optionChip({
              required String label,
              required bool selected,
              required VoidCallback onTap,
            }) {
              return ChoiceChip(
                label: Text(label),
                selected: selected,
                onSelected: (_) => onTap(),
                selectedColor: const Color(0xFFE5EDFF),
                side: BorderSide(
                  color: selected
                      ? const Color(0xFF315FD3)
                      : const Color(0xFFE2E5EA),
                  width: selected ? 1.5 : 1,
                ),
                labelStyle: TextStyle(
                  color: selected
                      ? const Color(0xFF244CB2)
                      : const Color(0xFF394150),
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
                showCheckmark: false,
              );
            }

            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.88,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: Container(
                              width: 42,
                              height: 4,
                              decoration: BoxDecoration(
                                color: const Color(0xFFD5D9E0),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: 76,
                                height: 76,
                                child: ProductThumb(
                                  imageUrl: pickProductImage(_product),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '฿${variantPrice.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        color: AppColors.primary,
                                        fontSize: 20,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 5),
                                    Text(
                                      _product!['product_name']?.toString() ??
                                          'สินค้า',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                    Text(
                                      variantStock > 0
                                          ? 'คงเหลือ $variantStock ชิ้น'
                                          : 'สินค้าหมด',
                                      style: const TextStyle(
                                        color: Color(0xFF727A88),
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                tooltip: 'ปิด',
                                onPressed: () => Navigator.pop(sheetContext),
                                icon: const Icon(Icons.close_rounded),
                              ),
                            ],
                          ),
                          const Divider(height: 26),
                          if (colors.isNotEmpty) ...[
                            Text(
                              'สี',
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              children: colors.map((color) {
                                return optionChip(
                                  label: color,
                                  selected: selectedColor == color,
                                  onTap: () {
                                    final matches = variants
                                        .where(
                                          (variant) =>
                                              optionValue(
                                                variant,
                                                'variant_color',
                                              ) ==
                                              color,
                                        )
                                        .toList();
                                    final sameSize = matches
                                        .where(
                                          (variant) =>
                                              optionValue(
                                                variant,
                                                'variant_size',
                                              ) ==
                                              optionValue(
                                                selectedVariant,
                                                'variant_size',
                                              ),
                                        )
                                        .toList();
                                    selectVariant(
                                      sameSize.isNotEmpty
                                          ? sameSize.first
                                          : matches.first,
                                    );
                                  },
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 16),
                          ],
                          if (sizes.isNotEmpty) ...[
                            Text(
                              'ขนาด / ไซส์',
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              children: sizes.map((size) {
                                final matchingVariants = variants
                                    .where(
                                      (variant) =>
                                          optionValue(
                                                variant,
                                                'variant_size',
                                              ) ==
                                              size &&
                                          (selectedColor == null ||
                                              optionValue(
                                                    variant,
                                                    'variant_color',
                                                  ) ==
                                                  selectedColor),
                                    )
                                    .toList();
                                final available = matchingVariants.any(
                                  (variant) =>
                                      (int.tryParse(
                                            variant['variant_stock']
                                                    ?.toString() ??
                                                '0',
                                          ) ??
                                          0) >
                                      0,
                                );
                                return optionChip(
                                  label: size,
                                  selected:
                                      optionValue(
                                        selectedVariant,
                                        'variant_size',
                                      ) ==
                                      size,
                                  onTap: available
                                      ? () {
                                          final inStock = matchingVariants
                                              .where(
                                                (variant) =>
                                                    (int.tryParse(
                                                          variant['variant_stock']
                                                                  ?.toString() ??
                                                              '0',
                                                        ) ??
                                                        0) >
                                                    0,
                                              )
                                              .toList();
                                          selectVariant(inStock.first);
                                        }
                                      : () {},
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 16),
                          ],
                          Row(
                            children: [
                              const Text(
                                'จำนวน',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                              const Spacer(),
                              IconButton(
                                tooltip: 'ลดจำนวน',
                                onPressed: quantity > 1
                                    ? () => setSheetState(() => quantity--)
                                    : null,
                                icon: const Icon(Icons.remove_circle_outline),
                              ),
                              Text('$quantity'),
                              IconButton(
                                tooltip: 'เพิ่มจำนวน',
                                onPressed: quantity < variantStock
                                    ? () => setSheetState(() => quantity++)
                                    : null,
                                icon: const Icon(Icons.add_circle_outline),
                              ),
                            ],
                          ),
                          Text(
                            'ยอดรวม ฿${(variantPrice * quantity).toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: variantStock <= 0
                                ? null
                                : () => Navigator.pop(sheetContext, {
                                    'action': 'cart',
                                    'variant': selectedVariant,
                                    'quantity': quantity,
                                  }),
                            icon: const Icon(Icons.add_shopping_cart_outlined),
                            label: const Text('ใส่ตะกร้า'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: variantStock <= 0
                                ? null
                                : () => Navigator.pop(sheetContext, {
                                    'action': 'buy',
                                    'variant': selectedVariant,
                                    'quantity': quantity,
                                  }),
                            icon: const Icon(Icons.arrow_forward_rounded),
                            label: const Text('ซื้อเลย'),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
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
      },
    );

    if (!mounted || choice == null) return;

    final variant = Map<String, dynamic>.from(choice['variant'] as Map);
    final variantId = int.tryParse(variant['variant_id']?.toString() ?? '');
    final quantity = int.tryParse(choice['quantity']?.toString() ?? '') ?? 1;
    final unitPrice =
        double.tryParse(variant['variant_price']?.toString() ?? '') ?? _price;

    if (variantId == null) {
      showAppSnackBar(context, 'ไม่พบตัวเลือกสินค้านี้', isError: true);
      return;
    }

    if (choice['action'] == 'cart') {
      await _addToCart(variantId: variantId, quantity: quantity);
    } else {
      await _buyNow(
        variantId: variantId,
        quantity: quantity,
        unitPrice: unitPrice,
      );
    }
  }

  void _chatWithSeller() {
    final sellerId = _sellerId;
    if (sellerId == null) {
      showAppSnackBar(context, 'ไม่พบข้อมูลร้านค้า', isError: true);
      return;
    }
    if (sellerId == widget.userId) {
      showAppSnackBar(context, 'นี่คือสินค้าของคุณเอง', isError: true);
      return;
    }

    final rawSellerName = _product?['seller_name']?.toString().trim() ?? '';
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatRoomPage(
          postId: 0,
          buyerId: widget.userId,
          sellerId: sellerId,
          sellerName: rawSellerName.isEmpty ? 'ร้านค้า' : rawSellerName,
        ),
      ),
    );
  }

  void _openSellerStore() {
    final sellerId = _sellerId;
    if (sellerId == null) {
      showAppSnackBar(context, 'ไม่พบข้อมูลร้านค้า', isError: true);
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BuyerStorePage(
          sellerId: sellerId,
          userId: widget.userId,
          sellerName: _product?['seller_name']?.toString(),
        ),
      ),
    );
  }

  List<String> get _productImages {
    final rawImages = _product?['product_images'];
    final images = rawImages is List
        ? rawImages
              .map((image) => image.toString().trim())
              .where((image) => image.isNotEmpty)
              .toList()
        : <String>[];
    if (images.isNotEmpty) return images;

    final fallback =
        pickProductImage(_product) ??
        ProductImageCache.lookup(widget.productId);
    return fallback == null ? [] : [fallback];
  }

  Future<void> _shareProduct() async {
    if (_product == null) return;
    final name = _product!['product_name']?.toString() ?? 'สินค้า';
    final description = _product!['product_description']?.toString() ?? '';
    await SharePlus.instance.share(
      ShareParams(
        title: name,
        text: '$name\nราคา ฿${_price.toStringAsFixed(2)}\n$description',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: LoadingView());
    }

    if (_product == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text(
            'รายละเอียดสินค้า',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          elevation: 0,
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF202735),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF2F6),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(
                    Icons.wifi_off_outlined,
                    size: 30,
                    color: Color(0xFF9299A8),
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'ไม่พบข้อมูลสินค้า\nหรือเชื่อมต่อเซิร์ฟเวอร์ไม่ได้',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: Color(0xFF777F8D),
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: 150,
                  height: 42,
                  child: SecondaryButton(
                    label: 'ลองใหม่',
                    onPressed: _loadProduct,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final soldOut = _stock <= 0;
    final name = _product!['product_name']?.toString() ?? 'ไม่มีชื่อสินค้า';
    final description =
        _product!['product_description']?.toString() ?? 'ไม่มีรายละเอียดสินค้า';
    final sellerName = _product!['seller_name']?.toString() ?? 'ร้านค้า';
    final categoryName = _product!['category_name']?.toString();
    final productImages = _productImages;
    final soldCount =
        int.tryParse(_product!['sold_count']?.toString() ?? '0') ?? 0;

    // แปลงจำนวนขายเป็น K
    String formattedSoldCount = soldCount.toString();
    if (soldCount >= 1000) {
      formattedSoldCount = '${(soldCount / 1000).toStringAsFixed(1)}k';
    }

    return Scaffold(
      backgroundColor: AppColors.background,

      // =========================
      // App Bar (ทับรูปภาพสินค้า)
      // =========================
      appBar: AppBar(
        backgroundColor: AppColors.primaryDark,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0,
        title: Container(
          height: 36,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
          ),
          child: TextField(
            readOnly: true,
            onTap: () => showSearch<void>(
              context: context,
              delegate: _BuyerProductSearchDelegate(userId: widget.userId),
              query: name,
            ),
            decoration: InputDecoration(
              hintText: name,
              hintStyle: const TextStyle(
                fontSize: 13,
                color: Color(0xFF202735),
              ),
              prefixIcon: const Icon(
                Icons.search,
                size: 20,
                color: Colors.grey,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                vertical: 10,
                horizontal: 10,
              ),
            ),
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'แชร์สินค้า',
            icon: const Icon(Icons.share_outlined, color: Colors.white),
            onPressed: _shareProduct,
          ),
          AppBarCartButton(
            count: _cartCount,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => BuyerCartPage(userId: widget.userId),
                ),
              ).then((_) => _loadCartCount());
            },
          ),
          const SizedBox(width: 4),
        ],
      ),

      body: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final columns = width >= 1100
              ? 5
              : width >= 800
              ? 4
              : width >= 600
              ? 3
              : 2;

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // =========================
                // รูปสินค้า
                // =========================
                AspectRatio(
                  aspectRatio: 1.0, // สัดส่วน 1:1
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (productImages.isEmpty)
                        ProductThumb(dimmed: soldOut, iconSize: 80)
                      else
                        PageView.builder(
                          itemCount: productImages.length,
                          onPageChanged: (index) {
                            setState(() => _currentImageIndex = index);
                          },
                          itemBuilder: (context, index) => ProductThumb(
                            imageUrl: productImages[index],
                            dimmed: soldOut,
                            iconSize: 80,
                          ),
                        ),
                      if (productImages.isNotEmpty)
                        Positioned(
                          right: 16,
                          bottom: 16,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.55),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              productImages.length == 1
                                  ? '1'
                                  : '${_currentImageIndex + 1}/${productImages.length}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // =========================
                // แถบราคา
                // =========================
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  color: const Color(0xFF264C9E),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text(
                        '฿ ',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        _price.toStringAsFixed(2),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          height: 1.0,
                        ),
                      ),
                    ],
                  ),
                ),

                // =========================
                // ข้อมูลสินค้า (ชื่อ, ขายแล้ว)
                // =========================
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              name,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF202735),
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'ขายแล้ว $formattedSoldCount ชิ้น',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF596170),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                // =========================
                // ข้อมูลร้านค้า
                // =========================
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: AppColors.primaryDark,
                        child: Text(
                          sellerName.trim().isEmpty
                              ? '?'
                              : sellerName.trim()[0].toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    sellerName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'สถานะออนไลน์ยังไม่มีข้อมูล',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: _openSellerStore,
                        icon: const Icon(Icons.storefront, size: 16),
                        label: const Text(
                          'ดูร้านค้า',
                          style: TextStyle(fontSize: 12),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(color: AppColors.primary),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          minimumSize: const Size(0, 32),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                // =========================
                // คุณสมบัติสินค้า / รายละเอียด
                // =========================
                Container(
                  width: double.infinity,
                  color: Colors.white,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'คุณสมบัติสินค้า',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Color(0xFF202735),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // จำลองคุณสมบัติเป็นตาราง
                      _buildSpecRow('หมวดหมู่', categoryName ?? 'ทั่วไป'),
                      _buildSpecRow('รายละเอียด', description),
                      _buildSpecRow(
                        'สต็อกสินค้า',
                        soldOut ? 'สินค้าหมด' : 'มีสินค้าพร้อมส่ง $_stock ชิ้น',
                      ),
                    ],
                  ),
                ),

                // =========================
                // จำนวนที่ต้องการ
                // =========================
                if (!soldOut) ...[
                  const SizedBox(height: 8),
                  Container(
                    color: Colors.white,
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        const Text(
                          'จำนวนที่ต้องการ',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF202735),
                          ),
                        ),
                        const Spacer(),
                        QuantitySelector(
                          quantity: _quantity,
                          maxQuantity: _stock,
                          onChanged: (q) {
                            setState(() {
                              _quantity = q;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ],

                // =========================
                // สินค้าแนะนำอื่นๆ
                // =========================
                _buildRelatedSection(16.0, columns, categoryName),
              ],
            ),
          );
        },
      ),

      // =========================
      // Bottom Action Bar
      // =========================
      bottomNavigationBar: SafeArea(
        child: Container(
          height: 60,
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, -3),
              ),
            ],
          ),
          child: Row(
            children: [
              // ร้านค้า
              SizedBox(
                width: 60,
                child: InkWell(
                  onTap: _openSellerStore,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(
                        Icons.storefront_outlined,
                        size: 22,
                        color: Color(0xFF596170),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'ร้านค้า',
                        style: TextStyle(
                          fontSize: 10,
                          color: Color(0xFF596170),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // แชท
              SizedBox(
                width: 60,
                child: InkWell(
                  onTap: _chatWithSeller,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(
                        Icons.chat_bubble_outline_rounded,
                        size: 22,
                        color: Color(0xFF596170),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'แชท',
                        style: TextStyle(
                          fontSize: 10,
                          color: Color(0xFF596170),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // เพิ่มลงรถเข็น
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 4,
                  ),
                  child: InkWell(
                    onTap: soldOut || _isSubmitting ? null : _onAddToCart,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFE7F0FF),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(
                            Icons.add_shopping_cart_rounded,
                            size: 18,
                            color: Color(0xFF264C9E),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'เพิ่มลงรถเข็น',
                            style: TextStyle(
                              color: Color(0xFF264C9E),
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // ซื้อเลย
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(4, 8, 8, 8),
                  child: InkWell(
                    onTap: soldOut || _isSubmitting ? null : _onBuyNow,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF264C9E),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'ซื้อเลย',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              height: 1.1,
                            ),
                          ),
                          Text(
                            '฿${_price.toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                            ),
                          ),
                        ],
                      ),
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

  // Widget ช่วยสร้างแถวคุณสมบัติสินค้า
  Widget _buildSpecRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, color: Color(0xFF202735)),
            ),
          ),
        ],
      ),
    );
  }
}
