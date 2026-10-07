<?php
header("Content-Type: application/json; charset=UTF-8");

ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
error_reporting(E_ALL);

$host = "172.18.111.42";
$user = "6620310006";
$pass = "6620310006";
$db   = "6620310006_2PS-Shop";

$conn = new mysqli($host, $user, $pass, $db);

if ($conn->connect_error) {
    echo json_encode([
        "success" => false,
        "message" => "ไม่สามารถเชื่อมต่อฐานข้อมูลได้",
        "error"   => $conn->connect_error
    ], JSON_UNESCAPED_UNICODE);
    exit;
}

$conn->set_charset("utf8mb4");

function successResponse($message, $data = null) {
    $result = [
        "success" => true,
        "message" => $message
    ];
    if ($data !== null) {
        $result["data"] = $data;
    }
    echo json_encode($result, JSON_UNESCAPED_UNICODE);
    exit;
}

function errorResponse($message, $error = null) {
    $result = [
        "success" => false,
        "message" => $message
    ];
    if ($error !== null) {
        $result["error"] = $error;
    }
    echo json_encode($result, JSON_UNESCAPED_UNICODE);
    exit;
}