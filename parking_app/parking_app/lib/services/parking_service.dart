import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/parking_spot_model.dart';

class ParkingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // URL de tu API backend
  final String apiUrl = 'http://localhost:3000/api';

  // Obtener todos los espacios de estacionamiento
  Future<List<ParkingSpot>> getAllSpots() async {
    try {
      final snapshot = await _firestore.collection('parking_spots').get();
      return snapshot.docs
          .map((doc) => ParkingSpot.fromJson({'id': doc.id, ...doc.data()}))
          .toList();
    } catch (e) {
      print('Error al obtener espacios: $e');
      return [];
    }
  }

  // Obtener espacios disponibles
  Future<List<ParkingSpot>> getAvailableSpots() async {
    try {
      final snapshot =
          await _firestore
              .collection('parking_spots')
              .where('status', isEqualTo: 'available')
              .get();

      return snapshot.docs
          .map((doc) => ParkingSpot.fromJson({'id': doc.id, ...doc.data()}))
          .toList();
    } catch (e) {
      print('Error al obtener espacios disponibles: $e');
      return [];
    }
  }

  // Reservar un espacio
  Future<bool> reserveSpot(String spotId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      // Verificar disponibilidad
      final spotDoc =
          await _firestore.collection('parking_spots').doc(spotId).get();
      if (!spotDoc.exists || spotDoc.data()?['status'] != 'available') {
        return false;
      }

      // Reservar el espacio
      await _firestore.collection('parking_spots').doc(spotId).update({
        'status': 'reserved',
        'userId': user.uid,
        'reservationTime': FieldValue.serverTimestamp(),
      });

      // Enviar al backend
      final token = await user.getIdToken();
      final response = await http.post(
        Uri.parse('$apiUrl/parking/reserve'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'spotId': spotId, 'userId': user.uid}),
      );

      if (response.statusCode != 200) {
        // Revertir la reserva si el backend falla
        await _firestore.collection('parking_spots').doc(spotId).update({
          'status': 'available',
          'userId': null,
          'reservationTime': null,
        });
        return false;
      }

      return true;
    } catch (e) {
      print('Error al reservar espacio: $e');
      return false;
    }
  }

  // Registrar entrada de vehículo
  Future<bool> registerEntry(
    String spotId,
    String plateNumber, {
    File? plateImage,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      String? imageUrl;

      // Si se proporciona una imagen, subirla a Firebase Storage
      if (plateImage != null) {
        final ref = _storage.ref().child(
          'plates/${DateTime.now().millisecondsSinceEpoch}_$plateNumber.jpg',
        );
        await ref.putFile(plateImage);
        imageUrl = await ref.getDownloadURL();
      }

      // Verificar disponibilidad
      final spotDoc =
          await _firestore.collection('parking_spots').doc(spotId).get();
      if (!spotDoc.exists) return false;

      final status = spotDoc.data()?['status'];
      if (status != 'available' &&
          !(status == 'reserved' && spotDoc.data()?['userId'] == user.uid)) {
        return false;
      }

      // Crear un batch para realizar múltiples operaciones atómicamente
      final batch = _firestore.batch();

      // Actualizar el espacio
      final spotRef = _firestore.collection('parking_spots').doc(spotId);
      batch.update(spotRef, {
        'status': 'occupied',
        'userId': user.uid,
        'plateNumber': plateNumber,
        'entryTime': FieldValue.serverTimestamp(),
        'plateImageUrl': imageUrl,
      });

      // Crear registro en historial
      final historyRef = _firestore.collection('parking_history').doc();
      batch.set(historyRef, {
        'parkingSpotId': spotId,
        'spotNumber': spotDoc.data()?['number'],
        'spotSection': spotDoc.data()?['section'],
        'spotFloor': spotDoc.data()?['floor'],
        'userId': user.uid,
        'plateNumber': plateNumber,
        'plateImageUrl': imageUrl,
        'entryTime': FieldValue.serverTimestamp(),
        'status': 'active',
      });

      // Ejecutar el batch
      await batch.commit();

      // Enviar al backend
      try {
        final token = await user.getIdToken();
        await http.post(
          Uri.parse('$apiUrl/parking/entry'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({
            'spotId': spotId,
            'userId': user.uid,
            'plateNumber': plateNumber,
            'imageUrl': imageUrl,
          }),
        );
      } catch (e) {
        print('Error al registrar entrada en backend: $e');
        // Continuamos aun si falla el backend
      }

      return true;
    } catch (e) {
      print('Error al registrar entrada: $e');
      return false;
    }
  }

  // Registrar salida de vehículo
  Future<Map<String, dynamic>> registerExit(String spotId) async {
    try {
      final user = _auth.currentUser;
      if (user == null)
        return {'success': false, 'message': 'Usuario no autenticado'};

      // Verificar ocupación
      final spotDoc =
          await _firestore.collection('parking_spots').doc(spotId).get();
      if (!spotDoc.exists || spotDoc.data()?['status'] != 'occupied') {
        return {'success': false, 'message': 'El espacio no está ocupado'};
      }

      // Buscar el registro activo en el historial
      final historySnapshot =
          await _firestore
              .collection('parking_history')
              .where('parkingSpotId', isEqualTo: spotId)
              .where('status', isEqualTo: 'active')
              .limit(1)
              .get();

      if (historySnapshot.docs.isEmpty) {
        return {
          'success': false,
          'message': 'No se encontró registro de entrada',
        };
      }

      final historyDoc = historySnapshot.docs.first;
      final historyData = historyDoc.data();
      final entryTime = historyData['entryTime'] as Timestamp;

      // Calcular duración y tarifa
      final exitTime = Timestamp.now();
      final durationMs =
          exitTime.millisecondsSinceEpoch - entryTime.millisecondsSinceEpoch;
      final durationHours = durationMs / (1000 * 60 * 60);

      // Tarifa por hora (ajustar según necesidades)
      final hourlyRate = 5.0;
      final amount = hourlyRate * (durationHours.ceil());

      // Crear un batch para realizar múltiples operaciones atómicamente
      final batch = _firestore.batch();

      // Actualizar el espacio
      final spotRef = _firestore.collection('parking_spots').doc(spotId);
      batch.update(spotRef, {
        'status': 'available',
        'userId': FieldValue.delete(),
        'plateNumber': FieldValue.delete(),
        'entryTime': FieldValue.delete(),
        'plateImageUrl': FieldValue.delete(),
      });

      // Actualizar historial
      final historyRef = _firestore
          .collection('parking_history')
          .doc(historyDoc.id);
      batch.update(historyRef, {
        'exitTime': exitTime,
        'duration': durationHours,
        'amount': amount,
        'status': 'completed',
      });

      // Crear registro de pago
      final paymentRef = _firestore.collection('payments').doc();
      batch.set(paymentRef, {
        'userId': user.uid,
        'historyId': historyDoc.id,
        'spotId': spotId,
        'plateNumber': historyData['plateNumber'],
        'amount': amount,
        'method': 'app', // O el método que corresponda
        'status': 'completed',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Ejecutar el batch
      await batch.commit();

      // Enviar al backend
      try {
        final token = await user.getIdToken();
        await http.post(
          Uri.parse('$apiUrl/parking/exit'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({
            'spotId': spotId,
            'historyId': historyDoc.id,
            'amount': amount,
            'paymentMethod': 'app',
          }),
        );
      } catch (e) {
        print('Error al registrar salida en backend: $e');
        // Continuamos aun si falla el backend
      }

      // Devolver resultado
      return {
        'success': true,
        'amount': amount,
        'duration': durationHours,
        'entryTime': entryTime.toDate(),
        'exitTime': exitTime.toDate(),
      };
    } catch (e) {
      print('Error al registrar salida: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  // Obtener historial de estacionamiento del usuario
  Future<List<Map<String, dynamic>>> getUserParkingHistory() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return [];

      final snapshot =
          await _firestore
              .collection('parking_history')
              .where('userId', isEqualTo: user.uid)
              .orderBy('entryTime', descending: true)
              .get();

      return snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
    } catch (e) {
      print('Error al obtener historial: $e');
      return [];
    }
  }

  // Obtener estacionamientos activos del usuario
  Future<List<Map<String, dynamic>>> getUserActiveParking() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return [];

      final snapshot =
          await _firestore
              .collection('parking_history')
              .where('userId', isEqualTo: user.uid)
              .where('status', isEqualTo: 'active')
              .get();

      return snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
    } catch (e) {
      print('Error al obtener estacionamientos activos: $e');
      return [];
    }
  }

  // Reconocer placa desde imagen
  Future<String?> recognizePlate(File imageFile) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;

      // Subir imagen a Storage temporalmente para el reconocimiento
      final ref = _storage.ref().child(
        'temp_plates/${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      await ref.putFile(imageFile);
      final imageUrl = await ref.getDownloadURL();

      // Enviar al backend para reconocimiento
      final token = await user.getIdToken();
      final response = await http.post(
        Uri.parse('$apiUrl/plate-recognition/recognize'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'imageUrl': imageUrl}),
      );

      if (response.statusCode != 200) {
        return null;
      }

      final data = jsonDecode(response.body);

      // Eliminar archivo temporal
      await ref.delete();

      return data['plateNumber'];
    } catch (e) {
      print('Error al reconocer placa: $e');
      return null;
    }
  }

  // Obtener vehículos del usuario
  Future<List<Map<String, dynamic>>> getUserVehicles() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return [];

      final snapshot =
          await _firestore
              .collection('vehicles')
              .where('userId', isEqualTo: user.uid)
              .get();

      return snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
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

  // Obtener pagos del usuario
  Future<List<Map<String, dynamic>>> getUserPayments() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return [];

      final snapshot =
          await _firestore
              .collection('payments')
              .where('userId', isEqualTo: user.uid)
              .orderBy('createdAt', descending: true)
              .get();

      return snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
    } catch (e) {
      print('Error al obtener pagos: $e');
      return [];
    }
  }
}
