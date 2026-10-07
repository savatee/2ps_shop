import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/image_utils.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/safe_network_image.dart';
import '../../../core/network/api_client.dart';
import '../../../core/utils/input_formatters.dart';

class WantedComposePage extends StatefulWidget {
  final int userId;
  final Map<String, dynamic>? post;

  const WantedComposePage({super.key, required this.userId, this.post});

  @override
  State<WantedComposePage> createState() => _WantedComposePageState();
}

class _WantedComposePageState extends State<WantedComposePage> {
  static const _suggestedTags = ['#มือหนึ่ง', '#มือสองสภาพดี'];
  static const _urgentTag = '#ตามหาด่วน';
  static const _descriptionMaxLength = 500;

  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _budgetController = TextEditingController();
  final _imagePicker = ImagePicker();
  Uint8List? _selectedImageBytes;
  String? _selectedImagePath;
  String? _existingImagePath;
  List<Map<String, dynamic>> _categories = [];
  int? _selectedCategoryId;
  bool _loadingCategories = true;
  bool _submitting = false;
  bool _removeExistingImage = false;

  /// หน้าที่: เตรียมสถานะเริ่มต้นของหน้าจอและเริ่มโหลดข้อมูลที่จำเป็น (คลาส _WantedComposePageState).
  @override
  void initState() {
    super.initState();
    final post = widget.post;
    if (post != null) {
      _titleController.text = post['title']?.toString() ?? '';
      _descriptionController.text =
          post['wanted_description']?.toString() ?? '';
      _budgetController.text = post['budget']?.toString() ?? '';
      _selectedCategoryId = int.tryParse(post['category_id']?.toString() ?? '');
      _existingImagePath = post['wanted_image']?.toString();
    }
    _loadCategories();
    if (post != null) _refreshPostFromDb();
  }

  /// โหมดแก้ไข: ดึงข้อมูลโพสต์ล่าสุดจากฐานข้อมูลมาเติมฟอร์ม
  Future<void> _refreshPostFromDb() async {
    final id = int.tryParse(widget.post?['wanted_post_id']?.toString() ?? '');
    if (id == null) return;
    try {
      final result = await ApiClient.getWantedPost(id, viewerId: widget.userId);
      final data = result['data'];
      if (!mounted || result['success'] != true || data is! Map) return;
      setState(() {
        _titleController.text =
            data['title']?.toString() ?? _titleController.text;
        _descriptionController.text =
            data['wanted_description']?.toString() ??
            _descriptionController.text;
        final budget = double.tryParse(data['budget']?.toString() ?? '');
        if (budget != null) {
          _budgetController.text = budget == budget.roundToDouble()
              ? budget.toStringAsFixed(0)
              : budget.toString();
        }
        _selectedCategoryId =
            int.tryParse(data['category_id']?.toString() ?? '') ??
            _selectedCategoryId;
        _existingImagePath = pickWantedImage(data) ?? _existingImagePath;
      });
    } catch (_) {
      // ใช้ข้อมูลที่ส่งมาจากหน้าก่อนหน้าต่อไป
    }
  }

