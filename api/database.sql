-- phpMyAdmin SQL Dump
-- version 5.2.1
-- https://www.phpmyadmin.net/
--
-- Servidor: 127.0.0.1
-- Tiempo de generación: 10-01-2026 a las 07:33:25
-- Versión del servidor: 10.4.32-MariaDB
-- Versión de PHP: 8.0.30

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
START TRANSACTION;
SET time_zone = "+00:00";

--
-- Base de datos: `gestion_tesis`
--

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `asesorias`
--

CREATE TABLE `asesorias` (
  `id` int(11) NOT NULL,
  `alumno_id` int(11) NOT NULL,
  `docente_id` int(11) NOT NULL,
  `proyecto_id` int(11) DEFAULT NULL,
  `fecha_inicio` datetime DEFAULT current_timestamp(),
  `estado` enum('activo','finalizado','cancelado') DEFAULT 'activo'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Volcado de datos para la tabla `asesorias`
--

INSERT INTO `asesorias` (`id`, `alumno_id`, `docente_id`, `proyecto_id`, `fecha_inicio`, `estado`) VALUES
(1, 1, 2, 1, '2026-01-09 23:04:39', 'activo');

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `entregables`
--

CREATE TABLE `entregables` (
  `id` int(11) NOT NULL,
  `tarea_id` int(11) NOT NULL,
  `alumno_id` int(11) NOT NULL,
  `archivo_url` varchar(255) NOT NULL,
  `comentario_alumno` text DEFAULT NULL,
  `fecha_entrega` datetime DEFAULT current_timestamp(),
  `nota` int(11) DEFAULT NULL,
  `feedback_docente` text DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `proyectos`
--

CREATE TABLE `proyectos` (
  `id` int(11) NOT NULL,
  `docente_id` int(11) NOT NULL,
  `titulo` varchar(200) NOT NULL,
  `descripcion` text DEFAULT NULL,
  `archivo_pdf_url` varchar(255) DEFAULT NULL,
  `estado` enum('disponible','asignado') DEFAULT 'disponible',
  `created_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Volcado de datos para la tabla `proyectos`
--

INSERT INTO `proyectos` (`id`, `docente_id`, `titulo`, `descripcion`, `archivo_pdf_url`, `estado`, `created_at`) VALUES
(1, 2, 'la golondrinas migran', 'este es un proyecto muy buenisimo', 'http://example.com/dummy.pdf', 'asignado', '2026-01-10 04:03:30'),
(5, 2, 'ho', 'hola', 'uploads/6961e913086a1_1408938691_introduccion-a-la-ingenieria-de-sistemas.pdf', 'disponible', '2026-01-10 05:52:19'),
(6, 2, 'prueba 2', 'prueba 2', 'uploads/6961efdc35f9b_URL_03_SIS01.pdf', 'disponible', '2026-01-10 06:21:16');

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `tareas`
--

CREATE TABLE `tareas` (
  `id` int(11) NOT NULL,
  `asesoria_id` int(11) NOT NULL,
  `titulo` varchar(150) NOT NULL,
  `descripcion` text DEFAULT NULL,
  `fecha_limite` datetime DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Volcado de datos para la tabla `tareas`
--

INSERT INTO `tareas` (`id`, `asesoria_id`, `titulo`, `descripcion`, `fecha_limite`, `created_at`) VALUES
(1, 1, 'primer entregable', 'hasta la matriz de consistencia', '2026-01-17 04:14:00', '2026-01-10 04:14:02'),
(2, 1, 'segundo entregable', 'hasta el Marco teorico', '2026-01-23 23:59:59', '2026-01-10 04:28:53');

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `usuarios`
--

CREATE TABLE `usuarios` (
  `id` int(11) NOT NULL,
  `nombre_completo` varchar(100) NOT NULL,
  `email` varchar(100) NOT NULL,
  `password` varchar(255) NOT NULL,
  `rol` enum('admin','docente','alumno') NOT NULL,
  `foto_perfil` varchar(255) DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Volcado de datos para la tabla `usuarios`
--

INSERT INTO `usuarios` (`id`, `nombre_completo`, `email`, `password`, `rol`, `foto_perfil`, `created_at`) VALUES
(1, 'Joel Bolivar', 'joel@gmail.com', '$2y$10$tQuaosyjPgD5PcjDWcZfLuNI.ExMvGvDYu6HDmFrlufFN1aBib4tG', 'alumno', NULL, '2026-01-10 03:56:18'),
(2, 'Godofredo Poccori Humeres', 'godo@gmail.com', '$2y$10$2IQiyKge84/Zsyj8gL7MjeWgVjV/KHgjzC3l/2DU0884TubFqsktu', 'docente', NULL, '2026-01-10 03:57:15'),
(3, 'Juan Lopez', 'juan@gmail.com', '$2y$10$ktQHIWj.3495FdyMl2WkGeLngi6x4pjZedvvm4C.hil.rStRNr4y6', 'alumno', NULL, '2026-01-10 04:31:41'),
(4, 'Maylin', 'maylin@gmail.com', '$2y$10$iJ/VRbrDXle/BOr8IoO57.apsWFzrr2XAqrV0tGQAF1Zc/gIUsJM2', 'docente', NULL, '2026-01-10 04:32:27');

--
-- Índices para tablas volcadas
--

--
-- Indices de la tabla `asesorias`
--
ALTER TABLE `asesorias`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `alumno_id` (`alumno_id`),
  ADD UNIQUE KEY `proyecto_id` (`proyecto_id`),
  ADD KEY `docente_id` (`docente_id`);

--
-- Indices de la tabla `entregables`
--
ALTER TABLE `entregables`
  ADD PRIMARY KEY (`id`),
  ADD KEY `tarea_id` (`tarea_id`),
  ADD KEY `alumno_id` (`alumno_id`);

--
-- Indices de la tabla `proyectos`
--
ALTER TABLE `proyectos`
  ADD PRIMARY KEY (`id`),
  ADD KEY `docente_id` (`docente_id`);

--
-- Indices de la tabla `tareas`
--
ALTER TABLE `tareas`
  ADD PRIMARY KEY (`id`),
  ADD KEY `asesoria_id` (`asesoria_id`);

--
-- Indices de la tabla `usuarios`
--
ALTER TABLE `usuarios`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `email` (`email`);

--
-- AUTO_INCREMENT de las tablas volcadas
--

--
-- AUTO_INCREMENT de la tabla `asesorias`
--
ALTER TABLE `asesorias`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=2;

--
-- AUTO_INCREMENT de la tabla `entregables`
--
ALTER TABLE `entregables`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT de la tabla `proyectos`
--
ALTER TABLE `proyectos`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=7;

--
-- AUTO_INCREMENT de la tabla `tareas`
--
ALTER TABLE `tareas`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=3;

--
-- AUTO_INCREMENT de la tabla `usuarios`
--
ALTER TABLE `usuarios`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=5;

--
-- Restricciones para tablas volcadas
--

--
-- Filtros para la tabla `asesorias`
--
ALTER TABLE `asesorias`
  ADD CONSTRAINT `asesorias_ibfk_1` FOREIGN KEY (`alumno_id`) REFERENCES `usuarios` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `asesorias_ibfk_2` FOREIGN KEY (`docente_id`) REFERENCES `usuarios` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `fk_asesorias_proyecto` FOREIGN KEY (`proyecto_id`) REFERENCES `proyectos` (`id`) ON DELETE SET NULL;

--
-- Filtros para la tabla `entregables`
--
ALTER TABLE `entregables`
  ADD CONSTRAINT `entregables_ibfk_1` FOREIGN KEY (`tarea_id`) REFERENCES `tareas` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `entregables_ibfk_2` FOREIGN KEY (`alumno_id`) REFERENCES `usuarios` (`id`) ON DELETE CASCADE;

--
-- Filtros para la tabla `proyectos`
--
ALTER TABLE `proyectos`
  ADD CONSTRAINT `proyectos_ibfk_1` FOREIGN KEY (`docente_id`) REFERENCES `usuarios` (`id`) ON DELETE CASCADE;

--
-- Filtros para la tabla `tareas`
--
ALTER TABLE `tareas`
  ADD CONSTRAINT `tareas_ibfk_1` FOREIGN KEY (`asesoria_id`) REFERENCES `asesorias` (`id`) ON DELETE CASCADE;
COMMIT;
