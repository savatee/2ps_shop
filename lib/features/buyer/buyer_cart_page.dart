import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/image_utils.dart';
import '../../core/utils/product_image_cache.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/loading_view.dart';
import '../../core/widgets/product_thumb.dart';
import '../../core/widgets/quantity_selector.dart';
import '../../core/network/api_client.dart';
import 'buyer_checkout_page.dart';

class BuyerCartPage extends StatefulWidget {
  final int userId;

  const BuyerCartPage({super.key, required this.userId});

  @override
  State<BuyerCartPage> createState() => _BuyerCartPageState();
}

class _BuyerCartPageState extends State<BuyerCartPage> {
  List<Map<String, dynamic>> _items = [];
  bool _isLoading = true;
  bool _editMode = false;
  final Set<int> _selectedCartIds = {};
  final Set<int> _busyCartIds = {}; // กันกดซ้ำระหว่างรอ API ตอบ
  bool _deleting = false;

  @override
  void initState() {
    super.initState();
    _loadCart();
  }

  Future<void> _loadCart() async {
    setState(() => _isLoading = true);
    final result = await ApiClient.getCart(widget.userId);
    if (!mounted) return;

    final items = result
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    var stockAdjustmentFailed = false;

    for (final item in items) {
      ProductImageCache.remember(_productId(item), pickProductImage(item));
      final stock = _stock(item);
      final qty = _quantity(item);
      if (stock > 0 && qty > stock) {
        final cartId = _cartId(item);
        if (cartId != -1) {
          final result = await ApiClient.updateCart(
            userId: widget.userId,
            cartId: cartId,
            quantity: stock,
          );
          if (result['success'] == true) {
            item['cart_quantity'] = stock;
          } else {
            stockAdjustmentFailed = true;
          }
        }
      }
    }

    setState(() {
      _items = items;
      // เลือกไว้ทุกชิ้นที่ยังมีของ เป็นค่าเริ่มต้น (ผู้ใช้ค่อยติ๊กออกเองได้)
      _selectedCartIds
        ..clear()
        ..addAll(items.where(_isAvailable).map(_cartId));
      _isLoading = false;
    });
    if (stockAdjustmentFailed && mounted) {
      showAppSnackBar(
        context,
        'ปรับจำนวนสินค้าให้ตรงกับสต็อกไม่สำเร็จ',
        isError: true,
      );
    }
  }

  int _cartId(Map<String, dynamic> item) =>
      int.tryParse(item['cart_id']?.toString() ?? '') ?? -1;

  int? _productId(Map<String, dynamic> item) => int.tryParse(
    item['cart_product_id']?.toString() ?? item['product_id']?.toString() ?? '',
  );

  int _quantity(Map<String, dynamic> item) =>
      int.tryParse(
        (item['cart_quantity'] ?? item['quantity'])?.toString() ?? '1',
      ) ??
      1;

  double _price(Map<String, dynamic> item) =>
      double.tryParse(item['product_price']?.toString() ?? '0') ?? 0;

  int _stock(Map<String, dynamic> item) =>
      int.tryParse(item['stock']?.toString() ?? '0') ?? 0;

  bool _isAvailable(Map<String, dynamic> item) => _stock(item) > 0;

  String _shopName(Map<String, dynamic> item) =>
      item['seller_name']?.toString().trim().isNotEmpty == true
      ? item['seller_name'].toString()
      : 'ร้านค้า';

  Map<String, List<Map<String, dynamic>>> get _groupedByShop {
    final map = <String, List<Map<String, dynamic>>>{};
    for (final item in _items) {
      map.putIfAbsent(_shopName(item), () => []).add(item);
    }
    return map;
  }

  double get _selectedTotal => _items
      .where(
        (item) =>
            _isAvailable(item) && _selectedCartIds.contains(_cartId(item)),
      )
      .fold(0, (sum, item) => sum + (_price(item) * _quantity(item)));

  List<int> get _selectedAvailableCartIds => _items
      .where(
        (item) =>
            _isAvailable(item) && _selectedCartIds.contains(_cartId(item)),
      )
      .map(_cartId)
      .where((cartId) => cartId != -1)
      .toList();

  // โหมดแก้ไข (ลบสินค้า) เลือกได้ทุกชิ้นแม้ของจะหมด แต่โหมดปกติ (ชำระเงิน) เลือกได้เฉพาะชิ้นที่ยังมีของ
  bool get _allSelectableSelected {
    final selectableIds = (_editMode ? _items : _items.where(_isAvailable))
        .map(_cartId)
        .toSet();
    return selectableIds.isNotEmpty &&
        selectableIds.every(_selectedCartIds.contains);
  }

