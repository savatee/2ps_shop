import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/product_thumb.dart';
import '../../core/network/api_client.dart';
import 'buyer_checkout_page.dart';
import '../chat/chat_room_page.dart';
import 'order_success_page.dart';

class BuyerOrderDetailPage extends StatefulWidget {
  final int orderId;
  final int userId;

  const BuyerOrderDetailPage({
    super.key,
    required this.orderId,
    required this.userId,
  });

  @override
  State<BuyerOrderDetailPage> createState() => _BuyerOrderDetailPageState();
}

class _BuyerOrderDetailPageState extends State<BuyerOrderDetailPage> {
  bool isLoading = true;
  bool isCancelling = false;
  bool isBuyingAgain = false;
  String? loadError;

  Map<String, dynamic> order = {};

  List<dynamic> items = [];

  /// หน้าที่: เตรียมสถานะเริ่มต้นของหน้าจอและเริ่มโหลดข้อมูลที่จำเป็น (คลาส _BuyerOrderDetailPageState).
  @override
  void initState() {
    super.initState();
    loadOrderDetail();
  }

  // =========================================================
  // โหลดรายละเอียดคำสั่งซื้อ
  // =========================================================

  Future<void> loadOrderDetail() async {
    setState(() {
      isLoading = true;
      loadError = null;
    });

    try {
      final result = await ApiClient.getOrderDetail(
        widget.orderId,
        userId: widget.userId,
      );

      if (!mounted) return;

      if (result['success'] == true) {
        final data = result['data'];

        if (data is Map) {
          order = Map<String, dynamic>.from(data);

          final detailItems = data['items'] ?? data['order_items'] ?? [];

          items = detailItems is List
              ? detailItems
                    .whereType<Map>()
                    .map((item) => Map<String, dynamic>.from(item))
                    .toList()
              : [];
        } else {
          order = {};
          items = [];
          loadError = 'รูปแบบรายละเอียดคำสั่งซื้อไม่ถูกต้อง';
        }
      } else {
        order = {};
        items = [];
        loadError =
            result['message']?.toString() ??
            'ไม่สามารถโหลดรายละเอียดคำสั่งซื้อได้';
      }

      setState(() {
        isLoading = false;
      });
    } catch (e) {
      debugPrint('Load order detail error: $e');

      if (!mounted) return;

      setState(() {
        isLoading = false;
        loadError = 'เชื่อมต่อข้อมูลคำสั่งซื้อไม่ได้ กรุณาลองอีกครั้ง';
      });
    }
  }

  Map<String, dynamic> get payment {
    if (order['payment'] is Map) {
      return Map<String, dynamic>.from(order['payment']);
    }
    return order;
  }

  String get paymentMethod {
    return (payment['payment_method'] ?? '').toString().toLowerCase();
  }

  String get paymentStatus {
    return (payment['payment_status'] ?? '').toString().toLowerCase();
  }

  bool get isTransferPayment {
    return const {'qr', 'transfer', 'bank_transfer'}.contains(paymentMethod);
  }

  bool get isPaymentPaid {
    return const {'paid', 'completed'}.contains(paymentStatus);
  }

  bool get canPayByQr {
    return isTransferPayment &&
        !isPaymentPaid &&
        paymentStatus != 'submitted' &&
        paymentId != null;
  }

  int? get paymentId {
    return int.tryParse(payment['payment_id']?.toString() ?? '');
  }

  String get paymentMethodLabel {
    if (paymentMethod == 'cod') return 'เก็บเงินปลายทาง';
    if (isTransferPayment) return 'โอนเงิน (QR/ธนาคาร)';
    return payment['payment_method']?.toString() ?? '-';
  }

  String get paymentStatusLabel {
    if (isPaymentPaid) return 'ชำระเงินแล้ว';
    if (isTransferPayment) return 'รอตรวจสอบยอดโอน';
    return payment['payment_status']?.toString() ?? '-';
  }

