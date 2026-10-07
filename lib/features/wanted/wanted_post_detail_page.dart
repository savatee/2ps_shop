import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/image_utils.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/loading_view.dart';
import '../../core/widgets/safe_network_image.dart';
import '../../core/network/api_client.dart';
import '../chat/chat_room_page.dart';

class WantedPostDetailPage extends StatefulWidget {
  final dynamic post;
  final int userId;
  final bool isSeller;
  final Future<void> Function()? onOffer;

  const WantedPostDetailPage({
    super.key,
    required this.post,
    required this.userId,
    this.isSeller = false,
    this.onOffer,
  });

  @override
  State<WantedPostDetailPage> createState() => _WantedPostDetailPageState();
}

class _WantedPostDetailPageState extends State<WantedPostDetailPage> {
  List<dynamic> _offers = [];
  bool _loading = true;

  int get _postId =>
      int.tryParse(widget.post['wanted_post_id'].toString()) ?? 0;

  /// หน้าที่: เตรียมสถานะเริ่มต้นของหน้าจอและเริ่มโหลดข้อมูลที่จำเป็น (คลาส _WantedPostDetailPageState).
  @override
  void initState() {
    super.initState();
    _loadOffers();
  }

  /// หน้าที่: โหลดข้อมูล load ข้อเสนอ และอัปเดตสถานะการแสดงผลของหน้าจอ (คลาส _WantedPostDetailPageState).
  Future<void> _loadOffers() async {
    setState(() => _loading = true);
    final result = await ApiClient.getOffers(_postId, viewerId: widget.userId);
    if (!mounted) return;
    setState(() {
      _offers = result;
      _loading = false;
    });
  }

  /// หน้าที่: เปิดหรือแสดงหน้าต่าง/ส่วน UI สำหรับ open แชท (คลาส _WantedPostDetailPageState).
  Future<void> _openChat(dynamic offer) async {
    if (widget.isSeller) {
      final buyerId = int.tryParse(
        widget.post['wanted_buyer_id']?.toString() ?? '',
      );
      if (buyerId == null || buyerId <= 0 || widget.userId <= 0) return;

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatRoomPage(
            postId: _postId,
            postTitle: widget.post['title']?.toString() ?? '',
            postDescription: widget.post['wanted_description']?.toString(),
            postBudget: widget.post['budget']?.toString(),
            buyerId: buyerId,
            sellerId: widget.userId,
            sellerName: widget.post['buyer_name']?.toString() ?? 'ผู้ซื้อ',
            isSeller: true,
          ),
        ),
      );
      return;
    }
    final sellerId = int.tryParse(offer['user_id'].toString());
    final sellerName = offer['seller_name']?.toString() ?? 'ผู้ขาย';
    if (sellerId == null) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatRoomPage(
          postId: _postId,
          postTitle: widget.post['title']?.toString() ?? '',
          postDescription: widget.post['wanted_description']?.toString(),
          postBudget: widget.post['budget']?.toString(),
          buyerId: widget.userId,
          sellerId: sellerId,
          sellerName: sellerName,
          offerId: offer['comment_id']?.toString(),
          offerPrice: offer['offer_price']?.toString(),
          offerComment: offer['comment_text']?.toString(),
        ),
      ),
    );
  }

  /// หน้าที่: สร้าง UI ของหน้าจอหรือวิดเจ็ตใน wanted post detail page (คลาส _WantedPostDetailPageState).
  @override
  Widget build(BuildContext context) {
    final wantedImage = pickWantedImage(widget.post);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('รายละเอียดโพสต์')),
      body: RefreshIndicator(
        onRefresh: _loadOffers,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.post['title']?.toString() ?? '',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.post['wanted_description']?.toString() ?? '',
                      style: const TextStyle(height: 1.5),
                    ),
                    if (wantedImage != null) ...[
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: SafeNetworkImage(
                          source: wantedImage,
                          width: double.infinity,
                          height: 190,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Text(
                      'งบประมาณ ฿${widget.post['budget'] ?? '0'}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              _loading
                  ? 'กำลังโหลดข้อเสนอ...'
                  : 'ผู้ขายเสนอราคา ${_offers.length} ราย',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 10),
            if (_loading)
              const Padding(padding: EdgeInsets.all(30), child: LoadingView())
            else if (_offers.isEmpty)
              const EmptyState(
                icon: Icons.local_offer_outlined,
                title: 'ยังไม่มีคอมเมนต์หรือข้อเสนอ',
              )
            else
              ..._offers.map(
                (offer) => _OfferCard(
                  offer: offer,
                  isSeller: widget.isSeller,
                  onChat: () => _openChat(offer),
                ),
              ),
            if (widget.isSeller && widget.onOffer != null) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () async {
                    await widget.onOffer?.call();
                    await _loadOffers();
                  },
                  icon: const Icon(Icons.local_offer_outlined),
                  label: const Text('เสนอขายสินค้า'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _OfferCard extends StatelessWidget {
  final dynamic offer;
  final bool isSeller;
  final VoidCallback onChat;

  const _OfferCard({
    required this.offer,
    required this.isSeller,
    required this.onChat,
  });

  /// หน้าที่: สร้าง UI ของหน้าจอหรือวิดเจ็ตใน wanted post detail page (คลาส _OfferCard).
  @override
  Widget build(BuildContext context) {
    final sellerName = offer['seller_name']?.toString() ?? 'ผู้ขาย';
    final initial = sellerName.isNotEmpty ? sellerName[0] : '?';
    final sellerImage = buildImageUrl(offer['seller_image']?.toString());
    final price = offer['offer_price']?.toString() ?? '0';
    final message = offer['comment_text']?.toString() ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: AppColors.primaryLight,
                  child: sellerImage == null
                      ? Text(
                          initial,
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : SizedBox(
                          width: 32,
                          height: 32,
                          child: ClipOval(
                            child: Image.network(
                              sellerImage,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => Center(
                                child: Text(
                                  initial,
                                  style: const TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    sellerName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                Text(
                  '฿$price',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            if (message.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                message,
                style: const TextStyle(fontSize: 13, color: AppColors.textGrey),
              ),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: SecondaryButton(
                label: isSeller ? 'แชทกับผู้ซื้อ' : 'แชทกับผู้ขาย',
                icon: Icons.chat_bubble_outline,
                onPressed: onChat,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
