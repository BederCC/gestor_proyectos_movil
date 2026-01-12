# Gestor de Proyectos Móvil - Universidad Bolivar

Aplicación móvil desarrollada en Flutter para la gestión de proyectos de tesis y asesorías en la Universidad Bolivar. Esta herramienta facilita la interacción entre alumnos, docentes y administradores, permitiendo un seguimiento eficiente del proceso de titulación.

## 📱 Funcionalidades Principales

### 🎓 Alumnos

- **Registro y Login:** Acceso seguro a la plataforma.
- **Búsqueda de Asesores:** Visualización de docentes disponibles y solicitud de asesoría.
- **Gestión de Tareas:** Ver tareas asignadas, fechas límite y subir entregables (PDF).
- **Feedback:** Recibir calificaciones y comentarios de los docentes.
- **Proyectos Públicos:** Acceso a un feed de proyectos de tesis públicos para referencia.

### 👨‍🏫 Docentes

- **Gestión de Solicitudes:** Aceptar o rechazar solicitudes de asesoría de alumnos.
- **Asignación de Tareas:** Crear tareas con descripciones y fechas límite para sus asesorados.
- **Revisión y Calificación:** Descargar entregables, calificar y dar feedback.
- **Publicación de Proyectos:** Subir y gestionar sus proyectos de investigación.

### 🛡️ Administrador

- **Gestión de Usuarios:** Crear, editar y eliminar usuarios (Alumnos, Docentes, Admins).
- **Supervisión de Proyectos:** Vista global de todos los proyectos y capacidad de moderación.

## 🚀 ¿Cómo Iniciar?

### Prerrequisitos

- Flutter SDK instalado.
- Servidor PHP (XAMPP, WAMP, o PHP nativo).
- Base de datos MySQL.

### 1. Configuración del Backend (API)

1. Importa el archivo `api/database.sql` en tu gestor de base de datos (phpMyAdmin, MySQL Workbench).
2. Configura los datos de conexión en `api/config.php` si es necesario.
3. Inicia el servidor PHP. Navega a la carpeta `api` y ejecuta:
   ```bash
   php -S 0.0.0.0:8000
   ```
   _Nota: Asegúrate de que tu dispositivo móvil o emulador tenga acceso a la IP de tu máquina._

### 2. Configuración de la App Móvil

1. Navega a la raíz del proyecto Flutter.
2. Instala las dependencias:
   ```bash
   flutter pub get
   ```
3. Ejecuta la aplicación:
   ```bash
   flutter run
   ```

## 🛠️ Tecnologías Utilizadas

- **Frontend:** Flutter (Dart)
- **Backend:** PHP (Nativo)
- **Base de Datos:** MySQL

---

**Hecho por Beder Casa** 🚀
