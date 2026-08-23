import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/app_models.dart';

class AuthService {
  AuthService({FirebaseAuth? auth, FirebaseFirestore? db})
    : _auth = auth ?? FirebaseAuth.instance,
      _db = db ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;

  Stream<User?> get authChanges => _auth.authStateChanges();
  User? get currentAuthUser => _auth.currentUser;

  Future<void> signIn({required String email, required String password}) async {
    await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<void> register({
    required String name,
    required String phone,
    required String email,
    required String password,
    required AppRole role,
    required String zoneId,
    Map<String, dynamic> extra = const {},
  }) async {
    UserCredential? credential;
    try {
      credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      await credential.user!.updateDisplayName(name.trim());
      final uid = credential.user!.uid;
      final verification = role == AppRole.customer ? 'approved' : 'pending';
      final userData = <String, dynamic>{
        'id': uid,
        'name': name.trim(),
        'phone': phone.trim(),
        'email': email.trim().toLowerCase(),
        'role': role.value,
        'verification_status': verification,
        'zone_id': zoneId,
        'photo_url': extra['photo_url'] ?? '',
        'extra': extra,
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      };
      final batch = _db.batch();
      batch.set(_db.collection('users').doc(uid), userData);
      if (role == AppRole.driver) {
        batch.set(_db.collection('drivers').doc(uid), {
          'user_id': uid,
          'vehicle_type': extra['vehicle_type'] ?? '',
          'vehicle_brand': extra['vehicle_brand'] ?? '',
          'plate_number': extra['plate_number'] ?? '',
          'face_url': extra['face_url'] ?? '',
          'identity_url': extra['identity_url'] ?? '',
          'is_active': false,
          'current_order_id': '',
          'zone_id': zoneId,
          'created_at': FieldValue.serverTimestamp(),
        });
      } else if (role == AppRole.umkm) {
        batch.set(_db.collection('merchants').doc(uid), {
          'user_id': uid,
          'business_name': extra['business_name'] ?? name,
          'category': extra['business_category'] ?? '',
          'address': extra['business_address'] ?? '',
          'description': extra['description'] ?? '',
          'image_url': extra['photo_url'] ?? '',
          'is_open': false,
          'zone_id': zoneId,
          'created_at': FieldValue.serverTimestamp(),
        });
      } else if (role == AppRole.service) {
        batch.set(_db.collection('service_partners').doc(uid), {
          'user_id': uid,
          'service_type': extra['service_type'] ?? '',
          'description': extra['description'] ?? '',
          'image_url': extra['photo_url'] ?? '',
          'is_available': false,
          'zone_id': zoneId,
          'created_at': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
    } catch (_) {
      await credential?.user?.delete();
      rethrow;
    }
  }

  Future<void> signOut() => _auth.signOut();

  Future<void> sendPasswordReset(String email) =>
      _auth.sendPasswordResetEmail(email: email.trim());
}
