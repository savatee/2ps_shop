import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/product_thumb.dart';
import '../../core/network/api_client.dart';
import 'buyer_order_detail_page.dart';

class BuyerOrderPage extends StatefulWidget {
  final int userId;

  const BuyerOrderPage({super.key, required this.userId});

  @override
  State<BuyerOrderPage> createState() => _BuyerOrderPageState();
}

class _BuyerOrderPageState extends State<BuyerOrderPage> {
  int selectedTab = 0;
  bool isLoading = true;

  List<dynamic> orders = [];

  final List<String> tabs = [
    'ทั้งหมด',
    'รอชำระเงิน',
    'รอตรวจสอบ',
    'กำลังเตรียม',
    'อยู่ระหว่างจัดส่ง',
    'สำเร็จ',
    'ยกเลิก',
  ];

  @override
  void initState() {
    super.initState();
    loadOrders();
  }

  // =========================================================
  // โหลดคำสั่งซื้อ
  // =========================================================

  Future<void> loadOrders() async {
    setState(() {
      isLoading = true;
    });

    try {
      final result = await ApiClient.getOrders(widget.userId);

      if (!mounted) return;

      setState(() {
        orders = result;
        isLoading = false;
      });
    } catch (e) {
      debugPrint('โหลดคำสั่งซื้อผิดพลาด: $e');

      if (!mounted) return;

      setState(() {
        orders = [];
        isLoading = false;
      });
    }
  }

  // =========================================================
  // แปลงสถานะ
  // =========================================================

  bool isAwaitingPayment(dynamic order) {
    final method = (order['payment_method'] ?? '').toString().toLowerCase();
    final paymentStatus = (order['payment_status'] ?? '')
        .toString()
        .toLowerCase();
    final orderStatus = (order['order_status'] ?? order['status'] ?? '')
        .toString()
        .toLowerCase();

    const transferMethods = {'qr', 'transfer', 'bank_transfer'};
    const paidStatuses = {'paid', 'completed', 'refunded', 'submitted'};

    return transferMethods.contains(method) &&
        !paidStatuses.contains(paymentStatus) &&
        !orderStatus.contains('cancel');
  }

  String getStatus(dynamic order) {
    if (isAwaitingPayment(order)) {
      return 'รอชำระเงิน';
    }

    final orderStatus = (order['status'] ?? order['order_status'] ?? '')
        .toString()
        .toLowerCase();

    if (orderStatus.contains('cancel') || orderStatus.contains('ยกเลิก')) {
      return 'ยกเลิก';
    }

    if ((order['payment_status'] ?? '').toString().toLowerCase() ==
        'submitted') {
      return 'รอตรวจสอบ';
    }

    final value =
        (order['status'] ??
                order['order_status'] ??
                order['status_order'] ??
                '')
            .toString()
            .toLowerCase();

    if (value.contains('complete') ||
        value.contains('completed') ||
        value.contains('success') ||
        value.contains('delivered') ||
        value.contains('สำเร็จ')) {
      return 'สำเร็จ';
    }

    if (value.contains('shipping') ||
        value.contains('shipped') ||
        value.contains('delivery') ||
        value.contains('จัดส่ง')) {
      return 'อยู่ระหว่างจัดส่ง';
    }

    return 'กำลังเตรียม';
  }

  // =========================================================
  // กรองคำสั่งซื้อ
  // =========================================================

  List<dynamic> get filteredOrders {
    if (selectedTab == 0) {
      return orders;
    }

    final selectedStatus = tabs[selectedTab];

    return orders.where((order) {
      return getStatus(order) == selectedStatus;
    }).toList();
  }

  // =========================================================
  // Order ID
  // =========================================================

  int? getOrderId(dynamic order) {
    final value = order['order_id'] ?? order['id'] ?? order['orders_id'];

    return int.tryParse(value?.toString() ?? '');
  }

  // =========================================================
  // ยอดรวม
  // =========================================================

  double getTotal(dynamic order) {
    final value =
        order['total_amount'] ??
        order['total_price'] ??
        order['grand_total'] ??
        order['total'] ??
        0;

    return double.tryParse(value.toString()) ?? 0;
  }

  // =========================================================
  // จำนวนรายการ
  // =========================================================

  int getItemCount(dynamic order) {
    final value =
        order['item_count'] ?? order['total_items'] ?? order['quantity'] ?? 1;

    return int.tryParse(value.toString()) ?? 1;
  }

