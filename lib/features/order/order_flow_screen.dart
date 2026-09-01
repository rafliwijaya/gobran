import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../core/common_widgets.dart';
import '../../core/formatters.dart';
import '../../models/app_models.dart';
import '../../services/firestore_service.dart';
import '../../services/location_service.dart';
import 'order_detail_screen.dart';

class OrderFlowScreen extends StatefulWidget {
  const OrderFlowScreen({
    required this.user,
    required this.serviceType,
    super.key,
  });
  final AppUser user;
  final String serviceType;
  @override
  State<OrderFlowScreen> createState() => _OrderFlowScreenState();
}

class _OrderFlowScreenState extends State<OrderFlowScreen> {
  static const _babalan = LatLng(4.0217, 98.2810);
  final _mapController = MapController();
  final _pickupNote = TextEditingController();
  final _destinationNote = TextEditingController();
  final _mapsLinkController = TextEditingController();
  final _location = LocationService();
  AddressPoint? _pickup;
  AddressPoint? _destination;
  MapRoute? _route;
  bool _editingPickup = true;
  bool _loadingRoute = false;
  bool _submitting = false;
  String _payment = 'cash';
  bool _showCenterPin = true;

  @override
  void dispose() {
    _pickupNote.dispose();
    _destinationNote.dispose();
    _mapsLinkController.dispose();
    super.dispose();
  }

