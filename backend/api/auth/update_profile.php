<?php
require_once __DIR__ . '/../config/bootstrap.php';
require_once __DIR__ . '/../lib/uploads.php';
$authenticatedUser = requireUser($conn);

$rawInput = file_get_contents('php://input');
$jsonInput = json_decode($rawInput, true) ?? [];

$userId = (int)$authenticatedUser['user_id'];
$name   = trim($jsonInput['name'] ?? $_POST['name'] ?? '');
$phone  = trim($jsonInput['user_phone'] ?? $_POST['user_phone'] ?? '');

if ($name === '') {
    errorResponse("กรุณาระบุข้อมูลให้ครบถ้วน", 400);
}

// ตรวจสอบว่ามีผู้ใช้อยู่จริง (พ่วงดึง profile_image เดิมมาด้วย เผื่อต้องลบทิ้ง)
$checkStmt = $conn->prepare("SELECT user_id, profile_image FROM users WHERE user_id = ? LIMIT 1");
if (!$checkStmt) {
    errorResponse("SQL Error: " . $conn->error, 500);
}
$checkStmt->bind_param("i", $userId);
$checkStmt->execute();
$existingUser = $checkStmt->get_result()->fetch_assoc();
$checkStmt->close();

if (!$existingUser) {
    errorResponse("ไม่พบข้อมูลผู้ใช้นี้ในระบบ", 404);
}

// ----------------------------------------------------
// รูปโปรไฟล์ (ถ้ามีการแนบไฟล์มาด้วย)
// ----------------------------------------------------
$newProfilePath = null;
$oldProfilePath = $existingUser['profile_image'] ?? null;

$profileUpload = $_FILES['profile_image'] ?? null;
$uploadError = (int)($profileUpload['error'] ?? UPLOAD_ERR_NO_FILE);
if ($profileUpload !== null && $uploadError !== UPLOAD_ERR_OK && $uploadError !== UPLOAD_ERR_NO_FILE) {
    error_log('PROFILE IMAGE UPLOAD ERROR: user_id=' . $userId . ' code=' . $uploadError);
    errorResponse(
        $uploadError === UPLOAD_ERR_INI_SIZE || $uploadError === UPLOAD_ERR_FORM_SIZE
            ? 'รูปภาพมีขนาดใหญ่เกินกำหนด'
            : 'เซิร์ฟเวอร์รับไฟล์รูปภาพไม่สำเร็จ กรุณาลองใหม่',
        $uploadError === UPLOAD_ERR_INI_SIZE || $uploadError === UPLOAD_ERR_FORM_SIZE ? 413 : 400
    );
}

$hasProfileImage = $profileUpload !== null && $uploadError === UPLOAD_ERR_OK;

if ($hasProfileImage) {
    $profileDir = UPLOAD_ROOT . '/profile';
    if (!is_dir($profileDir) && !@mkdir($profileDir, 0755, true) && !is_dir($profileDir)) {
        error_log('PROFILE IMAGE DIRECTORY CREATE FAILED: ' . $profileDir);
        errorResponse('เซิร์ฟเวอร์ไม่สามารถเตรียมพื้นที่เก็บรูปได้', 503);
    }
    if (!is_writable($profileDir)) {
        error_log('PROFILE IMAGE DIRECTORY NOT WRITABLE: ' . $profileDir);
        errorResponse('เซิร์ฟเวอร์ไม่มีสิทธิ์บันทึกรูปโปรไฟล์ กรุณาตรวจสอบสิทธิ์โฟลเดอร์ uploads/profile', 503);
    }

    $newProfilePath = saveUploadedProfileImage($profileUpload, $userId);
    if ($newProfilePath === null) {
        error_log('PROFILE IMAGE SAVE FAILED: user_id=' . $userId . ' size=' . (int)($profileUpload['size'] ?? 0));
        errorResponse("อัปโหลดรูปโปรไฟล์ไม่สำเร็จ ตรวจสอบชนิดไฟล์ jpg, jpeg, png, webp หรือสิทธิ์โฟลเดอร์", 400);
    }
}

// ----------------------------------------------------
// อัปเดตข้อมูลลงฐานข้อมูล
// ----------------------------------------------------
if ($newProfilePath !== null) {
    $stmt = $conn->prepare("UPDATE users SET name = ?, user_phone = ?, profile_image = ?, user_updated_at = NOW() WHERE user_id = ?");
    if (!$stmt) {
        errorResponse("SQL Prepare Error: " . $conn->error, 500);
    }
    $stmt->bind_param("sssi", $name, $phone, $newProfilePath, $userId);
} else {
    $stmt = $conn->prepare("UPDATE users SET name = ?, user_phone = ?, user_updated_at = NOW() WHERE user_id = ?");
    if (!$stmt) {
        errorResponse("SQL Prepare Error: " . $conn->error, 500);
    }
    $stmt->bind_param("ssi", $name, $phone, $userId);
}

if (!$stmt->execute()) {
    // ถ้าบันทึก DB ไม่สำเร็จ ลบไฟล์ใหม่ที่เพิ่งอัปโหลดทิ้งไป กันไฟล์ค้าง
    if ($newProfilePath !== null) {
        deleteStoredFile($newProfilePath);
    }
    $errorMsg = $stmt->error;
    $stmt->close();
    $conn->close();
    errorResponse("เกิดข้อผิดพลาดในการบันทึก: " . $errorMsg, 500);
}
$stmt->close();

// ลบรูปเก่าทิ้งหลังบันทึกรูปใหม่สำเร็จแล้ว
if ($newProfilePath !== null && $oldProfilePath) {
    deleteStoredFile($oldProfilePath);
}

$fetchStmt = $conn->prepare("SELECT user_id, name, email, user_phone, profile_image, role, user_status FROM users WHERE user_id = ? LIMIT 1");
$fetchStmt->bind_param("i", $userId);
$fetchStmt->execute();
$updatedUser = $fetchStmt->get_result()->fetch_assoc();
$fetchStmt->close();
$conn->close();

if ($updatedUser && isset($updatedUser['profile_image'])) {
    $updatedUser['profile_image_url'] = imageUrlFromPath($updatedUser['profile_image']);
}

successResponse("อัปเดตข้อมูลสำเร็จ", $updatedUser);