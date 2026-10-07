import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/loading_view.dart';
import '../../core/widgets/product_thumb.dart';
import '../../core/utils/image_utils.dart';
import '../../core/network/api_client.dart';
import 'buyer_main_page.dart';
import 'buyer_order_detail_page.dart';

class OrderSuccessPage extends StatefulWidget {
  final int userId;
  final int orderId;
  final int paymentId;
  final double totalAmount;
  final String paymentMethod;

  const OrderSuccessPage({
    super.key,
    required this.userId,
    required this.orderId,
    required this.paymentId,
    required this.totalAmount,
    required this.paymentMethod,
  });

  @override
  State<OrderSuccessPage> createState() => _OrderSuccessPageState();
}

class _OrderSuccessPageState extends State<OrderSuccessPage> {
  Map<String, dynamic>? _orderData;
  bool _isLoading = true;
  String? _loadError;

  Map<String, dynamic> get _paymentData {
    final payment = _orderData?['payment'];
    return payment is Map ? Map<String, dynamic>.from(payment) : {};
  }

  String get _paymentMethod =>
      (_paymentData['payment_method'] ??
              _orderData?['payment_method'] ??
              widget.paymentMethod)
          .toString()
          .toLowerCase();

  String get _paymentStatus =>
      (_paymentData['payment_status'] ?? '').toString().toLowerCase();

  String get _orderStatus =>
      (_orderData?['order_status'] ?? '').toString().toLowerCase();

  double get _totalAmount =>
      double.tryParse(
        (_paymentData['amount'] ?? _orderData?['total_amount'] ?? '')
            .toString(),
      ) ??
      widget.totalAmount;

