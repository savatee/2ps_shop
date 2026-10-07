import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/image_utils.dart';
import '../../core/utils/time_utils.dart';
import '../../core/widgets/safe_network_image.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/loading_view.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../core/network/api_client.dart';
import '../seller/api/seller_api.dart';
import '../seller/seller_theme.dart';
import '../buyer/wanted/wanted_compose_page.dart';
import 'wanted_post_detail_page.dart';
import '../../core/utils/input_formatters.dart';

class WantedFeedPage extends StatefulWidget {
  final int userId;
  final bool isSeller;

  const WantedFeedPage({
    super.key,
    required this.userId,
    this.isSeller = false,
  });

  @override
  State<WantedFeedPage> createState() => _WantedFeedPageState();
}

class _WantedFeedPageState extends State<WantedFeedPage> {
  List<dynamic> _posts = [];
  bool _loading = true;
  String _filterType = 'all'; // 'all' (ทั้งหมด) หรือ 'me' (ของฉัน)
  String _searchKeyword = '';

  final _searchController = TextEditingController();

  List<Map<String, dynamic>> _categories = [
    {'category_id': 0, 'category_name': 'ทั้งหมด'},
  ];
  int _selectedCategoryIndex = 0;

  /// หน้าที่: เตรียมสถานะเริ่มต้นของหน้าจอและเริ่มโหลดข้อมูลที่จำเป็น (คลาส _WantedFeedPageState).
  @override
  void initState() {
    super.initState();
    _load();
  }

  /// หน้าที่: คืนทรัพยากรของหน้าจอ เช่น controller และ listener ก่อนปิดหน้า (คลาส _WantedFeedPageState).
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// หน้าที่: โหลดข้อมูล load และอัปเดตสถานะการแสดงผลของหน้าจอ (คลาส _WantedFeedPageState).
  Future<void> _load() async {
    setState(() => _loading = true);

    try {
      final categoryData = await ApiClient.getCategories();
      final result = widget.isSeller
          ? await SellerApi.wantedPosts()
          : _filterType == 'me'
          ? await ApiClient.getBuyerRequests(widget.userId)
          : await ApiClient.getAllWantedPosts(widget.userId);

      if (!mounted) return;
      setState(() {
        _categories = [
          {'category_id': 0, 'category_name': 'ทั้งหมด'},
          ...categoryData.whereType<Map>().map(
            (item) => Map<String, dynamic>.from(item),
          ),
        ];
        if (_selectedCategoryIndex >= _categories.length) {
          _selectedCategoryIndex = 0;
        }
        _posts = widget.isSeller
            ? result
                  .where((post) => post['wanted_status']?.toString() == 'open')
                  .toList()
            : result;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      showAppSnackBar(context, 'โหลดประกาศไม่สำเร็จ: $error', isError: true);
    }
  }

  List<dynamic> get _filteredPosts {
    final keyword = _searchKeyword.trim().toLowerCase();
    final categoryId =
        int.tryParse(
          '${_categories[_selectedCategoryIndex]['category_id'] ?? 0}',
        ) ??
        0;

    return _posts.where((post) {
      final title = post['title']?.toString().toLowerCase() ?? '';
      final description =
          post['wanted_description']?.toString().toLowerCase() ?? '';
      final searchableText = '$title $description';
      final matchesSearch = keyword.isEmpty || searchableText.contains(keyword);
      final postCategoryId = int.tryParse('${post['category_id'] ?? 0}') ?? 0;
      final matchesCategory = categoryId == 0 || postCategoryId == categoryId;
      return matchesSearch && matchesCategory;
    }).toList();
  }

  /// หน้าที่: เปิดหรือแสดงหน้าต่าง/ส่วน UI สำหรับ open Compose (คลาส _WantedFeedPageState).
  Future<void> _openCompose() async {
    final posted = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => WantedComposePage(userId: widget.userId),
      ),
    );
    if (posted == true) _load();
  }

