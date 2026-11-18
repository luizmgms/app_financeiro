import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

/// Opções do Firebase geradas para o projeto `finance-control-luizmgms`.
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
        throw UnsupportedError(
          'DefaultFirebaseOptions não foi configurado para macOS.',
        );
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions não foi configurado para Linux.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions não é suportado nesta plataforma.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBCC9uXxFXqbk-v9YlIObQRG1nhfJf9rxk',
    appId: '1:419399885428:web:4f443b826ff51f9a716721',
    messagingSenderId: '419399885428',
    projectId: 'finance-control-luizmgms',
    authDomain: 'finance-control-luizmgms.firebaseapp.com',
    storageBucket: 'finance-control-luizmgms.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyB5IfrDf76RnAXsTAMhgemNuuGPbyWJ30w',
    appId: '1:419399885428:android:853081011691e95e716721',
    messagingSenderId: '419399885428',
    projectId: 'finance-control-luizmgms',
    storageBucket: 'finance-control-luizmgms.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAEY-RrWKBPizkA3j0_S-kivZ111qH3NdE',
    appId: '1:419399885428:ios:9b83d3a909d26d5e716721',
    messagingSenderId: '419399885428',
    projectId: 'finance-control-luizmgms',
    storageBucket: 'finance-control-luizmgms.firebasestorage.app',
    androidClientId:
        '419399885428-qv3fmtmdj42kf80v4tp71bu6j6kvse43.apps.googleusercontent.com',
    iosClientId:
        '419399885428-2u94t69r8jn6kee052o6hrpmdugfdr3j.apps.googleusercontent.com',
    iosBundleId: 'br.com.financecontrol.financeControl',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyBCC9uXxFXqbk-v9YlIObQRG1nhfJf9rxk',
    appId: '1:419399885428:web:4f443b826ff51f9a716721',
    messagingSenderId: '419399885428',
    projectId: 'finance-control-luizmgms',
    authDomain: 'finance-control-luizmgms.firebaseapp.com',
    storageBucket: 'finance-control-luizmgms.firebasestorage.app',
  );
}
