import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';

import '../core/formatters.dart';
import '../models/app_models.dart';

class FirestoreService {
  FirestoreService({
    FirebaseFirestore? db,
    FirebaseAuth? auth,
    FirebaseStorage? storage,
  }) : _db = db ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance,
       _storage = storage ?? FirebaseStorage.instance;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;
  final FirebaseStorage _storage;

  String get uid => _auth.currentUser!.uid;

  Stream<AppUser?> watchCurrentUser() => _db
      .collection('users')
      .doc(uid)
      .snapshots()
      .map((doc) => doc.exists ? AppUser.fromDoc(doc) : null);

  Future<AppUser> currentUser() async =>
      AppUser.fromDoc(await _db.collection('users').doc(uid).get());

  Stream<List<AppZone>> watchZones() => _db
      .collection('zones')
      .where('is_active', isEqualTo: true)
      .snapshots()
      .map(
        (snap) =>
            snap.docs.map(AppZone.fromDoc).toList()
              ..sort((a, b) => a.name.compareTo(b.name)),
      );

  Stream<PricingConfig> watchPricing() => _db
      .collection('app_config')
      .doc('pricing')
      .snapshots()
      .map((doc) => PricingConfig.fromMap(doc.data()));

  static const _maxInlineImageBytes = 600 * 1024;

  Future<String> uploadImage(XFile file, String folder) async {
    final Uint8List bytes = await file.readAsBytes();
    if (bytes.isEmpty) {
      throw Exception('File gambar kosong atau tidak dapat dibaca.');
    }
    if (bytes.lengthInBytes >= 5 * 1024 * 1024) {
      throw Exception('Ukuran gambar maksimal 5 MB.');
    }
    final rawName = file.name.trim().isEmpty ? 'image.jpg' : file.name.trim();
    final safeName = rawName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final contentType = _resolveImageContentType(file, safeName);
    final ref = _storage.ref(
      '$folder/${DateTime.now().millisecondsSinceEpoch}_$safeName',
    );
    try {
      final snapshot = await ref.putData(
        bytes,
        SettableMetadata(contentType: contentType),
      );
      if (snapshot.state != TaskState.success) {
        throw Exception('Upload gambar belum selesai (${snapshot.state.name}).');
      }
      return await snapshot.ref.getDownloadURL();
    } on FirebaseException catch (e) {
      if (e.code == 'object-not-found' ||
          e.code == 'bucket-not-found' ||
          e.code == 'unimplemented') {
        if (bytes.lengthInBytes > _maxInlineImageBytes) {
          final kb = (bytes.lengthInBytes / 1024).round();
          throw Exception(
            'Firebase Storage belum aktif dan ukuran gambar ($kb KB) terlalu besar untuk disimpan di Firestore (maks. 600 KB). Pilih gambar lebih kecil atau masukkan URL gambar.',
          );
        }
        return 'data:$contentType;base64,${base64Encode(bytes)}';
      }
      if (e.code == 'unauthorized') {
        throw Exception(
          'Upload ditolak (${e.code}): Periksa login akun dan storage.rules pada folder $folder.',
        );
      }
      throw Exception('Upload gambar gagal (${e.code}): ${e.message ?? e}');
    }
  }

  String _resolveImageContentType(XFile file, String fileName) {
    final mime = file.mimeType?.trim().toLowerCase() ?? '';
    if (mime.startsWith('image/')) return mime;
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.gif')) return 'image/gif';
    return 'image/jpeg';
  }

  Future<void> updateRegistrationImages(
    AppRole role,
    Map<String, String> urls,
  ) async {
    final userUpdate = <String, dynamic>{};
    if (urls['photo_url']?.isNotEmpty ?? false) {
      userUpdate['photo_url'] = urls['photo_url'];
    }
    if (urls.isNotEmpty) {
      for (final entry in urls.entries) {
        userUpdate['extra.${entry.key}'] = entry.value;
      }
      userUpdate['updated_at'] = FieldValue.serverTimestamp();
      await _db.collection('users').doc(uid).update(userUpdate);
    }
    if (role == AppRole.driver) {
      await _db.collection('drivers').doc(uid).set({
        if (urls['face_url']?.isNotEmpty ?? false) 'face_url': urls['face_url'],
        if (urls['identity_url']?.isNotEmpty ?? false)
          'identity_url': urls['identity_url'],
      }, SetOptions(merge: true));
    } else if (role == AppRole.umkm) {
      await _db.collection('merchants').doc(uid).set({
        if (urls['photo_url']?.isNotEmpty ?? false)
          'image_url': urls['photo_url'],
      }, SetOptions(merge: true));
    } else if (role == AppRole.service) {
      await _db.collection('service_partners').doc(uid).set({
        if (urls['photo_url']?.isNotEmpty ?? false)
          'image_url': urls['photo_url'],
      }, SetOptions(merge: true));
    }
  }

