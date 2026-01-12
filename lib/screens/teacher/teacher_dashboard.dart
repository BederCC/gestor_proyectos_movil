import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import '../../api_service.dart';
import '../../widgets/app_drawer.dart';

class TeacherDashboard extends StatefulWidget {
  const TeacherDashboard({super.key});

  @override
  State<TeacherDashboard> createState() => _TeacherDashboardState();
}

class _TeacherDashboardState extends State<TeacherDashboard>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Map<String, dynamic>? _user;
  List<dynamic> _students = [];
  List<dynamic> _projects = [];
  bool _isLoadingStudents = false;
  bool _isLoadingProjects = false;

  final _projectTitleController = TextEditingController();
  final _projectDescController = TextEditingController();

  bool _isInit = true;

  List<dynamic> _requests = [];
  bool _isLoadingRequests = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isInit) {
      _user =
          ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;
      if (_user != null) {
        _loadStudents();
        _loadProjects();
        _loadRequests();
      }
      _isInit = false;
    }
  }

  Future<void> _loadRequests() async {
    setState(() => _isLoadingRequests = true);
    try {
      final requests = await ApiService.getRequests(_user!['id']);
      setState(() {
        _requests = requests;
      });
    } catch (e) {
      // Error
    } finally {
      setState(() => _isLoadingRequests = false);
    }
  }

  Future<void> _respondRequest(int asesoriaId, String response) async {
    try {
      final result = await ApiService.respondRequest(asesoriaId, response);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(result['message'])));
        if (result['success']) {
          _loadRequests();
          if (response == 'accept') _loadStudents();
        }
      }
    } catch (e) {
      // Error
    }
  }

  Future<void> _loadProjects() async {
    setState(() => _isLoadingProjects = true);
    try {
      final response = await http.get(
        Uri.parse(
          '${ApiService.baseUrl}/teachers.php?action=my_projects&docente_id=${_user!['id']}',
        ),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _projects = data['projects'];
        });
      }
    } catch (e) {
      // Handle error
    } finally {
      setState(() => _isLoadingProjects = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  Future<void> _loadStudents() async {
    setState(() => _isLoadingStudents = true);
    try {
      final response = await http.get(
        Uri.parse(
          '${ApiService.baseUrl}/teachers.php?action=my_students&docente_id=${_user!['id']}',
        ),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _students = data['students'];
        });
      }
    } catch (e) {
      // Handle error
    } finally {
      setState(() => _isLoadingStudents = false);
    }
  }

  Future<void> _createProject(PlatformFile? file, bool isPublic) async {
    if (_projectTitleController.text.isEmpty) return;

    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiService.baseUrl}/teachers.php?action=create_project'),
      );

      request.fields['docente_id'] = _user!['id'].toString();
      request.fields['titulo'] = _projectTitleController.text;
      request.fields['descripcion'] = _projectDescController.text;
      request.fields['visibilidad'] = isPublic ? 'publico' : 'privado';

      if (file != null && file.path != null) {
        request.files.add(
          await http.MultipartFile.fromPath('pdf_file', file.path!),
        );
      }

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      final data = jsonDecode(response.body);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(data['message'])));
        if (data['success']) {
          _projectTitleController.clear();
          _projectDescController.clear();
          Navigator.pop(context);
          _loadProjects(); // Recargar lista
        }
      }
    } catch (e) {
      // Error
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _toggleVisibility(
    int projectId,
    String currentVisibility,
  ) async {
    final newVisibility = currentVisibility == 'publico'
        ? 'privado'
        : 'publico';
    try {
      final response = await http.post(
        Uri.parse(
          '${ApiService.baseUrl}/teachers.php?action=toggle_project_visibility',
        ),
        body: jsonEncode({
          'proyecto_id': projectId,
          'visibilidad': newVisibility,
        }),
      );
      final data = jsonDecode(response.body);
      if (mounted) {
        if (data['success']) {
          _loadProjects();
        } else {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(data['message'])));
        }
      }
    } catch (e) {
      // Error
    }
  }

  Future<void> _createTask(int asesoriaId) async {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    DateTime? selectedDate;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: const Text('Asignar Tarea'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(labelText: 'Título'),
                ),
                TextField(
                  controller: descController,
                  decoration: const InputDecoration(labelText: 'Descripción'),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Text(
                      selectedDate == null
                          ? 'Sin fecha límite'
                          : 'Límite: ${selectedDate!.toLocal().toString().split(' ')[0]}',
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now().add(
                            const Duration(days: 1),
                          ),
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(
                            const Duration(days: 365),
                          ),
                        );
                        if (picked != null) {
                          setStateDialog(() {
                            selectedDate = picked;
                          });
                        }
                      },
                      child: const Text('Seleccionar Fecha'),
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (titleController.text.isEmpty || selectedDate == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Título y fecha son obligatorios'),
                      ),
                    );
                    return;
                  }

                  try {
                    // Ajustar fecha al final del día (23:59:59)
                    final deadline = DateTime(
                      selectedDate!.year,
                      selectedDate!.month,
                      selectedDate!.day,
                      23,
                      59,
                      59,
                    );

                    final response = await http.post(
                      Uri.parse(
                        '${ApiService.baseUrl}/teachers.php?action=create_task',
                      ),
                      body: jsonEncode({
                        'asesoria_id': asesoriaId,
                        'titulo': titleController.text,
                        'descripcion': descController.text,
                        'fecha_limite': deadline
                            .toIso8601String()
                            .replaceAll('T', ' ')
                            .substring(0, 19),
                      }),
                    );
                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Tarea asignada')),
                      );
                      _loadStudents(); // Recargar para ver la nueva tarea
                    }
                  } catch (e) {
                    // Error
                  }
                },
                child: const Text('Asignar'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showCreateProjectDialog() {
    PlatformFile? selectedFile;
    bool isPublic = true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: const Text('Nuevo Proyecto'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _projectTitleController,
                  decoration: const InputDecoration(labelText: 'Título'),
                ),
                TextField(
                  controller: _projectDescController,
                  decoration: const InputDecoration(labelText: 'Descripción'),
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text('Público'),
                  subtitle: Text(
                    isPublic
                        ? 'Visible para todos'
                        : 'Privado (Solo tú lo ves)',
                  ),
                  value: isPublic,
                  onChanged: (val) {
                    setStateDialog(() {
                      isPublic = val;
                    });
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        selectedFile?.name ?? 'Ningún archivo seleccionado',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.attach_file),
                      onPressed: () async {
                        FilePickerResult? result = await FilePicker.platform
                            .pickFiles(
                              type: FileType.custom,
                              allowedExtensions: ['pdf'],
                            );

                        if (result != null) {
                          setStateDialog(() {
                            selectedFile = result.files.single;
                          });
                        }
                      },
                      tooltip: 'Seleccionar PDF',
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () {
                  _createProject(selectedFile, isPublic);
                },
                child: const Text('Crear'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _gradeDeliverable(
    int entregableId,
    String? nota,
    String feedback,
  ) async {
    try {
      final response = await http.post(
        Uri.parse(
          '${ApiService.baseUrl}/teachers.php?action=grade_deliverable',
        ),
        body: jsonEncode({
          'entregable_id': entregableId,
          'nota': nota,
          'feedback': feedback,
        }),
      );
      final data = jsonDecode(response.body);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(data['message'])));
        if (data['success']) {
          _loadStudents(); // Recargar para ver cambios
        }
      }
    } catch (e) {
      // Error
    }
  }

  void _showGradeDialog(Map<String, dynamic> task) {
    final feedbackController = TextEditingController(
      text: task['feedback_docente'] ?? '',
    );
    final notaController = TextEditingController(
      text: task['nota']?.toString() ?? '',
    );

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Calificar Entregable'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: notaController,
                decoration: const InputDecoration(
                  labelText: 'Nota (0-20)',
                  hintText: 'Ej. 18',
                ),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: feedbackController,
                decoration: const InputDecoration(
                  labelText: 'Comentarios / Feedback',
                ),
                maxLines: 3,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _gradeDeliverable(
                  task['entregable_id'],
                  notaController.text.isEmpty ? null : notaController.text,
                  feedbackController.text,
                );
              },
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Panel Docente: ${_user?['nombre_completo'] ?? ''}'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Mis Proyectos'),
            Tab(text: 'Mis Alumnos'),
            Tab(text: 'Solicitudes'),
          ],
        ),
      ),
      drawer: _user != null
          ? AppDrawer(
              user: _user!,
              onProfileUpdated: () {
                setState(() {});
              },
            )
          : null,
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab Proyectos
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: ElevatedButton(
                  onPressed: _showCreateProjectDialog,
                  child: const Text('Subir Nuevo Proyecto'),
                ),
              ),
              Expanded(
                child: _isLoadingProjects
                    ? const Center(child: CircularProgressIndicator())
                    : ListView.builder(
                        itemCount: _projects.length,
                        itemBuilder: (context, index) {
                          final project = _projects[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            child: ListTile(
                              title: Text(project['titulo']),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(project['descripcion'] ?? ''),
                                  if (project['archivo_pdf_url'] != null)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 8.0),
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.picture_as_pdf,
                                            size: 16,
                                            color: Colors.red,
                                          ),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              project['archivo_pdf_url']
                                                  .toString()
                                                  .split('/')
                                                  .last,
                                              style: const TextStyle(
                                                color: Colors.blue,
                                                decoration:
                                                    TextDecoration.underline,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                              trailing: IconButton(
                                icon: Icon(
                                  project['visibilidad'] == 'publico'
                                      ? Icons.public
                                      : Icons.lock,
                                  color: project['visibilidad'] == 'publico'
                                      ? Colors.green
                                      : Colors.grey,
                                ),
                                onPressed: () => _toggleVisibility(
                                  project['id'],
                                  project['visibilidad'] ?? 'publico',
                                ),
                                tooltip: project['visibilidad'] == 'publico'
                                    ? 'Público (Toca para ocultar)'
                                    : 'Privado (Toca para publicar)',
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
          // Tab Alumnos
          _isLoadingStudents
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  itemCount: _students.length,
                  itemBuilder: (context, index) {
                    final student = _students[index];
                    final tasks = student['tasks'] as List<dynamic>? ?? [];

                    return Card(
                      margin: const EdgeInsets.all(8),
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                student['alumno_nombre'],
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text(student['alumno_email'] ?? ''),
                              trailing: IconButton(
                                icon: const Icon(Icons.add_task),
                                onPressed: () =>
                                    _createTask(student['asesoria_id']),
                                tooltip: 'Asignar Tarea',
                              ),
                            ),
                            const Divider(),
                            const Text(
                              'Entregables asignados:',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Colors.grey,
                              ),
                            ),
                            if (tasks.isEmpty)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 8.0),
                                child: Text(
                                  'No hay tareas asignadas',
                                  style: TextStyle(fontStyle: FontStyle.italic),
                                ),
                              )
                            else
                              ...tasks.map((task) {
                                return ListTile(
                                  dense: true,
                                  contentPadding: const EdgeInsets.only(
                                    left: 16,
                                  ),
                                  leading: const Icon(
                                    Icons.assignment,
                                    size: 20,
                                  ),
                                  title: Text(task['titulo']),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Fecha límite: ${task['fecha_limite'] ?? 'Sin fecha'}',
                                      ),
                                      if (task['archivo_url'] != null)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            top: 4.0,
                                          ),
                                          child: Row(
                                            children: [
                                              const Icon(
                                                Icons.check_circle,
                                                size: 16,
                                                color: Colors.green,
                                              ),
                                              const SizedBox(width: 4),
                                              const Text(
                                                'Entregado:',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.green,
                                                ),
                                              ),
                                              const SizedBox(width: 4),
                                              Expanded(
                                                child: Text(
                                                  task['archivo_url']
                                                      .toString()
                                                      .split('/')
                                                      .last,
                                                  style: const TextStyle(
                                                    color: Colors.blue,
                                                    decoration: TextDecoration
                                                        .underline,
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                        )
                                      else
                                        const Padding(
                                          padding: EdgeInsets.only(top: 4.0),
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons.pending,
                                                size: 16,
                                                color: Colors.orange,
                                              ),
                                              SizedBox(width: 4),
                                              Text(
                                                'Pendiente de entrega',
                                                style: TextStyle(
                                                  color: Colors.orange,
                                                  fontStyle: FontStyle.italic,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                  trailing: task['archivo_url'] != null
                                      ? Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            if (task['nota'] != null ||
                                                (task['feedback_docente'] !=
                                                        null &&
                                                    task['feedback_docente']
                                                        .toString()
                                                        .isNotEmpty))
                                              const Padding(
                                                padding: EdgeInsets.only(
                                                  right: 8.0,
                                                ),
                                                child: Row(
                                                  children: [
                                                    Icon(
                                                      Icons.check_circle,
                                                      size: 16,
                                                      color: Colors.green,
                                                    ),
                                                    SizedBox(width: 4),
                                                    Text(
                                                      'Entregado',
                                                      style: TextStyle(
                                                        color: Colors.green,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            IconButton(
                                              icon: const Icon(
                                                Icons.rate_review,
                                              ),
                                              tooltip: 'Calificar / Comentar',
                                              onPressed: () =>
                                                  _showGradeDialog(task),
                                            ),
                                          ],
                                        )
                                      : null,
                                );
                              }),
                          ],
                        ),
                      ),
                    );
                  },
                ),
          // Tab Solicitudes
          _isLoadingRequests
              ? const Center(child: CircularProgressIndicator())
              : _requests.isEmpty
              ? const Center(child: Text('No tienes solicitudes pendientes'))
              : ListView.builder(
                  itemCount: _requests.length,
                  itemBuilder: (context, index) {
                    final request = _requests[index];
                    return Card(
                      margin: const EdgeInsets.all(8),
                      child: ListTile(
                        title: Text(request['alumno_nombre']),
                        subtitle: Text('Email: ${request['alumno_email']}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(
                                Icons.check,
                                color: Colors.green,
                              ),
                              onPressed: () => _respondRequest(
                                request['asesoria_id'],
                                'accept',
                              ),
                              tooltip: 'Aceptar',
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.red),
                              onPressed: () => _respondRequest(
                                request['asesoria_id'],
                                'reject',
                              ),
                              tooltip: 'Rechazar',
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ],
      ),
    );
  }
}
