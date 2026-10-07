<?php

header("Content-Type: application/json; charset=UTF-8");

$host = "172.18.111.42";
$user = "6620310006";
$pass = "6620310006";
$db   = "6620310006_2PS-Shop";

$conn = new mysqli($host, $user, $pass, $db);

if ($conn->connect_error) {
    http_response_code(500);
    echo json_encode([
        "success" => false,
        "message" => "Database connection failed"
    ], JSON_UNESCAPED_UNICODE);
    exit;
}

$conn->set_charset("utf8mb4");

$action = $_POST['action'] ?? $_GET['action'] ?? '';

function out($data) {
    echo json_encode($data, JSON_UNESCAPED_UNICODE);
    exit;
}

function idv($key) {
    return intval($_POST[$key] ?? $_GET[$key] ?? 0);
}

function sellerExists(mysqli $conn, int $sellerId): bool {
    $stmt = $conn->prepare(
        "SELECT user_id FROM users WHERE user_id = ? AND role = 'seller' AND user_status = 'active' LIMIT 1"
    );
    $stmt->bind_param("i", $sellerId);
    $stmt->execute();
    return $stmt->get_result()->num_rows > 0;
}

if ($action !== 'categories' && $action !== 'wanted_posts' &&
    $action !== 'chat_rooms' && $action !== 'messages' &&
    $action !== 'seller_profile' && $action !== 'sales_summary' &&
    $action !== 'test') {
    $sellerId = idv('seller_id');
    if ($sellerId > 0 && !sellerExists($conn, $sellerId)) {
        out(["success" => false, "message" => "ไม่พบผู้ขายหรือบัญชีไม่ใช่ seller"]);
    }
}

