import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../core/app_theme.dart';
import '../../core/common_widgets.dart';
import '../../core/formatters.dart';
import '../../models/app_models.dart';
import '../../services/firestore_service.dart';
import '../../services/location_service.dart';
import '../order/order_detail_screen.dart';

class FoodMarketplaceScreen extends StatefulWidget {
  const FoodMarketplaceScreen({required this.user, super.key});
  final AppUser user;
  @override
  State<FoodMarketplaceScreen> createState() => _FoodMarketplaceScreenState();
}

class _FoodMarketplaceScreenState extends State<FoodMarketplaceScreen> {
  final Map<String, int> _quantities = {};
  final Map<String, Product> _selected = {};
  String _category = 'Semua';

  int get itemCount => _quantities.values.fold(0, (acc, value) => acc + value);
  int get total => _quantities.entries.fold(
    0,
    (acc, entry) =>
        acc + (_selected[entry.key]?.discountedPrice ?? 0) * entry.value,
  );

  void _add(Product product) {
    final merchantIds = _selected.values.map((e) => e.merchantId).toSet();
    if (merchantIds.isNotEmpty && !merchantIds.contains(product.merchantId)) {
      showMessage(
        context,
        'Selesaikan pesanan dari UMKM sebelumnya terlebih dahulu.',
        error: true,
      );
      return;
    }
    setState(() {
      _selected[product.id] = product;
      _quantities[product.id] = (_quantities[product.id] ?? 0) + 1;
    });
  }

