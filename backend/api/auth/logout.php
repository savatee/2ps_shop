<?php
require_once __DIR__ . '/../config/bootstrap.php';
requireUser($conn);

$token = apiBearerToken();
startApiSession($token);
$_SESSION = [];
session_destroy();
$conn->close();

successResponse('ออกจากระบบสำเร็จ');