  String get _orderDate {
    final rawDate =
        (_orderData?['created_at'] ?? _orderData?['order_created_at'] ?? '')
            .toString();
    final date = DateTime.tryParse(rawDate);
    if (date == null) return 'บันทึกคำสั่งซื้อแล้ว';
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/${date.year} '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')} น.';
  }

  @override
  void initState() {
    super.initState();
    _loadOrderData();
  }

  Future<void> _loadOrderData() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final result = await ApiClient.getOrderDetail(
        widget.orderId,
        userId: widget.userId,
      );

      if (!mounted) return;

      if (result['success'] == true && result['data'] is Map) {
        setState(() {
          _orderData = Map<String, dynamic>.from(result['data']);
          _isLoading = false;
        });
      } else {
        setState(() {
          _loadError =
              result['message']?.toString() ??
              'ไม่สามารถโหลดรายละเอียดคำสั่งซื้อได้';
          _isLoading = false;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadError = 'เชื่อมต่อข้อมูลคำสั่งซื้อไม่ได้ กรุณาลองอีกครั้ง';
        _isLoading = false;
      });
    }
  }

  void _goHome() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => BuyerMainPage(userId: widget.userId)),
      (route) => false,
    );
  }

  void _goToOrderDetail() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BuyerOrderDetailPage(
          orderId: widget.orderId,
          userId: widget.userId,
        ),
      ),
    );
  }

  void _copyOrderId() {
    Clipboard.setData(ClipboardData(text: '2PS-${widget.orderId}'));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('คัดลอกหมายเลขคำสั่งซื้อแล้ว')),
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
          onPressed: _goHome,
        ),
        title: const Text(
          'ชำระเงิน',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
        elevation: 0,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Colors.tealAccent,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const LoadingView()
          : _loadError != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.cloud_off_outlined, size: 48),
                    const SizedBox(height: 12),
                    Text(_loadError!, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: _loadOrderData,
                      icon: const Icon(Icons.refresh),
                      label: const Text('ลองโหลดอีกครั้ง'),
                    ),
                  ],
                ),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  _buildHeaderCard(),
                  _buildPaymentCard(),
                  _buildTimelineCard(),
                  _buildAddressCard(),
                  _buildProductCard(),
                  _buildSummaryCard(),
                  _buildActionButtons(),
                ],
              ),
            ),
    );
  }

  Widget _buildHeaderCard() {
    final isCancelled = _orderStatus == 'cancelled';
    final isCod = _paymentMethod == 'cod';
    final isPaid = {'paid', 'completed'}.contains(_paymentStatus);
    final isSubmitted = _paymentStatus == 'submitted';
    final message = isCancelled
        ? 'คำสั่งซื้อนี้ถูกยกเลิกแล้ว'
        : isCod
        ? 'ระบบบันทึกคำสั่งซื้อแล้ว กรุณาชำระเงินเมื่อได้รับสินค้า'
        : isPaid
        ? 'ยืนยันการชำระเงินแล้ว ร้านค้าจะดำเนินการจัดส่งต่อไป'
        : isSubmitted
        ? 'ระบบรับแจ้งชำระเงินแล้ว กำลังรอร้านค้าตรวจสอบยอด'
        : 'ระบบบันทึกคำสั่งซื้อแล้ว กรุณาชำระเงินตามช่องทางที่เลือก';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: isCancelled ? Colors.red : const Color(0xFF10B981),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF10B981).withValues(alpha: 0.3),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Icon(
              isCancelled ? Icons.close : Icons.check,
              color: Colors.white,
              size: 40,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            isCancelled ? 'คำสั่งซื้อถูกยกเลิก' : 'สั่งซื้อสินค้าสำเร็จ!',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Colors.grey, height: 1.5),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'หมายเลขคำสั่งซื้อ:',
                            style: TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '#2PS-${widget.orderId}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Text(
                            'วันที่สั่งซื้อ:',
                            style: TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _orderDate,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _copyOrderId,
                  icon: const Icon(Icons.copy, size: 14),
                  label: const Text('คัดลอก', style: TextStyle(fontSize: 11)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF64748B),
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 0,
                    ),
                    minimumSize: const Size(0, 32),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentCard() {
    final isCod = _paymentMethod == 'cod';
    final isPaid = {'paid', 'completed'}.contains(_paymentStatus);
    final isSubmitted = _paymentStatus == 'submitted';
    final statusLabel = isCod
        ? 'ชำระปลายทาง'
        : isPaid
        ? 'ชำระแล้ว'
        : isSubmitted
        ? 'รอตรวจสอบ'
        : 'รอชำระเงิน';
    final statusColor = isCod
        ? Colors.orange
        : isPaid
        ? Colors.green
        : Colors.blue;
    final description = isCod
        ? 'ชำระเงินกับเจ้าหน้าที่เมื่อได้รับสินค้า'
        : isPaid
        ? 'ร้านค้ายืนยันยอดชำระเงินแล้ว'
        : isSubmitted
        ? 'ระบบรับแจ้งชำระแล้ว รอร้านค้าตรวจสอบยอด'
        : 'กรุณาชำระเงินตามช่องทางที่เลือก';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: statusColor.shade400,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isCod ? Icons.payments_outlined : Icons.qr_code_2,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        isCod
                            ? 'เตรียมชำระเงินเมื่อรับสินค้า (COD)'
                            : 'ชำระเงินผ่าน QR พร้อมเพย์',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.shade50,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        statusLabel,
                        style: TextStyle(
                          color: statusColor.shade700,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      'ยอดคำสั่งซื้อ: ',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    Text(
                      '฿${_totalAmount.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Colors.grey,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineCard() {
    final statusLabel = switch (_orderStatus) {
      'pending' => 'รอร้านค้าดำเนินการ',
      'processing' => 'กำลังเตรียมสินค้า',
      'shipped' => 'กำลังจัดส่ง',
      'completed' => 'จัดส่งสำเร็จ',
      'cancelled' => 'คำสั่งซื้อถูกยกเลิก',
      '' => 'รับคำสั่งซื้อแล้ว',
      _ => _orderStatus,
    };
    final isCancelled = _orderStatus == 'cancelled';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'สถานะคำสั่งซื้อ',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Icon(
                isCancelled ? Icons.cancel_outlined : Icons.check_circle,
                color: isCancelled ? Colors.red : Colors.green,
                size: 24,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      statusLabel,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'อัปเดตจากคำสั่งซื้อ #2PS-${widget.orderId}',
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAddressCard() {
    final address = _orderData?['shipping_address'];
    final name = address != null ? (address['recipient_name'] ?? '') : '';
    final phone = address != null ? (address['address_phone'] ?? '') : '';
    final fullAddress = address != null ? _addressLine(address) : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
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
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 8),
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: 'คุณ$name ',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      TextSpan(
                        text: phone,
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  fullAddress,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductCard() {
    final rawItems = _orderData?['items'];
    final items = rawItems is List
        ? rawItems
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList()
        : <Map<String, dynamic>>[];
    if (items.isEmpty) return const SizedBox.shrink();
    final totalQuantity = items.fold<int>(
      0,
      (total, item) =>
          total + (int.tryParse(item['item_quantity']?.toString() ?? '') ?? 0),
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'รายการสินค้า $totalQuantity ชิ้น',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 12),
          for (var index = 0; index < items.length; index++) ...[
            _buildProductRow(items[index]),
            if (index < items.length - 1)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Divider(height: 1),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildProductRow(Map<String, dynamic> item) {
    final name = item['product_name']?.toString() ?? 'สินค้า';
    final imageUrl = pickProductImage(item);
    final quantity = int.tryParse(item['item_quantity']?.toString() ?? '') ?? 0;
    final price = double.tryParse(item['item_price']?.toString() ?? '') ?? 0;
    final subtotal =
        double.tryParse(item['subtotal']?.toString() ?? '') ?? price * quantity;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(8),
          ),
          clipBehavior: Clip.antiAlias,
          child: ProductThumb(imageUrl: imageUrl, iconSize: 20),
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
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '฿${price.toStringAsFixed(2)} x $quantity',
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
              const SizedBox(height: 4),
              Text(
                'รวม ฿${subtotal.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ยอดรวมคำสั่งซื้อ',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'ยอดที่บันทึกในระบบ',
                style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
              ),
              Text(
                '฿${_totalAmount.toStringAsFixed(2)}',
                style: const TextStyle(color: Color(0xFF1E293B), fontSize: 12),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1, color: Color(0xFFF1F5F9)),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text(
                'ยอดรวม',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: Color(0xFF1E293B),
                ),
              ),
              Text(
                '฿${_totalAmount.toStringAsFixed(2)}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.blue.shade700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: _goToOrderDetail,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Text(
                  'ดูรายละเอียดคำสั่งซื้อ / ติดตามพัสดุ',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
                SizedBox(width: 8),
                Icon(Icons.arrow_forward, size: 16),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton.icon(
            onPressed: _goHome,
            icon: const Icon(Icons.home_outlined, size: 18),
            label: const Text(
              'กลับสู่หน้าหลัก / ช้อปต่อ',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF475569),
              side: const BorderSide(color: Color(0xFFE2E8F0)),
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.security, color: Colors.green, size: 12),
            const SizedBox(width: 4),
            Text(
              'รับประกันความปลอดภัยโดย 2PS Shop 100% ตรวจสอบได้ทุกขั้นตอน',
              style: TextStyle(fontSize: 9, color: Colors.grey.shade500),
            ),
          ],
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}
