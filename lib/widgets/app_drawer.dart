import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../api_service.dart';

class AppDrawer extends StatefulWidget {
  final Map<String, dynamic> user;
  final VoidCallback? onProfileUpdated;

  const AppDrawer({super.key, required this.user, this.onProfileUpdated});

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _passwordController;
  bool _isEditing = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.user['nombre_completo'],
    );
    _emailController = TextEditingController(text: widget.user['email']);
    _passwordController = TextEditingController();
  }

  Future<void> _updateProfile() async {
    setState(() => _isLoading = true);
    try {
      final response = await http.post(
        Uri.parse('${ApiService.baseUrl}/auth.php?action=update_profile'),
        body: jsonEncode({
          'id': widget.user['id'],
          'nombre': _nameController.text,
          'email': _emailController.text,
          'password': _passwordController.text.isNotEmpty
              ? _passwordController.text
              : null,
        }),
      );
      final data = jsonDecode(response.body);

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(data['message'])));

        if (data['success']) {
          // Actualizar datos locales si es necesario o pedir recarga
          // Por simplicidad, actualizamos el mapa local user
          widget.user['nombre_completo'] = _nameController.text;
          widget.user['email'] = _emailController.text;
          setState(() {
            _isEditing = false;
            _passwordController.clear();
          });
          if (widget.onProfileUpdated != null) {
            widget.onProfileUpdated!();
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            accountName: Text(widget.user['nombre_completo']),
            accountEmail: Text(widget.user['email']),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.white,
              child: Text(
                widget.user['nombre_completo'][0].toString().toUpperCase(),
                style: const TextStyle(fontSize: 24.0),
              ),
            ),
          ),
          if (!_isEditing) ...[
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Editar Perfil'),
              onTap: () => setState(() => _isEditing = true),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Cerrar Sesión'),
              onTap: () {
                Navigator.pushReplacementNamed(context, '/login');
              },
            ),
          ] else ...[
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      const Text(
                        'Editar Información',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Nombre Completo',
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _emailController,
                        decoration: const InputDecoration(labelText: 'Email'),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _passwordController,
                        decoration: const InputDecoration(
                          labelText: 'Nueva Contraseña (Opcional)',
                        ),
                        obscureText: true,
                      ),
                      const SizedBox(height: 16),
                      if (_isLoading)
                        const CircularProgressIndicator()
                      else
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  _isEditing = false;
                                  _nameController.text =
                                      widget.user['nombre_completo'];
                                  _emailController.text = widget.user['email'];
                                  _passwordController.clear();
                                });
                              },
                              child: const Text('Cancelar'),
                            ),
                            ElevatedButton(
                              onPressed: _updateProfile,
                              child: const Text('Guardar'),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
