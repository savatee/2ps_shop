<?php

// ============================================================
// SELLER API : ตัวรับ request + ส่งต่อไปยังไฟล์ตามหมวด
// Flutter ยังเรียกไฟล์นี้ไฟล์เดียวเหมือนเดิม
// ============================================================

define('SELLER_API', true);

require_once __DIR__ . '/../config/bootstrap.php';
require_once __DIR__ . '/../lib/uploads.php';
require_once __DIR__ . '/includes/helpers.php';
require_once __DIR__ . '/includes/variants.php';

// ให้ mysqli โยน exception เสมอ (แล้วเราจับส่งกลับเป็น JSON แทน HTTP 500 เงียบ ๆ)
mysqli_report(MYSQLI_REPORT_ERROR | MYSQLI_REPORT_STRICT);

$action = $_POST['action'] ?? $_GET['action'] ?? '';

try {


// ------------------------------------------------------------
// action ที่ไม่ต้องตรวจว่าเป็น seller
// ------------------------------------------------------------

$noSellerCheck = [
    'categories',
    'wanted_posts',
    'test',
];

if (!in_array($action, $noSellerCheck, true)) {
    $authenticatedSeller = requireRole($conn, 'seller');
    $GLOBALS['authenticatedSellerId'] = (int)$authenticatedSeller['user_id'];
}

if (!in_array($action, $noSellerCheck, true)) {

    $sellerId = sellerIdValue();

    if ($sellerId <= 0 || !sellerExists($conn, $sellerId)) {
        errorResponse("ไม่พบผู้ขายหรือบัญชีไม่ใช่ seller");
    }
}


// ------------------------------------------------------------
// ตารางส่งต่อ  action => ไฟล์ใน actions/
// ------------------------------------------------------------

$routes = [

    // actions/product.php
    'categories'      => 'product',
    'seller_products' => 'product',
    'add_product'     => 'product',
    'product_variants' => 'product',
    'update_product'  => 'product',
    'delete_product'  => 'product',

    // actions/wanted.php
    'wanted_posts'          => 'wanted',
    'add_wanted_comment'    => 'wanted',

    // actions/chat.php
    'chat_rooms'   => 'chat',
    'messages'     => 'chat',
    'send_message' => 'chat',

    // actions/order.php
    'seller_orders'       => 'order',
    'update_order_status' => 'order',
    'seller_cancel_order' => 'order',

    // actions/sales.php
    'sales_summary' => 'sales',

    // actions/profile.php
    'update_profile'  => 'profile',
];


if ($action === 'test') {

    successResponse(
        "Seller API ทำงานปกติ",
        ["database" => $db]
    );

} elseif (isset($routes[$action])) {

    require __DIR__ . '/actions/' . $routes[$action] . '.php';

} else {

    errorResponse("Invalid action", 400);
}


$conn->close();

} catch (Throwable $e) {

    // Keep internal exception details in the server log only.
    error_log('SELLER API [' . $action . '] ' . $e->getMessage()
        . ' @ ' . basename($e->getFile()) . ':' . $e->getLine());

    errorResponse("เซิร์ฟเวอร์ผิดพลาด กรุณาลองใหม่", 500);
}
