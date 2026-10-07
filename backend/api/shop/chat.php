<?php

require_once __DIR__ . '/../config/bootstrap.php';
require_once __DIR__ . '/../lib/uploads.php';

/*
|--------------------------------------------------------------------------
| Chat API
|--------------------------------------------------------------------------
| หลักการ:
| 1. ผู้ซื้อ 1 คน + ผู้ขาย 1 คน = บทสนทนาเดียว
| 2. ไม่แยกห้องตาม post_id
| 3. room_post_id ใช้เก็บโพสต์แรกที่เริ่มแชทเท่านั้น
| 4. ถ้าฐานข้อมูลเก่ามีห้องซ้ำ ระบบจะรวมประวัติข้อความของทุกห้อง
|    ของคู่ buyer + seller เดียวกันให้เห็นเป็นบทสนทนาเดียว
|--------------------------------------------------------------------------
*/

$action = $_POST['action'] ?? $_GET['action'] ?? '';

switch ($action) {

    // ============================================================
    // GET OR CREATE CHAT
    // ============================================================
    case 'get_or_create_chat':

        $postId = intval($_POST['post_id'] ?? 0);
        $buyerId = intval($_POST['buyer_id'] ?? 0);
        $sellerId = intval($_POST['seller_id'] ?? 0);

        if ($buyerId <= 0 || $sellerId <= 0) {
            errorResponse("ข้อมูลแชทไม่ครบ");
        }

        if ($buyerId == $sellerId) {
            errorResponse("ไม่สามารถแชทกับตัวเองได้");
        }

        /*
         * สำคัญ:
         * ค้นหาจาก buyer + seller เท่านั้น
         * ไม่ใช้ post_id เป็นตัวแบ่งห้อง
         */
        $stmt = $conn->prepare("
            SELECT room_id
            FROM chat_rooms
            WHERE room_buyer_id = ?
              AND room_seller_id = ?
            ORDER BY room_id ASC
            LIMIT 1
        ");

        $stmt->bind_param(
            "ii",
            $buyerId,
            $sellerId
        );

        $stmt->execute();

        $existing = $stmt
            ->get_result()
            ->fetch_assoc();

        $stmt->close();

        /*
         * ถ้ามีห้องอยู่แล้ว
         * ใช้ห้องเดิมทันที
         */
        if ($existing) {

            successResponse(
                "เปิดแชทสำเร็จ",
                [
                    "chat_id" => $existing['room_id']
                ]
            );
        }

        /*
         * ถ้ายังไม่มีห้อง
         * สร้างใหม่
         */
        $stmt = $conn->prepare("
            INSERT INTO chat_rooms
            (
                room_buyer_id,
                room_seller_id,
                room_post_id
            )
            VALUES (?, ?, ?)
        ");

        $stmt->bind_param(
            "iii",
            $buyerId,
            $sellerId,
            $postId
        );

        if (!$stmt->execute()) {

            $err = $stmt->error;

            $stmt->close();

            /*
             * เผื่อมีอีก request สร้างห้องพร้อมกัน
             * ลองค้นหาอีกครั้ง
             */
            $find = $conn->prepare("
                SELECT room_id
                FROM chat_rooms
                WHERE room_buyer_id = ?
                  AND room_seller_id = ?
                ORDER BY room_id ASC
                LIMIT 1
            ");

            $find->bind_param(
                "ii",
                $buyerId,
                $sellerId
            );

            $find->execute();

            $existingAfterError = $find
                ->get_result()
                ->fetch_assoc();

            $find->close();

            if ($existingAfterError) {

                successResponse(
                    "เปิดแชทสำเร็จ",
                    [
                        "chat_id" => $existingAfterError['room_id']
                    ]
                );
            }

            errorResponse(
                "เปิดแชทไม่สำเร็จ",
                $err
            );
        }

        $chatId = $stmt->insert_id;

        $stmt->close();

        successResponse(
            "เปิดแชทสำเร็จ",
            [
                "chat_id" => $chatId
            ]
        );

        break;


    // ============================================================
    // GET MESSAGES
    // ============================================================
    case 'get_messages':

        $chatId = intval($_GET['chat_id'] ?? 0);
        $readerId = intval($_GET['reader_id'] ?? 0);

        if ($chatId <= 0) {
            errorResponse("ไม่พบห้องแชท");
        }

        /*
         * หา buyer + seller ของห้องที่เลือก
         */
        $stmt = $conn->prepare("
            SELECT
                room_buyer_id,
                room_seller_id
            FROM chat_rooms
            WHERE room_id = ?
            LIMIT 1
        ");

        $stmt->bind_param(
            "i",
            $chatId
        );

        $stmt->execute();

        $room = $stmt
            ->get_result()
            ->fetch_assoc();

        $stmt->close();

        if (!$room) {
            errorResponse("ไม่พบห้องแชท");
        }

        $buyerId = intval($room['room_buyer_id']);
        $sellerId = intval($room['room_seller_id']);

        if ($readerId > 0 && $readerId !== $buyerId && $readerId !== $sellerId) {
            errorResponse("ไม่มีสิทธิ์อ่านข้อความในห้องนี้", 403);
        }

        /*
         * --------------------------------------------------------
         * Mark as read
         * --------------------------------------------------------
         *
         * ทำให้ข้อความจากอีกฝ่ายของ "ทุกห้องเก่า"
         * ถูกอ่านด้วย
         */
        if ($readerId > 0) {

            $mark = $conn->prepare("
                UPDATE messages m
                INNER JOIN chat_rooms cr
                    ON m.message_room_id = cr.room_id
                SET m.is_read = 1
                WHERE cr.room_buyer_id = ?
                  AND cr.room_seller_id = ?
                  AND m.sender_id != ?
                  AND m.is_read = 0
            ");

            $mark->bind_param(
                "iii",
                $buyerId,
                $sellerId,
                $readerId
            );

            $mark->execute();

            $mark->close();
        }

        /*
         * --------------------------------------------------------
         * ดึงข้อความทั้งหมดของ buyer + seller
         * --------------------------------------------------------
         *
         * ตรงนี้สำคัญที่สุด
         *
         * ต่อให้ฐานข้อมูลเดิมมี:
         *
         * room 1 = buyer ↔ sawa
         * room 5 = buyer ↔ sawa
         * room 9 = buyer ↔ sawa
         *
         * ก็จะเอาข้อความทั้งหมดมารวมกัน
         */
        $stmt = $conn->prepare("
            SELECT
                m.*
            FROM messages m
            INNER JOIN chat_rooms cr
                ON m.message_room_id = cr.room_id
            WHERE cr.room_buyer_id = ?
              AND cr.room_seller_id = ?
            ORDER BY m.message_id ASC
        ");

        $stmt->bind_param(
            "ii",
            $buyerId,
            $sellerId
        );

        $stmt->execute();

        $res = $stmt->get_result();

        $messages = [];

        while ($r = $res->fetch_assoc()) {
            $messages[] = $r;
        }

        $stmt->close();

        successResponse(
            "โหลดข้อความสำเร็จ",
            $messages
        );

        break;


    // ============================================================
    // SEND MESSAGE
    // ============================================================
    case 'send_message':

        $chatId = intval($_POST['chat_id'] ?? 0);
        $senderId = intval($_POST['sender_id'] ?? 0);

        $messageText = trim(
            $_POST['message'] ?? ''
        );

        $productId =
            isset($_POST['product_id']) &&
            $_POST['product_id'] !== ''
                ? intval($_POST['product_id'])
                : null;

        $uploadError = (int)($_FILES['message_image']['error'] ?? UPLOAD_ERR_NO_FILE);
        $hasImage = isset($_FILES['message_image']) && $uploadError === UPLOAD_ERR_OK;

        if ($uploadError !== UPLOAD_ERR_OK && $uploadError !== UPLOAD_ERR_NO_FILE) {
            errorResponse("อัปโหลดรูปไม่สำเร็จ กรุณาลองเลือกรูปที่มีขนาดเล็กลง");
        }

        if ($chatId <= 0 || $senderId <= 0) {
            errorResponse("ข้อมูลข้อความไม่ครบ");
        }

        $roomCheck = $conn->prepare("
            SELECT room_buyer_id, room_seller_id
            FROM chat_rooms
            WHERE room_id = ?
            LIMIT 1
        ");
        $roomCheck->bind_param("i", $chatId);
        $roomCheck->execute();
        $room = $roomCheck->get_result()->fetch_assoc();
        $roomCheck->close();

        if (!$room) {
            errorResponse("ไม่พบห้องแชท");
        }
        if ($senderId !== intval($room['room_buyer_id']) &&
            $senderId !== intval($room['room_seller_id'])) {
            errorResponse("ไม่มีสิทธิ์ส่งข้อความในห้องนี้", 403);
        }

        if (
            $messageText === '' &&
            !$hasImage &&
            $productId === null
        ) {
            errorResponse(
                "กรุณาพิมพ์ข้อความ แนบรูปภาพ หรือแนบสินค้า"
            );
        }

        /*
         * message_type มีแค่ text / product
         */
        $messageType =
            $productId !== null
                ? 'product'
                : 'text';

        /*
         * ส่งข้อความลงห้องหลัก
         *
         * ห้องนี้จะเป็นห้องที่ get_or_create_chat
         * เลือกกลับมา
         */
        $stmt = $conn->prepare("
            INSERT INTO messages
            (
                message_room_id,
                sender_id,
                message,
                message_product_id,
                message_type,
                message_image,
                is_read
            )
            VALUES (?, ?, ?, ?, ?, ?, 0)
        ");

        $messageImage = null;
        $stmt->bind_param(
            "iisiss",
            $chatId,
            $senderId,
            $messageText,
            $productId,
            $messageType,
            $messageImage
        );

        if (!$stmt->execute()) {

            $err = $stmt->error;

            $stmt->close();

            errorResponse(
                "ส่งข้อความไม่สำเร็จ",
                $err
            );
        }

        $messageId = $stmt->insert_id;

        $stmt->close();

        if ($hasImage) {
            $imagePath = saveUploadedMessageImage($_FILES['message_image'], $messageId);
            if ($imagePath === null) {
                $delete = $conn->prepare("DELETE FROM messages WHERE message_id = ?");
                $delete->bind_param("i", $messageId);
                $delete->execute();
                $delete->close();
                errorResponse("บันทึกรูปไม่สำเร็จ กรุณาลองใหม่อีกครั้ง");
            }

            $updateImage = $conn->prepare(
                "UPDATE messages SET message_image = ? WHERE message_id = ?"
            );
            $updateImage->bind_param("si", $imagePath, $messageId);
            if (!$updateImage->execute()) {
                deleteStoredFile($imagePath);
                $updateImage->close();
                $delete = $conn->prepare("DELETE FROM messages WHERE message_id = ?");
                $delete->bind_param("i", $messageId);
                $delete->execute();
                $delete->close();
                errorResponse("บันทึกรูปไม่สำเร็จ กรุณาลองใหม่อีกครั้ง");
            }
            $updateImage->close();
        }

        $roomUpdate = $conn->prepare(
            "UPDATE chat_rooms
             SET room_updated_at = CURRENT_TIMESTAMP
             WHERE room_id = ?"
        );
        $roomUpdate->bind_param('i', $chatId);
        $roomUpdate->execute();
        $roomUpdate->close();

        successResponse(
            "ส่งข้อความสำเร็จ",
            [
                "message_id" => $messageId
            ]
        );

        break;


    // ============================================================
    // GET BUYER CHATS
    // ============================================================
    case 'get_buyer_chats':

        $buyerId = intval(
            $_GET['buyer_id'] ?? 0
        );

        if ($buyerId <= 0) {
            errorResponse("ไม่พบผู้ซื้อ");
        }

        /*
         * ดึงทุกห้องก่อน
         *
         * จากนั้นรวมด้วย seller_id ใน PHP
         * เพื่อรองรับฐานข้อมูลเก่าที่มีห้องซ้ำ
         */
        $stmt = $conn->prepare("
            SELECT
                cr.room_id,
                cr.room_buyer_id,
                cr.room_seller_id,
                cr.room_post_id,
                cr.room_created_at,

                s.name AS seller_name,
                s.profile_image AS seller_image,

                (
                    SELECT CASE
                        WHEN m.message_image IS NOT NULL
                             AND TRIM(COALESCE(m.message, '')) = ''
                        THEN '[รูปภาพ]'
                        ELSE m.message
                    END
                    FROM messages m
                    WHERE m.message_room_id = cr.room_id
                    ORDER BY m.message_id DESC
                    LIMIT 1
                ) AS last_message,

                (
                    SELECT m.message_created_at
                    FROM messages m
                    WHERE m.message_room_id = cr.room_id
                    ORDER BY m.message_id DESC
                    LIMIT 1
                ) AS last_message_at,

                (
                    SELECT COUNT(*)
                    FROM messages m
                    WHERE m.message_room_id = cr.room_id
                      AND m.sender_id != ?
                      AND m.is_read = 0
                ) AS unread_count

            FROM chat_rooms cr

            LEFT JOIN users s
                ON cr.room_seller_id = s.user_id

            WHERE cr.room_buyer_id = ?

            ORDER BY
                COALESCE(
                    (
                        SELECT MAX(m2.message_created_at)
                        FROM messages m2
                        WHERE m2.message_room_id = cr.room_id
                    ),
                    cr.room_created_at
                ) DESC
        ");

        $stmt->bind_param(
            "ii",
            $buyerId,
            $buyerId
        );

        $stmt->execute();

        $res = $stmt->get_result();

        /*
         * ========================================================
         * รวมตาม seller
         * ========================================================
         *
         * 1 seller = 1 ช่อง
         */
        $grouped = [];

        while ($r = $res->fetch_assoc()) {

            $sellerId = $r['room_seller_id'];

            if (!isset($grouped[$sellerId])) {

                $grouped[$sellerId] = [
                    'room_id' => $r['room_id'],
                    'room_buyer_id' => $r['room_buyer_id'],
                    'room_seller_id' => $r['room_seller_id'],
                    'room_post_id' => $r['room_post_id'],
                    'room_created_at' => $r['room_created_at'],

                    'seller_name' => $r['seller_name'],
                    'seller_image' => $r['seller_image'],

                    'last_message' => $r['last_message'],
                    'last_message_at' => $r['last_message_at'],

                    'unread_count' =>
                        intval($r['unread_count']),
                ];

            } else {

                /*
                 * รวมจำนวน unread
                 */
                $grouped[$sellerId]['unread_count'] +=
                    intval($r['unread_count']);

                /*
                 * ถ้าห้องนี้มีข้อความใหม่กว่า
                 * ให้ใช้เป็น Preview
                 */
                $currentTime =
                    $grouped[$sellerId]['last_message_at'];

                $newTime =
                    $r['last_message_at'];

                if (
                    $newTime !== null &&
                    (
                        $currentTime === null ||
                        strtotime($newTime) >
                        strtotime($currentTime)
                    )
                ) {

                    $grouped[$sellerId]['room_id'] =
                        $r['room_id'];

                    $grouped[$sellerId]['room_post_id'] =
                        $r['room_post_id'];

                    $grouped[$sellerId]['last_message'] =
                        $r['last_message'];

                    $grouped[$sellerId]['last_message_at'] =
                        $r['last_message_at'];
                }
            }
        }

        $stmt->close();

        $chats = array_values($grouped);

        /*
         * เรียงจากแชทล่าสุดไปเก่าสุด
         */
        usort(
            $chats,
            function ($a, $b) {

                $aTime =
                    $a['last_message_at'] ??
                    $a['room_created_at'] ??
                    '';

                $bTime =
                    $b['last_message_at'] ??
                    $b['room_created_at'] ??
                    '';

                return strtotime($bTime) <=> strtotime($aTime);
            }
        );

        successResponse(
            "โหลดรายการแชทสำเร็จ",
            $chats
        );

        break;


    // ============================================================
    // INVALID ACTION
    // ============================================================
    default:

        errorResponse(
            "Invalid chat action"
        );
}

$conn->close();