  Future<void> _selectPoint(LatLng point) async {
    final address = await _location.reverseGeocode(point);
    if (!mounted) return;
    setState(() {
      final value = AddressPoint(
        latitude: point.latitude,
        longitude: point.longitude,
        address: address,
      );
      if (_editingPickup) {
        _pickup = value;
        if (_destination == null) {
          _editingPickup = false;
          _showCenterPin = true;
        } else {
          _showCenterPin = false;
        }
      } else {
        _destination = value;
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
        _editingPickup = true;
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

  Future<void> _submit(PricingConfig pricing) async {
    if (_pickup == null || _destination == null || _route == null) {
      showMessage(
        context,
        'Tentukan titik jemput dan tujuan terlebih dahulu.',
        error: true,
      );
      return;
    }
    if (_pickupNote.text.trim().isEmpty ||
        _destinationNote.text.trim().isEmpty) {
      showMessage(
        context,
        'Catatan detail lokasi jemput dan tujuan wajib diisi.',
        error: true,
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      final pickup = AddressPoint(
        latitude: _pickup!.latitude,
        longitude: _pickup!.longitude,
        address: _pickup!.address,
        note: _pickupNote.text.trim(),
      );
      final destination = AddressPoint(
        latitude: _destination!.latitude,
        longitude: _destination!.longitude,
        address: _destination!.address,
        note: _destinationNote.text.trim(),
      );
      final id = await FirestoreService().createRideOrder(
        customer: widget.user,
        serviceType: widget.serviceType,
        pickup: pickup,
        destination: destination,
        route: _route!,
        pricing: pricing,
        paymentMethod: _payment,
      );
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => OrderDetailScreen(orderId: id)),
      );
    } catch (e) {
      if (mounted) showMessage(context, '$e', error: true);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _importFromGoogleMapsLink(String url) async {
    setState(() => _loadingRoute = true);
    try {
      String resolvedUrl = url;
      if (url.contains('maps.app.goo.gl') || url.contains('goo.gl/maps')) {
        resolvedUrl = await _location.resolveRedirect(url);
      }

      LatLng? pickupPoint;
      LatLng? destinationPoint;

      // 1. Try to extract start/pickup coordinates from '/dir/lat,lon'
      final startDirRegex = RegExp(r'/dir/(-?\d+\.\d+),(-?\d+\.\d+)');
      final startDirMatch = startDirRegex.firstMatch(resolvedUrl);
      if (startDirMatch != null) {
        pickupPoint = LatLng(
          double.parse(startDirMatch.group(1)!),
          double.parse(startDirMatch.group(2)!),
        );
      }

      // 2. Try to extract destination coordinates from the second part of '/dir/...'
      // e.g. /dir/lat,lon/lat,lon or /dir/My+Location/lat,lon
      final destDirRegex = RegExp(r'/dir/[^/]+/(-?\d+\.\d+),(-?\d+\.\d+)');
      final destDirMatch = destDirRegex.firstMatch(resolvedUrl);
      if (destDirMatch != null) {
        destinationPoint = LatLng(
          double.parse(destDirMatch.group(1)!),
          double.parse(destDirMatch.group(2)!),
        );
      }

      // 3. Fallback: Parse embedded 'data' coordinates if destination is not found yet
      // (very common when destinations are places/businesses, e.g. SMA Negeri 1 Babalan)
      if (destinationPoint == null) {
        final latMatch = RegExp(r'!3d(-?\d+\.\d+)').firstMatch(resolvedUrl);
        final lonMatch = RegExp(r'!4d(-?\d+\.\d+)').firstMatch(resolvedUrl);
        if (latMatch != null && lonMatch != null) {
          destinationPoint = LatLng(
            double.parse(latMatch.group(1)!),
            double.parse(lonMatch.group(1)!),
          );
        }
      }

      // 4. Try standard query/params fallback
      if (pickupPoint == null) {
        final saddrRegex = RegExp(r'[?&]saddr=(-?\d+\.\d+),(-?\d+\.\d+)');
        final sMatch = saddrRegex.firstMatch(resolvedUrl);
        if (sMatch != null) {
          pickupPoint = LatLng(
            double.parse(sMatch.group(1)!),
            double.parse(sMatch.group(2)!),
          );
        }
      }
      if (destinationPoint == null) {
        final daddrRegex = RegExp(r'[?&]daddr=(-?\d+\.\d+),(-?\d+\.\d+)');
        final dMatch = daddrRegex.firstMatch(resolvedUrl);
        if (dMatch != null) {
          destinationPoint = LatLng(
            double.parse(dMatch.group(1)!),
            double.parse(dMatch.group(2)!),
          );
        }
      }

      // 5. Place/query or @ lat,lon fallback
      if (destinationPoint == null) {
        final placeRegex = RegExp(r'/place/(-?\d+\.\d+),(-?\d+\.\d+)');
        final placeMatch = placeRegex.firstMatch(resolvedUrl);
        if (placeMatch != null) {
          destinationPoint = LatLng(
            double.parse(placeMatch.group(1)!),
            double.parse(placeMatch.group(2)!),
          );
        }
      }
      if (destinationPoint == null) {
        final qRegex = RegExp(r'[?&](query|q)=(-?\d+\.\d+),(-?\d+\.\d+)');
        final qMatch = qRegex.firstMatch(resolvedUrl);
        if (qMatch != null) {
          destinationPoint = LatLng(
            double.parse(qMatch.group(2)!),
            double.parse(qMatch.group(3)!),
          );
        }
      }
      if (destinationPoint == null) {
        final atRegex = RegExp(r'@(-?\d+\.\d+),(-?\d+\.\d+)');
        final atMatch = atRegex.firstMatch(resolvedUrl);
        if (atMatch != null) {
          destinationPoint = LatLng(
            double.parse(atMatch.group(1)!),
            double.parse(atMatch.group(2)!),
          );
        }
      }

      // 6. If pickup is My+Location, use current GPS coordinates
      if (pickupPoint == null &&
          (resolvedUrl.contains('/dir/My+Location') ||
              resolvedUrl.contains('/dir/Lokasi+Saya'))) {
        try {
          pickupPoint = await _location.currentLocation();
        } catch (_) {}
      }

      if (pickupPoint == null && destinationPoint == null) {
        throw Exception('Link tidak valid atau koordinat tidak ditemukan.');
      }

      if (pickupPoint != null) {
        final address = await _location.reverseGeocode(pickupPoint);
        _pickup = AddressPoint(
          latitude: pickupPoint.latitude,
          longitude: pickupPoint.longitude,
          address: address,
        );
      }
      if (destinationPoint != null) {
        final address = await _location.reverseGeocode(destinationPoint);
        _destination = AddressPoint(
          latitude: destinationPoint.latitude,
          longitude: destinationPoint.longitude,
          address: address,
        );
      }

      if (_destination != null) {
        _mapController.move(_destination!.latLng, 14);
      } else if (_pickup != null) {
        _mapController.move(_pickup!.latLng, 14);
      }

      setState(() {
        _showCenterPin = false; // Hide center pin since both are set from link
      });

      await _calculateRoute();
      if (mounted) {
        showMessage(context, 'Link Google Maps berhasil dimuat.');
      }
    } catch (e) {
      if (mounted) showMessage(context, 'Gagal memuat link: $e', error: true);
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
          'Salin link Google Maps terlebih dahulu.',
          error: true,
        );
      }
      return;
    }
    final parsed = Uri.tryParse(url);
    if (parsed?.scheme.toLowerCase() != 'https') {
      if (mounted) {
        showMessage(context, 'Link harus menggunakan HTTPS.', error: true);
      }
      return;
    }
    _mapsLinkController.text = url;
    await _importFromGoogleMapsLink(url);
  }

  @override
  Widget build(BuildContext context) {
    final label = widget.serviceType == 'ojek' ? 'Ojek' : 'Express';
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 0,
        title: Text('Pesan $label'),
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
          final fare = _route == null
              ? 0
              : FareCalculator.calculate(
                  _route!.distanceKm,
                  firstTwoKmFare: pricing.firstTwoKmFare,
                  additionalPerKm: pricing.additionalPerKm,
                );
          return Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fill(
                child: Stack(
                  children: [
                    FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
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
                                child: const _MapPin(
                                  icon: Icons.person_pin_circle,
                                  color: Color(0xFF087F5B),
                                ),
                              ),
                            if (_destination != null)
                              Marker(
                                point: _destination!.latLng,
                                width: 46,
                                height: 46,
                                child: const _MapPin(
                                  icon: Icons.location_on,
                                  color: Color(0xFFD92D20),
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
                    // Centered Marker Pin (Gojek Style) - Only visible when _showCenterPin is true
                    if (_showCenterPin) ...[
                      Center(
                        child: Container(
                          margin: const EdgeInsets.only(
                            bottom: 38,
                          ), // Offset so the tip aligns with center
                          child: Icon(
                            _editingPickup
                                ? Icons.person_pin_circle
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
                      // Confirm center location button
                      Positioned(
                        bottom: MediaQuery.of(context).size.height * .30 + 12,
                        left: 12,
                        right: 60, // Avoid current location FAB overlapping
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00880F),
                            foregroundColor: Colors.white,
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
                                  ? 'Gunakan titik tengah untuk Jemput'
                                  : 'Gunakan titik tengah untuk Tujuan',
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
                      bottom: MediaQuery.of(context).size.height * .30 + 12,
                      right: 12,
                      child: FloatingActionButton.small(
                        heroTag: 'current_location',
                        onPressed: _useCurrentLocation,
                        child: const Icon(Icons.my_location),
                      ),
                    ),
                    if (_loadingRoute)
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
                initialChildSize: .30,
                minChildSize: .24,
                maxChildSize: .90,
                snap: true,
                snapSizes: const [.30, .90],
                builder: (context, scrollController) => Material(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(18, 12, 18, 32),
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
                      const SizedBox(height: 4),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Paste Google Maps Link Card
                          Card(
                            elevation: 0,
                            color: const Color(0xFFF0FDF4),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: const BorderSide(
                                color: Color(0xFF00880F),
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
                                    'Pesan cepat via link Google Maps',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: Color(0xFF00880F),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: TextField(
                                          controller: _mapsLinkController,
                                          readOnly: true,
                                          showCursor: false,
                                          onTap: _pasteMapsLink,
                                          decoration: InputDecoration(
                                            hintText:
                                                'Ketuk untuk menempel link Google Maps...',
                                            isDense: true,
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                  horizontal: 12,
                                                  vertical: 10,
                                                ),
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            fillColor: Colors.white,
                                            filled: true,
                                            suffixIcon: IconButton(
                                              tooltip: 'Tempel link',
                                              icon: const Icon(
                                                Icons.content_paste,
                                              ),
                                              onPressed: _pasteMapsLink,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          // Custom rectangular card segments for selecting mode
                          Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => setState(() {
                                    _editingPickup = true;
                                    _showCenterPin = true;
                                  }),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _editingPickup
                                          ? const Color(0xFFF0FDF4)
                                          : Colors.white,
                                      border: Border.all(
                                        color: _editingPickup
                                            ? const Color(0xFF00880F)
                                            : Colors.grey.shade300,
                                        width: 1.5,
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Column(
                                      children: [
                                        Icon(
                                          Icons.trip_origin,
                                          color: _editingPickup
                                              ? const Color(0xFF00880F)
                                              : Colors.grey,
                                          size: 20,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Titik Penjemputan',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                            color: _editingPickup
                                                ? const Color(0xFF00880F)
                                                : Colors.grey.shade700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => setState(() {
                                    _editingPickup = false;
                                    _showCenterPin = true;
                                  }),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
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
                                          'Atur Tujuan',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                            color: !_editingPickup
                                                ? const Color(0xFFD92D20)
                                                : Colors.grey.shade700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          _AddressCard(
                            title: 'Titik penjemputan',
                            address:
                                _pickup?.address ??
                                'Geser peta dan klik Gunakan lokasi tengah',
                            color: const Color(0xFF087F5B),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _pickupNote,
                            decoration: const InputDecoration(
                              labelText: 'Catatan detail jemput',
                              hintText: 'Rumah cat biru, pagar hitam',
                            ),
                          ),
                          const SizedBox(height: 12),
                          _AddressCard(
                            title: 'Titik tujuan',
                            address:
                                _destination?.address ??
                                'Geser peta dan klik Gunakan lokasi tengah',
                            color: const Color(0xFFD92D20),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _destinationNote,
                            decoration: const InputDecoration(
                              labelText: 'Catatan detail tujuan',
                              hintText: 'Depan minimarket, hubungi saat tiba',
                            ),
                          ),
                          if (_route != null) ...[
                            const SizedBox(height: 16),
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.route,
                                      color: Color(0xFF087F5B),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        '${_route!.distanceKm.toStringAsFixed(1)} km • ±${_route!.durationMinutes.ceil()} menit',
                                      ),
                                    ),
                                    Text(
                                      rupiah(fare),
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 16),
                          const Text(
                            'Metode pembayaran',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                          RadioGroup<String>(
                            groupValue: _payment,
                            onChanged: (value) =>
                                setState(() => _payment = value ?? 'cash'),
                            child: Column(
                              children: [
                                RadioListTile(
                                  value: 'cash',
                                  title: const Text('Tunai'),
                                  secondary: const Icon(
                                    Icons.payments_outlined,
                                  ),
                                ),
                                RadioListTile(
                                  value: 'qris',
                                  title: const Text('QRIS manual'),
                                  secondary: const Icon(Icons.qr_code_2),
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
                          const SizedBox(height: 16),
                          OutlinedButton.icon(
                            onPressed: _destination == null
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
                            onPressed: _submitting
                                ? null
                                : () => _submit(pricing),
                            child: _submitting
                                ? const CircularProgressIndicator()
                                : Text('Pesan $label • ${rupiah(fare)}'),
                          ),
                        ],
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

class _MapPin extends StatelessWidget {
  const _MapPin({required this.icon, required this.color});
  final IconData icon;
  final Color color;
  @override
  Widget build(BuildContext context) => Icon(
    icon,
    color: color,
    size: 42,
    shadows: const [Shadow(color: Colors.white, blurRadius: 4)],
  );
}

class _AddressCard extends StatelessWidget {
  const _AddressCard({
    required this.title,
    required this.address,
    required this.color,
  });
  final String title;
  final String address;
  final Color color;
  @override
  Widget build(BuildContext context) => Card(
    elevation: 0.5,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    child: ListTile(
      leading: Icon(Icons.location_on, color: color),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
      subtitle: Text(address, maxLines: 2, overflow: TextOverflow.ellipsis),
    ),
  );
}

class AddressSearchScreen extends StatefulWidget {
  const AddressSearchScreen({super.key});
  @override
  State<AddressSearchScreen> createState() => _AddressSearchScreenState();
}

class _AddressSearchScreenState extends State<AddressSearchScreen> {
  final _controller = TextEditingController();
  List<AddressSearchResult> _results = [];
  bool _loading = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    setState(() => _loading = true);
    try {
      final results = await LocationService().searchAddress(_controller.text);
      if (mounted) setState(() => _results = results);
    } catch (e) {
      if (mounted) showMessage(context, '$e', error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Cari alamat')),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _controller,
            autofocus: true,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _search(),
            decoration: InputDecoration(
              hintText: 'Contoh: Pasar Pangkalan Brandan',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(
                onPressed: _search,
                icon: const Icon(Icons.arrow_forward),
              ),
            ),
          ),
        ),
        if (_loading) const LinearProgressIndicator(),
        Expanded(
          child: ListView.separated(
            itemCount: _results.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final result = _results[index];
              return ListTile(
                leading: const Icon(Icons.location_on_outlined),
                title: Text(result.label),
                onTap: () => Navigator.pop(context, result),
              );
            },
          ),
        ),
      ],
    ),
  );
}
