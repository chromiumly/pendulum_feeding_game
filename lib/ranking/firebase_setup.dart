/// Connecting to Firebase.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';

/// Returns a function that gives Firestore, with Firebase initialised on
/// first use rather than at launch, so that a slow or missing network never
/// delays the game. After a failure the next call tries again.
Future<FirebaseFirestore> Function() lazyFirestore() {
  Future<FirebaseFirestore>? initialised;
  return () => initialised ??= () async {
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(options: firebaseOptions);
      }
      return FirebaseFirestore.instance;
    } on Object {
      initialised = null;
      rethrow;
    }
  }();
}
