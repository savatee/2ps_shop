import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'api/seller_api.dart';
import 'models/seller_models.dart';
import 'package:flutter/services.dart';
import '../../core/utils/input_formatters.dart';

class SellerAddProductScreen extends StatefulWidget {
  final int sellerId;
  final SellerProduct? product;

  const SellerAddProductScreen({
    super.key,
    required this.sellerId,
    this.product,
  });

  @override
  State<SellerAddProductScreen> createState() => _SellerAddProductScreenState();
}

class _VariantRow {
  final TextEditingController size;
  final TextEditingController color;
  final TextEditingController price;
  final TextEditingController stock;

  _VariantRow({
    String sizeValue = '',
    String colorValue = '',
    String priceValue = '',
    String stockValue = '',
  }) : size = TextEditingController(text: sizeValue),
       color = TextEditingController(text: colorValue),
       price = TextEditingController(text: priceValue),
       stock = TextEditingController(text: stockValue);

  void dispose() {
    size.dispose();
    color.dispose();
    price.dispose();
    stock.dispose();
  }
}

class _SellerAddProductScreenState extends State<SellerAddProductScreen> {
  final name = TextEditingController();
  final description = TextEditingController();
  final price = TextEditingController();
  final stock = TextEditingController();

  List<SellerCategory> categories = [];
  int? categoryId;

  List<ProductImage> oldImages = [];
  List<Uint8List> newImages = [];
  List<int> deletedImageIds = [];

  final List<_VariantRow> variantRows = [];

  bool hasVariants = false;

  bool loading = true;
  bool saving = false;

  bool get isEdit => widget.product != null;

  @override
  void initState() {
    super.initState();

    final p = widget.product;

    if (p != null) {
      name.text = p.name;
      description.text = p.description;
      price.text = p.price.toString();
      stock.text = p.stock.toString();

      categoryId = p.categoryId;

      oldImages = List<ProductImage>.from(p.images);

      if (p.variants.isNotEmpty) {
        hasVariants = true;

        for (final v in p.variants) {
          variantRows.add(
            _VariantRow(
              sizeValue: v.size ?? '',
              colorValue: v.color ?? '',
              priceValue: v.price.toString(),
              stockValue: v.stock.toString(),
            ),
          );
        }
      }
    }

    loadData();
  }

  Future<void> loadData() async {
    try {
      final categoryData = await SellerApi.categories();

      List<dynamic> variantData = [];

      if (isEdit) {
        variantData = await SellerApi.productVariants(
          widget.product!.productId,
        );
      }

      if (!mounted) return;

      final loadedCategories = categoryData
          .map((e) => SellerCategory.fromJson(Map<String, dynamic>.from(e)))
          .toList();

      if (variantData.isNotEmpty) {
        for (final row in variantRows) {
          row.dispose();
        }

        variantRows.clear();

        for (final item in variantData) {
          final v = ProductVariant.fromJson(Map<String, dynamic>.from(item));

          variantRows.add(
            _VariantRow(
              sizeValue: v.size ?? '',
              colorValue: v.color ?? '',
              priceValue: v.price.toString(),
              stockValue: v.stock.toString(),
            ),
          );
        }

        hasVariants = variantRows.isNotEmpty;
      }

      setState(() {
        categories = loadedCategories;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        loading = false;
      });

      showMessage('โหลดข้อมูลสินค้าไม่สำเร็จ: $e');
    }
  }

  Future<void> pickImages() async {
    try {
      final picker = ImagePicker();

      final selected = await picker.pickMultiImage(
        imageQuality: 80,
        maxWidth: 1200,
      );

      if (selected.isEmpty) return;

      final List<Uint8List> selectedBytes = [];

      for (final file in selected) {
        final bytes = await file.readAsBytes();

        if (bytes.isNotEmpty) {
          selectedBytes.add(bytes);
        }
      }

      if (!mounted) return;

      setState(() {
        newImages.addAll(selectedBytes);
      });
    } catch (e) {
      showMessage('เลือกรูปภาพไม่สำเร็จ: $e');
    }
  }

  void removeOldImage(int index) {
    if (index < 0 || index >= oldImages.length) {
      return;
    }

    final image = oldImages[index];

    if (image.imageId > 0) {
      deletedImageIds.add(image.imageId);
    }

    setState(() {
      oldImages.removeAt(index);
    });
  }

  void removeNewImage(int index) {
    if (index < 0 || index >= newImages.length) {
      return;
    }

    setState(() {
      newImages.removeAt(index);
    });
  }

