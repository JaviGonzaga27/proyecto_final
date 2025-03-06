// lib/services/parking_history_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/parking_history_model.dart';

class ParkingHistoryService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Obtener todo el historial del usuario
  Future<List<ParkingHistoryModel>> getUserParkingHistory() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return [];

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

  // Obtener estacionamientos activos
  Future<List<ParkingHistoryModel>> getActiveParking() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return [];

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

  // Registrar entrada automáticamente
  Future<ParkingHistoryModel?> registerEntry(
    String parkingSpotId,
    String spotNumber,
    String spotSection,
    int spotFloor,
    String plateNumber,
    String? plateImageUrl,
  ) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;

      // Actualizar estado del espacio a ocupado
      await _firestore.collection('parking_spots').doc(parkingSpotId).update({
        'status': 'occupied',
        'userId': user.uid,
        'plateNumber': plateNumber,
        'entryTime': FieldValue.serverTimestamp(),
      });

      // Crear registro en historial
      final historyRef = _firestore.collection('parking_history').doc();
      await historyRef.set({
        'parkingSpotId': parkingSpotId,
        'spotNumber': spotNumber,
        'spotSection': spotSection,
        'spotFloor': spotFloor,
        'userId': user.uid,
        'plateNumber': plateNumber,
        'plateImageUrl': plateImageUrl,
        'entryTime': FieldValue.serverTimestamp(),
        'status': 'active',
      });

      // Obtener el documento creado para devolverlo
      final historyDoc = await historyRef.get();
      return ParkingHistoryModel.fromJson({
        'id': historyRef.id,
        ...historyDoc.data()!,
        'entryTime':
            DateTime.now(), // Temporal hasta que se actualice en Firestore
      });
    } catch (e) {
      print('Error al registrar entrada: $e');
      return null;
    }
  }

  // Registrar salida automáticamente
  Future<Map<String, dynamic>> registerExit(String historyId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return {'success': false, 'message': 'Usuario no autenticado'};
      }

      // Obtener el registro de historial
      final historyDoc =
          await _firestore.collection('parking_history').doc(historyId).get();
      if (!historyDoc.exists) {
        return {'success': false, 'message': 'Registro no encontrado'};
      }

      final historyData = historyDoc.data()!;
      if (historyData['status'] != 'active') {
        return {
          'success': false,
          'message': 'Este estacionamiento ya no está activo',
        };
      }

      final parkingSpotId = historyData['parkingSpotId'];

      // Calcular duración y tarifa
      final entryTime =
          historyData['entryTime'] is Timestamp
              ? (historyData['entryTime'] as Timestamp).toDate()
              : DateTime.parse(historyData['entryTime']);
      final exitTime = DateTime.now();
      final durationMs = exitTime.difference(entryTime).inMilliseconds;
      final durationHours = durationMs / (1000 * 60 * 60);

      // Tarifa por hora (ajustar según necesidades)
      final hourlyRate = 5.0; // $5 por hora
      final amount = hourlyRate * (durationHours.ceil());

      // Actualizar historial
      await historyDoc.reference.update({
        'exitTime': exitTime.toIso8601String(),
        'duration': durationHours,
        'amount': amount,
        'status': 'completed',
      });

      // Actualizar espacio de estacionamiento
      await _firestore.collection('parking_spots').doc(parkingSpotId).update({
        'status': 'available',
        'userId': FieldValue.delete(),
        'plateNumber': FieldValue.delete(),
        'entryTime': FieldValue.delete(),
      });

      // Registrar pago automático
      final paymentRef = await _firestore.collection('payments').add({
        'userId': user.uid,
        'historyId': historyId,
        'spotId': parkingSpotId,
        'plateNumber': historyData['plateNumber'],
        'amount': amount,
        'method': 'app',
        'status': 'completed',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Actualizar historial con el ID de pago
      await historyDoc.reference.update({'paymentId': paymentRef.id});

      return {
        'success': true,
        'amount': amount,
        'duration': durationHours,
        'paymentId': paymentRef.id,
      };
    } catch (e) {
      print('Error al registrar salida: $e');
      return {'success': false, 'message': e.toString()};
    }
  }
}
