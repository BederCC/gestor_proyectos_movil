import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../api_service.dart';
import '../../widgets/app_drawer.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Map<String, dynamic>? _user;
  List<dynamic> _users = [];
  List<dynamic> _projects = [];
  bool _isLoadingUsers = false;
  bool _isLoadingProjects = false;

  String _selectedRoleFilter = 'Todos';
  String _projectSearchQuery = '';

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
      _loadUsers();
      _loadProjects();
    }
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoadingUsers = true);
    try {
      final response = await http.get(
        Uri.parse('${ApiService.baseUrl}/admin.php?action=list_users'),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _users = data['users'];
        });
      }
    } catch (e) {
      // Error
    } finally {
      setState(() => _isLoadingUsers = false);
    }
  }

  Future<void> _loadProjects() async {
    setState(() => _isLoadingProjects = true);
    try {
      final response = await http.get(
        Uri.parse('${ApiService.baseUrl}/admin.php?action=list_projects'),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _projects = data['projects'];
        });
      }
    } catch (e) {
      // Error
    } finally {
      setState(() => _isLoadingProjects = false);
    }
  }

  Future<void> _deleteUser(int id) async {
    if (!await _confirmDialog('¿Eliminar usuario?')) return;

    try {
      final response = await http.post(
        Uri.parse('${ApiService.baseUrl}/admin.php?action=delete_user'),
        body: jsonEncode({'id': id}),
      );
      final data = jsonDecode(response.body);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(data['message'])));
        if (data['success']) _loadUsers();
      }
    } catch (e) {
      // Error
    }
  }

  Future<void> _deleteProject(int id) async {
    if (!await _confirmDialog('¿Eliminar proyecto?')) return;

    try {
      final response = await http.post(
        Uri.parse('${ApiService.baseUrl}/admin.php?action=delete_project'),
        body: jsonEncode({'id': id}),
      );
      final data = jsonDecode(response.body);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(data['message'])));
        if (data['success']) _loadProjects();
      }
    } catch (e) {
      // Error
    }
  }

  Future<bool> _confirmDialog(String title) async {
    return await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            content: const Text('Esta acción no se puede deshacer.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text(
                  'Cancelar',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFB71C1C),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Eliminar'),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _showEditUserDialog(Map<String, dynamic> user) {
    final nameController = TextEditingController(text: user['nombre_completo']);
    final emailController = TextEditingController(text: user['email']);
    String role = user['rol'];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text(
              'Editar Usuario',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: 'Nombre',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.person),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: emailController,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.email),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: role,
                  items: const [
                    DropdownMenuItem(value: 'alumno', child: Text('Alumno')),
                    DropdownMenuItem(value: 'docente', child: Text('Docente')),
                    DropdownMenuItem(value: 'admin', child: Text('Admin')),
                  ],
                  onChanged: (val) => setStateDialog(() => role = val!),
                  decoration: InputDecoration(
                    labelText: 'Rol',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.admin_panel_settings),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Cancelar',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);
                  try {
                    final response = await http.post(
                      Uri.parse(
                        '${ApiService.baseUrl}/admin.php?action=update_user',
                      ),
                      body: jsonEncode({
                        'id': user['id'],
                        'nombre': nameController.text,
                        'email': emailController.text,
                        'rol': role,
                      }),
                    );
                    final data = jsonDecode(response.body);
                    if (mounted) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text(data['message'])));
                      if (data['success']) _loadUsers();
                    }
                  } catch (e) {
                    // Error
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFB71C1C),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Guardar'),
              ),
            ],
          );
        },
      ),
    );
  }

  // ... (getters _filteredUsers and _filteredProjects remain the same)

  List<dynamic> get _filteredUsers {
    if (_selectedRoleFilter == 'Todos') {
      return _users;
    }
    return _users
        .where(
          (user) =>
              user['rol'].toString().toLowerCase() ==
              _selectedRoleFilter.toLowerCase(),
        )
        .toList();
  }

  List<dynamic> get _filteredProjects {
    if (_projectSearchQuery.isEmpty) {
      return _projects;
    }
    return _projects
        .where(
          (project) => project['titulo'].toString().toLowerCase().contains(
            _projectSearchQuery.toLowerCase(),
          ),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: const Color(0xFFB71C1C),
        foregroundColor: Colors.white,
        title: Text(
          'Panel Admin: ${_user?['nombre_completo'] ?? ''}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Usuarios', icon: Icon(Icons.people)),
            Tab(text: 'Proyectos', icon: Icon(Icons.folder)),
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
          // Usuarios Tab
          Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16.0),
                color: Colors.white,
                child: DropdownButtonFormField<String>(
                  value: _selectedRoleFilter,
                  decoration: InputDecoration(
                    labelText: 'Filtrar por Rol',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.filter_list),
                    filled: true,
                    fillColor: Colors.grey[50],
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Todos', child: Text('Todos')),
                    DropdownMenuItem(value: 'alumno', child: Text('Alumnos')),
                    DropdownMenuItem(value: 'docente', child: Text('Docentes')),
                    DropdownMenuItem(value: 'admin', child: Text('Admins')),
                  ],
                  onChanged: (val) {
                    setState(() {
                      _selectedRoleFilter = val!;
                    });
                  },
                ),
              ),
              Expanded(
                child: _isLoadingUsers
                    ? const Center(child: CircularProgressIndicator())
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _filteredUsers.length,
                        itemBuilder: (context, index) {
                          final user = _filteredUsers[index];
                          Color roleColor = Colors.grey;
                          if (user['rol'] == 'admin') {
                            roleColor = Colors.red;
                          } else if (user['rol'] == 'docente') {
                            roleColor = Colors.blue;
                          } else if (user['rol'] == 'alumno') {
                            roleColor = Colors.green;
                          }

                          return Card(
                            elevation: 2,
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              leading: CircleAvatar(
                                backgroundColor: const Color(0xFFB71C1C),
                                child: Text(
                                  user['nombre_completo'][0]
                                      .toString()
                                      .toUpperCase(),
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                              title: Text(
                                user['nombre_completo'],
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 4),
                                  Text(user['email']),
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: roleColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: roleColor),
                                    ),
                                    child: Text(
                                      user['rol'].toString().toUpperCase(),
                                      style: TextStyle(
                                        color: roleColor,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(
                                      Icons.edit,
                                      color: Colors.blue,
                                    ),
                                    onPressed: () => _showEditUserDialog(user),
                                    tooltip: 'Editar',
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete,
                                      color: Colors.red,
                                    ),
                                    onPressed: () => _deleteUser(user['id']),
                                    tooltip: 'Eliminar',
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
          // Proyectos Tab
          Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16.0),
                color: Colors.white,
                child: TextField(
                  decoration: InputDecoration(
                    labelText: 'Buscar Proyecto',
                    hintText: 'Ingrese nombre del proyecto',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: Colors.grey[50],
                  ),
                  onChanged: (val) {
                    setState(() {
                      _projectSearchQuery = val;
                    });
                  },
                ),
              ),
              Expanded(
                child: _isLoadingProjects
                    ? const Center(child: CircularProgressIndicator())
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _filteredProjects.length,
                        itemBuilder: (context, index) {
                          final project = _filteredProjects[index];
                          final isPublic = project['visibilidad'] == 'publico';
                          return Card(
                            elevation: 2,
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.all(16),
                              leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.folder,
                                  color: Color(0xFFB71C1C),
                                ),
                              ),
                              title: Text(
                                project['titulo'],
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.person,
                                        size: 14,
                                        color: Colors.grey,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        project['docente_nombre'],
                                        style: const TextStyle(
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(
                                        isPublic ? Icons.public : Icons.lock,
                                        size: 14,
                                        color: isPublic
                                            ? Colors.green
                                            : Colors.orange,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        isPublic ? 'Público' : 'Privado',
                                        style: TextStyle(
                                          color: isPublic
                                              ? Colors.green
                                              : Colors.orange,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              trailing: IconButton(
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: Colors.red,
                                ),
                                onPressed: () => _deleteProject(project['id']),
                                tooltip: 'Eliminar Proyecto',
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
