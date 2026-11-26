import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';

DateTime _date(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
  return DateTime.now();
}

Map<String, dynamic> _map(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

enum AppRole { customer, driver, umkm, service, admin }

extension AppRoleX on AppRole {
  String get value => name;
  String get label => switch (this) {
    AppRole.customer => 'Pelanggan',
    AppRole.driver => 'Driver',
    AppRole.umkm => 'UMKM',
    AppRole.service => 'Jasa',
    AppRole.admin => 'Admin',
  };

  static AppRole parse(String value) => AppRole.values.firstWhere(
    (role) => role.name == value,
    orElse: () => AppRole.customer,
  );
}

class AppUser {
  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    required this.verificationStatus,
    required this.zoneId,
    required this.photoUrl,
    required this.createdAt,
    this.extra = const {},
  });

  final String id;
  final String name;
  final String email;
  final String phone;
  final AppRole role;
  final String verificationStatus;
  final String zoneId;
  final String photoUrl;
  final DateTime createdAt;
  final Map<String, dynamic> extra;

  factory AppUser.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return AppUser(
      id: doc.id,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      phone: data['phone'] ?? '',
      role: AppRoleX.parse(data['role'] ?? 'customer'),
      verificationStatus: data['verification_status'] ?? 'pending',
      zoneId: data['zone_id'] ?? '',
      photoUrl: data['photo_url'] ?? '',
      createdAt: _date(data['created_at']),
      extra: _map(data['extra']),
    );
  }
}

class AddressPoint {
  const AddressPoint({
    required this.latitude,
    required this.longitude,
    required this.address,
    this.note = '',
  });

  final double latitude;
  final double longitude;
  final String address;
  final String note;

  LatLng get latLng => LatLng(latitude, longitude);

  Map<String, dynamic> toMap() => {
    'latitude': latitude,
    'longitude': longitude,
    'address': address,
    'note': note,
    'geopoint': GeoPoint(latitude, longitude),
  };

  factory AddressPoint.fromMap(dynamic raw) {
    final data = _map(raw);
    final point = data['geopoint'];
    return AddressPoint(
      latitude:
          (data['latitude'] as num?)?.toDouble() ??
          (point is GeoPoint ? point.latitude : 0),
      longitude:
          (data['longitude'] as num?)?.toDouble() ??
          (point is GeoPoint ? point.longitude : 0),
      address: data['address'] ?? '',
      note: data['note'] ?? '',
    );
  }
}

class MapRoute {
  const MapRoute({
    required this.points,
    required this.distanceKm,
    required this.durationMinutes,
  });
  final List<LatLng> points;
  final double distanceKm;
  final double durationMinutes;
}

class AppOrder {
  const AppOrder({
    required this.id,
    required this.customerId,
    required this.customerName,
    required this.customerPhone,
    required this.customerPhotoUrl,
    required this.driverId,
    required this.driverName,
    required this.merchantId,
    required this.partnerId,
    required this.serviceType,
    required this.pickup,
    required this.destination,
    required this.distanceKm,
    required this.durationMinutes,
    required this.fare,
    required this.status,
    required this.paymentMethod,
    required this.zoneId,
    required this.createdAt,
    required this.items,
    required this.meta,
    this.rejectedDriverIds = const [],
  });

  final String id;
  final String customerId;
  final String customerName;
  final String customerPhone;
  final String customerPhotoUrl;
  final String driverId;
  final String driverName;
  final String merchantId;
  final String partnerId;
  final String serviceType;
  final AddressPoint pickup;
  final AddressPoint destination;
  final double distanceKm;
  final double durationMinutes;
  final int fare;
  final String status;
  final String paymentMethod;
  final String zoneId;
  final DateTime createdAt;
  final List<Map<String, dynamic>> items;
  final Map<String, dynamic> meta;
  /// Driver IDs yang sudah ditolak pelanggan untuk order ini
  final List<String> rejectedDriverIds;

