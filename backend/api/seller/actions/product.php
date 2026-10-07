<?php

defined('SELLER_API') or exit('Forbidden');

// ============================================================
// PRODUCT ACTIONS
// categories, seller_products, add_product, product_variants,
// product_images, update_product, delete_product
// ============================================================


function loadProductImages(mysqli $conn, int $productId): array
{
    $images = [];

    $stmt = $conn->prepare(
        "SELECT image_id, image_product_id, image_data
         FROM product_images
         WHERE image_product_id = ?
         ORDER BY image_id ASC"
    );

    if (!$stmt) {
        return $images;
    }

    $stmt->bind_param("i", $productId);
    $stmt->execute();

    $res = $stmt->get_result();

    while ($row = $res->fetch_assoc()) {
        $images[] = [
            'image_id'         => intval($row['image_id']),
            'image_product_id' => intval($row['image_product_id']),
            'image_path'       => $row['image_data'],
            'image_url'        => imageUrlFromPath($row['image_data']),
        ];
    }

    $stmt->close();

    return $images;
}


// บันทึกรูปที่อัปโหลดมา (images[]) ลง DB คืนจำนวนที่สำเร็จ
function insertProductImages(
    mysqli $conn,
    int $productId,
    ?string &$failureReason = null
): int
{
    $count = 0;
    $failureReason = null;
    $files = collectUploadedFiles('images');

    if (empty($files)) {
        $failureReason = 'ไม่พบไฟล์รูปที่ส่งมาจากแอป กรุณาเลือกรูปใหม่';
        return 0;
    }

    foreach ($files as $file) {

        $path = saveUploadedProductImage($file, $productId, $failureReason);

        if ($path === null) {
            continue;
        }

        $img = null;

        try {
            $img = $conn->prepare(
                "INSERT INTO product_images (image_product_id, image_data)
                 VALUES (?, ?)"
            );

            if (!$img) {
                deleteStoredFile($path);
                $failureReason = 'บันทึกข้อมูลรูปลงตาราง product_images ไม่สำเร็จ';
                continue;
            }

            $img->bind_param("is", $productId, $path);

            if ($img->execute()) {
                $count++;
            } else {
                deleteStoredFile($path);
                $failureReason = 'บันทึกข้อมูลรูปลงตาราง product_images ไม่สำเร็จ';
            }
        } catch (Throwable $e) {
            deleteStoredFile($path);
            $failureReason = 'บันทึกข้อมูลรูปลงตาราง product_images ไม่สำเร็จ';
            error_log('Product image insert failed: ' . $e->getMessage());
        } finally {
            if ($img instanceof mysqli_stmt) {
                $img->close();
            }
        }
    }

    if ($count > 0) {
        $failureReason = null;
    }

    return $count;
}


