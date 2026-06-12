import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
            'DefaultFirebaseOptions not configured for this platform');
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyA2FtqIjZRSHP2eOGKDC4a98kFQrnBScS0',
    appId: '1:332127348645:web:232531e07e94545bc72a4c',
    messagingSenderId: '332127348645',
    projectId: 'showsnap-2',
    authDomain: 'showsnap-2.firebaseapp.com',
    databaseURL: 'https://showsnap-2-default-rtdb.firebaseio.com',
    storageBucket: 'showsnap-2.firebasestorage.app',
  );

  // TODO: Replace appId with the one from google-services.json (Android App)
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyA2FtqIjZRSHP2eOGKDC4a98kFQrnBScS0',
    appId: '1:332127348645:android:REPLACE_WITH_ANDROID_APP_ID',
    messagingSenderId: '332127348645',
    projectId: 'showsnap-2',
    databaseURL: 'https://showsnap-2-default-rtdb.firebaseio.com',
    storageBucket: 'showsnap-2.firebasestorage.app',
  );

  // TODO: Replace appId with the one from GoogleService-Info.plist (iOS App)
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyA2FtqIjZRSHP2eOGKDC4a98kFQrnBScS0',
    appId: '1:332127348645:ios:REPLACE_WITH_IOS_APP_ID',
    messagingSenderId: '332127348645',
    projectId: 'showsnap-2',
    databaseURL: 'https://showsnap-2-default-rtdb.firebaseio.com',
    storageBucket: 'showsnap-2.firebasestorage.app',
    iosBundleId: 'com.tenx.showsnap',
  );
}