switch ($action) {

    case 'test':
        out([
            "success" => true,
            "message" => "Seller API ทำงานปกติ",
            "database" => $db
        ]);
        break;

    // -------------------------
    // หมวดหมู่
    // -------------------------
    case 'categories':
        $result = $conn->query(
            "SELECT category_id, category_name
             FROM categories
             WHERE category_status = 'active'
             ORDER BY category_name"
        );

        $rows = [];
        while ($r = $result->fetch_assoc()) $rows[] = $r;

        out(["success" => true, "categories" => $rows]);
        break;

    // -------------------------
    // สินค้าของผู้ขาย
    // -------------------------
    case 'seller_products':
        $sellerId = idv('seller_id');

        $stmt = $conn->prepare(
            "SELECT
                p.product_id,
                p.category_id,
                p.product_name,
                p.product_description,
                p.product_price,
                p.stock,
                p.product_status,
                c.category_name,
                (
                    SELECT TO_BASE64(pi.image_data)
                    FROM product_images pi
                    WHERE pi.image_product_id = p.product_id
                    ORDER BY pi.image_id
                    LIMIT 1
                ) AS image_data
             FROM products p
             JOIN categories c ON c.category_id = p.category_id
             WHERE p.product_seller_id = ?
             ORDER BY p.product_id DESC"
        );

        $stmt->bind_param("i", $sellerId);
        $stmt->execute();
        $result = $stmt->get_result();

        $rows = [];
        while ($r = $result->fetch_assoc()) $rows[] = $r;

        out(["success" => true, "products" => $rows]);
        break;

    // -------------------------
    // เพิ่มสินค้า + รูปภาพ
    // -------------------------
    case 'add_product':
        $sellerId = idv('seller_id');
        $categoryId = idv('category_id');
        $name = trim($_POST['product_name'] ?? '');
        $description = trim($_POST['product_description'] ?? '');
        $price = floatval($_POST['product_price'] ?? 0);
        $stock = intval($_POST['stock'] ?? 0);

        if ($categoryId <= 0 || $name === '' || $price < 0 || $stock < 0) {
            out(["success" => false, "message" => "ข้อมูลสินค้าไม่ครบหรือไม่ถูกต้อง"]);
        }

        $stmt = $conn->prepare(
            "INSERT INTO products
             (product_seller_id, category_id, product_name,
              product_description, product_price, stock, product_status)
             VALUES (?, ?, ?, ?, ?, ?, 'active')"
        );
        $stmt->bind_param(
            "iissdi",
            $sellerId, $categoryId, $name, $description, $price, $stock
        );

        if (!$stmt->execute()) {
            out(["success" => false, "message" => "เพิ่มสินค้าไม่สำเร็จ"]);
        }

        $productId = $conn->insert_id;

        if (isset($_FILES['image']) && $_FILES['image']['error'] === UPLOAD_ERR_OK) {
            $imageData = file_get_contents($_FILES['image']['tmp_name']);

            $img = $conn->prepare(
                "INSERT INTO product_images (image_product_id, image_data)
                 VALUES (?, ?)"
            );
            $img->bind_param("ib", $productId, $imageData);
            $img->send_long_data(1, $imageData);
            $img->execute();
            $img->close();
        }

        // บันทึก stock ครั้งแรก
        if ($stock > 0) {
            $mv = $conn->prepare(
                "INSERT INTO stock_movements
                 (movement_product_id, movement_seller_id, movement_type,
                  movement_quantity, note)
                 VALUES (?, ?, 'IN', ?, 'เพิ่มสินค้าใหม่')"
            );
            $mv->bind_param("iii", $productId, $sellerId, $stock);
            $mv->execute();
        }

        out([
            "success" => true,
            "message" => "โพสต์สินค้าสำเร็จ",
            "product_id" => $productId
        ]);
        break;

    // -------------------------
    // แก้ไขสินค้า
    // -------------------------
    case 'update_product':
        $sellerId = idv('seller_id');
        $productId = idv('product_id');
        $categoryId = idv('category_id');
        $name = trim($_POST['product_name'] ?? '');
        $description = trim($_POST['product_description'] ?? '');
        $price = floatval($_POST['product_price'] ?? 0);
        $stock = intval($_POST['stock'] ?? 0);
        $status = $_POST['product_status'] ?? 'active';

        if (!in_array($status, ['active', 'inactive'], true)) {
            $status = 'active';
        }

        $stmt = $conn->prepare(
            "SELECT stock FROM products
             WHERE product_id = ? AND product_seller_id = ? LIMIT 1"
        );
        $stmt->bind_param("ii", $productId, $sellerId);
        $stmt->execute();
        $oldResult = $stmt->get_result();

        if ($oldResult->num_rows === 0) {
            out(["success" => false, "message" => "ไม่พบสินค้านี้"]);
        }

        $oldStock = intval($oldResult->fetch_assoc()['stock']);

        $stmt = $conn->prepare(
            "UPDATE products
             SET category_id = ?, product_name = ?, product_description = ?,
                 product_price = ?, stock = ?, product_status = ?
             WHERE product_id = ? AND product_seller_id = ?"
        );
        $stmt->bind_param(
            "issdisii",
            $categoryId, $name, $description, $price, $stock, $status,
            $productId, $sellerId
        );

        if (!$stmt->execute()) {
            out(["success" => false, "message" => "แก้ไขสินค้าไม่สำเร็จ"]);
        }

        $diff = $stock - $oldStock;
        if ($diff !== 0) {
            $type = $diff > 0 ? 'IN' : 'OUT';
            $qty = abs($diff);
            $note = 'ปรับสต็อกสินค้า';

            $mv = $conn->prepare(
                "INSERT INTO stock_movements
                 (movement_product_id, movement_seller_id, movement_type,
                  movement_quantity, note)
                 VALUES (?, ?, ?, ?, ?)"
            );
            $mv->bind_param("iisis", $productId, $sellerId, $type, $qty, $note);
            $mv->execute();
        }

        out(["success" => true, "message" => "แก้ไขสินค้าสำเร็จ"]);
        break;

    // -------------------------
    // ลบสินค้า
    // -------------------------
    case 'delete_product':
        $sellerId = idv('seller_id');
        $productId = idv('product_id');

        $stmt = $conn->prepare(
            "UPDATE products
             SET product_status = 'inactive'
             WHERE product_id = ? AND product_seller_id = ?"
        );
        $stmt->bind_param("ii", $productId, $sellerId);

        if ($stmt->execute() && $stmt->affected_rows > 0) {
            out(["success" => true, "message" => "ปิดการขายสินค้าสำเร็จ"]);
        }

        out(["success" => false, "message" => "ลบสินค้าไม่สำเร็จ"]);
        break;

    // -------------------------
    // ลูกค้าตามหาสินค้า
    // -------------------------
    case 'wanted_posts':
        $result = $conn->query(
            "SELECT
                w.wanted_post_id,
                w.wanted_buyer_id,
                u.name AS buyer_name,
                w.title,
                w.wanted_description,
                w.budget,
                w.wanted_status,
                w.wanted_created_at
             FROM wanted_posts w
             JOIN users u ON u.user_id = w.wanted_buyer_id
             ORDER BY w.wanted_post_id DESC"
        );

        $rows = [];
        while ($r = $result->fetch_assoc()) $rows[] = $r;

        out(["success" => true, "posts" => $rows]);
        break;

    // -------------------------
    // เปิดห้องแชท
    // -------------------------
    case 'open_chat':
        $sellerId = idv('seller_id');
        $buyerId = idv('buyer_id');

        $stmt = $conn->prepare(
            "SELECT room_id FROM chat_rooms
             WHERE room_buyer_id = ? AND room_seller_id = ?
             LIMIT 1"
        );
        $stmt->bind_param("ii", $buyerId, $sellerId);
        $stmt->execute();
        $r = $stmt->get_result();

        if ($r->num_rows > 0) {
            out([
                "success" => true,
                "room_id" => intval($r->fetch_assoc()['room_id'])
            ]);
        }

        $stmt = $conn->prepare(
            "INSERT INTO chat_rooms (room_buyer_id, room_seller_id)
             VALUES (?, ?)"
        );
        $stmt->bind_param("ii", $buyerId, $sellerId);

        if ($stmt->execute()) {
            out([
                "success" => true,
                "room_id" => $conn->insert_id
            ]);
        }

        out(["success" => false, "message" => "สร้างห้องแชทไม่สำเร็จ"]);
        break;

    // -------------------------
    // ห้องแชทของผู้ขาย
    // -------------------------
    case 'chat_rooms':
        $sellerId = idv('seller_id');

        $stmt = $conn->prepare(
            "SELECT
                r.room_id,
                r.room_buyer_id,
                u.name AS buyer_name,
                (
                    SELECT m.message
                    FROM messages m
                    WHERE m.message_room_id = r.room_id
                    ORDER BY m.message_id DESC
                    LIMIT 1
                ) AS last_message,
                r.room_updated_at
             FROM chat_rooms r
             JOIN users u ON u.user_id = r.room_buyer_id
             WHERE r.room_seller_id = ?
             ORDER BY r.room_updated_at DESC"
        );
        $stmt->bind_param("i", $sellerId);
        $stmt->execute();
        $result = $stmt->get_result();

        $rows = [];
        while ($r = $result->fetch_assoc()) $rows[] = $r;

        out(["success" => true, "rooms" => $rows]);
        break;

    // -------------------------
    // ข้อความ
    // -------------------------
    case 'messages':
        $roomId = idv('room_id');

        $stmt = $conn->prepare(
            "SELECT message_id, sender_id, message, message_type,
                    message_created_at
             FROM messages
             WHERE message_room_id = ?
             ORDER BY message_id ASC"
        );
        $stmt->bind_param("i", $roomId);
        $stmt->execute();
        $result = $stmt->get_result();

        $rows = [];
        while ($r = $result->fetch_assoc()) $rows[] = $r;

        out(["success" => true, "messages" => $rows]);
        break;

    case 'send_message':
        $roomId = idv('room_id');
        $senderId = idv('sender_id');
        $message = trim($_POST['message'] ?? '');

        if ($message === '') {
            out(["success" => false, "message" => "ข้อความว่าง"]);
        }

        $stmt = $conn->prepare(
            "INSERT INTO messages
             (message_room_id, sender_id, message, message_type)
             VALUES (?, ?, ?, 'text')"
        );
        $stmt->bind_param("iis", $roomId, $senderId, $message);

        if ($stmt->execute()) {
            out(["success" => true, "message" => "ส่งข้อความสำเร็จ"]);
        }

        out(["success" => false, "message" => "ส่งข้อความไม่สำเร็จ"]);
        break;

    // -------------------------
    // คำสั่งซื้อของผู้ขาย
    // -------------------------
    case 'seller_orders':
        $sellerId = idv('seller_id');

        $stmt = $conn->prepare(
            "SELECT
                o.order_id,
                o.order_buyer_id,
                u.name AS buyer_name,
                oi.item_quantity,
                oi.subtotal,
                o.total_amount,
                o.order_status,
                o.order_created_at,
                p.product_name
             FROM order_items oi
             JOIN orders o ON o.order_id = oi.item_order_id
             JOIN users u ON u.user_id = o.order_buyer_id
             JOIN products p ON p.product_id = oi.item_product_id
             WHERE oi.item_seller_id = ?
             ORDER BY o.order_id DESC"
        );
        $stmt->bind_param("i", $sellerId);
        $stmt->execute();
        $result = $stmt->get_result();

        $rows = [];
        while ($r = $result->fetch_assoc()) $rows[] = $r;

        out(["success" => true, "orders" => $rows]);
        break;

    // -------------------------
    // เปลี่ยนสถานะออเดอร์
    // -------------------------
    case 'update_order_status':
        $sellerId = idv('seller_id');
        $orderId = idv('order_id');
        $status = $_POST['order_status'] ?? '';

        $allowed = ['pending', 'paid', 'processing', 'shipping', 'completed', 'cancelled'];
        if (!in_array($status, $allowed, true)) {
            out(["success" => false, "message" => "สถานะไม่ถูกต้อง"]);
        }

        $stmt = $conn->prepare(
            "UPDATE orders o
             SET o.order_status = ?
             WHERE o.order_id = ?
             AND EXISTS (
                 SELECT 1 FROM order_items oi
                 WHERE oi.item_order_id = o.order_id
                 AND oi.item_seller_id = ?
             )"
        );
        $stmt->bind_param("sii", $status, $orderId, $sellerId);

        if ($stmt->execute() && $stmt->affected_rows > 0) {
            out(["success" => true, "message" => "อัปเดตสถานะคำสั่งซื้อสำเร็จ"]);
        }

        out(["success" => false, "message" => "ไม่สามารถอัปเดตคำสั่งซื้อนี้ได้"]);
        break;

    // -------------------------
    // สรุปยอดขาย
    // -------------------------
    case 'sales_summary':
        $sellerId = idv('seller_id');

        $stmt = $conn->prepare(
            "SELECT
                COALESCE(SUM(oi.subtotal), 0) AS total_sales,
                COUNT(DISTINCT o.order_id) AS order_count,
                COALESCE(SUM(oi.item_quantity), 0) AS item_count
             FROM order_items oi
             JOIN orders o ON o.order_id = oi.item_order_id
             WHERE oi.item_seller_id = ?
             AND o.order_status = 'completed'"
        );
        $stmt->bind_param("i", $sellerId);
        $stmt->execute();
        $summary = $stmt->get_result()->fetch_assoc();

        $stmt = $conn->prepare(
            "SELECT
                c.category_name,
                COALESCE(SUM(oi.subtotal), 0) AS sales
             FROM order_items oi
             JOIN orders o ON o.order_id = oi.item_order_id
             JOIN products p ON p.product_id = oi.item_product_id
             JOIN categories c ON c.category_id = p.category_id
             WHERE oi.item_seller_id = ?
             AND o.order_status = 'completed'
             GROUP BY c.category_id, c.category_name
             ORDER BY sales DESC"
        );
        $stmt->bind_param("i", $sellerId);
        $stmt->execute();
        $result = $stmt->get_result();

        $categories = [];
        while ($r = $result->fetch_assoc()) $categories[] = $r;

        out([
            "success" => true,
            "total_sales" => $summary['total_sales'],
            "order_count" => $summary['order_count'],
            "item_count" => $summary['item_count'],
            "categories" => $categories
        ]);
        break;

    // -------------------------
    // โปรไฟล์
    // -------------------------
    case 'seller_profile':
        $userId = idv('user_id');

        $stmt = $conn->prepare(
            "SELECT user_id, name, email, user_phone, role, user_status
             FROM users
             WHERE user_id = ? AND role = 'seller'
             LIMIT 1"
        );
        $stmt->bind_param("i", $userId);
        $stmt->execute();
        $result = $stmt->get_result();

        if ($result->num_rows === 0) {
            out(["success" => false, "message" => "ไม่พบข้อมูลผู้ขาย"]);
        }

        out([
            "success" => true,
            "user" => $result->fetch_assoc()
        ]);
        break;

    case 'update_profile':
        $userId = idv('user_id');
        $name = trim($_POST['name'] ?? '');
        $phone = trim($_POST['user_phone'] ?? '');

        if ($name === '') {
            out(["success" => false, "message" => "กรุณากรอกชื่อ"]);
        }

        $stmt = $conn->prepare(
            "UPDATE users
             SET name = ?, user_phone = ?
             WHERE user_id = ? AND role = 'seller'"
        );
        $stmt->bind_param("ssi", $name, $phone, $userId);

        if ($stmt->execute()) {
            out(["success" => true, "message" => "บันทึกข้อมูลสำเร็จ"]);
        }

        out(["success" => false, "message" => "บันทึกข้อมูลไม่สำเร็จ"]);
        break;

    case 'change_password':
        $userId = idv('user_id');
        $oldPassword = $_POST['old_password'] ?? '';
        $newPassword = $_POST['new_password'] ?? '';

        if ($newPassword === '') {
            out(["success" => false, "message" => "กรุณากรอกรหัสผ่านใหม่"]);
        }

        $stmt = $conn->prepare(
            "SELECT password FROM users
             WHERE user_id = ? AND role = 'seller' LIMIT 1"
        );
        $stmt->bind_param("i", $userId);
        $stmt->execute();
        $result = $stmt->get_result();

        if ($result->num_rows === 0) {
            out(["success" => false, "message" => "ไม่พบผู้ขาย"]);
        }

        $user = $result->fetch_assoc();

        if (!password_verify($oldPassword, $user['password'])) {
            out(["success" => false, "message" => "รหัสผ่านเดิมไม่ถูกต้อง"]);
        }

        $hash = password_hash($newPassword, PASSWORD_DEFAULT);

        $stmt = $conn->prepare(
            "UPDATE users SET password = ?
             WHERE user_id = ? AND role = 'seller'"
        );
        $stmt->bind_param("si", $hash, $userId);
        $stmt->execute();

        out(["success" => true, "message" => "เปลี่ยนรหัสผ่านสำเร็จ"]);
        break;

    default:
        out([
            "success" => false,
            "message" => "Invalid action",
            "action" => $action
        ]);
}

$conn->close();
?>
