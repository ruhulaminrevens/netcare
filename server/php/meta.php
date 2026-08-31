<?php
declare(strict_types=1);

header('Content-Type: application/json; charset=utf-8');
header('Cache-Control: no-store, no-cache, must-revalidate, max-age=0');
header('Access-Control-Allow-Origin: *');

$forwarded = $_SERVER['HTTP_CF_CONNECTING_IP'] ?? $_SERVER['REMOTE_ADDR'] ?? null;

echo json_encode([
    'clientIp' => $forwarded,
    'server' => $_SERVER['SERVER_NAME'] ?? 'Custom PHP test point',
    'country' => $_SERVER['HTTP_CF_IPCOUNTRY'] ?? null,
], JSON_UNESCAPED_SLASHES);
