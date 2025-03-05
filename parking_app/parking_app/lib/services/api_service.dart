import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

class ApiService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // URL base de la API
  final String baseUrl = 'http://192.168.1.6:3000/api';

  // Obtener token actualizado
  Future<String?> _getToken() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    return await user.getIdToken();
  }

  // Método GET
  Future<Map<String, dynamic>> get(String endpoint) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'Usuario no autenticado'};
      }

      final response = await http.get(
        Uri.parse('$baseUrl/$endpoint'),
        headers: {'Authorization': 'Bearer $token'},
      );

      return _handleResponse(response);
    } catch (e) {
      print('Error en solicitud GET a $endpoint: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  // Método POST
  Future<Map<String, dynamic>> post(
    String endpoint,
    Map<String, dynamic> data,
  ) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'Usuario no autenticado'};
      }

      final response = await http.post(
        Uri.parse('$baseUrl/$endpoint'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(data),
      );

      return _handleResponse(response);
    } catch (e) {
      print('Error en solicitud POST a $endpoint: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  // Método PUT
  Future<Map<String, dynamic>> put(
    String endpoint,
    Map<String, dynamic> data,
  ) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'Usuario no autenticado'};
      }

      final response = await http.put(
        Uri.parse('$baseUrl/$endpoint'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(data),
      );

      return _handleResponse(response);
    } catch (e) {
      print('Error en solicitud PUT a $endpoint: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  // Método DELETE
  Future<Map<String, dynamic>> delete(String endpoint) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'Usuario no autenticado'};
      }

      final response = await http.delete(
        Uri.parse('$baseUrl/$endpoint'),
        headers: {'Authorization': 'Bearer $token'},
      );

      return _handleResponse(response);
    } catch (e) {
      print('Error en solicitud DELETE a $endpoint: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  // Método para procesar respuestas
  Map<String, dynamic> _handleResponse(http.Response response) {
    try {
      final data = jsonDecode(response.body);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return data;
      } else {
        return {
          'success': false,
          'message':
              data['message'] ??
              'Error en la solicitud: ${response.statusCode}',
          'statusCode': response.statusCode,
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error procesando respuesta: $e',
        'statusCode': response.statusCode,
      };
    }
  }

  // Verificar conexión con el servidor
  Future<bool> checkServerConnection() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/health'));
      return response.statusCode == 200;
    } catch (e) {
      print('Error de conexión con el servidor: $e');
      return false;
    }
  }
}