  void _toggleEditMode() {
    setState(() {
      _editMode = !_editMode;
      _selectedCartIds.clear();
      if (!_editMode) {
        _selectedCartIds.addAll(_items.where(_isAvailable).map(_cartId));
      }
    });
  }

  void _toggleSelectAll(bool? value) {
    setState(() {
      if (value == true) {
        final ids = _editMode ? _items : _items.where(_isAvailable);
        _selectedCartIds.addAll(ids.map(_cartId));
      } else {
        _selectedCartIds.clear();
      }
    });
  }

  void _toggleShop(List<Map<String, dynamic>> shopItems, bool select) {
    setState(() {
      final ids = _editMode ? shopItems : shopItems.where(_isAvailable);
      if (select) {
        _selectedCartIds.addAll(ids.map(_cartId));
      } else {
        _selectedCartIds.removeAll(shopItems.map(_cartId));
      }
    });
  }

  void _toggleItem(Map<String, dynamic> item, bool? value) {
    if (!_editMode && !_isAvailable(item)) return;
    setState(() {
      final id = _cartId(item);
      if (value == true) {
        _selectedCartIds.add(id);
      } else {
        _selectedCartIds.remove(id);
      }
    });
  }

  Future<void> _updateQuantity(
    Map<String, dynamic> item,
    int newQuantity,
  ) async {
    final cartId = _cartId(item);
    if (cartId == -1 || _busyCartIds.contains(cartId)) return;

    // ลดจาก 1 ให้ถือเป็นการลบออกจากตะกร้า (ตาม logic ฝั่ง backend: quantity <= 0 จะลบแถวทิ้ง)
    if (newQuantity < 1) {
      _confirmRemove(item);
      return;
    }

    // จำกัดจำนวนสูงสุดตามสต็อกจริง กันสั่งเกินจน checkout ไปติด error "สินค้าไม่เพียงพอ"
    final stock = _stock(item);
    final maxQty = stock < 1 ? 1 : stock;
    if (newQuantity > maxQty) {
      showAppSnackBar(
        context,
        'มีสินค้าในสต็อกเพียง $stock ชิ้น',
        isError: true,
      );
      newQuantity = maxQty;
    }

    setState(() {
      _busyCartIds.add(cartId);
      item['cart_quantity'] = newQuantity;
    });

    final result = await ApiClient.updateCart(
      userId: widget.userId,
      cartId: cartId,
      quantity: newQuantity,
    );
    if (!mounted) return;
    setState(() => _busyCartIds.remove(cartId));

    if (result['success'] != true) {
      showAppSnackBar(context, 'แก้ไขจำนวนสินค้าไม่สำเร็จ', isError: true);
      _loadCart();
    }
  }

