// File: lib/firebase_options.dart
// ============================================================
// QUAN TRỌNG: Thay thế các giá trị YOUR_... bằng config thực
// từ Firebase Console > Project Settings > Your apps > Web app
// ============================================================

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
        throw UnsupportedError(
          'Ứng dụng này chỉ chạy trên Web. Chưa cấu hình Firebase cho Android.',
        );
      case TargetPlatform.iOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for ios - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.macOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for macos - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
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

  /// ⚠️ THAY THẾ các giá trị bên dưới bằng config Firebase của bạn
  /// Lấy từ: Firebase Console > Project Settings > Your apps > Web app
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: "AIzaSyCoyA5GpUoVVi1VBkVda-TIlcytjNrqX6Q",
  authDomain: "nguoi-di-rung.firebaseapp.com",
  databaseURL: "https://nguoi-di-rung-default-rtdb.asia-southeast1.firebasedatabase.app",
  projectId: "nguoi-di-rung",
  storageBucket: "nguoi-di-rung.firebasestorage.app",
  messagingSenderId: "951154714575",
  appId: "1:951154714575:web:9530dea658f385377294ba",
  measurementId: "G-GQP6RZF5HW"
  );


}
