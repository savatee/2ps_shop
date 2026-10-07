<?php
require_once __DIR__ . '/../config/bootstrap.php';
requireRole($conn, 'admin');

error_reporting(0);
ini_set('display_errors', 0);


while (ob_get_level()) {
    ob_end_clean();
}

$palette = [
    0xFF4338CA, // Indigo
    0xFF0EA5E9, // Sky Blue
    0xFF10B981, // Emerald
    0xFFF59E0B, // Amber
    0xFFEC4899, // Pink
    0xFF8B5CF6, // Purple
    0xFF14B8A6, // Teal
    0xFFF97316  // Orange
];

// Count paid and fulfilled orders consistently with the seller summary.
// ใช้ INNER JOIN orders เพื่อตัดออเดอร์สถานะ pending หรือสถานะอื่นทิ้งไปโดยสิ้นเชิง
$salesSql = "SELECT 
                c.category_id, 
                c.category_name,
                COALESCE((
                    SELECT SUM(oi.subtotal)
                    FROM order_items oi
                    INNER JOIN orders o ON oi.item_order_id = o.order_id
                    INNER JOIN products p ON oi.item_product_id = p.product_id
                    WHERE p.category_id = c.category_id
                      AND o.order_status IN ('paid', 'processing', 'shipping', 'completed')
                ), 0) AS total_sales
             FROM categories c
             WHERE c.category_status = 'active'
             ORDER BY total_sales DESC, c.category_id ASC";

$res = $conn->query($salesSql);

$categoriesList = [];
$totalOverall = 0.0;

if ($res) {
    while ($row = $res->fetch_assoc()) {
        $sales = (float)$row['total_sales'];
        $categoriesList[] = [
            "id"    => (int)$row['category_id'],
            "name"  => $row['category_name'],
            "sales" => $sales,
        ];
        $totalOverall += $sales;
    }
}

// จัดสัดส่วนเปอร์เซ็นต์และชุดสีตามยอดขายจริงที่สำเร็จแล้ว
$finalCategories = [];
for ($i = 0; $i < count($categoriesList); $i++) {
    $item = $categoriesList[$i];
    $percent = 0;
    if ($totalOverall > 0) {
        $percent = (int)round(($item['sales'] / $totalOverall) * 100);
    }
    
    $finalCategories[] = [
        "id"         => $item['id'],
        "name"       => $item['name'],
        "sales"      => $item['sales'],
        "percentage" => $percent,
        "color"      => $palette[$i % count($palette)]
    ];
}

echo json_encode([
    "status"  => "success",
    "success" => true,
    "data"    => [
        "total_categories" => count($finalCategories),
        "total_sales"      => $totalOverall,
        "categories"       => $finalCategories
    ]
], JSON_UNESCAPED_UNICODE);

$conn->close();
exit;
