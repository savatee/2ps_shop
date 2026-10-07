<?php
// การจัดเก็บรูปอัปโหลด
//
// โครงสร้างบนเซิร์ฟเวอร์ (โฟลเดอร์ Final):
//   Final/backend/api/...   <- โค้ด PHP (ไฟล์นี้อยู่ที่ api/lib/)
//   Final/uploads/...       <- รูปที่ผู้ใช้อัปโหลด (product, message, profile)
//
// PROJECT_BASE_URL = URL ของโฟลเดอร์ที่มี uploads/ อยู่ข้างใน (ลงท้ายด้วย /)
// ต้องตรงกับ AppConfig.appBaseUrl ฝั่ง Flutter
// ตั้งค่าทับได้ใน config.local.php (PROJECT_BASE_URL, UPLOAD_ROOT)
define(
    'PROJECT_BASE_URL',
    rtrim(
        appConfig(
            'PROJECT_BASE_URL',
            'https://std.mcs.psu.ac.th/6620310006/html/Final'
        ),
        '/'
    ) . '/'
);

// หาโฟลเดอร์ uploads: ใช้ค่าจาก config ก่อน ไม่เช่นนั้นลองหาที่ระดับเดียวกับ backend/
// แล้วจึงลองระดับเดียวกับ api/ (กรณีวาง api/ ไว้ตรงๆ)
function resolveUploadRoot(): string
{
    $configured = trim(appConfig('UPLOAD_ROOT'));
    if ($configured !== '') {
        return rtrim($configured, '/\\');
    }

    $candidates = [
        dirname(__DIR__, 3) . '/uploads',
        dirname(__DIR__, 2) . '/uploads',
    ];

    foreach ($candidates as $candidate) {
        if (is_dir($candidate)) {
            return $candidate;
        }
    }

    return $candidates[0];
}

define(
    'UPLOAD_ROOT',
    resolveUploadRoot()
);

// ขนาดไฟล์รูปสูงสุด (10 MB)
define('UPLOAD_MAX_BYTES', 10 * 1024 * 1024);


// ============================================================
// IMAGE URL
// แปลง path ที่เก็บใน DB (เช่น uploads/product/xxx.jpg) เป็น URL เต็ม
// ============================================================

function imageUrlFromPath($path): ?string
{
    $path = trim((string)$path);

    if ($path === '') {
        return null;
    }

    if (preg_match('#^https?://#i', $path)) {
        return $path;
    }

    return PROJECT_BASE_URL . ltrim($path, '/');
}


// ============================================================
// SAVE (ภายใน)
// $folder = product | message | profile
// $prefix = product_{id} | msg_{id} | user_{id}
// คืนค่า path แบบ uploads/<folder>/<ชื่อไฟล์> หรือ null ถ้าไม่สำเร็จ
// ============================================================

function saveUploadedImage(
    array $file,
    string $folder,
    string $prefix,
    ?string &$failureReason = null
): ?string
{
    $failureReason = null;

    $uploadError = (int)($file['error'] ?? UPLOAD_ERR_NO_FILE);

    if ($uploadError !== UPLOAD_ERR_OK) {
        switch ($uploadError) {
            case UPLOAD_ERR_INI_SIZE:
            case UPLOAD_ERR_FORM_SIZE:
                $failureReason = 'ไฟล์รูปมีขนาดใหญ่เกินที่เซิร์ฟเวอร์รับได้ กรุณาเลือกรูปที่เล็กลง';
                break;
            case UPLOAD_ERR_PARTIAL:
                $failureReason = 'อัปโหลดรูปไม่ครบ กรุณาลองใหม่';
                break;
            case UPLOAD_ERR_NO_TMP_DIR:
            case UPLOAD_ERR_CANT_WRITE:
            case UPLOAD_ERR_EXTENSION:
                $failureReason = 'เซิร์ฟเวอร์ไม่สามารถรับไฟล์รูปได้ กรุณาติดต่อผู้ดูแล';
                break;
            default:
                $failureReason = 'ไม่พบไฟล์รูป กรุณาเลือกรูปใหม่';
                break;
        }

        error_log('Image upload failed: PHP upload error ' . $uploadError);
        return null;
    }

    $tmp = $file['tmp_name'] ?? '';

    if ($tmp === '' || !is_string($tmp)) {
        error_log('Image upload failed: temporary file is missing');
        $failureReason = 'เซิร์ฟเวอร์ไม่ได้รับไฟล์รูป กรุณาลองใหม่';
        return null;
    }

    if (!is_uploaded_file($tmp)) {
        error_log('Image upload failed: temporary file was not uploaded by PHP');
        $failureReason = 'ไฟล์รูปที่ส่งมาไม่ถูกต้อง กรุณาเลือกรูปใหม่';
        return null;
    }

    $size = (int)($file['size'] ?? 0);

    if ($size <= 0 || $size > UPLOAD_MAX_BYTES) {
        error_log('Image upload failed: invalid file size ' . $size);
        $failureReason = 'ไฟล์รูปต้องมีขนาดไม่เกิน 10 MB';
        return null;
    }

    // ตรวจชนิดไฟล์จากเนื้อไฟล์จริง ไม่เชื่อชื่อไฟล์ที่ client ส่งมา
    $allowed = [
        'image/jpeg' => 'jpg',
        'image/png'  => 'png',
        'image/webp' => 'webp',
        'image/gif'  => 'gif',
    ];

    $mime = null;

    if (function_exists('finfo_open')) {
        $finfo = finfo_open(FILEINFO_MIME_TYPE);
        if ($finfo) {
            $mime = finfo_file($finfo, $tmp) ?: null;
            finfo_close($finfo);
        }
    }

    if ($mime === null) {
        $info = @getimagesize($tmp);
        $mime = $info['mime'] ?? null;
    }

    if ($mime === null || !isset($allowed[$mime])) {
        error_log('Image upload failed: unsupported MIME type ' . ($mime ?? 'unknown'));
        $failureReason = 'ชนิดไฟล์รูปไม่รองรับ กรุณาใช้ JPG, PNG, WEBP หรือ GIF';
        return null;
    }

    $ext = $allowed[$mime];

    $dir = UPLOAD_ROOT . '/' . $folder;

    if (!is_dir($dir) && !@mkdir($dir, 0755, true) && !is_dir($dir)) {
        error_log('Cannot create upload dir: ' . $dir);
        $failureReason = 'เซิร์ฟเวอร์สร้างโฟลเดอร์เก็บรูปไม่ได้ กรุณาตรวจสอบสิทธิ์โฟลเดอร์ uploads';
        return null;
    }

    $filename = sprintf(
        '%s_%s_%s.%s',
        $prefix,
        date('Ymd_His'),
        bin2hex(random_bytes(8)),
        $ext
    );

    $target = $dir . '/' . $filename;

    if (!@move_uploaded_file($tmp, $target)) {
        error_log('move_uploaded_file failed; check upload directory permissions: ' . $target);
        $failureReason = 'เซิร์ฟเวอร์เขียนไฟล์ลง uploads ไม่ได้ กรุณาตรวจสอบสิทธิ์โฟลเดอร์';
        return null;
    }

    @chmod($target, 0644);

    return 'uploads/' . $folder . '/' . $filename;
}


