<?php
require_once __DIR__ . '/../config/bootstrap.php';

$action = $_POST['action'] ?? $_GET['action'] ?? '';

function readAddressFields() {
    return [
        trim($_POST['recipient_name'] ?? ''),
        trim($_POST['phone'] ?? ''),
        trim($_POST['details'] ?? ''),
        trim($_POST['subdistrict'] ?? ''),
        trim($_POST['district'] ?? ''),
        trim($_POST['province'] ?? ''),
        trim($_POST['postal_code'] ?? ''),
    ];
}

function validateAddressFields(array $f) {
    if ($f[0] === '') errorResponse("กรุณากรอกชื่อ-นามสกุลผู้รับ");
    if ($f[1] === '') errorResponse("กรุณากรอกเบอร์โทรศัพท์");
    if ($f[2] === '') errorResponse("กรุณากรอกที่อยู่ (บ้านเลขที่, ถนน)");
    if ($f[3] === '') errorResponse("กรุณากรอกตำบล/แขวง");
    if ($f[4] === '') errorResponse("กรุณากรอกอำเภอ/เขต");
    if ($f[5] === '') errorResponse("กรุณากรอกจังหวัด");
    if ($f[6] === '') errorResponse("กรุณากรอกรหัสไปรษณีย์");
}

function execStmt(mysqli_stmt $stmt) {
    if (!$stmt->execute()) {
        $err = $stmt->error;
        $stmt->close();
        throw new RuntimeException($err);
    }
}

function clearDefault($userId) {
    global $conn;
    $stmt = $conn->prepare("UPDATE addresses SET is_default = 0 WHERE address_user_id = ? AND is_default = 1");
    $stmt->bind_param("i", $userId);
    execStmt($stmt);
    $stmt->close();
}

function runInTransaction(callable $fn) {
    global $conn;
    $conn->begin_transaction();
    try {
        $result = $fn();
        $conn->commit();
        return $result;
    } catch (Throwable $e) {
        $conn->rollback();
        errorResponse("บันทึกที่อยู่ไม่สำเร็จ", $e->getMessage());
    }
}

function findOwnedAddress($addressId, $userId) {
    global $conn;
    $stmt = $conn->prepare("SELECT * FROM addresses WHERE address_id = ? AND address_user_id = ? LIMIT 1");
    $stmt->bind_param("ii", $addressId, $userId);
    $stmt->execute();
    $row = $stmt->get_result()->fetch_assoc();
    $stmt->close();
    if (!$row) errorResponse("ไม่พบที่อยู่ของคุณ");
    return $row;
}

// ถ้าผู้ใช้ไม่มีที่อยู่หลักเหลือ ให้เลื่อนที่อยู่ล่าสุดขึ้นมาเป็นหลักให้อัตโนมัติ
function ensureSomeDefault($userId, $excludeId) {
    global $conn;
    $stmt = $conn->prepare("SELECT COUNT(*) AS c FROM addresses WHERE address_user_id = ? AND is_default = 1");
    $stmt->bind_param("i", $userId);
    $stmt->execute();
    $count = intval($stmt->get_result()->fetch_assoc()['c'] ?? 0);
    $stmt->close();
    if ($count > 0) return;

    $next = $conn->prepare("SELECT address_id FROM addresses WHERE address_user_id = ? AND address_id <> ? ORDER BY address_id DESC LIMIT 1");
    $next->bind_param("ii", $userId, $excludeId);
    $next->execute();
    $row = $next->get_result()->fetch_assoc();
    $next->close();
    if (!$row) return;

    $promote = $conn->prepare("UPDATE addresses SET is_default = 1 WHERE address_id = ? AND address_user_id = ?");
    $promote->bind_param("ii", $row['address_id'], $userId);
    execStmt($promote);
    $promote->close();
}

