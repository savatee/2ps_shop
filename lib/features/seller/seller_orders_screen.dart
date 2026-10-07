import 'package:flutter/material.dart';

import 'seller_theme.dart';
import 'api/seller_api.dart';
import 'models/seller_models.dart';

class SellerOrdersScreen extends StatefulWidget {
  final int sellerId;

  const SellerOrdersScreen({super.key, required this.sellerId});

  @override
  State<SellerOrdersScreen> createState() => _SellerOrdersScreenState();
}

class _SellerOrdersScreenState extends State<SellerOrdersScreen> {
  bool loading = true;
  String? errorMessage;

  List<SellerOrder> orders = [];

  String selectedFilter = 'ทั้งหมด';

  final Set<int> updatingOrderIds = {};

  @override
  void initState() {
    super.initState();
    load();
  }

  // ============================================================
  // LOAD ORDERS
  // ============================================================

  Future<void> load() async {
    if (!mounted) return;

    setState(() {
      loading = true;
      errorMessage = null;
    });

    try {
      final data = await SellerApi.orders(widget.sellerId);

      final result = data
          .whereType<Map>()
          .map((e) => SellerOrder.fromJson(Map<String, dynamic>.from(e)))
          .toList();

      if (!mounted) return;

      setState(() {
        orders = result;
        loading = false;
      });
    } catch (e) {
      debugPrint('SELLER ORDERS ERROR: $e');

      if (!mounted) return;

      setState(() {
        loading = false;
        errorMessage = e.toString();
      });
    }
  }

  // ============================================================
  // NEXT STATUS
  // ============================================================

  String? getNextStatus(String currentStatus) {
    switch (currentStatus) {
      case 'pending':
        return 'paid';

      case 'paid':
        return 'processing';

      case 'processing':
        return 'shipping';

      case 'shipping':
        return 'completed';

      case 'completed':
      case 'cancelled':
        return null;

      default:
        return null;
    }
  }

  // ============================================================
  // NEXT STATUS BUTTON TEXT
  // ============================================================

  String nextStatusButtonText(String currentStatus) {
    switch (currentStatus) {
      case 'pending':
        return 'ยืนยันการชำระเงิน';

      case 'paid':
        return 'เริ่มดำเนินการ';

      case 'processing':
        return 'จัดส่งสินค้า';

      case 'shipping':
        return 'ยืนยันการจัดส่ง';

      default:
        return '';
    }
  }

  // ============================================================
  // UPDATE STATUS
  // ============================================================

