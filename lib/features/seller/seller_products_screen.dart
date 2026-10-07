import 'package:flutter/material.dart';

import 'api/seller_api.dart';
import 'models/seller_models.dart';
import 'seller_add_product_screen.dart';

class SellerProductsScreen extends StatefulWidget {
  final int sellerId;

  const SellerProductsScreen({super.key, required this.sellerId});

  @override
  State<SellerProductsScreen> createState() => _SellerProductsScreenState();
}

class _SellerProductsScreenState extends State<SellerProductsScreen> {
  List<SellerProduct> products = [];

  bool loading = true;
  bool deleting = false;
  final Set<int> selectedCategoryIds = {};

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();
    load();
  }

  // ============================================================
  // LOAD PRODUCTS
  // ============================================================

  Future<void> load() async {
    if (!mounted) return;

    setState(() {
      loading = true;
    });

    try {
      final data = await SellerApi.products(widget.sellerId);

      if (!mounted) return;

      final loadedProducts = data
          .map((e) => SellerProduct.fromJson(Map<String, dynamic>.from(e)))
          .toList();

      setState(() {
        products = loadedProducts;
        loading = false;
      });

      debugPrint('========== SELLER PRODUCTS ==========');
      debugPrint('ทั้งหมด: ${products.length}');
      debugPrint('กำลังขาย: ${activeProducts.length}');
      debugPrint('รออนุมัติ: ${pendingProducts.length}');
      debugPrint('ถูกปฏิเสธ: ${rejectedProducts.length}');
      debugPrint('ปิดการขาย: ${closedProducts.length}');
      debugPrint('====================================');
    } catch (e) {
      if (!mounted) return;

      setState(() {
        loading = false;
      });

      showMessage('โหลดสินค้าไม่สำเร็จ: $e');
    }
  }

  // ============================================================
  // STATUS FILTER
  // ============================================================

  Map<int, String> get categoryOptions {
    final options = <int, String>{};

    for (final product in products) {
      options.putIfAbsent(
        product.categoryId,
        () => product.categoryName.trim().isEmpty
            ? 'ไม่ระบุหมวดหมู่'
            : product.categoryName.trim(),
      );
    }

    return options;
  }

  /// หน้าที่: ค้นหาหรือกรองข้อมูล filter By หมวดหมู่สินค้า ตามเงื่อนไขที่ผู้ใช้เลือก (คลาส _SellerProductsScreenState).
  List<SellerProduct> filterByCategory(Iterable<SellerProduct> list) {
    if (selectedCategoryIds.isEmpty) return list.toList();

    return list
        .where((product) => selectedCategoryIds.contains(product.categoryId))
        .toList();
  }

  /// สินค้าที่กำลังขาย
  List<SellerProduct> get activeProducts {
    return filterByCategory(
      products.where((product) => product.productStatus == 'active'),
    );
  }

  /// สินค้าที่รอแอดมินอนุมัติ
  List<SellerProduct> get pendingProducts {
    return filterByCategory(
      products.where((product) => product.productStatus == 'pending'),
    );
  }

  /// สินค้าที่ถูกปฏิเสธ
  List<SellerProduct> get rejectedProducts {
    return filterByCategory(
      products.where((product) => product.productStatus == 'rejected'),
    );
  }

  /// สินค้าที่ปิดการขาย
  List<SellerProduct> get closedProducts {
    return filterByCategory(
      products.where((product) => product.productStatus == 'inactive'),
    );
  }

  // ============================================================
  // DELETE / CLOSE SALE
  // ============================================================

  Future<void> remove(SellerProduct product) async {
    if (deleting) return;

    // rejected = ลบถาวร
    final bool isRejected = product.productStatus == 'rejected';

    final String dialogTitle = isRejected ? 'ลบสินค้า' : 'ปิดการขายสินค้า';

    final String message = isRejected
        ? 'ต้องการลบสินค้า "${product.name}" หรือไม่?\n\n'
              'สินค้าที่ถูกปฏิเสธจะถูกลบออกจากระบบอย่างถาวร'
        : product.productStatus == 'pending'
        ? 'ต้องการยกเลิกสินค้านี้หรือไม่?\n\n'
              'สินค้าจะถูกย้ายไปที่ "ปิดการขาย"'
        : 'ต้องการปิดการขาย "${product.name}" หรือไม่?\n\n'
              'สินค้าจะถูกย้ายไปที่ "ปิดการขาย"';

    final String confirmText = isRejected ? 'ลบสินค้า' : 'ปิดการขาย';

    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(dialogTitle),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('ยกเลิก'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: Text(confirmText),
            ),
          ],
        );
      },
    );

    if (ok != true) return;

    if (!mounted) return;

    setState(() {
      deleting = true;
    });

    try {
      final result = await SellerApi.deleteProduct(
        widget.sellerId,
        product.productId,
      );

      if (!mounted) return;

      if (result['success'] == true) {
        showMessage(
          result['message']?.toString() ??
              (isRejected ? 'ลบสินค้าเรียบร้อยแล้ว' : 'ปิดการขายเรียบร้อยแล้ว'),
        );

        // โหลดรายการใหม่
        // ถ้า rejected ถูกลบจริง จะหายออกจากแท็บทันที
        await load();
      } else {
        showMessage(
          result['message']?.toString() ??
              (isRejected ? 'ลบสินค้าไม่สำเร็จ' : 'ปิดการขายไม่สำเร็จ'),
        );
      }
    } catch (e) {
      if (!mounted) return;

      showMessage(
        isRejected ? 'ลบสินค้าไม่สำเร็จ: $e' : 'ปิดการขายไม่สำเร็จ: $e',
      );
    } finally {
      if (mounted) {
        setState(() {
          deleting = false;
        });
      }
    }
  }

  // ============================================================
  // EDIT PRODUCT
  // ============================================================

  Future<void> editProduct(SellerProduct product) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            SellerAddProductScreen(sellerId: widget.sellerId, product: product),
      ),
    );

    if (!mounted) return;

    await load();
  }

  /// หน้าที่: เปิดหรือแสดงหน้าต่าง/ส่วน UI สำหรับ open หมวดหมู่สินค้า Filter Sheet (คลาส _SellerProductsScreenState).
  void openCategoryFilterSheet() {
    final draftSelectedIds = Set<int>.from(selectedCategoryIds);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final categories = categoryOptions.entries.toList()
              ..sort((a, b) => a.value.compareTo(b.value));

            return SafeArea(
              top: false,
              child: Container(
                height: MediaQuery.sizeOf(context).height * 0.68,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 12, 8),
                      child: Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'เลือกหมวดหมู่ที่ต้องการดู',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (draftSelectedIds.isNotEmpty)
                            TextButton(
                              onPressed: () {
                                setSheetState(draftSelectedIds.clear);
                              },
                              child: const Text('ล้างทั้งหมด'),
                            ),
                          IconButton(
                            tooltip: 'ปิด',
                            onPressed: () => Navigator.pop(sheetContext),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: categories.isEmpty
                          ? const Center(child: Text('ยังไม่มีสินค้า'))
                          : ListView.separated(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              itemCount: categories.length,
                              separatorBuilder: (_, _) =>
                                  const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final category = categories[index];
                                final categoryCount = products
                                    .where(
                                      (product) =>
                                          product.categoryId == category.key,
                                    )
                                    .length;
                                final isSelected = draftSelectedIds.contains(
                                  category.key,
                                );

                                return CheckboxListTile(
                                  value: isSelected,
                                  activeColor: const Color(0xFF0D356B),
                                  controlAffinity:
                                      ListTileControlAffinity.trailing,
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(
                                    category.value,
                                    style: TextStyle(
                                      fontWeight: isSelected
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                    ),
                                  ),
                                  subtitle: Text('$categoryCount รายการ'),
                                  onChanged: (checked) {
                                    setSheetState(() {
                                      if (checked == true) {
                                        draftSelectedIds.add(category.key);
                                      } else {
                                        draftSelectedIds.remove(category.key);
                                      }
                                    });
                                  },
                                );
                              },
                            ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: const BoxDecoration(
                        border: Border(
                          top: BorderSide(color: Color(0xFFE5E7EB)),
                        ),
                      ),
                      child: SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0D356B),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: () {
                            setState(() {
                              selectedCategoryIds
                                ..clear()
                                ..addAll(draftSelectedIds);
                            });
                            Navigator.pop(sheetContext);
                          },
                          child: Text(
                            'กรองสินค้า (${draftSelectedIds.isEmpty ? 'ทุกหมวด' : '${draftSelectedIds.length} หมวด'})',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ============================================================
  // MESSAGE
  // ============================================================

  void showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F6FA),

        // ======================================================
        // APP BAR
        // ======================================================
        appBar: AppBar(
          backgroundColor: const Color(0xFF0D356B),
          foregroundColor: Colors.white,

          title: const Text('สินค้าของฉัน'),

          bottom: TabBar(
            isScrollable: true,

            indicatorColor: Colors.white,
            indicatorWeight: 3,

            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,

            tabs: [
              Tab(text: 'กำลังขาย (${activeProducts.length})'),
              Tab(text: 'รออนุมัติ (${pendingProducts.length})'),
              Tab(text: 'ถูกปฏิเสธ (${rejectedProducts.length})'),
              Tab(text: 'ปิดการขาย (${closedProducts.length})'),
            ],
          ),
        ),

        // ======================================================
        // BODY
        // ======================================================
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'พบ ${filterByCategory(products).length} รายการ',
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        InkWell(
                          onTap: openCategoryFilterSheet,
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: selectedCategoryIds.isEmpty
                                  ? const Color(0xFFF1F5F9)
                                  : const Color(0xFFE8EEF7),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: selectedCategoryIds.isEmpty
                                    ? const Color(0xFFE2E8F0)
                                    : const Color(0xFFB7C7DD),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.filter_list, size: 17),
                                const SizedBox(width: 5),
                                Text(
                                  selectedCategoryIds.isEmpty
                                      ? 'เลือกหมวดหมู่'
                                      : 'หมวดหมู่ (${selectedCategoryIds.length})',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const Icon(Icons.arrow_drop_down, size: 18),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        productList(activeProducts),
                        productList(pendingProducts),
                        productList(rejectedProducts),
                        productList(closedProducts),
                      ],
                    ),
                  ),
                ],
              ),

        // ======================================================
        // ADD PRODUCT
        // ======================================================
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: const Color(0xFF0D356B),
          foregroundColor: Colors.white,

          onPressed: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    SellerAddProductScreen(sellerId: widget.sellerId),
              ),
            );

            if (!mounted) return;

            await load();
          },

          label: const Text('โพสต์ขายสินค้า'),

          icon: const Icon(Icons.add),
        ),
      ),
    );
  }

  // ============================================================
  // PRODUCT LIST
  // ============================================================

  Widget productList(List<SellerProduct> list) {
    if (list.isEmpty) {
      return RefreshIndicator(
        onRefresh: load,

        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),

          children: const [
            SizedBox(height: 220),

            Center(
              child: Text(
                'ไม่มีสินค้าในหมวดนี้',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: load,

      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),

        padding: const EdgeInsets.all(14),

        itemCount: list.length,

        separatorBuilder: (_, _) {
          return const SizedBox(height: 10);
        },

        itemBuilder: (_, index) {
          final product = list[index];

          return productCard(product);
        },
      ),
    );
  }

  // ============================================================
  // PRODUCT CARD
  // ============================================================

  Widget productCard(SellerProduct product) {
    final bool isInactive = product.productStatus == 'inactive';

    final bool isRejected = product.productStatus == 'rejected';

    return Container(
      padding: const EdgeInsets.all(10),

      decoration: BoxDecoration(
        color: Colors.white,

        borderRadius: BorderRadius.circular(14),

        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),

      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,

        children: [
          // ====================================================
          // IMAGE
          // ====================================================
          productImage(product),

          const SizedBox(width: 12),

          // ====================================================
          // PRODUCT INFO
          // ====================================================
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                Text(
                  product.name,

                  maxLines: 2,

                  overflow: TextOverflow.ellipsis,

                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),

                const SizedBox(height: 5),

                statusBadge(product.productStatus),

                const SizedBox(height: 5),

                Text(
                  product.categoryName,
                  style: TextStyle(color: Colors.grey.shade600),
                ),

                const SizedBox(height: 4),

                Text(
                  '฿${product.price.toStringAsFixed(0)}',

                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Color(0xFF0D356B),
                  ),
                ),

                const SizedBox(height: 3),

                Text(
                  'คงเหลือ ${product.stock} ชิ้น',

                  style: TextStyle(color: Colors.grey.shade700),
                ),

                if (product.images.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),

                    child: Text(
                      '${product.images.length} รูป',

                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // ====================================================
          // MENU
          // ====================================================
          if (!isInactive)
            PopupMenuButton<String>(
              enabled: !deleting,

              onSelected: (value) {
                // แก้ไข
                if (value == 'edit') {
                  editProduct(product);
                }

                // ลบ / ปิดการขาย
                if (value == 'delete') {
                  remove(product);
                }
              },

              itemBuilder: (_) {
                return [
                  // ==========================================
                  // EDIT
                  // ==========================================
                  const PopupMenuItem<String>(
                    value: 'edit',
                    child: Text('แก้ไข'),
                  ),

                  // ==========================================
                  // REJECTED
                  // ==========================================
                  if (isRejected)
                    const PopupMenuItem<String>(
                      value: 'delete',
                      child: Text(
                        'ลบสินค้า',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),

                  // ==========================================
                  // ACTIVE / PENDING
                  // ==========================================
                  if (!isRejected)
                    const PopupMenuItem<String>(
                      value: 'delete',
                      child: Text(
                        'ปิดการขาย',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                ];
              },
            ),
        ],
      ),
    );
  }

  // ============================================================
  // STATUS BADGE
  // ============================================================

  Widget statusBadge(String status) {
    String text;
    Color color;
    Color background;

    switch (status) {
      case 'active':
        text = 'กำลังขาย';
        color = Colors.green.shade700;
        background = Colors.green.shade50;
        break;

      case 'pending':
        text = 'รออนุมัติ';
        color = Colors.orange.shade700;
        background = Colors.orange.shade50;
        break;

      case 'rejected':
        text = 'ถูกปฏิเสธ';
        color = Colors.red.shade700;
        background = Colors.red.shade50;
        break;

      case 'inactive':
        text = 'ปิดการขาย';
        color = Colors.grey.shade700;
        background = Colors.grey.shade200;
        break;

      default:
        text = status;
        color = Colors.grey.shade700;
        background = Colors.grey.shade200;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),

      decoration: BoxDecoration(
        color: background,

        borderRadius: BorderRadius.circular(20),
      ),

      child: Text(
        text,

        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  // ============================================================
  // PRODUCT IMAGE
  // ============================================================

  Widget productImage(SellerProduct product) {
    String? imageUrl;

    if (product.imageUrl != null && product.imageUrl!.trim().isNotEmpty) {
      imageUrl = product.imageUrl!.trim();
    }

    if ((imageUrl == null || imageUrl.isEmpty) && product.images.isNotEmpty) {
      final firstImage = product.images.first;

      if (firstImage.imageUrl != null &&
          firstImage.imageUrl!.trim().isNotEmpty) {
        imageUrl = firstImage.imageUrl!.trim();
      }
    }

    if (imageUrl == null || imageUrl.isEmpty) {
      return _emptyImage();
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),

      child: Image.network(
        imageUrl,

        width: 80,
        height: 80,

        fit: BoxFit.cover,

        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) {
            return child;
          }

          return Container(
            width: 80,
            height: 80,

            color: Colors.grey.shade100,

            child: const Center(
              child: SizedBox(
                width: 22,
                height: 22,

                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        },

        errorBuilder: (context, error, stackTrace) {
          debugPrint('IMAGE URL ERROR: $imageUrl');

          return _brokenImage();
        },
      ),
    );
  }

  // ============================================================
  // EMPTY IMAGE
  // ============================================================

  Widget _emptyImage() {
    return Container(
      width: 80,
      height: 80,

      decoration: BoxDecoration(
        color: Colors.grey.shade100,

        borderRadius: BorderRadius.circular(10),
      ),

      child: const Icon(Icons.image_outlined, color: Colors.grey, size: 32),
    );
  }

  // ============================================================
  // BROKEN IMAGE
  // ============================================================

  Widget _brokenImage() {
    return Container(
      width: 80,
      height: 80,

      decoration: BoxDecoration(
        color: Colors.grey.shade100,

        borderRadius: BorderRadius.circular(10),
      ),

      child: const Icon(
        Icons.broken_image_outlined,
        color: Colors.grey,
        size: 32,
      ),
    );
  }
}
