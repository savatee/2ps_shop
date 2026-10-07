<?php

require_once __DIR__ . '/../config/bootstrap.php';
require_once __DIR__ . '/promptpay.php';

/*
|--------------------------------------------------------------------------
| Helper
|--------------------------------------------------------------------------
*/

function normalizePaymentMethod($value)
{
    $value = strtolower(trim($value));

    if (
        in_array(
            $value,
            ['qr', 'transfer', 'bank_transfer'],
            true
        )
    ) {
        return 'qr';
    }

    if ($value === 'cod') {
        return 'cod';
    }

    return null;
}

function isTransferPayment($value)
{
    return in_array(
        strtolower(trim($value)),
        ['qr', 'transfer', 'bank_transfer'],
        true
    );
}

function formatAmount($value)
{
    return number_format(
        round((float)$value, 2),
        2,
        '.',
        ''
    );
}

function amountInCents($value)
{
    $amount = formatAmount($value);

    [$whole, $fraction] = array_pad(
        explode('.', $amount, 2),
        2,
        '00'
    );

    return ((int)$whole * 100)
        + (int)substr(
            str_pad($fraction, 2, '0'),
            0,
            2
        );
}

function isPaidStatus($value)
{
    return in_array(
        strtolower(trim($value)),
        ['paid', 'completed'],
        true
    );
}

/*
|--------------------------------------------------------------------------
| Action
|--------------------------------------------------------------------------
*/

$action =
    $_POST['action']
    ?? $_GET['action']
    ?? '';

