// File generated by FlutterFire CLI.
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
///
/// Example:
/// ```dart
/// import 'firebase_options.dart';
/// // ...
/// await Firebase.initializeApp(
///   options: DefaultFirebaseOptions.currentPlatform,
/// );
/// ```
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBbwNqRuGUNBNpnfDUcWD_NN-BEcARTk7k',
    appId: '1:466917125260:web:27e43293534d396fda9fa9',
    messagingSenderId: '466917125260',
    projectId: 'proyectofinal-869b4',
    authDomain: 'proyectofinal-869b4.firebaseapp.com',
    storageBucket: 'proyectofinal-869b4.firebasestorage.app',
    measurementId: 'G-5EYV37VLBF',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAIzTHD4x6a1R0-II2A-o_dQ5V275vkBnU',
    appId: '1:466917125260:android:6e038f2c3d8ee0dbda9fa9',
    messagingSenderId: '466917125260',
    projectId: 'proyectofinal-869b4',
    storageBucket: 'proyectofinal-869b4.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyATNOjkLhPROXU-mUXn6WbjbKtkhXe9qeE',
    appId: '1:466917125260:ios:d5d3d60c5f131f0fda9fa9',
    messagingSenderId: '466917125260',
    projectId: 'proyectofinal-869b4',
    storageBucket: 'proyectofinal-869b4.firebasestorage.app',
    androidClientId: '466917125260-kng90q6t9bjka3e2q7c4i6l6r22j7qii.apps.googleusercontent.com',
    iosClientId: '466917125260-kf4i0ttid7e63tsgriqsalnjt6cjpkaq.apps.googleusercontent.com',
    iosBundleId: 'com.example.parkingApp',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyATNOjkLhPROXU-mUXn6WbjbKtkhXe9qeE',
    appId: '1:466917125260:ios:d5d3d60c5f131f0fda9fa9',
    messagingSenderId: '466917125260',
    projectId: 'proyectofinal-869b4',
    storageBucket: 'proyectofinal-869b4.firebasestorage.app',
    androidClientId: '466917125260-kng90q6t9bjka3e2q7c4i6l6r22j7qii.apps.googleusercontent.com',
    iosClientId: '466917125260-kf4i0ttid7e63tsgriqsalnjt6cjpkaq.apps.googleusercontent.com',
    iosBundleId: 'com.example.parkingApp',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyBbwNqRuGUNBNpnfDUcWD_NN-BEcARTk7k',
    appId: '1:466917125260:web:27e43293534d396fda9fa9',
    messagingSenderId: '466917125260',
    projectId: 'proyectofinal-869b4',
    authDomain: 'proyectofinal-869b4.firebaseapp.com',
    storageBucket: 'proyectofinal-869b4.firebasestorage.app',
    measurementId: 'G-5EYV37VLBF',
  );
}
