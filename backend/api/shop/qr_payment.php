<?php

require_once __DIR__ . '/../config/bootstrap.php';
require_once __DIR__ . '/promptpay.php';

/*
|--------------------------------------------------------------------------
| รับข้อมูล
|--------------------------------------------------------------------------
*/

$action = $_GET['action'] ?? $_POST['action'] ?? 'get_qr';

$paymentId = intval(
    $_GET['payment_id']
    ?? $_POST['payment_id']
    ?? 0
);

$userId = intval(
    $_GET['user_id']
    ?? $_POST['user_id']
    ?? 0
);

if ($paymentId <= 0 || $userId <= 0) {
    errorResponse('ข้อมูลการชำระเงินไม่ครบ');
}

/*
|--------------------------------------------------------------------------
| โหลด Payment
|--------------------------------------------------------------------------
*/

$stmt = $conn->prepare(
    "SELECT
        p.payment_id,
        p.payment_order_id,
        p.payment_method,
        p.amount,
        p.payment_status,
        p.payment_submitted_at,
        p.payment_verified_at,

        o.total_amount,
        o.order_status,
        o.order_buyer_id

     FROM payments p

     INNER JOIN orders o
        ON o.order_id = p.payment_order_id

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

$payment = $stmt
    ->get_result()
    ->fetch_assoc();

$stmt->close();

if (!$payment) {
    errorResponse('ไม่พบรายการชำระเงิน');
}

/*
|--------------------------------------------------------------------------
| ตรวจสอบวิธีชำระเงิน
|--------------------------------------------------------------------------
*/

$paymentMethod = strtolower(
    trim($payment['payment_method'])
);

if (!in_array(
    $paymentMethod,
    ['qr', 'transfer', 'bank_transfer'],
    true
)) {
    errorResponse(
        'รายการนี้ไม่ใช่การชำระแบบโอน'
    );
}

/*
|--------------------------------------------------------------------------
| ตรวจสอบยอดเงิน
|--------------------------------------------------------------------------
*/

$expectedAmount = number_format(
    round((float)$payment['total_amount'], 2),
    2,
    '.',
    ''
);

$paymentAmount = number_format(
    round((float)$payment['amount'], 2),
    2,
    '.',
    ''
);

if ($expectedAmount !== $paymentAmount) {
    errorResponse(
        'ยอดการชำระไม่ตรงกับคำสั่งซื้อ'
    );
}

/*
|--------------------------------------------------------------------------
| สถานะ
|--------------------------------------------------------------------------
*/

$paymentStatus = strtolower(
    trim($payment['payment_status'])
);

$isPaid =
    $paymentStatus === 'paid';

$isSubmitted =
    $paymentStatus === 'submitted';

$isFailed =
    $paymentStatus === 'failed';

$isCancelled =
    strtolower(
        trim($payment['order_status'])
    ) === 'cancelled';

/*
|--------------------------------------------------------------------------
| สร้าง QR
|--------------------------------------------------------------------------
*/

$qrPayload = null;
$qrImageUrl = null;

/*
|--------------------------------------------------------------------------
| ถ้ายังไม่ได้ยืนยันการโอน
| ให้แสดง QR
|--------------------------------------------------------------------------
*/

if (
    !$isPaid &&
    !$isSubmitted &&
    !$isCancelled
) {

    $shopPromptPay = getShopPromptPayPhone();

    if (
        !is_string($shopPromptPay) ||
        trim($shopPromptPay) === ''
    ) {
        errorResponse(
            'ร้านค้ายังไม่ได้ตั้งค่าหมายเลข PromptPay'
        );
    }

    /*
    |--------------------------------------------------------------------------
    | Generate PromptPay Payload
    |--------------------------------------------------------------------------
    */

    $qrPayload = generatePromptPayPayload(
        trim($shopPromptPay),
        $paymentAmount
    );

    if ($qrPayload === false) {
        errorResponse(
            'หมายเลข PromptPay ของร้านไม่ถูกต้อง'
        );
    }

    /*
    |--------------------------------------------------------------------------
    | QR Image
    |--------------------------------------------------------------------------
    */

    $qrImageUrl =
        'https://api.qrserver.com/v1/create-qr-code/'
        . '?size=360x360'
        . '&ecc=M'
        . '&data='
        . urlencode($qrPayload);
}

/*
|--------------------------------------------------------------------------
| View HTML
|--------------------------------------------------------------------------
*/

if ($action === 'view_html') {

    header(
        'Content-Type: text/html; charset=UTF-8'
    );

    ?>

    <!DOCTYPE html>
    <html lang="th">

    <head>

        <meta charset="UTF-8">

        <meta
            name="viewport"
            content="width=device-width, initial-scale=1.0"
        >

        <title>
            ชำระเงิน - 2PS Shop
        </title>

        <style>

            * {
                box-sizing: border-box;
            }

            body {
                margin: 0;
                padding: 30px 15px;
                background: #f5f7fb;
                font-family: Arial, sans-serif;
                color: #1f2937;
            }

            .container {
                width: 100%;
                max-width: 420px;
                margin: 0 auto;
            }

            .card {
                background: #ffffff;
                border-radius: 20px;
                padding: 25px;
                box-shadow:
                    0 8px 30px
                    rgba(0, 0, 0, 0.08);
                text-align: center;
            }

            .title {
                margin: 0 0 8px;
                font-size: 24px;
                font-weight: 700;
                color: #003B87;
            }

            .subtitle {
                color: #6b7280;
                font-size: 14px;
                margin-bottom: 20px;
            }

            .payment-id {
                font-size: 14px;
                color: #6b7280;
                margin-bottom: 8px;
            }

            .amount {
                font-size: 32px;
                font-weight: 700;
                color: #003B87;
                margin: 10px 0 20px;
            }

            .qr {
                width: 280px;
                max-width: 100%;
                border-radius: 12px;
                border: 1px solid #e5e7eb;
                padding: 8px;
                background: white;
            }

            .status {
                margin-top: 20px;
                padding: 12px;
                border-radius: 10px;
                background: #f3f4f6;
                font-size: 14px;
                line-height: 1.6;
            }

            .warning {
                margin-top: 18px;
                color: #6b7280;
                font-size: 13px;
                line-height: 1.6;
            }

        </style>

    </head>

    <body>

        <div class="container">

            <div class="card">

                <h1 class="title">
                    2PS Shop
                </h1>

                <div class="subtitle">
                    ชำระเงินผ่าน QR พร้อมเพย์
                </div>

                <div class="payment-id">
                    รหัสการชำระ #
                    <?php
                    echo intval(
                        $payment['payment_id']
                    );
                    ?>
                </div>

                <div class="amount">
                    ฿
                    <?php
                    echo htmlspecialchars(
                        $paymentAmount
                    );
                    ?>
                </div>

                <?php if ($qrImageUrl !== null): ?>

                    <img
                        class="qr"
                        src="<?php
                        echo htmlspecialchars(
                            $qrImageUrl
                        );
                        ?>"
                        alt="PromptPay QR Code"
                    >

                <?php else: ?>

                    <div class="status">

                        <?php if ($isPaid): ?>

                            ชำระเงินเรียบร้อยแล้ว

                        <?php elseif ($isSubmitted): ?>

                            แจ้งชำระเงินแล้ว
                            <br>
                            รอร้านค้าตรวจสอบ

                        <?php elseif ($isFailed): ?>

                            การชำระเงินไม่สำเร็จ

                        <?php elseif ($isCancelled): ?>

                            คำสั่งซื้อนี้ถูกยกเลิก

                        <?php else: ?>

                            ไม่สามารถสร้าง QR ได้

                        <?php endif; ?>

                    </div>

                <?php endif; ?>

                <div class="warning">

                    กรุณาชำระเงินตามจำนวนที่แสดง
                    <br>
                    หลังจากโอนเงินแล้ว
                    <br>
                    กลับไปที่แอป 2PS Shop
                    <br>
                    แล้วกด "ฉันได้โอนเงินแล้ว"

                </div>

            </div>

        </div>

    </body>

    </html>

    <?php

    $conn->close();

    exit;
}

/*
|--------------------------------------------------------------------------
| JSON Response
|--------------------------------------------------------------------------
*/

successResponse(
    'โหลดข้อมูล QR การชำระเงินสำเร็จ',
    [
        'payment_id' =>
            intval(
                $payment['payment_id']
            ),

        'order_id' =>
            intval(
                $payment['payment_order_id']
            ),

        'payment_method' =>
            $payment['payment_method'],

        'amount' =>
            $paymentAmount,

        'payment_status' =>
            $paymentStatus,

        'payment_submitted_at' =>
            $payment['payment_submitted_at'],

        'payment_verified_at' =>
            $payment['payment_verified_at'],

        'is_paid' =>
            $isPaid,

        'is_submitted' =>
            $isSubmitted,

        'is_failed' =>
            $isFailed,

        'is_cancelled' =>
            $isCancelled,

        'qr_payload' =>
            $qrPayload,

        'qr_image_url' =>
            $qrImageUrl,
    ]
);

$conn->close();
