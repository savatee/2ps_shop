import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../core/widgets/loading_view.dart';
import '../../core/widgets/product_thumb.dart';
import '../../core/utils/image_utils.dart';
import '../../core/network/api_client.dart';
import 'order_success_page.dart';
import 'payment_page.dart';
import 'widgets/address_form_sheet.dart';

class BuyerCheckoutPage extends StatefulWidget {
  final int userId;
  final double total;
  final List<int> cartIds;
  final int? productId;
  final int? quantity;
  final int? variantId;

  const BuyerCheckoutPage({
    super.key,
    required this.userId,
    required this.total,
    required this.cartIds,
    this.productId,
    this.quantity,
    this.variantId,
  });

  @override
  State<BuyerCheckoutPage> createState() => _BuyerCheckoutPageState();
}

class _BuyerCheckoutPageState extends State<BuyerCheckoutPage> {
  List<Map<String, dynamic>> _addresses = [];
  List<Map<String, dynamic>> _items = [];

  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _submitError;

  int? _selectedAddressId;
  String _paymentMethod = 'qr';

  double _subtotal = 0;
  final double _shippingFee = 35.0;
  final double _shippingDiscount = 35.0;

  Map<String, List<Map<String, dynamic>>> get _itemsBySeller {
    final groups = <String, List<Map<String, dynamic>>>{};
    for (var index = 0; index < _items.length; index++) {
      final item = _items[index];
      final sellerId = int.tryParse(
        (item['product_seller_id'] ?? item['seller_id'])?.toString() ?? '',
      );
      final sellerName = item['seller_name']?.toString().trim() ?? '';
      final groupKey = sellerId != null && sellerId > 0
          ? 'seller:$sellerId'
          : sellerName.isNotEmpty
          ? 'name:$sellerName'
          : 'unknown:$index';
      groups.putIfAbsent(groupKey, () => []).add(item);
    }
    return groups;
  }

  String _sellerLabel(List<Map<String, dynamic>> items) {
    final first = items.first;
    final name = first['seller_name']?.toString().trim() ?? '';
    final sellerId = first['product_seller_id'] ?? first['seller_id'];
    if (name.isNotEmpty) {
      final duplicateName = _itemsBySeller.values.where((group) {
        return group.first['seller_name']?.toString().trim() == name;
      }).length > 1;
      return duplicateName && sellerId != null ? '$name (#$sellerId)' : name;
    }
    if (sellerId != null) return 'ร้านค้า #$sellerId';
    return 'ร้านค้าพันธมิตร 2PS Official';
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    // โหลดที่อยู่
    final addrResult = await ApiClient.getAddresses(widget.userId);
    final addresses = addrResult
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    // โหลดรายการสินค้า
    List<Map<String, dynamic>> loadedItems = [];
    double calculatedSubtotal = 0;

    if (widget.cartIds.isNotEmpty) {
      final cartResult = await ApiClient.getCart(widget.userId);
      final allCart = cartResult
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      loadedItems = allCart.where((item) {
        final cid = int.tryParse(item['cart_id']?.toString() ?? '');
        return widget.cartIds.contains(cid);
      }).toList();
      for (var item in loadedItems) {
        final price =
            double.tryParse(item['product_price']?.toString() ?? '0') ?? 0;
        final qty =
            int.tryParse(
              item['cart_quantity']?.toString() ??
                  item['quantity']?.toString() ??
                  '1',
            ) ??
            1;
        calculatedSubtotal += price * qty;
      }
    } else if (widget.productId != null) {
      final prodResult = await ApiClient.getProduct(widget.productId!);
      if (prodResult['success'] == true) {
        final p = prodResult['data'] ?? prodResult['product'];
        if (p != null) {
          final product = Map<String, dynamic>.from(p);
          final variants = product['variants'];
          if (widget.variantId != null && variants is List) {
            final selectedVariants = variants
                .whereType<Map>()
                .where(
                  (variant) =>
                      int.tryParse(variant['variant_id']?.toString() ?? '') ==
                      widget.variantId,
                )
                .toList();
            if (selectedVariants.isNotEmpty) {
              final variant = selectedVariants.first;
              product['product_price'] = variant['variant_price'];
              product['variant_size'] = variant['variant_size'];
              product['variant_color'] = variant['variant_color'];
              product['variant_id'] = variant['variant_id'];
              product['stock'] = variant['variant_stock'];
            }
          }
          loadedItems = [product];
          final price =
              double.tryParse(product['product_price']?.toString() ?? '0') ?? 0;
          final qty = widget.quantity ?? 1;
          loadedItems[0]['cart_quantity'] = qty;
          calculatedSubtotal += price * qty;
        }
      }
    }

    if (!mounted) return;

    setState(() {
      _addresses = addresses;
      _items = loadedItems;
      _subtotal = calculatedSubtotal > 0 ? calculatedSubtotal : widget.total;

      if (_selectedAddressId == null && addresses.isNotEmpty) {
        final defaultAddress = addresses.firstWhere(
          (a) =>
              a['is_default'] == 1 ||
              a['is_default'] == '1' ||
              a['is_default'] == true,
          orElse: () => addresses.first,
        );
        _selectedAddressId = int.tryParse(
          defaultAddress['address_id'].toString(),
        );
      }
      _isLoading = false;
    });
  }

