import 'dart:async';
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../core/widgets/loading_view.dart';
import '../../core/utils/image_utils.dart';
import '../../core/widgets/product_thumb.dart';
import '../../core/network/api_client.dart';

class PaymentPage extends StatefulWidget {
  final int userId;
  final int paymentId;
  final int orderId;
  final double amount;

  const PaymentPage({
    super.key,
    required this.userId,
    required this.paymentId,
    required this.orderId,
    required this.amount,
  });

  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  Map<String, dynamic>? _paymentData;
  Map<String, dynamic>? _orderData;

  bool _isLoading = true;
  bool _isSubmitting = false;

  String _paymentStatus = 'pending';

  /// หน้าที่: เตรียมสถานะเริ่มต้นของหน้าจอและเริ่มโหลดข้อมูลที่จำเป็น (คลาส _PaymentPageState).
  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // =====================================================
  // โหลดข้อมูลการชำระเงิน และ คำสั่งซื้อ
  // =====================================================

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final paymentFuture = ApiClient.getPaymentQr(
      userId: widget.userId,
      paymentId: widget.paymentId,
    );

    final orderFuture = ApiClient.getOrderDetail(
      widget.orderId,
      userId: widget.userId,
    );

    final results = await Future.wait([paymentFuture, orderFuture]);

    if (!mounted) return;

    final paymentResult = results[0];
    final orderResult = results[1];

    if (paymentResult['success'] != true) {
      setState(() => _isLoading = false);
      showAppSnackBar(
        context,
        paymentResult['message']?.toString() ??
            'ไม่สามารถโหลดข้อมูลการชำระเงินได้',
        isError: true,
      );
      return;
    }

    final rawData = paymentResult['data'];
    final payment = rawData is Map
        ? Map<String, dynamic>.from(rawData)
        : <String, dynamic>{};