switch ($action) {
    case 'get_addresses':
        $userId = intval($_GET['user_id'] ?? $_POST['user_id'] ?? 0);
        if ($userId <= 0) errorResponse("ไม่พบผู้ใช้");

        $stmt = $conn->prepare("SELECT * FROM addresses WHERE address_user_id = ? ORDER BY is_default DESC, address_id DESC");
        $stmt->bind_param("i", $userId);
        $stmt->execute();
        $res = $stmt->get_result();
        $addresses = [];
        while ($row = $res->fetch_assoc()) { $addresses[] = $row; }
        $stmt->close();
        successResponse("โหลดที่อยู่สำเร็จ", $addresses);
        break;

    case 'add_address':
        $userId = intval($_POST['user_id'] ?? 0);
        if ($userId <= 0) errorResponse("ไม่พบผู้ใช้");

        $fields = readAddressFields();
        validateAddressFields($fields);
        $isDefault = intval($_POST['is_default'] ?? 0) === 1 ? 1 : 0;

        $id = runInTransaction(function () use ($userId, $fields, $isDefault) {
            if ($isDefault) clearDefault($userId);

            $stmt = $GLOBALS['conn']->prepare("INSERT INTO addresses (address_user_id, recipient_name, address_phone, address_detail, subdistrict, district, province, postal_code, is_default) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)");
            $stmt->bind_param("isssssssi", $userId, $fields[0], $fields[1], $fields[2], $fields[3], $fields[4], $fields[5], $fields[6], $isDefault);
            execStmt($stmt);
            $id = $stmt->insert_id;
            $stmt->close();
            return $id;
        });

        successResponse("เพิ่มที่อยู่สำเร็จ", ["address_id" => $id]);
        break;

    case 'update_address':
        $userId = intval($_POST['user_id'] ?? 0);
        $addressId = intval($_POST['address_id'] ?? 0);
        if ($userId <= 0) errorResponse("ไม่พบผู้ใช้");
        if ($addressId <= 0) errorResponse("ไม่พบ Address ID");

        $fields = readAddressFields();
        validateAddressFields($fields);
        $isDefault = intval($_POST['is_default'] ?? 0) === 1 ? 1 : 0;
        findOwnedAddress($addressId, $userId);

        runInTransaction(function () use ($userId, $addressId, $fields, $isDefault) {
            if ($isDefault) clearDefault($userId);

            $stmt = $GLOBALS['conn']->prepare("UPDATE addresses SET recipient_name = ?, address_phone = ?, address_detail = ?, subdistrict = ?, district = ?, province = ?, postal_code = ?, is_default = ? WHERE address_id = ? AND address_user_id = ?");
            $stmt->bind_param("sssssssiii", $fields[0], $fields[1], $fields[2], $fields[3], $fields[4], $fields[5], $fields[6], $isDefault, $addressId, $userId);
            execStmt($stmt);
            $stmt->close();

            if (!$isDefault) ensureSomeDefault($userId, $addressId);
        });

        successResponse("แก้ไขที่อยู่สำเร็จ");
        break;

    case 'set_default_address':
        $userId = intval($_POST['user_id'] ?? 0);
        $addressId = intval($_POST['address_id'] ?? 0);
        if ($userId <= 0) errorResponse("ไม่พบผู้ใช้");
        if ($addressId <= 0) errorResponse("ไม่พบ Address ID");
        findOwnedAddress($addressId, $userId);

        runInTransaction(function () use ($userId, $addressId) {
            clearDefault($userId);

            $stmt = $GLOBALS['conn']->prepare("UPDATE addresses SET is_default = 1 WHERE address_id = ? AND address_user_id = ?");
            $stmt->bind_param("ii", $addressId, $userId);
            execStmt($stmt);
            $stmt->close();
        });

        successResponse("ตั้งเป็นที่อยู่หลักสำเร็จ");
        break;

    case 'delete_address':
        $userId = intval($_POST['user_id'] ?? 0);
        $addressId = intval($_POST['address_id'] ?? 0);
        if ($userId <= 0) errorResponse("ไม่พบผู้ใช้");
        if ($addressId <= 0) errorResponse("ไม่พบ Address ID");
        $address = findOwnedAddress($addressId, $userId);

        $stmt = $conn->prepare("SELECT COUNT(*) AS c FROM orders WHERE order_address_id = ?");
        $stmt->bind_param("i", $addressId);
        $stmt->execute();
        $used = intval($stmt->get_result()->fetch_assoc()['c'] ?? 0);
        $stmt->close();
        if ($used > 0) errorResponse("ไม่สามารถลบได้ เพราะที่อยู่นี้ถูกใช้ในคำสั่งซื้อแล้ว $used รายการ");

        $wasDefault = intval($address['is_default'] ?? 0) === 1;

        runInTransaction(function () use ($userId, $addressId, $wasDefault) {
            $stmt = $GLOBALS['conn']->prepare("DELETE FROM addresses WHERE address_id = ? AND address_user_id = ?");
            $stmt->bind_param("ii", $addressId, $userId);
            execStmt($stmt);
            $stmt->close();

            if ($wasDefault) ensureSomeDefault($userId, $addressId);
        });

        successResponse("ลบที่อยู่สำเร็จ");
        break;

    default:
        errorResponse("Invalid address action");
}
$conn->close();
