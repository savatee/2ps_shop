<?php
require_once __DIR__ . '/../config/bootstrap.php';

$action = $_GET['action'] ?? $_POST['action'] ?? 'read_products';

// สถานะออเดอร์ที่นับเป็น "ขายแล้ว"
const SOLD_ORDER_STATUSES = "'paid', 'processing', 'shipping', 'completed'";
// จำนวนสินค้าสูงสุดต่อหนึ่งหน้า (กันไม่ให้ client ขอทีละมากเกินไป)
const MAX_PAGE_SIZE = 100;

/* ------------------------------------------------------------------ */
/* Helpers                                                              */
/* ------------------------------------------------------------------ */

function requestInt(string $key, int $default = 0): int
{
    $value = $_GET[$key] ?? $_POST[$key] ?? $default;
    return is_numeric($value) ? (int)$value : $default;
}

// หน้าที่: อ่านและตรวจสอบ flag ที่ส่งมากับคำขอ API.
function requestFlag(string $key): bool
{
    $value = strtolower((string)($_GET[$key] ?? $_POST[$key] ?? ''));
    return in_array($value, ['1', 'true', 'yes'], true);
}

/**
 * อ่าน limit/offset จาก request
 * ไม่ส่ง limit มา = ไม่แบ่งหน้า (คงพฤติกรรมเดิมไว้ให้หน้าที่ยังไม่ได้แก้)
 *
 * @return array{0: ?int, 1: int}
 */
function pageParams(): array
{
    $limit = requestInt('limit', 0);
    if ($limit <= 0) {
        return [null, 0];
    }
    return [min($limit, MAX_PAGE_SIZE), max(0, requestInt('offset', 0))];
}

/**
 * SELECT พื้นฐานของสินค้า (รูปแรก + ชื่อหมวด + ชื่อผู้ขาย + ยอดขาย)
 * $extraSelect / $extraJoin ใช้เพิ่มคอลัมน์หรือ JOIN เฉพาะ action
 */
function productSelectSql(string $extraSelect = '', string $extraJoin = ''): string
{
    $sold = SOLD_ORDER_STATUSES;
    return "SELECT p.*, c.category_name, s.name AS seller_name,
        (SELECT pi.image_data FROM product_images pi
            WHERE pi.image_product_id = p.product_id
            ORDER BY pi.image_id ASC LIMIT 1) AS product_image,
        COALESCE((SELECT SUM(oi.item_quantity)
            FROM order_items oi
            INNER JOIN orders o ON o.order_id = oi.item_order_id
            WHERE oi.item_product_id = p.product_id
              AND o.order_status IN ($sold)), 0) AS sold_count
        $extraSelect
        FROM products p
        LEFT JOIN categories c ON p.category_id = c.category_id
        LEFT JOIN users s ON p.product_seller_id = s.user_id
        $extraJoin ";
}

/**
 * เงื่อนไขกรองที่ใช้ร่วมกัน: category_id, seller_id, exclude_id, in_stock
 *
 * @return array{0: string[], 1: string, 2: array}
 */
function productFilters(): array
{
    $where = ["p.product_status = 'active'"];
    $types = '';
    $params = [];

    $categoryId = requestInt('category_id');
    if ($categoryId > 0) {
        $where[] = 'p.category_id = ?';
        $types .= 'i';
        $params[] = $categoryId;
    }

    $sellerId = requestInt('seller_id');
    if ($sellerId > 0) {
        $where[] = 'p.product_seller_id = ?';
        $types .= 'i';
        $params[] = $sellerId;
    }

    $excludeId = requestInt('exclude_id');
    if ($excludeId > 0) {
        $where[] = 'p.product_id <> ?';
        $types .= 'i';
        $params[] = $excludeId;
    }

    if (requestFlag('in_stock')) {
        $where[] = 'p.stock > 0';
    }

    return [$where, $types, $params];
}

