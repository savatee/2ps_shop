<?php

defined('SELLER_API') or exit('Forbidden');

// ============================================================
// REQUEST HELPERS
// ============================================================

function idv($key)
{
    return intval($_POST[$key] ?? $_GET[$key] ?? 0);
}


// รองรับทั้ง seller_id และ user_id
function sellerIdValue(): int
{
    if (isset($GLOBALS['authenticatedSellerId'])) {
        return (int)$GLOBALS['authenticatedSellerId'];
    }

    return intval(
        $_POST['seller_id']
        ?? $_GET['seller_id']
        ?? $_POST['user_id']
        ?? $_GET['user_id']
        ?? 0
    );
}


// หน้าที่: ประมวลผลข้อมูล ผู้ขาย Exists ฝั่ง API และส่งผลลัพธ์กลับไปยังแอป.
function sellerExists(mysqli $conn, int $sellerId): bool
{
    $stmt = $conn->prepare(
        "SELECT user_id
         FROM users
         WHERE user_id = ?
           AND role = 'seller'
           AND user_status = 'active'
         LIMIT 1"
    );

    if (!$stmt) {
        return false;
    }

    $stmt->bind_param("i", $sellerId);
    $stmt->execute();

    $exists = $stmt->get_result()->num_rows > 0;

    $stmt->close();

    return $exists;
}


