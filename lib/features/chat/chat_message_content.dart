import 'package:flutter/material.dart';

import '../seller/seller_theme.dart';

class ChatMessageContent extends StatelessWidget {
  final String text;
  final bool isMine;
  final ValueChanged<Map<String, dynamic>>? onWantedPostTap;

  const ChatMessageContent({
    super.key,
    required this.text,
    required this.isMine,
    this.onWantedPostTap,
  });

  /// หน้าที่: แปลงหรืออ่านข้อมูล parse ข้อความ ให้อยู่ในรูปแบบที่แอปใช้งานได้ (คลาส ChatMessageContent).
  _ParsedChatMessage _parseMessage() {
    final lines = text.split('\n');
    final hasContext = lines.any(
      (line) => line.trim().startsWith('[โพสต์ตามหาสินค้า:'),
    );
    if (!hasContext) return _ParsedChatMessage.plain(text);

    final fields = <String, String>{};
    final messageLines = <String>[];
    int? postId;
    String? activeField;
    var inOffer = false;
    var inUserMessage = false;

    /// หน้าที่: ประมวลผลขั้นตอน append สำหรับส่วน chat message content (คลาส ChatMessageContent).
    void append(String key, String value) {
      if (value.isEmpty) return;
      final previous = fields[key];
      fields[key] = previous == null ? value : '$previous\n$value';
    }

    /// หน้าที่: ประมวลผลขั้นตอน read Field สำหรับส่วน chat message content (คลาส ChatMessageContent).
    void readField(String line, String label, String key) {
      activeField = key;
      append(key, line.substring(label.length).trim());
    }

    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.startsWith('[โพสต์ตามหาสินค้า:')) {
        final match = RegExp(
          r'^\[โพสต์ตามหาสินค้า:(\d+):ข้อเสนอ:\d+\]$',
        ).firstMatch(line);
        postId = int.tryParse(match?.group(1) ?? '');
        continue;
      }
      if (line == '[ข้อเสนอจากผู้ขาย]') {
        inOffer = true;
        activeField = null;
        continue;
      }
      if (line.startsWith('ชื่อสินค้า:')) {
        readField(line, 'ชื่อสินค้า:', 'title');
        continue;
      }
      if (line.startsWith('รายละเอียด:')) {
        readField(line, 'รายละเอียด:', 'description');
        continue;
      }
      if (line.startsWith('งบประมาณ:')) {
        readField(line, 'งบประมาณ:', 'budget');
        continue;
      }
      if (line.startsWith('ราคาเสนอ:')) {
        readField(line, 'ราคาเสนอ:', 'offerPrice');
        continue;
      }
      if (line.startsWith('คอมเมนต์:')) {
        readField(line, 'คอมเมนต์:', 'comment');
        continue;
      }
      if (line.startsWith('ข้อความ:')) {
        inUserMessage = true;
        activeField = null;
        final message = line.substring('ข้อความ:'.length).trim();
        if (message.isNotEmpty) messageLines.add(message);
        continue;
      }
      if (line.isEmpty) continue;

