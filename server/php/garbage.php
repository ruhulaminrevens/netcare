<?php
declare(strict_types=1);

ini_set('zlib.output_compression', '0');
set_time_limit(60);

$requested = filter_input(INPUT_GET, 'bytes', FILTER_VALIDATE_INT);
$bytes = is_int($requested) ? $requested : 1024 * 1024;
$bytes = max(0, min($bytes, 50 * 1024 * 1024));

header('Content-Type: application/octet-stream');
header('Content-Length: ' . $bytes);
header('Content-Encoding: identity');
header('Cache-Control: no-store, no-cache, must-revalidate, max-age=0');
header('Access-Control-Allow-Origin: *');
header('X-Content-Type-Options: nosniff');

$blockSize = 256 * 1024;
$block = random_bytes($blockSize);
$remaining = $bytes;

while ($remaining > 0 && !connection_aborted()) {
    $length = min($remaining, $blockSize);
    echo $length === $blockSize ? $block : substr($block, 0, $length);
    $remaining -= $length;
    if (ob_get_level() > 0) {
        ob_flush();
    }
    flush();
}