/** ต่อ LIMIT/OFFSET ท้าย SQL เมื่อ client ขอแบ่งหน้า */
function appendPaging(string $sql, string &$types, array &$params): string
{
    [$limit, $offset] = pageParams();
    if ($limit === null) {
        return $sql;
    }
    $types .= 'ii';
    $params[] = $limit;
    $params[] = $offset;
    return $sql . ' LIMIT ? OFFSET ?';
}

// หน้าที่: โหลดข้อมูล fetch สินค้า และอัปเดตสถานะการแสดงผลของหน้าจอ.
function fetchProducts(mysqli $conn, string $sql, string $types, array $params): array
{
    $stmt = $conn->prepare($sql);
    if (!$stmt) {
        errorResponse('โหลดสินค้าไม่สำเร็จ', 500, $conn->error);
    }
    if ($types !== '') {
        $stmt->bind_param($types, ...$params);
    }
    if (!$stmt->execute()) {
        $error = $stmt->error;
        $stmt->close();
        errorResponse('โหลดสินค้าไม่สำเร็จ', 500, $error);
    }
    $result = $stmt->get_result();
    $rows = [];
    while ($row = $result->fetch_assoc()) {
        $rows[] = $row;
    }
    $stmt->close();
    return $rows;
}

/* ------------------------------------------------------------------ */
/* Actions                                                              */
/* ------------------------------------------------------------------ */

