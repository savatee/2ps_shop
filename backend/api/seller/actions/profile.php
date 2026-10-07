<?php

defined('SELLER_API') or exit('Forbidden');

// ============================================================
// PROFILE ACTIONS
// seller_profile, update_profile, change_password
// ============================================================

switch ($action) {

    // ========================================================
    // SELLER PROFILE
    // ========================================================
    case 'seller_profile':

        $userId = sellerIdValue();

        $stmt = $conn->prepare(
            "SELECT
                user_id,
                name,
                email,
                user_phone,
                role,
                user_status,
                profile_image
             FROM users
             WHERE user_id = ?
               AND role = 'seller'
             LIMIT 1"
        );

        $stmt->bind_param("i", $userId);
        $stmt->execute();
        $result = $stmt->get_result();

        if ($result->num_rows === 0) {
            $stmt->close();
            errorResponse("ไม่พบข้อมูลผู้ขาย");
        }

        $user = $result->fetch_assoc();
        $stmt->close();

        $user['profile_image_url'] = imageUrlFromPath($user['profile_image'] ?? null);

        successResponse("สำเร็จ", ["user" => $user]);

        break;

    // ========================================================
    // UPDATE PROFILE
    // ========================================================
    case 'update_profile':

        $userId = sellerIdValue();

        $name  = trim($_POST['name'] ?? '');
        $phone = trim($_POST['user_phone'] ?? '');

        if ($name === '') {
            errorResponse("กรุณากรอกชื่อ");
        }

        $newProfilePath = null;
        $oldProfilePath = null;

        $hasProfileImage =
            isset($_FILES['profile_image']) &&
            ($_FILES['profile_image']['error'] ?? UPLOAD_ERR_NO_FILE) === UPLOAD_ERR_OK;

        if ($hasProfileImage) {
            $oldStmt = $conn->prepare(
                "SELECT profile_image
                 FROM users
                 WHERE user_id = ?
                   AND LOWER(role) = 'seller'
                 LIMIT 1"
            );

            $oldStmt->bind_param("i", $userId);
            $oldStmt->execute();
            $oldUser = $oldStmt->get_result()->fetch_assoc();
            $oldStmt->close();

            if (!$oldUser) {
                errorResponse("ไม่พบผู้ขาย");
            }

            $oldProfilePath = $oldUser['profile_image'] ?? null;
            $newProfilePath = saveUploadedProfileImage($_FILES['profile_image'], $userId);

            if ($newProfilePath === null) {
                errorResponse("อัปโหลดรูปโปรไฟล์ไม่สำเร็จ");
            }
        }

        if ($hasProfileImage) {
            $stmt = $conn->prepare(
                "UPDATE users
                 SET name = ?, user_phone = ?, profile_image = ?
                 WHERE user_id = ?
                   AND LOWER(role) = 'seller'"
            );
            $stmt->bind_param("sssi", $name, $phone, $newProfilePath, $userId);
        } else {
            $stmt = $conn->prepare(
                "UPDATE users
                 SET name = ?, user_phone = ?
                 WHERE user_id = ?
                   AND LOWER(role) = 'seller'"
            );
            $stmt->bind_param("ssi", $name, $phone, $userId);
        }

        if (!$stmt->execute()) {
            if ($newProfilePath !== null) {
                deleteStoredFile($newProfilePath);
            }
            $error = $stmt->error;
            $stmt->close();
            errorResponse("บันทึกข้อมูลไม่สำเร็จ: " . $error);
        }

        $stmt->close();

        if ($newProfilePath !== null && $oldProfilePath !== null) {
            deleteStoredFile($oldProfilePath);
        }

        successResponse(
            "บันทึกข้อมูลสำเร็จ",
            [
                "profile_image"     => $newProfilePath,
                "profile_image_url" => imageUrlFromPath($newProfilePath),
            ]
        );

        break;
// ========================================================
    // CHANGE PASSWORD  (แก้ไขแล้ว)
    // ========================================================

    case 'change_password':

        $userId = sellerIdValue();

        $oldPassword = trim($_POST['old_password'] ?? '');
        $newPassword = trim($_POST['new_password'] ?? '');

        // ----------------------------------------------------
        // ตรวจข้อมูลเบื้องต้น
        // ----------------------------------------------------

        if ($userId <= 0) {
            errorResponse("ไม่พบรหัสผู้ใช้");
        }

        if ($oldPassword === '') {
            errorResponse("กรุณากรอกรหัสผ่านเดิม");
        }

        if ($newPassword === '') {
            errorResponse("กรุณากรอกรหัสผ่านใหม่");
        }

        if (strlen($newPassword) < 6) {
            errorResponse("รหัสผ่านใหม่ต้องมีความยาวอย่างน้อย 6 ตัวอักษร");
        }

        if ($oldPassword === $newPassword) {
            errorResponse("รหัสผ่านใหม่ต้องไม่เหมือนรหัสผ่านเดิม");
        }

        // ----------------------------------------------------
        // ดึงข้อมูลผู้ใช้ (ไม่ผูก role ใน SQL เพื่อกัน error กว้างเกินไป
        // แล้วค่อยเช็ค role/status แยกทีหลัง จะได้ error message ชัดเจน)
        // ----------------------------------------------------

        $stmt = $conn->prepare(
            "SELECT user_id, password, role, user_status
             FROM users
             WHERE user_id = ?
             LIMIT 1"
        );

        if (!$stmt) {
            errorResponse("ไม่สามารถตรวจสอบข้อมูลผู้ใช้ได้: " . $conn->error);
        }

        $stmt->bind_param("i", $userId);

        if (!$stmt->execute()) {
            $error = $stmt->error;
            $stmt->close();
            errorResponse("ตรวจสอบข้อมูลผู้ใช้ไม่สำเร็จ: " . $error);
        }

        $result = $stmt->get_result();

        if ($result->num_rows === 0) {
            $stmt->close();
            errorResponse("ไม่พบผู้ใช้");
        }

        $user = $result->fetch_assoc();
        $stmt->close();

        // ----------------------------------------------------
        // ตรวจ role / status แบบไม่สนตัวพิมพ์เล็ก-ใหญ่หรือช่องว่าง
        // ----------------------------------------------------

        if (strtolower(trim($user['role'] ?? '')) !== 'seller') {
            errorResponse("บัญชีนี้ไม่ใช่ Seller");
        }

        if (strtolower(trim($user['user_status'] ?? '')) !== 'active') {
            errorResponse("บัญชี Seller นี้ไม่สามารถใช้งานได้");
        }

        // ----------------------------------------------------
        // ตรวจรหัสผ่านเดิม
        // ----------------------------------------------------

        if (empty($user['password']) || !password_verify($oldPassword, $user['password'])) {
            errorResponse("รหัสผ่านเดิมไม่ถูกต้อง");
        }

        // ----------------------------------------------------
        // เข้ารหัสรหัสผ่านใหม่
        // ----------------------------------------------------

        $hashedPassword = password_hash($newPassword, PASSWORD_DEFAULT);

        if ($hashedPassword === false) {
            errorResponse("ไม่สามารถเข้ารหัสรหัสผ่านใหม่ได้");
        }

        // ----------------------------------------------------
        // บันทึกรหัสผ่านใหม่ (ไม่ผูก role ใน WHERE เพราะเช็คแล้วด้านบน)
        // ----------------------------------------------------

        $updateStmt = $conn->prepare(
            "UPDATE users
             SET password = ?
             WHERE user_id = ?"
        );

        if (!$updateStmt) {
            errorResponse("ไม่สามารถเตรียมข้อมูลสำหรับเปลี่ยนรหัสผ่านได้: " . $conn->error);
        }

        $updateStmt->bind_param("si", $hashedPassword, $userId);

        if (!$updateStmt->execute()) {
            $error = $updateStmt->error;
            $updateStmt->close();
            errorResponse("เปลี่ยนรหัสผ่านไม่สำเร็จ: " . $error);
        }

        $updateStmt->close();

        successResponse("เปลี่ยนรหัสผ่านสำเร็จ");

        break;
}