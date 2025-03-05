import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // URL de tu API backend
  final String apiUrl = 'http://192.168.1.6:3000/api';

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Iniciar sesión con email y contraseña
  Future<User?> signInWithEmailAndPassword(
    String email,
    String password,
  ) async {
    try {
      // Autenticar con Firebase Auth
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Notificar al backend sobre el inicio de sesión
      try {
        // Obtener token de Firebase
        final token = await userCredential.user?.getIdToken();
        final uid = userCredential.user?.uid;

        // Verificar que token y uid no sean nulos
        if (token == null || uid == null) {
          print('Error: Token o UID nulos después de iniciar sesión');
          throw Exception("Token o UID nulos");
        }

        // Enviar solicitud al backend
        final response = await http.post(
          Uri.parse('$apiUrl/auth/login'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({'email': email, 'uid': uid}),
        );

        // Verificar respuesta
        if (response.statusCode == 200) {
          print('Login en backend exitoso');
        } else {
          print(
            'Error en login de backend: ${response.statusCode} - ${response.body}',
          );
        }
      } catch (backendError) {
        print('Error al comunicarse con el backend: $backendError');
      }

      notifyListeners();
      return userCredential.user;
    } catch (e) {
      print('Error al iniciar sesión: $e');
      rethrow;
    }
  }

  // Iniciar sesión con Google
  Future<User?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      final user = userCredential.user;

      // Si es la primera vez que el usuario inicia sesión, guardamos sus datos
      if (userCredential.additionalUserInfo?.isNewUser ?? false) {
        await _firestore.collection('users').doc(user?.uid).set({
          'email': user?.email,
          'displayName': user?.displayName,
          'photoURL': user?.photoURL,
          'role': 'user',
          'createdAt': FieldValue.serverTimestamp(),
        });

        // Obtener token para el backend
        final token = await user?.getIdToken();

        // Registrar en backend
        try {
          await http.post(
            Uri.parse('$apiUrl/auth/register'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': token != null ? 'Bearer $token' : '',
            },
            body: jsonEncode({
              'email': user?.email,
              'firstName': user?.displayName?.split(' ').first ?? '',
              'lastName': user?.displayName?.split(' ').last ?? '',
              'uid': user?.uid,
            }),
          );
        } catch (e) {
          print('Error al registrar en backend: $e');
        }
      } else {
        // Informar al backend del login con Google
        final token = await user?.getIdToken();

        try {
          if (token != null && user?.uid != null) {
            await http.post(
              Uri.parse('$apiUrl/auth/login'),
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $token',
              },
              body: jsonEncode({'email': user?.email, 'uid': user?.uid}),
            );
          }
        } catch (e) {
          print('Error al informar login a backend: $e');
        }
      }

      notifyListeners();
      return user;
    } catch (e) {
      print('Error al iniciar sesión con Google: $e');
      rethrow;
    }
  }

  // Registro con email y contraseña
  Future<User?> registerWithEmailAndPassword(
    String email,
    String password,
    String firstName,
    String lastName,
  ) async {
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = userCredential.user;

      // Actualizar el nombre en Firebase Auth
      await user?.updateDisplayName('$firstName $lastName');

      // Guardar datos adicionales en Firestore
      await _firestore.collection('users').doc(user?.uid).set({
        'email': email,
        'firstName': firstName,
        'lastName': lastName,
        'displayName': '$firstName $lastName',
        'role': 'user',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Obtener token
      final token = await user?.getIdToken();

      // Registrar en backend
      try {
        await http.post(
          Uri.parse('$apiUrl/auth/register'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': token != null ? 'Bearer $token' : '',
          },
          body: jsonEncode({
            'email': email,
            'firstName': firstName,
            'lastName': lastName,
            'password': password,
            'uid': user?.uid,
          }),
        );
      } catch (e) {
        print('Error al registrar en backend: $e');
      }

      notifyListeners();
      return user;
    } catch (e) {
      print('Error al registrar usuario: $e');
      rethrow;
    }
  }

  // Cerrar sesión
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      await _auth.signOut();
      notifyListeners();
    } catch (e) {
      print('Error al cerrar sesión: $e');
      rethrow;
    }
  }

  // Obtener token ID para las peticiones al backend
  Future<String?> getIdToken() async {
    return await _auth.currentUser?.getIdToken();
  }

  // Verificar token con backend
  Future<bool> verifyToken() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      final token = await user.getIdToken();

      final response = await http.post(
        Uri.parse('$apiUrl/auth/verify-token'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'idToken': token}),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Error al verificar token: $e');
      return false;
    }
  }
}