  /// หน้าที่: โหลดข้อมูล load หมวดหมู่สินค้า และอัปเดตสถานะการแสดงผลของหน้าจอ (คลาส _WantedComposePageState).
  Future<void> _loadCategories() async {
    try {
      final result = await ApiClient.getCategories();
      if (!mounted) return;
      setState(() {
        _categories = result
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .where((item) => item['category_status'] == 'active')
            .toList();
        _loadingCategories = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loadingCategories = false);
      showAppSnackBar(context, 'โหลดหมวดหมู่ไม่สำเร็จ: $error', isError: true);
    }
  }

  /// หน้าที่: เลือกรับข้อมูล pick รูปภาพ จากผู้ใช้หรืออุปกรณ์ (คลาส _WantedComposePageState).
  Future<void> _pickImage() async {
    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 80,
      );
      if (image == null) return;
      final bytes = await image.readAsBytes();
      if (!mounted) return;
      setState(() {
        _selectedImagePath = image.path;
        _selectedImageBytes = bytes;
        _removeExistingImage = false;
      });
    } catch (error) {
      if (!mounted) return;
      showAppSnackBar(context, 'เลือกรูปไม่สำเร็จ: $error', isError: true);
    }
  }

  /// หน้าที่: ลบข้อมูล remove รูปภาพ และจัดการผลการลบที่ API ส่งกลับ (คลาส _WantedComposePageState).
  void _removeImage() {
    setState(() {
      _selectedImagePath = null;
      _selectedImageBytes = null;
      _removeExistingImage = _existingImagePath?.isNotEmpty == true;
    });
  }

  /// หน้าที่: คืนทรัพยากรของหน้าจอ เช่น controller และ listener ก่อนปิดหน้า (คลาส _WantedComposePageState).
  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _budgetController.dispose();
    super.dispose();
  }

  /// หน้าที่: ตรวจสอบและส่งข้อมูล submit ไปบันทึกผ่าน API (คลาส _WantedComposePageState).
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategoryId == null || _loadingCategories) {
      showAppSnackBar(context, 'กรุณาเลือกหมวดหมู่สินค้า', isError: true);
      return;
    }

    setState(() => _submitting = true);
    final postId = int.tryParse(
      widget.post?['wanted_post_id']?.toString() ?? '',
    );
    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();
    final budget = double.parse(_budgetController.text.replaceAll(',', ''));
    final result = postId == null
        ? await ApiClient.createBuyerRequest(
            userId: widget.userId,
            title: title,
            description: description,
            budget: budget,
            categoryId: _selectedCategoryId!,
            imagePath: _selectedImagePath,
          )
        : await ApiClient.updateBuyerRequest(
            userId: widget.userId,
            postId: postId,
            title: title,
            description: description,
            budget: budget,
            categoryId: _selectedCategoryId!,
            imagePath: _selectedImagePath,
            removeImage: _removeExistingImage && _selectedImagePath == null,
          );
    if (!mounted) return;
    setState(() => _submitting = false);

    final success = result['success'] == true;
    showAppSnackBar(
      context,
      result['message']?.toString() ??
          (success ? 'ดำเนินการเสร็จสิ้น' : 'บันทึกโพสต์ไม่สำเร็จ'),
      isError: !success,
    );

    if (success) Navigator.pop(context, true);
  }

  // ---------- UI helpers (รูปแบบเดียวกับหน้าหลัก: การ์ดขาวมุมมน + เงาบาง) ----------
  BoxDecoration get _cardDecoration => BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(16),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.04),
        blurRadius: 12,
        offset: const Offset(0, 3),
      ),
    ],
  );

  /// หน้าที่: ประมวลผลขั้นตอน plain Decoration สำหรับส่วน wanted compose page (คลาส _WantedComposePageState).
  InputDecoration _plainDecoration(String hint, {Widget? suffix}) =>
      InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(
          color: Color(0xFF9AA1AE),
          fontSize: 13.5,
          fontWeight: FontWeight.w500,
        ),
        suffixIcon: suffix,
        suffixIconConstraints: const BoxConstraints(),
        isDense: true,
        filled: false,
        contentPadding: const EdgeInsets.symmetric(vertical: 6),
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        errorBorder: InputBorder.none,
        focusedErrorBorder: InputBorder.none,
        errorStyle: const TextStyle(fontSize: 11, color: AppColors.danger),
      );

  /// หน้าที่: ประมวลผลขั้นตอน field Card สำหรับส่วน wanted compose page (คลาส _WantedComposePageState).
  Widget _fieldCard({
    required String label,
    bool required = false,
    Widget? trailingLabel,
    required Widget child,
    Widget? footer,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: _cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text.rich(
                  TextSpan(
                    text: label,
                    children: [
                      if (required)
                        const TextSpan(
                          text: ' *',
                          style: TextStyle(color: AppColors.danger),
                        ),
                    ],
                  ),
                  style: const TextStyle(
                    color: AppColors.textGrey,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              ?trailingLabel,
            ],
          ),
          const SizedBox(height: 6),
          child,
          if (footer != null) ...[const SizedBox(height: 10), footer],
        ],
      ),
    );
  }

  /// หน้าที่: สลับค่า toggle Tag และอัปเดตหน้าจอตามสถานะใหม่ (คลาส _WantedComposePageState).
  void _toggleTag(String tag) {
    final current = _descriptionController.text.trimRight();
    if (current.contains(tag)) {
      _descriptionController
        ..text = current
            .replaceAll(tag, '')
            .replaceAll(RegExp(r'\s{2,}'), ' ')
            .trim()
        ..selection = TextSelection.collapsed(
          offset: _descriptionController.text.length,
        );
      setState(() {});
      return;
    }
    if (current.length + tag.length + (current.isEmpty ? 0 : 1) >
        _descriptionMaxLength) {
      return;
    }
    _descriptionController
      ..text = current.isEmpty ? tag : '$current $tag'
      ..selection = TextSelection.collapsed(
        offset: _descriptionController.text.length,
      );
    setState(() {});
  }

  /// หน้าที่: ประมวลผลขั้นตอน tag Chip สำหรับส่วน wanted compose page (คลาส _WantedComposePageState).
  Widget _tagChip(String tag, {bool urgent = false}) {
    final selected = _descriptionController.text.contains(tag);
    final fg = urgent ? const Color(0xFFB45309) : AppColors.textDark;
    final bg = urgent ? const Color(0xFFFFF4DC) : const Color(0xFFF1F4F8);
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _toggleTag(tag),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected
                  ? (urgent ? AppColors.accent : AppColors.primary)
                  : Colors.transparent,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (urgent) ...[
                const Icon(
                  Icons.bolt_rounded,
                  size: 13,
                  color: AppColors.accent,
                ),
                const SizedBox(width: 2),
              ],
              Text(
                tag,
                style: TextStyle(
                  color: fg,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// หน้าที่: สร้าง UI ส่วน Image Picker เพื่อใช้ในหน้าจอนี้ (คลาส _WantedComposePageState).
  Widget _buildImagePicker() {
    final existing = _removeExistingImage ? null : _existingImagePath;
    final hasImage =
        _selectedImageBytes != null ||
        (existing != null && existing.isNotEmpty);

    return CustomPaint(
      painter: _DashedBorderPainter(color: const Color(0xFFCBD5E1), radius: 16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(12),
              ),
              clipBehavior: Clip.antiAlias,
              child: _selectedImageBytes != null
                  ? Image.memory(_selectedImageBytes!, fit: BoxFit.cover)
                  : (existing != null && existing.isNotEmpty)
                  ? SafeNetworkImage(source: existing)
                  : const Icon(
                      Icons.image_outlined,
                      color: AppColors.textGrey,
                      size: 22,
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hasImage
                        ? 'รูปตัวอย่างสินค้า'
                        : 'เพิ่มรูปตัวอย่างสินค้า (ถ้ามี)',
                    style: const TextStyle(
                      color: AppColors.textDark,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  const Text(
                    'แนบรูปให้ผู้ขายเห็นภาพสินค้าที่ต้องการชัดขึ้น\nJPG, PNG, WEBP หรือ GIF ไม่เกิน 10 MB',
                    style: TextStyle(
                      color: AppColors.textGrey,
                      fontSize: 10.5,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            if (hasImage)
              IconButton(
                tooltip: 'ลบรูป',
                onPressed: _submitting ? null : _removeImage,
                icon: const Icon(Icons.close_rounded, size: 18),
                visualDensity: VisualDensity.compact,
              ),
            OutlinedButton(
              onPressed: _submitting ? null : _pickImage,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textDark,
                side: const BorderSide(color: AppColors.border),
                backgroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                minimumSize: const Size(0, 34),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              child: Text(
                hasImage ? 'เปลี่ยน' : '+ เพิ่ม',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// หน้าที่: สร้าง UI ส่วน Category Field เพื่อใช้ในหน้าจอนี้ (คลาส _WantedComposePageState).
  Widget _buildCategoryField() {
    final validSelection = _categories.any(
      (category) =>
          int.tryParse('${category['category_id']}') == _selectedCategoryId,
    );
    return _fieldCard(
      label: 'หมวดหมู่สินค้า',
      required: true,
      child: Row(
        children: [
          const Icon(
            Icons.grid_view_rounded,
            color: AppColors.textGrey,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: validSelection ? _selectedCategoryId : null,
                isExpanded: true,
                isDense: true,
                borderRadius: BorderRadius.circular(14),
                icon: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: AppColors.textGrey,
                ),
                hint: Text(
                  _loadingCategories
                      ? 'กำลังโหลดหมวดหมู่...'
                      : _categories.isEmpty
                      ? 'ไม่พบหมวดหมู่สินค้า'
                      : 'เลือกหมวดหมู่สินค้า',
                  style: const TextStyle(
                    color: AppColors.textDark,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: const TextStyle(
                  color: AppColors.textDark,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
                items: _categories
                    .map((category) {
                      final id = int.tryParse(
                        '${category['category_id'] ?? 0}',
                      );
                      if (id == null) return null;
                      return DropdownMenuItem<int>(
                        value: id,
                        child: Text(
                          category['category_name']?.toString() ?? '',
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    })
                    .whereType<DropdownMenuItem<int>>()
                    .toList(),
                onChanged: _loadingCategories || _categories.isEmpty
                    ? null
                    : (id) => setState(() => _selectedCategoryId = id),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// หน้าที่: สร้าง UI ของหน้าจอหรือวิดเจ็ตใน wanted compose page (คลาส _WantedComposePageState).
  @override
  Widget build(BuildContext context) {
    final isEdit = widget.post != null;
    final length = _descriptionController.text.length;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primaryDark,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        titleSpacing: 16,
        title: Row(
          children: [
            InkWell(
              onTap: () => Navigator.maybePop(context),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.chevron_left_rounded,
                  color: Colors.white,
                  size: 26,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Text(
              isEdit ? 'แก้ไขโพสต์' : 'โพสต์ตามหาสินค้า',
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: _cardDecoration,
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.campaign_outlined,
                      color: AppColors.primaryDark,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      isEdit
                          ? 'อัปเดตรายละเอียดโพสต์ของคุณ'
                          : 'บอกรายละเอียดสินค้าที่กำลังตามหา',
                      style: const TextStyle(
                        color: AppColors.textDark,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _fieldCard(
              label: 'ชื่อสินค้าที่ต้องการ',
              required: true,
              child: Row(
                children: [
                  const Icon(
                    Icons.search_rounded,
                    color: AppColors.textGrey,
                    size: 22,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _titleController,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: _plainDecoration(
                        'ระบุรุ่น หรือชื่อยี่ห้อสินค้าที่ต้องการ...',
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'กรุณากรอกชื่อสินค้า'
                          : null,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _buildCategoryField(),
            const SizedBox(height: 12),
            _fieldCard(
              label: 'รายละเอียดเพิ่มเติม',
              trailingLabel: Text(
                '$length/$_descriptionMaxLength',
                style: const TextStyle(color: AppColors.textGrey, fontSize: 11),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Icon(
                      Icons.notes_rounded,
                      color: AppColors.textGrey,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _descriptionController,
                      maxLines: 4,
                      minLines: 3,
                      maxLength: _descriptionMaxLength,
                      onChanged: (_) => setState(() {}),
                      style: const TextStyle(fontSize: 13.5, height: 1.4),
                      decoration: _plainDecoration(
                        'ระบุสี สภาพสินค้า ตำหนิที่ยอมรับได้ หรือสเปกที่ต้องการเพิ่มเติม...',
                      ).copyWith(counterText: ''),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'กรุณากรอกรายละเอียด'
                          : null,
                    ),
                  ),
                ],
              ),
              footer: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(right: 8),
                      child: Text(
                        'แท็กด่วน:',
                        style: TextStyle(
                          color: AppColors.textGrey,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    for (final tag in _suggestedTags) _tagChip(tag),
                    _tagChip(_urgentTag, urgent: true),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            _fieldCard(
              label: 'งบประมาณที่ตั้งไว้',
              child: Row(
                children: [
                  const Icon(
                    Icons.payments_outlined,
                    color: AppColors.textGrey,
                    size: 22,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _budgetController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: AppInputFormatters.money(),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                      decoration: _plainDecoration('ระบุงบประมาณ เช่น 1500'),
                      validator: (value) {
                        final amount = double.tryParse(
                          (value ?? '').replaceAll(',', '').trim(),
                        );
                        return amount == null || amount <= 0
                            ? 'กรุณากรอกงบประมาณให้ถูกต้อง'
                            : null;
                      },
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'THB (฿)',
                      style: TextStyle(
                        color: AppColors.textGrey,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _buildImagePicker(),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: SizedBox(
          height: 52,
          child: ElevatedButton.icon(
            onPressed: _submitting ? null : _submit,
            icon: _submitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.search_rounded, size: 20),
            label: Text(
              _submitting
                  ? 'กำลังบันทึก...'
                  : isEdit
                  ? 'บันทึกการแก้ไข'
                  : 'โพสต์ตามหาสินค้า',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryDark,
              foregroundColor: Colors.white,
              disabledBackgroundColor: AppColors.primaryDark,
              disabledForegroundColor: Colors.white,
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// กรอบเส้นประมุมมน (ไม่ต้องพึ่งแพ็กเกจเพิ่ม)
class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double radius;

  const _DashedBorderPainter({required this.color, required this.radius});

  /// หน้าที่: วาดเส้นขอบแบบประตามขนาดพื้นที่ที่ Flutter กำหนด (คลาส _DashedBorderPainter).
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)),
      );
    for (final metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        canvas.drawPath(metric.extractPath(distance, distance + 6), paint);
        distance += 10;
      }
    }
  }

  /// หน้าที่: บอก Flutter ว่าต้องวาดใหม่เมื่อข้อมูล painter เปลี่ยนหรือไม่ (คลาส _DashedBorderPainter).
  @override
  bool shouldRepaint(covariant _DashedBorderPainter old) =>
      old.color != color || old.radius != radius;
}
