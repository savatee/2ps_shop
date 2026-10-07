<?php

defined('SELLER_API') or exit('Forbidden');

// ============================================================
// PRODUCT VARIANTS (ไซส์ / สี)
// ============================================================

function saveProductVariants(mysqli $conn, int $productId, string $variantsJson): void
{
    $variants = json_decode($variantsJson, true);

    if (!is_array($variants)) {
        return;
    }

    foreach ($variants as $variant) {

        if (!is_array($variant)) {
            continue;
        }

        $size         = trim((string)($variant['size'] ?? ''));
        $color        = trim((string)($variant['color'] ?? ''));
        $variantPrice = floatval($variant['price'] ?? 0);
        $variantStock = intval($variant['stock'] ?? 0);

        if ($size === '' && $color === '') {
            continue;
        }

        if ($variantPrice < 0 || $variantStock < 0) {
            continue;
        }

        $stmt = $conn->prepare(
            "INSERT INTO product_variants
            (
                variant_product_id,
                variant_size,
                variant_color,
                variant_price,
                variant_stock,
                variant_status
            )
            VALUES (?, NULLIF(?, ''), NULLIF(?, ''), ?, ?, 'active')"
        );

        if (!$stmt) {
            continue;
        }

        $stmt->bind_param(
            "issdi",
            $productId,
            $size,
            $color,
            $variantPrice,
            $variantStock
        );

        $stmt->execute();
        $stmt->close();
    }
}