  /// Updates the signed-in customer's profile in Firestore and best-effort Auth.
  Future<String?> updateCustomerProfile({
    required String name,
    required String email,
    required String zoneId,
    required String photoUrl,
  }) async {
    final trimmedName = name.trim();
    final normalizedEmail = email.trim().toLowerCase();
    final trimmedZone = zoneId.trim();
    final trimmedPhoto = photoUrl.trim();

    await _db.collection('users').doc(uid).update({
      'name': trimmedName,
      'email': normalizedEmail,
      'zone_id': trimmedZone,
      'photo_url': trimmedPhoto,
      'updated_at': FieldValue.serverTimestamp(),
    });

    final authUser = _auth.currentUser;
    if (authUser == null) return null;

    try {
      if ((authUser.displayName ?? '').trim() != trimmedName) {
        await authUser.updateDisplayName(trimmedName);
      }
    } catch (_) {
      // Display name sync on Auth is best-effort; Firestore is source of truth.
    }

    final currentAuthEmail = (authUser.email ?? '').trim().toLowerCase();
    if (normalizedEmail.isNotEmpty && normalizedEmail != currentAuthEmail) {
      try {
        await authUser.verifyBeforeUpdateEmail(normalizedEmail);
        return 'Profil disimpan. Cek email $normalizedEmail untuk verifikasi perubahan email login.';
      } on FirebaseAuthException catch (e) {
        if (e.code == 'requires-recent-login') {
          return 'Profil & email tampilan disimpan. Untuk mengubah email login utama, silakan keluar lalu masuk ulang terlebih dahulu.';
        }
        return 'Profil disimpan di aplikasi (email login Auth tidak berubah: ${e.code}).';
      } catch (_) {
        return 'Profil berhasil diperbarui.';
      }
    }
    return null;
  }

  Stream<List<Product>> watchProducts({String? merchantId, int? limit}) {
    Query<Map<String, dynamic>> query = _db.collection('products');
    if (merchantId != null) {
      query = query.where('merchant_id', isEqualTo: merchantId);
    }
    if (merchantId == null) {
      query = query
          .where('is_active', isEqualTo: true)
          .orderBy('created_at', descending: true);
    }
    if (limit != null) query = query.limit(limit);
    return query.snapshots().map(
      (snap) => snap.docs.map(Product.fromDoc).toList(),
    );
  }

