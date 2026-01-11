<?php
require_once 'config.php';

$data = json_decode(file_get_contents("php://input"), true);
$action = isset($_GET['action']) ? $_GET['action'] : '';

if ($action === 'select_advisor') {
   // Alumno elige docente y proyecto
   $alumno_id = $data['alumno_id'] ?? null;
   $docente_id = $data['docente_id'] ?? null;
   $proyecto_id = $data['proyecto_id'] ?? null; // Puede ser null si el alumno propone, pero asumiremos que elige uno existente por ahora o se crea uno dummy.

   if (!$alumno_id || !$docente_id) {
      http_response_code(400);
      echo json_encode(['success' => false, 'message' => 'Faltan datos']);
      exit;
   }

   // 1. Verificar si el alumno ya tiene asesor
   $stmt = $pdo->prepare("SELECT id FROM asesorias WHERE alumno_id = ? AND estado = 'activo'");
   $stmt->execute([$alumno_id]);
   if ($stmt->fetch()) {
      http_response_code(409);
      echo json_encode(['success' => false, 'message' => 'Ya tienes un asesor asignado']);
      exit;
   }

   // 2. Verificar si el docente está libre (Atomicidad importante en prod, aquí básico)
   $stmt = $pdo->prepare("SELECT COUNT(*) FROM asesorias WHERE docente_id = ? AND estado = 'activo'");
   $stmt->execute([$docente_id]);
   if ($stmt->fetchColumn() > 0) {
      http_response_code(409);
      echo json_encode(['success' => false, 'message' => 'Este docente ya no está disponible']);
      exit;
   }

   // 3. Crear asesoría
   try {
      $pdo->beginTransaction();

      // Marcar proyecto como asignado SI se eligió uno
      if ($proyecto_id) {
         $stmt = $pdo->prepare("UPDATE proyectos SET estado = 'asignado' WHERE id = ?");
         $stmt->execute([$proyecto_id]);
      }

      // Crear registro asesoría
      $stmt = $pdo->prepare("INSERT INTO asesorias (alumno_id, docente_id, proyecto_id) VALUES (?, ?, ?)");
      $stmt->execute([$alumno_id, $docente_id, $proyecto_id]);

      $pdo->commit();
      echo json_encode(['success' => true, 'message' => 'Asesor seleccionado con éxito']);
   } catch (Exception $e) {
      $pdo->rollBack();
      http_response_code(500);
      echo json_encode(['success' => false, 'message' => 'Error al seleccionar asesor: ' . $e->getMessage()]);
   }
} elseif ($action === 'my_advisor') {
   // Ver quién es mi asesor y el proyecto
   $alumno_id = $_GET['alumno_id'] ?? null;

   if (!$alumno_id) {
      http_response_code(400);
      echo json_encode(['success' => false, 'message' => 'ID alumno requerido']);
      exit;
   }

   try {
      $sql = "SELECT a.id as asesoria_id, u.nombre_completo as docente_nombre, u.email as docente_email, p.titulo as proyecto_titulo
                FROM asesorias a
                JOIN usuarios u ON a.docente_id = u.id
                LEFT JOIN proyectos p ON a.proyecto_id = p.id
                WHERE a.alumno_id = ? AND a.estado = 'activo'";

      $stmt = $pdo->prepare($sql);
      $stmt->execute([$alumno_id]);
      $advisor = $stmt->fetch();

      if ($advisor) {
         echo json_encode(['success' => true, 'advisor' => $advisor]);
      } else {
         echo json_encode(['success' => true, 'advisor' => null]); // No tiene asesor
      }
   } catch (Exception $e) {
      http_response_code(500);
      echo json_encode(['success' => false, 'message' => 'Error al obtener asesor']);
   }
} elseif ($action === 'list_tasks') {
   // Ver tareas asignadas a mi asesoría
   $asesoria_id = $_GET['asesoria_id'] ?? null;

   if (!$asesoria_id) {
      http_response_code(400);
      echo json_encode(['success' => false, 'message' => 'ID asesoría requerido']);
      exit;
   }

   try {
      $stmt = $pdo->prepare("SELECT * FROM tareas WHERE asesoria_id = ? ORDER BY created_at DESC");
      $stmt->execute([$asesoria_id]);
      $tasks = $stmt->fetchAll();
      echo json_encode(['success' => true, 'tasks' => $tasks]);
   } catch (Exception $e) {
      http_response_code(500);
      echo json_encode(['success' => false, 'message' => 'Error al listar tareas']);
   }
} elseif ($action === 'upload_deliverable') {
   // Subir entregable
   // Nota: Ahora se espera multipart/form-data.

   $tarea_id = $_POST['tarea_id'] ?? null;
   $alumno_id = $_POST['alumno_id'] ?? null;
   $comentario = $_POST['comentario'] ?? '';
   $archivo_url = null;

   if (!$tarea_id || !$alumno_id) {
      http_response_code(400);
      echo json_encode(['success' => false, 'message' => 'Faltan datos']);
      exit;
   }

   // Manejo de subida de archivo
   if (isset($_FILES['deliverable_file']) && $_FILES['deliverable_file']['error'] === UPLOAD_ERR_OK) {
      $uploadDir = 'uploads/deliverables/';
      if (!is_dir($uploadDir)) {
         mkdir($uploadDir, 0777, true);
      }

      $fileName = uniqid() . '_' . basename($_FILES['deliverable_file']['name']);
      $targetPath = $uploadDir . $fileName;

      if (move_uploaded_file($_FILES['deliverable_file']['tmp_name'], $targetPath)) {
         // URL relativa
         $archivo_url = 'uploads/deliverables/' . $fileName;
      }
   }

   if (!$archivo_url) {
      http_response_code(400);
      echo json_encode(['success' => false, 'message' => 'No se ha subido ningún archivo']);
      exit;
   }

   try {
      $stmt = $pdo->prepare("INSERT INTO entregables (tarea_id, alumno_id, archivo_url, comentario_alumno) VALUES (?, ?, ?, ?)");
      $stmt->execute([$tarea_id, $alumno_id, $archivo_url, $comentario]);
      echo json_encode(['success' => true, 'message' => 'Entregable enviado']);
   } catch (Exception $e) {
      http_response_code(500);
      echo json_encode(['success' => false, 'message' => 'Error al enviar entregable: ' . $e->getMessage()]);
   }
} else {
   http_response_code(400);
   echo json_encode(['success' => false, 'message' => 'Acción no válida']);
}