  Future<void> changeStatus(SellerOrder order, String newStatus) async {
    final orderId = order.orderId;

    if (updatingOrderIds.contains(orderId)) {
      return;
    }

    setState(() {
      updatingOrderIds.add(orderId);
    });

    try {
      debugPrint(
        'CHANGE ORDER #$orderId '
        '${order.status} -> $newStatus',
      );

      final result = await SellerApi.updateOrderStatus(
        sellerId: widget.sellerId,
        orderId: orderId,
        status: newStatus,
      );

      if (!mounted) return;

      if (result['success'] != true) {
        throw Exception(
          result['message']?.toString() ?? 'ไม่สามารถเปลี่ยนสถานะได้',
        );
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SellerTheme.snackBar('คำสั่งซื้อ #$orderId → ${statusText(newStatus)}'),
      );

      await load();
    } catch (e) {
      debugPrint('CHANGE STATUS ERROR #$orderId: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SellerTheme.snackBar('เกิดข้อผิดพลาด: $e'));
    } finally {
      if (mounted) {
        setState(() {
          updatingOrderIds.remove(orderId);
        });
      }
    }
  }

  // ============================================================
  // IMAGE
  // ============================================================

  Widget buildProductImage(SellerOrder order) {
    String imageUrl = order.productImageUrl?.trim() ?? '';

    if (imageUrl.isEmpty) {
      final path = order.productImagePath?.trim() ?? '';

      if (path.isNotEmpty) {
        imageUrl = SellerApi.imageUrl(path) ?? '';
      }
    }

    if (imageUrl.isEmpty) {
      return SellerTheme.imagePlaceholder(
        width: 72,
        height: 72,
        icon: Icons.image_outlined,
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(SellerTheme.radiusMedium),
      child: Image.network(
        imageUrl,
        width: 72,
        height: 72,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) {
            return child;
          }

          return Container(
            width: 72,
            height: 72,
            decoration: SellerTheme.cardDecoration(
              color: SellerTheme.backgroundLight,
              radius: SellerTheme.radiusMedium,
              shadow: false,
            ),
            child: const Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: SellerTheme.navy,
                ),
              ),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          debugPrint(
            'ORDER IMAGE ERROR '
            '#${order.orderId}: $error',
          );

          return SellerTheme.imagePlaceholder(
            width: 72,
            height: 72,
            icon: Icons.broken_image_outlined,
          );
        },
      ),
    );
  }

  // ============================================================
  // FILTER
  // ============================================================

  List<SellerOrder> get filteredOrders {
    if (selectedFilter == 'ทั้งหมด') {
      return orders;
    }

    if (selectedFilter == 'รอดำเนินการ') {
      return orders.where((e) => e.status == 'pending').toList();
    }

    if (selectedFilter == 'ชำระเงินแล้ว') {
      return orders.where((e) => e.status == 'paid').toList();
    }

    if (selectedFilter == 'กำลังดำเนินการ') {
      return orders
          .where((e) => e.status == 'processing' || e.status == 'shipping')
          .toList();
    }

    if (selectedFilter == 'เสร็จสิ้น') {
      return orders.where((e) => e.status == 'completed').toList();
    }

    if (selectedFilter == 'ยกเลิก') {
      return orders.where((e) => e.status == 'cancelled').toList();
    }

    return orders;
  }

  // ============================================================
  // STATUS TEXT
  // ============================================================

  String statusText(String status) {
    switch (status) {
      case 'pending':
        return 'รอดำเนินการ';

      case 'paid':
        return 'ชำระเงินแล้ว';

      case 'processing':
        return 'กำลังดำเนินการ';

      case 'shipping':
        return 'กำลังจัดส่ง';

      case 'completed':
        return 'เสร็จสิ้น';

      case 'cancelled':
        return 'ยกเลิก';

      default:
        return status;
    }
  }

  // ============================================================
  // STATUS COLOR
  // ============================================================

  Color statusColor(String status) {
    return SellerTheme.statusColor(status);
  }

  // ============================================================
  // ACTION BUTTONS
  // ============================================================

  Widget buildActionButtons(SellerOrder order) {
    final isUpdating = updatingOrderIds.contains(order.orderId);

    final nextStatus = getNextStatus(order.status);

    if (nextStatus == null) {
      return const SizedBox.shrink();
    }

    final buttonText = nextStatusButtonText(order.status);

    return Row(
      children: [
        Expanded(
          flex: 1,
          child: SizedBox(
            height: 44,
            child: ElevatedButton(
              onPressed: isUpdating
                  ? null
                  : () {
                      changeStatus(order, nextStatus);
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: SellerTheme.navyDark,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(SellerTheme.radiusLarge),
                ),
              ),
              child: isUpdating
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(buttonText, style: SellerTheme.buttonText),
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // ORDER CARD
  // ============================================================

  Widget buildOrderCard(SellerOrder order) {
    final color = statusColor(order.status);

    final canAction = getNextStatus(order.status) != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: SellerTheme.cardDecoration(radius: SellerTheme.radiusCard),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ORDER HEADER
          Row(
            children: [
              Expanded(
                child: Text(
                  'คำสั่งซื้อ #${order.orderId}',
                  style: SellerTheme.sectionTitle,
                ),
              ),

              SellerTheme.statusBadge(statusText(order.status), color: color),
            ],
          ),

          const SizedBox(height: 12),

          // BUYER
          Row(
            children: [
              const Icon(
                Icons.person_outline,
                size: 18,
                color: SellerTheme.textSecondary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(order.buyerName, style: SellerTheme.bodySecondary),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // PRODUCT
          Container(
            padding: const EdgeInsets.all(12),
            decoration: SellerTheme.cardDecoration(
              color: SellerTheme.backgroundLight,
              radius: SellerTheme.radiusMedium,
              shadow: false,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                buildProductImage(order),

                const SizedBox(width: 12),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.productName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: SellerTheme.textPrimary,
                        ),
                      ),

                      if (order.variantLabel.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(order.variantLabel, style: SellerTheme.small),
                      ],

                      const SizedBox(height: 6),

                      Text(
                        'จำนวน ${order.quantity} ชิ้น',
                        style: SellerTheme.small,
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                Text(
                  '฿${order.subtotal.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: SellerTheme.navyDark,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // DATE
          Row(
            children: [
              const Icon(
                Icons.access_time,
                size: 16,
                color: SellerTheme.textLight,
              ),
              const SizedBox(width: 5),
              Text(order.createdAt, style: SellerTheme.small),
            ],
          ),

          const SizedBox(height: 12),

          // TOTAL
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              const Text('รวม ', style: SellerTheme.bodySecondary),
              Text(
                '฿${order.totalAmount.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: SellerTheme.navyDark,
                ),
              ),
            ],
          ),

          if (canAction) ...[
            const SizedBox(height: 14),
            buildActionButtons(order),
          ],
        ],
      ),
    );
  }

  // ============================================================
  // FILTER BAR
  // ============================================================

  Widget buildFilterBar() {
    final filters = [
      'ทั้งหมด',
      'รอดำเนินการ',
      'ชำระเงินแล้ว',
      'กำลังดำเนินการ',
      'เสร็จสิ้น',
      'ยกเลิก',
    ];

    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: filters.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final filter = filters[index];

          return SellerTheme.filterChip(
            text: filter,
            selected: selectedFilter == filter,
            onTap: () {
              setState(() {
                selectedFilter = filter;
              });
            },
          );
        },
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final visibleOrders = filteredOrders;

    return Theme(
      data: SellerTheme.theme(),
      child: Scaffold(
        backgroundColor: SellerTheme.background,

        appBar: SellerTheme.appBar('คำสั่งซื้อ'),

        body: RefreshIndicator(
          onRefresh: load,
          color: SellerTheme.navy,
          child: Column(
            children: [
              const SizedBox(height: 12),

              buildFilterBar(),

              const SizedBox(height: 12),

              Expanded(
                child: loading
                    ? SellerTheme.loading()
                    : errorMessage != null
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          SizedBox(
                            height: MediaQuery.of(context).size.height * 0.30,
                            child: SellerTheme.empty(
                              message: 'โหลดคำสั่งซื้อไม่สำเร็จ\n$errorMessage',
                              icon: Icons.error_outline,
                            ),
                          ),
                        ],
                      )
                    : visibleOrders.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          const SizedBox(height: 250),
                          SellerTheme.empty(
                            message: 'ยังไม่มีคำสั่งซื้อ',
                            icon: Icons.receipt_long_outlined,
                          ),
                        ],
                      )
                    : ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        itemCount: visibleOrders.length,
                        itemBuilder: (context, index) {
                          return buildOrderCard(visibleOrders[index]);
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
