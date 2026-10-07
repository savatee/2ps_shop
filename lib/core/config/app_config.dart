/// ค่าตั้งต้นของแอป: แก้ที่นี่ที่เดียวเมื่อย้ายเซิร์ฟเวอร์หรือเปลี่ยนโฟลเดอร์
///
/// โครงสร้างบนเซิร์ฟเวอร์ (โฟลเดอร์ Final):
///   Final/backend/api/...  -> API (PHP)
///   Final/uploads/...      -> รูปที่อัปโหลด
class AppConfig {
  static const String serverOrigin = 'https://std.mcs.psu.ac.th';

  /// โฟลเดอร์โปรเจกต์บนเซิร์ฟเวอร์ (ที่มี backend/ และ uploads/ อยู่ข้างใน)
  static const String projectPath = '/6620310006/html/Final';

  static const String appBaseUrl = '$serverOrigin$projectPath';
  static const String uploadsBaseUrl = '$appBaseUrl/uploads/';
  static const String productImagesUrl = '${uploadsBaseUrl}product/';
  static const String apiBaseUrl = '$appBaseUrl/backend/api';
  static const String authApiBaseUrl = '$apiBaseUrl/auth';
  static const String adminApiBaseUrl = '$apiBaseUrl/admin';
  static const String sellerApiUrl = '$apiBaseUrl/seller/seller_api.php';
}
