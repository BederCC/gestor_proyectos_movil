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
            title: Text(title),
            content: const Text('Esta acción no se puede deshacer.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
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
            title: const Text('Editar Usuario'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Nombre'),
                ),
                TextField(
                  controller: emailController,
                  decoration: const InputDecoration(labelText: 'Email'),
                ),
                DropdownButtonFormField<String>(
                  value: role,
                  items: const [
                    DropdownMenuItem(value: 'alumno', child: Text('Alumno')),
                    DropdownMenuItem(value: 'docente', child: Text('Docente')),
                    DropdownMenuItem(value: 'admin', child: Text('Admin')),
                  ],
                  onChanged: (val) => setStateDialog(() => role = val!),
                  decoration: const InputDecoration(labelText: 'Rol'),
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
                child: const Text('Guardar'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Panel Admin: ${_user?['nombre_completo']}'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Usuarios'),
            Tab(text: 'Proyectos'),
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
          // Usuarios
          _isLoadingUsers
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  itemCount: _users.length,
                  itemBuilder: (context, index) {
                    final user = _users[index];
                    return ListTile(
                      leading: CircleAvatar(
                        child: Text(
                          user['nombre_completo'][0].toString().toUpperCase(),
                        ),
                      ),
                      title: Text(user['nombre_completo']),
                      subtitle: Text('${user['email']} - ${user['rol']}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.blue),
                            onPressed: () => _showEditUserDialog(user),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _deleteUser(user['id']),
                          ),
                        ],
                      ),
                    );
                  },
                ),
          // Proyectos
          _isLoadingProjects
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  itemCount: _projects.length,
                  itemBuilder: (context, index) {
                    final project = _projects[index];
                    return ListTile(
                      title: Text(project['titulo']),
                      subtitle: Text(
                        'Docente: ${project['docente_nombre']} - ${project['visibilidad']}',
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _deleteProject(project['id']),
                      ),
                    );
                  },
                ),
        ],
      ),
    );
  }
}