  // =========================================================
  // เปิดรายละเอียด
  // =========================================================

  Future<void> openOrder(dynamic order) async {
    final orderId = getOrderId(order);

    if (orderId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('ไม่พบหมายเลขคำสั่งซื้อ')));

      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            BuyerOrderDetailPage(orderId: orderId, userId: widget.userId),
      ),
    );

    loadOrders();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      // =====================================================
      // APP BAR
      // =====================================================
      appBar: AppBar(
        backgroundColor: AppColors.primaryDark,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,

        title: const Text(
          'คำสั่งซื้อ',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),

      body: Column(
        children: [
          // =================================================
          // TAB
          // =================================================
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12),

            child: SizedBox(
              height: 38,

              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 12),

                scrollDirection: Axis.horizontal,

                itemCount: tabs.length,

                separatorBuilder: (_, _) {
                  return const SizedBox(width: 8);
                },

                itemBuilder: (context, index) {
                  final selected = selectedTab == index;

                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        selectedTab = index;
                      });
                    },

                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),

                      padding: const EdgeInsets.symmetric(horizontal: 17),

                      alignment: Alignment.center,

                      decoration: BoxDecoration(
                        color: selected ? AppColors.primary : Colors.white,

                        borderRadius: BorderRadius.circular(20),

                        border: Border.all(
                          color: selected
                              ? AppColors.primary
                              : const Color(0xFFE2E8F0),
                        ),
                      ),

                      child: Text(
                        tabs[index],

                        style: TextStyle(
                          fontSize: 13,

                          color: selected
                              ? Colors.white
                              : const Color(0xFF64748B),

                          fontWeight: selected
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // =================================================
          // ORDER LIST
          // =================================================
          Expanded(
            child: RefreshIndicator(
              color: AppColors.primary,

              onRefresh: loadOrders,

              child: isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    )
                  : filteredOrders.isEmpty
                  ? buildEmpty()
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),

                      itemCount: filteredOrders.length,

                      itemBuilder: (context, index) {
                        final order = filteredOrders[index];

                        return OrderCard(
                          order: order,
                          status: getStatus(order),
                          orderId: getOrderId(order),
                          total: getTotal(order),
                          itemCount: getItemCount(order),
                          onTap: () {
                            openOrder(order);
                          },
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // ไม่มีคำสั่งซื้อ
  // =========================================================

  Widget buildEmpty() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),

      children: [
        const SizedBox(height: 100),

        Icon(
          Icons.receipt_long_outlined,
          size: 70,
          color: Colors.grey.shade300,
        ),

        const SizedBox(height: 15),

        const Center(
          child: Text(
            'ยังไม่มีคำสั่งซื้อ',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: Color(0xFF555555),
            ),
          ),
        ),

        const SizedBox(height: 6),

        const Center(
          child: Text(
            'คำสั่งซื้อของคุณจะแสดงที่นี่',
            style: TextStyle(fontSize: 13, color: Color(0xFF999999)),
          ),
        ),
      ],
    );
  }
}

// =============================================================
// ORDER CARD (ดีไซน์ใหม่)
// =============================================================

class OrderCard extends StatefulWidget {
  final dynamic order;
  final String status;
  final int? orderId;
  final double total;
  final int itemCount;
  final VoidCallback onTap;

  const OrderCard({
    super.key,
    required this.order,
    required this.status,
    required this.orderId,
    required this.total,
    required this.itemCount,
    required this.onTap,
  });

  @override
  State<OrderCard> createState() => _OrderCardState();
}

class _OrderCardState extends State<OrderCard> {
  String getProductName(dynamic item) {
    return (item['product_name'] ??
            item['name'] ??
            item['productName'] ??
            'สินค้า')
        .toString();
  }

  String getImage(dynamic item) {
    return (item['product_image'] ??
            item['image_url'] ??
            item['image'] ??
            item['product_image_url'] ??
            '')
        .toString();
  }

  int getQuantity(dynamic item) {
    final value = item['quantity'] ?? item['item_quantity'] ?? item['qty'] ?? 1;

    return int.tryParse(value.toString()) ?? 1;
  }

