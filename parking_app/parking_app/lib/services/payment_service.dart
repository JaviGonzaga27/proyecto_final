import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import '../models/payment_model.dart';

class PaymentService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // URL de tu API backend
  final String apiUrl = 'http://192.168.1.6:3000/api';

  // Obtener pagos del usuario
  Future<List<PaymentModel>> getUserPayments() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return [];

      // Intentar con backend
      final token = await user.getIdToken();

      try {
        final response = await http.get(
          Uri.parse('$apiUrl/payments/user/${user.uid}'),
          headers: {'Authorization': 'Bearer $token'},
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data['success'] && data['data'] != null) {
            final List<dynamic> paymentsJson = data['data'];
            return paymentsJson
                .map(
                  (json) => PaymentModel.fromJson({'id': json['id'], ...json}),
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
              .collection('payments')
              .where('userId', isEqualTo: user.uid)
              .orderBy('createdAt', descending: true)
              .get();

      return snapshot.docs
          .map((doc) => PaymentModel.fromJson({'id': doc.id, ...doc.data()}))
          .toList();
    } catch (e) {
      print('Error al obtener pagos: $e');
      return [];
    }
  }

  // Obtener recibo de pago
  Future<Map<String, dynamic>> getReceipt(String paymentId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return {'success': false, 'message': 'Usuario no autenticado'};
      }

      // Intentar con backend
      final token = await user.getIdToken();

      try {
        final response = await http.get(
          Uri.parse('$apiUrl/payments/$paymentId/receipt'),
          headers: {'Authorization': 'Bearer $token'},
        );

        if (response.statusCode == 200) {
          return jsonDecode(response.body);
        }
      } catch (e) {
        print('Error con API backend, usando Firestore: $e');
      }

      // Fallback: crear recibo local
      final paymentDoc =
          await _firestore.collection('payments').doc(paymentId).get();

      if (!paymentDoc.exists) {
        return {'success': false, 'message': 'Pago no encontrado'};
      }

      final payment = paymentDoc.data()!;

      return {
        'success': true,
        'data': {
          'paymentId': paymentId,
          'amount': payment['amount'],
          'date': payment['createdAt'],
          'method': payment['method'],
          'status': payment['status'],
        },
      };
    } catch (e) {
      print('Error al obtener recibo: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  // Procesar un pago
  Future<Map<String, dynamic>> processPayment(
    String historyId,
    String spotId,
    String plateNumber,
    double amount,
    String method,
  ) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return {'success': false, 'message': 'Usuario no autenticado'};
      }

      // Intentar con backend
      final token = await user.getIdToken();

      try {
        final response = await http.post(
          Uri.parse('$apiUrl/payments'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({
            'userId': user.uid,
            'historyId': historyId,
            'spotId': spotId,
            'plateNumber': plateNumber,
            'amount': amount,
            'method': method,
          }),
        );

        if (response.statusCode == 201) {
          final data = jsonDecode(response.body);
          return {'success': true, 'paymentId': data['paymentId']};
        }
      } catch (e) {
        print('Error con API backend, usando Firestore: $e');
      }

      // Fallback a Firestore
      final paymentRef = await _firestore.collection('payments').add({
        'userId': user.uid,
        'historyId': historyId,
        'spotId': spotId,
        'plateNumber': plateNumber,
        'amount': amount,
        'method': method,
        'status': 'completed',
        'createdAt': FieldValue.serverTimestamp(),
      });

      return {'success': true, 'paymentId': paymentRef.id};
    } catch (e) {
      print('Error al procesar pago: $e');
      return {'success': false, 'message': e.toString()};
    }
  }
}
