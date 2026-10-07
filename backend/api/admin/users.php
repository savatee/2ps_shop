<?php
require_once __DIR__ . '/../config/bootstrap.php';
requireRole($conn, 'admin');

error_reporting(0);
ini_set('display_errors', 0);


while (ob_get_level()) {
    ob_end_clean();
}

$method = $_SERVER['REQUEST_METHOD'];
$rawInput = json_decode(file_get_contents("php://input"), true) ?? [];

// -------------------------------------------------------------
// 1. POST: อัปเดตสถานะ (Status) หรือ สิทธิ์ (Role)
// -------------------------------------------------------------
if ($method === 'POST') {
    $userId = intval($_POST['user_id'] ?? $rawInput['user_id'] ?? 0);
    $action = trim($_POST['action'] ?? $rawInput['action'] ?? '');

    if ($userId <= 0) {
        echo json_encode(["status" => "error", "success" => false, "message" => "รหัสผู้ใช้ไม่ถูกต้อง"], JSON_UNESCAPED_UNICODE);
        exit;
    }

    // 1.1 เปลี่ยนสถานะผู้ใช้ (active / suspended / inactive)
    if ($action === 'update_status') {
        $inputStatus = strtolower(trim($_POST['status'] ?? $rawInput['status'] ?? ''));
        $newStatus = ($inputStatus === 'suspended' || $inputStatus === 'inactive') ? 'inactive' : 'active';
        
        $stmt = $conn->prepare("UPDATE users SET user_status = ? WHERE user_id = ?");
        $stmt->bind_param("si", $newStatus, $userId);
        
        if ($stmt->execute()) {
            echo json_encode([
                "status"     => "success",
                "success"    => true,
                "message"    => "อัปเดตสถานะเป็น $newStatus สำเร็จ",
                "new_status" => $newStatus
            ], JSON_UNESCAPED_UNICODE);
        } else {
            echo json_encode(["status" => "error", "success" => false, "message" => "SQL Error: " . $conn->error], JSON_UNESCAPED_UNICODE);
        }
        $stmt->close();
        $conn->close();
        exit;
    }

    // 1.2 เปลี่ยนสิทธิ์ผู้ใช้ (buyer / seller / admin)
    if ($action === 'update_role') {
        $inputRole = strtolower(trim($_POST['role'] ?? $rawInput['role'] ?? 'buyer'));
        $validRoles = ['buyer', 'seller', 'admin'];
        $newRole = in_array($inputRole, $validRoles) ? $inputRole : 'buyer';
        
        $stmt = $conn->prepare("UPDATE users SET role = ? WHERE user_id = ?");
        $stmt->bind_param("si", $newRole, $userId);
        
        if ($stmt->execute()) {
            echo json_encode([
                "status"   => "success",
                "success"  => true,
                "message"  => "ปรับเปลี่ยนสิทธิ์เป็น $newRole สำเร็จ",
                "new_role" => $newRole
            ], JSON_UNESCAPED_UNICODE);
        } else {
            echo json_encode(["status" => "error", "success" => false, "message" => "SQL Error: " . $conn->error], JSON_UNESCAPED_UNICODE);
        }
        $stmt->close();
        $conn->close();
        exit;
    }

    echo json_encode(["status" => "error", "success" => false, "message" => "ไม่พบคำสั่ง action ที่ระบุ"], JSON_UNESCAPED_UNICODE);
    $conn->close();
    exit;
}


// -------------------------------------------------------------
// 2. GET: ดึงรายชื่อผู้ใช้งาน (ค้นหา, กรองสิทธิ์ และกรองสถานะ)
// -------------------------------------------------------------
$keyword = trim($_GET['keyword'] ?? $_GET['search'] ?? $rawInput['keyword'] ?? $rawInput['search'] ?? '');
$roleFilter = strtolower(trim($_GET['role'] ?? $rawInput['role'] ?? 'all'));
$statusFilter = strtolower(trim($_GET['status'] ?? $rawInput['status'] ?? 'all'));

// แก้ไขจุดที่ 1: ดึงคอลัมน์ profile_image (หรือ user_image) ออกมาด้วย
$sql = "SELECT user_id, name, email, user_phone, profile_image, role, user_status FROM users WHERE 1=1";
$params = [];
$types = "";

// ค้นหาชื่อ เบอร์ หรืออีเมล
if (!empty($keyword)) {
    $sql .= " AND (name LIKE ? OR user_phone LIKE ? OR email LIKE ?)";
    $kw = "%" . $keyword . "%";
    $params[] = $kw;
    $params[] = $kw;
    $params[] = $kw;
    $types .= "sss";
}

// กรองตามสิทธิ์
if (!empty($roleFilter) && $roleFilter !== 'all') {
    $sql .= " AND LOWER(TRIM(role)) = ?";
    $params[] = $roleFilter;
    $types .= "s";
}

// กรองตามสถานะบัญชี
if (!empty($statusFilter) && $statusFilter !== 'all') {
    if ($statusFilter === 'active') {
        $sql .= " AND LOWER(TRIM(user_status)) = 'active'";
    } else {
        $sql .= " AND (LOWER(TRIM(user_status)) IN ('inactive', 'suspended') OR user_status IS NULL OR user_status = '')";
    }
}

$sql .= " ORDER BY user_id DESC";

if (!empty($params)) {
    $stmt = $conn->prepare($sql);
    $stmt->bind_param($types, ...$params);
    $stmt->execute();
    $result = $stmt->get_result();
} else {
    $result = $conn->query($sql);
}

if (!$result) {
    http_response_code(500);
    echo json_encode(["status" => "error", "success" => false, "message" => $conn->error], JSON_UNESCAPED_UNICODE);
    exit;
}

$users = [];
while ($row = $result->fetch_assoc()) {
    $displayName = !empty($row['name']) ? $row['name'] : (!empty($row['email']) ? $row['email'] : 'ผู้ใช้งาน');
    $initials = mb_substr($displayName, 0, 2, 'UTF-8');
    
    $rawStatus = strtolower(trim($row['user_status'] ?? 'active'));
    $normalizedStatus = ($rawStatus === 'inactive' || $rawStatus === 'suspended') ? 'inactive' : 'active';

    // แก้ไขจุดที่ 2: แนบ profile_image ส่งออกไปใน JSON
    $users[] = [
        "user_id"        => (int)$row['user_id'],
        "name"           => $displayName,
        "email"          => $row['email'] ?? '',
        "user_phone"     => $row['user_phone'] ?? '',
        "profile_image"  => $row['profile_image'] ?? $row['user_image'] ?? '',
        "role"           => strtolower(trim($row['role'] ?? 'buyer')),
        "user_status"    => $normalizedStatus,
        "activity_count" => 0,
        "initials"       => $initials,
    ];
}

echo json_encode([
    "status"  => "success",
    "success" => true,
    "message" => "โหลดรายชื่อผู้ใช้สำเร็จ",
    "data"    => $users
], JSON_UNESCAPED_UNICODE);

$conn->close();
exit;
