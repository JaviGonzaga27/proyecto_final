import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;

class ProfileService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // URL de tu API backend
  final String apiUrl = 'http://192.168.1.6:3000/api';

  // Obtener perfil de usuario
  Future<Map<String, dynamic>> getUserProfile() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return {'success': false, 'message': 'Usuario no autenticado'};
      }

      // Intentar con backend
      final token = await user.getIdToken();

      try {
        final response = await http.get(
          Uri.parse('$apiUrl/users/${user.uid}/profile'),
          headers: {'Authorization': 'Bearer $token'},
        );

        if (response.statusCode == 200) {
          return jsonDecode(response.body);
        }
      } catch (e) {
        print('Error con API backend, usando Firestore: $e');
      }

      // Fallback: crear perfil local
      final userDoc = await _firestore.collection('users').doc(user.uid).get();

      if (!userDoc.exists) {
        return {'success': false, 'message': 'Usuario no encontrado'};
      }

      // Obtener vehículos del usuario
      final vehiclesSnapshot =
          await _firestore
              .collection('vehicles')
              .where('userId', isEqualTo: user.uid)
              .get();

      // Obtener historial de estacionamiento
      final parkingStats =
          await _firestore
              .collection('parking_history')
              .where('userId', isEqualTo: user.uid)
              .get();

      // Obtener pagos
      final payments =
          await _firestore
              .collection('payments')
              .where('userId', isEqualTo: user.uid)
              .get();

      final userData = userDoc.data()!;

      return {
        'success': true,
        'data': {
          'id': user.uid,
          'email': userData['email'],
          'firstName': userData['firstName'],
          'lastName': userData['lastName'],
          'displayName':
              userData['displayName'] ??
              '${userData['firstName']} ${userData['lastName']}',
          'photoURL': userData['photoURL'] ?? user.photoURL,
          'role': userData['role'] ?? 'user',
          'vehicles':
              vehiclesSnapshot.docs
                  .map((doc) => {'id': doc.id, ...doc.data()})
                  .toList(),
          'stats': {
            'totalParkings': parkingStats.size,
            'totalPayments': payments.size,
            'totalAmount':
                payments.docs.isEmpty
                    ? 0
                    : payments.docs
                        .map((doc) => doc.data()['amount'] ?? 0.0)
                        .fold(
                          0.0,
                          (sum, amount) =>
                              sum +
                              (amount is double ? amount : amount.toDouble()),
                        ),
          },
        },
      };
    } catch (e) {
      print('Error al obtener perfil: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  // Actualizar perfil de usuario
  Future<bool> updateUserProfile(Map<String, dynamic> userData) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      // Intentar con backend
      final token = await user.getIdToken();

      try {
        final response = await http.put(
          Uri.parse('$apiUrl/users/${user.uid}'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode(userData),
        );

        if (response.statusCode == 200) {
          return true;
        }
      } catch (e) {
        print('Error con API backend, usando Firestore: $e');
      }

      // Actualizar en Firestore
      await _firestore.collection('users').doc(user.uid).update({
        ...userData,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Si incluye nombre, actualizar displayName en Firebase Auth
      if (userData.containsKey('firstName') ||
          userData.containsKey('lastName')) {
        final userDoc =
            await _firestore.collection('users').doc(user.uid).get();
        final currentData = userDoc.data() ?? {};

        final firstName =
            userData['firstName'] ?? currentData['firstName'] ?? '';
        final lastName = userData['lastName'] ?? currentData['lastName'] ?? '';

        await user.updateDisplayName('$firstName $lastName');

        // Actualizar también displayName en Firestore
        await _firestore.collection('users').doc(user.uid).update({
          'displayName': '$firstName $lastName',
        });
      }

      return true;
    } catch (e) {
      print('Error al actualizar perfil: $e');
      return false;
    }
  }

  // Actualizar preferencias de usuario
  Future<bool> updateUserPreferences(Map<String, dynamic> preferences) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      // Intentar con backend
      final token = await user.getIdToken();

      try {
        final response = await http.put(
          Uri.parse('$apiUrl/users/${user.uid}/preferences'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode(preferences),
        );

        if (response.statusCode == 200) {
          return true;
        }
      } catch (e) {
        print('Error con API backend, usando Firestore: $e');
      }

      // Actualizar en Firestore
      await _firestore.collection('users').doc(user.uid).update({
        'preferences': preferences,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      print('Error al actualizar preferencias: $e');
      return false;
    }
  }
}
