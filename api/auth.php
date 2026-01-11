<?php
require_once 'config.php';

// Obtener datos del body (JSON)
$data = json_decode(file_get_contents("php://input"), true);

// Determinar la acción basada en un parámetro GET 'action'
$action = isset($_GET['action']) ? $_GET['action'] : '';

if ($action === 'register') {
   // Registro de usuario
   $nombre = $data['nombre'] ?? '';
   $email = $data['email'] ?? '';
   $password = $data['password'] ?? '';
   $rol = $data['rol'] ?? 'alumno'; // Default alumno

   if (empty($nombre) || empty($email) || empty($password)) {
      http_response_code(400);
      echo json_encode(['success' => false, 'message' => 'Faltan datos obligatorios']);
      exit;
   }

   // Verificar si el email ya existe
   $stmt = $pdo->prepare("SELECT id FROM usuarios WHERE email = ?");
   $stmt->execute([$email]);
   if ($stmt->fetch()) {
      http_response_code(409); // Conflict
      echo json_encode(['success' => false, 'message' => 'El email ya está registrado']);
      exit;
   }

   // Hash password
   $hashed_password = password_hash($password, PASSWORD_DEFAULT);

   try {
      $stmt = $pdo->prepare("INSERT INTO usuarios (nombre_completo, email, password, rol) VALUES (?, ?, ?, ?)");
      $stmt->execute([$nombre, $email, $hashed_password, $rol]);

      echo json_encode(['success' => true, 'message' => 'Usuario registrado correctamente']);
   } catch (Exception $e) {
      http_response_code(500);
      echo json_encode(['success' => false, 'message' => 'Error al registrar usuario']);
   }
} elseif ($action === 'login') {
   // Login de usuario
   $email = $data['email'] ?? '';
   $password = $data['password'] ?? '';

   if (empty($email) || empty($password)) {
      http_response_code(400);
      echo json_encode(['success' => false, 'message' => 'Email y contraseña requeridos']);
      exit;
   }

   $stmt = $pdo->prepare("SELECT id, nombre_completo, email, password, rol FROM usuarios WHERE email = ?");
   $stmt->execute([$email]);
   $user = $stmt->fetch();

   if ($user && password_verify($password, $user['password'])) {
      // Login exitoso
      unset($user['password']); // No devolver el hash
      echo json_encode(['success' => true, 'user' => $user]);
   } else {
      http_response_code(401);
      echo json_encode(['success' => false, 'message' => 'Credenciales inválidas']);
   }
} else {
   http_response_code(400);
   echo json_encode(['success' => false, 'message' => 'Acción no válida']);
}
