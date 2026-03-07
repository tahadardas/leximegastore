<?php
require_once __DIR__ . '/../../../wp-load.php';

$courier_id = 1; // Assuming 1 or we'll get a real courier ID from the DB
$couriers = get_users(['role' => 'delivery_agent']);
if (!empty($couriers)) {
    $courier_id = $couriers[0]->ID;
}
echo "Courier ID: $courier_id\n";

$args = array(
    'limit' => -1,
    'return' => 'objects',
    'status' => array('completed', 'processing', 'delivered-unpaid', 'out-for-delivery'),
    'meta_query' => array(
        'relation' => 'AND',
        array(
            'key' => '_lexi_delivery_agent_id',
            'value' => (string) $courier_id,
            'compare' => '=',
        ),
        array(
            'key' => '_lexi_cod_collected_amount',
            'value' => 0,
            'compare' => '>',
            'type' => 'DECIMAL(20,2)',
        ),
        array(
            'relation' => 'OR',
            array(
                'key' => '_lexi_cod_settled',
                'compare' => 'NOT EXISTS',
            ),
            array(
                'key' => '_lexi_cod_settled',
                'value' => 'yes',
                'compare' => '!=',
            ),
        ),
    ),
);

$orders = wc_get_orders($args);
echo "Orders found with strict meta query: " . count($orders) . "\n";

$args2 = array(
    'limit' => -1,
    'return' => 'objects',
    'meta_query' => array(
        array(
            'key' => '_lexi_delivery_agent_id',
            'value' => (string) $courier_id,
            'compare' => '=',
        ),
    ),
);

$all_courier_orders = wc_get_orders($args2);
echo "All orders for courier: " . count($all_courier_orders) . "\n";
foreach ($all_courier_orders as $o) {
    echo "Order " . $o->get_id() . " status: " . $o->get_status() . " collected: " . $o->get_meta('_lexi_cod_collected_amount') . " settled: " . $o->get_meta('_lexi_cod_settled') . "\n";
}

global $wpdb;
$table = $wpdb->prefix . 'lexi_order_events';
echo "\nOrder events for courier:\n";
$events = $wpdb->get_results("SELECT * FROM {$table} WHERE courier_id = {$courier_id} AND event_type = 'cod_collected'");
foreach ($events as $e) {
    echo "Event " . $e->id . " order " . $e->order_id . " amount " . $e->amount . " created " . $e->created_at . "\n";
}