switch ($action) {

    /*
    |--------------------------------------------------------------------------
    | CREATE ORDER
    |--------------------------------------------------------------------------
    */

    case 'create_order':

        $userId = intval(
            $_POST['user_id'] ?? 0
        );

        $addressId = intval(
            $_POST['address_id'] ?? 0
        );

        $paymentMethod =
            normalizePaymentMethod(
                $_POST['payment_method'] ?? 'cod'
            );

        $cartIdsRaw =
            trim(
                $_POST['cart_ids'] ?? ''
            );

        $directProductId =
            intval(
                $_POST['product_id'] ?? 0
            );

        $directQuantity =
            intval(
                $_POST['quantity'] ?? 0
            );

        $directVariantId =
            intval(
                $_POST['variant_id'] ?? 0
            );

        $selectedCartIds = [];

        /*
        |--------------------------------------------------------------------------
        | Validate
        |--------------------------------------------------------------------------
        */

        if (
            $userId <= 0 ||
            $addressId <= 0
        ) {
            errorResponse(
                'ข้อมูลคำสั่งซื้อไม่ครบ'
            );
        }

        if ($paymentMethod === null) {
            errorResponse(
                'ช่องทางชำระเงินไม่ถูกต้อง'
            );
        }

        /*
        |--------------------------------------------------------------------------
        | Cart IDs
        |--------------------------------------------------------------------------
        */

        if ($cartIdsRaw !== '') {

            $rawCartIds =
                explode(
                    ',',
                    $cartIdsRaw
                );

            foreach ($rawCartIds as $rawCartId) {

                $rawCartId =
                    trim($rawCartId);

                if (
                    !ctype_digit($rawCartId) ||
                    intval($rawCartId) <= 0
                ) {
                    errorResponse(
                        'รายการสินค้าในตะกร้าไม่ถูกต้อง'
                    );
                }

                $selectedCartIds[] =
                    intval($rawCartId);
            }

            if (
                count(
                    array_unique(
                        $selectedCartIds
                    )
                )
                !==
                count($selectedCartIds)
            ) {
                errorResponse(
                    'พบรายการสินค้าในตะกร้าซ้ำ'
                );
            }
        }

        /*
        |--------------------------------------------------------------------------
        | Direct Buy
        |--------------------------------------------------------------------------
        */

        if (
            isset($_POST['product_id']) &&
            $directProductId <= 0
        ) {
            errorResponse(
                'ข้อมูลสินค้าที่ต้องการซื้อไม่ถูกต้อง'
            );
        }

        if (
            $directProductId > 0 &&
            (
                $directQuantity <= 0 ||
                $cartIdsRaw !== ''
            )
        ) {
            errorResponse(
                'ข้อมูลสินค้าที่ต้องการซื้อไม่ถูกต้อง'
            );
        }

        if (
            !isset($_POST['product_id']) &&
            ($directQuantity !== 0 || $directVariantId !== 0)
        ) {
            errorResponse(
                'ไม่พบสินค้าที่ต้องการซื้อ'
            );
        }

        /*
        |--------------------------------------------------------------------------
        | QR Validation
        |--------------------------------------------------------------------------
        */

        if ($paymentMethod === 'qr') {

            $shopPromptPay =
                getShopPromptPayPhone();

            if (
                !is_string($shopPromptPay) ||
                trim($shopPromptPay) === ''
            ) {
                errorResponse(
                    'ร้านค้ายังไม่ได้ตั้งค่าหมายเลข PromptPay'
                );
            }

            if (
                generatePromptPayPayload(
                    trim($shopPromptPay),
                    1
                ) === false
            ) {
                errorResponse(
                    'หมายเลข PromptPay ของร้านไม่ถูกต้อง'
                );
            }
        }

        /*
        |--------------------------------------------------------------------------
        | Check Address
        |--------------------------------------------------------------------------
        */

        $addressStmt = $conn->prepare(
            'SELECT address_id
             FROM addresses
             WHERE address_id = ?
             AND address_user_id = ?
             LIMIT 1'
        );

        $addressStmt->bind_param(
            'ii',
            $addressId,
            $userId
        );

        $addressStmt->execute();

        $address =
            $addressStmt
                ->get_result()
                ->fetch_assoc();

        $addressStmt->close();

        if (!$address) {
            errorResponse(
                'ไม่พบที่อยู่ของผู้ซื้อ'
            );
        }

        /*
        |--------------------------------------------------------------------------
        | Transaction
        |--------------------------------------------------------------------------
        */

        $conn->begin_transaction();

        try {

            /*
            |--------------------------------------------------------------------------
            | Get Products
            |--------------------------------------------------------------------------
            */

            if ($directProductId > 0) {

                $stmt = $conn->prepare(
                    "SELECT
                        0 AS cart_id,
                        p.product_id AS cart_product_id,
                        ? AS cart_quantity,
                        COALESCE(v.variant_price, p.product_price) AS product_price,
                        CASE WHEN v.variant_id IS NULL THEN p.stock
                             ELSE v.variant_stock END AS stock,
                        p.product_seller_id,
                        v.variant_id AS item_variant_id,
                        v.variant_size AS item_size,
                        v.variant_color AS item_color,
                        EXISTS(
                            SELECT 1 FROM product_variants pv
                            WHERE pv.variant_product_id = p.product_id
                            AND pv.variant_status = 'active'
                        ) AS has_variants
                     FROM products p
                     LEFT JOIN product_variants v
                        ON v.variant_id = ?
                        AND v.variant_product_id = p.product_id
                        AND v.variant_status = 'active'
                     WHERE p.product_id = ?
                     AND p.product_status = 'active'
                     FOR UPDATE"
                );

                $stmt->bind_param(
                    'iii',
                    $directQuantity,
                    $directVariantId,
                    $directProductId
                );

            } else {

                $sql = '
                    SELECT
                        c.*,
                        COALESCE(v.variant_price, p.product_price) AS product_price,
                        CASE WHEN c.cart_variant_id IS NULL THEN p.stock
                             ELSE v.variant_stock END AS stock,
                        p.product_seller_id,
                        v.variant_id AS item_variant_id,
                        v.variant_size AS item_size,
                        v.variant_color AS item_color,
                        EXISTS(
                            SELECT 1 FROM product_variants pv
                            WHERE pv.variant_product_id = p.product_id
                            AND pv.variant_status = \'active\'
                        ) AS has_variants

                    FROM cart c

                    INNER JOIN products p
                        ON c.cart_product_id =
                           p.product_id

                    LEFT JOIN product_variants v
                        ON v.variant_id = c.cart_variant_id
                        AND v.variant_product_id = c.cart_product_id

                    WHERE c.cart_user_id = ?
                    AND p.product_status = \'active\'
                ';

                if (!empty($selectedCartIds)) {

                    $idList =
                        implode(
                            ',',
                            $selectedCartIds
                        );

                    $sql .= "
                        AND c.cart_id
                        IN ($idList)
                    ";
                }

                $sql .= ' FOR UPDATE';

                $stmt =
                    $conn->prepare($sql);

                $stmt->bind_param(
                    'i',
                    $userId
                );
            }

            $stmt->execute();

            $res =
                $stmt->get_result();

            $cartItems = [];

            $totalCents = 0;

            while (
                $row =
                $res->fetch_assoc()
            ) {

                if (
                    intval($row['has_variants'] ?? 0) === 1 &&
                    empty($row['item_variant_id'])
                ) {
                    throw new Exception(
                        'กรุณาเลือกสีหรือไซส์สินค้าใหม่ก่อนสั่งซื้อ'
                    );
                }

                if (
                    $directVariantId > 0 &&
                    empty($row['item_variant_id'])
                ) {
                    throw new Exception(
                        'ไม่พบตัวเลือกสินค้าที่เลือก'
                    );
                }

                $quantity =
                    intval(
                        $row['cart_quantity']
                    );

                if ($quantity <= 0) {
                    throw new Exception(
                        'จำนวนสินค้าไม่ถูกต้อง'
                    );
                }

                /*
                |--------------------------------------------------------------------------
                | Check Stock
                |--------------------------------------------------------------------------
                */

                if (
                    $quantity >
                    intval($row['stock'])
                ) {
                    throw new Exception(
                        'สินค้าบางรายการมีจำนวนไม่เพียงพอ'
                    );
                }

                $priceText =
                    formatAmount(
                        $row['product_price']
                    );

                $priceCents =
                    amountInCents(
                        $priceText
                    );

                $subtotalCents =
                    $priceCents * $quantity;

                $totalCents +=
                    $subtotalCents;

                $row['_price'] =
                    $priceText;

                $row['_subtotal'] =
                    formatAmount(
                        $subtotalCents / 100
                    );

                $cartItems[] =
                    $row;
            }

            $stmt->close();

            /*
            |--------------------------------------------------------------------------
            | Validate Selected Cart
            |--------------------------------------------------------------------------
            */

            if (
                $directProductId === 0 &&
                $cartIdsRaw !== '' &&
                count($cartItems)
                !== count($selectedCartIds)
            ) {
                throw new Exception(
                    'สินค้าที่เลือกบางรายการไม่อยู่ในตะกร้าแล้ว'
                );
            }

            if (empty($cartItems)) {
                throw new Exception(
                    'ไม่มีสินค้าในตะกร้า'
                );
            }

            $total =
                formatAmount(
                    $totalCents / 100
                );

            /*
            |--------------------------------------------------------------------------
            | Create Order
            |--------------------------------------------------------------------------
            */

            $orderStmt =
                $conn->prepare(
                    "INSERT INTO orders
                    (
                        order_buyer_id,
                        order_address_id,
                        total_amount,
                        order_status
                    )
                    VALUES
                    (?, ?, ?, 'pending')"
                );

            $orderStmt->bind_param(
                'iis',
                $userId,
                $addressId,
                $total
            );

            $orderStmt->execute();

            $orderId =
                $orderStmt->insert_id;

            $orderStmt->close();

            /*
            |--------------------------------------------------------------------------
            | Create Order Items
            |--------------------------------------------------------------------------
            */

            $orderedCartIds = [];

            foreach ($cartItems as $item) {

                $quantity =
                    intval(
                        $item['cart_quantity']
                    );

                $itemStmt =
                    $conn->prepare(
                        'INSERT INTO order_items
                        (
                            item_order_id,
                            item_product_id,
                            item_variant_id,
                            item_size,
                            item_color,
                            item_seller_id,
                            item_quantity,
                            item_price,
                            subtotal
                        )
                        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)'
                    );

                $itemStmt->bind_param(
                        'iiissiiss',
                    $orderId,
                    $item['cart_product_id'],
                        $item['item_variant_id'],
                        $item['item_size'],
                        $item['item_color'],
                    $item['product_seller_id'],
                    $quantity,
                    $item['_price'],
                    $item['_subtotal']
                );

                $itemStmt->execute();

                $itemStmt->close();

                $productId = intval($item['cart_product_id']);
                $sellerId = intval($item['product_seller_id']);

                if (!empty($item['item_variant_id'])) {
                    $variantId = intval($item['item_variant_id']);
                    $variantStockStmt = $conn->prepare(
                        "UPDATE product_variants
                         SET variant_stock = variant_stock - ?
                         WHERE variant_id = ?
                         AND variant_product_id = ?
                         AND variant_stock >= ?"
                    );
                    $variantStockStmt->bind_param(
                        'iiii',
                        $quantity,
                        $variantId,
                        $productId,
                        $quantity
                    );
                    $variantStockStmt->execute();
                    if ($variantStockStmt->affected_rows !== 1) {
                        throw new Exception(
                            'ตัวเลือกสินค้าบางรายการมีจำนวนไม่เพียงพอ'
                        );
                    }
                    $variantStockStmt->close();
                }

                $stockStmt = $conn->prepare(
                    "UPDATE products
                     SET stock = stock - ?
                     WHERE product_id = ?
                     AND product_seller_id = ?
                     AND stock >= ?"
                );
                $stockStmt->bind_param(
                    'iiii',
                    $quantity,
                    $productId,
                    $sellerId,
                    $quantity
                );
                $stockStmt->execute();
                if ($stockStmt->affected_rows !== 1) {
                    throw new Exception(
                        'สินค้าบางรายการมีจำนวนไม่เพียงพอ'
                    );
                }
                $stockStmt->close();

                $movementNote = 'ตัดสต็อกจากคำสั่งซื้อ #' . $orderId;
                $movementStmt = $conn->prepare(
                    "INSERT INTO stock_movements
                     (movement_product_id, movement_seller_id, movement_type,
                      movement_quantity, note)
                     VALUES (?, ?, 'OUT', ?, ?)"
                );
                $movementStmt->bind_param(
                    'iiis',
                    $productId,
                    $sellerId,
                    $quantity,
                    $movementNote
                );
                $movementStmt->execute();
                $movementStmt->close();

                if (
                    intval(
                        $item['cart_id']
                    ) > 0
                ) {
                    $orderedCartIds[] =
                        intval(
                            $item['cart_id']
                        );
                }
            }

            /*
            |--------------------------------------------------------------------------
            | Delete Cart
            |--------------------------------------------------------------------------
            */

            if (!empty($orderedCartIds)) {

                $idList =
                    implode(
                        ',',
                        $orderedCartIds
                    );

                $conn->query(
                    "DELETE FROM cart
                     WHERE cart_id
                     IN ($idList)"
                );
            }

            /*
            |--------------------------------------------------------------------------
            | Create Payment
            |--------------------------------------------------------------------------
            */

            $paymentStmt =
                $conn->prepare(
                    "INSERT INTO payments
                    (
                        payment_order_id,
                        payment_method,
                        amount,
                        payment_status
                    )
                    VALUES
                    (?, ?, ?, 'pending')"
                );

            $paymentStmt->bind_param(
                'iss',
                $orderId,
                $paymentMethod,
                $total
            );

            $paymentStmt->execute();

            $paymentId =
                $paymentStmt->insert_id;

            $paymentStmt->close();

            /*
            |--------------------------------------------------------------------------
            | Commit
            |--------------------------------------------------------------------------
            */

            $conn->commit();

            successResponse(
                $paymentMethod === 'qr'
                    ? 'สร้างคำสั่งซื้อและรอชำระเงิน'
                    : 'สร้างคำสั่งซื้อสำเร็จ',
                [
                    'order_id' =>
                        intval($orderId),

                    'order_status' =>
                        'pending',

                    'total_amount' =>
                        $total,

                    'payment_id' =>
                        intval($paymentId),

                    'payment_method' =>
                        $paymentMethod,

                    'payment_status' =>
                        'pending',

                    'is_paid' =>
                        false,
                ]
            );

        } catch (Throwable $e) {

            $conn->rollback();

            errorResponse(
                'สร้างคำสั่งซื้อไม่สำเร็จ',
                $e->getMessage()
            );
        }

        break;

    case 'cancel_order':

        $userId = intval($_POST['user_id'] ?? 0);
        $orderId = intval($_POST['order_id'] ?? 0);

        if ($userId <= 0 || $orderId <= 0) {
            errorResponse('ข้อมูลคำสั่งซื้อไม่ถูกต้อง');
        }

        $conn->begin_transaction();

        try {
            $lock = $conn->prepare(
                "SELECT order_status FROM orders
                 WHERE order_id = ? AND order_buyer_id = ? FOR UPDATE"
            );
            $lock->bind_param('ii', $orderId, $userId);
            $lock->execute();
            $lockedOrder = $lock->get_result()->fetch_assoc();
            $lock->close();

            if (!$lockedOrder) {
                throw new Exception('ไม่พบคำสั่งซื้อของคุณ');
            }

            if ($lockedOrder['order_status'] === 'cancelled') {
                $conn->commit();
                successResponse('คำสั่งซื้อนี้ถูกยกเลิกแล้ว');
            }

            if ($lockedOrder['order_status'] !== 'pending') {
                throw new Exception('ยกเลิกได้เฉพาะคำสั่งซื้อที่ยังรอดำเนินการ');
            }

            $items = $conn->prepare(
                "SELECT item_product_id, item_variant_id,
                        item_seller_id, item_quantity
                 FROM order_items WHERE item_order_id = ? FOR UPDATE"
            );
            $items->bind_param('i', $orderId);
            $items->execute();
            $itemRows = $items->get_result();

            while ($item = $itemRows->fetch_assoc()) {
                $productId = intval($item['item_product_id']);
                $variantId = intval($item['item_variant_id'] ?? 0);
                $sellerId = intval($item['item_seller_id']);
                $quantity = intval($item['item_quantity']);

                if ($variantId > 0) {
                    $restoreVariant = $conn->prepare(
                        "UPDATE product_variants
                         SET variant_stock = variant_stock + ?
                         WHERE variant_id = ?
                         AND variant_product_id = ?"
                    );
                    $restoreVariant->bind_param(
                        'iii',
                        $quantity,
                        $variantId,
                        $productId
                    );
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

                $note = 'คืนสต็อกจากการยกเลิกคำสั่งซื้อ #' . $orderId;
                $movement = $conn->prepare(
                    "INSERT INTO stock_movements
                     (movement_product_id, movement_seller_id, movement_type,
                      movement_quantity, note)
                     VALUES (?, ?, 'IN', ?, ?)"
                );
                $movement->bind_param('iiis', $productId, $sellerId, $quantity, $note);
                $movement->execute();
                $movement->close();
            }
            $items->close();

            $updateOrder = $conn->prepare(
                "UPDATE orders SET order_status = 'cancelled' WHERE order_id = ?"
            );
            $updateOrder->bind_param('i', $orderId);
            $updateOrder->execute();
            $updateOrder->close();

            $updatePayment = $conn->prepare(
                "UPDATE payments SET payment_status = 'cancelled'
                 WHERE payment_order_id = ?
                 AND payment_status IN ('pending', 'submitted')"
            );
            $updatePayment->bind_param('i', $orderId);
            $updatePayment->execute();
            $updatePayment->close();

            $conn->commit();
            successResponse('ยกเลิกคำสั่งซื้อเรียบร้อยแล้ว');
        } catch (Throwable $e) {
            $conn->rollback();
            errorResponse('ไม่สามารถยกเลิกคำสั่งซื้อได้', $e->getMessage());
        }

        break;

    /*
    |--------------------------------------------------------------------------
    | GET ORDERS
    |--------------------------------------------------------------------------
    */

    case 'get_orders':

        $userId = intval(
            $_GET['user_id']
            ?? $_POST['user_id']
            ?? 0
        );

        if ($userId <= 0) {
            errorResponse(
                'ไม่พบผู้ซื้อ'
            );
        }

        $stmt =
            $conn->prepare(
                "SELECT
                    o.*,

                    (
                        SELECT p.payment_id
                        FROM payments p
                        WHERE p.payment_order_id =
                              o.order_id
                        ORDER BY p.payment_id DESC
                        LIMIT 1
                    ) AS payment_id,

                    (
                        SELECT p.payment_method
                        FROM payments p
                        WHERE p.payment_order_id =
                              o.order_id
                        ORDER BY p.payment_id DESC
                        LIMIT 1
                    ) AS payment_method,

                    (
                        SELECT p.amount
                        FROM payments p
                        WHERE p.payment_order_id =
                              o.order_id
                        ORDER BY p.payment_id DESC
                        LIMIT 1
                    ) AS payment_amount,

                    (
                        SELECT p.payment_status
                        FROM payments p
                        WHERE p.payment_order_id =
                              o.order_id
                        ORDER BY p.payment_id DESC
                        LIMIT 1
                    ) AS payment_status,

                    (
                        SELECT p.payment_submitted_at
                        FROM payments p
                        WHERE p.payment_order_id =
                              o.order_id
                        ORDER BY p.payment_id DESC
                        LIMIT 1
                    ) AS payment_submitted_at,

                    (
                        SELECT p.payment_verified_at
                        FROM payments p
                        WHERE p.payment_order_id =
                              o.order_id
                        ORDER BY p.payment_id DESC
                        LIMIT 1
                    ) AS payment_verified_at,

                    (
                        SELECT COUNT(*)
                        FROM order_items oi
                        WHERE oi.item_order_id =
                              o.order_id
                    ) AS item_count

                 FROM orders o

                 WHERE o.order_buyer_id = ?

                 ORDER BY o.order_id DESC"
            );

        $stmt->bind_param(
            'i',
            $userId
        );

        $stmt->execute();

        $res =
            $stmt->get_result();

        $orders = [];

        while (
            $row =
            $res->fetch_assoc()
        ) {
            $orders[] =
                $row;
        }

        $stmt->close();

        /*
        |--------------------------------------------------------------------------
        | Load Items
        |--------------------------------------------------------------------------
        */

        $orderIds =
            array_column(
                $orders,
                'order_id'
            );

        if (!empty($orderIds)) {

            $idList =
                implode(
                    ',',
                    array_map(
                        'intval',
                        $orderIds
                    )
                );

            $itemsStmt =
                $conn->prepare(
                    "SELECT
                        oi.*,
                        p.product_name,

                        (
                            SELECT pi.image_data
                            FROM product_images pi
                            WHERE pi.image_product_id =
                                  oi.item_product_id
                            ORDER BY pi.image_id ASC
                            LIMIT 1
                        ) AS product_image

                     FROM order_items oi

                     INNER JOIN products p
                        ON oi.item_product_id =
                           p.product_id

                     WHERE oi.item_order_id
                     IN ($idList)"
                );

            $itemsStmt->execute();

            $itemsRes =
                $itemsStmt->get_result();

            $itemsByOrder = [];

            while (
                $item =
                $itemsRes->fetch_assoc()
            ) {

                $itemsByOrder[
                    $item['item_order_id']
                ][] =
                    $item;
            }

            $itemsStmt->close();

            foreach ($orders as &$order) {

                $order['items'] =
                    $itemsByOrder[
                        $order['order_id']
                    ] ?? [];
            }

            unset($order);
        }

        successResponse(
            'โหลดคำสั่งซื้อสำเร็จ',
            $orders
        );

        break;

    /*
    |--------------------------------------------------------------------------
    | GET ORDER DETAIL
    |--------------------------------------------------------------------------
    */

    case 'get_order_detail':

        $orderId = intval(
            $_GET['order_id']
            ?? $_POST['order_id']
            ?? 0
        );

        $userId = intval(
            $_GET['user_id']
            ?? $_POST['user_id']
            ?? 0
        );

        if (
            $orderId <= 0 ||
            $userId <= 0
        ) {
            errorResponse(
                'ข้อมูลคำสั่งซื้อไม่ครบ'
            );
        }

        /*
        |--------------------------------------------------------------------------
        | Order
        |--------------------------------------------------------------------------
        */

        $stmt =
            $conn->prepare(
                'SELECT *
                 FROM orders
                 WHERE order_id = ?
                 AND order_buyer_id = ?
                 LIMIT 1'
            );

        $stmt->bind_param(
            'ii',
            $orderId,
            $userId
        );

        $stmt->execute();

        $order =
            $stmt
                ->get_result()
                ->fetch_assoc();

        $stmt->close();

        if (!$order) {
            errorResponse(
                'ไม่พบคำสั่งซื้อ'
            );
        }

        /*
        |--------------------------------------------------------------------------
        | Items
        |--------------------------------------------------------------------------
        */

        $stmt =
            $conn->prepare(
                "SELECT
                    oi.*,
                    p.product_name,

                    (
                        SELECT pi.image_data
                        FROM product_images pi
                        WHERE pi.image_product_id =
                              oi.item_product_id
                        ORDER BY pi.image_id ASC
                        LIMIT 1
                    ) AS product_image

                 FROM order_items oi

                 INNER JOIN products p
                    ON oi.item_product_id =
                       p.product_id

                 WHERE oi.item_order_id = ?"
            );

        $stmt->bind_param(
            'i',
            $orderId
        );

        $stmt->execute();

        $items = [];

        $res =
            $stmt->get_result();

        while (
            $row =
            $res->fetch_assoc()
        ) {
            $items[] =
                $row;
        }

        $stmt->close();

        $order['items'] =
            $items;

        /*
        |--------------------------------------------------------------------------
        | Address
        |--------------------------------------------------------------------------
        */

        $addrStmt =
            $conn->prepare(
                'SELECT *
                 FROM addresses
                 WHERE address_id = ?
                 LIMIT 1'
            );

        $addrStmt->bind_param(
            'i',
            $order['order_address_id']
        );

        $addrStmt->execute();

        $address =
            $addrStmt
                ->get_result()
                ->fetch_assoc();

        $addrStmt->close();

        $order['shipping_address'] =
            $address ?: null;

        /*
        |--------------------------------------------------------------------------
        | Payment
        |--------------------------------------------------------------------------
        */

        $paymentStmt =
            $conn->prepare(
                'SELECT
                    payment_id,
                    payment_order_id,
                    payment_method,
                    amount,
                    payment_status,
                    payment_submitted_at,
                    payment_verified_at,
                    payment_verified_by

                 FROM payments

                 WHERE payment_order_id = ?

                 ORDER BY payment_id DESC

                 LIMIT 1'
            );

        $paymentStmt->bind_param(
            'i',
            $orderId
        );

        $paymentStmt->execute();

        $payment =
            $paymentStmt
                ->get_result()
                ->fetch_assoc();

        $paymentStmt->close();

        $order['payment'] =
            $payment ?: null;

        successResponse(
            'โหลดรายละเอียดสำเร็จ',
            $order
        );

        break;

    /*
    |--------------------------------------------------------------------------
    | Default
    |--------------------------------------------------------------------------
    */

    default:

        errorResponse(
            'Invalid order action'
        );
}

$conn->close();
