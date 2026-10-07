<?php

require_once __DIR__ . '/../config/bootstrap.php';

/*
|--------------------------------------------------------------------------
| รับข้อมูล
|--------------------------------------------------------------------------
*/

$action =
    $_POST['action']
    ?? $_GET['action']
    ?? '';

if ($action !== 'confirm_transfer') {
    errorResponse(
        'Invalid payment action'
    );
}

$paymentId = intval(
    $_POST['payment_id']
    ?? $_GET['payment_id']
    ?? 0
);

$userId = intval(
    $_POST['user_id']
    ?? $_GET['user_id']
    ?? 0
);

if (
    $paymentId <= 0 ||
    $userId <= 0
) {
    errorResponse(
        'ข้อมูลการยืนยันการโอนไม่ครบ'
    );
}

/*
|--------------------------------------------------------------------------
| ตรวจสอบ Payment
|--------------------------------------------------------------------------
*/

$stmt =
    $conn->prepare(
        "SELECT
            p.payment_id,
            p.payment_order_id,
            p.payment_method,
            p.amount,
            p.payment_status,

            o.order_id,
            o.order_buyer_id,
            o.order_status

         FROM payments p

         INNER JOIN orders o
            ON o.order_id =
               p.payment_order_id

         WHERE p.payment_id = ?
         AND o.order_buyer_id = ?

         LIMIT 1"
    );

$stmt->bind_param(
    'ii',
    $paymentId,
    $userId
);

$stmt->execute();

$payment =
    $stmt
        ->get_result()
        ->fetch_assoc();

$stmt->close();

if (!$payment) {
    errorResponse(
        'ไม่พบรายการชำระเงิน'
    );
}

/*
|--------------------------------------------------------------------------
| ตรวจสอบวิธีชำระเงิน
|--------------------------------------------------------------------------
*/

$paymentMethod =
    strtolower(
        trim(
            $payment['payment_method']
        )
    );

if (
    !in_array(
        $paymentMethod,
        ['qr', 'transfer', 'bank_transfer'],
        true
    )
) {
    errorResponse(
        'รายการนี้ไม่ใช่การโอนเงิน'
    );
}

/*
|--------------------------------------------------------------------------
| ตรวจสอบสถานะ
|--------------------------------------------------------------------------
*/

$currentStatus =
    strtolower(
        trim(
            $payment['payment_status']
        )
    );

if ($currentStatus === 'paid') {

    successResponse(
        'รายการนี้ได้รับการยืนยันแล้ว',
        [
            'payment_id' =>
                intval(
                    $payment['payment_id']
                ),

            'order_id' =>
                intval(
                    $payment['payment_order_id']
                ),

            'payment_status' =>
                'paid',

            'is_paid' =>
                true,

            'is_submitted' =>
                false,
        ]
    );

    $conn->close();

    exit;
}

if (
    !in_array(
        $currentStatus,
        ['pending', 'failed'],
        true
    )
) {
    errorResponse(
        'ไม่สามารถยืนยันการโอนในสถานะปัจจุบันได้'
    );
}

/*
|--------------------------------------------------------------------------
| ตรวจสอบ Order
|--------------------------------------------------------------------------
*/

$orderStatus =
    strtolower(
        trim(
            $payment['order_status']
        )
    );

if ($orderStatus === 'cancelled') {
    errorResponse(
        'คำสั่งซื้อนี้ถูกยกเลิกแล้ว'
    );
}

/*
|--------------------------------------------------------------------------
| ยืนยันการโอน
|--------------------------------------------------------------------------
|
| สำคัญ:
| ยังไม่เปลี่ยนเป็น paid
|
| submitted =
| ผู้ซื้อแจ้งว่าโอนแล้ว
|
| paid =
| ร้านค้าตรวจสอบแล้ว
|
|--------------------------------------------------------------------------
*/

$updateStmt =
    $conn->prepare(
        "UPDATE payments
         SET
            payment_status = 'submitted',
            payment_submitted_at = NOW(),
            payment_verified_at = NULL,
            payment_verified_by = NULL

         WHERE payment_id = ?
         AND payment_status IN ('pending', 'failed')"
    );

$updateStmt->bind_param(
    'i',
    $paymentId
);

$updateStmt->execute();

$affectedRows =
    $updateStmt->affected_rows;

$updateStmt->close();

if ($affectedRows <= 0) {
    errorResponse(
        'ไม่สามารถยืนยันการโอนได้'
    );
}

/*
|--------------------------------------------------------------------------
| Response
|--------------------------------------------------------------------------
*/

successResponse(
    'ยืนยันการโอนเงินเรียบร้อยแล้ว รอร้านค้าตรวจสอบ',
    [
        'payment_id' =>
            intval(
                $payment['payment_id']
            ),

        'order_id' =>
            intval(
                $payment['payment_order_id']
            ),

        'payment_status' =>
            'submitted',

        'payment_submitted_at' =>
            date('Y-m-d H:i:s'),

        'is_paid' =>
            false,

        'is_submitted' =>
            true,
    ]
);

$conn->close();
