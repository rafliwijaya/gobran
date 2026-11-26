import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/app_theme.dart';
import '../../core/common_widgets.dart';
import '../../core/formatters.dart';
import '../../models/app_models.dart';
import '../../services/firestore_service.dart';
import '../../services/location_service.dart';

// ─── Warna ───────────────────────────────────────────────────────
const _kGreen = AppColors.primaryDark;
const _kGreenLight = AppColors.primaryLight;
const _kRed = Color(0xFFD92D20);
const _kRedLight = Color(0xFFFFF1F2);
const _kOrange = Color(0xFFE67E00);

class OrderDetailScreen extends StatelessWidget {
  const OrderDetailScreen({required this.orderId, super.key});
  final String orderId;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(
      title: const Text('Detail Pesanan'),
      backgroundColor: AppColors.primary,
      foregroundColor: AppColors.ink,
      elevation: 0,
    ),
    body: StreamBuilder<AppOrder?>(
      stream: FirestoreService().watchOrder(orderId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('${snapshot.error}'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final order = snapshot.data;
        if (order == null) {
          return const Center(child: Text('Order tidak ditemukan.'));
        }
        return _OrderDetailBody(order: order);
      },
    ),
  );
}

class _OrderDetailBody extends StatelessWidget {
  const _OrderDetailBody({required this.order});
  final AppOrder order;

