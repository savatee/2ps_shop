<?php
require_once __DIR__ . '/../config/bootstrap.php';
$authenticatedUser = requireUser($conn);

$rawInput = file_get_contents('php://input');
$jsonInput = json_decode($rawInput, true);

$userId      = (int)$authenticatedUser['user_id'];
$oldPassword = $jsonInput['old_password']  ?? $_POST['old_password']  ?? '';
$newPassword = $jsonInput['new_password']  ?? $_POST['new_password']  ?? '';

if ($oldPassword === '' || $newPassword === '') {
    errorResponse("กรุณากรอกรหัสผ่านให้ครบถ้วน", 400);
}

if (strlen($newPassword) < 6) {
    errorResponse("รหัสผ่านใหม่ต้องมีความยาวอย่างน้อย 6 ตัวอักษร", 400);
}

// 1. ตรวจสอบผู้ใช้และรหัสผ่านเดิม
$stmt = $conn->prepare("SELECT password FROM users WHERE user_id = ? LIMIT 1");
if (!$stmt) {
    errorResponse("SQL Error: " . $conn->error, 500);
}
$stmt->bind_param("i", $userId);
$stmt->execute();
$result = $stmt->get_result();

if ($result->num_rows === 0) {
    $stmt->close();
    errorResponse("ไม่พบผู้ใช้งานนี้ในระบบ", 404);
}

$user = $result->fetch_assoc();
$stmt->close();

if (!password_verify($oldPassword, $user['password'])) {
    $conn->close();
    errorResponse("รหัสผ่านเดิมไม่ถูกต้อง", 400);
}

// 2. แฮชรหัสผ่านใหม่แล้วบันทึก
$hashedPassword = password_hash($newPassword, PASSWORD_DEFAULT);

$updateStmt = $conn->prepare("UPDATE users SET password = ?, user_updated_at = NOW() WHERE user_id = ?");
if (!$updateStmt) {
    $conn->close();
    errorResponse("SQL Prepare Error: " . $conn->error, 500);
}

$updateStmt->bind_param("si", $hashedPassword, $userId);

if ($updateStmt->execute()) {
    $updateStmt->close();
    $conn->close();
    successResponse("เปลี่ยนรหัสผ่านสำเร็จ");
} else {
    $errorMsg = $updateStmt->error;
    $updateStmt->close();
    $conn->close();
    errorResponse("เกิดข้อผิดพลาดในการเปลี่ยนรหัสผ่าน: " . $errorMsg, 500);
}
