// File generated manually for your Firebase project.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

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
      default:
        throw UnsupportedError(
          'This platform is not supported yet. Configure it in Firebase.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBI71Ylng15kYkggs7OVCFeb5SuMIHKlm4',
    appId: '1:1087473816518:web:73fb726b44117abb7018c7',
    messagingSenderId: '1087473816518',
    projectId: 'mybingoapp-c925a',
    authDomain: 'mybingoapp-c925a.firebaseapp.com',
    databaseURL: 'https://mybingoapp-c925a-default-rtdb.europe-west1.firebasedatabase.app',
    storageBucket: 'mybingoapp-c925a.appspot.com',
    measurementId: 'G-VEZRHFC4ZH',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBI71Ylng15kYkggs7OVCFeb5SuMIHKlm4',
    appId: '1:1087473816518:android:d19942735a297d2e7018c7',
    messagingSenderId: '1087473816518',
    projectId: 'myingoapp-c925a',
    databaseURL: 'https://mybingoapp-c925a-default-rtdb.europe-west1.firebasedatabase.app',
    storageBucket: 'mybingoapp-c925a.appspot.com',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBI71Ylng15kYkggs7OVCFeb5SuMIHKlm4',
    appId: '1:1087473816518:ios:8c2813a351f333337018c7',
    messagingSenderId: '1087473816518',
    projectId: 'mybingoapp-c925a',
    databaseURL: 'https://mybingoapp-c925a-default-rtdb.europe-west1.firebasedatabase.app',
    storageBucket: 'mybingoapp-c925a.appspot.com',
    iosBundleId: 'com.example.mygame',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyBI71Ylng15kYkggs7OVCFeb5SuMIHKlm4',
    appId: '1:1087473816518:ios:8c2813a351f333337018c7',
    messagingSenderId: '1087473816518',
    projectId: 'mybingoapp-c925a',
    databaseURL: 'https://mybingoapp-c925a-default-rtdb.europe-west1.firebasedatabase.app',
    storageBucket: 'mybingoapp-c925a.appspot.com',
    iosBundleId: 'com.example.mygame',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyBI71Ylng15kYkggs7OVCFeb5SuMIHKlm4',
    appId: '1:1087473816518:web:130985dc7614d9b17018c7',
    messagingSenderId: '1087473816518',
    projectId: 'mybingoapp-c925a',
    authDomain: 'mybingoapp-c925a.firebaseapp.com',
    databaseURL: 'https://mybingoapp-c925a-default-rtdb.europe-west1.firebasedatabase.app',
    storageBucket: 'mybingoapp-c925a.appspot.com',
    measurementId: 'G-VEZRHFC4ZH',
  );
}
