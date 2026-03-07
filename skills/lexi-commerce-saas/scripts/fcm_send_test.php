<?php
/**
 * Admin-only FCM test sender helper.
 *
 * Usage:
 * php fcm_send_test.php --url="https://example.com/wp-json/lexi/v1/admin/notifications/send-test" --token="ADMIN_BEARER" --device="FCM_DEVICE_TOKEN"
 */

$options = getopt("", ["url:", "token:", "device:", "title::", "body::"]);

$url = $options["url"] ?? "";
$token = $options["token"] ?? "";
$device = $options["device"] ?? "";
$title = $options["title"] ?? "Lexi Test Notification";
$body = $options["body"] ?? "This is a test push from fcm_send_test.php";

if ($url === "" || $token === "" || $device === "") {
    fwrite(STDERR, "Missing required args: --url --token --device\n");
    exit(1);
}

$payload = [
    "token" => $device,
    "notification_type" => "admin_test",
    "title" => $title,
    "body" => $body
];

$ch = curl_init($url);
curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
curl_setopt($ch, CURLOPT_POST, true);
curl_setopt($ch, CURLOPT_HTTPHEADER, [
    "Content-Type: application/json",
    "Authorization: Bearer " . $token
]);
curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($payload));

$resp = curl_exec($ch);
$httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);

if ($resp === false) {
    fwrite(STDERR, "cURL error: " . curl_error($ch) . "\n");
    curl_close($ch);
    exit(1);
}

curl_close($ch);
echo "HTTP {$httpCode}\n";
echo $resp . "\n";

