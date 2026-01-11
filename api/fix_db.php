<?php
require_once 'config.php';

try {
   // 1. Eliminar tabla entregables si existe (para asegurar estructura limpia)
   $sqlDrop = "DROP TABLE IF EXISTS entregables";
   $pdo->exec($sqlDrop);
   echo "Tabla 'entregables' eliminada (si existía).<br>";

   // 2. Crear tabla entregables con la estructura correcta
   $sqlCreate = "CREATE TABLE entregables (
        id INT AUTO_INCREMENT PRIMARY KEY,
        tarea_id INT NOT NULL,
        alumno_id INT NOT NULL,
        archivo_url VARCHAR(255) NOT NULL,
        comentario_alumno TEXT,
        fecha_entrega DATETIME DEFAULT CURRENT_TIMESTAMP,
        nota INT NULL,
        feedback_docente TEXT NULL,
        FOREIGN KEY (tarea_id) REFERENCES tareas(id) ON DELETE CASCADE,
        FOREIGN KEY (alumno_id) REFERENCES usuarios(id) ON DELETE CASCADE
    )";
   $pdo->exec($sqlCreate);
   echo "Tabla 'entregables' creada correctamente con columna 'tarea_id'.<br>";
} catch (PDOException $e) {
   echo "Error: " . $e->getMessage();
}
