<?php

defined('SELLER_API') or exit('Forbidden');

// ============================================================
// WANTED ACTIONS (ลูกค้าตามหาสินค้า)
// wanted_posts, wanted_comments, add_wanted_comment,
// delete_wanted_comment
// ============================================================

switch ($action) {


    // ========================================================
    // WANTED POSTS
    // ========================================================

    case 'wanted_posts':

        $result = $conn->query(
            "SELECT
                w.wanted_post_id,
                w.wanted_buyer_id,
                w.category_id,
                c.category_name,
                u.name AS buyer_name,
                w.title,
                w.wanted_description,
                w.budget,
                w.wanted_image,
                u.profile_image AS buyer_image,
                w.wanted_status,
                w.wanted_created_at

             FROM wanted_posts w

             JOIN users u
               ON u.user_id = w.wanted_buyer_id

                         LEFT JOIN categories c
                             ON c.category_id = w.category_id

                         WHERE w.wanted_status = 'open'

             ORDER BY w.wanted_post_id DESC"
        );

        if (!$result) {
            errorResponse("โหลดประกาศไม่สำเร็จ: " . $conn->error);
        }

        $rows = [];

        while ($r = $result->fetch_assoc()) {
            $r['wanted_image_url'] = imageUrlFromPath($r['wanted_image'] ?? null);
            $r['buyer_image_url'] = imageUrlFromPath($r['buyer_image'] ?? null);
            $rows[] = $r;
        }

        successResponse("สำเร็จ", ["posts" => $rows]);

        break;


    // ========================================================
    // WANTED COMMENTS
    // ========================================================

    case 'wanted_comments':

        $wantedPostId = idv('wanted_post_id');

        $stmt = $conn->prepare(
            "SELECT
                c.comment_id,
                c.wanted_post_id,
                c.user_id,
                u.name AS seller_name,
                c.offer_price,
                c.comment_text,
                c.comment_created_at

             FROM wanted_comments c

             JOIN users u
               ON u.user_id = c.user_id

             WHERE c.wanted_post_id = ?

             ORDER BY c.comment_id DESC"
        );

        if (!$stmt) {
            errorResponse("โหลดความคิดเห็นไม่สำเร็จ");
        }

        $stmt->bind_param("i", $wantedPostId);
        $stmt->execute();

        $result = $stmt->get_result();

        $rows = [];

        while ($r = $result->fetch_assoc()) {
            $rows[] = $r;
        }

        $stmt->close();

        successResponse("สำเร็จ", ["comments" => $rows]);

        break;


    // ========================================================
    // ADD WANTED COMMENT
    // ========================================================

    case 'add_wanted_comment':

        $sellerId     = sellerIdValue();
        $wantedPostId = idv('wanted_post_id');
        $offerPrice   = floatval($_POST['offer_price'] ?? 0);
        $commentText  = trim($_POST['comment_text'] ?? '');

        if (
            $sellerId <= 0 ||
            $wantedPostId <= 0 ||
            $offerPrice <= 0 ||
            $commentText === ''
        ) {
            errorResponse("ข้อมูลข้อเสนอไม่ครบหรือไม่ถูกต้อง");
        }

        $stmt = $conn->prepare(
            "SELECT wanted_status
             FROM wanted_posts
             WHERE wanted_post_id = ?
             LIMIT 1"
        );

        $stmt->bind_param("i", $wantedPostId);
        $stmt->execute();

        $post = $stmt->get_result()->fetch_assoc();

        $stmt->close();

        if (!$post) {
            errorResponse("ไม่พบประกาศนี้");
        }

        if ($post['wanted_status'] !== 'open') {
            errorResponse("ประกาศนี้ปิดรับข้อเสนอแล้ว");
        }

        $stmt = $conn->prepare(
            "INSERT INTO wanted_comments
            (
                wanted_post_id,
                user_id,
                offer_price,
                comment_text
            )
            VALUES (?, ?, ?, ?)"
        );

        $stmt->bind_param(
            "iids",
            $wantedPostId,
            $sellerId,
            $offerPrice,
            $commentText
        );

        if ($stmt->execute()) {

            $commentId = $conn->insert_id;

            $stmt->close();

            successResponse("เสนอราคาสำเร็จ", ["comment_id" => $commentId]);
        }

        $error = $stmt->error;

        $stmt->close();

        errorResponse("เสนอราคาไม่สำเร็จ: " . $error);

        break;


    // ========================================================
    // DELETE WANTED COMMENT
    // ========================================================

    case 'delete_wanted_comment':

        $sellerId  = sellerIdValue();
        $commentId = idv('comment_id');

        $stmt = $conn->prepare(
            "DELETE FROM wanted_comments
             WHERE comment_id = ?
               AND user_id = ?"
        );

        $stmt->bind_param("ii", $commentId, $sellerId);

        if ($stmt->execute() && $stmt->affected_rows > 0) {

            $stmt->close();

            successResponse("ลบข้อเสนอสำเร็จ");
        }

        $stmt->close();

        errorResponse("ลบข้อเสนอไม่สำเร็จ");

        break;
}