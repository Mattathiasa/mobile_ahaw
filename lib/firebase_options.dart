// Firebase web options for the mahibere-ahaw project, derived from the
// Android/iOS config files already in the repo (same project + API key work
// across platforms as long as the key isn't HTTP-referrer-restricted).
//
// NOTE: `appId` below is a placeholder. For full web parity (analytics, FCM on
// web), run `flutterfire configure` once to regenerate this file with the real
// Web App ID from the Firebase console. Auth and Firestore work with these
// values as-is.
//
// ignore_for_file: type=lint
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
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for macOS.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBzP9grJ5Vx6ZsTESSZ3kMdhsl6vaah1Ew',
    appId: '1:43913101958:web:PLACEHOLDER_RUN_FLUTTERFIRE_CONFIGURE',
    messagingSenderId: '43913101958',
    projectId: 'mahibere-ahaw',
    authDomain: 'mahibere-ahaw.firebaseapp.com',
    storageBucket: 'mahibere-ahaw.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCD8nSoD4W9o7r0SwYJt-RVKhmcBV19EDo',
    appId: '1:43913101958:android:63093cbdc5ff8d6c294707',
    messagingSenderId: '43913101958',
    projectId: 'mahibere-ahaw',
    storageBucket: 'mahibere-ahaw.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBzP9grJ5Vx6ZsTESSZ3kMdhsl6vaah1Ew',
    appId: '1:43913101958:ios:d8823fdba45f4248294707',
    messagingSenderId: '43913101958',
    projectId: 'mahibere-ahaw',
    storageBucket: 'mahibere-ahaw.firebasestorage.app',
    iosBundleId: 'com.example.mobileAhaw',
  );
}