      final field = activeField;
      if (inUserMessage) {
        messageLines.add(rawLine);
      } else if (field != null) {
        append(field, line);
      } else if (inOffer) {
        append('comment', line);
      }
    }

    return _ParsedChatMessage(
      hasContext: true,
      postId: postId,
      title: fields['title'],
      description: fields['description'],
      budget: fields['budget'],
      offerPrice: fields['offerPrice'],
      comment: fields['comment'],
      message: messageLines.join('\n').trim(),
    );
  }

  /// หน้าที่: สร้าง UI ของหน้าจอหรือวิดเจ็ตใน chat message content (คลาส ChatMessageContent).
  @override
  Widget build(BuildContext context) {
    final parsed = _parseMessage();
    final foreground = isMine ? Colors.white : SellerTheme.textPrimary;
    final secondary = isMine ? Colors.white70 : SellerTheme.textSecondary;
    final dividerColor = isMine
        ? Colors.white.withValues(alpha: 0.25)
        : SellerTheme.border;

    if (!parsed.hasContext) {
      return Text(text, style: TextStyle(color: foreground, fontSize: 14));
    }

    final postId = parsed.postId;
    final canOpenPost = postId != null && onWantedPostTap != null;
    final budget = parsed.budget?.replaceFirst(RegExp(r'^฿\s*'), '') ?? '0';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: canOpenPost
              ? () => onWantedPostTap!({
                  'wanted_post_id': postId,
                  'title': parsed.title ?? '',
                  'wanted_description': parsed.description ?? '',
                  'budget': budget,
                  'wanted_status': 'open',
                })
              : null,
          borderRadius: BorderRadius.circular(4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.search_rounded, size: 15, color: secondary),
                  const SizedBox(width: 5),
                  Text(
                    'โพสต์ตามหาสินค้า',
                    style: TextStyle(
                      color: secondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (canOpenPost) ...[
                    const SizedBox(width: 4),
                    Icon(Icons.open_in_new, size: 13, color: secondary),
                  ],
                ],
              ),
              if (parsed.title?.isNotEmpty == true) ...[
                const SizedBox(height: 5),
                Text(
                  parsed.title!,
                  style: TextStyle(
                    color: foreground,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              if (parsed.description?.isNotEmpty == true) ...[
                const SizedBox(height: 4),
                Text(
                  parsed.description!,
                  style: TextStyle(
                    color: foreground,
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
              ],
              if (parsed.budget?.isNotEmpty == true) ...[
                const SizedBox(height: 6),
                _detailLine('งบประมาณ', parsed.budget!, foreground, secondary),
              ],
              if (parsed.offerPrice?.isNotEmpty == true ||
                  parsed.comment?.isNotEmpty == true) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Divider(height: 1, color: dividerColor),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.local_offer_outlined,
                      size: 15,
                      color: secondary,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'ข้อเสนอจากผู้ขาย',
                      style: TextStyle(
                        color: foreground,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                if (parsed.offerPrice?.isNotEmpty == true) ...[
                  const SizedBox(height: 4),
                  _detailLine(
                    'ราคาเสนอ',
                    parsed.offerPrice!,
                    foreground,
                    secondary,
                  ),
                ],
                if (parsed.comment?.isNotEmpty == true) ...[
                  const SizedBox(height: 3),
                  _detailLine(
                    'รายละเอียด',
                    parsed.comment!,
                    foreground,
                    secondary,
                  ),
                ],
              ],
            ],
          ),
        ),
        if (parsed.message.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Divider(height: 1, color: dividerColor),
          ),
          Text(
            parsed.message,
            style: TextStyle(color: foreground, fontSize: 14, height: 1.35),
          ),
        ],
      ],
    );
  }

  /// หน้าที่: ประมวลผลขั้นตอน รายละเอียด บรรทัด สำหรับส่วน chat message content (คลาส ChatMessageContent).
  Widget _detailLine(
    String label,
    String value,
    Color foreground,
    Color secondary,
  ) {
    return RichText(
      text: TextSpan(
        style: TextStyle(color: foreground, fontSize: 12.5, height: 1.3),
        children: [
          TextSpan(
            text: '$label: ',
            style: TextStyle(color: secondary, fontWeight: FontWeight.w600),
          ),
          TextSpan(
            text: value,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _ParsedChatMessage {
  final bool hasContext;
  final int? postId;
  final String? title;
  final String? description;
  final String? budget;
  final String? offerPrice;
  final String? comment;
  final String message;

  const _ParsedChatMessage({
    required this.hasContext,
    this.postId,
    this.title,
    this.description,
    this.budget,
    this.offerPrice,
    this.comment,
    this.message = '',
  });

  const _ParsedChatMessage.plain(String message)
    : this(hasContext: false, message: message);
}
