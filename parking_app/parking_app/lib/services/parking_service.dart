import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_storage/firebase_storage.dart';
import '../models/parking_spot_model.dart';
import '../models/parking_history_model.dart';

class ParkingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // URL de tu API backend
  final String apiUrl = 'http://192.168.1.6:3000/api';

  // Obtener todos los espacios de estacionamiento
  Future<List<ParkingSpot>> getAllSpots() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return [];

      // Para depuración
      print('Obteniendo espacios de estacionamiento...');

      // Obtener desde Firestore directamente para depuración
      final snapshot = await _firestore.collection('parking_spots').get();

      print('Espacios encontrados: ${snapshot.docs.length}');

      if (snapshot.docs.isEmpty) {
        print('ADVERTENCIA: No hay espacios en la base de datos');
      }

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
      // Intentar con backend
      final user = _auth.currentUser;
      if (user != null) {
        final token = await user.getIdToken();

        try {
          final response = await http.get(
            Uri.parse('$apiUrl/parking/available'),
            headers: {'Authorization': 'Bearer $token'},
          );

          if (response.statusCode == 200) {
            final data = jsonDecode(response.body);
            if (data['success'] && data['data'] != null) {
              final List<dynamic> spotsJson = data['data'];
              return spotsJson
                  .map(
                    (json) => ParkingSpot.fromJson({'id': json['id'], ...json}),
                  )
                  .toList();
            }
          }
        } catch (e) {
          print('Error con API backend, usando Firestore: $e');
        }
      }

      // Fallback a Firestore
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

      // Intentar con backend
      final token = await user.getIdToken();

      try {
        final response = await http.post(
          Uri.parse('$apiUrl/parking/reserve'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({'spotId': spotId, 'userId': user.uid}),
        );

        if (response.statusCode == 200) {
          return true;
        }
      } catch (e) {
        print('Error con API backend, usando Firestore: $e');
      }

      // Fallback a Firestore
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

      // Si hay imagen, primero subirla a Storage
      String? imageUrl;
      if (plateImage != null) {
        // Intentar reconocimiento de placa con backend
        final token = await user.getIdToken();

        try {
          // Crear formulario multipart
          var request = http.MultipartRequest(
            'POST',
            Uri.parse('$apiUrl/plate-recognition/recognize'),
          );

          request.headers['Authorization'] = 'Bearer $token';
          request.files.add(
            await http.MultipartFile.fromPath('image', plateImage.path),
          );

          var streamedResponse = await request.send();
          var response = await http.Response.fromStream(streamedResponse);

          if (response.statusCode == 200) {
            final data = jsonDecode(response.body);
            if (data['success']) {
              imageUrl = data['imageUrl'];
            }
          }
        } catch (e) {
          print('Error con API de reconocimiento: $e');

          // Fallback: subir a Firebase Storage
          final ref = _storage.ref().child(
            'plates/${DateTime.now().millisecondsSinceEpoch}_$plateNumber.jpg',
          );
          await ref.putFile(plateImage);
          imageUrl = await ref.getDownloadURL();
        }
      }

      // Intentar con backend
      final token = await user.getIdToken();

      try {
        final response = await http.post(
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

        if (response.statusCode == 200) {
          return true;
        }
      } catch (e) {
        print('Error con API backend, usando Firestore: $e');
      }

      // Fallback a Firestore
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

      // Intentar con backend
      final token = await user.getIdToken();

      try {
        final response = await http.post(
          Uri.parse('$apiUrl/parking/exit'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({'spotId': spotId, 'paymentMethod': 'app'}),
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data['success']) {
            return {
              'success': true,
              'amount': data['data']['amount'],
              'duration': data['data']['duration'],
            };
          }
        }
      } catch (e) {
        print('Error con API backend, usando Firestore: $e');
      }

      // Fallback a Firestore
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
  Future<List<ParkingHistoryModel>> getUserParkingHistory() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return [];

      // Intentar con backend
      final token = await user.getIdToken();

      try {
        final response = await http.get(
          Uri.parse('$apiUrl/users/${user.uid}/parking-history'),
          headers: {'Authorization': 'Bearer $token'},
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data['success'] && data['data'] != null) {
            final List<dynamic> historyJson = data['data'];
            return historyJson
                .map(
                  (json) =>
                      ParkingHistoryModel.fromJson({'id': json['id'], ...json}),
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
              .collection('parking_history')
              .where('userId', isEqualTo: user.uid)
              .orderBy('entryTime', descending: true)
              .get();

      return snapshot.docs
          .map(
            (doc) =>
                ParkingHistoryModel.fromJson({'id': doc.id, ...doc.data()}),
          )
          .toList();
    } catch (e) {
      print('Error al obtener historial: $e');
      return [];
    }
  }

  // Obtener estacionamientos activos del usuario
  Future<List<ParkingHistoryModel>> getUserActiveParking() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return [];

      // Intentar con backend
      final token = await user.getIdToken();

      try {
        final response = await http.get(
          Uri.parse('$apiUrl/users/${user.uid}/parking-history?status=active'),
          headers: {'Authorization': 'Bearer $token'},
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data['success'] && data['data'] != null) {
            final List<dynamic> historyJson = data['data'];
            return historyJson
                .map(
                  (json) =>
                      ParkingHistoryModel.fromJson({'id': json['id'], ...json}),
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
              .collection('parking_history')
              .where('userId', isEqualTo: user.uid)
              .where('status', isEqualTo: 'active')
              .get();

      return snapshot.docs
          .map(
            (doc) =>
                ParkingHistoryModel.fromJson({'id': doc.id, ...doc.data()}),
          )
          .toList();
    } catch (e) {
      print('Error al obtener estacionamientos activos: $e');
      return [];
    }
  }
}
