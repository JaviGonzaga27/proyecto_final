import 'dart:convert';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

class PlateRecognitionService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // URL de tu API backend
  final String apiUrl = 'http://192.168.1.6:3000/api';

  // Reconocer placa desde imagen
  Future<Map<String, dynamic>> recognizePlate(File imageFile) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return {'success': false, 'message': 'Usuario no autenticado'};
      }

      final token = await user.getIdToken();

      // Crear solicitud multipart
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$apiUrl/plate-recognition/recognize'),
      );

      request.headers['Authorization'] = 'Bearer $token';
      request.files.add(
        await http.MultipartFile.fromPath('image', imageFile.path),
      );

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {
          'success': false,
          'message':
              'Error en el reconocimiento de placa: ${response.statusCode}',
          'error': response.body,
        };
      }
    } catch (e) {
      print('Error al reconocer placa: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  // Validar formato de placa
  bool isValidPlateFormat(String plateNumber) {
    // Ajusta la expresión regular según el formato de placas de tu país
    final RegExp plateRegex = RegExp(r'^[A-Z]{3}\d{3,4}$');
    return plateRegex.hasMatch(plateNumber);
  }
}