  void setHasVariants(bool value) {
    if (saving) return;

    setState(() {
      hasVariants = value;

      if (hasVariants && variantRows.isEmpty) {
        variantRows.add(_VariantRow());
      }
    });
  }

  void addVariantRow() {
    setState(() {
      variantRows.add(_VariantRow());
    });
  }

  void removeVariantRow(int index) {
    if (index < 0 || index >= variantRows.length) {
      return;
    }

    if (variantRows.length <= 1) {
      showMessage('ต้องมีอย่างน้อย 1 รายการ');
      return;
    }

    final row = variantRows.removeAt(index);

    row.dispose();

    setState(() {});
  }

  List<Map<String, dynamic>> buildVariants() {
    final result = <Map<String, dynamic>>[];

    for (int i = 0; i < variantRows.length; i++) {
      final row = variantRows[i];

      final sizeValue = row.size.text.trim();
      final colorValue = row.color.text.trim();

      final variantPrice = double.tryParse(row.price.text.trim());

      final variantStock = int.tryParse(row.stock.text.trim());

      // ต้องมีอย่างน้อย ไซส์ หรือ สี
      if (sizeValue.isEmpty && colorValue.isEmpty) {
        throw Exception('กรุณากรอกไซส์หรือสีของรายการที่ ${i + 1}');
      }

      if (variantPrice == null || variantPrice < 0) {
        throw Exception('กรุณากรอกราคาของรายการที่ ${i + 1} ให้ถูกต้อง');
      }

      if (variantStock == null || variantStock < 0) {
        throw Exception('กรุณากรอกสต็อกของรายการที่ ${i + 1} ให้ถูกต้อง');
      }

      result.add({
        'size': sizeValue.isEmpty ? null : sizeValue,
        'color': colorValue.isEmpty ? null : colorValue,
        'price': variantPrice,
        'stock': variantStock,
      });
    }

    return result;
  }

