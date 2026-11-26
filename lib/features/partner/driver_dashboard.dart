import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/app_theme.dart';
import '../../core/common_widgets.dart';
import '../../core/formatters.dart';
import '../../models/app_models.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../services/location_service.dart';

// ─── Warna tema driver ───────────────────────────────────────────
const _kGreen = AppColors.primaryDark;
const _kGreenLight = AppColors.primaryLight;
const _kRed = Color(0xFFD92D20);
const _kBg = AppColors.background;

// ─── Shell dengan bottom navbar ──────────────────────────────────
class DriverDashboard extends StatefulWidget {
  const DriverDashboard({required this.user, super.key});
  final AppUser user;
  @override
  State<DriverDashboard> createState() => _DriverDashboardState();
}

class _DriverDashboardState extends State<DriverDashboard> {
  int _navIndex = 0;
  bool _active = false;
  bool _profileLoaded = false;
  StreamSubscription<LatLng>? _locationSubscription;

  @override
  void dispose() {
    _locationSubscription?.cancel();
    super.dispose();
  }

  Future<void> _toggle(bool value) async {
    try {
      LatLng? point;
      if (value) point = await LocationService().currentLocation();
      await FirestoreService().setDriverActive(value, point);
      await _locationSubscription?.cancel();
      if (value) {
        _locationSubscription = LocationService().locationStream().listen(
          FirestoreService().updateDriverLocation,
        );
      }
      if (mounted) setState(() => _active = value);
    } catch (e) {
      if (mounted) showMessage(context, '$e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirestoreService().watchDriverProfile(),
      builder: (context, profileSnapshot) {
        if (profileSnapshot.hasData && !_profileLoaded) {
          _profileLoaded = true;
          _active = profileSnapshot.data!.data()?['is_active'] ?? false;
          if (_active) {
            WidgetsBinding.instance.addPostFrameCallback((_) => _toggle(true));
          }
        }

        final pages = [
          _HomeTab(user: widget.user, active: _active, onToggle: _toggle),
          _HistoryTab(),
          _RekapTab(),
          _AccountTab(user: widget.user),
        ];

        return Scaffold(
          backgroundColor: _kBg,
          body: IndexedStack(index: _navIndex, children: pages),
          bottomNavigationBar: _DriverNavBar(
            index: _navIndex,
            onTap: (i) => setState(() => _navIndex = i),
          ),
        );
      },
    );
  }
}

// ─── Bottom Navbar ────────────────────────────────────────────────
class _DriverNavBar extends StatelessWidget {
  const _DriverNavBar({required this.index, required this.onTap});
  final int index;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              _NavItem(
                icon: Symbols.home_rounded,
                activeIcon: Symbols.home_rounded,
                label: 'Beranda',
                selected: index == 0,
                onTap: () => onTap(0),
              ),
              _NavItem(
                icon: Symbols.receipt_long_rounded,
                activeIcon: Symbols.receipt_long_rounded,
                label: 'Riwayat',
                selected: index == 1,
                onTap: () => onTap(1),
              ),
              _NavItem(
                icon: Symbols.bar_chart_rounded,
                activeIcon: Symbols.bar_chart_rounded,
                label: 'Rekap',
                selected: index == 2,
                onTap: () => onTap(2),
              ),
              _NavItem(
                icon: Symbols.person_rounded,
                activeIcon: Symbols.person_rounded,
                label: 'Akun',
                selected: index == 3,
                onTap: () => onTap(3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              selected ? activeIcon : icon,
              fill: selected ? 1 : 0,
              color: selected ? _kGreen : Colors.grey,
              size: 24,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
                color: selected ? _kGreen : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Tab Beranda ──────────────────────────────────────────────────
class _HomeTab extends StatelessWidget {
  const _HomeTab({
    required this.user,
    required this.active,
    required this.onToggle,
  });
  final AppUser user;
  final bool active;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header gradient
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [_kGreen, Color(0xFF005F09)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: Colors.white.withValues(alpha: 0.2),
                        child: const Icon(
                          Symbols.moped_rounded,
                          fill: 1,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'GoBran Driver',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              user.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: active
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          active ? '🟢 Online' : '🔴 Offline',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: active ? _kGreen : Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  // Toggle card — berbeda visual antara ON dan OFF
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: active
                          ? Colors.white.withValues(alpha: 0.22)
                          : Colors.black.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: active
                            ? Colors.white.withValues(alpha: 0.7)
                            : Colors.white.withValues(alpha: 0.25),
                        width: active ? 1.5 : 1.0,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          active
                              ? Icons.wifi_tethering
                              : Icons.wifi_tethering_off,
                          color: active ? Colors.white : Colors.white60,
                          size: 26,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                active ? 'Siap menerima order' : 'Tidak aktif',
                                style: TextStyle(
                                  color: active ? Colors.white : Colors.white70,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              Text(
                                active
                                    ? 'Order dari zona ${user.zoneId} akan masuk'
                                    : 'Aktifkan untuk mulai menerima order',
                                style: TextStyle(
                                  color: active
                                      ? Colors.white.withValues(alpha: 0.8)
                                      : Colors.white54,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: active,
                          onChanged: onToggle,
                          activeThumbColor: Colors.white,
                          activeTrackColor: _kGreen.withValues(alpha: 0.6),
                          inactiveThumbColor: Colors.white70,
                          inactiveTrackColor: Colors.white24,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: active
              ? StreamBuilder<AppOrder?>(
                  stream: FirestoreService().watchMyCurrentDriverOrder(),
                  builder: (context, activeSnap) {
                    final activeOrder = activeSnap.data;
                    if (activeOrder != null) {
                      return _ActiveOrderBanner(order: activeOrder, user: user);
                    }
                    return _OpenOrders(user: user);
                  },
                )
              : _OfflineEmptyState(),
        ),
      ],
    );
  }
}

// ─── Banner ketika driver punya order aktif/pending ─────────────
class _ActiveOrderBanner extends StatelessWidget {
  const _ActiveOrderBanner({required this.order, required this.user});
  final AppOrder order;
  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final isPending = order.status == 'pending_confirmation';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isPending) ...[
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7ED),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFE67E00), width: 2),
                ),
                child: const Center(
                  child: SizedBox(
                    width: 36,
                    height: 36,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: Color(0xFFE67E00),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Menunggu Konfirmasi Pelanggan',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFFE67E00),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Pelanggan sedang mempertimbangkan Anda sebagai driver.\nHarap tunggu sebentar...',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ] else ...[
              Container(
                width: 80,
                height: 80,
                decoration: const BoxDecoration(
                  color: _kGreenLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle, color: _kGreen, size: 44),
              ),
              const SizedBox(height: 18),
              const Text(
                'Order Aktif',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: _kGreen,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Anda sedang dalam proses pengantaran.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ],
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => DriverOrderDetailScreen(orderId: order.id),
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: isPending ? const Color(0xFFE67E00) : _kGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              icon: Icon(
                isPending
                    ? Icons.pending_outlined
                    : Icons.receipt_long_outlined,
              ),
              label: Text(
                isPending ? 'Lihat Status Order' : 'Lanjutkan Order',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Empty state saat offline ─────────────────────────────────────
class _OfflineEmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Symbols.moped_rounded,
                fill: 1,
                size: 52,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Anda Sedang Offline',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Aktifkan toggle di atas untuk mulai menerima order masuk dari pelanggan.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade500),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Daftar order masuk ───────────────────────────────────────────
class _OpenOrders extends StatelessWidget {
  const _OpenOrders({required this.user});
  final AppUser user;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirestoreService().watchDriverProfile(),
      builder: (context, profileSnapshot) {
        final currentOrderId =
            profileSnapshot.data?.data()?['current_order_id']?.toString() ?? '';
        if (currentOrderId.isNotEmpty) {
          return StreamBuilder<AppOrder?>(
            stream: FirestoreService().watchOrder(currentOrderId),
            builder: (context, orderSnapshot) {
              final order = orderSnapshot.data;
              final isActive =
                  order != null &&
                  const [
                    'pending_confirmation',
                    'accepted',
                    'driver_confirmed',
                    'heading_to_pickup',
                    'at_pickup',
                    'picked_up',
                    'on_delivery',
                  ].contains(order.status);
              return isActive
                  ? _ActiveOrderOnly(orderId: currentOrderId)
                  : _OpenOrdersList(user: user);
            },
          );
        }
        return _OpenOrdersList(user: user);
      },
    );
  }
}

class _OpenOrdersList extends StatelessWidget {
  const _OpenOrdersList({required this.user});
  final AppUser user;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AppOrder>>(
      stream: FirestoreService().watchOpenDriverOrders(user.zoneId),
      builder: (context, snapshot) => AsyncView<List<AppOrder>>(
        snapshot: snapshot,
        isEmpty: (items) => items.isEmpty,
        emptyMessage: 'Belum ada order masuk di zona ini.\nTunggu sebentar...',
        builder: (items) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
              child: Row(
                children: [
                  const Icon(
                    Icons.local_fire_department,
                    color: _kRed,
                    size: 20,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${items.length} Order Masuk',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: EdgeInsets.fromLTRB(
                  16,
                  4,
                  16,
                  24 + bottomSystemInset(context),
                ),
                itemCount: items.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 12),
                itemBuilder: (context, index) =>
                    _OrderCard(order: items[index], user: user),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActiveOrderOnly extends StatelessWidget {
  const _ActiveOrderOnly({required this.orderId});
  final String orderId;

  @override
  Widget build(BuildContext context) => StreamBuilder<AppOrder?>(
    stream: FirestoreService().watchOrder(orderId),
    builder: (context, snapshot) {
      final order = snapshot.data;
      if (order == null) {
        return const Center(child: CircularProgressIndicator());
      }
      return Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Order Aktif',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
            ),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: const Icon(
                  Symbols.moped_rounded,
                  fill: 1,
                  color: _kGreen,
                ),
                title: Text(
                  order.destination.address,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text('Status: ${order.status}'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => DriverOrderDetailScreen(orderId: order.id),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Selesaikan order ini terlebih dahulu untuk melihat order masuk lain.',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    },
  );
}

// ─── Kartu order masuk ────────────────────────────────────────────
class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order, required this.user});
  final AppOrder order;
  final AppUser user;

  IconData get _serviceIcon => switch (order.serviceType) {
    'food' => Symbols.restaurant_rounded,
    'ojek' => Symbols.moped_rounded,
    _ => Symbols.local_shipping_rounded,
  };

  Color get _serviceColor => switch (order.serviceType) {
    'food' => const Color(0xFFE67E00),
    'ojek' => _kGreen,
    _ => const Color(0xFF2563EB),
  };

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: _serviceColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(_serviceIcon, color: _serviceColor, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'GO${order.serviceType.toUpperCase()}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        '${order.distanceKm.toStringAsFixed(1)} km • ±${order.durationMinutes.ceil()} menit',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      rupiah(order.fare),
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        color: _kGreen,
                      ),
                    ),
                    Text(
                      order.paymentMethod == 'cash' ? '💵 Tunai' : '📱 QRIS',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            _LocationRow(
              icon: Icons.trip_origin,
              color: _kGreen,
              label: 'Jemput',
              address: order.pickup.address,
            ),
            const SizedBox(height: 8),
            _LocationRow(
              icon: Icons.location_on,
              color: _kRed,
              label: 'Tujuan',
              address: order.destination.address,
            ),
            const SizedBox(height: 14),
            // Tombol dengan ukuran sama (SizedBox + Row)
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 44,
                    child: OutlinedButton.icon(
                      onPressed: () => _showOrderDetail(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _kGreen,
                        side: const BorderSide(color: _kGreen),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: EdgeInsets.zero,
                      ),
                      icon: const Icon(Icons.info_outline, size: 16),
                      label: const Text(
                        'Lihat Detail',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SizedBox(
                    height: 44,
                    child: ElevatedButton.icon(
                      onPressed: () => _accept(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _kGreen,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: EdgeInsets.zero,
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.check_circle_outline, size: 16),
                      label: const Text(
                        'Terima Pesanan',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
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

  void _showOrderDetail(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _OrderDetailSheet(order: order, user: user),
    );
  }

  Future<void> _accept(BuildContext context) async {
    final won = await FirestoreService().acceptDriverOrder(order.id, user);
    if (!context.mounted) return;
    if (!won) {
      showMessage(
        context,
        'Order tidak tersedia atau Anda masih membawa order aktif.',
        error: true,
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DriverOrderDetailScreen(orderId: order.id),
        ),
      );
    }
  }
}

// ─── Baris lokasi ─────────────────────────────────────────────────
class _LocationRow extends StatelessWidget {
  const _LocationRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.address,
  });
  final IconData icon;
  final Color color;
  final String label;
  final String address;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade500,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                address,
                style: const TextStyle(fontSize: 13),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Bottom sheet detail order ────────────────────────────────────
class _OrderDetailSheet extends StatefulWidget {
  const _OrderDetailSheet({required this.order, required this.user});
  final AppOrder order;
  final AppUser user;

  @override
  State<_OrderDetailSheet> createState() => _OrderDetailSheetState();
}

class _OrderDetailSheetState extends State<_OrderDetailSheet> {
  LatLng? _driverPoint;

  @override
  void initState() {
    super.initState();
    LocationService()
        .currentLocation()
        .then((p) {
          if (mounted) setState(() => _driverPoint = p);
        })
        .catchError((_) {});
  }

  Future<void> _openFullRoute() async {
    var driverPoint = _driverPoint;
    if (driverPoint == null) {
      try {
        driverPoint = await LocationService().currentLocation();
      } catch (_) {}
    }
    final origin = driverPoint == null
        ? null
        : AddressPoint(
            latitude: driverPoint.latitude,
            longitude: driverPoint.longitude,
            address: 'Posisi Driver',
          );

    await LocationService().openGoogleMaps(
      widget.order.destination,
      origin: origin,
      waypoints: [widget.order.pickup],
    );
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.80,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, controller) => ListView(
        controller: controller,
        padding: EdgeInsets.fromLTRB(
          20,
          0,
          20,
          30 + bottomSystemInset(context),
        ),
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _kGreenLight,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'GO${order.serviceType.toUpperCase()}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    color: _kGreen,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                rupiah(order.fare),
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                  color: _kGreen,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Mini map
          if (order.pickup.latitude != 0)
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                height: 160,
                child: FutureBuilder<MapRoute>(
                  future: LocationService().route(
                    order.pickup.latLng,
                    order.destination.latLng,
                  ),
                  builder: (context, routeSnapshot) => FlutterMap(
                    options: MapOptions(
                      initialCenter: order.pickup.latLng,
                      initialZoom: 13,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'id.gobran.app',
                      ),
                      if (routeSnapshot.hasData)
                        PolylineLayer(
                          polylines: [
                            Polyline(
                              points: routeSnapshot.data!.points,
                              strokeWidth: 5,
                              color: _kGreen,
                            ),
                          ],
                        ),
                      MarkerLayer(
                        markers: [
                          if (_driverPoint != null)
                            Marker(
                              point: _driverPoint!,
                              width: 38,
                              height: 38,
                              child: const Icon(
                                Symbols.moped_rounded,
                                fill: 1,
                                size: 32,
                                color: Color(0xFF2563EB),
                              ),
                            ),
                          Marker(
                            point: order.pickup.latLng,
                            width: 38,
                            height: 38,
                            child: const Icon(
                              Icons.person_pin_circle,
                              size: 36,
                              color: _kGreen,
                            ),
                          ),
                          Marker(
                            point: order.destination.latLng,
                            width: 38,
                            height: 38,
                            child: const Icon(
                              Icons.location_on,
                              size: 36,
                              color: _kRed,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          const SizedBox(height: 12),
          // Info lokasi
          _InfoCard(
            children: [
              _InfoRow(
                Symbols.moped_rounded,
                'Posisi Driver Saat Ini',
                const Color(0xFF2563EB),
                _driverPoint != null
                    ? 'Lokasi GPS terdeteksi'
                    : 'Mendeteksi lokasi...',
              ),
              const Divider(),
              _InfoRow(
                Icons.trip_origin,
                'Titik Penjemputan',
                _kGreen,
                order.pickup.address,
                note: order.pickup.note.isNotEmpty ? order.pickup.note : null,
              ),
              const Divider(),
              _InfoRow(
                Icons.location_on,
                'Titik Tujuan',
                _kRed,
                order.destination.address,
                note: order.destination.note.isNotEmpty
                    ? order.destination.note
                    : null,
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Info tarif
          _InfoCard(
            children: [
              _SummaryRow('Jarak', '${order.distanceKm.toStringAsFixed(1)} km'),
              _SummaryRow('Estimasi', '±${order.durationMinutes.ceil()} menit'),
              _SummaryRow(
                'Pembayaran',
                order.paymentMethod == 'cash' ? 'Tunai' : 'QRIS',
              ),
              const Divider(),
              _SummaryRow('Total Tarif', rupiah(order.fare), isHighlight: true),
            ],
          ),
          const SizedBox(height: 12),
          // Tombol Buka Maps (3 titik rute)
          OutlinedButton.icon(
            onPressed: _openFullRoute,
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF2563EB),
              side: const BorderSide(color: Color(0xFF2563EB)),
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.map_outlined),
            label: const Text('Rute di Google Maps'),
          ),
          const SizedBox(height: 10),
          // Tombol Terima
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(context);
              final won = await FirestoreService().acceptDriverOrder(
                order.id,
                widget.user,
              );
              if (!context.mounted) return;
              if (!won) {
                showMessage(
                  context,
                  'Order tidak tersedia atau Anda masih membawa order aktif.',
                  error: true,
                );
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => DriverOrderDetailScreen(orderId: order.id),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _kGreen,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            icon: const Icon(Icons.check_circle_outline),
            label: const Text(
              'Terima Order Ini',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              foregroundColor: _kRed,
              side: const BorderSide(color: _kRed),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Lewati',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Widgets shared ───────────────────────────────────────────────
class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      boxShadow: [
        BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8),
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

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.icon, this.label, this.color, this.address, {this.note});
  final IconData icon;
  final String label;
  final Color color;
  final String address;
  final String? note;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
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
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                address,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (note != null)
                Text(
                  'Catatan: $note',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow(this.label, this.value, {this.isHighlight = false});
  final String label;
  final String value;
  final bool isHighlight;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontWeight: isHighlight ? FontWeight.w800 : FontWeight.normal,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: isHighlight ? 16 : 14,
            color: isHighlight ? _kGreen : null,
          ),
        ),
      ],
    ),
  );
}

// ─── Tab Riwayat ──────────────────────────────────────────────────
class _HistoryTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kGreen,
        foregroundColor: Colors.white,
        centerTitle: true,
        title: const Text(
          'Riwayat',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        automaticallyImplyLeading: false,
        elevation: 0,
      ),
      body: StreamBuilder<List<AppOrder>>(
        stream: FirestoreService().watchDriverOrders(),
        builder: (context, snapshot) => AsyncView<List<AppOrder>>(
          snapshot: snapshot,
          isEmpty: (items) =>
              !items.any((order) => order.status == 'completed'),
          emptyMessage: 'Belum ada riwayat order.',
          builder: (items) => ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'Riwayat Order',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
              ),
              const SizedBox(height: 12),
              ...items
                  .where((order) => order.status == 'completed')
                  .map(
                    (order) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Card(
                        elevation: 0.5,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          leading: Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: _kGreenLight,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              order.serviceType == 'food'
                                  ? Symbols.restaurant_rounded
                                  : Symbols.moped_rounded,
                              fill: 1,
                              color: _kGreen,
                              size: 20,
                            ),
                          ),
                          title: Text(
                            'GO${order.serviceType.toUpperCase()}',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${shortDate(order.createdAt)} • ${rupiah(order.fare)}',
                              ),
                              const SizedBox(height: 3),
                              Text(
                                order.pickup.address,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            ],
                          ),
                          isThreeLine: true,
                          trailing: StatusPill(order.status),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  DriverOrderDetailScreen(orderId: order.id),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Tab Rekap ────────────────────────────────────────────────────
class _RekapTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kGreen,
        foregroundColor: Colors.white,
        centerTitle: true,
        title: const Text(
          'Rekap Pendapatan',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        automaticallyImplyLeading: false,
        elevation: 0,
      ),
      body: StreamBuilder<List<AppOrder>>(
        stream: FirestoreService().watchDriverOrders(),
        builder: (context, snapshot) => AsyncView<List<AppOrder>>(
          snapshot: snapshot,
          isEmpty: (items) => items.isEmpty,
          emptyMessage: 'Belum ada data pendapatan.',
          builder: (items) {
            final completed = items
                .where((e) => e.status == 'completed')
                .toList();
            final cancelled = items
                .where((e) => e.status == 'cancelled')
                .toList();
            final ongoing = items
                .where((e) => !['completed', 'cancelled'].contains(e.status))
                .toList();
            final totalIncome = completed.fold<int>(
              0,
              (total, e) => total + e.fare,
            );
            final netIncome = completed.fold<int>(0, (total, e) {
              if (e.serviceType == 'food') {
                return total + ((e.meta['delivery_fare'] as num?)?.toInt() ?? 0);
              }
              return total + e.fare;
            });
            final merchantPayTotal = totalIncome - netIncome;
            final cashIncome = completed
                .where((e) => e.paymentMethod == 'cash')
                .fold<int>(0, (s, e) => s + e.fare);
            final qrisIncome = completed
                .where((e) => e.paymentMethod == 'qris')
                .fold<int>(0, (s, e) => s + e.fare);

            return ListView(
              padding: EdgeInsets.fromLTRB(
                16,
                16,
                16,
                24 + bottomSystemInset(context),
              ),
              children: [
                // Kartu pendapatan bersih & total pendapatan utama
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [_kGreen, Color(0xFF4F7A0D)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.account_balance_wallet_outlined,
                            color: Colors.white70,
                            size: 18,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Pendapatan Bersih (Ongkir)',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        rupiah(netIncome),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Total Diterima (Kotor): ${rupiah(totalIncome)}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          _IncomePill(
                            Icons.check_circle_outline,
                            '${completed.length} Selesai',
                            Colors.white,
                          ),
                          const SizedBox(width: 10),
                          _IncomePill(
                            Icons.cancel_outlined,
                            '${cancelled.length} Batal',
                            Colors.white60,
                          ),
                          const SizedBox(width: 10),
                          _IncomePill(
                            Icons.pending_outlined,
                            '${ongoing.length} Aktif',
                            Colors.white70,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Breakdown pendapatan bersih & metode bayar
                _InfoCard(
                  children: [
                    const Text(
                      'Rincian Pendapatan & Pembayaran',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _RekapRow(
                      Symbols.delivery_dining_rounded,
                      'Pendapatan Bersih (Ongkir)',
                      netIncome,
                      _kGreen,
                    ),
                    const SizedBox(height: 8),
                    _RekapRow(
                      Symbols.storefront_rounded,
                      'Dibayar ke Toko UMKM',
                      merchantPayTotal,
                      const Color(0xFFE67E00),
                    ),
                    const Divider(height: 20),
                    _RekapRow(
                      Icons.payments_outlined,
                      'Total Pembayaran Tunai',
                      cashIncome,
                      const Color(0xFF16A34A),
                    ),
                    const SizedBox(height: 8),
                    _RekapRow(
                      Icons.qr_code_2,
                      'Total Pembayaran QRIS',
                      qrisIncome,
                      const Color(0xFF2563EB),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Statistik order
                _InfoCard(
                  children: [
                    const Text(
                      'Statistik Order',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _SummaryRow('Total Order', '${items.length} order'),
                    _SummaryRow('Order Selesai', '${completed.length} order'),
                    _SummaryRow(
                      'Order Dibatalkan',
                      '${cancelled.length} order',
                    ),
                    _SummaryRow('Order Aktif', '${ongoing.length} order'),
                    const Divider(),
                    _SummaryRow(
                      'Tingkat Keberhasilan',
                      items.isEmpty
                          ? '-'
                          : '${((completed.length / items.length) * 100).toStringAsFixed(0)}%',
                      isHighlight: true,
                    ),
                  ],
                ),
                if (completed.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _InfoCard(
                    children: [
                      const Text(
                        'Rata-rata per Order',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _SummaryRow(
                        'Rata-rata Tarif',
                        rupiah(totalIncome ~/ completed.length),
                        isHighlight: true,
                      ),
                      _SummaryRow(
                        'Rata-rata Jarak',
                        '${(completed.fold<double>(0, (s, e) => s + e.distanceKm) / completed.length).toStringAsFixed(1)} km',
                      ),
                    ],
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _IncomePill extends StatelessWidget {
  const _IncomePill(this.icon, this.label, this.color);
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}

class _RekapRow extends StatelessWidget {
  const _RekapRow(this.icon, this.label, this.amount, this.color);
  final IconData icon;
  final String label;
  final int amount;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 18),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
      ),
      Text(
        rupiah(amount),
        style: TextStyle(fontWeight: FontWeight.w800, color: color),
      ),
    ],
  );
}

// ─── Tab Akun ─────────────────────────────────────────────────────
class _AccountTab extends StatelessWidget {
  const _AccountTab({required this.user});
  final AppUser user;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kGreen,
        foregroundColor: Colors.white,
        centerTitle: true,
        title: const Text(
          'Akun Saya',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        automaticallyImplyLeading: false,
        elevation: 0,
      ),
      body: StreamBuilder<List<AppZone>>(
        stream: FirestoreService().watchZones(),
        builder: (context, snapshot) {
          final zones = snapshot.data ?? const <AppZone>[];
          final activeZoneName = zones
              .where((z) => z.id == user.zoneId)
              .map((z) => z.name)
              .firstOrNull ??
              user.zoneId;
          return ListView(
            padding: EdgeInsets.fromLTRB(
              20,
              20,
              20,
              24 + bottomSystemInset(context),
            ),
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 36,
                      backgroundColor: _kGreenLight,
                      child: Text(
                        user.name.isNotEmpty ? user.name[0].toUpperCase() : 'D',
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: _kGreen,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      user.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user.phone,
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _kGreenLight,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Driver · Zona $activeZoneName',
                        style: const TextStyle(
                          color: _kGreen,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _MenuTile(
                Symbols.location_on_rounded,
                'Ganti Zona ($activeZoneName)',
                () => _showZonePicker(context, zones),
              ),
              _MenuTile(Icons.help_outline, 'Bantuan & FAQ', () {}),
              _MenuTile(Icons.info_outline, 'Tentang GoBran', () {}),
              const SizedBox(height: 8),
              _MenuTile(Icons.logout, 'Keluar', () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Keluar'),
                    content: const Text('Yakin ingin keluar dari akun?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Batal'),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _kRed,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Keluar'),
                      ),
                    ],
                  ),
                );
                if (confirmed == true) await AuthService().signOut();
              }, color: _kRed),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showZonePicker(
    BuildContext context,
    List<AppZone> zones,
  ) async {
    if (zones.isEmpty) {
      showMessage(
        context,
        'Daftar zona belum tersedia. Coba beberapa saat lagi.',
        error: true,
      );
      return;
    }
    var selected = zones.any((z) => z.id == user.zoneId)
        ? user.zoneId
        : zones.first.id;
    var saving = false;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Ganti Zona Driver'),
          content: DropdownButtonFormField<String>(
            initialValue: selected,
            decoration: const InputDecoration(
              labelText: 'Pilih Zona Aktif',
              prefixIcon: Icon(Symbols.location_on_rounded),
            ),
            items: zones
                .map(
                  (z) => DropdownMenuItem(value: z.id, child: Text(z.name)),
                )
                .toList(),
            onChanged: saving
                ? null
                : (v) {
                    if (v != null) setState(() => selected = v);
                  },
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(dialogContext),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      setState(() => saving = true);
                      try {
                        await FirestoreService().updateDriverZone(selected);
                        if (dialogContext.mounted) {
                          Navigator.pop(dialogContext);
                          showMessage(
                            dialogContext,
                            'Zona driver berhasil diperbarui.',
                          );
                        }
                      } catch (e) {
                        setState(() => saving = false);
                        if (dialogContext.mounted) {
                          showMessage(dialogContext, '$e', error: true);
                        }
                      }
                    },
              child: saving
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Simpan Zona'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile(this.icon, this.label, this.onTap, {this.color});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? Colors.grey.shade800;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6),
        ],
      ),
      child: ListTile(
        leading: Icon(icon, color: c),
        title: Text(
          label,
          style: TextStyle(fontWeight: FontWeight.w600, color: c),
        ),
        trailing: Icon(
          Icons.chevron_right,
          color: Colors.grey.shade400,
          size: 20,
        ),
        onTap: onTap,
      ),
    );
  }
}

// ─── Detail screen (order sudah diterima) ────────────────────────
class DriverOrderDetailScreen extends StatefulWidget {
  const DriverOrderDetailScreen({required this.orderId, super.key});
  final String orderId;
  @override
  State<DriverOrderDetailScreen> createState() =>
      _DriverOrderDetailScreenState();
}

class _DriverOrderDetailScreenState extends State<DriverOrderDetailScreen> {
  LatLng? _driverPoint;

  // State untuk deteksi penolakan dari pelanggan
  bool _rejectionNotified = false;

  @override
  void initState() {
    super.initState();
    LocationService()
        .currentLocation()
        .then((value) {
          if (mounted) setState(() => _driverPoint = value);
        })
        .catchError((_) {});
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _kBg,
    appBar: AppBar(
      backgroundColor: _kGreen,
      foregroundColor: Colors.white,
      title: const Text(
        'Detail Order',
        style: TextStyle(fontWeight: FontWeight.w800),
      ),
      elevation: 0,
    ),
    body: StreamBuilder<AppOrder?>(
      stream: FirestoreService().watchOrder(widget.orderId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final order = snapshot.data;
        if (order == null) {
          return const Center(child: Text('Order tidak ditemukan.'));
        }

        // Deteksi: driver ini telah ditolak oleh pelanggan
        final myUid = FirestoreService().uid;
        if (!_rejectionNotified && order.rejectedDriverIds.contains(myUid)) {
          _rejectionNotified = true;
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            if (!mounted) return;
            showMessage(
              context,
              '❌ Pelanggan tidak menerima Anda. Order diteruskan ke driver lain.',
              error: true,
            );
            final nav = Navigator.of(context);
            await Future.delayed(const Duration(seconds: 3));
            if (mounted) {
              nav.pop();
            }
          });
        }
        final nextStatus = _nextStatus(order.status, order.serviceType);
        return ListView(
          padding: EdgeInsets.only(bottom: 32 + bottomSystemInset(context)),
          children: [
            if (order.pickup.latitude != 0)
              SizedBox(
                height: 280,
                child: FutureBuilder<MapRoute>(
                  future: LocationService().route(
                    order.pickup.latLng,
                    order.destination.latLng,
                  ),
                  builder: (context, routeSnapshot) => FlutterMap(
                    options: MapOptions(
                      initialCenter: order.pickup.latLng,
                      initialZoom: 13,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'id.gobran.app',
                      ),
                      if (routeSnapshot.hasData)
                        PolylineLayer(
                          polylines: [
                            Polyline(
                              points: routeSnapshot.data!.points,
                              strokeWidth: 5,
                              color: _kGreen,
                            ),
                          ],
                        ),
                      MarkerLayer(
                        markers: [
                          if (_driverPoint != null)
                            Marker(
                              point: _driverPoint!,
                              width: 42,
                              height: 42,
                              child: const Icon(
                                Symbols.moped_rounded,
                                fill: 1,
                                size: 34,
                                color: Color(0xFF2563EB),
                              ),
                            ),
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
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'GO${order.serviceType.toUpperCase()}',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      StatusPill(order.status, serviceType: order.serviceType),
                    ],
                  ),
                  if (order.serviceType == 'food') ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: order.meta['merchant_stage'] == 'handed_over'
                            ? _kGreenLight
                            : const Color(0xFFFFF7ED),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            order.meta['merchant_stage'] == 'handed_over'
                                ? Icons.inventory_2_rounded
                                : Icons.soup_kitchen_outlined,
                            size: 20,
                            color: order.meta['merchant_stage'] == 'handed_over'
                                ? _kGreen
                                : const Color(0xFFE67E00),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              order.meta['merchant_stage'] == 'handed_over'
                                  ? 'UMKM sudah menyerahkan pesanan ke driver'
                                  : 'UMKM sedang menyiapkan / menunggu serah terima pesanan',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 12.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  _InfoCard(
                    children: [
                      const Text(
                        'Profil Pelanggan',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Builder(
                            builder: (context) {
                              final customerImage = appImageProvider(
                                order.customerPhotoUrl,
                              );
                              return CircleAvatar(
                                radius: 24,
                                backgroundImage: customerImage,
                                child: customerImage == null
                                    ? const Icon(Icons.person)
                                    : null,
                              );
                            },
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  order.customerName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                  ),
                                ),
                                if (order.customerPhone.isNotEmpty)
                                  Text(
                                    order.customerPhone,
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _InfoCard(
                    children: [
                      _InfoRow(
                        Icons.trip_origin,
                        'Titik Penjemputan',
                        _kGreen,
                        order.pickup.address,
                        note: order.pickup.note.isNotEmpty
                            ? order.pickup.note
                            : null,
                      ),
                      const Divider(),
                      _InfoRow(
                        Icons.location_on,
                        'Titik Tujuan',
                        _kRed,
                        order.destination.address,
                        note: order.destination.note.isNotEmpty
                            ? order.destination.note
                            : null,
                      ),
                    ],
                  ),
                  if (order.items.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _InfoCard(
                      children: [
                        const Text(
                          'Item Order',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 8),
                        ...order.items.map(
                          (item) =>
                              Text('${item['quantity']}× ${item['name']}'),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),
                  _InfoCard(
                    children: [
                      _SummaryRow(
                        'Jarak',
                        '${order.distanceKm.toStringAsFixed(1)} km',
                      ),
                      _SummaryRow(
                        'Estimasi',
                        '±${order.durationMinutes.ceil()} menit',
                      ),
                      _SummaryRow(
                        'Pembayaran',
                        order.paymentMethod == 'cash' ? 'Tunai' : 'QRIS',
                      ),
                      const Divider(),
                      _SummaryRow(
                        'Total Tarif',
                        rupiah(order.fare),
                        isHighlight: true,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () async {
                      var driverPoint = _driverPoint;
                      if (driverPoint == null) {
                        try {
                          driverPoint = await LocationService()
                              .currentLocation();
                        } catch (_) {}
                      }
                      if (!context.mounted) return;
                      await LocationService().openGoogleMaps(
                        order.destination,
                        origin: driverPoint == null
                            ? null
                            : AddressPoint(
                                latitude: driverPoint.latitude,
                                longitude: driverPoint.longitude,
                                address: 'Posisi driver',
                              ),
                        waypoints: [order.pickup],
                      );
                    },
                    icon: const Icon(Icons.navigation_outlined),
                    label: const Text('Buka Navigasi Google Maps'),
                  ),
                  const SizedBox(height: 10),
                  if (order.status == 'pending_confirmation')
                    OutlinedButton.icon(
                      onPressed: () async {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (dialogContext) => AlertDialog(
                            title: const Text('Batalkan konfirmasi?'),
                            content: const Text(
                              'Order akan dikembalikan ke daftar order baru untuk driver lain.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () =>
                                    Navigator.pop(dialogContext, false),
                                child: const Text('Tidak'),
                              ),
                              FilledButton(
                                onPressed: () =>
                                    Navigator.pop(dialogContext, true),
                                child: const Text('Batalkan'),
                              ),
                            ],
                          ),
                        );
                        if (confirmed != true || !context.mounted) return;
                        try {
                          await FirestoreService().cancelDriverConfirmation(
                            order,
                          );
                          if (context.mounted) Navigator.pop(context);
                        } catch (error) {
                          if (context.mounted) {
                            showMessage(context, '$error', error: true);
                          }
                        }
                      },
                      icon: const Icon(Icons.undo),
                      label: const Text('Batalkan Konfirmasi'),
                    ),
                  if (order.status == 'pending_confirmation')
                    const SizedBox(height: 10),
                  if (nextStatus != null)
                    ElevatedButton(
                      onPressed: () => FirestoreService().updateOrderStatus(
                        order,
                        nextStatus.$1,
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _kGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        nextStatus.$2,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    ),
  );

  (String, String)? _nextStatus(String current, String serviceType) {
    if (serviceType == 'food') {
      return switch (current) {
        'driver_confirmed' => ('heading_to_pickup', 'Menuju ke UMKM'),
        'heading_to_pickup' => ('at_pickup', 'Sudah sampai di UMKM'),
        'at_pickup' => ('on_delivery', 'Menuju lokasi pelanggan'),
        'on_delivery' => ('completed', 'Selesai'),
        _ => null,
      };
    }
    return switch (current) {
      'driver_confirmed' => ('heading_to_pickup', 'Mulai Menuju Lokasi Jemput'),
      'heading_to_pickup' => (
        'at_pickup',
        '📍 Sudah Sampai di Titik Penjemputan',
      ),
      'at_pickup' => ('on_delivery', 'Mulai Menuju Tempat Tujuan'),
      'on_delivery' => ('completed', 'Sudah Sampai Tujuan'),
      _ => null,
    };
  }
}