  Future<void> _addAddress() async {
    final saved = await showAddressFormSheet(context, userId: widget.userId);
    if (saved == true) _loadData();
  }

  void _showAddressSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'เลือกที่อยู่จัดส่ง',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              const Divider(height: 1),
              if (_addresses.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Text('ยังไม่มีที่อยู่จัดส่ง'),
                )
              else
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _addresses.length,
                    itemBuilder: (context, index) {
                      final a = _addresses[index];
                      final id = int.tryParse(a['address_id'].toString());
                      return ListTile(
                        leading: Icon(
                          id == _selectedAddressId
                              ? Icons.radio_button_checked
                              : Icons.radio_button_off,
                          color: id == _selectedAddressId
                              ? Colors.blue.shade700
                              : Colors.grey,
                        ),
                        title: Text(a['recipient_name']?.toString() ?? ''),
                        subtitle: Text(_addressLine(a)),
                        onTap: () {
                          setState(() => _selectedAddressId = id);
                          Navigator.pop(context);
                        },
                      );
                    },
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: OutlinedButton.icon(
                  onPressed: () async {
                    Navigator.pop(context);
                    await _addAddress();
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('เพิ่มที่อยู่ใหม่'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.blue.shade700,
                    side: BorderSide(color: Colors.blue.shade700),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _confirmOrder() async {
    if (_selectedAddressId == null) {
      showAppSnackBar(context, 'กรุณาเลือกที่อยู่จัดส่ง', isError: true);
      return;
    }

    setState(() {
      _isSubmitting = true;
      _submitError = null;
    });

    Map<String, dynamic> result;
    try {
      result = await ApiClient.createOrder(
        userId: widget.userId,
        addressId: _selectedAddressId!,
        paymentMethod: _paymentMethod,
        cartIds: widget.cartIds,
        productId: widget.productId,
        quantity: widget.quantity,
        variantId: widget.variantId,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _submitError = 'เชื่อมต่อระบบไม่สำเร็จ กรุณาลองใหม่อีกครั้ง';
      });
      return;
    }

    if (!mounted) return;

    setState(() {
      _isSubmitting = false;
    });

    if (result['success'] != true) {
      setState(() {
        _submitError =
            result['message']?.toString() ?? 'สร้างคำสั่งซื้อไม่สำเร็จ';
      });
      return;
    }

    final data = result['data'];

    final orderId = int.tryParse(data?['order_id']?.toString() ?? '') ?? 0;
    final paymentId = int.tryParse(data?['payment_id']?.toString() ?? '') ?? 0;
    final totalAmount =
        double.tryParse(data?['total_amount']?.toString() ?? '') ?? _subtotal;

    final paymentMethod =
        data?['payment_method']?.toString().trim().isNotEmpty == true
        ? data['payment_method'].toString()
        : _paymentMethod;

    if (orderId <= 0) {
      showAppSnackBar(context, 'ไม่พบรหัสคำสั่งซื้อ', isError: true);
      return;
    }

    if (paymentMethod == 'qr') {
      if (paymentId <= 0) {
        showAppSnackBar(context, 'ไม่พบข้อมูลการชำระเงิน', isError: true);
        return;
      }

      // paymentConfirmed == true  -> กดยืนยัน "ชำระเงินแล้ว" ใน PaymentPage
      // paymentConfirmed != true  -> กดย้อนกลับ/เปลี่ยนช่องทางชำระเงิน (ยกเลิก)
      final paymentConfirmed = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => PaymentPage(
            userId: widget.userId,
            paymentId: paymentId,
            orderId: orderId,
            amount: totalAmount,
          ),
        ),
      );

      if (!mounted) return;

      if (paymentConfirmed == true) {
        // ยืนยันชำระเงินสำเร็จ -> ไปหน้าสำเร็จ แทนที่หน้า checkout
        // (route ของ checkout page ยังอยู่ตอนนี้ ไม่ได้ถูกทำลายไปก่อน
        // เหมือนที่ PaymentPage เคยทำด้วย pushAndRemoveUntil)
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => OrderSuccessPage(
              userId: widget.userId,
              orderId: orderId,
              paymentId: paymentId,
              totalAmount: totalAmount,
              paymentMethod: paymentMethod,
            ),
          ),
        );
        return;
      }

