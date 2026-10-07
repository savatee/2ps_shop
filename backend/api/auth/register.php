<?php
require_once __DIR__ . '/../config/bootstrap.php';

$name = trim($_POST['name'] ?? '');
$email = trim($_POST['email'] ?? '');
$password = $_POST['password'] ?? '';
$phone = trim($_POST['phone'] ?? '');
$role = trim($_POST['role'] ?? 'buyer');

$allowedRoles = ['buyer', 'seller'];
if (!in_array($role, $allowedRoles)) {
    $role = 'buyer';
}

if ($name === '' || $email === '' || $password === '') {
    errorResponse("กรุณากรอกข้อมูลให้ครบ");
}

$stmt = $conn->prepare("SELECT user_id FROM users WHERE email = ? LIMIT 1");
$stmt->bind_param("s", $email);
$stmt->execute();
if ($stmt->get_result()->num_rows > 0) {
    $stmt->close();
    errorResponse("Email นี้มีผู้ใช้งานแล้ว");
}
$stmt->close();

$hashedPassword = password_hash($password, PASSWORD_DEFAULT);
$status = "active";

$stmt = $conn->prepare("
    INSERT INTO users (name, email, password, user_phone, role, user_status)
    VALUES (?, ?, ?, ?, ?, ?)
");
$stmt->bind_param("ssssss", $name, $email, $hashedPassword, $phone, $role, $status);

if (!$stmt->execute()) {
    $error = $stmt->error;
    $stmt->close();
    errorResponse("สมัครสมาชิกไม่สำเร็จ", $error);
}

$userId = $stmt->insert_id;
$stmt->close();
$conn->close();

successResponse("สมัครสมาชิกสำเร็จ", [
    "user_id" => $userId,
    "name"    => $name,
    "email"   => $email,
    "role"    => $role
]);
