import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import '../../api_service.dart';
import '../../widgets/app_drawer.dart';

class StudentDashboard extends StatefulWidget {
  const StudentDashboard({super.key});

  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Map<String, dynamic>? _user;
  Map<String, dynamic>? _advisor;
  List<dynamic> _teachers = [];
  List<dynamic> _tasks = [];
  List<dynamic> _publicProjects = [];
  bool _isLoading = true;
  bool _isLoadingProjects = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _user = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;
    if (_user != null) {
      _checkAdvisor();
      _loadPublicProjects();
    }
  }

  Future<void> _loadPublicProjects() async {
    setState(() => _isLoadingProjects = true);
    try {
      final response = await http.get(
        Uri.parse(
          '${ApiService.baseUrl}/students.php?action=list_public_projects',
        ),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _publicProjects = data['projects'];
        });
      }
    } catch (e) {
      // Error
    } finally {
      setState(() => _isLoadingProjects = false);
    }
  }

  Future<void> _checkAdvisor() async {
    setState(() => _isLoading = true);
    try {
      // 1. Ver si ya tiene asesor
      final response = await http.get(
        Uri.parse(
          '${ApiService.baseUrl}/students.php?action=my_advisor&alumno_id=${_user!['id']}',
        ),
      );
      final data = jsonDecode(response.body);
      if (data['advisor'] != null) {
        setState(() {
          _advisor = data['advisor'];
        });
        // Solo cargar tareas si está activo
        if (_advisor!['estado'] == 'activo') {
          _loadTasks(_advisor!['asesoria_id']);
        }
      } else {
        // Si no tiene, cargar lista de docentes
        _loadTeachers();
        setState(() {
          _advisor = null;
        });
      }
    } catch (e) {
      // Error
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadTeachers() async {
    final teachers = await ApiService.getTeachers();
    setState(() {
      _teachers = teachers;
    });
  }

  Future<void> _loadTasks(int asesoriaId) async {
    try {
      final response = await http.get(
        Uri.parse(
          '${ApiService.baseUrl}/students.php?action=list_tasks&asesoria_id=$asesoriaId',
        ),
      );
      final data = jsonDecode(response.body);
      setState(() {
        _tasks = data['tasks'];
      });
    } catch (e) {
      // Error
    }
  }

  Future<void> _selectAdvisor(int docenteId) async {
    try {
      final result = await ApiService.selectAdvisor(
        _user!['id'],
        docenteId,
        null,
      ); // Project ID is now optional/null
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(result['message'])));
        if (result['success']) {
          _checkAdvisor();
        }
      }
    } catch (e) {
      // Error
    }
  }

  Future<void> _uploadDeliverable(int taskId) async {
    final commentController = TextEditingController();
    PlatformFile? selectedFile;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: const Text('Subir Entregable'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: commentController,
                  decoration: const InputDecoration(
                    labelText: 'Comentario',
                    hintText: 'Describe tu entrega...',
                  ),
                  maxLines: 3,
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
                onPressed: () async {
                  if (selectedFile == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Debes seleccionar un archivo PDF'),
                      ),
                    );
                    return;
                  }
                  Navigator.pop(context); // Cerrar diálogo
                  await _performUpload(
                    taskId,
                    selectedFile!,
                    commentController.text,
                  );
                },
                child: const Text('Enviar'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _performUpload(
    int taskId,
    PlatformFile file,
    String comment,
  ) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse(
          '${ApiService.baseUrl}/students.php?action=upload_deliverable',
        ),
      );

      request.fields['tarea_id'] = taskId.toString();
      request.fields['alumno_id'] = _user!['id'].toString();
      request.fields['comentario'] = comment;

      if (file.path != null) {
        request.files.add(
          await http.MultipartFile.fromPath('deliverable_file', file.path!),
        );
      }

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      final data = jsonDecode(response.body);

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(data['message'])));
        // Recargar tareas para ver si cambió algo (opcional)
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Panel Alumno: ${_user?['nombre_completo']}'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Proyectos Públicos'),
            Tab(text: 'Mi Asesoría'),
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
          // Tab 1: Proyectos Públicos
          _isLoadingProjects
              ? const Center(child: CircularProgressIndicator())
              : _buildPublicProjectsList(),
          // Tab 2: Mi Asesoría
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : (_advisor == null
                    ? _buildTeacherList()
                    : _advisor!['estado'] == 'pendiente'
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.hourglass_empty,
                              size: 64,
                              color: Colors.orange,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Solicitud enviada a ${_advisor!['docente_nombre']}',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text('Esperando aprobación del docente...'),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _checkAdvisor,
                              child: const Text('Actualizar Estado'),
                            ),
                          ],
                        ),
                      )
                    : _buildDashboard()),
        ],
      ),
    );
  }

  Widget _buildPublicProjectsList() {
    if (_publicProjects.isEmpty) {
      return const Center(
        child: Text('No hay proyectos públicos disponibles.'),
      );
    }
    return ListView.builder(
      itemCount: _publicProjects.length,
      itemBuilder: (context, index) {
        final project = _publicProjects[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ListTile(
            title: Text(
              project['titulo'],
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Docente: ${project['docente_nombre']}'),
                const SizedBox(height: 4),
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
                              decoration: TextDecoration.underline,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            isThreeLine: true,
          ),
        );
      },
    );
  }

  Widget _buildTeacherList() {
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            'Elige tu Asesor (Solo puedes elegir uno)',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _teachers.length,
            itemBuilder: (context, index) {
              final teacher = _teachers[index];
              final isBusy = teacher['is_busy'] == true;
              return Card(
                color: isBusy ? Colors.grey[300] : Colors.white,
                child: ListTile(
                  title: Text(teacher['nombre_completo']),
                  subtitle: Text(isBusy ? 'OCUPADO' : 'DISPONIBLE'),
                  trailing: isBusy
                      ? null
                      : ElevatedButton(
                          onPressed: () => _selectAdvisor(teacher['id']),
                          child: const Text('Elegir'),
                        ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDashboard() {
    return Column(
      children: [
        Card(
          margin: const EdgeInsets.all(16),
          color: Colors.blue[50],
          child: ListTile(
            title: Text('Mi Asesor: ${_advisor!['docente_nombre']}'),
          ),
        ),
        const Divider(),
        const Padding(
          padding: EdgeInsets.all(8.0),
          child: Text(
            'Mis Tareas / Entregables',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _tasks.length,
            itemBuilder: (context, index) {
              final task = _tasks[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          task['titulo'],
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(task['descripcion'] ?? ''),
                            const SizedBox(height: 4),
                            Text(
                              'Vence: ${task['fecha_limite'] ?? 'Sin fecha'}',
                              style: TextStyle(
                                color: Colors.red[700],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        trailing: IconButton(
                          icon: Icon(
                            task['archivo_url'] != null
                                ? Icons.edit
                                : Icons.upload_file,
                            color: task['archivo_url'] != null
                                ? Colors.orange
                                : Colors.blue,
                          ),
                          onPressed: () => _uploadDeliverable(task['id']),
                          tooltip: task['archivo_url'] != null
                              ? 'Editar Entregable'
                              : 'Subir Entregable',
                        ),
                      ),
                      if (task['archivo_url'] != null) ...[
                        const Divider(),
                        const Text(
                          'Tu Entrega:',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Row(
                          children: [
                            const Icon(
                              Icons.picture_as_pdf,
                              size: 16,
                              color: Colors.red,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                task['archivo_url'].toString().split('/').last,
                                style: const TextStyle(
                                  color: Colors.blue,
                                  decoration: TextDecoration.underline,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        if (task['nota'] != null ||
                            task['feedback_docente'] != null) ...[
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.green[50],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.green[200]!),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Calificación: ${task['nota'] ?? '-'} / 20',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green[800],
                                  ),
                                ),
                                if (task['feedback_docente'] != null &&
                                    task['feedback_docente']
                                        .toString()
                                        .isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    'Feedback: ${task['feedback_docente']}',
                                    style: TextStyle(color: Colors.green[900]),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
