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

   // 1. Verificar si el alumno ya tiene asesor o solicitud pendiente
   $stmt = $pdo->prepare("SELECT id, estado FROM asesorias WHERE alumno_id = ? AND estado IN ('activo', 'pendiente')");
   $stmt->execute([$alumno_id]);
   if ($row = $stmt->fetch()) {
      $msg = $row['estado'] === 'activo' ? 'Ya tienes un asesor asignado' : 'Ya tienes una solicitud pendiente';
      http_response_code(409);
      echo json_encode(['success' => false, 'message' => $msg]);
      exit;
   }

   // 2. Verificar si el docente está libre (Opcional: tal vez permitir solicitudes aunque esté ocupado, pero por ahora mantenemos la restricción)
   // Nota: Si solo contamos 'activos', el docente podría recibir mil solicitudes.
   // Dejemos que reciba solicitudes, la restricción de "ocupado" se aplicará al ACEPTAR.
   // O podemos mantenerla aquí. Mantenemos aquí para no ilusionar al alumno.
   $stmt = $pdo->prepare("SELECT COUNT(*) FROM asesorias WHERE docente_id = ? AND estado = 'activo'");
   $stmt->execute([$docente_id]);
   if ($stmt->fetchColumn() > 0) {
      http_response_code(409);
      echo json_encode(['success' => false, 'message' => 'Este docente ya no está disponible']);
      exit;
   }

   // 3. Crear solicitud de asesoría (estado pendiente)
   try {
      $pdo->beginTransaction();

      // NO marcamos proyecto como asignado todavía. Se marcará cuando el docente acepte.

      // Crear registro asesoría con estado pendiente
      $stmt = $pdo->prepare("INSERT INTO asesorias (alumno_id, docente_id, proyecto_id, estado) VALUES (?, ?, ?, 'pendiente')");
      $stmt->execute([$alumno_id, $docente_id, $proyecto_id]);

      $pdo->commit();
      echo json_encode(['success' => true, 'message' => 'Solicitud enviada al docente. Espera su aprobación.']);
   } catch (Exception $e) {
      $pdo->rollBack();
      http_response_code(500);
      echo json_encode(['success' => false, 'message' => 'Error al enviar solicitud: ' . $e->getMessage()]);
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
      $sql = "SELECT a.id as asesoria_id, a.estado, u.nombre_completo as docente_nombre, u.email as docente_email, p.titulo as proyecto_titulo
                FROM asesorias a
                JOIN usuarios u ON a.docente_id = u.id
                LEFT JOIN proyectos p ON a.proyecto_id = p.id
                WHERE a.alumno_id = ? AND a.estado IN ('activo', 'pendiente')";

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
      $stmt = $pdo->prepare("
         SELECT t.*, e.archivo_url, e.nota, e.feedback_docente, e.fecha_entrega
         FROM tareas t
         LEFT JOIN entregables e ON t.id = e.tarea_id
         WHERE t.asesoria_id = ?
         ORDER BY t.fecha_limite ASC
      ");
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
} elseif ($action === 'list_public_projects') {
   // Listar proyectos públicos para que los alumnos los vean
   try {
      $stmt = $pdo->prepare("
         SELECT p.*, u.nombre_completo as docente_nombre 
         FROM proyectos p
         JOIN usuarios u ON p.docente_id = u.id
         WHERE p.visibilidad = 'publico'
         ORDER BY p.created_at DESC
      ");
      $stmt->execute();
      $projects = $stmt->fetchAll();
      echo json_encode(['success' => true, 'projects' => $projects]);
   } catch (Exception $e) {
      http_response_code(500);
      echo json_encode(['success' => false, 'message' => 'Error al listar proyectos']);
   }
} elseif ($action === 'cancel_request') {
   $asesoria_id = $data['asesoria_id'] ?? null;

   if (!$asesoria_id) {
      http_response_code(400);
      echo json_encode(['success' => false, 'message' => 'ID asesoría requerido']);
      exit;
   }

   try {
      $stmt = $pdo->prepare("DELETE FROM asesorias WHERE id = ? AND estado = 'pendiente'");
      $stmt->execute([$asesoria_id]);

      if ($stmt->rowCount() > 0) {
         echo json_encode(['success' => true, 'message' => 'Solicitud cancelada']);
      } else {
         echo json_encode(['success' => false, 'message' => 'No se pudo cancelar la solicitud (tal vez ya fue aceptada)']);
      }
   } catch (Exception $e) {
      http_response_code(500);
      echo json_encode(['success' => false, 'message' => 'Error al cancelar solicitud']);
   }
} else {
   http_response_code(400);
   echo json_encode(['success' => false, 'message' => 'Acción no válida']);
}
