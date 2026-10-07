import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';
import '../../core/utils/time_utils.dart';
import '../../core/widgets/empty_state.dart';
import 'chat_room_page.dart';
import '../seller/api/seller_api.dart';
import '../seller/seller_theme.dart';

class ChatListPage extends StatefulWidget {
  final int userId;
  final bool isSeller;
  final int? initialRoomId;

  const ChatListPage({
    super.key,
    required this.userId,
    this.isSeller = false,
    this.initialRoomId,
  });

  @override
  State<ChatListPage> createState() => _ChatListPageState();
}

class _ChatListPageState extends State<ChatListPage> {
  List<dynamic> _chats = [];
  bool _loading = true;
  bool _failed = false;
  bool _openedInitial = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });

    try {
      final result = widget.isSeller
          ? await SellerApi.chatRooms(widget.userId)
          : await ApiClient.getBuyerChats(widget.userId);

      if (!mounted) return;

      final groupedChats = <String, Map<String, dynamic>>{};
      for (final item in result) {
        if (item is! Map) continue;

        final chat = Map<String, dynamic>.from(item);
        final participantId = widget.isSeller
            ? chat['room_buyer_id']?.toString() ?? ''
            : chat['room_seller_id']?.toString() ??
                  chat['seller_id']?.toString() ??
                  '';
        if (participantId.isEmpty) continue;

        final existing = groupedChats[participantId];
        final currentTime = _chatTime(chat);
        if (existing == null || _isNewer(currentTime, _chatTime(existing))) {
          groupedChats[participantId] = chat;
        } else {
          final existingUnread =
              int.tryParse(existing['unread_count']?.toString() ?? '0') ?? 0;
          final currentUnread =
              int.tryParse(chat['unread_count']?.toString() ?? '0') ?? 0;
          if (currentUnread > existingUnread) {
            existing['unread_count'] = currentUnread;
          }
        }
      }

      final chats = groupedChats.values.toList()
        ..sort((a, b) => _chatTime(b).compareTo(_chatTime(a)));

      setState(() {
        _chats = chats;
        _loading = false;
        _failed = false;
      });

      if (!_openedInitial && widget.initialRoomId != null) {
        final room = chats.cast<Map<String, dynamic>?>().firstWhere(
          (chat) => int.tryParse('${chat?['room_id']}') == widget.initialRoomId,
          orElse: () => null,
        );
        if (room != null) {
          _openedInitial = true;
          openChat(room);
        }
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _chats = [];
        _loading = false;
        _failed = true;
      });
    }
  }

  String _chatTime(Map<String, dynamic> chat) => widget.isSeller
      ? chat['room_updated_at']?.toString() ?? ''
      : chat['last_message_at']?.toString() ??
            chat['room_created_at']?.toString() ??
            '';

  Future<void> openChat(Map<String, dynamic> chat) async {
    if (widget.isSeller) {
      final roomId = int.tryParse('${chat['room_id']}') ?? 0;
      final buyerId = int.tryParse('${chat['room_buyer_id']}') ?? 0;
      if (roomId <= 0 || buyerId <= 0) return;

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatRoomPage(
            postId: int.tryParse('${chat['room_post_id'] ?? 0}') ?? 0,
            postTitle: '',
            buyerId: buyerId,
            sellerId: widget.userId,
            sellerName: chat['buyer_name']?.toString() ?? 'ผู้ซื้อ',
            isSeller: true,
            initialChatId: roomId,
          ),
        ),
      );
    } else {
      final sellerId = int.tryParse(
        chat['room_seller_id']?.toString() ??
            chat['seller_id']?.toString() ??
            '',
      );
      if (sellerId == null) return;

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatRoomPage(
            postId: int.tryParse('${chat['room_post_id'] ?? 0}') ?? 0,
            postTitle: '',
            buyerId: widget.userId,
            sellerId: sellerId,
            sellerName: chat['seller_name']?.toString() ?? 'ผู้ขาย',
          ),
        ),
      );
    }

    if (mounted) _load();
  }

  bool _isNewer(String newTime, String oldTime) {
    if (newTime.isEmpty) return false;
    if (oldTime.isEmpty) return true;

    final newDate = DateTime.tryParse(newTime);
    final oldDate = DateTime.tryParse(oldTime);

    if (newDate == null) return false;
    if (oldDate == null) return true;

    return newDate.isAfter(oldDate);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SellerTheme.backgroundLight,
      appBar: SellerTheme.appBar(widget.isSeller ? 'แชทกับลูกค้า' : 'แชท'),
      body: _loading
          ? SellerTheme.loading()
          : _chats.isEmpty
          ? EmptyState(
              icon: Icons.chat_bubble_outline,
              title: 'ยังไม่มีการสนทนา',
              subtitle: _failed
                  ? 'เชื่อมต่อเซิร์ฟเวอร์ไม่ได้ ลองเช็คอินเทอร์เน็ตแล้วกดโหลดใหม่'
                  : 'เริ่มแชทได้จากหน้ารายละเอียดสินค้า หรือหน้าข้อเสนอในโพสต์ตามหาสินค้า',
              actionLabel: 'โหลดใหม่',
              onAction: _load,
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 4),
                itemCount: _chats.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final chat = _chats[index];
                  final participantName = widget.isSeller
                      ? chat['buyer_name']?.toString() ?? 'ผู้ซื้อ'
                      : chat['seller_name']?.toString() ?? 'ผู้ขาย';
                  final imagePath = widget.isSeller
                      ? chat['buyer_image']?.toString()
                      : chat['seller_image']?.toString();
                  final imageUrl = SellerApi.imageUrl(imagePath);
                  final lastMessage = chat['last_message']?.toString().trim();
                  final preview = lastMessage?.isNotEmpty == true
                      ? lastMessage!
                      : 'เริ่มการสนทนาแล้ว';
                  final unread =
                      int.tryParse(chat['unread_count']?.toString() ?? '0') ??
                      0;
                  final time = timeAgo(_chatTime(chat));
                  final initial = participantName.isNotEmpty
                      ? participantName[0].toUpperCase()
                      : '?';

                  return Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(SellerTheme.radiusCard),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(
                        SellerTheme.radiusCard,
                      ),
                      onTap: () => openChat(chat),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(
                            SellerTheme.radiusCard,
                          ),
                          border: Border.all(color: SellerTheme.border),
                        ),
                        child: Row(
                          children: [
                            ClipOval(
                              child: imageUrl == null
                                  ? _avatarFallback(initial)
                                  : Image.network(
                                      imageUrl,
                                      width: 50,
                                      height: 50,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, _, _) =>
                                          _avatarFallback(initial),
                                    ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    participantName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: unread > 0
                                          ? FontWeight.w800
                                          : FontWeight.w600,
                                      color: SellerTheme.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    preview,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: SellerTheme.bodySecondary,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  time,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: SellerTheme.textSecondary,
                                  ),
                                ),
                                if (unread > 0) ...[
                                  const SizedBox(height: 6),
                                  Container(
                                    constraints: const BoxConstraints(
                                      minWidth: 20,
                                      minHeight: 20,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: const BoxDecoration(
                                      color: SellerTheme.navy,
                                      shape: BoxShape.circle,
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      unread > 99 ? '99+' : '$unread',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.chevron_right,
                              color: SellerTheme.textLight,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }

  Widget _avatarFallback(String initial) {
    return Container(
      width: 50,
      height: 50,
      alignment: Alignment.center,
      color: SellerTheme.navyLight,
      child: Text(
        initial,
        style: const TextStyle(
          color: SellerTheme.navy,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