    setState(() {
      _paymentData = payment;
      _paymentStatus = payment['payment_status']?.toString() ?? 'pending';
      if (orderResult['success'] == true && orderResult['data'] is Map) {
        _orderData = Map<String, dynamic>.from(orderResult['data']);
      }
      _isLoading = false;
    });
  }

  // =====================================================
  // ยืนยันการชำระเงิน (ไม่ต้องแนบสลิป)
  // =====================================================

  Future<void> _confirmPayment() async {
    if (_paymentStatus == 'paid') {
      showAppSnackBar(
        context,
        'รายการนี้ชำระเงินเรียบร้อยแล้ว',
        isError: false,
      );
      return;
    }

    if (_paymentStatus == 'submitted') {
      showAppSnackBar(
        context,
        'คุณแจ้งชำระเงินแล้ว กรุณารอตรวจสอบ',
        isError: false,
      );
      return;
    }

    if (_paymentStatus == 'cancelled') {
      showAppSnackBar(context, 'รายการนี้ถูกยกเลิกแล้ว', isError: true);
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    final result = await ApiClient.confirmPaymentTransfer(
      userId: widget.userId,
      paymentId: widget.paymentId,
    );

    if (!mounted) return;

    setState(() {
      _isSubmitting = false;
    });

    if (result['success'] != true) {
      showAppSnackBar(
        context,
        result['message']?.toString() ?? 'ไม่สามารถยืนยันการชำระเงินได้',
        isError: true,
      );
      return;
    }

    // เดิมใช้ pushAndRemoveUntil(..., (route) => false) ซึ่งเคลียร์ทุก route
    // ในสแต็ก รวมถึง route ของ buyer_checkout_page ที่กำลัง await
    // Navigator.push(PaymentPage) ค้างอยู่ด้วย พอ route นั้นหายไป checkout
    // page เรียก Navigator.pop(context, true) ซ้ำจึงชน assertion
    // '_history.isNotEmpty' เพราะไม่มี route เหลือให้ pop
    //
    // แก้โดย pop PaymentPage กลับไปพร้อมผลลัพธ์ แล้วให้ checkout page
    // เป็นคนตัดสินใจไปหน้า OrderSuccessPage เอง (เหมือน flow เก็บเงินปลายทาง)
    Navigator.pop(context, true);
  }

  // =====================================================
  // BUILD
  // =====================================================

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
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: _isLoading
          ? const LoadingView()
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildTimerCard(),
                  _buildQrCard(),
                  _buildOrderSummary(),
                ],
              ),
            ),
      bottomNavigationBar: _isLoading ? null : _buildBottomAction(),
    );
  }

  /// หน้าที่: สร้าง UI ส่วน Timer Card เพื่อใช้ในหน้าจอนี้ (คลาส _PaymentPageState).
  Widget _buildTimerCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF2FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDBEAFE)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.access_time, color: Colors.blue, size: 20),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: 'กรุณาชำระเงินภายใน  ',
                        style: TextStyle(
                          color: Color(0xFF202735),
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextSpan(
                        text: '09:41',
                        style: TextStyle(
                          color: Colors.blue,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextSpan(
                        text: ' นาที',
                        style: TextStyle(
                          color: Color(0xFF202735),
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'ระบบจะตรวจสอบยอดเงินและยืนยันออเดอร์อัตโนมัติ',
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// หน้าที่: สร้าง UI ส่วน Qr Card เพื่อใช้ในหน้าจอนี้ (คลาส _PaymentPageState).
  Widget _buildQrCard() {
    final qrUrl = _paymentData?['qr_image_url']?.toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header (THAI QR)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFF0F172A),
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade700,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'THAI\nQR',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      height: 1.1,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'สแกนจ่ายได้ทุกธนาคาร',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Text(
                  'PromptPay',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),

          // QR Image
          Padding(
            padding: const EdgeInsets.all(24),
            child: qrUrl != null && qrUrl.isNotEmpty
                ? Image.network(
                    qrUrl,
                    width: 220,
                    height: 220,
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return const SizedBox(
                        width: 220,
                        height: 220,
                        child: Center(child: CircularProgressIndicator()),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) =>
                        const SizedBox(
                          width: 220,
                          height: 220,
                          child: Center(
                            child: Icon(
                              Icons.qr_code,
                              size: 60,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                  )
                : const SizedBox(
                    width: 220,
                    height: 220,
                    child: Center(
                      child: Icon(Icons.qr_code, size: 60, color: Colors.grey),
                    ),
                  ),
          ),

          // Amount
          const Text(
            'ยอดชำระสุทธิ',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          Text(
            '฿${widget.amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.bold,
              color: Colors.blue.shade600,
              height: 1.1,
            ),
          ),

          const SizedBox(height: 16),

          // Order Info
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'หมายเลขคำสั่งซื้อ:',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    Text(
                      '#2PS-${widget.orderId}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF202735),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'ผู้รับเงิน:',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const Text(
                      '2PS Shop Official',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF202735),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Save QR Button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: OutlinedButton.icon(
              onPressed: () {
                showAppSnackBar(context, 'บันทึกรูป QR ลงในเครื่องสำเร็จ');
              },
              icon: const Icon(Icons.download_rounded, size: 18),
              label: const Text(
                'บันทึกรูป QR ลงในเครื่อง',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF475569),
                side: BorderSide.none,
                backgroundColor: const Color(0xFFF1F5F9),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                minimumSize: const Size.fromHeight(48),
              ),
            ),
          ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  /// หน้าที่: สร้าง UI ส่วน Order Summary เพื่อใช้ในหน้าจอนี้ (คลาส _PaymentPageState).
  Widget _buildOrderSummary() {
    if (_orderData == null) return const SizedBox.shrink();

    final items = _orderData!['items'] as List<dynamic>? ?? [];
    if (items.isEmpty) return const SizedBox.shrink();

    final item = items.first;
    final name = item['product_name']?.toString() ?? 'สินค้า';
    final imageUrl = pickProductImage(item);
    final qty = int.tryParse(item['item_quantity']?.toString() ?? '1') ?? 1;
    final price = double.tryParse(item['item_price']?.toString() ?? '0') ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'สรุปรายการสินค้า',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 50,
                height: 50,
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
                        color: Color(0xFF202735),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'ตัวเลือก: ค่าเริ่มต้น (จำนวน $qty ชิ้น)',
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '฿${price.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF202735),
                      ),
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

  /// หน้าที่: สร้าง UI ส่วน Bottom Action เพื่อใช้ในหน้าจอนี้ (คลาส _PaymentPageState).
  Widget _buildBottomAction() {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
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
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _isSubmitting || _paymentStatus != 'pending'
                    ? null
                    : _confirmPayment,
                icon: _isSubmitting
                    ? const SizedBox()
                    : const Icon(Icons.check, size: 20),
                label: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'ชำระเงินแล้ว',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade600,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.shade300,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: () => Navigator.pop(context),
              child: const Text(
                'เปลี่ยนช่องทางการชำระเงิน',
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.security, color: Colors.green, size: 12),
                const SizedBox(width: 4),
                Text(
                  'รับประกันความปลอดภัยมาตรฐาน 2PS Shop 100%',
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