  /// Label progres langsung untuk kartu & detail pesanan pelanggan.
  String get customerProgressLabel {
    final drv = driverName.trim().isNotEmpty ? ' ($driverName)' : '';
    if (serviceType == 'food') {
      final handedOver = meta['merchant_stage'] == 'handed_over';
      return switch (status) {
        'waiting_merchant' => 'Menunggu UMKM menerima pesanan',
        'searching' =>
          'Pesanan diterima UMKM • Mencari driver terdekat...',
        'driver_confirmed' => 'Driver$drv menerima pesanan • Siap ke UMKM',
        'heading_to_pickup' => 'Driver$drv sedang menuju ke UMKM',
        'at_pickup' => handedOver
            ? 'Driver$drv sudah di UMKM • Pesanan diserahkan'
            : 'Driver$drv sudah sampai di UMKM',
        'on_delivery' => 'Driver$drv sedang menuju lokasi pelanggan',
        'completed' => 'Pesanan makanan telah selesai diantar',
        'cancelled' => 'Pesanan dibatalkan',
        _ => status,
      };
    }
    return switch (status) {
      'searching' => 'Mencari driver terdekat...',
      'waiting_partner' => 'Menunggu mitra jasa menerima permintaan',
      'accepted' => 'Mitra jasa menerima permintaan Anda',
      'pending_confirmation' =>
        'Driver$drv ditemukan • Menunggu konfirmasi Anda',
      'driver_confirmed' => 'Driver$drv siap menuju titik jemput',
      'heading_to_pickup' => 'Driver$drv sedang menuju titik jemput',
      'at_pickup' => 'Driver$drv sudah sampai di titik jemput',
      'on_delivery' => 'Driver$drv sedang menuju lokasi tujuan',
      'completed' => 'Order selesai',
      'cancelled' => 'Order dibatalkan',
      _ => status,
    };
  }

  /// Pelanggan hanya bisa membatalkan pesanan food sebelum diterima UMKM.
  bool get customerCanCancel {
    if (serviceType == 'food') {
      return status == 'waiting_merchant';
    }
    return const [
      'searching',
      'waiting_partner',
      'pending_confirmation',
      'heading_to_pickup',
    ].contains(status);
  }

  factory AppOrder.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return AppOrder(
      id: doc.id,
      customerId: data['customer_id'] ?? '',
      customerName: data['customer_name'] ?? '',
      customerPhone: data['customer_phone'] ?? '',
      customerPhotoUrl: data['customer_photo_url'] ?? '',
      driverId: data['driver_id'] ?? '',
      driverName: data['driver_name'] ?? '',
      merchantId: data['merchant_id'] ?? '',
      partnerId: data['partner_id'] ?? '',
      serviceType: data['service_type'] ?? '',
      pickup: AddressPoint.fromMap(data['pickup']),
      destination: AddressPoint.fromMap(data['destination']),
      distanceKm: (data['distance_km'] as num?)?.toDouble() ?? 0,
      durationMinutes: (data['duration_minutes'] as num?)?.toDouble() ?? 0,
      fare: (data['fare'] as num?)?.toInt() ?? 0,
      status: data['status'] ?? 'searching',
      paymentMethod: data['payment_method'] ?? 'cash',
      zoneId: data['zone_id'] ?? '',
      createdAt: _date(data['created_at']),
      items: (data['items'] as List? ?? []).map((e) => _map(e)).toList(),
      meta: _map(data['meta']),
      rejectedDriverIds: List<String>.from(data['rejected_driver_ids'] ?? []),
    );
  }
}

class Product {
  const Product({
    required this.id,
    required this.merchantId,
    required this.merchantName,
    required this.name,
    required this.description,
    required this.category,
    required this.price,
    required this.stock,
    required this.imageUrl,
    required this.isActive,
    this.discountPercent = 0,
  });

  final String id;
  final String merchantId;
  final String merchantName;
  final String name;
  final String description;
  final String category;
  final int price;
  final int stock;
  final String imageUrl;
  final bool isActive;
  final int discountPercent;

  bool get hasDiscount => discountPercent > 0 && discountPercent <= 100;

  int get discountedPrice =>
      hasDiscount ? (price * (100 - discountPercent) / 100).round() : price;

