<?php
require_once __DIR__ . '/../config/bootstrap.php';
requireRole($conn, 'admin');

// ปิดการแสดง Error หน้าเว็บโดยตรง เพื่อป้องกันข้อความขยะแทรกใน JSON
error_reporting(0);
ini_set('display_errors', 0);


// เคลียร์ buffer ป้องกันช่องว่างหรือ whitespace นำหน้า JSON
while (ob_get_level()) {
    ob_end_clean();
}

// -------------------------------------------------------------
// 1. สรุปข้อมูลผู้ใช้ (ตาราง users)
// -------------------------------------------------------------
$totalUsers = 0;
$userRes = $conn->query("SELECT COUNT(*) AS total FROM users");
if ($userRes && $uRow = $userRes->fetch_assoc()) {
    $totalUsers = (int)$uRow['total'];
}

// -------------------------------------------------------------
// 2. สินค้ารออนุมัติ (ตาราง products สถานะ pending)
// -------------------------------------------------------------
$pendingCount = 0;
$pendingSellers = 0;
$pendingRes = $conn->query("
    SELECT 
        COUNT(*) AS cnt, 
        COUNT(DISTINCT product_seller_id) AS sellers_cnt 
    FROM products 
    WHERE product_status = 'pending'
");
if ($pendingRes && $pRow = $pendingRes->fetch_assoc()) {
    $pendingCount = (int)($pRow['cnt'] ?? 0);
    $pendingSellers = (int)($pRow['sellers_cnt'] ?? 0);
}

// -------------------------------------------------------------
// 3. ยอดขายและสถานะคำสั่งซื้อ (ตาราง orders)
// -------------------------------------------------------------
$totalSales = 0.0;
$completedOrders = 0;
$openOrders = 0;

$orderRes = $conn->query("
    SELECT 
        COALESCE(SUM(CASE WHEN order_status IN ('paid', 'processing', 'shipping', 'completed') THEN total_amount ELSE 0 END), 0) AS total_sales,
        COUNT(CASE WHEN order_status IN ('paid', 'processing', 'shipping', 'completed') THEN 1 END) AS completed_cnt,
        COUNT(CASE WHEN order_status IN ('pending', 'processing', 'shipping') THEN 1 END) AS open_cnt
    FROM orders
");

if ($orderRes && $oRow = $orderRes->fetch_assoc()) {
    $totalSales = (float)$oRow['total_sales'];
    $completedOrders = (int)$oRow['completed_cnt'];
    $openOrders = (int)$oRow['open_cnt']; // คำขอ/คำสั่งซื้อที่ยังค้างดำเนินการ
}

// กรณีที่ยังไม่มีคำสั่งซื้อจริง ให้คำนวณมูลค่าสต็อกสินค้า active ในระบบเป็นยอดประเมิน
if ($totalSales == 0) {
    $stockRes = $conn->query("SELECT COALESCE(SUM(product_price * stock), 0) AS est_sales FROM products WHERE product_status = 'active'");
    if ($stockRes && $sRow = $stockRes->fetch_assoc()) {
        $totalSales = (float)$sRow['est_sales'];
    }
}

// -------------------------------------------------------------
// 4. ดึงรายการสินค้าที่รออนุมัติล่าสุด พร้อมรูปภาพ (สูงสุด 5 รายการ)
// -------------------------------------------------------------
$pendingList = [];
$pendingQuery = "
    SELECT 
        p.product_id AS id,
        p.product_name,
        p.product_price AS price,
        COALESCE(u.name, 'ผู้ขาย') AS seller_name,
        (SELECT img.image_data 
         FROM product_images img 
         WHERE img.image_product_id = p.product_id 
         ORDER BY img.image_id ASC 
         LIMIT 1) AS product_image
    FROM products p
    LEFT JOIN users u ON p.product_seller_id = u.user_id
    WHERE p.product_status = 'pending'
    ORDER BY p.product_id DESC
    LIMIT 5
";
$pListRes = $conn->query($pendingQuery);
if ($pListRes) {
    while ($item = $pListRes->fetch_assoc()) {
        $pendingList[] = [
            "id"            => (int)$item['id'],
            "product_name"  => $item['product_name'] ?? '',
            "price"         => (float)($item['price'] ?? 0),
            "seller_name"   => $item['seller_name'],
            "product_image" => $item['product_image'] ?? '',
            "time_ago"      => 'ล่าสุด'
        ];
    }
}

// -------------------------------------------------------------
// 5. ส่งผลลัพธ์โครงสร้าง JSON กลับไปยัง Flutter
// -------------------------------------------------------------
echo json_encode([
    "status"  => "success",
    "success" => true,
    "message" => "โหลดสถิติสำเร็จ",
    "data"    => [
        "sales_overview" => [
            "total_sales"      => $totalSales,
            "completed_orders" => $completedOrders,
            "open_requests"    => $openOrders,
            "month_label"      => "กันยายน 2026"
        ],
        "users_summary" => [
            "total_users"   => $totalUsers,
            "new_this_week" => 0
        ],
        "pending_approval" => [
            "count"         => $pendingCount,
            "sellers_count" => $pendingSellers
        ],
        "pending_products" => $pendingList
    ]
], JSON_UNESCAPED_UNICODE);

$conn->close();
exit;
