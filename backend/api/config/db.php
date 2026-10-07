<?php
ini_set('display_errors', 0);
ini_set('display_startup_errors', 0);
error_reporting(E_ALL);

// ค่าเชื่อมต่อฐานข้อมูล: อ่านจากตัวแปรสภาพแวดล้อม หรือไฟล์ config/config.local.php
// (ดูตัวอย่างที่ config.local.example.php)
$host = trim(appConfig('DB_HOST'));
$user = trim(appConfig('DB_USER'));
$pass = appConfig('DB_PASSWORD');
$db   = trim(appConfig('DB_NAME'));

if ($host === '' || $user === '' || $pass === '' || $db === '') {
    http_response_code(500);
    echo json_encode([
        'status'  => 'error',
        'success' => false,
        'message' => 'Server database configuration is missing',
    ], JSON_UNESCAPED_UNICODE);
    exit;
}

// PHP 8.1+ จะโยน exception เมื่อเชื่อมต่อไม่ได้ ต้องดักไว้เพื่อให้ตอบกลับเป็น JSON
// (ไม่เช่นนั้นเซิร์ฟเวอร์จะส่งหน้า HTML 500 ซึ่งแอปอ่านไม่ได้)
try {
    $conn = new mysqli($host, $user, $pass, $db);
} catch (Throwable $e) {
    error_log('Database connection failed: ' . $e->getMessage());
    http_response_code(500);
    echo json_encode([
        'status'  => 'error',
        'success' => false,
        'message' => 'ไม่สามารถเชื่อมต่อฐานข้อมูลได้',
    ], JSON_UNESCAPED_UNICODE);
    exit;
}

if ($conn->connect_error) {
    error_log('Database connection failed: ' . $conn->connect_error);
    http_response_code(500);
    echo json_encode([
        'status'  => 'error',
        'success' => false,
        'message' => 'ไม่สามารถเชื่อมต่อฐานข้อมูลได้',
    ], JSON_UNESCAPED_UNICODE);
    exit;
}

$conn->set_charset('utf8mb4');