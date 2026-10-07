import 'package:flutter/material.dart';

import 'seller_theme.dart';
import 'api/seller_api.dart';
import 'models/seller_models.dart';

class SellerHistoryScreen extends StatefulWidget {
  final int sellerId;

  const SellerHistoryScreen({super.key, required this.sellerId});

  @override
  State<SellerHistoryScreen> createState() => _SellerHistoryScreenState();
}

class _SellerHistoryScreenState extends State<SellerHistoryScreen> {
  List<SellerOrder> orders = [];

  bool loading = true;

  String filter = 'ทั้งหมด';

  @override
  void initState() {
    super.initState();
    load();
  }

  // ============================================================
  // LOAD
  // ============================================================

  Future<void> load() async {
    try {
      if (mounted) {
        setState(() {
          loading = true;
        });
      }

      final data = await SellerApi.orders(widget.sellerId);

      if (!mounted) return;

      setState(() {
        orders = data
            .map((e) => SellerOrder.fromJson(Map<String, dynamic>.from(e)))
            .toList();

        loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        loading = false;
      });

      showMessage('โหลดประวัติการขายไม่สำเร็จ: $e');
    }
  }

  // ============================================================
  // STATUS TEXT
  // ============================================================

  String thai(String status) {
    switch (status) {
      case 'shipping':
        return 'กำลังจัดส่ง';

      case 'completed':
        return 'เสร็จสิ้น';

      case 'cancelled':
        return 'ยกเลิกแล้ว';

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
  // MESSAGE
  // ============================================================

  void showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(SellerTheme.snackBar(message));
  }

  // ============================================================
  // EMPTY MESSAGE
  // ============================================================

  String getEmptyMessage() {
    switch (filter) {
      case 'shipping':
        return 'ไม่มีรายการกำลังจัดส่ง';

      case 'completed':
        return 'ยังไม่มีรายการที่เสร็จสิ้น';

      case 'cancelled':
        return 'ยังไม่มีรายการที่ยกเลิก';

      default:
        return 'ยังไม่มีประวัติการขาย';
    }
  }

  // ============================================================
  // FILTER
  // ============================================================

  Widget filterChip(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: SellerTheme.filterChip(
        text: label,
        selected: filter == value,
        onTap: () {
          setState(() {
            filter = value;
          });
        },
      ),
    );
  }

  // ============================================================
  // HISTORY CARD
  // ============================================================

  Widget historyCard(SellerOrder order) {
    final statusCol = statusColor(order.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: SellerTheme.cardDecoration(
        radius: SellerTheme.radiusCard,
        borderColor: order.status == 'cancelled'
            ? SellerTheme.dangerLight
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ==================================================
          // HEADER
          // ==================================================
          Row(
            children: [
              Expanded(
                child: Text(
                  'คำสั่งซื้อ #${order.orderId}',
                  style: SellerTheme.sectionTitle,
                ),
              ),

              Text(order.createdAt, style: SellerTheme.small),
            ],
          ),

          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1, color: SellerTheme.border),
          ),

          // ==================================================
          // PRODUCT
          // ==================================================
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: SellerTheme.cardDecoration(
                  color: SellerTheme.backgroundLight,
                  radius: SellerTheme.radiusMedium,
                  shadow: false,
                ),
                child: const Icon(
                  Icons.shopping_bag_outlined,
                  color: SellerTheme.textSecondary,
                  size: 22,
                ),
              ),

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
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: SellerTheme.textPrimary,
                      ),
                    ),

                    const SizedBox(height: 4),

                    Text(
                      'ลูกค้า: ${order.buyerName}',
                      style: SellerTheme.bodySecondary,
                    ),

                    const SizedBox(height: 2),

                    Text(
                      'จำนวน: ${order.quantity} ชิ้น',
                      style: SellerTheme.bodySecondary,
                    ),

                    if (order.variantLabel.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        order.variantLabel,
                        style: SellerTheme.bodySecondary,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // ==================================================
          // STATUS + PRICE
          // ==================================================
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SellerTheme.statusBadge(thai(order.status), color: statusCol),

              Text(
                '฿${order.subtotal.toStringAsFixed(0)}',
                style: TextStyle(
                  color: order.status == 'cancelled'
                      ? SellerTheme.textSecondary
                      : SellerTheme.orange,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ],
          ),

          // ==================================================
          // CANCELLED MESSAGE
          // ==================================================
          if (order.status == 'cancelled') ...[
            const SizedBox(height: 12),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: SellerTheme.cardDecoration(
                color: SellerTheme.dangerLight,
                radius: SellerTheme.radiusSmall,
                shadow: false,
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: SellerTheme.danger, size: 16),

                  SizedBox(width: 6),

                  Expanded(
                    child: Text(
                      'คำสั่งซื้อนี้ถูกยกเลิกแล้ว',
                      style: TextStyle(color: SellerTheme.danger, fontSize: 12),
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

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final history = orders.where((o) {
      return o.status == 'shipping' ||
          o.status == 'completed' ||
          o.status == 'cancelled';
    }).toList();

    final shown = filter == 'ทั้งหมด'
        ? history
        : history.where((o) => o.status == filter).toList();

    return Theme(
      data: SellerTheme.theme(),
      child: Scaffold(
        backgroundColor: SellerTheme.background,

        appBar: SellerTheme.appBar('ประวัติการขาย'),

        body: loading
            ? SellerTheme.loading()
            : RefreshIndicator(
                onRefresh: load,
                color: SellerTheme.navy,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  children: [
                    // ==================================================
                    // FILTER
                    // ==================================================
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          filterChip('ทั้งหมด', 'ทั้งหมด'),
                          filterChip('กำลังจัดส่ง', 'shipping'),
                          filterChip('เสร็จสิ้น', 'completed'),
                          filterChip('ยกเลิกแล้ว', 'cancelled'),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ==================================================
                    // EMPTY
                    // ==================================================
                    if (shown.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 50, bottom: 50),
                        child: SellerTheme.empty(
                          message: getEmptyMessage(),
                          icon: filter == 'cancelled'
                              ? Icons.cancel_outlined
                              : filter == 'shipping'
                              ? Icons.local_shipping_outlined
                              : filter == 'completed'
                              ? Icons.check_circle_outline
                              : Icons.history_rounded,
                        ),
                      ),

                    // ==================================================
                    // HISTORY LIST
                    // ==================================================
                    ...shown.map((order) => historyCard(order)),
                  ],
                ),
              ),
      ),
    );
  }
}
