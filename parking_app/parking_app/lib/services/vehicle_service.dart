import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import '../models/vehicle_model.dart';

class VehicleService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // URL de tu API backend
  final String apiUrl = 'http://192.168.1.6:3000/api';

  // Obtener vehículos del usuario
  Future<List<VehicleModel>> getUserVehicles() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return [];

      // Intentar con backend
      final token = await user.getIdToken();

      try {
        final response = await http.get(
          Uri.parse('$apiUrl/users/${user.uid}/vehicles'),
          headers: {'Authorization': 'Bearer $token'},
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data['success'] && data['data'] != null) {
            final List<dynamic> vehiclesJson = data['data'];
            return vehiclesJson
                .map(
                  (json) => VehicleModel.fromJson({'id': json['id'], ...json}),
                )
                .toList();
          }
        }
      } catch (e) {
        print('Error con API backend, usando Firestore: $e');
      }

      // Fallback a Firestore
      final snapshot =
          await _firestore
              .collection('vehicles')
              .where('userId', isEqualTo: user.uid)
              .get();

      return snapshot.docs
          .map((doc) => VehicleModel.fromJson({'id': doc.id, ...doc.data()}))
          .toList();
    } catch (e) {
      print('Error al obtener vehículos: $e');
      return [];
    }
  }

  // Agregar vehículo
  Future<bool> addVehicle(
    String plateNumber,
    String brand,
    String model,
    String color,
  ) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      // Intentar con backend
      final token = await user.getIdToken();

      try {
        final response = await http.post(
          Uri.parse('$apiUrl/users/${user.uid}/vehicles'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({
            'plateNumber': plateNumber,
            'brand': brand,
            'model': model,
            'color': color,
          }),
        );

        if (response.statusCode == 201) {
          return true;
        }
      } catch (e) {
        print('Error con API backend, usando Firestore: $e');
      }

      // Verificar si la placa ya existe
      final existingVehicle =
          await _firestore
              .collection('vehicles')
              .where('plateNumber', isEqualTo: plateNumber)
              .get();

      if (existingVehicle.docs.isNotEmpty) {
        return false;
      }

      // Agregar vehículo
      await _firestore.collection('vehicles').add({
        'userId': user.uid,
        'plateNumber': plateNumber,
        'brand': brand,
        'model': model,
        'color': color,
        'createdAt': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      print('Error al agregar vehículo: $e');
      return false;
    }
  }

  // Eliminar vehículo
  Future<bool> deleteVehicle(String vehicleId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      // Intentar con backend
      final token = await user.getIdToken();

      try {
        final response = await http.delete(
          Uri.parse('$apiUrl/users/${user.uid}/vehicles/$vehicleId'),
          headers: {'Authorization': 'Bearer $token'},
        );

        if (response.statusCode == 200) {
          return true;
        }
      } catch (e) {
        print('Error con API backend, usando Firestore: $e');
      }

      // Verificar que el vehículo pertenezca al usuario
      final vehicleDoc =
          await _firestore.collection('vehicles').doc(vehicleId).get();
      if (!vehicleDoc.exists || vehicleDoc.data()?['userId'] != user.uid) {
        return false;
      }

      // Eliminar vehículo
      await _firestore.collection('vehicles').doc(vehicleId).delete();

      return true;
    } catch (e) {
      print('Error al eliminar vehículo: $e');
      return false;
    }
  }

  // Editar vehículo
  Future<bool> updateVehicle(
    String vehicleId,
    String brand,
    String model,
    String color,
  ) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      // Intentar con backend
      final token = await user.getIdToken();

      try {
        final response = await http.put(
          Uri.parse('$apiUrl/users/${user.uid}/vehicles/$vehicleId'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({'brand': brand, 'model': model, 'color': color}),
        );

        if (response.statusCode == 200) {
          return true;
        }
      } catch (e) {
        print('Error con API backend, usando Firestore: $e');
      }

      // Verificar que el vehículo pertenezca al usuario
      final vehicleDoc =
          await _firestore.collection('vehicles').doc(vehicleId).get();
      if (!vehicleDoc.exists || vehicleDoc.data()?['userId'] != user.uid) {
        return false;
      }

      // Actualizar vehículo
      await _firestore.collection('vehicles').doc(vehicleId).update({
        'brand': brand,
        'model': model,
        'color': color,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      print('Error al actualizar vehículo: $e');
      return false;
    }
  }
}
