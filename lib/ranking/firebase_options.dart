/// The Firebase project the game uses.
library;

import 'package:firebase_core/firebase_core.dart';

/// Firebase web app settings from the Firebase console. They are meant to
/// be public: access to the data is controlled by firestore.rules.
const firebaseOptions = FirebaseOptions(
  apiKey: 'AIzaSyACFEaxegvXMGj92bqOzLqgBY2SHpOpu1s',
  authDomain: 'pendulum-feeding-game.firebaseapp.com',
  projectId: 'pendulum-feeding-game',
  storageBucket: 'pendulum-feeding-game.firebasestorage.app',
  messagingSenderId: '903683677413',
  appId: '1:903683677413:web:0f61af20e1a064b0e3480c',
);
