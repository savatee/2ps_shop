import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/image_utils.dart';
import '../../core/utils/time_utils.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../core/widgets/loading_view.dart';
import '../../core/network/api_client.dart';
import 'chat_message_content.dart';
import '../buyer/buyer_product_detail_page.dart';
import '../wanted/wanted_post_detail_page.dart';
import '../seller/seller_theme.dart';

class ChatRoomPage extends StatefulWidget {
  final int postId;
  final String? postTitle;
  final String? postDescription;
  final String? postBudget;
  final int buyerId;
  final int sellerId;
  final String sellerName;
  final bool isSeller;
  final int? initialChatId;
  final String? prefilledMessage;
  final String? offerId;
  final String? offerPrice;
  final String? offerComment;
  final int? shareProductId;
  final String? shareProductName;

  const ChatRoomPage({
    super.key,
    required this.postId,
    this.postTitle,
    this.postDescription,
    this.postBudget,
    required this.buyerId,
    required this.sellerId,
    required this.sellerName,
    this.isSeller = false,
    this.initialChatId,
    this.prefilledMessage,
    this.offerId,
    this.offerPrice,
    this.offerComment,
    this.shareProductId,
    this.shareProductName,
  });

  @override
  State<ChatRoomPage> createState() => _ChatRoomPageState();
}

class _ChatRoomPageState extends State<ChatRoomPage> {
  static const _thaiMonths = [
    'มกราคม',
    'กุมภาพันธ์',
    'มีนาคม',
    'เมษายน',
    'พฤษภาคม',
    'มิถุนายน',
    'กรกฎาคม',
    'สิงหาคม',
    'กันยายน',
    'ตุลาคม',
    'พฤศจิกายน',
    'ธันวาคม',
  ];

  String get _wantedContextMarker =>
      '[โพสต์ตามหาสินค้า:${widget.postId}:ข้อเสนอ:${widget.offerId ?? 0}]';

  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _picker = ImagePicker();

  int? _chatId;
  List<dynamic> _messages = [];
  Uint8List? _selectedImage;
  bool _loading = true;
  bool _sending = false;
  bool _refreshing = false;
  bool _hasSharedProduct = false;
  bool _wantedContextSent = false;
  String? _initError;

  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _messageController.text = widget.prefilledMessage ?? '';
    _init();

