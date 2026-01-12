import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
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
  PlatformFile? _selectedImage;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.user['nombre_completo'],
    );
    _emailController = TextEditingController(text: widget.user['email']);
    _passwordController = TextEditingController();
  }

  Future<void> _pickImage() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.image,
    );

    if (result != null) {
      setState(() {
        _selectedImage = result.files.single;
        _isEditing = true; // Enter edit mode to save
      });
    }
  }

  Future<void> _updateProfile() async {
    setState(() => _isLoading = true);
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiService.baseUrl}/auth.php?action=update_profile'),
      );

      request.fields['id'] = widget.user['id'].toString();
      request.fields['nombre'] = _nameController.text;
      request.fields['email'] = _emailController.text;
      if (_passwordController.text.isNotEmpty) {
        request.fields['password'] = _passwordController.text;
      }

      if (_selectedImage != null && _selectedImage!.path != null) {
        request.files.add(
          await http.MultipartFile.fromPath(
            'foto_perfil',
            _selectedImage!.path!,
          ),
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
          // Update local user data
          widget.user['nombre_completo'] = _nameController.text;
          widget.user['email'] = _emailController.text;
          if (data['user'] != null && data['user']['foto_perfil'] != null) {
            widget.user['foto_perfil'] = data['user']['foto_perfil'];
          }

          setState(() {
            _isEditing = false;
            _passwordController.clear();
            _selectedImage = null;
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
            currentAccountPicture: GestureDetector(
              onTap: _pickImage,
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 36,
                    backgroundColor: Colors.white,
                    backgroundImage: _selectedImage != null
                        ? FileImage(File(_selectedImage!.path!))
                        : (widget.user['foto_perfil'] != null
                                  ? NetworkImage(
                                      widget.user['foto_perfil']
                                              .toString()
                                              .startsWith('http')
                                          ? widget.user['foto_perfil']
                                          : '${ApiService.baseUrl}/${widget.user['foto_perfil']}',
                                    )
                                  : null)
                              as ImageProvider?,
                    child:
                        _selectedImage == null &&
                            widget.user['foto_perfil'] == null
                        ? Text(
                            widget.user['nombre_completo'][0]
                                .toString()
                                .toUpperCase(),
                            style: const TextStyle(fontSize: 24.0),
                          )
                        : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.blue,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.camera_alt,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
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
                                  _selectedImage = null;
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
