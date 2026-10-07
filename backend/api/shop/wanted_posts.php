<?php
require_once __DIR__ . '/../config/bootstrap.php';
require_once __DIR__ . '/../lib/uploads.php';

$action = $_POST['action'] ?? $_GET['action'] ?? '';

switch ($action) {
    case 'create_buyer_request':
        $buyerId = intval($_POST['buyer_id'] ?? 0);
        $categoryId = intval($_POST['category_id'] ?? 0);
        $title = trim($_POST['title'] ?? '');
        $description = trim($_POST['description'] ?? '');
        $budget = floatval($_POST['budget'] ?? 0);

        if ($buyerId <= 0 || $categoryId <= 0 || $title === '' || $description === '' || $budget <= 0) {
            errorResponse("กรุณากรอกข้อมูลให้ครบ");
        }

        $categoryStmt = $conn->prepare("SELECT category_id FROM categories WHERE category_id = ? AND category_status = 'active' LIMIT 1");
        $categoryStmt->bind_param("i", $categoryId);
        $categoryStmt->execute();
        $validCategory = $categoryStmt->get_result()->num_rows > 0;
        $categoryStmt->close();
        if (!$validCategory) errorResponse("กรุณาเลือกหมวดหมู่ที่ใช้งานได้");

        $stmt = $conn->prepare("INSERT INTO wanted_posts (wanted_buyer_id, category_id, title, wanted_description, budget, wanted_status) VALUES (?, ?, ?, ?, ?, 'open')");
        $stmt->bind_param("iissd", $buyerId, $categoryId, $title, $description, $budget);
        if (!$stmt->execute()) {
            $err = $stmt->error;
            $stmt->close();
            errorResponse("สร้างโพสต์ไม่สำเร็จ", $err);
        }
        $id = $stmt->insert_id;
        $stmt->close();

        $uploadError = (int)($_FILES['wanted_image']['error'] ?? UPLOAD_ERR_NO_FILE);
        if ($uploadError !== UPLOAD_ERR_NO_FILE) {
            $failureReason = null;
            $imagePath = saveUploadedImage(
                $_FILES['wanted_image'],
                'wanted',
                'wanted_' . $id,
                $failureReason
            );
            if ($imagePath === null) {
                $deleteStmt = $conn->prepare(
                    "DELETE FROM wanted_posts WHERE wanted_post_id = ? AND wanted_buyer_id = ?"
                );
                $deleteStmt->bind_param("ii", $id, $buyerId);
                $deleteStmt->execute();
                $deleteStmt->close();
                errorResponse($failureReason ?? "อัปโหลดรูปไม่สำเร็จ", 400);
            }

            $imageStmt = $conn->prepare(
                "UPDATE wanted_posts SET wanted_image = ? WHERE wanted_post_id = ?"
            );
            if (!$imageStmt) {
                deleteStoredFile($imagePath);
                errorResponse("บันทึกรูปโพสต์ไม่สำเร็จ", 500, $conn->error);
            }
            $imageStmt->bind_param("si", $imagePath, $id);
            if (!$imageStmt->execute()) {
                $imageError = $imageStmt->error;
                $imageStmt->close();
                deleteStoredFile($imagePath);
                errorResponse("บันทึกรูปโพสต์ไม่สำเร็จ", 500, $imageError);
            }
            $imageStmt->close();
        }
        successResponse("สร้างโพสต์ตามหาสินค้าสำเร็จ", ["wanted_post_id" => $id]);
        break;

    case 'update_buyer_request':
        $userId = intval($_POST['user_id'] ?? 0);
        $postId = intval($_POST['wanted_post_id'] ?? 0);
        $categoryId = intval($_POST['category_id'] ?? 0);
        $title = trim($_POST['title'] ?? '');
        $description = trim($_POST['description'] ?? '');
        $budget = floatval($_POST['budget'] ?? 0);

        if ($userId <= 0 || $postId <= 0 || $categoryId <= 0 || $title === '' || $description === '' || $budget <= 0) {
            errorResponse("กรุณากรอกข้อมูลให้ครบ");
        }

        $categoryStmt = $conn->prepare("SELECT category_id FROM categories WHERE category_id = ? AND category_status = 'active' LIMIT 1");
        $categoryStmt->bind_param("i", $categoryId);
        $categoryStmt->execute();
        $validCategory = $categoryStmt->get_result()->num_rows > 0;
        $categoryStmt->close();
        if (!$validCategory) errorResponse("กรุณาเลือกหมวดหมู่ที่ใช้งานได้");

        $oldImageStmt = $conn->prepare(
            "SELECT wanted_image FROM wanted_posts WHERE wanted_post_id = ? AND wanted_buyer_id = ? LIMIT 1"
        );
        $oldImageStmt->bind_param("ii", $postId, $userId);
        $oldImageStmt->execute();
        $existingPost = $oldImageStmt->get_result()->fetch_assoc();
        $oldImageStmt->close();
        if (!$existingPost) errorResponse("ไม่พบโพสต์หรือคุณไม่มีสิทธิ์แก้ไข", 404);

        $removeImage = ($_POST['remove_image'] ?? '0') === '1';
        $oldImagePath = $existingPost['wanted_image'] ?? null;
        $newImagePath = null;
        $uploadError = (int)($_FILES['wanted_image']['error'] ?? UPLOAD_ERR_NO_FILE);
        if ($uploadError !== UPLOAD_ERR_NO_FILE) {
            $failureReason = null;
            $newImagePath = saveUploadedImage(
                $_FILES['wanted_image'],
                'wanted',
                'wanted_' . $postId,
                $failureReason
            );
            if ($newImagePath === null) {
                errorResponse($failureReason ?? "อัปโหลดรูปไม่สำเร็จ", 400);
            }
        }

        if ($newImagePath !== null || $removeImage) {
            $imageValue = $newImagePath;
            $stmt = $conn->prepare("UPDATE wanted_posts SET title = ?, wanted_description = ?, budget = ?, category_id = ?, wanted_image = ? WHERE wanted_post_id = ? AND wanted_buyer_id = ?");
            $stmt->bind_param("ssdisii", $title, $description, $budget, $categoryId, $imageValue, $postId, $userId);
        } else {
            $stmt = $conn->prepare("UPDATE wanted_posts SET title = ?, wanted_description = ?, budget = ?, category_id = ? WHERE wanted_post_id = ? AND wanted_buyer_id = ?");
            $stmt->bind_param("ssdiii", $title, $description, $budget, $categoryId, $postId, $userId);
        }
        if (!$stmt->execute()) {
            $error = $stmt->error;
            $stmt->close();
            if ($newImagePath !== null) deleteStoredFile($newImagePath);
            errorResponse("แก้ไขโพสต์ไม่สำเร็จ", $error);
        }
        $affected = $stmt->affected_rows;
        $stmt->close();
        if ($affected === 0) {
            $check = $conn->prepare("SELECT wanted_post_id FROM wanted_posts WHERE wanted_post_id = ? AND wanted_buyer_id = ? LIMIT 1");
            $check->bind_param("ii", $postId, $userId);
            $check->execute();
            $exists = $check->get_result()->num_rows > 0;
            $check->close();
            if (!$exists) errorResponse("ไม่พบโพสต์หรือคุณไม่มีสิทธิ์แก้ไข");
        }
        if ($newImagePath !== null && $oldImagePath) {
            deleteStoredFile($oldImagePath);
        } elseif ($removeImage && $oldImagePath) {
            deleteStoredFile($oldImagePath);
        }
        successResponse("แก้ไขโพสต์สำเร็จ");
        break;

    case 'set_buyer_request_status':
        $userId = intval($_POST['user_id'] ?? 0);
        $postId = intval($_POST['wanted_post_id'] ?? 0);
        $status = trim($_POST['status'] ?? '');

        if ($userId <= 0 || $postId <= 0 || !in_array($status, ['open', 'closed'], true)) {
            errorResponse("ข้อมูลโพสต์ไม่ถูกต้อง");
        }

        $stmt = $conn->prepare("UPDATE wanted_posts SET wanted_status = ? WHERE wanted_post_id = ? AND wanted_buyer_id = ?");
        $stmt->bind_param("sii", $status, $postId, $userId);
        if (!$stmt->execute()) {
            $error = $stmt->error;
            $stmt->close();
            errorResponse("เปลี่ยนสถานะโพสต์ไม่สำเร็จ", $error);
        }
        $affected = $stmt->affected_rows;
        $stmt->close();
        if ($affected === 0) {
            $check = $conn->prepare("SELECT wanted_post_id FROM wanted_posts WHERE wanted_post_id = ? AND wanted_buyer_id = ? LIMIT 1");
            $check->bind_param("ii", $postId, $userId);
            $check->execute();
            $exists = $check->get_result()->num_rows > 0;
            $check->close();
            if (!$exists) errorResponse("ไม่พบโพสต์หรือคุณไม่มีสิทธิ์แก้ไข");
        }
        successResponse($status === 'closed' ? "ปิดโพสต์เป็นส่วนตัวแล้ว" : "เปิดรับข้อเสนอแล้ว");
        break;

    case 'delete_buyer_request':
        $userId = intval($_POST['user_id'] ?? 0);
        $postId = intval($_POST['wanted_post_id'] ?? 0);
        if ($userId <= 0 || $postId <= 0) errorResponse("ข้อมูลโพสต์ไม่ถูกต้อง");

        $conn->begin_transaction();
        try {
            $ownerStmt = $conn->prepare("SELECT wanted_post_id FROM wanted_posts WHERE wanted_post_id = ? AND wanted_buyer_id = ? FOR UPDATE");
            $ownerStmt->bind_param("ii", $postId, $userId);
            $ownerStmt->execute();
            $ownedPost = $ownerStmt->get_result()->fetch_assoc();
            $ownerStmt->close();
            if (!$ownedPost) throw new Exception("ไม่พบโพสต์หรือคุณไม่มีสิทธิ์ลบ");

            // Keep existing conversations but detach them from the removed post.
            $chatStmt = $conn->prepare("UPDATE chat_rooms SET room_post_id = 0 WHERE room_post_id = ?");
            $chatStmt->bind_param("i", $postId);
            $chatStmt->execute();
            $chatStmt->close();

            $commentStmt = $conn->prepare("DELETE FROM wanted_comments WHERE wanted_post_id = ?");
            $commentStmt->bind_param("i", $postId);
            $commentStmt->execute();
            $commentStmt->close();

            $deleteStmt = $conn->prepare("DELETE FROM wanted_posts WHERE wanted_post_id = ? AND wanted_buyer_id = ?");
            $deleteStmt->bind_param("ii", $postId, $userId);
            $deleteStmt->execute();
            if ($deleteStmt->affected_rows !== 1) {
                $deleteStmt->close();
                throw new Exception("ลบโพสต์ไม่สำเร็จ");
            }
            $deleteStmt->close();
            $conn->commit();
        } catch (Throwable $e) {
            $conn->rollback();
            errorResponse("ลบโพสต์ไม่สำเร็จ", $e->getMessage());
        }
        successResponse("ลบโพสต์สำเร็จ");
        break;

    case 'get_buyer_requests':
        $buyerId = intval($_GET['buyer_id'] ?? 0);
        $viewerId = intval($_GET['viewer_id'] ?? 0);
        if ($buyerId > 0) {
            $stmt = $conn->prepare("SELECT wp.*, u.name AS buyer_name, u.profile_image AS buyer_image, c.category_name FROM wanted_posts wp LEFT JOIN users u ON wp.wanted_buyer_id = u.user_id LEFT JOIN categories c ON wp.category_id = c.category_id WHERE wp.wanted_buyer_id = ? ORDER BY wp.wanted_post_id DESC");
            $stmt->bind_param("i", $buyerId);
            $stmt->execute();
            $res = $stmt->get_result();
        } elseif ($viewerId > 0) {
            $stmt = $conn->prepare("SELECT wp.*, u.name AS buyer_name, u.profile_image AS buyer_image, c.category_name FROM wanted_posts wp LEFT JOIN users u ON wp.wanted_buyer_id = u.user_id LEFT JOIN categories c ON wp.category_id = c.category_id WHERE wp.wanted_status = 'open' OR wp.wanted_buyer_id = ? ORDER BY wp.wanted_post_id DESC");
            $stmt->bind_param("i", $viewerId);
            $stmt->execute();
            $res = $stmt->get_result();
        } else {
            $res = $conn->query("SELECT wp.*, u.name AS buyer_name, u.profile_image AS buyer_image, c.category_name FROM wanted_posts wp LEFT JOIN users u ON wp.wanted_buyer_id = u.user_id LEFT JOIN categories c ON wp.category_id = c.category_id WHERE wp.wanted_status = 'open' ORDER BY wp.wanted_post_id DESC");
        }
        $posts = [];
        while ($r = $res->fetch_assoc()) {
            // ส่ง URL เต็มของรูปไปด้วย เพื่อให้แอปแสดงรูปได้แน่นอน
            $r['wanted_image_url'] = imageUrlFromPath($r['wanted_image'] ?? null);
            $r['buyer_image_url'] = imageUrlFromPath($r['buyer_image'] ?? null);
            $posts[] = $r;
        }
        if (isset($stmt)) $stmt->close();
        successResponse("โหลดโพสต์สำเร็จ", $posts);
        break;

    // --- ดึงโพสต์เดียว (ใช้เปิดจากลิงก์ในแชท) ---
    case 'get_wanted_post':
        $wantedPostId = intval($_GET['wanted_post_id'] ?? $_POST['wanted_post_id'] ?? 0);
        $viewerId = intval($_GET['viewer_id'] ?? $_POST['viewer_id'] ?? 0);
        if ($wantedPostId <= 0) errorResponse("ไม่พบโพสต์");
        $stmt = $conn->prepare("SELECT wp.*, u.name AS buyer_name, u.profile_image AS buyer_image, c.category_name FROM wanted_posts wp LEFT JOIN users u ON wp.wanted_buyer_id = u.user_id LEFT JOIN categories c ON wp.category_id = c.category_id WHERE wp.wanted_post_id = ? AND (wp.wanted_status = 'open' OR wp.wanted_buyer_id = ?) LIMIT 1");
        $stmt->bind_param("ii", $wantedPostId, $viewerId);
        $stmt->execute();
        $post = $stmt->get_result()->fetch_assoc();
        $stmt->close();
        if (!$post) errorResponse("ไม่พบโพสต์นี้ หรือโพสต์ถูกลบ/ปิดแล้ว", 404);
        $post['wanted_image_url'] = imageUrlFromPath($post['wanted_image'] ?? null);
        $post['buyer_image_url'] = imageUrlFromPath($post['buyer_image'] ?? null);
        successResponse("โหลดโพสต์สำเร็จ", $post);
        break;

    // --- ส่วนจัดการข้อเสนอ/คอมเมนต์ (รองรับ offer_price ตามตารางจริง) ---
    case 'get_comments':
        $wantedPostId = intval($_GET['wanted_post_id'] ?? $_POST['wanted_post_id'] ?? 0);
        $viewerId = intval($_GET['viewer_id'] ?? $_POST['viewer_id'] ?? 0);
        if ($wantedPostId <= 0) errorResponse("ไม่พบโพสต์");
        $stmt = $conn->prepare("
            SELECT c.*, u.name AS seller_name, u.profile_image AS seller_image, u.role AS seller_role
            FROM wanted_comments c 
            LEFT JOIN users u ON c.user_id = u.user_id 
            INNER JOIN wanted_posts wp ON wp.wanted_post_id = c.wanted_post_id
            WHERE c.wanted_post_id = ?
              AND (wp.wanted_status = 'open' OR wp.wanted_buyer_id = ?)
            ORDER BY c.comment_id ASC
        ");
        $stmt->bind_param("ii", $wantedPostId, $viewerId);
        $stmt->execute();
        $res = $stmt->get_result();
        $comments = [];
        while ($r = $res->fetch_assoc()) { 
            $comments[] = $r; 
        }
        $stmt->close();
        successResponse("โหลดข้อเสนอสำเร็จ", $comments);
        break;

    default:
        errorResponse("Invalid wanted action");
}
$conn->close();