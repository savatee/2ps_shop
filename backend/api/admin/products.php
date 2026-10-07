<?php
require_once __DIR__ . '/../config/bootstrap.php';
requireRole($conn, 'admin');

error_reporting(0);
ini_set('display_errors', 0);


while (ob_get_level()) {
    ob_end_clean();
}

// ----------------------------------------------------
// 1. อัปเดตสถานะ (POST) - อนุมัติ / ปฏิเสธ
// ----------------------------------------------------
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $rawInput = json_decode(file_get_contents("php://input"), true) ?? [];
    $productId = intval($_POST['product_id'] ?? $rawInput['product_id'] ?? 0);
    $status = trim($_POST['status'] ?? $rawInput['status'] ?? '');
    $action = trim($_POST['action'] ?? $rawInput['action'] ?? '');

    // กำหนดสถานะตามคำสั่งของแอดมิน
    if ($action === 'approve' || $status === 'approved' || $status === 'active') {
        $status = 'active';
    } elseif ($action === 'reject' || $status === 'rejected') {
        $status = 'rejected'; // ใช้ rejected สำหรับแอดมินปฏิเสธ
    }

    if ($productId <= 0 || empty($status)) {
        echo json_encode([
            "status"  => "error",
            "success" => false,
            "message" => "ข้อมูลไม่ครบถ้วนหรือไม่ถูกต้อง"
        ], JSON_UNESCAPED_UNICODE);
        exit;
    }

    $stmt = $conn->prepare("UPDATE products SET product_status = ? WHERE product_id = ?");
    if ($stmt) {
        $stmt->bind_param("si", $status, $productId);
        $stmt->execute();
        $stmt->close();
        echo json_encode([
            "status"     => "success",
            "success"    => true,
            "message"    => "อัปเดตสถานะสินค้าเป็น $status สำเร็จ",
            "new_status" => $status
        ], JSON_UNESCAPED_UNICODE);
    } else {
        echo json_encode([
            "status"  => "error",
            "success" => false,
            "message" => $conn->error
        ], JSON_UNESCAPED_UNICODE);
    }
    $conn->close();
    exit;
}

// ----------------------------------------------------
// 2. ดึงข้อมูลสินค้าและหมวดหมู่ (GET)
// ----------------------------------------------------
$statusFilter = trim($_GET['status'] ?? 'all');
$categoryIdsRaw = trim($_GET['category_ids'] ?? $_GET['category_id'] ?? '');
$search = trim($_GET['search'] ?? $_GET['keyword'] ?? '');

// ดึงหมวดหมู่ทั้งหมด
$categories = [];
$catRes = $conn->query("SELECT category_id, category_name FROM categories ORDER BY category_id ASC");
if ($catRes) {
    while ($cat = $catRes->fetch_assoc()) {
        $categories[] = [
            "id"   => (int)$cat['category_id'],
            "name" => $cat['category_name']
        ];
    }
}

// ดึงสินค้า พร้อมรูปแรกจากตาราง product_images
$sql = "
    SELECT 
        p.product_id,
        p.product_name,
        p.product_description,
        p.product_price,
        p.stock,
        p.product_status,
        p.product_created_at,
        p.category_id,
        COALESCE(c.category_name, 'ทั่วไป') AS category_name,
        COALESCE(u.name, 'ผู้ขาย') AS seller_name,
        COALESCE(u.user_phone, u.email, '-') AS seller_contact,
        (SELECT img.image_data 
         FROM product_images img 
         WHERE img.image_product_id = p.product_id 
         ORDER BY img.image_id ASC 
         LIMIT 1) AS product_image
    FROM products p
    LEFT JOIN categories c ON p.category_id = c.category_id
    LEFT JOIN users u ON p.product_seller_id = u.user_id
    WHERE 1=1
";

// กรองสถานะ (all, pending, active, rejected, inactive)
if (!empty($statusFilter) && $statusFilter !== 'all') {
    $safeStatus = $conn->real_escape_string($statusFilter);
    $sql .= " AND p.product_status = '$safeStatus'";
}

// กรองหลายหมวดหมู่
if (!empty($categoryIdsRaw)) {
    $ids = array_filter(array_map('intval', explode(',', $categoryIdsRaw)));
    if (!empty($ids)) {
        $sql .= " AND p.category_id IN (" . implode(',', $ids) . ")";
    }
}

// ค้นหาชื่อสินค้า หรือชื่อผู้ขาย
if (!empty($search)) {
    $safeSearch = $conn->real_escape_string($search);
    $sql .= " AND (p.product_name LIKE '%$safeSearch%' OR u.name LIKE '%$safeSearch%')";
}

$sql .= " ORDER BY p.product_id DESC";

$result = $conn->query($sql);
$products = [];

if ($result) {
    while ($row = $result->fetch_assoc()) {
        $timeDiff = !empty($row['product_created_at']) ? (time() - strtotime($row['product_created_at'])) : 0;
        if ($timeDiff < 3600) {
            $timeAgo = max(1, floor($timeDiff / 60)) . ' นาทีที่แล้ว';
        } elseif ($timeDiff < 86400) {
            $timeAgo = floor($timeDiff / 3600) . ' ชั่วโมงที่แล้ว';
        } else {
            $timeAgo = floor($timeDiff / 86400) . ' วันที่แล้ว';
        }

        $products[] = [
            "product_id"          => (int)$row['product_id'],
            "product_name"        => $row['product_name'] ?? '',
            "product_description" => $row['product_description'] ?? '',
            "product_image"       => $row['product_image'] ?? '',
            "price"               => (float)($row['product_price'] ?? 0),
            "stock"               => (int)($row['stock'] ?? 0),
            "status"              => $row['product_status'] ?? 'pending',
            "category_id"         => (int)($row['category_id'] ?? 0),
            "category_name"       => $row['category_name'],
            "seller_name"         => $row['seller_name'],
            "seller_contact"      => $row['seller_contact'],
            "time_ago"            => $timeAgo
        ];
    }
}

echo json_encode([
    "status"  => "success",
    "success" => true,
    "data"    => [
        "total"      => count($products),
        "categories" => $categories,
        "products"   => $products
    ]
], JSON_UNESCAPED_UNICODE);

$conn->close();
exit;