// หน้าที่: บันทึกหรือสร้างข้อมูล save Uploaded สินค้า รูปภาพ แล้วจัดการผลที่เซิร์ฟเวอร์ตอบกลับ.
function saveUploadedProductImage(
    array $file,
    int $productId,
    ?string &$failureReason = null
): ?string
{
    return saveUploadedImage(
        $file,
        'product',
        'product_' . $productId,
        $failureReason
    );
}

// หน้าที่: บันทึกหรือสร้างข้อมูล save Uploaded ข้อความ รูปภาพ แล้วจัดการผลที่เซิร์ฟเวอร์ตอบกลับ.
function saveUploadedMessageImage(array $file, int $messageId): ?string
{
    return saveUploadedImage($file, 'message', 'msg_' . $messageId);
}

// หน้าที่: บันทึกหรือสร้างข้อมูล save Uploaded โปรไฟล์ รูปภาพ แล้วจัดการผลที่เซิร์ฟเวอร์ตอบกลับ.
function saveUploadedProfileImage(array $file, int $userId): ?string
{
    return saveUploadedImage($file, 'profile', 'user_' . $userId);
}


// ============================================================
// DELETE
// ลบไฟล์จริงจาก path ที่เก็บใน DB (ลบได้เฉพาะในโฟลเดอร์ uploads เท่านั้น)
// ============================================================

function deleteStoredFile($path): bool
{
    $path = trim((string)$path);

    if ($path === '' || preg_match('#^https?://#i', $path)) {
        return false;
    }

    // ตัด "uploads/" ข้างหน้าออก แล้วต่อกับ UPLOAD_ROOT
    $relative = ltrim($path, '/');
    if (strpos($relative, 'uploads/') === 0) {
        $relative = substr($relative, strlen('uploads/'));
    }

    // กัน path traversal
    if ($relative === '' || strpos($relative, '..') !== false) {
        return false;
    }

    $full = UPLOAD_ROOT . '/' . $relative;

    $realRoot = realpath(UPLOAD_ROOT);
    $realFile = realpath($full);

    if ($realRoot === false || $realFile === false) {
        return false;
    }

    if (strpos($realFile, $realRoot . DIRECTORY_SEPARATOR) !== 0) {
        return false;
    }

    if (!is_file($realFile)) {
        return false;
    }

    return @unlink($realFile);
}

// หน้าที่: รวบรวมไฟล์ที่ส่งมากับคำขอเพื่อให้ API ประมวลผล.
function collectUploadedFiles(string $key): array
{
    $files = [];

    if (!isset($_FILES[$key])) {
        return $files;
    }

    if (is_array($_FILES[$key]['name'])) {
        foreach ($_FILES[$key]['name'] as $index => $name) {
            $tmp = $_FILES[$key]['tmp_name'][$index] ?? '';
            $files[] = [
                'name' => $name,
                'type' => $_FILES[$key]['type'][$index] ?? '',
                'tmp_name' => $tmp,
                'error' => $_FILES[$key]['error'][$index] ?? UPLOAD_ERR_NO_FILE,
                'size' => $_FILES[$key]['size'][$index] ?? 0,
            ];
        }
    } else {
        $files[] = $_FILES[$key];
    }

    return $files;
}