switch ($action) {


    // ========================================================
    // CATEGORIES
    // ========================================================

    case 'categories':

        $result = $conn->query(
            "SELECT category_id, category_name
             FROM categories
             WHERE category_status = 'active'
             ORDER BY category_name"
        );

        if (!$result) {
            errorResponse("โหลดหมวดหมู่ไม่สำเร็จ: " . $conn->error);
        }

        $rows = [];

        while ($r = $result->fetch_assoc()) {
            $rows[] = $r;
        }

        successResponse("สำเร็จ", ["categories" => $rows]);

        break;


    // ========================================================
    // SELLER PRODUCTS
    // ========================================================

    case 'seller_products':

        $sellerId = sellerIdValue();

        if ($sellerId <= 0) {
            errorResponse("ไม่พบรหัสผู้ขาย");
        }

        if (!sellerExists($conn, $sellerId)) {
            errorResponse("ไม่พบผู้ขายหรือบัญชีไม่ใช่ seller");
        }

        $stmt = $conn->prepare(
            "SELECT
                p.product_id,
                p.product_seller_id,
                p.category_id,
                p.product_name,
                p.product_description,
                p.product_price,
                p.stock,
                p.product_status,
                c.category_name

             FROM products p

             LEFT JOIN categories c
                ON c.category_id = p.category_id

             WHERE p.product_seller_id = ?

             AND p.product_status IN (
                'active', 'pending', 'rejected', 'inactive'
             )

             ORDER BY p.product_id DESC"
        );

        if (!$stmt) {
            errorResponse("ไม่สามารถโหลดสินค้าได้: " . $conn->error);
        }

        $stmt->bind_param("i", $sellerId);

        if (!$stmt->execute()) {
            $error = $stmt->error;
            $stmt->close();
            errorResponse("โหลดสินค้าไม่สำเร็จ: " . $error);
        }

        $result = $stmt->get_result();

        $products = [];

        while ($row = $result->fetch_assoc()) {

            $images = loadProductImages($conn, intval($row['product_id']));

            $products[] = [
                "product_id"          => intval($row['product_id']),
                "product_seller_id"   => intval($row['product_seller_id']),
                "category_id"         => intval($row['category_id']),
                "product_name"        => $row['product_name'],
                "product_description" => $row['product_description'],
                "product_price"       => floatval($row['product_price']),
                "stock"               => intval($row['stock']),
                "product_status"      => $row['product_status'],
                "category_name"       => $row['category_name'] ?? '',
                "image_url"           => !empty($images) ? $images[0]['image_url'] : null,
                "images"              => $images,
            ];
        }

        $stmt->close();

        successResponse("โหลดสินค้าสำเร็จ", ["products" => $products]);

        break;


    // ========================================================
    // ADD PRODUCT
    // ========================================================

    case 'add_product':

        $sellerId    = sellerIdValue();
        $categoryId  = idv('category_id');
        $name        = trim($_POST['product_name'] ?? '');
        $description = trim($_POST['product_description'] ?? '');
        $price       = floatval($_POST['product_price'] ?? 0);
        $stock       = intval($_POST['stock'] ?? 0);
        $variantsJson = $_POST['variants'] ?? '[]';

        if (
            $sellerId <= 0 ||
            $categoryId <= 0 ||
            $name === '' ||
            $price < 0 ||
            $stock < 0
        ) {
            errorResponse("ข้อมูลสินค้าไม่ครบหรือไม่ถูกต้อง");
        }

        if (!sellerExists($conn, $sellerId)) {
            errorResponse("ไม่พบผู้ขายหรือบัญชีไม่ใช่ seller");
        }

        $conn->begin_transaction();

        $stmt = $conn->prepare(
            "INSERT INTO products
            (
                product_seller_id,
                category_id,
                product_name,
                product_description,
                product_price,
                stock,
                product_status
            )
            VALUES (?, ?, ?, ?, ?, ?, 'pending')"
        );

        if (!$stmt) {
            errorResponse("ไม่สามารถเพิ่มสินค้าได้: " . $conn->error);
        }

        $stmt->bind_param(
            "iissdi",
            $sellerId,
            $categoryId,
            $name,
            $description,
            $price,
            $stock
        );

        if (!$stmt->execute()) {
            $error = $stmt->error;
            $stmt->close();
            errorResponse("เพิ่มสินค้าไม่สำเร็จ: " . $error);
        }

        $productId = $conn->insert_id;

        $stmt->close();

        // variants
        saveProductVariants($conn, $productId, $variantsJson);

        // images
        $imageFailureReason = null;
        $uploadedImages = insertProductImages(
            $conn,
            $productId,
            $imageFailureReason
        );

        if ($uploadedImages === 0) {
            $conn->rollback();
            errorResponse(
                $imageFailureReason ?? "บันทึกรูปสินค้าไม่สำเร็จ กรุณาลองใหม่"
            );
        }

        // stock movement
        if ($stock > 0) {

            $mv = $conn->prepare(
                "INSERT INTO stock_movements
                (
                    movement_product_id,
                    movement_seller_id,
                    movement_type,
                    movement_quantity,
                    note
                )
                VALUES (?, ?, 'IN', ?, 'เพิ่มสินค้าใหม่')"
            );

            if ($mv) {
                $mv->bind_param("iii", $productId, $sellerId, $stock);
                $mv->execute();
                $mv->close();
            }
        }

        $conn->commit();

        successResponse(
            "ส่งสินค้าเพื่อรออนุมัติแล้ว",
            [
                "product_id"     => $productId,
                "product_status" => "pending",
                "image_count"    => $uploadedImages,
            ]
        );

        break;


    // ========================================================
    // PRODUCT VARIANTS
    // ========================================================

    case 'product_variants':

        $productId = idv('product_id');

        if ($productId <= 0) {
            errorResponse("ไม่พบ product_id");
        }

        $stmt = $conn->prepare(
            "SELECT
                variant_id,
                variant_product_id,
                variant_size,
                variant_color,
                variant_price,
                variant_stock,
                variant_status
             FROM product_variants
             WHERE variant_product_id = ?
             ORDER BY variant_id ASC"
        );

        if (!$stmt) {
            errorResponse("โหลดรายละเอียดไซส์ไม่สำเร็จ: " . $conn->error);
        }

        $stmt->bind_param("i", $productId);
        $stmt->execute();
        $result = $stmt->get_result();

        $variants = [];

        while ($row = $result->fetch_assoc()) {

            $variants[] = [
                'variant_id'         => intval($row['variant_id']),
                'variant_product_id' => intval($row['variant_product_id']),
                'variant_size'       => $row['variant_size'],
                'variant_color'      => $row['variant_color'],
                'variant_price'      => floatval($row['variant_price']),
                'variant_stock'      => intval($row['variant_stock']),
                'variant_status'     => $row['variant_status'],

                // ชื่อสั้น ให้ ProductVariant.fromJson ใน Flutter อ่านได้
                'size'  => $row['variant_size'],
                'color' => $row['variant_color'],
                'price' => floatval($row['variant_price']),
                'stock' => intval($row['variant_stock']),
            ];
        }

        $stmt->close();

        successResponse("สำเร็จ", ["variants" => $variants]);

        break;


    // ========================================================
    // PRODUCT IMAGES
    // ========================================================

    case 'product_images':

        $productId = idv('product_id');

        if ($productId <= 0) {
            errorResponse("ไม่พบ product_id");
        }

        successResponse(
            "สำเร็จ",
            [
                "product_id" => $productId,
                "images"     => loadProductImages($conn, $productId),
            ]
        );

        break;


    // ========================================================
    // UPDATE PRODUCT
    // ========================================================

    case 'update_product':

        $sellerId    = sellerIdValue();
        $productId   = idv('product_id');
        $categoryId  = idv('category_id');
        $name        = trim($_POST['product_name'] ?? '');
        $description = trim($_POST['product_description'] ?? '');
        $price       = floatval($_POST['product_price'] ?? 0);
        $stock       = intval($_POST['stock'] ?? 0);
        $variantsJson = $_POST['variants'] ?? '[]';

        if (
            $sellerId <= 0 ||
            $productId <= 0 ||
            $categoryId <= 0 ||
            $name === '' ||
            $price < 0 ||
            $stock < 0
        ) {
            errorResponse("ข้อมูลสินค้าไม่ครบหรือไม่ถูกต้อง");
        }

        if (!sellerExists($conn, $sellerId)) {
            errorResponse("ไม่พบผู้ขายหรือบัญชีไม่ใช่ seller");
        }

        // ดึงสินค้าเดิม
        $check = $conn->prepare(
            "SELECT stock, product_status
             FROM products
             WHERE product_id = ?
               AND product_seller_id = ?
             LIMIT 1"
        );

        if (!$check) {
            errorResponse("ตรวจสอบสินค้าไม่สำเร็จ: " . $conn->error);
        }

        $check->bind_param("ii", $productId, $sellerId);
        $check->execute();

        $checkResult = $check->get_result();

        if ($checkResult->num_rows === 0) {
            $check->close();
            errorResponse("ไม่พบสินค้าหรือสินค้านี้ไม่ใช่ของคุณ");
        }

        $oldProduct = $checkResult->fetch_assoc();
        $oldStock   = intval($oldProduct['stock']);
        $oldStatus  = $oldProduct['product_status'];

        $check->close();

        if ($oldStatus === 'inactive') {
            errorResponse("สินค้านี้ปิดการขายแล้ว ไม่สามารถแก้ไขได้");
        }

        // active -> active, pending -> pending, rejected -> pending
        if ($oldStatus === 'rejected') {

            $stmt = $conn->prepare(
                "UPDATE products
                 SET
                    category_id = ?,
                    product_name = ?,
                    product_description = ?,
                    product_price = ?,
                    stock = ?,
                    product_status = 'pending'
                 WHERE product_id = ?
                   AND product_seller_id = ?
                   AND product_status = 'rejected'"
            );

        } else {

            $stmt = $conn->prepare(
                "UPDATE products
                 SET
                    category_id = ?,
                    product_name = ?,
                    product_description = ?,
                    product_price = ?,
                    stock = ?
                 WHERE product_id = ?
                   AND product_seller_id = ?
                   AND product_status IN ('active', 'pending')"
            );
        }

        if (!$stmt) {
            errorResponse("ไม่สามารถแก้ไขสินค้าได้: " . $conn->error);
        }

        $stmt->bind_param(
            "issdiii",
            $categoryId,
            $name,
            $description,
            $price,
            $stock,
            $productId,
            $sellerId
        );

        if (!$stmt->execute()) {
            $error = $stmt->error;
            $stmt->close();
            errorResponse("แก้ไขสินค้าไม่สำเร็จ: " . $error);
        }

        $stmt->close();

        // แทนที่ variants ทั้งหมด
        $deleteVariants = $conn->prepare(
            "DELETE FROM product_variants WHERE variant_product_id = ?"
        );

        if ($deleteVariants) {
            $deleteVariants->bind_param("i", $productId);
            $deleteVariants->execute();
            $deleteVariants->close();
        }

        saveProductVariants($conn, $productId, $variantsJson);

        // ลบรูปเก่า
        $deletedIds = json_decode($_POST['deleted_image_ids'] ?? '[]', true);

        $deletedCount = 0;

        if (is_array($deletedIds)) {

            foreach ($deletedIds as $id) {

                $imageId = intval($id);

                if ($imageId <= 0) {
                    continue;
                }

                $q = $conn->prepare(
                    "SELECT image_data
                     FROM product_images
                     WHERE image_id = ?
                       AND image_product_id = ?
                     LIMIT 1"
                );

                if (!$q) {
                    continue;
                }

                $q->bind_param("ii", $imageId, $productId);
                $q->execute();

                $oldImage = $q->get_result()->fetch_assoc();

                $q->close();

                if (!$oldImage) {
                    continue;
                }

                $path = $oldImage['image_data'];

                $d = $conn->prepare(
                    "DELETE FROM product_images
                     WHERE image_id = ?
                       AND image_product_id = ?"
                );

                if (!$d) {
                    continue;
                }

                $d->bind_param("ii", $imageId, $productId);

                if ($d->execute() && $d->affected_rows > 0) {
                    $deletedCount++;
                    deleteStoredFile($path);
                }

                $d->close();
            }
        }

        // เพิ่มรูปใหม่
        $newImageCount = insertProductImages($conn, $productId);

        // stock movement
        $diff = $stock - $oldStock;

        if ($diff !== 0) {

            $type = $diff > 0 ? 'IN' : 'OUT';
            $qty  = abs($diff);
            $note = 'ปรับสต็อกสินค้า';

            $mv = $conn->prepare(
                "INSERT INTO stock_movements
                (
                    movement_product_id,
                    movement_seller_id,
                    movement_type,
                    movement_quantity,
                    note
                )
                VALUES (?, ?, ?, ?, ?)"
            );

            if ($mv) {
                $mv->bind_param("iisis", $productId, $sellerId, $type, $qty, $note);
                $mv->execute();
                $mv->close();
            }
        }

        $newStatus = $oldStatus === 'rejected' ? 'pending' : $oldStatus;

        successResponse(
            $oldStatus === 'rejected'
                ? "แก้ไขสินค้าแล้ว กรุณารอ Admin อนุมัติอีกครั้ง"
                : "แก้ไขสินค้าเรียบร้อยแล้ว",
            [
                "product_id"          => $productId,
                "product_status"      => $newStatus,
                "deleted_image_count" => $deletedCount,
                "new_image_count"     => $newImageCount,
            ]
        );

        break;


    // ========================================================
    // DELETE PRODUCT
    // rejected = ลบถาวร, active/pending = ปิดการขาย (inactive)
    // ========================================================

    case 'delete_product':

        $sellerId  = sellerIdValue();
        $productId = idv('product_id');

        if ($sellerId <= 0) {
            errorResponse("ไม่พบ seller_id");
        }

        if ($productId <= 0) {
            errorResponse("ไม่พบ product_id");
        }

        $checkStmt = $conn->prepare(
            "SELECT product_id, product_status
             FROM products
             WHERE product_id = ?
               AND product_seller_id = ?
             LIMIT 1"
        );

        if (!$checkStmt) {
            errorResponse("ตรวจสอบสินค้าไม่สำเร็จ: " . $conn->error);
        }

        $checkStmt->bind_param("ii", $productId, $sellerId);
        $checkStmt->execute();

        $result = $checkStmt->get_result();

        if ($result->num_rows === 0) {
            $checkStmt->close();
            errorResponse("ไม่พบสินค้าของผู้ขายรายนี้");
        }

        $product = $result->fetch_assoc();

        $checkStmt->close();

        $status = $product['product_status'];


        // ---------- REJECTED : ลบจริง ----------

        if ($status === 'rejected') {

            $imagePaths = [];

            $imageStmt = $conn->prepare(
                "SELECT image_data
                 FROM product_images
                 WHERE image_product_id = ?"
            );

            if ($imageStmt) {

                $imageStmt->bind_param("i", $productId);
                $imageStmt->execute();

                $imageResult = $imageStmt->get_result();

                while ($image = $imageResult->fetch_assoc()) {
                    $imagePaths[] = $image['image_data'];
                }

                $imageStmt->close();
            }

            $deleteImages = $conn->prepare(
                "DELETE FROM product_images WHERE image_product_id = ?"
            );

            if ($deleteImages) {

                $deleteImages->bind_param("i", $productId);

                if (!$deleteImages->execute()) {
                    $error = $deleteImages->error;
                    $deleteImages->close();
                    errorResponse("ลบรูปสินค้าไม่สำเร็จ: " . $error);
                }

                $deleteImages->close();
            }

            foreach ($imagePaths as $imagePath) {
                deleteStoredFile($imagePath);
            }

            $deleteProduct = $conn->prepare(
                "DELETE FROM products
                 WHERE product_id = ?
                   AND product_seller_id = ?
                   AND product_status = 'rejected'"
            );

            if (!$deleteProduct) {
                errorResponse("ไม่สามารถลบสินค้าได้: " . $conn->error);
            }

            $deleteProduct->bind_param("ii", $productId, $sellerId);

            if (!$deleteProduct->execute()) {
                $error = $deleteProduct->error;
                $deleteProduct->close();
                errorResponse("ลบสินค้าไม่สำเร็จ: " . $error);
            }

            if ($deleteProduct->affected_rows <= 0) {
                $deleteProduct->close();
                errorResponse("ไม่สามารถลบสินค้าได้");
            }

            $deleteProduct->close();

            successResponse(
                "ลบสินค้าที่ถูกปฏิเสธเรียบร้อยแล้ว",
                [
                    "product_id"     => $productId,
                    "product_status" => "deleted",
                ]
            );

            break;
        }


        // ---------- INACTIVE : ปิดอยู่แล้ว ----------

        if ($status === 'inactive') {

            successResponse(
                "สินค้านี้ถูกปิดการขายแล้ว",
                [
                    "product_id"     => $productId,
                    "product_status" => "inactive",
                ]
            );

            break;
        }


        // ---------- ACTIVE / PENDING : ปิดการขาย ----------

        if ($status === 'active' || $status === 'pending') {

            $stmt = $conn->prepare(
                "UPDATE products
                 SET product_status = 'inactive'
                 WHERE product_id = ?
                   AND product_seller_id = ?
                   AND product_status IN ('active', 'pending')"
            );

            if (!$stmt) {
                errorResponse("ไม่สามารถปิดการขายสินค้าได้: " . $conn->error);
            }

            $stmt->bind_param("ii", $productId, $sellerId);

            if (!$stmt->execute()) {
                $error = $stmt->error;
                $stmt->close();
                errorResponse("ปิดการขายสินค้าไม่สำเร็จ: " . $error);
            }

            $stmt->close();

            successResponse(
                "ปิดการขายสินค้าเรียบร้อยแล้ว",
                [
                    "product_id"     => $productId,
                    "product_status" => "inactive",
                ]
            );

            break;
        }

        errorResponse("ไม่สามารถดำเนินการกับสถานะสินค้านี้ได้");

        break;
}