  /// หน้าที่: ปรับปรุงข้อมูลหรือสถานะ edit โพสต์ ผ่าน API และอัปเดตหน้าจอ (คลาส _WantedFeedPageState).
  Future<void> _editPost(Map<String, dynamic> post) async {
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => WantedComposePage(userId: widget.userId, post: post),
      ),
    );
    if (updated == true) _load();
  }

  /// หน้าที่: ลบข้อมูล delete โพสต์ และจัดการผลการลบที่ API ส่งกลับ (คลาส _WantedFeedPageState).
  Future<void> _deletePost(Map<String, dynamic> post) async {
    final postId = int.tryParse(post['wanted_post_id']?.toString() ?? '');
    if (postId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ลบโพสต์'),
        content: Text('ต้องการลบโพสต์ "${post['title'] ?? ''}" ใช่หรือไม่?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ยกเลิก'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('ลบ', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final result = await ApiClient.deleteBuyerRequest(
      userId: widget.userId,
      postId: postId,
    );
    if (!mounted) return;
    final success = result['success'] == true;
    showAppSnackBar(
      context,
      result['message']?.toString() ??
          (success ? 'ลบโพสต์สำเร็จ' : 'ลบโพสต์ไม่สำเร็จ'),
      isError: !success,
    );
    if (success) _load();
  }

  /// หน้าที่: สลับค่า toggle โพสต์ สถานะ และอัปเดตหน้าจอตามสถานะใหม่ (คลาส _WantedFeedPageState).
  Future<void> _togglePostStatus(Map<String, dynamic> post) async {
    final postId = int.tryParse(post['wanted_post_id']?.toString() ?? '');
    if (postId == null) return;
    final isOpen = post['wanted_status']?.toString() == 'open';
    final result = await ApiClient.setBuyerRequestStatus(
      userId: widget.userId,
      postId: postId,
      status: isOpen ? 'closed' : 'open',
    );
    if (!mounted) return;
    final success = result['success'] == true;
    showAppSnackBar(
      context,
      result['message']?.toString() ??
          (success ? 'เปลี่ยนสถานะโพสต์สำเร็จ' : 'เปลี่ยนสถานะไม่สำเร็จ'),
      isError: !success,
    );
    if (success) _load();
  }

  /// หน้าที่: เปิดหรือแสดงหน้าต่าง/ส่วน UI สำหรับ show ผู้ขาย ข้อเสนอ Dialog (คลาส _WantedFeedPageState).
  Future<void> _showSellerOfferDialog(Map<String, dynamic> post) async {
    final postId = int.tryParse(post['wanted_post_id']?.toString() ?? '');
    if (postId == null || widget.userId <= 0) return;

    final priceController = TextEditingController();
    final detailController = TextEditingController();
    var saving = false;

    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (dialogContentContext, setDialogState) {
            /// หน้าที่: ตรวจสอบและส่งข้อมูล submit ไปบันทึกผ่าน API (คลาส _WantedFeedPageState).
            Future<void> submit() async {
              final price = double.tryParse(priceController.text.trim());
              final detail = detailController.text.trim();
              if (price == null || price <= 0 || detail.isEmpty) {
                showAppSnackBar(
                  context,
                  'กรุณากรอกราคาและรายละเอียดข้อเสนอให้ครบ',
                  isError: true,
                );
                return;
              }

              setDialogState(() => saving = true);
              try {
                final result = await SellerApi.addWantedComment(
                  sellerId: widget.userId,
                  wantedPostId: postId,
                  offerPrice: price,
                  commentText: detail,
                );
                if (!mounted || !dialogContext.mounted) return;
                Navigator.pop(dialogContext);
                showAppSnackBar(
                  context,
                  result['message']?.toString() ?? 'เสนอราคาสำเร็จ',
                );
              } catch (error) {
                if (!mounted || !dialogContext.mounted) return;
                setDialogState(() => saving = false);
                showAppSnackBar(
                  context,
                  'เสนอราคาไม่สำเร็จ: $error',
                  isError: true,
                );
              }
            }

            return AlertDialog(
              title: const Text('เสนอสินค้า'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      post['title']?.toString() ?? '',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Text('งบประมาณ ฿${post['budget']?.toString() ?? '0'}'),
                    const SizedBox(height: 16),
                    TextField(
                      controller: priceController,
                      enabled: !saving,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: AppInputFormatters.money(),
                      decoration: const InputDecoration(
                        labelText: 'ราคาเสนอ',
                        prefixText: '฿ ',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: detailController,
                      enabled: !saving,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'รายละเอียดข้อเสนอ',
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : () => Navigator.pop(dialogContext),
                  child: const Text('ยกเลิก'),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: SellerTheme.navy,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: saving ? null : submit,
                  child: saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('ส่งข้อเสนอ'),
                ),
              ],
            );
          },
        ),
      );
    } finally {
      priceController.dispose();
      detailController.dispose();
    }
  }

  /// หน้าที่: สร้าง UI ส่วน Empty State เพื่อใช้ในหน้าจอนี้ (คลาส _WantedFeedPageState).
  Widget _buildEmptyState() {
    if (_posts.isEmpty &&
        _searchKeyword.isEmpty &&
        _selectedCategoryIndex == 0) {
      return EmptyState(
        icon: Icons.search_off,
        title: 'ยังไม่มีโพสต์ตามหาสินค้า',
        subtitle: widget.isSeller
            ? 'ยังไม่มีประกาศจากลูกค้าที่เปิดรับข้อเสนอ'
            : 'เป็นคนแรกที่โพสต์ตามหาสินค้าที่คุณต้องการ',
        actionLabel: widget.isSeller ? null : 'โพสต์ตามหาสินค้า',
        onAction: widget.isSeller ? null : _openCompose,
      );
    }

    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text('ไม่พบโพสต์ที่ตรงกับตัวกรอง'),
      ),
    );
  }

  /// หน้าที่: สร้าง UI ของหน้าจอหรือวิดเจ็ตใน wanted feed page (คลาส _WantedFeedPageState).
  @override
  Widget build(BuildContext context) {
    final displayPosts = _filteredPosts;

    return Scaffold(
      backgroundColor: SellerTheme.backgroundLight,
      appBar: widget.isSeller ? SellerTheme.appBar('ลูกค้าตามหาสินค้า') : null,
      body: Column(
        children: [
          _buildHeader(),
          _buildCategoryRow(),
          Expanded(
            child: _loading
                ? const LoadingView()
                : displayPosts.isEmpty
                ? _buildEmptyState()
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
                      itemCount: displayPosts.length,
                      itemBuilder: (context, index) {
                        final post = displayPosts[index];
                        final isOwner =
                            int.tryParse(
                              post['wanted_buyer_id']?.toString() ?? '',
                            ) ==
                            widget.userId;

                        return _FeedCard(
                          post: post,
                          isOwner: isOwner,
                          onEdit: widget.isSeller
                              ? () {}
                              : () =>
                                    _editPost(Map<String, dynamic>.from(post)),
                          onDelete: widget.isSeller
                              ? () {}
                              : () => _deletePost(
                                  Map<String, dynamic>.from(post),
                                ),
                          onToggleStatus: widget.isSeller
                              ? () {}
                              : () => _togglePostStatus(
                                  Map<String, dynamic>.from(post),
                                ),
                          onTap: () {
                            if (widget.isSeller) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => WantedPostDetailPage(
                                    post: post,
                                    userId: widget.userId,
                                    isSeller: true,
                                    onOffer: () => _showSellerOfferDialog(
                                      Map<String, dynamic>.from(post),
                                    ),
                                  ),
                                ),
                              );
                            } else {
                              Navigator.push<bool>(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => WantedPostDetailPage(
                                    post: post,
                                    userId: widget.userId,
                                  ),
                                ),
                              ).then((changed) {
                                if (changed == true) _load();
                              });
                            }
                          },
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: widget.isSeller
          ? null
          : FloatingActionButton(
              onPressed: _openCompose,
              backgroundColor: SellerTheme.navy,
              child: const Icon(Icons.add, color: Colors.white),
            ),
    );
  }

  /// หน้าที่: สร้าง UI ส่วน Header เพื่อใช้ในหน้าจอนี้ (คลาส _WantedFeedPageState).
  Widget _buildHeader() {
    return Container(
      color: SellerTheme.navy,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            Expanded(
              child: Container(
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(
                    color: Color(0xFF202735),
                    fontSize: 13,
                  ),
                  onChanged: (value) => setState(() => _searchKeyword = value),
                  decoration: InputDecoration(
                    hintText:
                        'ค้นหาประกาศตามหาสินค้า เช่น iPhone, เสื้อยืด, กางเกง',
                    hintStyle: const TextStyle(
                      color: Color(0xFF9AA1AE),
                      fontSize: 12,
                    ),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: Color(0xFF9AA1AE),
                      size: 20,
                    ),
                    suffixIcon: _searchKeyword.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'ล้างคำค้นหา',
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchKeyword = '');
                            },
                            icon: const Icon(
                              Icons.close_rounded,
                              color: Color(0xFF9299A8),
                              size: 18,
                            ),
                          ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
            ),
            if (!widget.isSeller) ...[
              const SizedBox(width: 8),
              Container(
                width: 88,
                height: 42,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _filterType,
                    isExpanded: true,
                    alignment: Alignment.center,
                    icon: const Icon(
                      Icons.keyboard_arrow_down,
                      color: SellerTheme.navy,
                      size: 20,
                    ),
                    dropdownColor: Colors.white,
                    onChanged: (newValue) {
                      if (newValue == null) return;
                      setState(() => _filterType = newValue);
                      _load();
                    },
                    items: const [
                      DropdownMenuItem(
                        value: 'all',
                        alignment: Alignment.center,
                        child: Center(
                          child: Text(
                            'All',
                            style: TextStyle(
                              color: SellerTheme.navy,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'me',
                        alignment: Alignment.center,
                        child: Center(
                          child: Text(
                            'Me',
                            style: TextStyle(
                              color: SellerTheme.navy,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// หน้าที่: สร้าง UI ส่วน Category Row เพื่อใช้ในหน้าจอนี้ (คลาส _WantedFeedPageState).
  Widget _buildCategoryRow() {
    return SizedBox(
      height: 54,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: ListView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                children: [
                  for (var index = 0; index < _categories.length; index++)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _categoryChip(index),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 42,
              height: 38,
              child: PopupMenuButton<int>(
                tooltip: 'กรองหมวดหมู่',
                padding: EdgeInsets.zero,
                onSelected: (index) =>
                    setState(() => _selectedCategoryIndex = index),
                itemBuilder: (context) => [
                  for (var index = 0; index < _categories.length; index++)
                    PopupMenuItem<int>(
                      value: index,
                      child: Text(
                        _categories[index]['category_name']?.toString() ?? '',
                      ),
                    ),
                ],
                child: Container(
                  decoration: BoxDecoration(
                    color: _selectedCategoryIndex == 0
                        ? Colors.white
                        : const Color(0xFFEAF1FF),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _selectedCategoryIndex == 0
                          ? const Color(0xFFE1E5EB)
                          : const Color(0xFF264C9E),
                    ),
                  ),
                  child: Icon(
                    Icons.filter_list_rounded,
                    size: 20,
                    color: _selectedCategoryIndex == 0
                        ? const Color(0xFF4A5568)
                        : const Color(0xFF264C9E),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// หน้าที่: ประมวลผลขั้นตอน หมวดหมู่สินค้า Chip สำหรับส่วน wanted feed page (คลาส _WantedFeedPageState).
  Widget _categoryChip(int index) {
    final selected = _selectedCategoryIndex == index;
    final icon = switch (index) {
      0 => Icons.apps_rounded,
      1 => Icons.checkroom_outlined,
      2 => Icons.devices_other_outlined,
      3 => Icons.toys_outlined,
      _ => Icons.chair_outlined,
    };

    return Material(
      color: selected ? SellerTheme.navy : Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () => setState(() => _selectedCategoryIndex = index),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? SellerTheme.navy : const Color(0xFFE1E5EB),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: selected ? Colors.white : const Color(0xFF7B8497),
              ),
              const SizedBox(width: 6),
              Text(
                _categories[index]['category_name']?.toString() ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? Colors.white : const Color(0xFF4A5568),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeedCard extends StatelessWidget {
  final dynamic post;
  final bool isOwner;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggleStatus;

  const _FeedCard({
    required this.post,
    required this.isOwner,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleStatus,
  });

  /// หน้าที่: สร้าง UI ของหน้าจอหรือวิดเจ็ตใน wanted feed page (คลาส _FeedCard).
  @override
  Widget build(BuildContext context) {
    final buyerName = post['buyer_name']?.toString() ?? 'ผู้ซื้อ';
    final initial = buyerName.isNotEmpty ? buyerName[0].toUpperCase() : '?';
    final buyerImage = buildImageUrl(
      post['buyer_image_url']?.toString() ?? post['buyer_image']?.toString(),
    );
    final wantedImage = pickWantedImage(post);

    // จัดการรูปแบบเวลา
    String postDate = timeAgo(post['wanted_created_at']?.toString());
    if (postDate.isEmpty) {
      final date = DateTime.tryParse(
        post['wanted_created_at']?.toString() ?? '',
      );
      if (date != null) {
        postDate = '${date.day} ก.ย. ${date.year + 543}';
      }
    }

    final isOpen = post['wanted_status']?.toString() == 'open';
    final budget = double.tryParse(post['budget']?.toString() ?? '0') ?? 0;
    final title = post['title']?.toString() ?? '';
    final description = post['wanted_description']?.toString() ?? '';
    final categoryName = post['category_name']?.toString() ?? '';

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
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Avatar, Name, Time, Menu
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: const Color(0xFFE2E8F0),
                  child: buyerImage == null
                      ? Text(
                          initial,
                          style: const TextStyle(
                            color: Color(0xFF0F172A),
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        )
                      : SizedBox(
                          width: 36,
                          height: 36,
                          child: ClipOval(
                            child: Image.network(
                              buyerImage,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => Center(
                                child: Text(
                                  initial,
                                  style: const TextStyle(
                                    color: Color(0xFF0F172A),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Row(
                    children: [
                      Text(
                        buyerName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        '•',
                        style: TextStyle(color: Colors.grey, fontSize: 10),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        postDate,
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!isOpen)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'ปิดรับแล้ว',
                      style: TextStyle(
                        fontSize: 10,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                if (isOwner)
                  PopupMenuButton<String>(
                    padding: EdgeInsets.zero,
                    icon: const Icon(
                      Icons.more_vert,
                      color: Colors.grey,
                      size: 20,
                    ),
                    onSelected: (value) {
                      switch (value) {
                        case 'edit':
                          onEdit();
                          break;
                        case 'toggle':
                          onToggleStatus();
                          break;
                        case 'delete':
                          onDelete();
                          break;
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.edit_outlined),
                          title: Text('แก้ไข'),
                        ),
                      ),
                      PopupMenuItem(
                        value: 'toggle',
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            isOpen
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                          ),
                          title: Text(
                            isOpen
                                ? 'ปิดโพสต์ / ตั้งเป็นส่วนตัว'
                                : 'เปิดโพสต์อีกครั้ง',
                          ),
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            Icons.delete_outline,
                            color: AppColors.danger,
                          ),
                          title: Text('ลบโพสต์'),
                        ),
                      ),
                    ],
                  ),
              ],
            ),

            const SizedBox(height: 12),

            // Title
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
            ),
            if (categoryName.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: SellerTheme.navyLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  categoryName,
                  style: const TextStyle(
                    color: SellerTheme.navy,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 6),

            // Description
            Text(
              description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontSize: 12,
                height: 1.5,
              ),
            ),
            if (wantedImage != null) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SafeNetworkImage(
                  source: wantedImage,
                  width: double.infinity,
                  height: 150,
                  fit: BoxFit.cover,
                ),
              ),
            ],
            const SizedBox(height: 12),

            const SizedBox(height: 16),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            const SizedBox(height: 12),

            // Footer
            if (isOpen || !isOwner) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'งบประมาณที่ตั้งไว้',
                        style: TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '฿${budget.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: SellerTheme.navy,
                            ),
                          ),
                          const Text(
                            ' / ตัว',
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  if (isOwner)
                    ElevatedButton(
                      onPressed: onTap,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: SellerTheme.navy,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 0,
                        ),
                        minimumSize: const Size(0, 36),
                      ),
                      child: const Text(
                        'ดูข้อเสนอ',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    )
                  else
                    ElevatedButton.icon(
                      onPressed: onTap,
                      icon: const Icon(Icons.add, size: 14),
                      label: Text(
                        isOwner ? 'ดูข้อเสนอ' : 'ดูคอมเมนต์ / เสนอขาย',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: SellerTheme.navy,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 0,
                        ),
                        minimumSize: const Size(0, 36),
                      ),
                    ),
                ],
              ),
            ] else ...[
              // Closed means the request is no longer accepting offers.
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'งบประมาณเดิม',
                        style: TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '฿${budget.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                    ],
                  ),
                  Column(
                    children: const [
                      Text(
                        'ปิดรับแล้ว',
                        style: TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                  InkWell(
                    onTap: onTap,
                    child: const Text(
                      'ดูประวัติ',
                      style: TextStyle(
                        color: Color(0xFF1E293B),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
