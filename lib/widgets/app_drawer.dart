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
          // Custom Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.only(
              top: 50,
              bottom: 20,
              left: 20,
              right: 20,
            ),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFB71C1C), Color(0xFFE53935)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: _pickImage,
                  child: Stack(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: CircleAvatar(
                          radius: 40,
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
                                  style: const TextStyle(
                                    fontSize: 32.0,
                                    color: Color(0xFFB71C1C),
                                    fontWeight: FontWeight.bold,
                                  ),
                                )
                              : null,
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(color: Colors.black26, blurRadius: 4),
                            ],
                          ),
                          child: const Icon(
                            Icons.camera_alt,
                            size: 18,
                            color: Color(0xFFB71C1C),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  widget.user['nombre_completo'],
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.user['email'],
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ),
          ),
          if (!_isEditing) ...[
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.edit, color: Color(0xFFB71C1C)),
              title: const Text(
                'Editar Perfil',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              onTap: () => setState(() => _isEditing = true),
            ),
            const Divider(),
            const Spacer(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text(
                'Cerrar Sesión',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onTap: () {
                Navigator.pushReplacementNamed(context, '/login');
              },
            ),
            const SizedBox(height: 20),
            const Padding(
              padding: EdgeInsets.only(bottom: 16.0),
              child: Text(
                'Universidad de Bolivar v1.0',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ),
          ] else ...[
            Expanded(
              child: Container(
                color: Colors.grey[50],
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back),
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
                          ),
                          const Text(
                            'Editar Información',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFB71C1C),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      TextField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          labelText: 'Nombre Completo',
                          prefixIcon: const Icon(Icons.person_outline),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _emailController,
                        decoration: InputDecoration(
                          labelText: 'Email',
                          prefixIcon: const Icon(Icons.email_outlined),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _passwordController,
                        decoration: InputDecoration(
                          labelText: 'Nueva Contraseña',
                          prefixIcon: const Icon(Icons.lock_outline),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          helperText: 'Dejar en blanco para mantener la actual',
                        ),
                        obscureText: true,
                      ),
                      const SizedBox(height: 32),
                      if (_isLoading)
                        const Center(child: CircularProgressIndicator())
                      else
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _updateProfile,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFB71C1C),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 2,
                            ),
                            child: const Text(
                              'Guardar Cambios',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
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
