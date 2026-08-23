import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();

  StreamSubscription<String>? _refreshSubscription;

  Future<void> initializeForSignedInUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await FirebaseMessaging.instance.requestPermission(alert: true, badge: true, sound: true);
    final token = await FirebaseMessaging.instance.getToken();
    if (token != null) await _saveToken(user.uid, token);
    await _refreshSubscription?.cancel();
    _refreshSubscription = FirebaseMessaging.instance.onTokenRefresh.listen(
      (value) => _saveToken(user.uid, value),
    );
  }

  Future<void> _saveToken(String uid, String token) async {
    await FirebaseFirestore.instance.collection('users').doc(uid).set({
      'fcm_token': token,
      'fcm_updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    final user = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    if (user.data()?['role'] == 'driver') {
      await FirebaseFirestore.instance.collection('drivers').doc(uid).set({
        'fcm_token': token,
      }, SetOptions(merge: true));
    }
  }
}