  factory Product.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final rawDiscount = (data['discount_percent'] as num?)?.toInt() ?? 0;
    return Product(
      id: doc.id,
      merchantId: data['merchant_id'] ?? '',
      merchantName: data['merchant_name'] ?? '',
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      category: data['category'] ?? 'Lainnya',
      price: (data['price'] as num?)?.toInt() ?? 0,
      stock: (data['stock'] as num?)?.toInt() ?? 0,
      imageUrl: data['image_url'] ?? '',
      isActive: data['is_active'] ?? true,
      discountPercent: rawDiscount.clamp(0, 100),
    );
  }
}

class ServiceListing {
  const ServiceListing({
    required this.id,
    required this.partnerId,
    required this.partnerName,
    required this.name,
    required this.description,
    required this.category,
    required this.estimatedPrice,
    required this.imageUrl,
    required this.zoneId,
  });
  final String id;
  final String partnerId;
  final String partnerName;
  final String name;
  final String description;
  final String category;
  final int estimatedPrice;
  final String imageUrl;
  final String zoneId;

  factory ServiceListing.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return ServiceListing(
      id: doc.id,
      partnerId: data['partner_id'] ?? '',
      partnerName: data['partner_name'] ?? '',
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      category: data['category'] ?? 'Lainnya',
      estimatedPrice: (data['estimated_price'] as num?)?.toInt() ?? 0,
      imageUrl: data['image_url'] ?? '',
      zoneId: data['zone_id'] ?? '',
    );
  }
}

class ContentItem {
  const ContentItem({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.summary,
    required this.imageUrl,
    required this.category,
    required this.publishedAt,
  });
  final String id;
  final String type;
  final String title;
  final String body;
  final String summary;
  final String imageUrl;
  final String category;
  final DateTime publishedAt;

  factory ContentItem.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return ContentItem(
      id: doc.id,
      type: data['type'] ?? 'news',
      title: data['title'] ?? '',
      body: data['body'] ?? '',
      summary: data['summary'] ?? '',
      imageUrl: data['image_url'] ?? '',
      category: data['category'] ?? 'lainnya',
      publishedAt: _date(data['published_at']),
    );
  }
}

class EmergencyContact {
  const EmergencyContact({
    required this.id,
    required this.category,
    required this.name,
    required this.phone,
  });
  final String id;
  final String category;
  final String name;
  final String phone;

  factory EmergencyContact.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return EmergencyContact(
      id: doc.id,
      category: data['category'] ?? 'sakit',
      name: data['name'] ?? '',
      phone: data['phone'] ?? '',
    );
  }
}

class AppZone {
  const AppZone({required this.id, required this.name, required this.isActive});
  final String id;
  final String name;
  final bool isActive;
  factory AppZone.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return AppZone(
      id: doc.id,
      name: data['name'] ?? doc.id,
      isActive: data['is_active'] ?? true,
    );
  }
}

class PricingConfig {
  const PricingConfig({
    this.firstTwoKmFare = 10000,
    this.additionalPerKm = 5000,
    this.qrisImageUrl = '',
  });
  final int firstTwoKmFare;
  final int additionalPerKm;
  final String qrisImageUrl;
  factory PricingConfig.fromMap(Map<String, dynamic>? data) => PricingConfig(
    firstTwoKmFare: (data?['first_two_km_fare'] as num?)?.toInt() ?? 10000,
    additionalPerKm: (data?['additional_per_km'] as num?)?.toInt() ?? 5000,
    qrisImageUrl: data?['qris_image_url'] ?? '',
  );
}

class InboxMessage {
  const InboxMessage({
    required this.id,
    required this.orderId,
    required this.title,
    required this.message,
    required this.isRead,
    required this.createdAt,
  });
  final String id;
  final String orderId;
  final String title;
  final String message;
  final bool isRead;
  final DateTime createdAt;
  factory InboxMessage.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return InboxMessage(
      id: doc.id,
      orderId: data['order_id'] ?? '',
      title: data['title'] ?? 'GoBran',
      message: data['message'] ?? '',
      isRead: data['is_read'] ?? false,
      createdAt: _date(data['created_at']),
    );
  }
}
