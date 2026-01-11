<?php
require_once 'config.php';

$data = json_decode(file_get_contents("php://input"), true);
$action = isset($_GET['action']) ? $_GET['action'] : '';

if ($action === 'list_users') {
   try {
      $stmt = $pdo->prepare("SELECT id, nombre_completo, email, rol, created_at FROM usuarios ORDER BY created_at DESC");
      $stmt->execute();
      $users = $stmt->fetchAll();
      echo json_encode(['success' => true, 'users' => $users]);
   } catch (Exception $e) {
      http_response_code(500);
      echo json_encode(['success' => false, 'message' => 'Error al listar usuarios']);
   }
} elseif ($action === 'update_user') {
   $id = $data['id'] ?? null;
   $nombre = $data['nombre'] ?? '';
   $email = $data['email'] ?? '';
   $rol = $data['rol'] ?? '';

   if (!$id || empty($nombre) || empty($email) || empty($rol)) {
      http_response_code(400);
      echo json_encode(['success' => false, 'message' => 'Faltan datos']);
      exit;
   }

   try {
      $stmt = $pdo->prepare("UPDATE usuarios SET nombre_completo = ?, email = ?, rol = ? WHERE id = ?");
      $stmt->execute([$nombre, $email, $rol, $id]);
      echo json_encode(['success' => true, 'message' => 'Usuario actualizado']);
   } catch (Exception $e) {
      http_response_code(500);
      echo json_encode(['success' => false, 'message' => 'Error al actualizar usuario']);
   }
} elseif ($action === 'delete_user') {
   $id = $data['id'] ?? null;

   if (!$id) {
      http_response_code(400);
      echo json_encode(['success' => false, 'message' => 'ID requerido']);
      exit;
   }

   try {
      $stmt = $pdo->prepare("DELETE FROM usuarios WHERE id = ?");
      $stmt->execute([$id]);
      echo json_encode(['success' => true, 'message' => 'Usuario eliminado']);
   } catch (Exception $e) {
      http_response_code(500);
      echo json_encode(['success' => false, 'message' => 'Error al eliminar usuario']);
   }
} elseif ($action === 'list_projects') {
   try {
      $stmt = $pdo->prepare("
         SELECT p.*, u.nombre_completo as docente_nombre 
         FROM proyectos p
         JOIN usuarios u ON p.docente_id = u.id
         ORDER BY p.created_at DESC
      ");
      $stmt->execute();
      $projects = $stmt->fetchAll();
      echo json_encode(['success' => true, 'projects' => $projects]);
   } catch (Exception $e) {
      http_response_code(500);
      echo json_encode(['success' => false, 'message' => 'Error al listar proyectos']);
   }
} elseif ($action === 'delete_project') {
   $id = $data['id'] ?? null;

   if (!$id) {
      http_response_code(400);
      echo json_encode(['success' => false, 'message' => 'ID requerido']);
      exit;
   }

   try {
      $stmt = $pdo->prepare("DELETE FROM proyectos WHERE id = ?");
      $stmt->execute([$id]);
      echo json_encode(['success' => true, 'message' => 'Proyecto eliminado']);
   } catch (Exception $e) {
      http_response_code(500);
      echo json_encode(['success' => false, 'message' => 'Error al eliminar proyecto']);
   }
} else {
   http_response_code(400);
   echo json_encode(['success' => false, 'message' => 'Acción no válida']);
}
