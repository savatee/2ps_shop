<?php
require_once __DIR__ . '/../config/bootstrap.php';
$authenticatedUser = requireUser($conn);

// รองรับทั้ง Form-Data, URL Query Parameter และ Raw JSON
$rawInput = file_get_contents('php://input');
$jsonInput = json_decode($rawInput, true) ?? [];

$action = $_POST['action'] ?? $_GET['action'] ?? $jsonInput['action'] ?? '';

// ถ้าไม่ได้ระบุ action แต่ส่ง user_id มา ให้กำหนด action เป็น get_user อัตโนมัติ
if (empty($action) && (isset($_GET['user_id']) || isset($_POST['user_id']) || isset($jsonInput['user_id']))) {
    $action = 'get_user';
}

switch ($action) {

    case 'get_user':
        $requestedUserId = (int)($_GET['user_id'] ?? $_POST['user_id'] ?? $jsonInput['user_id'] ?? 0);
        $userId = $requestedUserId > 0
            ? $requestedUserId
            : (int)$authenticatedUser['user_id'];
        $isOwnProfile = $userId === (int)$authenticatedUser['user_id'];

        $columns = $isOwnProfile
            ? 'user_id, name, email, user_phone, profile_image, role, user_status, user_created_at, user_updated_at'
            : 'user_id, name, profile_image, role, user_status';
        $stmt = $conn->prepare("SELECT $columns FROM users WHERE user_id = ? LIMIT 1");
        $stmt->bind_param("i", $userId);
        $stmt->execute();
        $userData = $stmt->get_result()->fetch_assoc();
        $stmt->close();

        if (!$userData) {
            errorResponse("ไม่พบข้อมูลผู้ใช้", 404);
        }
        
        successResponse("โหลดข้อมูลสำเร็จ", $userData);
        break;

    case 'update_user':
        $userId = (int)$authenticatedUser['user_id'];
        $name   = trim($_POST['name'] ?? $jsonInput['name'] ?? '');
        $email  = trim($_POST['email'] ?? $jsonInput['email'] ?? '');
        $phone  = trim($_POST['phone'] ?? $_POST['user_phone'] ?? $jsonInput['phone'] ?? $jsonInput['user_phone'] ?? '');

        if ($name === '' || $email === '') {
            errorResponse("ข้อมูลไม่ครบถ้วน", 400);
        }

        $stmt = $conn->prepare("UPDATE users SET name = ?, email = ?, user_phone = ?, user_updated_at = NOW() WHERE user_id = ?");
        $stmt->bind_param("sssi", $name, $email, $phone, $userId);
        
        if (!$stmt->execute()) {
            $err = $stmt->error;
            $stmt->close();
            errorResponse("แก้ไขข้อมูลไม่สำเร็จ: " . $err, 500);
        }
        $stmt->close();
        successResponse("แก้ไขข้อมูลสำเร็จ");
        break;

    default:
        errorResponse("Invalid user action", 400);
}

$conn->close();
