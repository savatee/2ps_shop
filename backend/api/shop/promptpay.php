  <?php
// คำนวณ CRC-16/CCITT-FALSE (poly 0x1021, init 0xFFFF) ตามมาตรฐาน EMVCo / Thai QR
function calculateCRC16($payload) {
    $polynomial = 0x1021;
    $result = 0xFFFF;
    for ($i = 0; $i < strlen($payload); $i++) {
        $result ^= (ord($payload[$i]) << 8);
        for ($j = 0; $j < 8; $j++) {
            if ($result & 0x8000) {
                $result = (($result << 1) ^ $polynomial) & 0xFFFF;
            } else {
                $result = ($result << 1) & 0xFFFF;
            }
        }
    }
    return strtoupper(str_pad(dechex($result), 4, '0', STR_PAD_LEFT));
}

// สร้างฟิลด์แบบ TLV: [id 2 หลัก][ความยาว 2 หลัก][ค่า]
function emvField($id, $value) {
    return $id . sprintf("%02d", strlen($value)) . $value;
}

// หน้าที่: สร้าง payload สำหรับนำไปสร้าง QR PromptPay.
function generatePromptPayPayload($target, $amount = null) {
    $target = preg_replace('/[^0-9]/', '', $target);
    if (strlen($target) == 10) {
        // เบอร์มือถือ: ตัด 0 ตัวหน้าออก แล้วใส่รหัสประเทศ 0066 แทน
        $target = "0066" . substr($target, 1);
        $targetType = "01";
    } elseif (strlen($target) == 13) {
        // เลขบัตรประชาชน / เลขผู้เสียภาษี
        $targetType = "02";
    } else {
        return false;
    }

    $hasAmount = ($amount !== null && $amount > 0);

    // tag 29 = ข้อมูลบัญชี PromptPay: AID (00) + ประเภทผู้รับ (01/02)
    $merchantAccount = emvField("00", "A000000677010111") . emvField($targetType, $target);

    $payload  = emvField("00", "01");                       // payload format indicator
    $payload .= emvField("01", $hasAmount ? "12" : "11");   // 11 = QR ใช้ซ้ำ, 12 = QR ระบุยอดครั้งเดียว
    $payload .= emvField("29", $merchantAccount);
    // ลำดับ tag ต้องเรียงจากน้อยไปมากตามมาตรฐาน EMVCo: 53 -> 54 -> 58 -> 63
    $payload .= emvField("53", "764");                      // currency = THB

    if ($hasAmount) {
        $payload .= emvField("54", number_format((float)$amount, 2, '.', ''));
    }

    $payload .= emvField("58", "TH");                       // country code

    $payload .= "6304"; // tag CRC + ความยาว 4 (ต้องรวมใน payload ก่อนคำนวณ)
    $payload .= calculateCRC16($payload);
    return $payload;
}
