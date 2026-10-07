<?php
require_once __DIR__ . '/../config/bootstrap.php';

$email = trim($_POST['email'] ?? '');
$password = $_POST['password'] ?? '';

if ($email === '' || $password === '') {
    errorResponse("กรุณากรอก Email และ Password");
}

$stmt = $conn->prepare("SELECT * FROM users WHERE email = ? LIMIT 1");
if (!$stmt) {
    errorResponse("ไม่สามารถตรวจสอบผู้ใช้ได้", $conn->error);
}

$stmt->bind_param("s", $email);
$stmt->execute();
$result = $stmt->get_result();

if ($result->num_rows === 0) {
    $stmt->close();
    errorResponse("ไม่พบ Email นี้");
}

$userData = $result->fetch_assoc();

if (!password_verify($password, $userData['password'])) {
    $stmt->close();
    errorResponse("รหัสผ่านไม่ถูกต้อง");
}

if (isset($userData['user_status']) && $userData['user_status'] !== 'active') {
    $stmt->close();
    errorResponse("บัญชีนี้ไม่สามารถใช้งานได้");
}

$stmt->close();
try {
    $token = createApiSession((int)$userData['user_id']);
} catch (Throwable $error) {
    errorResponse(
        "ระบบเข้าสู่ระบบยังไม่พร้อม กรุณาลองใหม่หรือติดต่อผู้ดูแลระบบ",
        503,
        $error->getMessage()
    );
}
$userData['api_token'] = $token;

unset($userData['password']);
$conn->close();

echo json_encode([
    "success" => true,
    "message" => "เข้าสู่ระบบสำเร็จ",
    "user"    => $userData
], JSON_UNESCAPED_UNICODE);
