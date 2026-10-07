<?php

defined('SELLER_API') or exit('Forbidden');

// ============================================================
// ORDER ACTIONS
// seller_orders, update_order_status
// ============================================================

switch ($action) {


    // ========================================================
    // SELLER ORDERS
    // ========================================================

    case 'seller_orders':

        $sellerId = sellerIdValue();

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

                p.product_id,
                p.product_name,

                pi.image_data AS product_image_path,

                pay.payment_method,
                pay.payment_status,
                pay.payment_submitted_at,
                EXISTS (
                    SELECT 1 FROM order_items other_item
                    WHERE other_item.item_order_id = o.order_id
                      AND other_item.item_seller_id <> ?
                ) AS has_other_sellers

             FROM order_items oi

             JOIN orders o
               ON o.order_id = oi.item_order_id

             JOIN users u
               ON u.user_id = o.order_buyer_id

             JOIN products p
               ON p.product_id = oi.item_product_id

             LEFT JOIN product_images pi
               ON pi.image_id = (
                   SELECT MIN(pi2.image_id)
                   FROM product_images pi2
                   WHERE pi2.image_product_id = p.product_id
              )

             LEFT JOIN payments pay
               ON pay.payment_id = (
                   SELECT MAX(pay2.payment_id)
                   FROM payments pay2
                   WHERE pay2.payment_order_id = o.order_id
              )

             WHERE oi.item_seller_id = ?

             ORDER BY o.order_id DESC"
        );

        $stmt->bind_param("ii", $sellerId, $sellerId);
        $stmt->execute();

        $result = $stmt->get_result();

        $rows = [];

        while ($r = $result->fetch_assoc()) {

            $r['order_id']       = intval($r['order_id']);
            $r['order_buyer_id'] = intval($r['order_buyer_id']);
            $r['item_quantity']  = intval($r['item_quantity']);
            $r['subtotal']       = floatval($r['subtotal']);
            $r['total_amount']   = floatval($r['total_amount']);
            $r['product_id']     = intval($r['product_id']);

            // product image
            $imagePath = $r['product_image_path'] ?? null;

            if ($imagePath !== null) {
                $imagePath = trim($imagePath);
            }

            if ($imagePath === '') {
                $imagePath = null;
            }

            $r['product_image_path'] = $imagePath;
            $r['product_image_url']  = imageUrlFromPath($imagePath);

            // ตั้งค่า slip เป็น null ไว้ก่อน เนื่องจากตาราง payments ไม่มีคอลัมน์เก็บไฟล์สลิปโดยตรง
            $r['payment_slip_path'] = null;
            $r['payment_slip_url']  = null;

            $rows[] = $r;
        }

        $stmt->close();

        successResponse("สำเร็จ", ["orders" => $rows]);

        break;


    // ========================================================
    // UPDATE ORDER STATUS
    // ========================================================

    case 'update_order_status':

        $sellerId = sellerIdValue();
        $orderId  = idv('order_id');
        $status   = $_POST['order_status'] ?? '';

        $allowed = [
            'pending',
            'paid',
            'processing',
            'shipping',
            'completed',
        ];

        if (!in_array($status, $allowed, true)) {
            errorResponse("สถานะไม่ถูกต้อง");
        }

        $stmt = $conn->prepare(
            "UPDATE orders o

             SET o.order_status = ?

             WHERE o.order_id = ?

               AND EXISTS (
                    SELECT 1
                    FROM order_items oi
                    WHERE oi.item_order_id = o.order_id
                      AND oi.item_seller_id = ?
               )"
        );

        $stmt->bind_param("sii", $status, $orderId, $sellerId);

        if ($stmt->execute() && $stmt->affected_rows > 0) {

            $stmt->close();

            // ผู้ขายยืนยันสลิป -> อัปเดตตาราง payments
            if ($status === 'paid') {

                $payStmt = $conn->prepare(
                    "UPDATE payments

                     SET
                        payment_status = 'paid',
                        payment_verified_at = NOW(),
                        payment_verified_by = ?

                     WHERE payment_order_id = ?
                       AND payment_status IN ('pending', 'submitted')"
                );

                $payStmt->bind_param("ii", $sellerId, $orderId);
                $payStmt->execute();
                $payStmt->close();
            }

            successResponse("อัปเดตสถานะคำสั่งซื้อสำเร็จ");
        }

        $stmt->close();

        errorResponse("ไม่สามารถอัปเดตคำสั่งซื้อนี้ได้");

        break;

    case 'seller_cancel_order':

        $sellerId = sellerIdValue();
        $orderId = idv('order_id');

        if ($orderId <= 0) {
            errorResponse('ข้อมูลคำสั่งซื้อไม่ถูกต้อง');
        }

        $conn->begin_transaction();

        try {
            $lock = $conn->prepare(
                "SELECT order_status FROM orders WHERE order_id = ? FOR UPDATE"
            );
            $lock->bind_param('i', $orderId);
            $lock->execute();
            $order = $lock->get_result()->fetch_assoc();
            $lock->close();

            if (!$order) {
                throw new Exception('ไม่พบคำสั่งซื้อ');
            }
            if ($order['order_status'] !== 'pending') {
                throw new Exception('ยกเลิกได้เฉพาะคำสั่งซื้อที่รอดำเนินการ');
            }

            // An order may contain products from several sellers. Never let one
            // seller cancel another seller's items through the order-level status.
            $items = $conn->prepare(
                "SELECT item_product_id, item_variant_id, item_seller_id, item_quantity
                 FROM order_items WHERE item_order_id = ? FOR UPDATE"
            );
            $items->bind_param('i', $orderId);
            $items->execute();
            $itemRows = $items->get_result();
            $rows = [];
            while ($item = $itemRows->fetch_assoc()) {
                if (intval($item['item_seller_id']) !== $sellerId) {
                    throw new Exception('คำสั่งซื้อนี้มีสินค้าจากร้านอื่น จึงยกเลิกจากฝั่งร้านเดียวไม่ได้');
                }
                $rows[] = $item;
            }
            $items->close();

            if (!$rows) {
                throw new Exception('ไม่พบสินค้าในคำสั่งซื้อของร้านนี้');
            }

            foreach ($rows as $item) {
                $productId = intval($item['item_product_id']);
                $variantId = intval($item['item_variant_id'] ?? 0);
                $quantity = intval($item['item_quantity']);

                if ($variantId > 0) {
                    $restoreVariant = $conn->prepare(
                        "UPDATE product_variants SET variant_stock = variant_stock + ?
                         WHERE variant_id = ? AND variant_product_id = ?"
                    );
                    $restoreVariant->bind_param('iii', $quantity, $variantId, $productId);
                    $restoreVariant->execute();
                    if ($restoreVariant->affected_rows !== 1) {
                        throw new Exception('คืนสต็อกตัวเลือกสินค้าไม่สำเร็จ');
                    }
                    $restoreVariant->close();
                }

                $restore = $conn->prepare(
                    "UPDATE products SET stock = stock + ?
                     WHERE product_id = ? AND product_seller_id = ?"
                );
                $restore->bind_param('iii', $quantity, $productId, $sellerId);
                $restore->execute();
                if ($restore->affected_rows !== 1) {
                    throw new Exception('คืนสต็อกสินค้าไม่สำเร็จ');
                }
                $restore->close();

                $note = 'คืนสต็อกจากผู้ขายยกเลิกคำสั่งซื้อ #' . $orderId;
                $movement = $conn->prepare(
                    "INSERT INTO stock_movements
                     (movement_product_id, movement_seller_id, movement_type,
                      movement_quantity, note) VALUES (?, ?, 'IN', ?, ?)"
                );
                $movement->bind_param('iiis', $productId, $sellerId, $quantity, $note);
                $movement->execute();
                $movement->close();
            }

            $update = $conn->prepare(
                "UPDATE orders SET order_status = 'cancelled' WHERE order_id = ?"
            );
            $update->bind_param('i', $orderId);
            $update->execute();
            $update->close();

            $payment = $conn->prepare(
                "UPDATE payments SET payment_status = 'cancelled'
                 WHERE payment_order_id = ? AND payment_status IN ('pending', 'submitted')"
            );
            $payment->bind_param('i', $orderId);
            $payment->execute();
            $payment->close();

            $conn->commit();
            successResponse('ยกเลิกคำสั่งซื้อและคืนสต็อกเรียบร้อยแล้ว');
        } catch (Throwable $e) {
            $conn->rollback();
            errorResponse('ไม่สามารถยกเลิกคำสั่งซื้อได้', $e->getMessage());
        }

        break;
}