  bool get hasCoordinates =>
      order.pickup.latitude != 0 && order.destination.latitude != 0;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.only(bottom: 32 + bottomSystemInset(context)),
      children: [
        // ── Status Banner ─────────────────────────────────────────
        _StatusBanner(
          status: order.status,
          serviceType: order.serviceType,
          handedOver: order.meta['merchant_stage'] == 'handed_over',
          rejectionCount: order.rejectedDriverIds.length,
        ),

        // ── Map ───────────────────────────────────────────────────
        if (hasCoordinates)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                height: 200,
                child: FutureBuilder<MapRoute>(
                  future: LocationService().route(
                    order.pickup.latLng,
                    order.destination.latLng,
                  ),
                  builder: (context, snapshot) => FlutterMap(
                    options: MapOptions(
                      initialCenter: order.pickup.latLng,
                      initialZoom: 13.5,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'id.gobran.app',
                      ),
                      if (snapshot.hasData)
                        PolylineLayer(
                          polylines: [
                            Polyline(
                              points: snapshot.data!.points,
                              color: _kGreen,
                              strokeWidth: 5,
                            ),
                          ],
                        ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: order.pickup.latLng,
                            width: 42,
                            height: 42,
                            child: const Icon(
                              Icons.person_pin_circle,
                              size: 40,
                              color: _kGreen,
                            ),
                          ),
                          Marker(
                            point: order.destination.latLng,
                            width: 42,
                            height: 42,
                            child: const Icon(
                              Icons.location_on,
                              size: 40,
                              color: _kRed,
                            ),
                          ),
                        ],
                      ),
                      RichAttributionWidget(
                        attributions: [
                          TextSourceAttribution('OpenStreetMap contributors'),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 4),

              // ── Info order ─────────────────────────────────────
              _InfoCard(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _serviceLabel(order.serviceType),
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    shortDate(order.createdAt),
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // ── Lokasi ─────────────────────────────────────────
              _InfoCard(
                children: [
                  if (order.pickup.address.isNotEmpty)
                    _PointInfo(
                      icon: Icons.trip_origin,
                      color: _kGreen,
                      title: 'Titik Penjemputan',
                      point: order.pickup,
                    ),
                  if (order.pickup.address.isNotEmpty &&
                      order.destination.address.isNotEmpty)
                    const Divider(height: 1),
                  if (order.destination.address.isNotEmpty)
                    _PointInfo(
                      icon: Icons.location_on,
                      color: _kRed,
                      title: 'Tujuan',
                      point: order.destination,
                    ),
                ],
              ),
              const SizedBox(height: 12),

              // ── Items (food) ───────────────────────────────────
              if (order.serviceType == 'food' && order.items.isNotEmpty) ...[
                _InfoCard(
                  children: [
                    const Text(
                      'Pesanan',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 8),
                    ...order.items.map(
                      (item) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(
                          children: [
                            Expanded(child: Text(item['name'] ?? '')),
                            Text(
                              '${item['quantity'] ?? 1} × ${rupiah((item['price'] as num?) ?? 0)}',
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],

              // ── Tarif ──────────────────────────────────────────
              _InfoCard(
                children: [
                  if (order.serviceType == 'food' &&
                      order.meta['food_subtotal'] != null) ...[
                    _row(
                      'Subtotal Makanan',
                      rupiah((order.meta['food_subtotal'] as num?) ?? 0),
                    ),
                    _row(
                      'Ongkos Kirim',
                      rupiah((order.meta['delivery_fare'] as num?) ?? 0),
                    ),
                    const Divider(),
                  ],
                  _row('Total', rupiah(order.fare), bold: true),
                  _row(
                    'Pembayaran',
                    order.paymentMethod == 'qris' ? 'QRIS manual' : 'Tunai',
                  ),
                  if (order.distanceKm > 0)
                    _row('Jarak', '${order.distanceKm.toStringAsFixed(1)} km'),
                ],
              ),
              const SizedBox.shrink(), // Remove StatusPill from here
              // ── QRIS ───────────────────────────────────────────
              if (order.paymentMethod == 'qris') ...[
                StreamBuilder<PricingConfig>(
                  stream: FirestoreService().watchPricing(),
                  builder: (context, snap) {
                    final url = snap.data?.qrisImageUrl ?? '';
                    return _InfoCard(
                      color: const Color(0xFFFFFAE8),
                      children: [
                        const Text(
                          'Bayar melalui QRIS manual lalu simpan bukti pembayaran.',
                          textAlign: TextAlign.center,
                        ),
                        if (url.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          NetworkImageBox(url: url, height: 240),
                        ],
                      ],
                    );
                  },
                ),
                const SizedBox(height: 12),
              ],

              // ── Buka Maps ──────────────────────────────────────
              if (hasCoordinates) ...[
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  onPressed: () => LocationService().openGoogleMaps(
                    order.destination,
                    origin: order.pickup,
                  ),
                  icon: const Icon(Icons.map_outlined),
                  label: const Text('Buka rute di Google Maps'),
                ),
                const SizedBox(height: 16),
              ],

              // ═══════════════════════════════════════════════════
              // ── STATUS-SPECIFIC ACTIONS ────────────────────────
              // ═══════════════════════════════════════════════════

              // ── 1. Menunggu konfirmasi PELANGGAN ───────────────
              if (order.status == 'pending_confirmation' &&
                  order.driverId.isNotEmpty) ...[
                _DriverConfirmCard(order: order),
                const SizedBox(height: 12),
              ],

              // ── 2. Driver sudah dikonfirmasi ───────────────────
              if (order.status == 'driver_confirmed' &&
                  order.driverName.isNotEmpty) ...[
                _ConfirmedDriverCard(order: order),
                const SizedBox(height: 12),
              ],

              // ── 3. Driver sedang dalam perjalanan/proses ───────
              if ([
                    'heading_to_pickup',
                    'at_pickup',
                    'on_delivery',
                  ].contains(order.status) &&
                  order.driverName.isNotEmpty) ...[
                _ActiveDriverCard(order: order),
                const SizedBox(height: 12),
              ],

              // ── Pembatalan: hanya di status tertentu ───────────
              if (order.customerCanCancel) ...[
                _CancelButton(order: order),
              ] else if (order.serviceType == 'food' &&
                  !['completed', 'cancelled'].contains(order.status)) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.lock_outline, size: 18, color: Colors.grey),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Pesanan sudah diterima UMKM dan tidak dapat dibatalkan oleh pelanggan.',
                          style: TextStyle(fontSize: 12.5, color: Colors.grey),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _row(String label, String value, {bool bold = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      children: [
        Expanded(child: Text(label)),
        Text(
          value,
          style: TextStyle(
            fontWeight: bold ? FontWeight.w900 : FontWeight.w600,
            fontSize: bold ? 17 : 14,
          ),
        ),
      ],
    ),
  );

  String _serviceLabel(String type) => switch (type) {
    'ojek' => 'Order Ojek',
    'express' => 'Order Express',
    'food' => 'Order Makanan',
    'service' => 'Permintaan Jasa',
    _ => 'Order',
  };
}

// ─── Status Banner ────────────────────────────────────────────────
class _StatusBanner extends StatelessWidget {
  const _StatusBanner({
    required this.status,
    required this.serviceType,
    required this.rejectionCount,
    this.handedOver = false,
  });
  final String status;
  final String serviceType;
  final int rejectionCount;
  final bool handedOver;

  @override
  Widget build(BuildContext context) {
    final cfg = _config();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      decoration: BoxDecoration(
        color: cfg.$3,
        border: Border(
          bottom: BorderSide(color: cfg.$1.withValues(alpha: 0.3)),
        ),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(cfg.$4, color: cfg.$1, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  cfg.$2,
                  softWrap: true,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: cfg.$1,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          if (status == 'pending_confirmation' && rejectionCount > 0) ...[
            const SizedBox(height: 6),
            Text(
              'Anda sudah menolak $rejectionCount driver (maks. 3×)',
              style: TextStyle(
                color: cfg.$1.withValues(alpha: 0.8),
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // (color, label, bgColor, icon)
  (Color, String, Color, IconData) _config() {
    final isFood = serviceType == 'food';
    return switch (status) {
      'searching' => (
        _kGreen,
        isFood
            ? 'Pesanan Diterima UMKM • Mencari Driver...'
            : 'Mencari Driver...',
        _kGreenLight,
        Icons.search,
      ),
      'waiting_partner' => (
        _kOrange,
        'Menunggu Konfirmasi Mitra Jasa',
        const Color(0xFFFFF7ED),
        Icons.hourglass_top_outlined,
      ),
      'waiting_merchant' => (
        _kOrange,
        'Menunggu Konfirmasi UMKM',
        const Color(0xFFFFF7ED),
        Icons.hourglass_top_outlined,
      ),
      'preparing' => (
        _kOrange,
        'Pesanan Sedang Disiapkan UMKM',
        const Color(0xFFFFF7ED),
        Icons.soup_kitchen_outlined,
      ),
      'ready' => (
        _kGreen,
        'Pesanan Sudah Siap',
        _kGreenLight,
        Icons.inventory_2_outlined,
      ),
      'accepted' => (
        _kGreen,
        'Pesanan Diterima Mitra',
        _kGreenLight,
        Icons.check_circle_outline,
      ),
      'pending_confirmation' => (
        _kOrange,
        'Menunggu Konfirmasi Pelanggan',
        const Color(0xFFFFF7ED),
        Icons.pending_outlined,
      ),
      'driver_confirmed' => (
        _kGreen,
        isFood ? 'Driver Ditemukan • Bersiap ke UMKM' : 'Driver Dikonfirmasi',
        _kGreenLight,
        Icons.check_circle_outline,
      ),
      'heading_to_pickup' => (
        _kGreen,
        isFood
            ? 'Driver Sedang Menuju ke UMKM'
            : 'Driver Menuju Lokasi Anda',
        _kGreenLight,
        Icons.navigation_outlined,
      ),
      'at_pickup' => (
        _kGreen,
        isFood
            ? (handedOver
                  ? 'Driver di UMKM • Pesanan Sudah Diserahkan'
                  : 'Driver Sudah Sampai di UMKM')
            : 'Driver Sudah di Lokasi Anda',
        _kGreenLight,
        Icons.location_on_outlined,
      ),
      'on_delivery' => (
        const Color(0xFF2563EB),
        isFood
            ? 'Driver Menuju Lokasi Pelanggan'
            : 'Perjalanan ke Tujuan',
        const Color(0xFFEFF6FF),
        Icons.directions_car_outlined,
      ),
      'completed' => (_kGreen, 'Order Selesai', _kGreenLight, Icons.check_circle),
      'cancelled' => (
        _kRed,
        'Order Dibatalkan',
        _kRedLight,
        Icons.cancel_outlined,
      ),
      _ => (Colors.grey, status, Colors.grey.shade100, Icons.info_outline),
    };
  }
}

// ─── Card konfirmasi driver (status: pending_confirmation) ────────
class _DriverConfirmCard extends StatelessWidget {
  const _DriverConfirmCard({required this.order});
  final AppOrder order;

  @override
  Widget build(BuildContext context) {
    final rejectionCount = order.rejectedDriverIds.length;
    final remaining = 3 - rejectionCount;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kOrange.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(
            color: _kOrange.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profil driver
            StreamBuilder<Map<String, dynamic>>(
              stream: FirestoreService()
                  .watchDriverPublicProfile(order.driverId)
                  .map((s) => s.data() ?? {}),
              builder: (context, snap) {
                final data = snap.data ?? {};
                return _DriverProfileDetail(name: order.driverName, data: data);
              },
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                children: [
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Driver menunggu konfirmasi Anda',
                      style: TextStyle(
                        color: _kOrange,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 10),
            if (remaining > 1)
              Text(
                '⚠️ Anda dapat menolak $remaining driver lagi sebelum order otomatis dibatalkan.',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                textAlign: TextAlign.center,
              )
            else if (remaining == 1)
              const Text(
                '⚠️ Ini adalah kesempatan terakhir! Menolak driver ini akan membatalkan order Anda.',
                style: TextStyle(
                  color: _kRed,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 46,
                    child: OutlinedButton.icon(
                      onPressed: () => _showRejectDialog(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _kRed,
                        side: const BorderSide(color: _kRed),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.search, size: 16),
                      label: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'Cari Driver Lagi',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SizedBox(
                    height: 46,
                    child: ElevatedButton.icon(
                      onPressed: () => _confirm(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _kGreen,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.check_circle_outline, size: 16),
                      label: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'Terima Driver',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirm(BuildContext context) async {
    await FirestoreService().confirmDriver(order);
  }

  Future<void> _showRejectDialog(BuildContext context) async {
    await FirestoreService().rejectDriver(order);
  }
}

// ─── Detail profil driver (lengkap) ──────────────────────────────
class _DriverProfileDetail extends StatelessWidget {
  const _DriverProfileDetail({required this.name, required this.data});
  final String name;
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Builder(
        builder: (context) {
          final faceImage = appImageProvider(
            (data['face_url'] ?? '').toString(),
          );
          return CircleAvatar(
            radius: 32,
            backgroundColor: _kGreenLight,
            backgroundImage: faceImage,
            child: faceImage == null
                ? const Icon(Icons.person, size: 28, color: _kGreen)
                : null,
          );
        },
      ),
      const SizedBox(width: 14),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              name,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            if ((data['vehicle_type'] ?? '').toString().isNotEmpty)
              _DetailRow(
                Symbols.moped_rounded,
                '${data['vehicle_type']} ${data['vehicle_brand'] ?? ''}'.trim(),
              ),
            if ((data['plate_number'] ?? '').toString().isNotEmpty)
              _DetailRow(Icons.credit_card, 'Plat: ${data['plate_number']}'),
            if ((data['vehicle_color'] ?? '').toString().isNotEmpty)
              _DetailRow(
                Icons.palette_outlined,
                'Warna: ${data['vehicle_color']}',
              ),
          ],
        ),
      ),
    ],
  );
}

class _DetailRow extends StatelessWidget {
  const _DetailRow(this.icon, this.text);
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 4),
    child: Row(
      children: [
        Icon(icon, size: 14, color: Colors.grey.shade600),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
          ),
        ),
      ],
    ),
  );
}

// ─── Card driver sudah dikonfirmasi ───────────────────────────────
class _ConfirmedDriverCard extends StatelessWidget {
  const _ConfirmedDriverCard({required this.order});
  final AppOrder order;

  @override
  Widget build(BuildContext context) => _InfoCard(
    color: _kGreenLight,
    children: [
      Row(
        children: [
          const Icon(Icons.check_circle, color: _kGreen, size: 18),
          const SizedBox(width: 8),
          const Text(
            'Driver Dikonfirmasi',
            style: TextStyle(fontWeight: FontWeight.w800, color: _kGreen),
          ),
        ],
      ),
      const SizedBox(height: 10),
      StreamBuilder<Map<String, dynamic>>(
        stream: FirestoreService()
            .watchDriverPublicProfile(order.driverId)
            .map((s) => s.data() ?? {}),
        builder: (context, snap) =>
            _DriverProfileDetail(name: order.driverName, data: snap.data ?? {}),
      ),
      const SizedBox(height: 8),
      Text(
        'Driver akan menuju lokasi Anda. Harap bersiap!',
        style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
        textAlign: TextAlign.center,
      ),
    ],
  );
}

// ─── Card driver sedang aktif (heading/at_pickup/on_delivery) ─────
class _ActiveDriverCard extends StatelessWidget {
  const _ActiveDriverCard({required this.order});
  final AppOrder order;

  @override
  Widget build(BuildContext context) => _InfoCard(
    color: _kGreenLight,
    children: [
      StreamBuilder<Map<String, dynamic>>(
        stream: FirestoreService()
            .watchDriverPublicProfile(order.driverId)
            .map((s) => s.data() ?? {}),
        builder: (context, snap) =>
            _DriverProfileDetail(name: order.driverName, data: snap.data ?? {}),
      ),
    ],
  );
}

// ─── Tombol batalkan ──────────────────────────────────────────────
class _CancelButton extends StatelessWidget {
  const _CancelButton({required this.order});
  final AppOrder order;

  @override
  Widget build(BuildContext context) => TextButton.icon(
    onPressed: () => _cancel(context),
    style: TextButton.styleFrom(foregroundColor: _kRed),
    icon: const Icon(Icons.cancel_outlined),
    label: const Text('Batalkan Order'),
  );

  Future<void> _cancel(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Batalkan Order?'),
        content: const Text(
          'Order akan dibatalkan dan tidak dapat dikembalikan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Tidak'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _kRed,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Batalkan'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await FirestoreService().updateOrderStatus(order, 'cancelled');
    }
  }
}

// ─── Shared widgets ───────────────────────────────────────────────
class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.children, this.color});
  final List<Widget> children;
  final Color? color;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: color ?? Colors.white,
      borderRadius: BorderRadius.circular(14),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    ),
  );
}

class _PointInfo extends StatelessWidget {
  const _PointInfo({
    required this.icon,
    required this.color,
    required this.title,
    required this.point,
  });
  final IconData icon;
  final Color color;
  final String title;
  final AddressPoint point;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              Text(
                '${point.address}${point.note.isEmpty ? '' : '\nCatatan: ${point.note}'}',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
