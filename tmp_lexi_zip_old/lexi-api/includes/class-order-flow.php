<?php
/**
 * Shared order/payment/status helpers for operational flows.
 *
 * @package Lexi_API
 */

defined('ABSPATH') || exit;

class Lexi_Order_Flow
{
    public const PAYMENT_METHOD_COD = 'cod';
    public const PAYMENT_METHOD_SHAMCASH = 'sham_cash';
    public const PAYMENT_METHOD_SHAMCASH_LEGACY = 'shamcash';

    public const STATUS_PENDING_VERIFICATION = 'pending-verification';
    public const STATUS_PENDING_VERIFICATION_LEGACY = 'pending-verificat';
    public const STATUS_OUT_FOR_DELIVERY = 'out-for-delivery';
    public const STATUS_DELIVERED_UNPAID = 'delivered-unpaid';

    /**
     * @return array<int,string>
     */
    public static function shamcash_payment_ids(): array
    {
        return array(
            self::PAYMENT_METHOD_SHAMCASH,
            self::PAYMENT_METHOD_SHAMCASH_LEGACY,
        );
    }

    public static function canonical_shamcash_payment_id(): string
    {
        return self::PAYMENT_METHOD_SHAMCASH;
    }

    public static function normalize_payment_method(string $raw): string
    {
        $value = strtolower(trim($raw));
        $value = str_replace('-', '_', $value);

        if ($value === self::PAYMENT_METHOD_COD) {
            return self::PAYMENT_METHOD_COD;
        }

        if (in_array($value, self::shamcash_payment_ids(), true)) {
            return self::PAYMENT_METHOD_SHAMCASH;
        }

        return $value;
    }

    public static function is_shamcash_method(string $raw): bool
    {
        return in_array(
            self::normalize_payment_method($raw),
            self::shamcash_payment_ids(),
            true
        ) || self::normalize_payment_method($raw) === self::PAYMENT_METHOD_SHAMCASH;
    }

    public static function resolve_order_payment_method(WC_Order $order): string
    {
        $meta = (string) $order->get_meta('_lexi_payment_method');
        if (trim($meta) !== '') {
            return self::normalize_payment_method($meta);
        }

        return self::normalize_payment_method((string) $order->get_payment_method());
    }

    public static function is_shamcash_order(WC_Order $order): bool
    {
        return self::resolve_order_payment_method($order) === self::PAYMENT_METHOD_SHAMCASH;
    }

    public static function is_cod_order(WC_Order $order): bool
    {
        return self::resolve_order_payment_method($order) === self::PAYMENT_METHOD_COD;
    }

    public static function normalize_public_status(string $raw): string
    {
        $status = strtolower(trim($raw));
        if (strpos($status, 'wc-') === 0) {
            $status = substr($status, 3);
        }
        $status = str_replace('_', '-', $status);

        if (in_array(
            $status,
            self::pending_verification_statuses(),
            true
        )) {
            return self::STATUS_PENDING_VERIFICATION;
        }

        return $status;
    }

    /**
     * DB-safe status used when persisting ShamCash "pending verification".
     *
     * WordPress `post_status` is limited to 20 chars. The full key
     * `wc-pending-verification` can be truncated by storage layers, so we store
     * the safe slug and normalize to `pending-verification` in API responses.
     */
    public static function pending_verification_storage_status(): string
    {
        return self::STATUS_PENDING_VERIFICATION_LEGACY;
    }

    /**
     * @return array<int,string>
     */
    public static function pending_verification_statuses(): array
    {
        return array(
            self::STATUS_PENDING_VERIFICATION,
            self::STATUS_PENDING_VERIFICATION_LEGACY,
            'on-hold',
        );
    }
}