  Future<void> _confirmRemove(Map<String, dynamic> item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ลบสินค้า'),
        content: Text(
          'ต้องการลบ "${item['product_name'] ?? 'สินค้านี้'}" ออกจากตะกร้าใช่หรือไม่?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ยกเลิก'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('ลบ', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (confirmed == true) _removeItem(item);
  }

  Future<void> _removeItem(Map<String, dynamic> item) async {
    final cartId = _cartId(item);
    if (cartId == -1) return;

    setState(() {
      _items.removeWhere((e) => _cartId(e) == cartId);
      _selectedCartIds.remove(cartId);
    });

    final result = await ApiClient.deleteCart(
      userId: widget.userId,
      cartId: cartId,
    );
    if (!mounted) return;

    if (result['success'] != true) {
      showAppSnackBar(context, 'ลบสินค้าไม่สำเร็จ', isError: true);
      _loadCart();
    }
  }

  Future<void> _confirmRemoveSelected() async {
    if (_selectedCartIds.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ลบสินค้า'),
        content: Text(
          'ต้องการลบสินค้าที่เลือก ${_selectedCartIds.length} รายการออกจากตะกร้าใช่หรือไม่?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ยกเลิก'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('ลบ', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _deleting = true);
    final idsToRemove = _selectedCartIds.toList();
    final deletedIds = <int>{};
    var hasFailures = false;

    for (final cartId in idsToRemove) {
      final result = await ApiClient.deleteCart(
        userId: widget.userId,
        cartId: cartId,
      );
      if (result['success'] == true) {
        deletedIds.add(cartId);
      } else {
        hasFailures = true;
      }
    }

    if (!mounted) return;
    setState(() {
      _items.removeWhere((e) => deletedIds.contains(_cartId(e)));
      _selectedCartIds.removeAll(deletedIds);
      _deleting = false;
      if (!hasFailures) {
        _selectedCartIds.clear();
        _editMode = false;
      }
    });
    if (hasFailures) {
      showAppSnackBar(
        context,
        'ลบบางรายการไม่สำเร็จ กรุณาลองอีกครั้ง',
        isError: true,
      );
    }
  }

  Future<void> _goToCheckout() async {
    final cartIds = _selectedAvailableCartIds;
    if (_editMode || cartIds.isEmpty) {
      showAppSnackBar(
        context,
        'กรุณาเลือกสินค้าที่ต้องการชำระเงิน',
        isError: true,
      );
      return;
    }

    final success = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => BuyerCheckoutPage(
          userId: widget.userId,
          total: _items
              .where((item) => cartIds.contains(_cartId(item)))
              .fold(0, (sum, item) => sum + (_price(item) * _quantity(item))),
          cartIds: cartIds,
        ),
      ),
    );

    if (success == true) _loadCart();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: false,
      extendBodyBehindAppBar: false,
      resizeToAvoidBottomInset: false,
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: Text('ตะกร้า${_items.isNotEmpty ? ' (${_items.length})' : ''}'),
        actions: [
          if (_items.isNotEmpty)
            TextButton(
              onPressed: _toggleEditMode,
              child: Text(
                _editMode ? 'เสร็จสิ้น' : 'แก้ไข',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14.5,
                ),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const LoadingView()
          : _items.isEmpty
          ? EmptyState(
              icon: Icons.shopping_cart_outlined,
              title: 'ตะกร้าว่างเปล่า',
              subtitle: 'ยังไม่มีสินค้าในตะกร้าของคุณ',
              actionLabel: 'ไปเลือกซื้อสินค้า',
              onAction: () => Navigator.pop(context),
            )
          : RefreshIndicator(
              onRefresh: _loadCart,
              child: ListView(
                padding: const EdgeInsets.only(top: 8, bottom: 16),
                children: [
                  ..._groupedByShop.entries.map((entry) {
                    final shopItems = entry.value;
                    final selectableIds =
                        (_editMode ? shopItems : shopItems.where(_isAvailable))
                            .map(_cartId)
                            .toSet();
                    final shopSelected =
                        selectableIds.isNotEmpty &&
                        selectableIds.every(_selectedCartIds.contains);

                    return _ShopGroup(
                      shopName: entry.key,
                      selected: shopSelected,
                      onSelectedChanged: selectableIds.isEmpty
                          ? null
                          : (v) => _toggleShop(shopItems, v ?? false),
                      children: shopItems.map((item) {
                        final available = _isAvailable(item);
                        return _CartItemCard(
                          item: item,
                          quantity: _quantity(item),
                          price: _price(item),
                          available: available,
                          editMode: _editMode,
                          selected: _selectedCartIds.contains(_cartId(item)),
                          onSelectedChanged: (v) => _toggleItem(item, v),
                          onQuantityChanged: (q) => _updateQuantity(item, q),
                          onRemove: () => _confirmRemove(item),
                        );
                      }).toList(),
                    );
                  }),
                ],
              ),
            ),
      bottomNavigationBar: _items.isEmpty
          ? null
          : Container(
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: .08),
                    blurRadius: 12,
                    offset: const Offset(0, -3),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      Checkbox(
                        value: _allSelectableSelected,
                        onChanged: _toggleSelectAll,
                        activeColor: AppColors.primary,
                      ),
                      const Text('ทั้งหมด', style: TextStyle(fontSize: 13.5)),
                      const Spacer(),
                      if (!_editMode)
                        Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: Column(
                            mainAxisSize: MainAxisSize.min, // ป้องกันขยายเต็มจอ
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text(
                                'ยอดรวม',
                                style: TextStyle(
                                  color: AppColors.textGrey,
                                  fontSize: 11.5,
                                ),
                              ),
                              Text(
                                '฿${_selectedTotal.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      SizedBox(
                        width: _editMode ? 96 : 148,
                        height: 42,
                        child: _editMode
                            ? ElevatedButton(
                                onPressed: _selectedCartIds.isEmpty || _deleting
                                    ? null
                                    : _confirmRemoveSelected,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.danger,
                                  foregroundColor: Colors.white,
                                  minimumSize: Size.zero,
                                  padding: EdgeInsets.zero,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                      AppRadius.pill,
                                    ),
                                  ),
                                ),
                                child: _deleting
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : Text('ลบ (${_selectedCartIds.length})'),
                              )
                            : ElevatedButton(
                                onPressed:
                                    _editMode ||
                                        _selectedAvailableCartIds.isEmpty
                                    ? null
                                    : _goToCheckout,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  minimumSize: Size.zero,
                                  padding: EdgeInsets.zero,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                      AppRadius.pill,
                                    ),
                                  ),
                                ),
                                child: Text(
                                  'ชำระเงิน (${_selectedCartIds.length})',
                                  style: const TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}

class _ShopGroup extends StatelessWidget {
  final String shopName;
  final List<Widget> children;
  final bool selected;
  final ValueChanged<bool?>? onSelectedChanged;

  const _ShopGroup({
    required this.shopName,
    required this.children,
    required this.selected,
    required this.onSelectedChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(
          top: BorderSide(color: AppColors.border),
          bottom: BorderSide(color: AppColors.border),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 2),
            child: Row(
              children: [
                Checkbox(
                  value: selected,
                  onChanged: onSelectedChanged,
                  activeColor: AppColors.primary,
                ),
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.storefront_rounded,
                    size: 14,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    shopName,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: AppColors.textDark,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ...children,
        ],
      ),
    );
  }
}

class _CartItemCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final int quantity;
  final double price;
  final bool available;
  final bool editMode;
  final bool selected;
  final ValueChanged<bool?> onSelectedChanged;
  final ValueChanged<int> onQuantityChanged;
  final VoidCallback onRemove;

  const _CartItemCard({
    required this.item,
    required this.quantity,
    required this.price,
    required this.available,
    required this.editMode,
    required this.selected,
    required this.onSelectedChanged,
    required this.onQuantityChanged,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final name = item['product_name']?.toString() ?? 'สินค้า';
    final imageUrl = pickProductImage(item);
    final imageCount =
        int.tryParse(item['product_image_count']?.toString() ?? '') ??
        (imageUrl == null ? 0 : 1);
    final stock = int.tryParse(item['stock']?.toString() ?? '0') ?? 0;
    final subtotal = price * quantity;
    final options = [
      if (item['variant_color']?.toString().isNotEmpty ?? false)
        'สี ${item['variant_color']}',
      if (item['variant_size']?.toString().isNotEmpty ?? false)
        'ไซส์ ${item['variant_size']}',
    ].join(' · ');
    // โหมดปกติ: ของหมดกดเลือกไม่ได้ (สั่งซื้อไม่ได้) / โหมดแก้ไข: เลือกได้เสมอ เพื่อลบทิ้งได้ง่าย
    final checkboxEnabled = editMode || available;

    return Opacity(
      opacity: available || editMode ? 1 : 0.55,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              value: selected,
              onChanged: checkboxEnabled ? onSelectedChanged : null,
              activeColor: AppColors.primary,
            ),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              child: SizedBox(
                width: 72,
                height: 72,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ProductThumb(imageUrl: imageUrl, dimmed: !available),
                    if (imageCount > 0)
                      Positioned(
                        right: 4,
                        bottom: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            imageCount == 1 ? '1' : '1/$imageCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13.5,
                      color: AppColors.textDark,
                    ),
                  ),
                  if (options.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      options,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textGrey,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                  const SizedBox(height: 6),
                  if (!available)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.dangerBg,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      child: const Text(
                        'สินค้าหมด',
                        style: TextStyle(
                          color: AppColors.danger,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '฿${price.toStringAsFixed(2)}',
                            style: TextStyle(
                              color: available
                                  ? AppColors.primary
                                  : AppColors.textGrey,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          if (quantity > 1)
                            Text(
                              'รวม ฿${subtotal.toStringAsFixed(2)}',
                              style: const TextStyle(
                                color: AppColors.textGrey,
                                fontSize: 11.5,
                              ),
                            ),
                        ],
                      ),
                      if (editMode)
                        Text(
                          'x$quantity',
                          style: const TextStyle(
                            color: AppColors.textGrey,
                            fontSize: 12.5,
                          ),
                        )
                      else if (available)
                        QuantitySelector(
                          quantity: quantity,
                          iconSize: 15,
                          maxQuantity: stock,
                          onChanged: onQuantityChanged,
                        )
                      else
                        TextButton.icon(
                          onPressed: onRemove,
                          icon: const Icon(
                            Icons.delete_outline,
                            size: 16,
                            color: AppColors.danger,
                          ),
                          label: const Text(
                            'ลบออก',
                            style: TextStyle(
                              color: AppColors.danger,
                              fontSize: 12.5,
                            ),
                          ),
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: Size.zero,
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
    );
  }
}