  Widget productImage(dynamic item) {
    return ProductThumb(imageUrl: getImage(item), iconSize: 24);
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.order['items'] is List ? widget.order['items'] : [];

    // ดึงไอเท็มแรกมาแสดงเป็นตัวแทนของออเดอร์นั้น
    final firstItem = items.isNotEmpty ? items.first : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),

      decoration: BoxDecoration(
        color: Colors.white,

        borderRadius: BorderRadius.circular(16),

        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),

            blurRadius: 10,

            offset: const Offset(0, 2),
          ),
        ],
      ),

      child: InkWell(
        borderRadius: BorderRadius.circular(16),

        onTap: widget.onTap,

        child: Padding(
          padding: const EdgeInsets.all(16),

          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ===========================================
              // ส่วนบน: รูปสินค้า + ชื่อสินค้า + จำนวน
              // ===========================================
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 64,
                    height: 64,

                    decoration: BoxDecoration(
                      color: const Color(
                        0xFFF1F5F9,
                      ), // สีเทาอ่อนเป็นพื้นหลังรูป

                      borderRadius: BorderRadius.circular(12),
                    ),

                    clipBehavior: Clip.antiAlias,

                    child: firstItem != null
                        ? productImage(firstItem)
                        : const Icon(
                            Icons.image_outlined,
                            color: Color(0xFF94A3B8),
                          ),
                  ),

                  const SizedBox(width: 12),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,

                      children: [
                        Text(
                          firstItem != null
                              ? getProductName(firstItem)
                              : 'ไม่พบรายละเอียดสินค้า',

                          maxLines: 2,

                          overflow: TextOverflow.ellipsis,

                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E293B),
                          ),
                        ),

                        const SizedBox(height: 6),

                        Text(
                          firstItem != null
                              ? 'จำนวน ${getQuantity(firstItem)} ชิ้น'
                              : '',

                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // ===========================================
              // ส่วนล่าง: หมายเลขออเดอร์ + จำนวนรายการ + ราคา + สถานะ
              // ===========================================
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,

                children: [
                  // ด้านซ้าย
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,

                      children: [
                        if (widget.orderId != null)
                          Text(
                            'คำสั่งซื้อ #${widget.orderId}',

                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF64748B),
                            ),
                          ),

                        const SizedBox(height: 4),

                        Text(
                          '${widget.itemCount} รายการ',

                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ด้านขวา
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,

                    children: [
                      Text(
                        '฿${widget.total.toStringAsFixed(2)}',

                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                          height: 1.1,
                        ),
                      ),

                      const SizedBox(height: 6),

                      statusBadge(widget.status),
                    ],
                  ),

                  const SizedBox(width: 8),

                  const Padding(
                    padding: EdgeInsets.only(bottom: 6),
                    child: Icon(
                      Icons.chevron_right,
                      color: Color(0xFF94A3B8),
                      size: 20,
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

  // =========================================================
  // STATUS BADGE (ป้ายสถานะ)
  // =========================================================

  Widget statusBadge(String status) {
    Color textColor;
    Color backgroundColor;
    Color borderColor;

    switch (status) {
      case 'สำเร็จ':
        textColor = const Color(0xFF10B981);
        backgroundColor = const Color(0xFFECFDF5);
        borderColor = const Color(0xFFA7F3D0);
        break;

      case 'ยกเลิก':
        textColor = const Color(0xFFEF4444);
        backgroundColor = const Color(0xFFFEF2F2);
        borderColor = const Color(0xFFFECACA);
        break;

      case 'อยู่ระหว่างจัดส่ง':
        textColor = const Color(0xFF3B82F6);
        backgroundColor = const Color(0xFFEFF6FF);
        borderColor = const Color(0xFFBFDBFE);
        break;

      case 'รอชำระเงิน':
      case 'รอตรวจสอบ':
        textColor = const Color(0xFFF59E0B);
        backgroundColor = const Color(0xFFFFFBEB);
        borderColor = const Color(0xFFFDE68A);
        break;

      default: // กำลังเตรียม
        textColor = const Color(0xFFF97316);
        backgroundColor = const Color(0xFFFFF7ED);
        borderColor = const Color(0xFFFFEDD5);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),

      decoration: BoxDecoration(
        color: backgroundColor,

        borderRadius: BorderRadius.circular(20),

        border: Border.all(color: borderColor),
      ),

      child: Text(
        status,

        style: TextStyle(
          fontSize: 11,
          color: textColor,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
