import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // URL de tu API backend
  final String apiUrl = 'http://192.168.1.6:3000/api';

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

        print(
          'Token obtenido: ${token.substring(0, 10)}...',
        ); // Solo muestra los primeros 10 caracteres por seguridad
        print('UID: $uid');

        // URL completa para depuración
        final url = Uri.parse('$apiUrl/auth/login');
        print('URL de login: ${url.toString()}');

        // Enviar solicitud al backend
        final response = await http.post(
          Uri.parse(
            'http://192.168.1.6:3000/api/auth/login',
          ), // URL hardcodeada para prueba
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({'email': email, 'uid': uid}),
        );

        // Verificar respuesta
        print('Respuesta del backend: ${response.statusCode}');
        print('Cuerpo de respuesta: ${response.body}');

        if (response.statusCode == 200) {
          print('Login en backend exitoso');
        } else {
          print(
            'Error en login de backend: ${response.statusCode} - ${response.body}',
          );
          // No interrumpimos el flujo por fallos del backend
        }
      } catch (backendError) {
        print('Error al comunicarse con el backend: $backendError');
        // No interrumpimos el flujo por fallos del backend
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

        // También registramos el usuario en nuestro backend
        try {
          await http.post(
            Uri.parse('$apiUrl/auth/register'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'email': user?.email,
              'firstName': user?.displayName?.split(' ').first,
              'lastName': user?.displayName?.split(' ').last,
              'password':
                  'google-auth-user', // Contraseña temporal para usuarios de Google
              'uid': user?.uid,
            }),
          );
          print('Respuesta recibida del backend');
        } catch (e) {
          print('Error al registrar en backend: $e');
          // No detenemos el flujo por error del backend
        }
      }
      print('Respuesta recibida del backend');

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

      // Registrar en nuestro backend
      try {
        await http.post(
          Uri.parse('$apiUrl/auth/register'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'email': email,
            'firstName': firstName,
            'lastName': lastName,
            'password': password,
          }),
        );
      } catch (e) {
        print('Error al registrar en backend: $e');
        // No detenemos el flujo por error del backend
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
}
