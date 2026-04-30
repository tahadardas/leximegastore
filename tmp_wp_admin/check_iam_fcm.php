<?php
declare(strict_types=1);

$saPath = __DIR__ . '/../leximeganew-59d1831591ed.json';
if (!is_file($saPath)) {
    fwrite(STDERR, "Service account JSON not found: {$saPath}\n");
    exit(2);
}

$sa = json_decode((string) file_get_contents($saPath), true);
if (!is_array($sa)) {
    fwrite(STDERR, "Invalid service account JSON.\n");
    exit(2);
}

function b64url(string $input): string
{
    return rtrim(strtr(base64_encode($input), '+/', '-_'), '=');
}

function http_request(string $url, string $method = 'GET', array $headers = [], ?string $body = null): array
{
    $ch = curl_init($url);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_FOLLOWLOCATION, true);
    curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, false);
    curl_setopt($ch, CURLOPT_SSL_VERIFYHOST, false);
    curl_setopt($ch, CURLOPT_CUSTOMREQUEST, $method);
    if (!empty($headers)) {
        curl_setopt($ch, CURLOPT_HTTPHEADER, $headers);
    }
    if ($body !== null) {
        curl_setopt($ch, CURLOPT_POSTFIELDS, $body);
    }
    $raw = curl_exec($ch);
    $err = curl_error($ch);
    $code = (int) curl_getinfo($ch, CURLINFO_HTTP_CODE);
    curl_close($ch);

    if ($raw === false) {
        return ['ok' => false, 'status' => $code, 'error' => $err, 'body' => ''];
    }

    return ['ok' => true, 'status' => $code, 'error' => '', 'body' => (string) $raw];
}

$now = time();
$header = b64url(json_encode(['alg' => 'RS256', 'typ' => 'JWT'], JSON_UNESCAPED_SLASHES));
$payload = b64url(json_encode([
    'iss' => (string) ($sa['client_email'] ?? ''),
    'scope' => 'https://www.googleapis.com/auth/cloud-platform',
    'aud' => 'https://oauth2.googleapis.com/token',
    'iat' => $now,
    'exp' => $now + 3600,
], JSON_UNESCAPED_SLASHES));

$unsigned = $header . '.' . $payload;
$signature = '';
$okSign = openssl_sign($unsigned, $signature, (string) $sa['private_key'], OPENSSL_ALGO_SHA256);
if (!$okSign) {
    fwrite(STDERR, "Failed to sign JWT assertion.\n");
    exit(2);
}
$assertion = $unsigned . '.' . b64url($signature);

$tokenResp = http_request(
    'https://oauth2.googleapis.com/token',
    'POST',
    ['Content-Type: application/x-www-form-urlencoded'],
    http_build_query([
        'grant_type' => 'urn:ietf:params:oauth:grant-type:jwt-bearer',
        'assertion' => $assertion,
    ])
);

if (!$tokenResp['ok']) {
    fwrite(STDERR, "Token HTTP error: {$tokenResp['error']}\n");
    exit(2);
}

$tokenJson = json_decode($tokenResp['body'], true);
if (!is_array($tokenJson) || empty($tokenJson['access_token'])) {
    fwrite(STDOUT, "TOKEN_RESPONSE: {$tokenResp['body']}\n");
    exit(1);
}

$accessToken = (string) $tokenJson['access_token'];
$projectId = (string) ($sa['project_id'] ?? '');
$member = 'serviceAccount:' . (string) ($sa['client_email'] ?? '');
$targetRole = 'roles/firebasecloudmessaging.admin';

$getPolicyResp = http_request(
    sprintf('https://cloudresourcemanager.googleapis.com/v1/projects/%s:getIamPolicy', rawurlencode($projectId)),
    'POST',
    [
        'Authorization: Bearer ' . $accessToken,
        'Content-Type: application/json',
    ],
    '{}'
);

if (!$getPolicyResp['ok']) {
    fwrite(STDERR, "getIamPolicy transport error: {$getPolicyResp['error']}\n");
    exit(2);
}

$policyJson = json_decode($getPolicyResp['body'], true);
if (!is_array($policyJson)) {
    fwrite(STDOUT, "GET_POLICY_STATUS={$getPolicyResp['status']}\n");
    fwrite(STDOUT, "GET_POLICY_RAW={$getPolicyResp['body']}\n");
    exit(1);
}

$hasTargetRole = false;
$bindings = (isset($policyJson['bindings']) && is_array($policyJson['bindings'])) ? $policyJson['bindings'] : [];
foreach ($bindings as $binding) {
    if (!is_array($binding)) {
        continue;
    }
    if ((string) ($binding['role'] ?? '') !== $targetRole) {
        continue;
    }
    $members = (isset($binding['members']) && is_array($binding['members'])) ? $binding['members'] : [];
    if (in_array($member, $members, true)) {
        $hasTargetRole = true;
        break;
    }
}

fwrite(STDOUT, "GET_POLICY_STATUS={$getPolicyResp['status']}\n");
if (isset($policyJson['error'])) {
    fwrite(STDOUT, 'GET_POLICY_ERROR=' . json_encode($policyJson['error'], JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES) . "\n");
}
fwrite(STDOUT, "PROJECT_ID={$projectId}\n");
fwrite(STDOUT, "MEMBER={$member}\n");
fwrite(STDOUT, "HAS_FCM_ROLE=" . ($hasTargetRole ? 'yes' : 'no') . "\n");

$apply = in_array('--apply', $argv, true);
if (!$apply) {
    exit(0);
}

if (isset($policyJson['error'])) {
    fwrite(STDERR, "Cannot apply: getIamPolicy already returned error.\n");
    exit(1);
}

if ($hasTargetRole) {
    fwrite(STDOUT, "APPLY_SKIPPED=already_has_role\n");
    exit(0);
}

$found = false;
for ($i = 0; $i < count($bindings); $i++) {
    if (!is_array($bindings[$i])) {
        continue;
    }
    if ((string) ($bindings[$i]['role'] ?? '') === $targetRole) {
        $members = (isset($bindings[$i]['members']) && is_array($bindings[$i]['members'])) ? $bindings[$i]['members'] : [];
        $members[] = $member;
        $bindings[$i]['members'] = array_values(array_unique($members));
        $found = true;
        break;
    }
}
if (!$found) {
    $bindings[] = [
        'role' => $targetRole,
        'members' => [$member],
    ];
}

$updatedPolicy = [
    'bindings' => $bindings,
];
if (isset($policyJson['etag'])) {
    $updatedPolicy['etag'] = $policyJson['etag'];
}
if (isset($policyJson['version'])) {
    $updatedPolicy['version'] = $policyJson['version'];
}

$setBody = json_encode(['policy' => $updatedPolicy], JSON_UNESCAPED_SLASHES);
$setResp = http_request(
    sprintf('https://cloudresourcemanager.googleapis.com/v1/projects/%s:setIamPolicy', rawurlencode($projectId)),
    'POST',
    [
        'Authorization: Bearer ' . $accessToken,
        'Content-Type: application/json',
    ],
    $setBody
);

fwrite(STDOUT, "SET_POLICY_STATUS={$setResp['status']}\n");
fwrite(STDOUT, "SET_POLICY_RAW={$setResp['body']}\n");
exit(0);
