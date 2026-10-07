<?php
require_once __DIR__ . '/../config/bootstrap.php';

$action = $_POST['action'] ?? $_GET['action'] ?? '';

switch ($action) {
    case 'get_cart':
        $userId = intval($_GET['user_id'] ?? 0);
        $stmt = $conn->prepare("SELECT c.*, p.product_name,
            COALESCE(v.variant_price, p.product_price) AS product_price,
            CASE WHEN c.cart_variant_id IS NULL THEN p.stock
                 ELSE v.variant_stock END AS stock,
            v.variant_size, v.variant_color,
                p.product_seller_id, s.name AS seller_name,
                (SELECT pi.image_data FROM product_images pi WHERE pi.image_product_id = p.product_id ORDER BY pi.image_id ASC LIMIT 1) AS product_image
                FROM cart c
                INNER JOIN products p ON c.cart_product_id = p.product_id
            LEFT JOIN product_variants v
                ON v.variant_id = c.cart_variant_id
                AND v.variant_product_id = c.cart_product_id
                LEFT JOIN users s ON p.product_seller_id = s.user_id
                WHERE c.cart_user_id = ?
                ORDER BY c.cart_id DESC");
        $stmt->bind_param("i", $userId);
        $stmt->execute();
        $res = $stmt->get_result();
        $cart = [];
        while ($r = $res->fetch_assoc()) { $cart[] = $r; }
        $stmt->close();
        successResponse("โหลดตะกร้าสำเร็จ", $cart);
        break;

    case 'add_to_cart':
        $userId = intval($_POST['user_id'] ?? 0);
        $productId = intval($_POST['product_id'] ?? 0);
        $quantity = intval($_POST['quantity'] ?? 1);
        $variantId = intval($_POST['variant_id'] ?? 0);

        if ($userId <= 0) errorResponse("ไม่พบผู้ใช้");
        if ($productId <= 0) errorResponse("ไม่พบสินค้า");
        if ($quantity < 1) errorResponse("จำนวนสินค้าต้องมากกว่า 0");

        $stmt = $conn->prepare("SELECT stock,
            EXISTS(
                SELECT 1 FROM product_variants
                WHERE variant_product_id = products.product_id
                AND variant_status = 'active'
            ) AS has_variants
            FROM products WHERE product_id = ? LIMIT 1");
        $stmt->bind_param("i", $productId);
        $stmt->execute();
        $product = $stmt->get_result()->fetch_assoc();
        $stmt->close();

        if (!$product) errorResponse("ไม่พบสินค้า");

        if ($variantId > 0) {
            $variantStmt = $conn->prepare(
                "SELECT variant_stock FROM product_variants
                 WHERE variant_id = ? AND variant_product_id = ?
                   AND variant_status = 'active' LIMIT 1"
            );
            $variantStmt->bind_param("ii", $variantId, $productId);
            $variantStmt->execute();
            $variant = $variantStmt->get_result()->fetch_assoc();
            $variantStmt->close();
            if (!$variant) errorResponse("ไม่พบตัวเลือกสินค้านี้");
            $availableStock = intval($variant['variant_stock']);
        } else {
            if (intval($product['has_variants']) === 1) {
                errorResponse("กรุณาเลือกสีหรือไซส์สินค้า");
            }
            $availableStock = intval($product['stock']);
        }

        if ($availableStock < 1) errorResponse("สินค้าหมดสต็อค");

        $cartVariantId = $variantId > 0 ? $variantId : null;
        $stmt = $conn->prepare("SELECT cart_id, cart_quantity FROM cart
                WHERE cart_user_id = ? AND cart_product_id = ?
                  AND cart_variant_id <=> ? LIMIT 1");
        $stmt->bind_param("iii", $userId, $productId, $cartVariantId);
        $stmt->execute();
        $exist = $stmt->get_result()->fetch_assoc();
        $stmt->close();

        if ($exist) {
            $newQty = intval($exist['cart_quantity']) + $quantity;
            if ($newQty > $availableStock) errorResponse("จำนวนสินค้าเกินสต็อคที่มี");

            $stmt = $conn->prepare("UPDATE cart SET cart_quantity = ? WHERE cart_id = ? AND cart_user_id = ?");
            $stmt->bind_param("iii", $newQty, $exist['cart_id'], $userId);
        } else {
                if ($quantity > $availableStock) errorResponse("จำนวนสินค้าเกินสต็อคที่มี");

                $stmt = $conn->prepare("INSERT INTO cart
                    (cart_user_id, cart_product_id, cart_variant_id, cart_quantity)
                    VALUES (?, ?, ?, ?)");
                $stmt->bind_param("iiii", $userId, $productId, $cartVariantId, $quantity);
        }
        $stmt->execute();
        $stmt->close();
        successResponse("เพิ่มสินค้าในตะกร้าสำเร็จ");
        break;

    case 'delete_cart':
        $userId = intval($_POST['user_id'] ?? $_GET['user_id'] ?? 0);
        $cartId = intval($_POST['cart_id'] ?? 0);
        if ($userId <= 0) errorResponse("ไม่พบผู้ใช้");
        if ($cartId <= 0) errorResponse("ไม่พบ Cart ID");

        $stmt = $conn->prepare("DELETE FROM cart WHERE cart_id = ? AND cart_user_id = ?");
        $stmt->bind_param("ii", $cartId, $userId);
        $stmt->execute();
        $affected = $stmt->affected_rows;
        $stmt->close();
        if ($affected <= 0) errorResponse("ไม่พบสินค้าในตะกร้าของคุณ");
        successResponse("ลบสินค้าออกจากตะกร้าสำเร็จ");
        break;

    case 'update_cart':
        $userId = intval($_POST['user_id'] ?? $_GET['user_id'] ?? 0);
        $cartId = intval($_POST['cart_id'] ?? 0);
        $quantity = intval($_POST['quantity'] ?? 0);
        if ($userId <= 0) errorResponse("ไม่พบผู้ใช้");
        if ($cartId <= 0) errorResponse("ไม่พบ Cart ID");

        if ($quantity <= 0) {
            $stmt = $conn->prepare("DELETE FROM cart WHERE cart_id = ? AND cart_user_id = ?");
            $stmt->bind_param("ii", $cartId, $userId);
            $stmt->execute();
            $affected = $stmt->affected_rows;
            $stmt->close();
            if ($affected <= 0) errorResponse("ไม่พบสินค้าในตะกร้าของคุณ");
        } else {
            $stmt = $conn->prepare("SELECT
                    CASE WHEN c.cart_variant_id IS NULL THEN p.stock
                         ELSE v.variant_stock END AS stock
                FROM cart c
                INNER JOIN products p ON c.cart_product_id = p.product_id
                LEFT JOIN product_variants v
                    ON v.variant_id = c.cart_variant_id
                    AND v.variant_product_id = c.cart_product_id
                WHERE c.cart_id = ? AND c.cart_user_id = ? LIMIT 1");
            $stmt->bind_param("ii", $cartId, $userId);
            $stmt->execute();
            $row = $stmt->get_result()->fetch_assoc();
            $stmt->close();

            if (!$row) errorResponse("ไม่พบสินค้าในตะกร้าของคุณ");
            if ($quantity > intval($row['stock'])) errorResponse("จำนวนสินค้าเกินสต็อคที่มี");

            $stmt = $conn->prepare("UPDATE cart SET cart_quantity = ? WHERE cart_id = ? AND cart_user_id = ?");
            $stmt->bind_param("iii", $quantity, $cartId, $userId);
            $stmt->execute();
            $stmt->close();
        }
        successResponse("แก้ไขตะกร้าสำเร็จ");
        break;

    default:
        errorResponse("Invalid cart action");
}
$conn->close();