      // ยกเลิก/ย้อนกลับจากหน้าชำระเงิน -> ปิดหน้า checkout กลับไปก่อนหน้า
      Navigator.pop(context, true);
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => OrderSuccessPage(
          userId: widget.userId,
          orderId: orderId,
          paymentId: paymentId,
          totalAmount: totalAmount,
          paymentMethod: paymentMethod,
        ),
      ),
    );
  }

  String _addressLine(Map<String, dynamic> a) {
    final parts = [
      a['address_detail'],
      a['subdistrict'],
      a['district'],
      a['province'],
      a['postal_code'],
    ].where((e) => e != null && e.toString().trim().isNotEmpty);
    return parts.join(' ');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primaryDark,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'ชำระเงิน',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const LoadingView()
          : SingleChildScrollView(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildAddressCard(),
                  _buildProductCard(),
                  _buildShippingCard(),
                  _buildPaymentMethods(),
                  _buildSummary(),
                ],
              ),
            ),
      bottomNavigationBar: _isLoading
          ? null
          : SafeArea(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
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
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_submitError != null) ...[
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF0EF),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.error_outline,
                              color: Colors.red,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _submitError!,
                                style: const TextStyle(
                                  color: Color(0xFFB42318),
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              constraints: const BoxConstraints(),
                              padding: EdgeInsets.zero,
                              onPressed: () =>
                                  setState(() => _submitError = null),
                              icon: const Icon(
                                Icons.close,
                                color: Color(0xFFB42318),
                                size: 18,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'ยอดชำระสุทธิ',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                              Text(
                                '฿${_subtotal.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue.shade700,
                                  height: 1.1,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(
                          width: 140,
                          height: 44,
                          child: ElevatedButton(
                            onPressed: _addresses.isEmpty || _isSubmitting
                                ? null
                                : _confirmOrder,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue.shade600,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: _isSubmitting
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        'สั่งซื้อ\nสินค้า',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          height: 1.1,
                                        ),
                                      ),
                                      SizedBox(width: 6),
                                      Icon(Icons.arrow_forward, size: 18),
                                    ],
                                  ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.security,
                          color: Colors.green,
                          size: 12,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'รับประกันความปลอดภัยโดย 2PS Shop 100%',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildAddressCard() {
    Map<String, dynamic>? selectedAddress;
    if (_selectedAddressId != null) {
      try {
        selectedAddress = _addresses.firstWhere(
          (a) => int.tryParse(a['address_id'].toString()) == _selectedAddressId,
        );
      } catch (_) {}
    }

    return GestureDetector(
      onTap: _showAddressSelector,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            // แถบเส้นไล่สีด้านบน (Gradient line)
            Container(
              height: 4,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue, Colors.pinkAccent],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: selectedAddress == null
                  ? const Row(
                      children: [
                        Icon(Icons.location_on_outlined, color: Colors.grey),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'กรุณาเลือก/เพิ่มที่อยู่จัดส่ง',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                        Icon(Icons.chevron_right, color: Colors.grey),
                      ],
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.blue.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.location_on_outlined,
                            color: Colors.blue.shade700,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'ที่อยู่สำหรับจัดส่ง',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'คุณ${selectedAddress['recipient_name']} (${selectedAddress['address_phone']})',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: Color(0xFF202735),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _addressLine(selectedAddress),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF596170),
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right,
                          color: Colors.grey,
                          size: 20,
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductCard() {
    final shopGroups = _itemsBySeller.values.toList();
    if (shopGroups.isEmpty) return const SizedBox.shrink();

    return Column(
      children: shopGroups.map(_buildShopCard).toList(),
    );
  }

  Widget _buildShopCard(List<Map<String, dynamic>> shopItems) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // หัวร้านค้า
          Padding(
            padding: const EdgeInsets.all(14).copyWith(bottom: 10),
            child: Row(
              children: [
                Icon(Icons.storefront, size: 18, color: Colors.blue.shade700),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _sellerLabel(shopItems),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Color(0xFF202735),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'พร้อมส่ง\nทันที',
                    style: TextStyle(
                      color: Colors.green,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF0F1F4)),
          // รายการสินค้า
          ...shopItems.map((item) {
            final name = item['product_name']?.toString() ?? 'ไม่มีชื่อสินค้า';
            final price =
                double.tryParse(item['product_price']?.toString() ?? '0') ?? 0;
            final qty =
                int.tryParse(
                  item['cart_quantity']?.toString() ??
                      widget.quantity?.toString() ??
                      '1',
                ) ??
                1;
            final imageUrl = pickProductImage(item);

            return Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: ProductThumb(imageUrl: imageUrl),
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
                            fontSize: 13,
                            color: Color(0xFF202735),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if ((item['variant_size']?.toString().isNotEmpty ??
                                false) ||
                            (item['variant_color']?.toString().isNotEmpty ??
                                false)) ...[
                          const SizedBox(height: 6),
                          Text(
                            [
                              if (item['variant_color']
                                      ?.toString()
                                      .isNotEmpty ??
                                  false)
                                'สี ${item['variant_color']}',
                              if (item['variant_size']?.toString().isNotEmpty ??
                                  false)
                                'ไซส์ ${item['variant_size']}',
                            ].join(' · '),
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF596170),
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '฿${price.toStringAsFixed(2)}',
                              style: TextStyle(
                                color: Colors.blue.shade700,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              'จำนวน: $qty ชิ้น',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildShippingCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.local_shipping_outlined,
              color: Colors.blue.shade700,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'การจัดส่งด่วนพิเศษ (Express Delivery)',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF202735),
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'คาดการณ์จัดส่งภายใน 1-2 วันทำการ',
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.green),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'ฟรีค่าจัดส่ง',
              style: TextStyle(
                color: Colors.green,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethods() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 12, top: 4),
          child: Text(
            'วิธีการชำระเงิน',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: Color(0xFF202735),
            ),
          ),
        ),
        _buildPaymentOption(
          id: 'qr',
          title: 'สแกนจ่ายผ่าน QR พร้อมเพย์',
          subtitle: 'PromptPay QR - สะดวก รวดเร็ว ไม่มีค่าธรรมเนียม',
          icon: Icons.qr_code_2,
        ),
        const SizedBox(height: 10),
        _buildPaymentOption(
          id: 'cod',
          title: 'เก็บเงินปลายทาง (COD)',
          subtitle: 'ชำระเงินเมื่อได้รับสินค้า',
          icon: Icons.payments_outlined,
        ),
      ],
    );
  }

  Widget _buildPaymentOption({
    required String id,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final selected = _paymentMethod == id;
    return GestureDetector(
      onTap: () => setState(() => _paymentMethod = id),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? Colors.blue.shade600 : Colors.grey.shade200,
            width: selected ? 1.5 : 1,
          ),
          boxShadow: [
            if (!selected)
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: Row(
          children: [
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: selected ? Colors.blue.shade600 : Colors.grey.shade300,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                      fontSize: 13,
                      color: const Color(0xFF202735),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
            ),
            if (selected)
              Icon(Icons.check_circle, color: Colors.blue.shade600, size: 20)
            else
              Icon(icon, color: Colors.grey.shade400, size: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSummary() {
    return Container(
      margin: const EdgeInsets.only(top: 20, bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'ยอดรวมค่าสินค้า',
                style: TextStyle(color: Color(0xFF596170), fontSize: 13),
              ),
              Text(
                '฿${_subtotal.toStringAsFixed(2)}',
                style: const TextStyle(color: Color(0xFF202735), fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'ค่าจัดส่ง',
                style: TextStyle(color: Color(0xFF596170), fontSize: 13),
              ),
              Text(
                '฿${_shippingFee.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 13,
                  decoration: TextDecoration.lineThrough,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: const [
                  Icon(
                    Icons.local_offer_outlined,
                    color: Colors.green,
                    size: 14,
                  ),
                  SizedBox(width: 4),
                  Text(
                    'ส่วนลดค่าส่ง',
                    style: TextStyle(color: Colors.green, fontSize: 13),
                  ),
                ],
              ),
              Text(
                '-฿${_shippingDiscount.abs().toStringAsFixed(2)}',
                style: const TextStyle(color: Colors.green, fontSize: 13),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Divider(height: 1, color: Color(0xFFF0F1F4)),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text(
                'ยอดชำระสุทธิ',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Color(0xFF202735),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '฿${_subtotal.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                      color: Colors.blue.shade700,
                      height: 1.1,
                    ),
                  ),
                  const Text(
                    '(รวมภาษีมูลค่าเพิ่มแล้ว)',
                    style: TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