  void _remove(Product product) {
    setState(() {
      final next = (_quantities[product.id] ?? 0) - 1;
      if (next <= 0) {
        _quantities.remove(product.id);
        _selected.remove(product.id);
      } else {
        _quantities[product.id] = next;
      }
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Makanan & Minuman')),
    body: StreamBuilder<List<Product>>(
      stream: FirestoreService().watchProducts(),
      builder: (context, snapshot) => AsyncView<List<Product>>(
        snapshot: snapshot,
        isEmpty: (items) => items.isEmpty,
        emptyMessage: 'Belum ada produk UMKM yang tersedia.',
        builder: (all) {
          final categories = ['Semua', ...all.map((e) => e.category).toSet()];
          if (!categories.contains(_category)) _category = 'Semua';
          final items = _category == 'Semua'
              ? all
              : all.where((e) => e.category == _category).toList();
          return Column(
            children: [
              SizedBox(
                height: 56,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  scrollDirection: Axis.horizontal,
                  itemCount: categories.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (_, i) => ChoiceChip(
                    label: Text(categories[i]),
                    selected: categories[i] == _category,
                    onSelected: (_) =>
                        setState(() => _category = categories[i]),
                  ),
                ),
              ),
              Expanded(
                child: GridView.builder(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    8,
                    16,
                    24 + bottomSystemInset(context),
                  ),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: .58,
                  ),
                  itemCount: items.length,
                  itemBuilder: (_, index) {
                    final product = items[index];
                    final quantity = _quantities[product.id] ?? 0;
                    return Card(
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Stack(
                            children: [
                              NetworkImageBox(
                                url: product.imageUrl,
                                height: 115,
                                width: double.infinity,
                              ),
                              if (product.hasDiscount)
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: ProductDiscountBadge(
                                    discountPercent: product.discountPercent,
                                  ),
                                ),
                            ],
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(11),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    product.name,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  Text(
                                    product.merchantName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.grey,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const Spacer(),
                                  ProductPriceText(
                                    originalPriceText: rupiah(product.price),
                                    finalPriceText: rupiah(
                                      product.discountedPrice,
                                    ),
                                    hasDiscount: product.hasDiscount,
                                  ),
                                  const SizedBox(height: 8),
                                  if (quantity == 0)
                                    SizedBox(
                                      width: double.infinity,
                                      child: FilledButton.tonal(
                                        onPressed: product.stock <= 0
                                            ? null
                                            : () => _add(product),
                                        child: const Text('Tambah'),
                                      ),
                                    )
                                  else
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        IconButton.filledTonal(
                                          onPressed: () => _remove(product),
                                          icon: const Icon(Icons.remove),
                                          visualDensity: VisualDensity.compact,
                                        ),
                                        Text(
                                          '$quantity',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                        IconButton.filled(
                                          onPressed: quantity >= product.stock
                                              ? null
                                              : () => _add(product),
                                          icon: const Icon(Icons.add),
                                          visualDensity: VisualDensity.compact,
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    ),
    bottomNavigationBar: itemCount == 0
        ? null
        : Container(
            padding: EdgeInsets.fromLTRB(
              16,
              12,
              16,
              16 + bottomSystemInset(context),
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Color(0x22000000), blurRadius: 12)],
            ),
            child: ElevatedButton(
              onPressed: _openMapCheckout,
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: Colors.black12,
                    child: Text(
                      '$itemCount',
                      style: const TextStyle(
                        color: AppColors.ink,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(child: Text('Lihat keranjang')),
                  Text(
                    rupiah(total),
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ],
              ),
            ),
          ),
  );

  Future<void> _openMapCheckout() async {
    final first = _selected.values.first;
    final itemsPayload = _quantities.entries.map((entry) {
      final product = _selected[entry.key]!;
      return {
        'product_id': product.id,
        'name': product.name,
        'price': product.discountedPrice,
        'original_price': product.price,
        'discount_percent': product.discountPercent,
        'quantity': entry.value,
      };
    }).toList();

    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => FoodCheckoutScreen(
          user: widget.user,
          merchantId: first.merchantId,
          merchantName: first.merchantName,
          items: itemsPayload,
          foodSubtotal: total,
        ),
      ),
    );
  }
}

/// Map-based food checkout matching the Ojek/Express flow (pin map, Google Maps
/// link, route calculation, delivery fare, and payment selection).
class FoodCheckoutScreen extends StatefulWidget {
  const FoodCheckoutScreen({
    required this.user,
    required this.merchantId,
    required this.merchantName,
    required this.items,
    required this.foodSubtotal,
    super.key,
  });

  final AppUser user;
  final String merchantId;
  final String merchantName;
  final List<Map<String, dynamic>> items;
  final int foodSubtotal;

  @override
  State<FoodCheckoutScreen> createState() => _FoodCheckoutScreenState();
}

class _FoodCheckoutScreenState extends State<FoodCheckoutScreen> {
  static const _babalan = LatLng(4.0217, 98.2810);
  final _mapController = MapController();
  final _destinationNote = TextEditingController();
  final _mapsLinkController = TextEditingController();
  final _location = LocationService();

  AddressPoint? _pickup;
  AddressPoint? _destination;
  MapRoute? _route;
  bool _merchantHasPin = false;
  bool _editingPickup = false;
  bool _loadingMerchant = true;
  bool _loadingRoute = false;
  bool _submitting = false;
  bool _showCenterPin = true;
  String _payment = 'cash';

  @override
  void initState() {
    super.initState();
    _loadMerchantLocation();
  }

  @override
  void dispose() {
    _destinationNote.dispose();
    _mapsLinkController.dispose();
    super.dispose();
  }

  Future<void> _loadMerchantLocation() async {
    try {
      final data = await FirestoreService().getMerchantPublicProfile(
        widget.merchantId,
      );
      final geo = data['location'];
      final address = (data['address'] ?? '').toString().trim();
      if (geo is GeoPoint && (geo.latitude != 0 || geo.longitude != 0)) {
        final storeLatLng = LatLng(geo.latitude, geo.longitude);
        final resolvedAddress = address.isNotEmpty
            ? address
            : await _location.reverseGeocode(storeLatLng);
        if (!mounted) return;
        setState(() {
          _merchantHasPin = true;
          _pickup = AddressPoint(
            latitude: geo.latitude,
            longitude: geo.longitude,
            address: resolvedAddress,
            note: 'Ambil pesanan di ${widget.merchantName}',
          );
          _editingPickup = false;
          _loadingMerchant = false;
        });
        _mapController.move(storeLatLng, 14.5);
        return;
      }
      if (!mounted) return;
      setState(() {
        _merchantHasPin = false;
        _editingPickup = true;
        _loadingMerchant = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _merchantHasPin = false;
          _editingPickup = true;
          _loadingMerchant = false;
        });
      }
    }
  }

  Future<void> _selectPoint(LatLng point) async {
    final address = await _location.reverseGeocode(point);
    if (!mounted) return;
    setState(() {
      if (_editingPickup) {
        _pickup = AddressPoint(
          latitude: point.latitude,
          longitude: point.longitude,
          address: address,
          note: 'Ambil pesanan di ${widget.merchantName}',
        );
        if (_destination == null) {
          _editingPickup = false;
          _showCenterPin = true;
        } else {
          _showCenterPin = false;
        }
      } else {
        _destination = AddressPoint(
          latitude: point.latitude,
          longitude: point.longitude,
          address: address,
        );
        _showCenterPin = false;
      }
    });
    await _calculateRoute();
  }

  Future<void> _useCurrentLocation() async {
    try {
      final point = await _location.currentLocation();
      _mapController.move(point, 16);
      setState(() {
        _editingPickup = false;
        _showCenterPin = true;
      });
      await _selectPoint(point);
    } catch (e) {
      if (mounted) showMessage(context, '$e', error: true);
    }
  }

  Future<void> _calculateRoute() async {
    if (_pickup == null || _destination == null) return;
    setState(() => _loadingRoute = true);
    try {
      final route = await _location.route(
        _pickup!.latLng,
        _destination!.latLng,
      );
      if (!mounted) return;
      setState(() => _route = route);
      if (route.points.isNotEmpty) {
        final middle = route.points[route.points.length ~/ 2];
        _mapController.move(middle, 13.5);
      }
    } catch (e) {
      if (mounted) showMessage(context, '$e', error: true);
    } finally {
      if (mounted) setState(() => _loadingRoute = false);
    }
  }

  Future<void> _pasteMapsLink() async {
    final clipboard = await Clipboard.getData(Clipboard.kTextPlain);
    final url = clipboard?.text?.trim() ?? '';
    if (url.isEmpty) {
      if (mounted) {
        showMessage(
          context,
          'Salin link Google Maps lokasi antar terlebih dahulu.',
          error: true,
        );
      }
      return;
    }
    _mapsLinkController.text = url;
    setState(() => _loadingRoute = true);
    try {
      final parsed = await _location.parseGoogleMapsLink(url);
      final targetPoint = parsed.destination ?? parsed.pickup;
      if (targetPoint == null) {
        throw Exception('Koordinat tujuan tidak ditemukan di link.');
      }
      final address = await _location.reverseGeocode(targetPoint);
      if (!mounted) return;
      setState(() {
        _destination = AddressPoint(
          latitude: targetPoint.latitude,
          longitude: targetPoint.longitude,
          address: address,
        );
        _editingPickup = false;
        _showCenterPin = false;
      });
      _mapController.move(targetPoint, 15);
      await _calculateRoute();
      if (mounted) {
        showMessage(context, 'Lokasi antar dari Google Maps berhasil dimuat.');
      }
    } catch (e) {
      if (mounted) showMessage(context, 'Gagal memuat link: $e', error: true);
    } finally {
      if (mounted) setState(() => _loadingRoute = false);
    }
  }

  Future<void> _submit(PricingConfig pricing) async {
    if (_pickup == null) {
      showMessage(
        context,
        'Tentukan titik lokasi UMKM di peta terlebih dahulu.',
        error: true,
      );
      return;
    }
    if (_destination == null || _route == null) {
      showMessage(
        context,
        'Tentukan titik pengantaran Anda di peta terlebih dahulu.',
        error: true,
      );
      return;
    }
    if (_destinationNote.text.trim().isEmpty) {
      showMessage(
        context,
        'Catatan detail lokasi pengantaran wajib diisi.',
        error: true,
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      final deliveryFare = FareCalculator.calculate(
        _route!.distanceKm,
        firstTwoKmFare: pricing.firstTwoKmFare,
        additionalPerKm: pricing.additionalPerKm,
      );
      final totalFare = widget.foodSubtotal + deliveryFare;
      final id = await FirestoreService().createFoodOrder(
        customer: widget.user,
        merchantId: widget.merchantId,
        merchantName: widget.merchantName,
        items: widget.items,
        foodSubtotal: widget.foodSubtotal,
        deliveryFare: deliveryFare,
        total: totalFare,
        pickup: _pickup!,
        destination: AddressPoint(
          latitude: _destination!.latitude,
          longitude: _destination!.longitude,
          address: _destination!.address,
          note: _destinationNote.text.trim(),
        ),
        route: _route,
        paymentMethod: _payment,
      );
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => OrderDetailScreen(orderId: id)),
        (route) => route.isFirst,
      );
    } catch (e) {
      if (mounted) showMessage(context, '$e', error: true);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = bottomSystemInset(context);
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 0,
        title: const Text('Checkout Makanan'),
        actions: [
          StreamBuilder<int>(
            stream: FirestoreService().watchOnlineDriverCount(),
            builder: (context, snapshot) => Container(
              margin: const EdgeInsets.only(right: 12, top: 8, bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: .52),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  const Icon(Icons.circle, color: Color(0xFF8BE28B), size: 10),
                  const SizedBox(width: 6),
                  Text(
                    '${snapshot.data ?? 0} online',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: StreamBuilder<PricingConfig>(
        stream: FirestoreService().watchPricing(),
        initialData: const PricingConfig(),
        builder: (context, pricingSnapshot) {
          final pricing = pricingSnapshot.data ?? const PricingConfig();
          final deliveryFare = _route == null
              ? 0
              : FareCalculator.calculate(
                  _route!.distanceKm,
                  firstTwoKmFare: pricing.firstTwoKmFare,
                  additionalPerKm: pricing.additionalPerKm,
                );
          final totalFare = widget.foodSubtotal + deliveryFare;

          return Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fill(
                child: Stack(
                  children: [
                    FlutterMap(
                      mapController: _mapController,
                      options: const MapOptions(
                        initialCenter: _babalan,
                        initialZoom: 14,
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'id.gobran.app',
                        ),
                        if (_route != null)
                          PolylineLayer(
                            polylines: [
                              Polyline(
                                points: _route!.points,
                                strokeWidth: 5,
                                color: const Color(0xFF087F5B),
                              ),
                            ],
                          ),
                        MarkerLayer(
                          markers: [
                            if (_pickup != null)
                              Marker(
                                point: _pickup!.latLng,
                                width: 46,
                                height: 46,
                                child: const Icon(
                                  Icons.storefront,
                                  color: Color(0xFF087F5B),
                                  size: 40,
                                  shadows: [
                                    Shadow(color: Colors.white, blurRadius: 4),
                                  ],
                                ),
                              ),
                            if (_destination != null)
                              Marker(
                                point: _destination!.latLng,
                                width: 46,
                                height: 46,
                                child: const Icon(
                                  Icons.location_on,
                                  color: Color(0xFFD92D20),
                                  size: 42,
                                  shadows: [
                                    Shadow(color: Colors.white, blurRadius: 4),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        const RichAttributionWidget(
                          attributions: [
                            TextSourceAttribution('OpenStreetMap contributors'),
                          ],
                        ),
                      ],
                    ),
                    if (_showCenterPin) ...[
                      Center(
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 38),
                          child: Icon(
                            _editingPickup
                                ? Icons.storefront
                                : Icons.location_on,
                            color: _editingPickup
                                ? const Color(0xFF087F5B)
                                : const Color(0xFFD92D20),
                            size: 48,
                            shadows: const [
                              Shadow(color: Colors.white, blurRadius: 8),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: MediaQuery.of(context).size.height * .32 + 12,
                        left: 12,
                        right: 60,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: AppColors.ink,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            elevation: 4,
                          ),
                          onPressed: () async {
                            final center = _mapController.camera.center;
                            await _selectPoint(center);
                          },
                          icon: const Icon(Icons.pin_drop_outlined, size: 16),
                          label: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              _editingPickup
                                  ? 'Gunakan titik tengah untuk Lokasi UMKM'
                                  : 'Gunakan titik tengah untuk Lokasi Antar',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                    Positioned(
                      bottom: MediaQuery.of(context).size.height * .32 + 12,
                      right: 12,
                      child: FloatingActionButton.small(
                        heroTag: 'food_current_location',
                        onPressed: _useCurrentLocation,
                        child: const Icon(Icons.my_location),
                      ),
                    ),
                    if (_loadingMerchant || _loadingRoute)
                      const Positioned.fill(
                        child: ColoredBox(
                          color: Color(0x33000000),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                      ),
                  ],
                ),
              ),
              DraggableScrollableSheet(
                initialChildSize: .32,
                minChildSize: .26,
                maxChildSize: .90,
                snap: true,
                snapSizes: const [.32, .90],
                builder: (context, scrollController) => Material(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: ListView(
                    controller: scrollController,
                    padding: EdgeInsets.fromLTRB(
                      18,
                      12,
                      18,
                      28 + bottomInset,
                    ),
                    children: [
                      Center(
                        child: Container(
                          width: 42,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade400,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (!_merchantHasPin && !_loadingMerchant) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF7ED),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFFE67E00).withValues(alpha: .4),
                            ),
                          ),
                          child: const Text(
                            'UMKM belum menyetel pin peta toko. Silakan pilih titik toko UMKM lalu titik antar Anda di peta.',
                            style: TextStyle(fontSize: 12.5),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      Card(
                        elevation: 0,
                        color: AppColors.primaryLight,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(
                            color: AppColors.primaryDark,
                            width: 0.8,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Text(
                                'Set lokasi antar via link Google Maps',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: AppColors.primaryDark,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _mapsLinkController,
                                readOnly: true,
                                showCursor: false,
                                onTap: _pasteMapsLink,
                                decoration: InputDecoration(
                                  hintText:
                                      'Ketuk untuk menempel link Google Maps...',
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  fillColor: Colors.white,
                                  filled: true,
                                  suffixIcon: IconButton(
                                    tooltip: 'Tempel link',
                                    icon: const Icon(Icons.content_paste),
                                    onPressed: _pasteMapsLink,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          if (!_merchantHasPin) ...[
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() {
                                  _editingPickup = true;
                                  _showCenterPin = true;
                                }),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _editingPickup
                                        ? AppColors.primaryLight
                                        : Colors.white,
                                    border: Border.all(
                                      color: _editingPickup
                                          ? AppColors.primaryDark
                                          : Colors.grey.shade300,
                                      width: 1.5,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Column(
                                    children: [
                                      Icon(
                                        Icons.storefront,
                                        color: _editingPickup
                                            ? AppColors.primaryDark
                                            : Colors.grey,
                                        size: 20,
                                      ),
                                      const SizedBox(height: 4),
                                      const Text(
                                        'Pin Lokasi UMKM',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                          ],
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() {
                                _editingPickup = false;
                                _showCenterPin = true;
                              }),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: !_editingPickup
                                      ? const Color(0xFFFFF1F2)
                                      : Colors.white,
                                  border: Border.all(
                                    color: !_editingPickup
                                        ? const Color(0xFFD92D20)
                                        : Colors.grey.shade300,
                                    width: 1.5,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.location_on_outlined,
                                      color: !_editingPickup
                                          ? const Color(0xFFD92D20)
                                          : Colors.grey,
                                      size: 20,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _destination == null
                                          ? 'Atur Lokasi Antar'
                                          : 'Ubah Lokasi Antar',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Card(
                        elevation: 0.5,
                        child: ListTile(
                          leading: const Icon(
                            Icons.storefront,
                            color: Color(0xFF087F5B),
                          ),
                          title: Text(
                            widget.merchantName,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          subtitle: Text(
                            _pickup?.address ??
                                'Geser peta untuk memilih titik UMKM',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Card(
                        elevation: 0.5,
                        child: ListTile(
                          leading: const Icon(
                            Icons.location_on,
                            color: Color(0xFFD92D20),
                          ),
                          title: const Text(
                            'Lokasi pengantaran Anda',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                          subtitle: Text(
                            _destination?.address ??
                                'Geser peta dan klik Gunakan titik tengah',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _destinationNote,
                        decoration: const InputDecoration(
                          labelText: 'Catatan detail lokasi antar',
                          hintText: 'Rumah pagar hijau, sebelah masjid',
                        ),
                      ),
                      const SizedBox(height: 14),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Text(
                                'Ringkasan Pesanan',
                                style: TextStyle(fontWeight: FontWeight.w900),
                              ),
                              const SizedBox(height: 8),
                              ...widget.items.map(
                                (item) => Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 3,
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          '${item['quantity']}× ${item['name']}',
                                        ),
                                      ),
                                      Text(
                                        rupiah(
                                          ((item['price'] as num?) ?? 0) *
                                              ((item['quantity'] as num?) ?? 1),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const Divider(),
                              Row(
                                children: [
                                  const Expanded(child: Text('Subtotal Makanan')),
                                  Text(rupiah(widget.foodSubtotal)),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      _route == null
                                          ? 'Ongkos Kirim'
                                          : 'Ongkos Kirim (${_route!.distanceKm.toStringAsFixed(1)} km)',
                                    ),
                                  ),
                                  Text(
                                    _route == null
                                        ? 'Pilih lokasi'
                                        : rupiah(deliveryFare),
                                  ),
                                ],
                              ),
                              const Divider(),
                              Row(
                                children: [
                                  const Expanded(
                                    child: Text(
                                      'Total Bayar',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    rupiah(totalFare),
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                      color: AppColors.primaryDark,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Metode pembayaran',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      RadioGroup<String>(
                        groupValue: _payment,
                        onChanged: (value) =>
                            setState(() => _payment = value ?? 'cash'),
                        child: const Column(
                          children: [
                            RadioListTile(
                              value: 'cash',
                              title: Text('Tunai'),
                              secondary: Icon(Icons.payments_outlined),
                            ),
                            RadioListTile(
                              value: 'qris',
                              title: Text('QRIS manual'),
                              secondary: Icon(Icons.qr_code_2),
                            ),
                          ],
                        ),
                      ),
                      if (_payment == 'qris')
                        Card(
                          color: const Color(0xFFFFFAE8),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: pricing.qrisImageUrl.isEmpty
                                ? const Text(
                                    'QRIS belum dipasang admin. Pilih Tunai atau hubungi admin.',
                                  )
                                : Column(
                                    children: [
                                      const Text(
                                        'Pindai QRIS GoBran dan tunjukkan bukti pembayaran kepada driver.',
                                      ),
                                      const SizedBox(height: 12),
                                      NetworkImageBox(
                                        url: pricing.qrisImageUrl,
                                        height: 230,
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      const SizedBox(height: 14),
                      OutlinedButton.icon(
                        onPressed: (_pickup == null || _destination == null)
                            ? null
                            : () => _location.openGoogleMaps(
                                _destination!,
                                origin: _pickup,
                              ),
                        icon: const Icon(Icons.map_outlined),
                        label: const Text('Buka rute di Google Maps'),
                      ),
                      const SizedBox(height: 10),
                      ElevatedButton(
                        onPressed: _submitting ? null : () => _submit(pricing),
                        child: _submitting
                            ? const SizedBox.square(
                                dimension: 20,
                                child: CircularProgressIndicator(
                                  color: AppColors.ink,
                                ),
                              )
                            : Text('Pesan Makanan • ${rupiah(totalFare)}'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
