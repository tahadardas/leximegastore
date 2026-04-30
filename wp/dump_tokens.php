<?php
require_once('wp-load.php');
global $wpdb;
$table = $wpdb->prefix . 'lexi_push_tokens';
$results = $wpdb->get_results("SELECT * FROM {$table} ORDER BY updated_at DESC LIMIT 10", ARRAY_A);

header('Content-Type: application/json');
echo json_encode($results, JSON_PRETTY_PRINT);
