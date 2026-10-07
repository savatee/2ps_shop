<?php

defined('SELLER_API') or exit('Forbidden');

// ============================================================
// CHAT ACTIONS
// open_chat, chat_rooms, messages, send_message
// ============================================================

switch ($action) {


    // ========================================================
    // OPEN CHAT
    // ========================================================

    case 'open_chat':

        $sellerId = sellerIdValue();
        $buyerId  = idv('buyer_id');

        $stmt = $conn->prepare(
            "SELECT room_id
             FROM chat_rooms
             WHERE room_buyer_id = ?
               AND room_seller_id = ?
             LIMIT 1"
        );

        $stmt->bind_param("ii", $buyerId, $sellerId);
        $stmt->execute();

        $r = $stmt->get_result();

        if ($r->num_rows > 0) {

            $roomId = intval($r->fetch_assoc()['room_id']);

            $stmt->close();

            successResponse("สำเร็จ", ["room_id" => $roomId]);
        }

        $stmt->close();

        $stmt = $conn->prepare(
            "INSERT INTO chat_rooms (room_buyer_id, room_seller_id)
             VALUES (?, ?)"
        );

        $stmt->bind_param("ii", $buyerId, $sellerId);

        if ($stmt->execute()) {

            $roomId = $conn->insert_id;

            $stmt->close();

            successResponse("สำเร็จ", ["room_id" => $roomId]);
        }

        $stmt->close();

        errorResponse("สร้างห้องแชทไม่สำเร็จ");

        break;


    // ========================================================
    // SELLER CHAT ROOMS
    // ========================================================

    case 'chat_rooms':

        $sellerId = sellerIdValue();

        $stmt = $conn->prepare(
            "SELECT
                r.room_id,
                r.room_buyer_id,
                u.name AS buyer_name,
                u.profile_image AS buyer_image,

                (
                    SELECT
                        CASE
                            WHEN m.message_image IS NOT NULL
                                 AND TRIM(COALESCE(m.message, '')) = ''
                            THEN '[รูปภาพ]'
                            ELSE m.message
                        END

                    FROM messages m

                    WHERE m.message_room_id = r.room_id

                    ORDER BY m.message_id DESC

                    LIMIT 1
                ) AS last_message,

                r.room_updated_at

             FROM chat_rooms r

             JOIN users u
               ON u.user_id = r.room_buyer_id

             WHERE r.room_seller_id = ?

             ORDER BY r.room_updated_at DESC"
        );

        $stmt->bind_param("i", $sellerId);
        $stmt->execute();

        $result = $stmt->get_result();

        $rows = [];

        while ($r = $result->fetch_assoc()) {
            $rows[] = $r;
        }

        $stmt->close();

        successResponse("สำเร็จ", ["rooms" => $rows]);

        break;


    // ========================================================
    // MESSAGES
    // ========================================================

    case 'messages':

        $roomId = idv('room_id');
        $sellerId = sellerIdValue();

        $roomCheck = $conn->prepare(
            "SELECT 1 FROM chat_rooms
             WHERE room_id = ? AND room_seller_id = ?
             LIMIT 1"
        );
        $roomCheck->bind_param('ii', $roomId, $sellerId);
        $roomCheck->execute();
        $ownsRoom = $roomCheck->get_result()->num_rows > 0;
        $roomCheck->close();

        if (!$ownsRoom) {
            errorResponse('ไม่มีสิทธิ์ดูห้องนี้', 403);
        }

        $stmt = $conn->prepare(
            "SELECT
                message_id,
                sender_id,
                message,
                message_type,
                message_image,
                message_created_at

             FROM messages

             WHERE message_room_id = ?

             ORDER BY message_id ASC"
        );

        $stmt->bind_param("i", $roomId);
        $stmt->execute();

        $result = $stmt->get_result();

        $rows = [];

        while ($r = $result->fetch_assoc()) {

            $r['message_image_url'] = imageUrlFromPath($r['message_image'] ?? null);

            $rows[] = $r;
        }

        $stmt->close();

        successResponse("สำเร็จ", ["messages" => $rows]);

        break;


    // ========================================================
    // SEND MESSAGE + IMAGE
    // ========================================================

    case 'send_message':

        $roomId   = idv('room_id');
        $senderId = idv('sender_id');
        $sellerId = sellerIdValue();
        $message  = trim($_POST['message'] ?? '');

        if ($roomId <= 0 || $senderId !== $sellerId) {
            errorResponse("ไม่มีสิทธิ์ส่งข้อความในห้องนี้", 403);
        }

        // ตรวจห้อง
        $roomStmt = $conn->prepare(
            "SELECT room_id
             FROM chat_rooms
             WHERE room_id = ?
               AND room_seller_id = ?
             LIMIT 1"
        );

        $roomStmt->bind_param("ii", $roomId, $sellerId);
        $roomStmt->execute();

        if ($roomStmt->get_result()->num_rows === 0) {
            $roomStmt->close();
            errorResponse("ไม่พบห้องแชท");
        }

        $roomStmt->close();

        $hasImage =
            isset($_FILES['message_image']) &&
            ($_FILES['message_image']['error'] ?? UPLOAD_ERR_NO_FILE) === UPLOAD_ERR_OK;

        if ($message === '' && !$hasImage) {
            errorResponse("กรุณาพิมพ์ข้อความหรือเลือกรูปภาพ");
        }

        $messageType = 'text';
        $imagePath   = null;

        // INSERT MESSAGE
        $stmt = $conn->prepare(
            "INSERT INTO messages
            (
                message_room_id,
                sender_id,
                message,
                message_type,
                message_image
            )
            VALUES (?, ?, ?, ?, NULL)"
        );

        $stmt->bind_param("iiss", $roomId, $senderId, $message, $messageType);

        if (!$stmt->execute()) {
            errorResponse("ส่งข้อความไม่สำเร็จ: " . $stmt->error);
        }

        $messageId = $conn->insert_id;

        $stmt->close();

        // SAVE IMAGE
        if ($hasImage) {

            $imagePath = saveUploadedMessageImage($_FILES['message_image'], $messageId);

            if ($imagePath === null) {

                $del = $conn->prepare("DELETE FROM messages WHERE message_id = ?");
                $del->bind_param("i", $messageId);
                $del->execute();
                $del->close();

                errorResponse("อัปโหลดรูปภาพไม่สำเร็จ");
            }

            $up = $conn->prepare(
                "UPDATE messages
                 SET message_image = ?
                 WHERE message_id = ?"
            );

            $up->bind_param("si", $imagePath, $messageId);

            if (!$up->execute()) {

                deleteStoredFile($imagePath);

                $up->close();

                $del = $conn->prepare("DELETE FROM messages WHERE message_id = ?");
                $del->bind_param("i", $messageId);
                $del->execute();
                $del->close();

                errorResponse("บันทึกข้อมูลรูปภาพไม่สำเร็จ");
            }

            $up->close();
        }

        // UPDATE ROOM
        $roomUpdate = $conn->prepare(
            "UPDATE chat_rooms
             SET room_updated_at = CURRENT_TIMESTAMP
             WHERE room_id = ?"
        );

        if ($roomUpdate) {
            $roomUpdate->bind_param("i", $roomId);
            $roomUpdate->execute();
            $roomUpdate->close();
        }

        successResponse(
            "ส่งข้อความสำเร็จ",
            [
                "message_id"        => $messageId,
                "message"           => $message,
                "message_type"      => $messageType,
                "message_image"     => $imagePath,
                "message_image_url" => imageUrlFromPath($imagePath),
            ]
        );

        break;
}