  Future<void> save() async {
    if (name.text.trim().isEmpty) {
      showMessage('กรุณากรอกชื่อสินค้า');
      return;
    }

    if (categoryId == null) {
      showMessage('กรุณาเลือกหมวดหมู่สินค้า');
      return;
    }

    if (!isEdit && newImages.isEmpty) {
      showMessage('กรุณาเลือกรูปภาพสินค้าอย่างน้อย 1 รูป');
      return;
    }

    if (isEdit && oldImages.isEmpty && newImages.isEmpty) {
      showMessage('สินค้าต้องมีรูปภาพอย่างน้อย 1 รูป');
      return;
    }

    try {
      List<Map<String, dynamic>> variants = [];

      double finalPrice;
      int finalStock;

      if (hasVariants) {
        if (variantRows.isEmpty) {
          showMessage('กรุณาเพิ่มรายการตัวเลือกอย่างน้อย 1 รายการ');
          return;
        }

        variants = buildVariants();

        // ใช้ราคาต่ำสุดเป็นราคาหลักของสินค้า
        finalPrice = variants
            .map((e) => (e['price'] as num).toDouble())
            .reduce((a, b) => a < b ? a : b);

        // รวม stock ของทุก variant
        finalStock = variants
            .map((e) => (e['stock'] as num).toInt())
            .fold<int>(0, (sum, value) => sum + value);
      } else {
        finalPrice = double.tryParse(price.text.trim()) ?? -1;

        finalStock = int.tryParse(stock.text.trim()) ?? -1;

        if (finalPrice < 0) {
          showMessage('กรุณากรอกราคาให้ถูกต้อง');
          return;
        }

        if (finalStock < 0) {
          showMessage('กรุณากรอกจำนวนสินค้าให้ถูกต้อง');
          return;
        }
      }

      setState(() {
        saving = true;
      });

      Map<String, dynamic> result;

      if (!isEdit) {
        result = await SellerApi.addProduct(
          sellerId: widget.sellerId,
          categoryId: categoryId!,
          name: name.text.trim(),
          description: description.text.trim(),
          price: finalPrice,
          stock: finalStock,
          variants: variants,
          imageBytesList: newImages,
        );
      } else {
        result = await SellerApi.updateProduct(
          sellerId: widget.sellerId,
          productId: widget.product!.productId,
          categoryId: categoryId!,
          name: name.text.trim(),
          description: description.text.trim(),
          price: finalPrice,
          stock: finalStock,
          variants: variants,
          imageBytesList: newImages,
          deletedImageIds: deletedImageIds,
        );
      }

      if (!mounted) return;

      showMessage(result['message']?.toString() ?? 'บันทึกสำเร็จ');

      await Future.delayed(const Duration(milliseconds: 700));

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        showMessage('บันทึกไม่สำเร็จ: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          saving = false;
        });
      }
    }
  }

  void showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    name.dispose();
    description.dispose();
    price.dispose();
    stock.dispose();

    for (final row in variantRows) {
      row.dispose();
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final totalImages = oldImages.length + newImages.length;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),

      appBar: AppBar(
        backgroundColor: const Color(0xFF0D356B),
        foregroundColor: Colors.white,
        title: Text(isEdit ? 'แก้ไขสินค้า' : 'โพสต์ขายสินค้า'),
      ),

      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(18),
              children: [
                // =====================================================
                // รูปภาพสินค้า
                // =====================================================
                Row(
                  children: [
                    const Text(
                      'รูปภาพสินค้า',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const Spacer(),
                    Text(
                      '$totalImages รูป',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                InkWell(
                  onTap: saving ? null : pickImages,
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    height: 110,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_photo_alternate_outlined, size: 36),
                        SizedBox(height: 7),
                        Text('เพิ่มรูปภาพ'),
                        SizedBox(height: 3),
                        Text(
                          'สามารถเลือกได้มากกว่า 1 รูป',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ),

                if (totalImages > 0) ...[
                  const SizedBox(height: 12),

                  SizedBox(
                    height: 110,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: totalImages,
                      separatorBuilder: (_, _) => const SizedBox(width: 10),
                      itemBuilder: (_, index) {
                        if (index < oldImages.length) {
                          final item = oldImages[index];

                          final imageUrl =
                              item.imageUrl ??
                              SellerApi.imageUrl(item.imagePath);

                          return _networkImageCard(
                            imageUrl,
                            index == 0 ? 'รูปหลัก' : 'รูปเดิม',
                            saving ? null : () => removeOldImage(index),
                          );
                        }

                        final newIndex = index - oldImages.length;

                        return _memoryImageCard(
                          newImages[newIndex],
                          oldImages.isEmpty && newIndex == 0
                              ? 'รูปหลัก'
                              : 'รูปใหม่',
                          saving ? null : () => removeNewImage(newIndex),
                        );
                      },
                    ),
                  ),
                ],

                const SizedBox(height: 18),

                // =====================================================
                // ชื่อสินค้า
                // =====================================================
                field(name, 'ชื่อสินค้า', 'กรอกชื่อสินค้า'),

                const SizedBox(height: 12),

                // =====================================================
                // หมวดหมู่
                // =====================================================
                DropdownButtonFormField<int>(
                  initialValue: categories.any((c) => c.id == categoryId)
                      ? categoryId
                      : null,
                  decoration: decoration('หมวดหมู่'),
                  items: categories
                      .map(
                        (c) => DropdownMenuItem<int>(
                          value: c.id,
                          child: Text(c.name),
                        ),
                      )
                      .toList(),
                  onChanged: saving
                      ? null
                      : (value) {
                          setState(() {
                            categoryId = value;
                          });
                        },
                ),

                const SizedBox(height: 16),

                // =====================================================
                // ตัวเลือกสินค้า
                // =====================================================
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'สินค้านี้มีตัวเลือกหรือไม่?',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                            SizedBox(height: 3),
                            Text(
                              'เช่น ไซส์ สี หรือเฉดสี',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),

                      Switch(
                        value: hasVariants,
                        onChanged: setHasVariants,
                        activeThumbColor: const Color(0xFF0D356B),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // =====================================================
                // ไม่มี Variant
                // =====================================================
                if (!hasVariants) ...[
                  field(
                    price,
                    'ราคา (บาท)',
                    'กรอกราคา',
                    keyboard: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    formatters: AppInputFormatters.money(),
                  ),

                  const SizedBox(height: 12),

                  field(
                    stock,
                    'จำนวนสินค้า',
                    'กรอกจำนวนสินค้า',
                    keyboard: TextInputType.number,
                    formatters: AppInputFormatters.digitsOnly(),
                  ),
                ]
                // =====================================================
                // มี Variant
                // =====================================================
                else ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'รายการตัวเลือกสินค้า',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                ),
                              ),
                            ),

                            TextButton.icon(
                              onPressed: saving ? null : addVariantRow,
                              icon: const Icon(Icons.add),
                              label: const Text('เพิ่มตัวเลือก'),
                            ),
                          ],
                        ),

                        const SizedBox(height: 8),

                        ...List.generate(
                          variantRows.length,
                          (index) => _variantCard(index),
                        ),

                        const SizedBox(height: 4),

                        const Text(
                          'สามารถกำหนดไซส์ สี/เฉดสี ราคา และสต็อกแยกกันได้',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 12),

                // =====================================================
                // รายละเอียด
                // =====================================================
                field(
                  description,
                  'รายละเอียดสินค้า',
                  'อธิบายรายละเอียดสินค้า...',
                  maxLines: 5,
                ),

                const SizedBox(height: 22),

                // =====================================================
                // ปุ่มบันทึก
                // =====================================================
                SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: saving ? null : save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0D356B),
                      foregroundColor: Colors.white,
                    ),
                    child: saving
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : Text(isEdit ? 'บันทึกการแก้ไข' : 'โพสต์สินค้า'),
                  ),
                ),
              ],
            ),
    );
  }

  // ================================================================
  // Variant Card
  // ================================================================

  Widget _variantCard(int index) {
    final row = variantRows[index];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                'ตัวเลือกที่ ${index + 1}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),

              const Spacer(),

              if (variantRows.length > 1)
                IconButton(
                  onPressed: saving ? null : () => removeVariantRow(index),
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  tooltip: 'ลบตัวเลือกนี้',
                ),
            ],
          ),

          const SizedBox(height: 4),

          // ==========================================================
          // ไซส์
          // ==========================================================
          field(row.size, 'ไซส์', 'เช่น S / M / L / XL'),

          const SizedBox(height: 10),

          // ==========================================================
          // สี / เฉดสี
          // ==========================================================
          field(row.color, 'สี / เฉดสี', 'เช่น ดำ / ขาว / แดง / ชมพู / Nude'),

          const SizedBox(height: 10),

          // ==========================================================
          // ราคา + สต็อก
          // ==========================================================
          Row(
            children: [
              Expanded(
                child: field(
                  row.price,
                  'ราคา',
                  'บาท',
                  keyboard: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  formatters: AppInputFormatters.money(),
                ),
              ),

              const SizedBox(width: 8),

              Expanded(
                child: field(
                  row.stock,
                  'สต็อก',
                  'ชิ้น',
                  keyboard: TextInputType.number,
                  formatters: AppInputFormatters.digitsOnly(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ================================================================
  // Network Image
  // ================================================================

  Widget _networkImageCard(String? url, String label, VoidCallback? onRemove) {
    return SizedBox(
      width: 105,
      height: 105,
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: url == null || url.isEmpty
                ? Container(
                    width: 105,
                    height: 105,
                    color: Colors.grey.shade200,
                    child: const Icon(Icons.broken_image_outlined),
                  )
                : Image.network(
                    url,
                    width: 105,
                    height: 105,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                      color: Colors.grey.shade200,
                      child: const Icon(Icons.broken_image_outlined),
                    ),
                  ),
          ),

          _removeButton(onRemove),

          _label(label),
        ],
      ),
    );
  }

  // ================================================================
  // Memory Image
  // ================================================================

  Widget _memoryImageCard(
    Uint8List image,
    String label,
    VoidCallback? onRemove,
  ) {
    return SizedBox(
      width: 105,
      height: 105,
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.memory(
              image,
              width: 105,
              height: 105,
              fit: BoxFit.cover,
            ),
          ),

          _removeButton(onRemove),

          _label(label),
        ],
      ),
    );
  }

  // ================================================================
  // ปุ่มลบรูป
  // ================================================================

  Widget _removeButton(VoidCallback? onRemove) {
    return Positioned(
      top: 5,
      right: 5,
      child: GestureDetector(
        onTap: onRemove,
        child: Container(
          width: 28,
          height: 28,
          decoration: const BoxDecoration(
            color: Colors.black54,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.close, size: 18, color: Colors.white),
        ),
      ),
    );
  }

  // ================================================================
  // Label รูป
  // ================================================================

  Widget _label(String label) {
    return Positioned(
      left: 5,
      bottom: 5,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: const TextStyle(color: Colors.white, fontSize: 11),
        ),
      ),
    );
  }

  // ================================================================
  // Input Decoration
  // ================================================================

  InputDecoration decoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  // ================================================================
  // TextField
  // ================================================================

  Widget field(
    TextEditingController controller,
    String label,
    String hint, {
    TextInputType? keyboard,
    List<TextInputFormatter>? formatters,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboard,
      inputFormatters: formatters,
      maxLines: maxLines,
      decoration: decoration(label).copyWith(hintText: hint),
    );
  }
}