  Future<void> saveProduct({
    String? id,
    required String merchantName,
    required String name,
    required String description,
    required String category,
    required int price,
    required int stock,
    required String imageUrl,
    int discountPercent = 0,
  }) async {
    final ref = id == null
        ? _db.collection('products').doc()
        : _db.collection('products').doc(id);
    await ref.set({
      'merchant_id': uid,
      'merchant_name': merchantName,
      'name': name.trim(),
      'description': description.trim(),
      'category': category,
      'price': price,
      'discount_percent': discountPercent.clamp(0, 100),
      'stock': stock,
      'image_url': imageUrl,
      'is_active': stock > 0,
      'updated_at': FieldValue.serverTimestamp(),
      if (id == null) 'created_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> deleteProduct(String id) =>
      _db.collection('products').doc(id).delete();

  Stream<List<ServiceListing>> watchServiceListings({String? partnerId}) {
    Query<Map<String, dynamic>> query = _db.collection('service_listings');
    if (partnerId != null) {
      query = query.where('partner_id', isEqualTo: partnerId);
    }
    return query.snapshots().map(
      (snap) => snap.docs.map(ServiceListing.fromDoc).toList(),
    );
  }

  Future<void> saveServiceListing({
    String? id,
    required AppUser partner,
    required String name,
    required String description,
    required String category,
    required int estimatedPrice,
    required String imageUrl,
  }) async {
    final ref = id == null
        ? _db.collection('service_listings').doc()
        : _db.collection('service_listings').doc(id);
    await ref.set({
      'partner_id': uid,
      'partner_name': partner.name,
      'name': name.trim(),
      'description': description.trim(),
      'category': category,
      'estimated_price': estimatedPrice,
      'image_url': imageUrl,
      'zone_id': partner.zoneId,
      'is_active': true,
      'updated_at': FieldValue.serverTimestamp(),
      if (id == null) 'created_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> deleteServiceListing(String id) =>
      _db.collection('service_listings').doc(id).delete();

  Stream<List<ContentItem>> watchContent(String type) => _db
      .collection('content')
      .where('type', isEqualTo: type)
      .where('is_published', isEqualTo: true)
      .orderBy('published_at', descending: true)
      .snapshots()
      .map((snap) => snap.docs.map(ContentItem.fromDoc).toList());

  Stream<List<EmergencyContact>> watchEmergencyContacts() => _db
      .collection('emergency_contacts')
      .snapshots()
      .map((snap) => snap.docs.map(EmergencyContact.fromDoc).toList());

  Stream<List<InboxMessage>> watchInbox() => _db
      .collection('inbox')
      .where('user_id', isEqualTo: uid)
      .orderBy('created_at', descending: true)
      .snapshots()
      .map((snap) => snap.docs.map(InboxMessage.fromDoc).toList());

  Future<void> markInboxRead(String id) =>
      _db.collection('inbox').doc(id).update({'is_read': true});

  Stream<List<AppOrder>> watchCustomerHistory() => _db
      .collection('orders')
      .where('customer_id', isEqualTo: uid)
      .orderBy('created_at', descending: true)
      .snapshots()
      .map((snap) => snap.docs.map(AppOrder.fromDoc).toList());

  Stream<int> watchOnlineDriverCount() => _db
      .collection('drivers')
      .where('is_active', isEqualTo: true)
      .snapshots()
      .map(
        (snap) => snap.docs.where((doc) {
          final data = doc.data();
          return (data['current_order_id'] ?? '').toString().isEmpty;
        }).length,
      );

  Stream<AppOrder?> watchOrder(String id) => _db
      .collection('orders')
      .doc(id)
      .snapshots()
      .map((doc) => doc.exists ? AppOrder.fromDoc(doc) : null);

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchDriverPublicProfile(
    String driverId,
  ) => _db.collection('drivers').doc(driverId).snapshots();

  Future<String> createRideOrder({
    required AppUser customer,
    required String serviceType,
    required AddressPoint pickup,
    required AddressPoint destination,
    required MapRoute route,
    required PricingConfig pricing,
    required String paymentMethod,
  }) async {
    if (serviceType == 'ojek') {
      final activeOrder = await _db
          .collection('orders')
          .where('customer_id', isEqualTo: uid)
          .where(
            'status',
            whereIn: const [
              'searching',
              'pending_confirmation',
              'driver_confirmed',
              'heading_to_pickup',
              'at_pickup',
              'on_delivery',
            ],
          )
          .limit(1)
          .get();
      if (activeOrder.docs.isNotEmpty) {
        throw StateError('Anda masih memiliki order ojek yang belum selesai.');
      }
    }
    final ref = _db.collection('orders').doc();
    final fare = FareCalculator.calculate(
      route.distanceKm,
      firstTwoKmFare: pricing.firstTwoKmFare,
      additionalPerKm: pricing.additionalPerKm,
    );
    await ref.set({
      'customer_id': uid,
      'customer_name': customer.name,
      'customer_phone': customer.phone,
      'customer_photo_url': customer.photoUrl,
      'driver_id': '',
      'driver_name': '',
      'merchant_id': '',
      'partner_id': '',
      'service_type': serviceType,
      'pickup': pickup.toMap(),
      'destination': destination.toMap(),
      'distance_km': route.distanceKm,
      'duration_minutes': route.durationMinutes,
      'fare': fare,
      'status': 'searching',
      'payment_method': paymentMethod,
      'zone_id': customer.zoneId,
      'route_points': route.points
          .map((p) => GeoPoint(p.latitude, p.longitude))
          .toList(),
      'items': <Map<String, dynamic>>[],
      'meta': <String, dynamic>{},
      'rejected_driver_ids': <String>[],
      'created_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  Future<String> createFoodOrder({
    required AppUser customer,
    required String merchantId,
    required String merchantName,
    required List<Map<String, dynamic>> items,
    required int foodSubtotal,
    required int deliveryFare,
    required int total,
    required AddressPoint pickup,
    required AddressPoint destination,
    required String paymentMethod,
    MapRoute? route,
  }) async {
    final ref = _db.collection('orders').doc();
    await ref.set({
      'customer_id': uid,
      'customer_name': customer.name,
      'customer_phone': customer.phone,
      'customer_photo_url': customer.photoUrl,
      'driver_id': '',
      'driver_name': '',
      'merchant_id': merchantId,
      'merchant_name': merchantName,
      'partner_id': '',
      'service_type': 'food',
      'pickup': pickup.toMap(),
      'destination': destination.toMap(),
      'distance_km': route?.distanceKm ?? 0,
      'duration_minutes': route?.durationMinutes ?? 0,
      'fare': total,
      'status': 'waiting_merchant',
      'payment_method': paymentMethod,
      'zone_id': customer.zoneId,
      'route_points': (route?.points ?? const <LatLng>[])
          .map((p) => GeoPoint(p.latitude, p.longitude))
          .toList(),
      'items': items,
      'meta': {
        'delivery_type': 'delivery',
        'merchant_name': merchantName,
        'food_subtotal': foodSubtotal,
        'delivery_fare': deliveryFare,
        'merchant_accepted': false,
        'merchant_stage': 'waiting',
      },
      'rejected_driver_ids': <String>[],
      'created_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  Future<Map<String, dynamic>> getMerchantPublicProfile(
    String merchantId,
  ) async {
    final doc = await _db.collection('merchants').doc(merchantId).get();
    return doc.data() ?? <String, dynamic>{};
  }

  Future<void> updateMerchantLocation(LatLng point, String address) =>
      _db.collection('merchants').doc(uid).set({
        'location': GeoPoint(point.latitude, point.longitude),
        'address': address.trim(),
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

  Future<void> acceptMerchantFoodOrder(AppOrder order) async {
    await _db.collection('orders').doc(order.id).update({
      'status': 'searching',
      'meta': {
        ...order.meta,
        'merchant_accepted': true,
        'merchant_stage': 'preparing',
      },
      'updated_at': FieldValue.serverTimestamp(),
    });
    await _db.collection('inbox').doc('${order.id}_searching').set({
      'user_id': order.customerId,
      'order_id': order.id,
      'title': 'Pesanan Diterima UMKM',
      'message':
          'UMKM menerima pesanan Anda dan GoBran sedang mencari driver.',
      'is_read': false,
      'created_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> handOverFoodOrderToDriver(AppOrder order) async {
    await _db.collection('orders').doc(order.id).update({
      'meta': {
        ...order.meta,
        'merchant_accepted': true,
        'merchant_stage': 'handed_over',
      },
      'updated_at': FieldValue.serverTimestamp(),
    });
    await _db.collection('inbox').doc('${order.id}_handed_over').set({
      'user_id': order.customerId,
      'order_id': order.id,
      'title': 'Diserahkan ke Driver',
      'message': 'Pesanan makanan sudah diserahkan UMKM kepada driver.',
      'is_read': false,
      'created_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> cancelFoodOrderByMerchant(AppOrder order) => updateOrderStatus(
    order,
    'cancelled',
    message: 'Pesanan dibatalkan oleh UMKM.',
  );

  Future<String> createServiceRequest({
    required AppUser customer,
    required ServiceListing listing,
    required String address,
    required String note,
  }) async {
    final ref = _db.collection('orders').doc();
    await ref.set({
      'customer_id': uid,
      'customer_name': customer.name,
      'driver_id': '',
      'driver_name': '',
      'merchant_id': '',
      'partner_id': listing.partnerId,
      'partner_name': listing.partnerName,
      'service_type': 'service',
      'pickup': const AddressPoint(
        latitude: 0,
        longitude: 0,
        address: '',
      ).toMap(),
      'destination': AddressPoint(
        latitude: 0,
        longitude: 0,
        address: address,
        note: note,
      ).toMap(),
      'distance_km': 0,
      'duration_minutes': 0,
      'fare': listing.estimatedPrice,
      'status': 'waiting_partner',
      'payment_method': 'cash',
      'zone_id': customer.zoneId,
      'items': <Map<String, dynamic>>[],
      'meta': {'listing_id': listing.id, 'listing_name': listing.name},
      'created_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  Stream<List<AppOrder>> watchOpenDriverOrders(String zoneId) => _db
      .collection('orders')
      .where('zone_id', isEqualTo: zoneId)
      .where('status', isEqualTo: 'searching')
      .orderBy('created_at', descending: true)
      .snapshots()
      .map(
        (snap) => snap.docs
            .map(AppOrder.fromDoc)
            // Filter client-side: jangan tampilkan order yang sudah menolak driver ini
            .where((order) => !order.rejectedDriverIds.contains(uid))
            .toList(),
      );

  /// Stream order aktif milik driver saat ini (belum selesai)
  Stream<AppOrder?> watchMyCurrentDriverOrder() => _db
      .collection('orders')
      .where('driver_id', isEqualTo: uid)
      .orderBy('created_at', descending: true)
      .limit(10)
      .snapshots()
      .map((snap) {
        const activeStatuses = [
          'pending_confirmation',
          'driver_confirmed',
          'heading_to_pickup',
          'at_pickup',
          'on_delivery',
        ];
        final orders = snap.docs.map(AppOrder.fromDoc).toList();
        try {
          return orders.firstWhere((o) => activeStatuses.contains(o.status));
        } catch (_) {
          return null;
        }
      });

  Stream<List<AppOrder>> watchDriverOrders() => _db
      .collection('orders')
      .where('driver_id', isEqualTo: uid)
      .orderBy('created_at', descending: true)
      .snapshots()
      .map((snap) => snap.docs.map(AppOrder.fromDoc).toList());

  Future<bool> acceptDriverOrder(String orderId, AppUser driver) async {
    final ref = _db.collection('orders').doc(orderId);
    final driverRef = _db.collection('drivers').doc(uid);
    return _db.runTransaction((transaction) async {
      final driverDoc = await transaction.get(driverRef);
      final doc = await transaction.get(ref);
      final data = doc.data();
      final currentOrderId =
          driverDoc.data()?['current_order_id']?.toString() ?? '';
      DocumentSnapshot<Map<String, dynamic>>? currentOrderDoc;
      if (currentOrderId.isNotEmpty && currentOrderId != orderId) {
        currentOrderDoc = await transaction.get(
          _db.collection('orders').doc(currentOrderId),
        );
      }
      final currentStatus = currentOrderDoc?.data()?['status']?.toString();
      final currentOrderIsActive =
          currentOrderDoc?.exists == true &&
          const [
            'pending_confirmation',
            'driver_confirmed',
            'heading_to_pickup',
            'at_pickup',
            'on_delivery',
          ].contains(currentStatus);
      if (data == null ||
          data['status'] != 'searching' ||
          (data['driver_id'] ?? '').toString().isNotEmpty ||
          currentOrderIsActive) {
        return false;
      }
      // Pastikan driver ini belum pernah ditolak oleh pelanggan untuk order ini
      final rejectedIds = List<String>.from(data['rejected_driver_ids'] ?? []);
      if (rejectedIds.contains(uid)) return false;

      final isFood = data['service_type'] == 'food';
      transaction.update(driverRef, {'current_order_id': orderId});
      transaction.update(ref, {
        'driver_id': uid,
        'driver_name': driver.name,
        'driver_photo_url': driver.photoUrl,
        'driver_phone': driver.phone,
        'status': isFood ? 'driver_confirmed' : 'pending_confirmation',
        if (isFood) 'confirmed_at': FieldValue.serverTimestamp(),
        'accepted_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      });
      return true;
    });
  }

  /// Pelanggan mengkonfirmasi driver → status menjadi driver_confirmed
  Future<void> confirmDriver(AppOrder order) async {
    await _db.collection('orders').doc(order.id).update({
      'status': 'driver_confirmed',
      'confirmed_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    });
    // Kirim notif ke pelanggan
    await _db.collection('inbox').doc('${order.id}_driver_confirmed').set({
      'user_id': order.customerId,
      'order_id': order.id,
      'title': 'Driver Dikonfirmasi ✅',
      'message':
          'Anda telah menerima driver. Driver segera menuju lokasi Anda.',
      'is_read': false,
      'created_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Pelanggan menolak driver → order kembali ke pool, driver ditambahkan ke daftar rejected
  /// Jika sudah 3× penolakan, order otomatis dibatalkan.
  Future<void> rejectDriver(AppOrder order) async {
    final ref = _db.collection('orders').doc(order.id);
    await _db.runTransaction((transaction) async {
      final doc = await transaction.get(ref);
      final data = doc.data() ?? {};
      final currentDriverId = data['driver_id']?.toString() ?? '';
      final rejectedIds = List<String>.from(data['rejected_driver_ids'] ?? []);

      if (currentDriverId.isNotEmpty &&
          !rejectedIds.contains(currentDriverId)) {
        rejectedIds.add(currentDriverId);
      }

      final shouldCancel = rejectedIds.length >= 3;

      // Bebaskan driver dari order ini
      if (currentDriverId.isNotEmpty) {
        transaction.update(_db.collection('drivers').doc(currentDriverId), {
          'current_order_id': '',
        });
      }

      transaction.update(ref, {
        'rejected_driver_ids': rejectedIds,
        'driver_id': '',
        'driver_name': '',
        'driver_phone': '',
        'driver_photo_url': '',
        'status': shouldCancel ? 'cancelled' : 'searching',
        'updated_at': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<bool> cancelDriverConfirmation(AppOrder order) async {
    final orderRef = _db.collection('orders').doc(order.id);
    final driverRef = _db.collection('drivers').doc(uid);
    await _db.runTransaction((transaction) async {
      final orderDoc = await transaction.get(orderRef);
      final data = orderDoc.data();
      if (data == null ||
          data['status'] != 'pending_confirmation' ||
          data['driver_id'] != uid) {
        throw StateError('Konfirmasi order sudah berubah.');
      }
      transaction.update(driverRef, {'current_order_id': ''});
      transaction.update(orderRef, {
        'driver_id': '',
        'driver_name': '',
        'driver_phone': '',
        'driver_photo_url': '',
        'status': 'searching',
        'updated_at': FieldValue.serverTimestamp(),
      });
    });
    await _db.collection('inbox').doc('${order.id}_driver_cancelled').set({
      'user_id': order.customerId,
      'order_id': order.id,
      'title': 'Driver mencari order lain',
      'message':
          'Driver membatalkan konfirmasi. Kami sedang mencari driver baru untuk Anda.',
      'is_read': false,
      'created_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    return true;
  }

  Future<void> updateOrderStatus(
    AppOrder order,
    String status, {
    String? message,
  }) async {
    await _db.collection('orders').doc(order.id).update({
      'status': status,
      'updated_at': FieldValue.serverTimestamp(),
      if (status == 'completed') 'completed_at': FieldValue.serverTimestamp(),
    });
    if (order.driverId.isNotEmpty &&
        (status == 'completed' || status == 'cancelled')) {
      try {
        await _db.collection('drivers').doc(order.driverId).set({
          'current_order_id': '',
        }, SetOptions(merge: true));
      } catch (_) {
        // Fallback: driver profile self-releases if order is already cancelled.
      }
    }
    await _db.collection('inbox').doc('${order.id}_$status').set({
      'user_id': order.customerId,
      'order_id': order.id,
      'title': 'Pembaruan order',
      'message':
          message ?? _statusMessage(status, serviceType: order.serviceType),
      'is_read': false,
      'created_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  String _statusMessage(String status, {String? serviceType}) {
    final isFood = serviceType == 'food';
    return switch (status) {
      'pending_confirmation' =>
        'Driver ditemukan! Silakan konfirmasi driver Anda.',
      'driver_confirmed' => isFood
          ? 'Driver ditemukan dan siap menuju ke UMKM.'
          : 'Anda telah menerima driver. Driver akan segera menuju lokasi.',
      'heading_to_pickup' => isFood
          ? 'Driver sedang menuju ke UMKM untuk mengambil pesanan.'
          : 'Driver sedang menuju lokasi penjemputan Anda.',
      'at_pickup' => isFood
          ? 'Driver sudah sampai di lokasi UMKM.'
          : 'Driver sudah tiba di titik penjemputan!',
      'on_delivery' => isFood
          ? 'Driver sedang menuju lokasi Anda untuk mengantar makanan.'
          : 'Perjalanan dimulai, menuju tujuan.',
      'completed' => 'Order telah selesai. Terima kasih!',
      'cancelled' => 'Order dibatalkan.',
      'accepted' => 'Order telah diterima mitra.',
      'picked_up' => 'Penumpang atau barang telah dijemput.',
      'preparing' => 'Pesanan sedang disiapkan UMKM.',
      'ready' => 'Pesanan sudah siap diambil atau diantar.',
      _ => 'Status order diperbarui.',
    };
  }

  Future<void> setDriverActive(bool value, LatLng? location) async {
    await _db.collection('drivers').doc(uid).set({
      'is_active': value,
      if (location != null)
        'location': GeoPoint(location.latitude, location.longitude),
      'last_seen_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> updateDriverLocation(LatLng location) =>
      _db.collection('drivers').doc(uid).set({
        'location': GeoPoint(location.latitude, location.longitude),
        'last_seen_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

  Future<void> updateDriverZone(String zoneId) async {
    final trimmedZone = zoneId.trim();
    if (trimmedZone.isEmpty) return;
    final batch = _db.batch();
    batch.update(_db.collection('users').doc(uid), {
      'zone_id': trimmedZone,
      'updated_at': FieldValue.serverTimestamp(),
    });
    batch.set(_db.collection('drivers').doc(uid), {
      'zone_id': trimmedZone,
    }, SetOptions(merge: true));
    await batch.commit();
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchDriverProfile() =>
      _db.collection('drivers').doc(uid).snapshots();
  Stream<DocumentSnapshot<Map<String, dynamic>>> watchMerchantProfile() =>
      _db.collection('merchants').doc(uid).snapshots();
  Stream<DocumentSnapshot<Map<String, dynamic>>> watchServiceProfile() =>
      _db.collection('service_partners').doc(uid).snapshots();

  Future<void> setMerchantOpen(bool value) => _db
      .collection('merchants')
      .doc(uid)
      .set({'is_open': value}, SetOptions(merge: true));
  Future<void> setServiceAvailable(bool value) => _db
      .collection('service_partners')
      .doc(uid)
      .set({'is_available': value}, SetOptions(merge: true));

  Stream<List<AppOrder>> watchMerchantOrders() => _db
      .collection('orders')
      .where('merchant_id', isEqualTo: uid)
      .orderBy('created_at', descending: true)
      .snapshots()
      .map((snap) => snap.docs.map(AppOrder.fromDoc).toList());

  Stream<List<AppOrder>> watchServiceOrders() => _db
      .collection('orders')
      .where('partner_id', isEqualTo: uid)
      .orderBy('created_at', descending: true)
      .snapshots()
      .map((snap) => snap.docs.map(AppOrder.fromDoc).toList());

  Stream<List<AppUser>> watchPendingPartners() => _db
      .collection('users')
      .where('verification_status', isEqualTo: 'pending')
      .snapshots()
      .map((snap) => snap.docs.map(AppUser.fromDoc).toList());

  Future<void> verifyPartner(String userId, String status) =>
      _db.collection('users').doc(userId).update({
        'verification_status': status,
        'verified_at': FieldValue.serverTimestamp(),
        'verified_by': uid,
      });

  Stream<QuerySnapshot<Map<String, dynamic>>> watchAdminCollection(
    String collection,
  ) => _db.collection(collection).snapshots();

  Future<void> saveAdminDocument(
    String collection,
    Map<String, dynamic> data, {
    String? id,
  }) async {
    final ref = id == null
        ? _db.collection(collection).doc()
        : _db.collection(collection).doc(id);
    await ref.set({
      ...data,
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> deleteAdminDocument(String collection, String id) =>
      _db.collection(collection).doc(id).delete();
}
