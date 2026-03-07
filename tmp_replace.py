import sys, re
path = 'C:/Users/BIG/StudioProjects/leximegastore/wp-content/plugins/lexi-api/includes/class-plugin.php'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

# Replace hook
pattern1 = r"(        add_action\('lexi_ai_daily_aggregation', array\(\$this, 'ai_daily_aggregation'\)\);\n    \})"
replacement1 = r"\1\n\n    /**\n     * Delete incomplete Sham Cash orders older than 3 days.\n     */\n    public function cleanup_old_shamcash_orders(): void\n    {\n        $orders = wc_get_orders(array(\n            'payment_method' => 'sham_cash',\n            'status'         => array('pending', 'on-hold', 'pending-verification'),\n            'date_created'   => '<' . (time() - (3 * DAY_IN_SECONDS)),\n            'limit'          => -1,\n        ));\n\n        foreach ($orders as $order) {\n            $order->delete(false);\n        }\n    }"

# Actually, my previous regex was a bit complex. Let's just do simple string replacement.

snippet1 = "        add_action('lexi_ai_daily_aggregation', array($this, 'ai_daily_aggregation'));\n    }"
rep1 = "        add_action('lexi_ai_daily_aggregation', array($this, 'ai_daily_aggregation'));\n\n        // Sham Cash auto-delete cron\n        add_action('lexi_daily_cleanup_shamcash', array($this, 'cleanup_old_shamcash_orders'));\n    }"
content = content.replace(snippet1, rep1)
content = content.replace(snippet1.replace('\n', '\r\n'), rep1.replace('\n', '\r\n'))

snippet2 = "    public function ai_daily_aggregation(): void\n    {\n        Lexi_AI_Core::instance()->daily_aggregation();\n    }"
rep2 = snippet2 + "\n\n    /**\n     * Delete incomplete Sham Cash orders older than 3 days.\n     */\n    public function cleanup_old_shamcash_orders(): void\n    {\n        $orders = wc_get_orders(array(\n            'payment_method' => 'sham_cash',\n            'status'         => array('pending', 'on-hold', 'pending-verification'),\n            'date_created'   => '<' . (time() - (3 * DAY_IN_SECONDS)),\n            'limit'          => -1,\n        ));\n\n        foreach ($orders as $order) {\n            $order->delete(false);\n        }\n    }"
content = content.replace(snippet2, rep2)
content = content.replace(snippet2.replace('\n', '\r\n'), rep2.replace('\n', '\r\n'))

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)

print('Done')