  bool get isAwaitingPayment {
    final orderStatus = (order['order_status'] ?? order['status'] ?? '')
        .toString()
        .toLowerCase();
    return isTransferPayment &&
        !isPaymentPaid &&
        paymentStatus != 'submitted' &&
        !orderStatus.contains('cancel');
  }

  bool get canCancelOrder =>
      (order['order_status'] ?? '').toString().toLowerCase() == 'pending';

  /// หน้าที่: เปิดหรือแสดงหน้าต่าง/ส่วน UI สำหรับ open ผู้ขาย แชท (คลาส _BuyerOrderDetailPageState).
  void openSellerChat() {
    final sellerId = int.tryParse(
      (items.isNotEmpty
                  ? items.first['item_seller_id'] ??
                        items.first['product_seller_id'] ??
                        items.first['seller_id']
                  : null)
              ?.toString() ??
          order['seller_id']?.toString() ??
          order['order_seller_id']?.toString() ??
          '',
    );

    if (sellerId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('ไม่พบข้อมูลร้านค้า')));
      return;
    }
    if (sellerId == widget.userId) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('นี่คือร้านค้าของคุณเอง')));
      return;
    }

    final sellerName =
        (order['shop_name'] ??
                order['seller_name'] ??
                (items.isNotEmpty ? items.first['seller_name'] : null))
            ?.toString()
            .trim();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatRoomPage(
          postId: 0,
          buyerId: widget.userId,
          sellerId: sellerId,
          sellerName: sellerName == null || sellerName.isEmpty
              ? 'ร้านค้า'
              : sellerName,
        ),
      ),
    );
  }

  /// หน้าที่: ยกเลิกรายการ cancel คำสั่งซื้อ และอัปเดตสถานะหลัง API ยืนยัน (คลาส _BuyerOrderDetailPageState).
  Future<void> cancelOrder() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ยกเลิกคำสั่งซื้อ'),
        content: const Text('ต้องการยกเลิกคำสั่งซื้อนี้หรือไม่?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('กลับ'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('ยืนยันยกเลิก'),
          ),
        ],
      ),
    );

    if (confirmed != true || isCancelling) return;

    setState(() => isCancelling = true);
    final result = await ApiClient.cancelOrder(
      orderId: widget.orderId,
      userId: widget.userId,
    );
    if (!mounted) return;

    setState(() => isCancelling = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result['message']?.toString() ?? 'ไม่สามารถยกเลิกคำสั่งซื้อได้',
        ),
      ),
    );

    if (result['success'] == true) {
      await loadOrderDetail();
    }
  }

  // =========================================================
  // ซื้ออีกครั้ง -> ใส่สินค้าทุกชิ้นในออเดอร์นี้กลับเข้าตะกร้า
  // แล้วพาไปหน้าชำระเงิน (checkout) ทันที
  // =========================================================

  int? _itemProductId(dynamic item) {
    final value = item['item_product_id'] ?? item['product_id'];
    return int.tryParse(value?.toString() ?? '');
  }

  int? _itemVariantId(dynamic item) {
    final value = item['item_variant_id'] ?? item['variant_id'];
    final id = int.tryParse(value?.toString() ?? '');
    return (id != null && id > 0) ? id : null;
  }

  /// หน้าที่: ประมวลผลขั้นตอน buy Again สำหรับส่วน buyer order detail page (คลาส _BuyerOrderDetailPageState).
  Future<void> buyAgain() async {
    if (isBuyingAgain || items.isEmpty) return;

    setState(() => isBuyingAgain = true);

    final failedNames = <String>[];
    final addedKeys = <String>{}; // "productId:variantId" ที่เพิ่มสำเร็จ

    for (final item in items) {
      final productId = _itemProductId(item);
      if (productId == null) continue;

      final variantId = _itemVariantId(item);

      final result = await ApiClient.addToCart(
        userId: widget.userId,
        productId: productId,
        quantity: quantity(item),
        variantId: variantId,
      );

      if (result['success'] == true) {
        addedKeys.add('$productId:${variantId ?? 0}');
      } else {
        failedNames.add(productName(item));
      }
    }

    if (!mounted) return;

    if (addedKeys.isEmpty) {
      setState(() => isBuyingAgain = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'ไม่สามารถเพิ่มสินค้ากลับเข้าตะกร้าได้ สินค้าอาจถูกปิดการขายหรือหมดสต็อก',
          ),
        ),
      );
      return;
    }

    // หา cart_id ของรายการที่เพิ่งเพิ่มกลับเข้าตะกร้า
    final cartList = await ApiClient.getCart(widget.userId);
    final matchedCartIds = <int>[];
    double total = 0;

    for (final row in cartList) {
      if (row is! Map) continue;
      final productId = int.tryParse(row['cart_product_id']?.toString() ?? '');
      final variantId =
          int.tryParse(row['cart_variant_id']?.toString() ?? '') ?? 0;
      if (productId == null) continue;

      final key = '$productId:$variantId';
      if (!addedKeys.contains(key)) continue;

      final cartId = int.tryParse(row['cart_id']?.toString() ?? '');
      if (cartId == null) continue;

      matchedCartIds.add(cartId);
      final price =
          double.tryParse(row['product_price']?.toString() ?? '0') ?? 0;
      final qty = int.tryParse(row['cart_quantity']?.toString() ?? '1') ?? 1;
      total += price * qty;
    }

    if (!mounted) return;
    setState(() => isBuyingAgain = false);

    if (matchedCartIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ไม่พบสินค้าในตะกร้า กรุณาลองใหม่อีกครั้ง'),
        ),
      );
      return;
    }

    if (failedNames.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'สินค้าต่อไปนี้ไม่สามารถซื้อซ้ำได้: ${failedNames.join(", ")}',
          ),
        ),
      );
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BuyerCheckoutPage(
          userId: widget.userId,
          total: total,
          cartIds: matchedCartIds,
        ),
      ),
    );
  }

  // =========================================================
  // STATUS
  // =========================================================

  String getStatus() {
    if (isAwaitingPayment) {
      return 'รอชำระเงิน';
    }

    if (isTransferPayment && paymentStatus == 'submitted') {
      return 'รอตรวจสอบการโอน';
    }

    final value =
        (order['status'] ??
                order['order_status'] ??
                order['status_order'] ??
                '')
            .toString()
            .toLowerCase();

    if (value.contains('cancel') || value.contains('ยกเลิก')) {
      return 'ยกเลิก';
    }

    if (value.contains('complete') ||
        value.contains('completed') ||
        value.contains('success') ||
        value.contains('delivered') ||
        value.contains('สำเร็จ')) {
      return 'จัดส่งสำเร็จแล้ว';
    }

    if (value.contains('shipping') ||
        value.contains('shipped') ||
        value.contains('delivery') ||
        value.contains('จัดส่ง')) {
      return 'กำลังจัดส่ง';
    }

    return 'กำลังเตรียมสินค้า';
  }

  // =========================================================
  // วันที่
  // =========================================================

  String getDate(String key) {
    final value = order[key];

    if (value == null) {
      return '-';
    }

    try {
      final date = DateTime.parse(value.toString());

      return '${date.day.toString().padLeft(2, '0')} '
          '${thaiMonth(date.month)} '
          '${date.year + 543}';
    } catch (e) {
      return value.toString();
    }
  }

  /// หน้าที่: อ่านหรือคำนวณค่า get Time จากข้อมูลปัจจุบัน (คลาส _BuyerOrderDetailPageState).
  String getTime(String key) {
    final value = order[key];

    if (value == null) {
      return '-';
    }

    try {
      final date = DateTime.parse(value.toString());

      return '${date.hour.toString().padLeft(2, '0')}:'
          '${date.minute.toString().padLeft(2, '0')} น.';
    } catch (e) {
      return '';
    }
  }

  /// หน้าที่: ประมวลผลขั้นตอน ไทย Month สำหรับส่วน buyer order detail page (คลาส _BuyerOrderDetailPageState).
  String thaiMonth(int month) {
    const months = [
      'ม.ค.',
      'ก.พ.',
      'มี.ค.',
      'เม.ย.',
      'พ.ค.',
      'มิ.ย.',
      'ก.ค.',
      'ส.ค.',
      'ก.ย.',
      'ต.ค.',
      'พ.ย.',
      'ธ.ค.',
    ];

    return months[month - 1];
  }

  // =========================================================
  // ราคา
  // =========================================================

  double getTotal() {
    final value =
        order['total_amount'] ??
        order['total_price'] ??
        order['grand_total'] ??
        order['total'] ??
        0;

    return double.tryParse(value.toString()) ?? 0;
  }

  /// หน้าที่: อ่านหรือคำนวณค่า get Subtotal จากข้อมูลปัจจุบัน (คลาส _BuyerOrderDetailPageState).
  double getSubtotal() {
    final value =
        order['subtotal'] ??
        order['sub_total'] ??
        order['product_total'] ??
        getTotal();

    return double.tryParse(value.toString()) ?? 0;
  }

  // =========================================================
  // ที่อยู่
  // =========================================================

  Map<String, dynamic> get address {
    if (order['shipping_address'] is Map) {
      return Map<String, dynamic>.from(order['shipping_address']);
    }

    if (order['address'] is Map) {
      return Map<String, dynamic>.from(order['address']);
    }

    return order;
  }

  /// หน้าที่: ประมวลผลขั้นตอน ที่อยู่จัดส่ง Value สำหรับส่วน buyer order detail page (คลาส _BuyerOrderDetailPageState).
  String addressValue(List<String> keys) {
    for (final key in keys) {
      final value = address[key];

      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString();
      }
    }

    return '';
  }

  // =========================================================
  // ชื่อสินค้า
  // =========================================================

  String productName(dynamic item) {
    return (item['product_name'] ??
            item['name'] ??
            item['productName'] ??
            'สินค้า')
        .toString();
  }

  // =========================================================
  // จำนวน
  // =========================================================

  int quantity(dynamic item) {
    final value = item['item_quantity'] ?? item['quantity'] ?? item['qty'] ?? 1;

    return int.tryParse(value.toString()) ?? 1;
  }

  // =========================================================
  // ราคาแต่ละสินค้า
  // =========================================================

  double itemPrice(dynamic item) {
    final value =
        item['item_price'] ??
        item['price'] ??
        item['product_price'] ??
        item['unit_price'] ??
        0;

    return double.tryParse(value.toString()) ?? 0;
  }

  // =========================================================
  // รูปสินค้า
  // =========================================================

  String imageUrl(dynamic item) {
    return (item['product_image'] ??
            item['image_data'] ??
            item['image_url'] ??
            item['image'] ??
            item['product_image_url'] ??
            '')
        .toString();
  }

  /// หน้าที่: ประมวลผลขั้นตอน สินค้า รูปภาพ สำหรับส่วน buyer order detail page (คลาส _BuyerOrderDetailPageState).
  Widget productImage(dynamic item) {
    final image = imageUrl(item);

    if (image.isEmpty) {
      return Container(
        color: const Color(0xFFF2F4F7),
        child: const Icon(
          Icons.image_outlined,
          color: Color(0xFFB4BBC5),
          size: 30,
        ),
      );
    }

    return ProductThumb(imageUrl: image, iconSize: 30);
  }

  // =========================================================
  // BUILD
  // =========================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,

      appBar: AppBar(
        backgroundColor: AppColors.primaryDark,

        elevation: 0,

        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),

          onPressed: () {
            Navigator.pop(context);
          },
        ),

        title: const Text(
          'รายละเอียดคำสั่งซื้อ',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),

        centerTitle: true,
      ),

      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : loadError != null
          ? buildError()
          : order.isEmpty
          ? buildError()
          : buildDetail(),
    );
  }

  // =========================================================
  // ERROR
  // =========================================================

  Widget buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,

        children: [
          const Icon(Icons.error_outline, size: 60, color: Colors.grey),

          const SizedBox(height: 12),

          Text(
            loadError ?? 'ไม่พบรายละเอียดคำสั่งซื้อ',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 15),

          ElevatedButton(
            onPressed: loadOrderDetail,

            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),

            child: const Text('ลองใหม่'),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // DETAIL
  // =========================================================

  Widget buildDetail() {
    final status = getStatus();

    final total = getTotal();

    final subtotal = getSubtotal();

    return RefreshIndicator(
      color: AppColors.primary,

      onRefresh: loadOrderDetail,

      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),

        padding: const EdgeInsets.only(top: 8, bottom: 25),

        child: Column(
          children: [
            // =============================================
            // STATUS
            // =============================================
            buildStatusCard(status),

            // =============================================
            // ADDRESS
            // =============================================
            buildAddressCard(),

            // =============================================
            // SHOP + PRODUCTS
            // =============================================
            buildProductCard(),

            // =============================================
            // PAYMENT
            // =============================================
            buildPaymentCard(subtotal, total),

            // =============================================
            // ORDER INFORMATION
            // =============================================
            buildOrderInfo(),

            // =============================================
            // BUTTON
            // =============================================
            buildBottomButtons(),
          ],
        ),
      ),
    );
  }

  // =========================================================
  // STATUS CARD
  // =========================================================

  Widget buildStatusCard(String status) {
    final success = status == 'จัดส่งสำเร็จแล้ว';

    final cancelled = status == 'ยกเลิก';

    final awaiting = status == 'รอชำระเงิน';

    Color color;

    IconData icon;

    if (success) {
      color = const Color(0xFF20A66A);

      icon = Icons.check_circle;
    } else if (cancelled) {
      color = const Color(0xFFE65C67);

      icon = Icons.cancel;
    } else if (awaiting) {
      color = const Color(0xFFE07A00);

      icon = Icons.account_balance_outlined;
    } else {
      color = const Color(0xFF2878C8);

      icon = Icons.local_shipping;
    }

    return Container(
      width: double.infinity,

      margin: const EdgeInsets.fromLTRB(8, 8, 8, 8),

      padding: const EdgeInsets.all(16),

      decoration: BoxDecoration(
        color: Colors.white,

        borderRadius: BorderRadius.circular(14),

        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),

      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,

            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),

              shape: BoxShape.circle,
            ),

            child: Icon(icon, color: color, size: 24),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                Text(
                  status,

                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),

                const SizedBox(height: 3),

                Text(
                  'คำสั่งซื้อ #${widget.orderId}',

                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF888888),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // ADDRESS CARD
  // =========================================================

  Widget buildAddressCard() {
    final name = addressValue([
      'recipient_name',
      'receiver_name',
      'name',
      'full_name',
    ]);

    final phone = addressValue([
      'address_phone',
      'phone',
      'recipient_phone',
      'receiver_phone',
    ]);

    final details = addressValue(['details', 'address', 'address_detail']);

    final subdistrict = addressValue(['subdistrict', 'sub_district', 'tambon']);

    final district = addressValue(['district', 'amphoe']);

    final province = addressValue(['province']);

    final postalCode = addressValue(['postal_code', 'zipcode', 'zip_code']);

    final fullAddress = [
      details,
      subdistrict.isNotEmpty ? 'ต.$subdistrict' : '',
      district.isNotEmpty ? 'อ.$district' : '',
      province,
      postalCode,
    ].where((e) => e.isNotEmpty).join(' ');

    return whiteCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          sectionTitle(Icons.location_on_outlined, 'ที่อยู่สำหรับจัดส่ง'),

          const SizedBox(height: 12),

          if (name.isNotEmpty)
            Text(
              name,

              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),

          if (phone.isNotEmpty) ...[
            const SizedBox(height: 3),

            Text(
              phone,

              style: const TextStyle(fontSize: 12, color: Color(0xFF777777)),
            ),
          ],

          if (fullAddress.isNotEmpty) ...[
            const SizedBox(height: 5),

            Text(
              fullAddress,

              style: const TextStyle(
                fontSize: 12,
                height: 1.5,
                color: Color(0xFF555555),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // =========================================================
  // PRODUCT CARD
  // =========================================================

  Widget buildProductCard() {
    return whiteCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Row(
            children: [
              const Icon(
                Icons.storefront_outlined,
                size: 19,
                color: AppColors.primary,
              ),

              const SizedBox(width: 7),

              Expanded(
                child: Text(
                  order['shop_name'] ??
                      order['seller_name'] ??
                      '2PS Shop Official',

                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              const Icon(
                Icons.chevron_right,
                size: 20,
                color: Color(0xFF999999),
              ),
            ],
          ),

          const SizedBox(height: 12),

          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 15),

              child: Center(
                child: Text(
                  'ไม่พบรายการสินค้า',
                  style: TextStyle(color: Color(0xFF888888)),
                ),
              ),
            )
          else
            ...items.map((item) {
              return buildProductItem(item);
            }),
        ],
      ),
    );
  }

  // =========================================================
  // PRODUCT ITEM
  // =========================================================

  Widget buildProductItem(dynamic item) {
    final name = productName(item);

    final qty = quantity(item);

    final price = itemPrice(item);
    final options = [
      if (item['item_color']?.toString().isNotEmpty ?? false)
        'สี ${item['item_color']}',
      if (item['item_size']?.toString().isNotEmpty ?? false)
        'ไซส์ ${item['item_size']}',
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),

      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Container(
            width: 68,
            height: 68,

            decoration: BoxDecoration(
              color: const Color(0xFFF2F4F7),

              borderRadius: BorderRadius.circular(10),
            ),

            clipBehavior: Clip.antiAlias,

            child: productImage(item),
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
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF333333),
                  ),
                ),

                if (options.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    options,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF747B88),
                    ),
                  ),
                ],

                const SizedBox(height: 5),

                Text(
                  'x$qty',

                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF999999),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 10),

          Text(
            '฿${(price * qty).toStringAsFixed(2)}',

            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // PAYMENT
  // =========================================================

  Future<void> openPayment() async {
    final id = paymentId;
    if (id == null) return;

    final amount =
        double.tryParse(payment['amount']?.toString() ?? '') ?? getTotal();

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OrderSuccessPage(
          userId: widget.userId,
          orderId: widget.orderId,
          paymentId: id,
          totalAmount: amount,
          paymentMethod: 'qr',
        ),
      ),
    );

    if (mounted) loadOrderDetail();
  }

  /// หน้าที่: สร้าง UI ส่วน Payment Card เพื่อใช้ในหน้าจอนี้ (คลาส _BuyerOrderDetailPageState).
  Widget buildPaymentCard(double subtotal, double total) {
    return whiteCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          sectionTitle(Icons.receipt_long_outlined, 'ข้อมูลการชำระเงิน'),

          const SizedBox(height: 14),

          priceRow('รวมค่าสินค้า', subtotal),

          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),

            child: Divider(height: 1),
          ),

          Row(
            children: [
              const Expanded(
                child: Text(
                  'ยอดชำระทั้งหมด',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),

              Text(
                '฿${total.toStringAsFixed(2)}',

                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),

            decoration: BoxDecoration(
              color: const Color(0xFFF4F6F8),

              borderRadius: BorderRadius.circular(8),
            ),

            child: Row(
              children: [
                const Icon(
                  Icons.account_balance_outlined,
                  size: 16,
                  color: Color(0xFF777777),
                ),

                const SizedBox(width: 7),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,

                    children: [
                      Text(
                        paymentMethodLabel,

                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF777777),
                        ),
                      ),

                      const SizedBox(height: 2),

                      Text(
                        paymentStatusLabel,

                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isPaymentPaid
                              ? const Color(0xFF20A66A)
                              : const Color(0xFFE07A00),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          if (canPayByQr) ...[
            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,

              child: ElevatedButton.icon(
                onPressed: openPayment,

                icon: const Icon(Icons.qr_code_2, size: 20),

                label: const Text('สแกน QR เพื่อชำระเงิน'),

                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,

                  foregroundColor: Colors.white,

                  padding: const EdgeInsets.symmetric(vertical: 14),

                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// หน้าที่: ประมวลผลขั้นตอน price Row สำหรับส่วน buyer order detail page (คลาส _BuyerOrderDetailPageState).
  Widget priceRow(String title, double price) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,

            style: const TextStyle(fontSize: 13, color: Color(0xFF666666)),
          ),
        ),

        Text(
          '฿${price.toStringAsFixed(2)}',

          style: const TextStyle(fontSize: 13, color: Color(0xFF555555)),
        ),
      ],
    );
  }

  // =========================================================
  // ORDER INFORMATION
  // =========================================================

  Widget buildOrderInfo() {
    final createdAt = getDate('created_at');

    final createdTime = getTime('created_at');

    final updatedAt = getDate('updated_at');

    final updatedTime = getTime('updated_at');

    return whiteCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          sectionTitle(Icons.info_outline, 'รายละเอียดคำสั่งซื้อ'),

          const SizedBox(height: 14),

          infoRow('หมายเลขคำสั่งซื้อ', '#${widget.orderId}'),

          if (createdAt != '-') ...[
            const SizedBox(height: 7),

            infoRow('วันที่สั่งซื้อ', '$createdAt $createdTime'),
          ],

          if (updatedAt != '-') ...[
            const SizedBox(height: 7),

            infoRow('อัปเดตล่าสุด', '$updatedAt $updatedTime'),
          ],
        ],
      ),
    );
  }

  /// หน้าที่: ประมวลผลขั้นตอน info Row สำหรับส่วน buyer order detail page (คลาส _BuyerOrderDetailPageState).
  Widget infoRow(String title, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,

      children: [
        SizedBox(
          width: 115,

          child: Text(
            title,

            style: const TextStyle(fontSize: 12, color: Color(0xFF888888)),
          ),
        ),

        Expanded(
          child: Text(
            value,

            textAlign: TextAlign.right,

            style: const TextStyle(fontSize: 12, color: Color(0xFF444444)),
          ),
        ),
      ],
    );
  }

  // =========================================================
  // BOTTOM BUTTONS
  // =========================================================

  Widget buildBottomButtons() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: openSellerChat,
                  icon: const Icon(Icons.chat_bubble_outline, size: 17),
                  label: const Text('ติดต่อร้านค้า'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: Color(0xFFD7DDE6)),
                    backgroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: isBuyingAgain ? null : buyAgain,
                  icon: isBuyingAgain
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.refresh, size: 17),
                  label: const Text('ซื้ออีกครั้ง'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (canCancelOrder)
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 10, 8, 0),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: isCancelling ? null : cancelOrder,
                icon: isCancelling
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.cancel_outlined, size: 18),
                label: const Text('ยกเลิกคำสั่งซื้อ'),
              ),
            ),
          ),
      ],
    );
  }

  // =========================================================
  // WHITE CARD
  // =========================================================

  Widget whiteCard({required Widget child}) {
    return Container(
      width: double.infinity,

      margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),

      padding: const EdgeInsets.all(14),

      decoration: BoxDecoration(
        color: Colors.white,

        borderRadius: BorderRadius.circular(14),

        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),

            blurRadius: 8,

            offset: const Offset(0, 2),
          ),
        ],
      ),

      child: child,
    );
  }

  // =========================================================
  // SECTION TITLE
  // =========================================================

  Widget sectionTitle(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, size: 19, color: AppColors.primary),

        const SizedBox(width: 7),

        Text(
          title,

          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Color(0xFF333333),
          ),
        ),
      ],
    );
  }
}
