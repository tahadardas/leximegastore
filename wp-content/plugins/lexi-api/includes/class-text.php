<?php
/**
 * Text normalization helpers for Arabic-safe API and email output.
 *
 * @package Lexi_API
 */

defined('ABSPATH') || exit;

class Lexi_Text
{
    /**
     * Normalize a single text value and repair common mojibake sequences.
     */
    public static function normalize($value): string
    {
        $text = (string) $value;
        if ('' === $text) {
            return '';
        }

        // Keep valid UTF-8 bytes whenever possible.
        $utf8 = wp_check_invalid_utf8($text, true);
        if (is_string($utf8) && '' !== $utf8) {
            $text = $utf8;
        }

        // Logic check: if text is already valid UTF-8 and contains Arabic,
        // we should be very careful about "fixing" it.
        if (self::arabic_score($text) > 0) {
            return $text;
        }

        if (!self::looks_mojibake($text) || !function_exists('mb_convert_encoding')) {
            return $text;
        }

        $fixed = $text;
        // Try one or two passes for double-encoded payloads.
        for ($i = 0; $i < 2; $i++) {
            $candidate = @mb_convert_encoding($fixed, 'ISO-8859-1', 'UTF-8');
            if (!is_string($candidate) || '' === $candidate) {
                break;
            }

            $candidate_utf8 = wp_check_invalid_utf8($candidate, true);
            if (!is_string($candidate_utf8) || '' === $candidate_utf8) {
                break;
            }

            if (self::arabic_score($candidate_utf8) <= self::arabic_score($fixed)) {
                break;
            }

            $fixed = $candidate_utf8;
        }

        return $fixed;
    }

    /**
     * Deep-normalize arrays/maps recursively.
     *
     * @param mixed $value
     * @return mixed
     */
    public static function normalize_deep($value)
    {
        if (is_array($value)) {
            $result = array();
            foreach ($value as $key => $row) {
                $result[$key] = self::normalize_deep($row);
            }
            return $result;
        }

        if (is_string($value)) {
            return self::normalize($value);
        }

        return $value;
    }

    private static function looks_mojibake(string $text): bool
    {
        // Only trigger on common mojibake patterns that are unlikely in valid text.
        // We use hex codes to avoid encoding issues in this source file.
        // \xC3\x83 is Ã, \xC3\x82 is Â.
        return (bool) preg_match('/(\xC3\x83.|\xC3\x82.)/u', $text);
    }

    private static function arabic_score(string $text): int
    {
        if ('' === $text) {
            return 0;
        }
        preg_match_all('/[\x{0600}-\x{06FF}]/u', $text, $matches);
        return isset($matches[0]) && is_array($matches[0]) ? count($matches[0]) : 0;
    }
}