    // โหลดข้อความใหม่ทุก 3 วิ โดยไม่รบกวนตำแหน่งเลื่อนถ้าไม่ได้อ่านอยู่ที่ล่างสุด
    _refreshTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted && !_sending && _chatId != null) {
        _loadMessages(forceScroll: false);
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    setState(() {
      _loading = true;
      _initError = null;
    });

    final chatResult = widget.initialChatId == null
        ? await ApiClient.getOrCreateChat(
            postId: widget.postId,
            buyerId: widget.buyerId,
            sellerId: widget.sellerId,
          )
        : {'success': true, 'data': {'chat_id': widget.initialChatId}};

    if (!mounted) return;

    if (chatResult['success'] != true) {
      setState(() {
        _loading = false;
        _initError = chatResult['message']?.toString() ?? 'เปิดแชทไม่สำเร็จ';
      });
      return;
    }

    final chatId = int.tryParse(
      chatResult['data']?['chat_id']?.toString() ?? '',
    );
    if (chatId == null) {
      setState(() {
        _loading = false;
        _initError = 'เปิดแชทไม่สำเร็จ';
      });
      return;
    }

    setState(() => _chatId = chatId);
    await _loadMessages(forceScroll: true);

    if (widget.shareProductId != null && !_hasSharedProduct) {
      _hasSharedProduct = true;
      await _send(productId: widget.shareProductId);
    }
  }

  Future<void> _loadMessages({bool forceScroll = true}) async {
    if (_chatId == null || _refreshing) return;
    _refreshing = true;

    final result = await ApiClient.getMessages(
      _chatId!,
      readerId: _activeUserId,
    );
    _refreshing = false;
    if (!mounted) return;

    final countBefore = _messages.length;
    setState(() {
      _messages = result;
      _wantedContextSent = result.any((message) {
        final senderId = int.tryParse(message['sender_id']?.toString() ?? '');
        final text = message['message']?.toString() ?? '';
        return senderId == _activeUserId &&
            text.contains(_wantedContextMarker);
      });
      _loading = false;
    });

    if (forceScroll) {
      _scrollToBottom();
    } else if (result.length > countBefore) {
      // มีข้อความใหม่ เพิ่งเลื่อนลงถ้าผู้ใช้กำลังอ่านอยู่แถวล่างสุด
      _maybeScrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    });
  }

  void _maybeScrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final position = _scrollController.position;
      // ถ้าห่างจากล่างสุดไม่เกิน 120px ให้เลื่อนตามข้อความใหม่
      if (position.maxScrollExtent - position.pixels < 120) {
        _scrollController.jumpTo(position.maxScrollExtent);
      }
    });
  }

  String? _messageWithWantedContext(String? text) {
    final userText = text?.trim();
    if (!_hasWantedContext || _wantedContextSent) return userText;

    final contextLines = <String>[_wantedContextMarker];
    final title = widget.postTitle?.trim();
    final description = widget.postDescription?.trim();
    final budget = widget.postBudget?.trim();
    final offerPrice = widget.offerPrice?.trim();
    final offerComment = widget.offerComment?.trim();

    if (title?.isNotEmpty == true) contextLines.add('ชื่อสินค้า: $title');
    if (description?.isNotEmpty == true) {
      contextLines.add('รายละเอียด: $description');
    }
    if (budget?.isNotEmpty == true) contextLines.add('งบประมาณ: ฿$budget');
    if (offerPrice?.isNotEmpty == true || offerComment?.isNotEmpty == true) {
      contextLines.add('[ข้อเสนอจากผู้ขาย]');
      if (offerPrice?.isNotEmpty == true) {
        contextLines.add('ราคาเสนอ: ฿$offerPrice');
      }
      if (offerComment?.isNotEmpty == true) {
        contextLines.add('คอมเมนต์: $offerComment');
      }
    }

    final messageContext = contextLines.join('\n');
    if (userText == null || userText.isEmpty) return messageContext;
    return '$messageContext\n\nข้อความ: $userText';
  }

  Future<void> _send({
    String? text,
    String? imageBase64,
    int? productId,
  }) async {
    if (_chatId == null) return;
    final messageText = _messageWithWantedContext(text);
    final includesWantedContext =
        _hasWantedContext && !_wantedContextSent && messageText != null;
    if ((messageText == null || messageText.trim().isEmpty) &&
        imageBase64 == null &&
        productId == null) {
      return;
    }

    if (includesWantedContext) _wantedContextSent = true;
    setState(() => _sending = true);

    Map<String, dynamic> result;
    try {
      result = await ApiClient.sendMessage(
        chatId: _chatId!,
        senderId: _activeUserId,
        message: messageText,
        imageBase64: imageBase64,
        productId: productId,
      );
    } catch (e) {
      debugPrint('ส่งข้อความผิดพลาด: $e');
      if (includesWantedContext) _wantedContextSent = false;
      if (!mounted) return;
      setState(() => _sending = false);
      showAppSnackBar(context, 'ส่งข้อความไม่สำเร็จ', isError: true);
      return;
    }

    if (!mounted) return;
    setState(() => _sending = false);

    if (result['success'] == true) {
      setState(() {
        _messageController.clear();
        if (imageBase64 != null) _selectedImage = null;
      });
      _loadMessages(forceScroll: true);
    } else {
      if (includesWantedContext) _wantedContextSent = false;
      showAppSnackBar(
        context,
        result['message']?.toString() ?? 'ส่งข้อความไม่สำเร็จ',
        isError: true,
      );
    }
  }

  /// เปิดโพสต์ตามหาสินค้าจริง: ดึงข้อมูลล่าสุดจากฐานข้อมูล
  /// ถ้าดึงไม่ได้จะใช้ข้อมูลที่อยู่ในแชทเป็นตัวสำรอง
  Future<void> _openWantedPost(
    int postId, {
    Map<String, dynamic>? fallback,
  }) async {
    if (postId <= 0) return;
    Map<String, dynamic>? post;
    try {
      final result = await ApiClient.getWantedPost(
        postId,
        viewerId: _activeUserId,
      );
      final data = result['data'];
      if (result['success'] == true && data is Map) {
        post = Map<String, dynamic>.from(data);
      } else if (result['success'] != true && fallback == null) {
        if (!mounted) return;
        showAppSnackBar(
          context,
          result['message']?.toString() ?? 'ไม่พบโพสต์นี้',
          isError: true,
        );
        return;
      }
    } catch (_) {
      // ใช้ข้อมูลสำรองด้านล่าง
    }
    post ??= fallback;
    if (post == null || !mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            WantedPostDetailPage(
              post: post,
              userId: _activeUserId,
              isSeller: widget.isSeller,
            ),
      ),
    );
  }

  int get _activeUserId => widget.isSeller ? widget.sellerId : widget.buyerId;

  Future<void> _pickImage() async {
    if (_sending) return;
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1280,
      maxHeight: 1280,
      imageQuality: 70,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    setState(() => _selectedImage = bytes);
  }

  Future<void> _sendComposerMessage() async {
    if (_sending) return;
    final text = _messageController.text;
    final image = _selectedImage;
    if (text.trim().isEmpty && image == null) return;
    await _send(
      text: text,
      imageBase64: image == null ? null : base64Encode(image),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SellerTheme.background,
      appBar: AppBar(
        backgroundColor: SellerTheme.navy,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.sellerName, style: const TextStyle(fontSize: 16)),
            if (widget.postTitle != null && widget.postTitle!.isNotEmpty)
              Text(
                widget.postTitle!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, color: Colors.white70),
              ),
          ],
        ),
      ),
      body: Column(
        children: [
          if (_hasWantedContext) _buildWantedContext(),
          Expanded(child: _buildBody()),
          if (_chatId != null) _buildComposer(),
        ],
      ),
    );
  }

  bool get _hasWantedContext =>
      widget.postTitle?.trim().isNotEmpty == true ||
      widget.postDescription?.trim().isNotEmpty == true ||
      widget.postBudget?.trim().isNotEmpty == true ||
      widget.offerPrice?.trim().isNotEmpty == true ||
      widget.offerComment?.trim().isNotEmpty == true;

  Widget _buildWantedContext() {
    final description = widget.postDescription?.trim();
    final budget = widget.postBudget?.trim();
    final offerComment = widget.offerComment?.trim();

    final canOpenPost = widget.postId > 0;
    final card = Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'โพสต์ตามหาสินค้า',
                  style: TextStyle(
                    color: SellerTheme.navy,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (canOpenPost)
                const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'ดูโพสต์',
                      style: TextStyle(
                        color: SellerTheme.navy,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 16,
                      color: SellerTheme.navy,
                    ),
                  ],
                ),
            ],
          ),
          if (widget.postTitle?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 3),
            Text(
              widget.postTitle!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
          if (description?.isNotEmpty == true) ...[
            const SizedBox(height: 3),
            Text(description!, maxLines: 2, overflow: TextOverflow.ellipsis),
          ],
          if (budget?.isNotEmpty == true) ...[
            const SizedBox(height: 3),
            Text('งบประมาณ ฿$budget'),
          ],
          if (widget.offerPrice?.trim().isNotEmpty == true ||
              offerComment?.isNotEmpty == true) ...[
            const Divider(height: 16),
            const Text(
              'ข้อเสนอจากผู้ขาย',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
            if (widget.offerPrice?.trim().isNotEmpty == true)
              Text(
                'ราคาเสนอ ฿${widget.offerPrice}',
                style: const TextStyle(
                  color: SellerTheme.navy,
                  fontWeight: FontWeight.w600,
                ),
              ),
            if (offerComment?.isNotEmpty == true)
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text(offerComment!),
              ),
          ],
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      child: canOpenPost
          ? Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(AppRadius.md),
                onTap: () => _openWantedPost(
                  widget.postId,
                  fallback: {
                    'wanted_post_id': widget.postId,
                    'title': widget.postTitle ?? '',
                    'wanted_description': widget.postDescription ?? '',
                    'budget': widget.postBudget ?? '0',
                    'wanted_status': 'open',
                  },
                ),
                child: card,
              ),
            )
          : card,
    );
  }

  Widget _buildBody() {
    if (_loading) return const LoadingView();

    if (_initError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.wifi_off_outlined,
                size: 40,
                color: AppColors.textGrey,
              ),
              const SizedBox(height: 12),
              Text(
                _initError!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textGrey),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: 160,
                child: SecondaryButton(label: 'ลองใหม่', onPressed: _init),
              ),
            ],
          ),
        ),
      );
    }

    if (_messages.isEmpty) {
      return Center(
        child: Text(
          widget.isSeller ? 'เริ่มต้นทักทายผู้ซื้อได้เลย' : 'เริ่มต้นทักทายผู้ขายได้เลย',
          style: TextStyle(color: AppColors.textGrey),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[index];
        final messageDate = DateTime.tryParse(
          message['message_created_at']?.toString() ?? '',
        );
        final previousDate = index > 0
            ? DateTime.tryParse(
                _messages[index - 1]['message_created_at']?.toString() ?? '',
              )
            : null;
        final startsNewDay =
            messageDate != null &&
            (index == 0 ||
                previousDate == null ||
                messageDate.year != previousDate.year ||
                messageDate.month != previousDate.month ||
                messageDate.day != previousDate.day);
        final isMine =
            int.tryParse(message['sender_id']?.toString() ?? '') ==
            _activeUserId;
        return Column(
          children: [
            if (startsNewDay) _buildDateSeparator(messageDate),
            _MessageBubble(
              message: message,
              isMine: isMine,
              buyerId: _activeUserId,
              onOpenWantedPost: (id, fallback) =>
                  _openWantedPost(id, fallback: fallback),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDateSeparator(DateTime date) {
    final label =
        'วันที่ ${date.day} ${_thaiMonths[date.month - 1]} ${date.year + 543}';

    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 12),
      child: Center(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.border,
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textGrey,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildComposer() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 6,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_selectedImage != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 8, 0),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.memory(
                      _selectedImage!,
                      width: 64,
                      height: 64,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'รูปภาพที่เลือก',
                      style: TextStyle(fontSize: 13, color: Colors.black54),
                    ),
                  ),
                  IconButton(
                    tooltip: 'ลบรูปภาพ',
                    onPressed: _sending
                        ? null
                        : () => setState(() => _selectedImage = null),
                    icon: const Icon(Icons.close, color: Colors.black54),
                  ),
                ],
              ),
            ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: _sending ? null : _pickImage,
                    icon: const Icon(
                      Icons.image_outlined,
                      color: SellerTheme.navy,
                    ),
                  ),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7F8FA),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: AppColors.border, width: 1.2),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: TextField(
                        controller: _messageController,
                        minLines: 1,
                        maxLines: 4,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _sendComposerMessage(),
                        style: const TextStyle(fontSize: 14),
                        decoration: const InputDecoration(
                          hintText: 'พิมพ์ข้อความ...',
                          hintStyle: TextStyle(
                            color: Color(0xFF9AA1AE),
                            fontSize: 14,
                          ),
                          isDense: true,
                          filled: false,
                          contentPadding: EdgeInsets.symmetric(vertical: 11),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          disabledBorder: InputBorder.none,
                          errorBorder: InputBorder.none,
                          focusedErrorBorder: InputBorder.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    onPressed: _sending ? null : _sendComposerMessage,
                    icon: const Icon(Icons.send, color: SellerTheme.navy),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final dynamic message;
  final bool isMine;
  final int buyerId;
  final void Function(int postId, Map<String, dynamic> fallback)
  onOpenWantedPost;

  const _MessageBubble({
    required this.message,
    required this.isMine,
    required this.buyerId,
    required this.onOpenWantedPost,
  });

  /// แสดงรูปข้อความ แบบปลอดภัย:
  /// - รูปใหม่ที่ส่งเป็น base64 -> Image.memory
  /// - ข้อมูลเก่าที่เก็บเป็น path/URL -> Image.network
  /// - ถ้าแปลงไม่ได้จะข้าม ไม่ทำให้หน้าจอแดง
  Widget? _messageImage(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final value = raw.trim();

    final Widget fallback = Container(
      width: 180,
      color: const Color(0xFFF1F3F6),
      alignment: Alignment.center,
      child: const Icon(
        Icons.image_not_supported_outlined,
        color: Color(0xFFB4BBC5),
      ),
    );

    if (isImagePath(value)) {
      final url = buildImageUrl(value);
      if (url == null) return null;
      return ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Image.network(
          url,
          width: 180,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => fallback,
        ),
      );
    }

    try {
      final bytes = base64Decode(value);
      return ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Image.memory(
          bytes,
          width: 180,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => fallback,
        ),
      );
    } catch (_) {
      // base64 ไม่ถูกต้อง (ข้อมูลเก่าที่ถูกบันทึกเสีย) -> ข้ามรูปไป
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = message['message']?.toString();
    final time = shortTime(message['message_created_at']?.toString());
    final messageType = message['message_type']?.toString();
    final productIdRaw = message['message_product_id']?.toString();
    final isProductShare =
        messageType == 'product' &&
        productIdRaw != null &&
        productIdRaw.isNotEmpty &&
        productIdRaw != 'null';
    final productId = int.tryParse(productIdRaw ?? '');
    final image = _messageImage(message['message_image']?.toString());

    final bubble = Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.66,
      ),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isMine ? SellerTheme.navy : Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isProductShare)
            InkWell(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              onTap: productId == null
                  ? null
                  : () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => BuyerProductDetailPage(
                            productId: productId,
                            userId: buyerId,
                          ),
                        ),
                      );
                    },
              child: Container(
                padding: const EdgeInsets.all(8),
                margin: EdgeInsets.only(
                  bottom: (text != null && text.isNotEmpty || image != null)
                      ? 8
                      : 0,
                ),
                decoration: BoxDecoration(
                  color: isMine
                      ? Colors.white.withValues(alpha: .14)
                      : SellerTheme.backgroundLight,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.inventory_2_outlined,
                      size: 16,
                      color: isMine ? Colors.white : SellerTheme.navy,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'แชร์สินค้า #$productIdRaw',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: isMine ? Colors.white : SellerTheme.navy,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.chevron_right,
                      size: 14,
                      color: isMine ? Colors.white70 : AppColors.textGrey,
                    ),
                  ],
                ),
              ),
            ),
          if (image != null) ...[
            image,
            if (text != null && text.isNotEmpty) const SizedBox(height: 8),
          ],
          if (text != null && text.isNotEmpty)
            ChatMessageContent(
              text: text,
              isMine: isMine,
              onWantedPostTap: (post) {
                final id = int.tryParse('${post['wanted_post_id']}');
                if (id != null) onOpenWantedPost(id, post);
              },
            ),
        ],
      ),
    );

    final row = Row(
      mainAxisAlignment: isMine
          ? MainAxisAlignment.end
          : MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [Flexible(child: bubble)],
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        crossAxisAlignment: isMine
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          row,
          Padding(
            padding: EdgeInsets.only(
              top: 2,
              left: isMine ? 0 : 32,
              right: isMine ? 4 : 0,
            ),
            child: Text(
              time,
              style: const TextStyle(fontSize: 10, color: AppColors.textGrey),
            ),
          ),
        ],
      ),
    );
  }
}