switch ($action) {
    // รายการสินค้า (ใหม่สุดก่อน)
    // พารามิเตอร์เสริม: limit, offset, category_id, seller_id, exclude_id, in_stock=1
    case 'read_products':
        [$where, $types, $params] = productFilters();
        $sql = productSelectSql()
            . 'WHERE ' . implode(' AND ', $where)
            . ' ORDER BY p.product_id DESC';
        $sql = appendPaging($sql, $types, $params);
        successResponse('โหลดสินค้าสำเร็จ', fetchProducts($conn, $sql, $types, $params));
        break;

    // สินค้ายอดนิยม: เฉพาะสินค้าที่เคยขายได้จริง เรียงตามยอดขาย
    // พารามิเตอร์เสริม: limit (ค่าเริ่มต้น 10, สูงสุด 50), in_stock=1
    case 'popular_products':
        [$where, $types, $params] = productFilters();
        $sold = SOLD_ORDER_STATUSES;
        $where[] = "EXISTS (SELECT 1 FROM order_items oi2
                INNER JOIN orders o2 ON o2.order_id = oi2.item_order_id
                WHERE oi2.item_product_id = p.product_id
                  AND o2.order_status IN ($sold))";
        $limit = max(1, min(requestInt('limit', 10), 50));
        $types .= 'i';
        $params[] = $limit;
        $sql = productSelectSql()
            . 'WHERE ' . implode(' AND ', $where)
            . ' ORDER BY sold_count DESC, p.product_id DESC LIMIT ?';
        successResponse('โหลดสินค้ายอดนิยมสำเร็จ', fetchProducts($conn, $sql, $types, $params));
        break;

    // สินค้าแนะนำเฉพาะผู้ใช้ (ต้องมี token)
    // 1) หมวดที่ผู้ใช้เคยซื้อมากที่สุดมาก่อน  2) ยอดขายรวม  3) ใหม่สุด
    // ตัดสินค้าของตัวเองและสินค้าหมดสต็อกออก สินค้าที่เคยซื้อยังแนะนำซ้ำได้
    // พารามิเตอร์เสริม: limit, offset
    case 'recommended_products':
        $user = requireUser($conn);
        $userId = (int)$user['user_id'];
        $sold = SOLD_ORDER_STATUSES;

        $extraSelect = ', COALESCE(pref.score, 0) AS pref_score';
        $extraJoin = "LEFT JOIN (
                SELECT p2.category_id, SUM(oi3.item_quantity) AS score
                FROM order_items oi3
                INNER JOIN orders o3 ON o3.order_id = oi3.item_order_id
                INNER JOIN products p2 ON p2.product_id = oi3.item_product_id
                WHERE o3.order_buyer_id = ?
                  AND o3.order_status IN ($sold)
                GROUP BY p2.category_id
            ) pref ON pref.category_id = p.category_id";

        // ลำดับ ? ต้องตรงกับลำดับใน SQL: JOIN -> WHERE -> LIMIT
        $types = 'i';
        $params = [$userId];

        $where = [
            "p.product_status = 'active'",
            'p.stock > 0',
            'p.product_seller_id <> ?',
        ];
        $types .= 'i';
        $params[] = $userId;

        $sql = productSelectSql($extraSelect, $extraJoin)
            . 'WHERE ' . implode(' AND ', $where)
            . ' ORDER BY pref_score DESC, sold_count DESC, p.product_id DESC';
        $sql = appendPaging($sql, $types, $params);
        successResponse('โหลดสินค้าแนะนำสำเร็จ', fetchProducts($conn, $sql, $types, $params));
        break;

    case 'get_product':
        $productId = intval($_GET['product_id'] ?? 0);
        $rows = fetchProducts(
            $conn,
            productSelectSql() . 'WHERE p.product_id = ? LIMIT 1',
            'i',
            [$productId]
        );
        $product = $rows[0] ?? null;
        if (!$product) {
            errorResponse('ไม่พบสินค้า');
        }

        $variantStmt = $conn->prepare(
            "SELECT variant_id, variant_size, variant_color, variant_price,
                    variant_stock
             FROM product_variants
             WHERE variant_product_id = ? AND variant_status = 'active'
             ORDER BY variant_id"
        );
        $variantStmt->bind_param('i', $productId);
        $variantStmt->execute();
        $variantResult = $variantStmt->get_result();
        $product['variants'] = [];
        while ($variant = $variantResult->fetch_assoc()) {
            $product['variants'][] = $variant;
        }
        $variantStmt->close();

        successResponse('โหลดสินค้าสำเร็จ', $product);
        break;

    // ค้นหาตามชื่อ/รายละเอียด (รองรับ limit, offset, category_id, in_stock เหมือน read_products)
    case 'search_products':
        $keyword = '%' . trim($_GET['keyword'] ?? '') . '%';
        [$where, $types, $params] = productFilters();
        $where[] = '(p.product_name LIKE ? OR p.product_description LIKE ?)';
        $types .= 'ss';
        $params[] = $keyword;
        $params[] = $keyword;
        $sql = productSelectSql()
            . 'WHERE ' . implode(' AND ', $where)
            . ' ORDER BY p.product_id DESC';
        $sql = appendPaging($sql, $types, $params);
        successResponse('ค้นหาสำเร็จ', fetchProducts($conn, $sql, $types, $params));
        break;

    case 'read_categories':
        $result = $conn->query("SELECT category_id, category_name, category_description, category_status FROM categories WHERE category_status = 'active' ORDER BY category_id DESC");
        $categories = [];
        while ($row = $result->fetch_assoc()) {
            $categories[] = $row;
        }
        successResponse('โหลดหมวดหมู่สำเร็จ', $categories);
        break;

    // สินค้าตามหมวดหมู่ (ตอนนี้ส่ง sold_count มาด้วยแล้ว)
    case 'products_by_category':
        if (requestInt('category_id') <= 0) {
            successResponse('โหลดสินค้าตามหมวดหมู่สำเร็จ', []);
        }
        [$where, $types, $params] = productFilters();
        $sql = productSelectSql()
            . 'WHERE ' . implode(' AND ', $where)
            . ' ORDER BY p.product_id DESC';
        $sql = appendPaging($sql, $types, $params);
        successResponse('โหลดสินค้าตามหมวดหมู่สำเร็จ', fetchProducts($conn, $sql, $types, $params));
        break;

    default:
        errorResponse('Invalid product action');
}
$conn->close();
