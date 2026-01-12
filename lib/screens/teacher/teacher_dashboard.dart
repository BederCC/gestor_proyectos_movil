import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import '../../api_service.dart';
import '../../widgets/app_drawer.dart';
import 'package:url_launcher/url_launcher.dart';

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

  Future<void> _launchURL(String urlString) async {
    String finalUrl = urlString;
    // Si la URL es relativa (no empieza con http), agregar el dominio base
    if (!urlString.startsWith('http') && !urlString.startsWith('https')) {
      if (urlString.startsWith('/')) {
        finalUrl = '${ApiService.baseUrl}$urlString';
      } else {
        finalUrl = '${ApiService.baseUrl}/$urlString';
      }
    }

    try {
      final Uri url = Uri.parse(finalUrl);
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('No se pudo abrir $finalUrl')));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al abrir URL: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: const Color(0xFFB71C1C),
        foregroundColor: Colors.white,
        title: Text(
          'Panel Docente: ${_user?['nombre_completo'] ?? ''}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
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
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('Subir Nuevo Proyecto'),
                  onPressed: _showCreateProjectDialog,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFB71C1C),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
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
                            elevation: 4,
                            margin: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          project['titulo'],
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 18,
                                            color: Color(0xFFB71C1C),
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        icon: Icon(
                                          project['visibilidad'] == 'publico'
                                              ? Icons.public
                                              : Icons.lock,
                                          color:
                                              project['visibilidad'] ==
                                                  'publico'
                                              ? Colors.green
                                              : Colors.grey,
                                        ),
                                        onPressed: () => _toggleVisibility(
                                          project['id'],
                                          project['visibilidad'] ?? 'publico',
                                        ),
                                        tooltip:
                                            project['visibilidad'] == 'publico'
                                            ? 'Público'
                                            : 'Privado',
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    project['descripcion'] ?? '',
                                    style: TextStyle(color: Colors.grey[800]),
                                  ),
                                  if (project['archivo_pdf_url'] != null) ...[
                                    const SizedBox(height: 16),
                                    Row(
                                      children: [
                                        OutlinedButton.icon(
                                          icon: const Icon(Icons.visibility),
                                          label: const Text('Previsualizar'),
                                          onPressed: () => _launchURL(
                                            project['archivo_pdf_url'],
                                          ),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: const Color(
                                              0xFFB71C1C,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        ElevatedButton.icon(
                                          icon: const Icon(Icons.download),
                                          label: const Text('Descargar'),
                                          onPressed: () => _launchURL(
                                            project['archivo_pdf_url'],
                                          ),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(
                                              0xFFB71C1C,
                                            ),
                                            foregroundColor: Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
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
                      elevation: 2,
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.grey.shade200),
                      ),
                      child: ExpansionTile(
                        leading: CircleAvatar(
                          backgroundColor: const Color(0xFFB71C1C),
                          child: Text(
                            student['alumno_nombre'][0].toUpperCase(),
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                        title: Text(
                          student['alumno_nombre'],
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        subtitle: Text(student['alumno_email'] ?? ''),
                        childrenPadding: const EdgeInsets.all(16),
                        children: [
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.add_task),
                              label: const Text('Asignar Nueva Tarea'),
                              onPressed: () =>
                                  _createTask(student['asesoria_id']),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.grey[200],
                                foregroundColor: Colors.black87,
                                elevation: 0,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (tasks.isEmpty)
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.all(8.0),
                                child: Text(
                                  'No hay tareas asignadas',
                                  style: TextStyle(
                                    fontStyle: FontStyle.italic,
                                    color: Colors.grey,
                                  ),
                                ),
                              ),
                            )
                          else
                            ...tasks.map((task) {
                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.grey[300]!),
                                ),
                                child: ListTile(
                                  dense: true,
                                  leading: const Icon(
                                    Icons.assignment_outlined,
                                    color: Color(0xFFB71C1C),
                                  ),
                                  title: Text(
                                    task['titulo'],
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  subtitle: Text(
                                    'Límite: ${task['fecha_limite'] ?? 'Sin fecha'}',
                                  ),
                                  trailing: task['archivo_url'] != null
                                      ? Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(
                                              Icons.check_circle,
                                              color: Colors.green,
                                              size: 20,
                                            ),
                                            const SizedBox(width: 8),
                                            IconButton(
                                              icon: const Icon(
                                                Icons.rate_review_outlined,
                                                color: Color(0xFFB71C1C),
                                              ),
                                              onPressed: () =>
                                                  _showGradeDialog(task),
                                              tooltip: 'Calificar',
                                            ),
                                          ],
                                        )
                                      : const Chip(
                                          label: Text(
                                            'Pendiente',
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: Colors.orange,
                                            ),
                                          ),
                                          backgroundColor: Color(0xFFFFF3E0),
                                        ),
                                  onTap: task['archivo_url'] != null
                                      ? () => _launchURL(task['archivo_url'])
                                      : null,
                                ),
                              );
                            }),
                        ],
                      ),
                    );
                  },
                ),
          // Tab Solicitudes
          _isLoadingRequests
              ? const Center(child: CircularProgressIndicator())
              : _requests.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.inbox, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text(
                        'No tienes solicitudes pendientes',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _requests.length,
                  itemBuilder: (context, index) {
                    final request = _requests[index];
                    return Card(
                      elevation: 4,
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        leading: CircleAvatar(
                          backgroundColor: Colors.orange,
                          child: const Icon(
                            Icons.person_add,
                            color: Colors.white,
                          ),
                        ),
                        title: Text(
                          request['alumno_nombre'],
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text('Email: ${request['alumno_email']}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(
                                Icons.check_circle,
                                color: Colors.green,
                                size: 32,
                              ),
                              onPressed: () => _respondRequest(
                                request['asesoria_id'],
                                'accept',
                              ),
                              tooltip: 'Aceptar',
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.cancel,
                                color: Colors.red,
                                size: 32,
                              ),
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
