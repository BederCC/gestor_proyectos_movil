<?php
require_once 'config.php';

try {
   // Modificar la columna proyecto_id para permitir NULL
   $sql = "ALTER TABLE asesorias MODIFY COLUMN proyecto_id INT NULL";
   $pdo->exec($sql);
   echo "Tabla 'asesorias' modificada: proyecto_id ahora permite NULL.<br>";

   // Opcional: Eliminar la restricción de clave foránea si da problemas y volverla a crear, 
   // pero MODIFY suele funcionar si solo cambiamos nulabilidad.
   // Si hay una constraint UNIQUE en proyecto_id, NULLs son permitidos (múltiples NULLs son válidos en MySQL UNIQUE).

} catch (PDOException $e) {
   echo "Error: " . $e->getMessage();
}
