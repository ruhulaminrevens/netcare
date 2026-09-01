<?php
declare(strict_types=1);

header('Content-Type: application/json; charset=utf-8');
header('Cache-Control: no-store, no-cache, must-revalidate, max-age=0');
header('Access-Control-Allow-Origin: *');

echo json_encode([
    'ok' => true,
    'service' => 'RAR NetCare test point',
    'time' => gmdate('c'),
], JSON_UNESCAPED_SLASHES);
