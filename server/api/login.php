<?php
require_once '../config/db.php';
$email = trim($_POST['email'] ?? '');
$password = $_POST['password'] ?? '';
if ($email === '' || $password === '') errorResponse('กรุณากรอกอีเมลและรหัสผ่าน');
$stmt = $conn->prepare('SELECT user_id,name,email,user_phone,profile_image,role,user_status,user_created_at,user_updated_at,password FROM users WHERE email=? LIMIT 1');
$stmt->bind_param('s',$email); $stmt->execute(); $user=$stmt->get_result()->fetch_assoc(); $stmt->close();
if (!$user) errorResponse('ไม่พบอีเมลนี้');
if (!password_verify($password,$user['password'])) errorResponse('รหัสผ่านไม่ถูกต้อง');
if ($user['user_status'] !== 'active') errorResponse('บัญชีนี้ไม่สามารถใช้งานได้');
if ($user['role'] !== 'seller') errorResponse('ระบบนี้สำหรับบัญชีผู้ขายเท่านั้น');
unset($user['password']);
echo json_encode(['success'=>true,'message'=>'เข้าสู่ระบบผู้ขายสำเร็จ','user'=>$user],JSON_UNESCAPED_UNICODE);
$conn->close();
