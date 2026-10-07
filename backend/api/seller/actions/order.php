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
                pay.payment_submitted_at

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

        $stmt->bind_param("i", $sellerId);
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
}