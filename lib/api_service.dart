import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  // Detectar si es Android (Emulador) para usar 10.0.2.2, sino localhost
  // Usamos el puerto 8000 para el servidor PHP integrado
  static String get baseUrl {
    if (Platform.isAndroid) {
      return 'http://10.0.2.2:8000';
    }
    return 'http://localhost:8000';
  }

  static Future<Map<String, dynamic>> login(
    String email,
    String password,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth.php?action=login'),
      body: jsonEncode({'email': email, 'password': password}),
      headers: {'Content-Type': 'application/json'},
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> register(
    String nombre,
    String email,
    String password,
    String rol,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth.php?action=register'),
      body: jsonEncode({
        'nombre': nombre,
        'email': email,
        'password': password,
        'rol': rol,
      }),
      headers: {'Content-Type': 'application/json'},
    );
    return jsonDecode(response.body);
  }

  static Future<List<dynamic>> getTeachers() async {
    final response = await http.get(
      Uri.parse('$baseUrl/teachers.php?action=list_teachers'),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['teachers'];
    }
    return [];
  }

  static Future<Map<String, dynamic>> selectAdvisor(
    int alumnoId,
    int docenteId,
    int? proyectoId,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/students.php?action=select_advisor'),
      body: jsonEncode({
        'alumno_id': alumnoId,
        'docente_id': docenteId,
        'proyecto_id': proyectoId,
      }),
      headers: {'Content-Type': 'application/json'},
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> respondRequest(
    int asesoriaId,
    String responseType, // 'accept' or 'reject'
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/teachers.php?action=respond_request'),
      body: jsonEncode({'asesoria_id': asesoriaId, 'response': responseType}),
      headers: {'Content-Type': 'application/json'},
    );
    return jsonDecode(response.body);
  }

  static Future<List<dynamic>> getRequests(int docenteId) async {
    final response = await http.get(
      Uri.parse(
        '$baseUrl/teachers.php?action=list_requests&docente_id=$docenteId',
      ),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['requests'];
    }
    return [];
  }

  // Más métodos según necesidad...
}
