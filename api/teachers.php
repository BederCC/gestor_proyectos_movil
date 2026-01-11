<?php
require_once 'config.php';

$data = json_decode(file_get_contents("php://input"), true);
$action = isset($_GET['action']) ? $_GET['action'] : '';

// Helper para verificar si un docente está ocupado
function isTeacherBusy($pdo, $teacherId)
{
   $stmt = $pdo->prepare("SELECT COUNT(*) FROM asesorias WHERE docente_id = ? AND estado = 'activo'");
   $stmt->execute([$teacherId]);
   return $stmt->fetchColumn() > 0;
}

if ($action === 'list_teachers') {
   // Listar todos los docentes y su estado (Libre/Ocupado)
   // Se asume que un docente está ocupado si tiene AL MENOS UNA asesoría activa.
   // (El requerimiento dice: "una vez elegido ya no puede elegir otro alumno a ese asesor")

   try {
      $stmt = $pdo->prepare("SELECT id, nombre_completo, email, foto_perfil FROM usuarios WHERE rol = 'docente'");
      $stmt->execute();
      $teachers = $stmt->fetchAll();

      foreach ($teachers as &$teacher) {
         $teacher['is_busy'] = isTeacherBusy($pdo, $teacher['id']);
      }

      echo json_encode(['success' => true, 'teachers' => $teachers]);
   } catch (Exception $e) {
      http_response_code(500);
      echo json_encode(['success' => false, 'message' => 'Error al listar docentes']);
   }
} elseif ($action === 'create_project') {
   // Docente sube un proyecto
   // Nota: Ahora se espera multipart/form-data, por lo que $data (json) no funcionará para los campos de texto si se envían como form-data.
   // Ajustaremos para leer $_POST y $_FILES.

   $docente_id = $_POST['docente_id'] ?? null;
   $titulo = $_POST['titulo'] ?? '';
   $descripcion = $_POST['descripcion'] ?? '';
   $pdf_url = null;

   if (!$docente_id || empty($titulo)) {
      http_response_code(400);
      echo json_encode(['success' => false, 'message' => 'Faltan datos']);
      exit;
   }

   // Manejo de subida de archivo
   if (isset($_FILES['pdf_file']) && $_FILES['pdf_file']['error'] === UPLOAD_ERR_OK) {
      $uploadDir = 'uploads/';
      if (!is_dir($uploadDir)) {
         mkdir($uploadDir, 0777, true);
      }

      $fileName = uniqid() . '_' . basename($_FILES['pdf_file']['name']);
      $targetPath = $uploadDir . $fileName;

      if (move_uploaded_file($_FILES['pdf_file']['tmp_name'], $targetPath)) {
         // Guardamos la URL relativa o absoluta según convenga.
         // Para este ejemplo, guardamos la ruta relativa accesible vía web.
         // Asumiendo que api/ está en la raíz pública o accesible.
         $pdf_url = 'http://' . $_SERVER['HTTP_HOST'] . '/uploads/' . $fileName;
         // Nota: Si usas emulador Android 10.0.2.2, localhost no funcionará igual.
         // Mejor guardar ruta relativa y que el cliente construya la URL, o usar IP.
         // Por simplicidad para el demo:
         $pdf_url = 'uploads/' . $fileName;
      }
   }

   try {
      $stmt = $pdo->prepare("INSERT INTO proyectos (docente_id, titulo, descripcion, archivo_pdf_url) VALUES (?, ?, ?, ?)");
      $stmt->execute([$docente_id, $titulo, $descripcion, $pdf_url]);
      echo json_encode(['success' => true, 'message' => 'Proyecto creado']);
   } catch (Exception $e) {
      http_response_code(500);
      echo json_encode(['success' => false, 'message' => 'Error al crear proyecto: ' . $e->getMessage()]);
   }
} elseif ($action === 'my_projects') {
   // Listar proyectos del docente
   $docente_id = $_GET['docente_id'] ?? null;

   if (!$docente_id) {
      http_response_code(400);
      echo json_encode(['success' => false, 'message' => 'ID docente requerido']);
      exit;
   }

   try {
      $stmt = $pdo->prepare("SELECT * FROM proyectos WHERE docente_id = ? ORDER BY created_at DESC");
      $stmt->execute([$docente_id]);
      $projects = $stmt->fetchAll();
      echo json_encode(['success' => true, 'projects' => $projects]);
   } catch (Exception $e) {
      http_response_code(500);
      echo json_encode(['success' => false, 'message' => 'Error al listar proyectos']);
   }
} elseif ($action === 'my_students') {
   // Ver alumnos asesorados por el docente (Activos)
   $docente_id = $_GET['docente_id'] ?? null;

   if (!$docente_id) {
      http_response_code(400);
      echo json_encode(['success' => false, 'message' => 'ID docente requerido']);
      exit;
   }

   try {
      $sql = "SELECT a.id as asesoria_id, u.nombre_completo as alumno_nombre, u.email as alumno_email, p.titulo as proyecto_titulo
                FROM asesorias a
                JOIN usuarios u ON a.alumno_id = u.id
                LEFT JOIN proyectos p ON a.proyecto_id = p.id
                WHERE a.docente_id = ? AND a.estado = 'activo'";

      $stmt = $pdo->prepare($sql);
      $stmt->execute([$docente_id]);
      $students = $stmt->fetchAll();

      // Obtener tareas para cada alumno
      foreach ($students as &$student) {
         $stmtTasks = $pdo->prepare("
            SELECT t.id, t.titulo, t.fecha_limite, e.archivo_url, e.comentario_alumno, e.fecha_entrega
            FROM tareas t
            LEFT JOIN entregables e ON t.id = e.tarea_id
            WHERE t.asesoria_id = ?
            ORDER BY t.fecha_limite ASC
         ");
         $stmtTasks->execute([$student['asesoria_id']]);
         $student['tasks'] = $stmtTasks->fetchAll();
      }

      echo json_encode(['success' => true, 'students' => $students]);
   } catch (Exception $e) {
      http_response_code(500);
      echo json_encode(['success' => false, 'message' => 'Error al obtener alumnos']);
   }
} elseif ($action === 'create_task') {
   // Crear entregable/tarea para un alumno (asesoría)
   $asesoria_id = $data['asesoria_id'] ?? null;
   $titulo = $data['titulo'] ?? '';
   $descripcion = $data['descripcion'] ?? '';
   $fecha_limite = $data['fecha_limite'] ?? null;

   if (!$asesoria_id || empty($titulo)) {
      http_response_code(400);
      echo json_encode(['success' => false, 'message' => 'Faltan datos']);
      exit;
   }

   try {
      $stmt = $pdo->prepare("INSERT INTO tareas (asesoria_id, titulo, descripcion, fecha_limite) VALUES (?, ?, ?, ?)");
      $stmt->execute([$asesoria_id, $titulo, $descripcion, $fecha_limite]);
      echo json_encode(['success' => true, 'message' => 'Tarea asignada correctamente']);
   } catch (Exception $e) {
      http_response_code(500);
      echo json_encode(['success' => false, 'message' => 'Error al asignar tarea: ' . $e->getMessage()]);
   }
} else {
   http_response_code(400);
   echo json_encode(['success' => false, 'message' => 'Acción no válida']);
}
