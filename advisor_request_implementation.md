# Advisor Request Workflow Implementation

## Overview

Implemented a system where students request an advisor, and the advisor must accept or reject the request.

## Changes

### Backend

- **`api/students.php`**:
  - Modified `select_advisor` to create a request with status 'pendiente'.
  - Updated `my_advisor` to return the 'estado' of the advisory.
- **`api/teachers.php`**:
  - Added `list_requests` to fetch pending requests for a teacher.
  - Added `respond_request` to accept or reject requests.
- **`api/auth.php`**:
  - Fixed profile image URL construction.

### Frontend (Flutter)

- **`lib/api_service.dart`**:
  - Added `getRequests` and `respondRequest` methods.
- **`lib/screens/student/student_dashboard.dart`**:
  - Updated UI to show "Solicitud Pendiente" state.
  - Only load tasks if the advisor status is 'activo'.
- **`lib/screens/teacher/teacher_dashboard.dart`**:
  - Added "Solicitudes" tab to list pending requests.
  - Implemented accept/reject functionality.

## Verification

- **Student Flow**:
  1. Student selects an advisor.
  2. Dashboard shows "Solicitud enviada... Esperando aprobación".
  3. Once accepted, dashboard shows tasks.
- **Teacher Flow**:
  1. Teacher sees pending requests in "Solicitudes" tab.
  2. Can accept (moves student to "Mis Alumnos") or reject.
