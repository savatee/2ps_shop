/// ประมวลผลขั้นตอน time Ago สำหรับส่วน time utils.
String timeAgo(String? value) {
  if (value == null || value.isEmpty) return '';
  final date = DateTime.tryParse(value);
  if (date == null) return value;
  final diff = DateTime.now().difference(date);
  if (diff.inMinutes < 1) return 'เมื่อสักครู่';
  if (diff.inHours < 1) return '${diff.inMinutes} นาทีที่แล้ว';
  if (diff.inDays < 1) return '${diff.inHours} ชั่วโมงที่แล้ว';
  if (diff.inDays < 30) return '${diff.inDays} วันที่แล้ว';
  return '${date.day}/${date.month}/${date.year}';
}

/// ประมวลผลขั้นตอน short Time สำหรับส่วน time utils.
String shortTime(String? value) {
  if (value == null || value.isEmpty) return '';
  final date = DateTime.tryParse(value);
  if (date == null) return value;
  return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
}
