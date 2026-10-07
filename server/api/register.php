<?php
require_once '../config/db.php';
$name=trim($_POST['name']??''); $email=trim($_POST['email']??''); $password=$_POST['password']??''; $phone=trim($_POST['phone']??'');
if($name===''||$email===''||$password==='') errorResponse('กรุณากรอกข้อมูลให้ครบ');
if(!filter_var($email,FILTER_VALIDATE_EMAIL)) errorResponse('รูปแบบอีเมลไม่ถูกต้อง');
if(strlen($password)<6) errorResponse('รหัสผ่านต้องมีอย่างน้อย 6 ตัวอักษร');
$stmt=$conn->prepare('SELECT user_id FROM users WHERE email=? LIMIT 1'); $stmt->bind_param('s',$email); $stmt->execute();
if($stmt->get_result()->num_rows>0){$stmt->close();errorResponse('อีเมลนี้มีผู้ใช้งานแล้ว');} $stmt->close();
$hash=password_hash($password,PASSWORD_DEFAULT); $role='seller'; $status='active';
$stmt=$conn->prepare('INSERT INTO users(name,email,password,user_phone,role,user_status) VALUES(?,?,?,?,?,?)');
$stmt->bind_param('ssssss',$name,$email,$hash,$phone,$role,$status);
if(!$stmt->execute()){ $stmt->close(); errorResponse('สมัครสมาชิกไม่สำเร็จ'); }
$id=$stmt->insert_id; $stmt->close(); $conn->close();
echo json_encode(['success'=>true,'message'=>'สมัครสมาชิกผู้ขายสำเร็จ','user'=>['user_id'=>$id,'name'=>$name,'email'=>$email,'user_phone'=>$phone,'role'=>'seller']],JSON_UNESCAPED_UNICODE);
