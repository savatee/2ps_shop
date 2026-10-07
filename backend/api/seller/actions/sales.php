<?php

defined('SELLER_API') or exit('Forbidden');

// ============================================================
// SALES ACTIONS
// sales_summary
// ============================================================

switch ($action) {


    // ========================================================
    // SALES SUMMARY
    // ========================================================

    case 'sales_summary':

        $sellerId = sellerIdValue();

        // ----------------------------------------------------
        // SUMMARY
        // ----------------------------------------------------

        $stmt = $conn->prepare(
            "SELECT

                COALESCE(SUM(oi.subtotal), 0) AS total_sales,

                COUNT(DISTINCT o.order_id) AS order_count,

                COALESCE(SUM(oi.item_quantity), 0) AS item_count

             FROM order_items oi

             JOIN orders o
               ON o.order_id = oi.item_order_id

             WHERE oi.item_seller_id = ?
               AND o.order_status IN ('paid', 'processing', 'shipping', 'completed')"
        );

        $stmt->bind_param("i", $sellerId);
        $stmt->execute();

        $summary = $stmt->get_result()->fetch_assoc();

        $stmt->close();


        // ----------------------------------------------------
        // SALES BY CATEGORY
        // ----------------------------------------------------

        $stmt = $conn->prepare(
            "SELECT

                c.category_name,

                COALESCE(SUM(oi.subtotal), 0) AS sales

             FROM order_items oi

             JOIN orders o
               ON o.order_id = oi.item_order_id

             JOIN products p
               ON p.product_id = oi.item_product_id

             JOIN categories c
               ON c.category_id = p.category_id

             WHERE oi.item_seller_id = ?
               AND o.order_status IN ('paid', 'processing', 'shipping', 'completed')

             GROUP BY c.category_id, c.category_name

             ORDER BY sales DESC"
        );

        $stmt->bind_param("i", $sellerId);
        $stmt->execute();

        $result = $stmt->get_result();

        $categories = [];

        while ($r = $result->fetch_assoc()) {

            $categories[] = [
                'category_name' => $r['category_name'],
                'sales'         => floatval($r['sales']),
            ];
        }

        $stmt->close();


        // ----------------------------------------------------
        // DAILY SALES
        // ----------------------------------------------------

        $stmt = $conn->prepare(
            "SELECT

                DATE(o.order_created_at) AS sale_date,

                COALESCE(SUM(oi.subtotal), 0) AS sales

             FROM order_items oi

             JOIN orders o
               ON o.order_id = oi.item_order_id

             WHERE oi.item_seller_id = ?
               AND o.order_status IN ('paid', 'processing', 'shipping', 'completed')

             GROUP BY DATE(o.order_created_at)

             ORDER BY sale_date ASC"
        );

        $stmt->bind_param("i", $sellerId);
        $stmt->execute();

        $result = $stmt->get_result();

        $dailySales = [];

        while ($r = $result->fetch_assoc()) {

            $dailySales[] = [
                'date'  => $r['sale_date'],
                'sales' => floatval($r['sales']),
            ];
        }

        $stmt->close();


        successResponse(
            "สำเร็จ",
            [
                "total_sales"  => floatval($summary['total_sales'] ?? 0),
                "order_count"  => intval($summary['order_count'] ?? 0),
                "item_count"   => intval($summary['item_count'] ?? 0),
                "categories"   => $categories,
                "daily_sales"  => $dailySales,
            ]
        );

        break;
}
