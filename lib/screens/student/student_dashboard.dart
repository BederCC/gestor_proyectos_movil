import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import '../../api_service.dart';
import '../../widgets/app_drawer.dart';
import 'package:url_launcher/url_launcher.dart';

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

  Future<void> _cancelRequest(int asesoriaId) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiService.baseUrl}/students.php?action=cancel_request'),
        body: jsonEncode({'asesoria_id': asesoriaId}),
      );
      final data = jsonDecode(response.body);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(data['message'])));
        if (data['success']) {
          _checkAdvisor(); // Reload state
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _launchURL(String urlString) async {
    String finalUrl = urlString;
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
                            ElevatedButton.icon(
                              onPressed: _checkAdvisor,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Actualizar Estado'),
                            ),
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              onPressed: () =>
                                  _cancelRequest(_advisor!['asesoria_id']),
                              icon: const Icon(Icons.cancel_outlined),
                              label: const Text('Cancelar Solicitud'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red,
                                side: const BorderSide(color: Colors.red),
                              ),
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
          elevation: 2,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Docente info
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: const Color(0xFFB71C1C),
                      child: Text(
                        project['docente_nombre'][0].toUpperCase(),
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          project['docente_nombre'],
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const Text(
                          'Docente',
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Body: Contenido del post
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      project['titulo'],
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      project['descripcion'] ?? '',
                      style: TextStyle(
                        color: Colors.grey[800],
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                    if (project['archivo_pdf_url'] != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.picture_as_pdf,
                              color: Color(0xFFB71C1C),
                              size: 32,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    project['archivo_pdf_url']
                                        .toString()
                                        .split('/')
                                        .last,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const Text(
                                    'Documento PDF',
                                    style: TextStyle(
                                      color: Colors.grey,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // Footer: Acciones
              if (project['archivo_pdf_url'] != null) ...[
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8.0,
                    vertical: 4.0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      TextButton.icon(
                        icon: const Icon(
                          Icons.visibility_outlined,
                          color: Colors.grey,
                        ),
                        label: const Text(
                          'Ver PDF',
                          style: TextStyle(color: Colors.grey),
                        ),
                        onPressed: () => _launchURL(project['archivo_pdf_url']),
                      ),
                      TextButton.icon(
                        icon: const Icon(
                          Icons.download_outlined,
                          color: Colors.grey,
                        ),
                        label: const Text(
                          'Descargar',
                          style: TextStyle(color: Colors.grey),
                        ),
                        onPressed: () => _launchURL(project['archivo_pdf_url']),
                      ),
                    ],
                  ),
                ),
              ],
            ],
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Advisor Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFB71C1C), Color(0xFFE53935)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.red.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              children: [
                const CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.white,
                  child: Icon(Icons.person, size: 40, color: Color(0xFFB71C1C)),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Mi Asesor',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _advisor!['docente_nombre'],
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Mis Tareas y Entregables',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          if (_tasks.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32.0),
                child: Column(
                  children: [
                    Icon(
                      Icons.assignment_turned_in,
                      size: 48,
                      color: Colors.grey,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'No tienes tareas asignadas aún.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _tasks.length,
              itemBuilder: (context, index) {
                final task = _tasks[index];
                final hasFile = task['archivo_url'] != null;
                final isGraded = task['nota'] != null;

                return Card(
                  elevation: 3,
                  margin: const EdgeInsets.only(bottom: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                task['titulo'],
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                            ),
                            if (isGraded)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.green[100],
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  'Nota: ${task['nota']}',
                                  style: TextStyle(
                                    color: Colors.green[800],
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              )
                            else if (hasFile)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.blue[100],
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  'Entregado',
                                  style: TextStyle(
                                    color: Colors.blue[800],
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              )
                            else
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.orange[100],
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  'Pendiente',
                                  style: TextStyle(
                                    color: Colors.orange[800],
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          task['descripcion'] ?? '',
                          style: TextStyle(color: Colors.grey[700]),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Icon(
                              Icons.calendar_today,
                              size: 14,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Vence: ${task['fecha_limite'] ?? 'Sin fecha'}',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 24),
                        if (hasFile) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey[50],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey[200]!),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.file_present,
                                  color: Color(0xFFB71C1C),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    task['archivo_url']
                                        .toString()
                                        .split('/')
                                        .last,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w500,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.download),
                                  onPressed: () =>
                                      _launchURL(task['archivo_url']),
                                  tooltip: 'Descargar mi entrega',
                                ),
                              ],
                            ),
                          ),
                          if (task['feedback_docente'] != null &&
                              task['feedback_docente']
                                  .toString()
                                  .isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.amber[50],
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.amber[200]!),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Feedback del Docente:',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.amber[900],
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    task['feedback_docente'],
                                    style: TextStyle(color: Colors.amber[900]),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            icon: Icon(hasFile ? Icons.edit : Icons.upload),
                            label: Text(
                              hasFile ? 'Editar Entrega' : 'Subir Entregable',
                            ),
                            onPressed: () => _uploadDeliverable(task['id']),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: hasFile
                                  ? Colors.orange
                                  : const Color(0xFFB71C1C),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
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
