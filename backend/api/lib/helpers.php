<?php

// อ่านค่าตั้งค่า: ตัวแปรสภาพแวดล้อมก่อน แล้วค่อยดูใน config/config.local.php
function appConfig(string $key, string $default = ''): string
{
    static $local = null;

    if ($local === null) {
        $local = [];
        $file = __DIR__ . '/../config/config.local.php';
        if (is_file($file)) {
            $loaded = require $file;
            if (is_array($loaded)) {
                $local = $loaded;
            }
        }
    }

    $env = getenv($key);
    if ($env !== false && $env !== '') {
        return $env;
    }

    return isset($local[$key]) ? (string)$local[$key] : $default;
}

// หน้าที่: อ่านเบอร์ PromptPay ของร้านจากค่าตั้งค่าเซิร์ฟเวอร์.
function getShopPromptPayPhone(): string
{
    return trim(appConfig('PROMPTPAY_PHONE'));
}

// หน้าที่: ส่ง JSON สถานะสำเร็จและข้อมูลกลับไปยังแอป แล้วจบคำขอ.
function successResponse($message, $data = null)
{
    http_response_code(200);
    $result = [
        'status' => 'success',
        'success' => true,
        'message' => $message,
    ];
    if ($data !== null) {
        $result['data'] = $data;
    }
    echo json_encode($result, JSON_UNESCAPED_UNICODE);
    exit;
}

// หน้าที่: ส่ง JSON แจ้งข้อผิดพลาดพร้อม HTTP status code แล้วจบคำขอ.
function errorResponse($message, $code = 400, $error = null)
{
    if (!is_numeric($code)) {
        $error = $code;
        $code = 400;
    }
    $statusCode = (int)$code;
    if ($error !== null || $statusCode >= 500) {
        $details = is_scalar($error) ? (string)$error : json_encode($error);
        error_log('API error: ' . $message . ' | ' . ($details ?: 'server error'));
    }
    if ($statusCode >= 500) {
        $message = 'เซิร์ฟเวอร์ผิดพลาด กรุณาลองใหม่';
    }

    http_response_code($statusCode);
    echo json_encode([
        'status' => 'error',
        'success' => false,
        'message' => $message,
    ], JSON_UNESCAPED_UNICODE);
    exit;
}

// หน้าที่: อ่านและตรวจสอบ Bearer token จากส่วนหัวคำขอเพื่อยืนยันตัวตน.
function apiBearerToken(): string
{
    $headers = function_exists('getallheaders') ? getallheaders() : [];
    $header = $_SERVER['HTTP_AUTHORIZATION']
        ?? $_SERVER['REDIRECT_HTTP_AUTHORIZATION']
        ?? '';
    if ($header === '' && is_array($headers)) {
        foreach ($headers as $name => $value) {
            if (strtolower((string)$name) === 'authorization') {
                $header = (string)$value;
                break;
            }
        }
    }
    if (!preg_match('/^Bearer\s+([a-f0-9]{32})$/i', $header, $matches)) {
        errorResponse('ไม่พบ token สำหรับยืนยันตัวตน กรุณาเข้าสู่ระบบใหม่', 401);
    }

    return strtolower($matches[1]);
}

// หน้าที่: เริ่ม session โดยใช้ token เพื่อให้ API อ่านข้อมูลบัญชีได้.
function startApiSession(string $token): void
{
    if (session_status() === PHP_SESSION_ACTIVE) {
        session_write_close();
    }

    ini_set('session.use_cookies', '0');
    ini_set('session.use_only_cookies', '0');
    ini_set('session.use_strict_mode', '0');
    ini_set('session.gc_maxlifetime', (string)(30 * 24 * 60 * 60));
    session_id($token);

    if (!session_start()) {
        errorResponse('ไม่สามารถเริ่มเซสชันได้', 503);
    }
}

// หน้าที่: สร้าง token และ session สำหรับบัญชีผู้ใช้หลังเข้าสู่ระบบ.
function createApiSession(int $userId): string
{
    $token = bin2hex(random_bytes(16));
    startApiSession($token);
    $_SESSION['api_user_id'] = $userId;
    $_SESSION['api_issued_at'] = time();
    if (!session_write_close()) {
        throw new RuntimeException('PHP could not persist the API session');
    }

    return $token;
}

// หน้าที่: ตรวจ token และดึงข้อมูลบัญชีผู้ใช้จากฐานข้อมูล.
function requireUser(mysqli $conn): array
{
    $token = apiBearerToken();
    startApiSession($token);
    $userId = (int)($_SESSION['api_user_id'] ?? 0);
    $issuedAt = (int)($_SESSION['api_issued_at'] ?? 0);
    session_write_close();

    if ($userId <= 0 || $issuedAt <= 0 || $issuedAt + (30 * 24 * 60 * 60) < time()) {
        errorResponse('ไม่พบเซสชันบนเซิร์ฟเวอร์ กรุณาออกจากระบบแล้วเข้าสู่ระบบใหม่', 401);
    }

    $stmt = $conn->prepare(
        "SELECT user_id, role FROM users
         WHERE user_id = ? AND user_status = 'active'
         LIMIT 1"
    );
    if (!$stmt) {
        errorResponse('ไม่สามารถตรวจสอบสิทธิ์ได้', 500, $conn->error);
    }
    $stmt->bind_param('i', $userId);
    $stmt->execute();
    $user = $stmt->get_result()->fetch_assoc();
    $stmt->close();

    if (!$user) {
        errorResponse('กรุณาเข้าสู่ระบบ', 401);
    }

    return $user;
}

// หน้าที่: ตรวจว่าบัญชีที่เข้าสู่ระบบมีบทบาทตรงกับที่ API อนุญาต.
function requireRole(mysqli $conn, string $role): array
{
    $user = requireUser($conn);
    if (strtolower((string)$user['role']) !== strtolower($role)) {
        errorResponse('ไม่มีสิทธิ์เข้าถึง', 403);
    }

    return $user;
}
