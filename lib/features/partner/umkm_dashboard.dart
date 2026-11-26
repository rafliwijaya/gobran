import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';

import '../../core/app_theme.dart';
import '../../core/common_widgets.dart';
import '../../core/formatters.dart';
import '../../models/app_models.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../services/location_service.dart';

class UmkmDashboard extends StatefulWidget {
  const UmkmDashboard({required this.user, super.key});
  final AppUser user;
  @override
  State<UmkmDashboard> createState() => _UmkmDashboardState();
}

class _UmkmDashboardState extends State<UmkmDashboard> {
  bool _open = false;
  bool _loaded = false;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.user.extra['business_name'] ?? 'Dashboard UMKM'),
      actions: [
        IconButton(
          onPressed: AuthService().signOut,
          icon: const Icon(Icons.logout),
        ),
      ],
    ),
    body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirestoreService().watchMerchantProfile(),
      builder: (context, snapshot) {
        final profileData = snapshot.data?.data() ?? <String, dynamic>{};
        if (snapshot.hasData && !_loaded) {
          _loaded = true;
          _open = profileData['is_open'] ?? false;
        }
        final geo = profileData['location'];
        final hasLocation =
            geo is GeoPoint && (geo.latitude != 0 || geo.longitude != 0);
        final addressText = (profileData['address'] ?? '').toString().trim();
        return DefaultTabController(
          length: 2,
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.fromLTRB(16, 16, 16, 10),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _open ? const Color(0xFFE8F7F0) : Colors.white,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(
                          _open
                              ? Icons.storefront
                              : Icons.storefront_outlined,
                          color: const Color(0xFF087F5B),
                          size: 32,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _open ? 'Toko sedang buka' : 'Toko sedang tutup',
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        Switch(
                          value: _open,
                          onChanged: (value) async {
                            await FirestoreService().setMerchantOpen(value);
                            if (mounted) setState(() => _open = value);
                          },
                        ),
                      ],
                    ),
                    const Divider(height: 18),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 18,
                          color: hasLocation
                              ? const Color(0xFF087F5B)
                              : Colors.orange.shade800,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            hasLocation
                                ? (addressText.isNotEmpty
                                      ? addressText
                                      : '${geo.latitude.toStringAsFixed(4)}, ${geo.longitude.toStringAsFixed(4)}')
                                : 'Pin peta toko belum diatur (untuk hitung ongkir otomatis)',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        TextButton.icon(
                          onPressed: () => Navigator.push<void>(
                            context,
                            MaterialPageRoute(
                              builder: (_) => _MerchantLocationPickerScreen(
                                initialPoint: hasLocation
                                    ? LatLng(geo.latitude, geo.longitude)
                                    : null,
                              ),
                            ),
                          ),
                          icon: const Icon(Icons.map_outlined, size: 16),
                          label: Text(hasLocation ? 'Ubah Pin' : 'Atur Peta'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const TabBar(
                tabs: [
                  Tab(text: 'Pesanan Masuk'),
                  Tab(text: 'Kelola Produk'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    const _MerchantOrders(),
                    _ProductManager(user: widget.user),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}

class _MerchantOrders extends StatelessWidget {
  const _MerchantOrders();
  @override
  Widget build(BuildContext context) => StreamBuilder<List<AppOrder>>(
    stream: FirestoreService().watchMerchantOrders(),
    builder: (context, snapshot) => AsyncView<List<AppOrder>>(
      snapshot: snapshot,
      isEmpty: (items) => items.isEmpty,
      emptyMessage: 'Belum ada pesanan makanan.',
      builder: (items) => ListView.separated(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          24 + bottomSystemInset(context),
        ),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final order = items[index];
          final driverAccepted =
              order.driverId.isNotEmpty &&
              [
                'driver_confirmed',
                'heading_to_pickup',
                'at_pickup',
              ].contains(order.status);
          final handedOver = order.meta['merchant_stage'] == 'handed_over';
          final canCancel =
              order.status == 'waiting_merchant' ||
              (order.status == 'searching' && order.driverId.isEmpty);
          final showAcceptedStage = [
            'searching',
            'driver_confirmed',
            'heading_to_pickup',
            'at_pickup',
          ].contains(order.status);

          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          order.customerName,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      StatusPill(order.status, serviceType: order.serviceType),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...order.items.map(
                    (item) => Text('${item['quantity']}× ${item['name']}'),
                  ),
                  const Divider(),
                  Text('Antar ke: ${order.destination.address}'),
                  if (order.destination.note.isNotEmpty)
                    Text('Catatan: ${order.destination.note}'),
                  if (order.status != 'waiting_merchant' &&
                      order.status != 'cancelled' &&
                      order.status != 'completed') ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        order.driverId.isEmpty
                            ? 'Sedang mencari driver untuk menjemput pesanan...'
                            : order.customerProgressLabel,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                  if (handedOver &&
                      order.status != 'completed' &&
                      order.status != 'cancelled') ...[
                    const SizedBox(height: 6),
                    const Text(
                      '✓ Pesanan sudah diserahkan ke driver',
                      style: TextStyle(
                        color: AppColors.primaryDark,
                        fontWeight: FontWeight.w700,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    rupiah(order.fare),
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                    ),
                  ),
                  if (order.status == 'waiting_merchant') ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _cancelOrderButton(context, order),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => FirestoreService()
                                .acceptMerchantFoodOrder(order),
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size(0, 48),
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                            ),
                            child: const FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text('Terima Pesanan'),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ] else if (showAcceptedStage && !handedOver) ...[
                    const SizedBox(height: 10),
                    if (driverAccepted)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          'Driver sudah menerima pesanan • Pembatalan dinonaktifkan',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    Row(
                      children: [
                        if (canCancel) ...[
                          Expanded(child: _cancelOrderButton(context, order)),
                          const SizedBox(width: 10),
                        ],
                        Expanded(
                          child: ElevatedButton(
                            onPressed: driverAccepted
                                ? () => FirestoreService()
                                      .handOverFoodOrderToDriver(order)
                                : null,
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size(0, 48),
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                            ),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                driverAccepted
                                    ? 'Serahkan ke Driver'
                                    : 'Tunggu Driver Terima',
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    ),
  );

  Widget _cancelOrderButton(BuildContext context, AppOrder order) =>
      OutlinedButton(
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFFD92D20),
          side: const BorderSide(color: Color(0xFFD92D20), width: 1.3),
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        onPressed: () => _confirmCancel(context, order),
        child: const FittedBox(
          fit: BoxFit.scaleDown,
          child: Text('Batalkan Pesanan'),
        ),
      );

  Future<void> _confirmCancel(BuildContext context, AppOrder order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Batalkan pesanan ini?'),
        content: const Text(
          'Pesanan akan dibatalkan dan pelanggan akan menerima pemberitahuan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Kembali'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFD92D20),
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Batalkan Pesanan'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await FirestoreService().cancelFoodOrderByMerchant(order);
    }
  }
}

class _ProductManager extends StatelessWidget {
  const _ProductManager({required this.user});
  final AppUser user;
  @override
  Widget build(BuildContext context) => Stack(
    children: [
      StreamBuilder<List<Product>>(
        stream: FirestoreService().watchProducts(merchantId: user.id),
        builder: (context, snapshot) => AsyncView<List<Product>>(
          snapshot: snapshot,
          builder: (items) => items.isEmpty
              ? const Center(
                  child: Text('Belum ada produk. Tekan + untuk menambahkan.'),
                )
              : ListView.separated(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    16,
                    16,
                    96 + bottomSystemInset(context),
                  ),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final product = items[index];
                    return Card(
                      clipBehavior: Clip.antiAlias,
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(10),
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: NetworkImageBox(
                            url: product.imageUrl,
                            width: 68,
                            height: 68,
                          ),
                        ),
                        title: Text(
                          product.name,
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        subtitle: Text(
                          product.hasDiscount
                              ? '${rupiah(product.discountedPrice)} (Diskon ${product.discountPercent}% dari ${rupiah(product.price)}) • Stok ${product.stock}'
                              : '${rupiah(product.price)} • Stok ${product.stock}',
                        ),
                        trailing: PopupMenuButton<String>(
                          onSelected: (value) {
                            if (value == 'edit') {
                              _showProductEditor(
                                context,
                                user,
                                product: product,
                              );
                            } else {
                              FirestoreService().deleteProduct(product.id);
                            }
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(value: 'edit', child: Text('Edit')),
                            PopupMenuItem(
                              value: 'delete',
                              child: Text('Hapus'),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ),
      Positioned(
        right: 18,
        bottom: 18 + bottomSystemInset(context),
        child: FloatingActionButton.extended(
          heroTag: 'add_product',
          onPressed: () => _showProductEditor(context, user),
          icon: const Icon(Icons.add),
          label: const Text('Produk'),
        ),
      ),
    ],
  );
}

Future<void> _showProductEditor(
  BuildContext context,
  AppUser user, {
  Product? product,
}) async {
  final name = TextEditingController(text: product?.name);
  final description = TextEditingController(text: product?.description);
  final category = TextEditingController(text: product?.category);
  final price = TextEditingController(text: product?.price.toString());
  final discount = TextEditingController(
    text: (product != null && product.discountPercent > 0)
        ? product.discountPercent.toString()
        : '',
  );
  final stock = TextEditingController(text: product?.stock.toString());
  final existingUrl = product?.imageUrl ?? '';
  final imageUrlInput = TextEditingController(
    text: existingUrl.startsWith('http') ? existingUrl : '',
  );
  XFile? image;
  var loading = false;
  String? errorMessage;
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text(product == null ? 'Tambah produk' : 'Edit produk'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Nama produk'),
              ),
              const SizedBox(height: 9),
              TextField(
                controller: description,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Deskripsi'),
              ),
              const SizedBox(height: 9),
              TextField(
                controller: category,
                decoration: const InputDecoration(labelText: 'Kategori'),
              ),
              const SizedBox(height: 9),
              TextField(
                controller: price,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Harga'),
              ),
              const SizedBox(height: 9),
              TextField(
                controller: discount,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Diskon (%) opsional',
                  hintText: 'Contoh: 50 (kosongkan jika tanpa diskon)',
                ),
              ),
              const SizedBox(height: 9),
              TextField(
                controller: stock,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Stok'),
              ),
              const SizedBox(height: 9),
              OutlinedButton.icon(
                onPressed: loading
                    ? null
                    : () async {
                        final selected = await ImagePicker().pickImage(
                          source: ImageSource.gallery,
                          imageQuality: 58,
                          maxWidth: 720,
                        );
                        if (selected != null) {
                          setState(() {
                            image = selected;
                            errorMessage = null;
                          });
                        }
                      },
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: Text(
                  image?.name ??
                      (existingUrl.isNotEmpty
                          ? 'Ganti foto dari galeri'
                          : 'Pilih foto dari galeri'),
                ),
              ),
              const SizedBox(height: 9),
              TextField(
                controller: imageUrlInput,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                  labelText: 'Atau tempel URL foto (opsional)',
                  hintText: 'https://...',
                ),
              ),
              if (existingUrl.startsWith('data:image/') && image == null) ...[
                const SizedBox(height: 6),
                const Text(
                  'Foto tersimpan aktif. Pilih foto baru atau isi URL untuk mengganti.',
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
              if (errorMessage != null) ...[
                const SizedBox(height: 10),
                FormErrorBox(message: errorMessage!),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: loading ? null : () => Navigator.pop(dialogContext),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: loading
                ? null
                : () async {
                    final parsedPrice = int.tryParse(price.text.trim());
                    final parsedStock = int.tryParse(stock.text.trim());
                    final discountText = discount.text.trim();
                    final parsedDiscount = discountText.isEmpty
                        ? 0
                        : int.tryParse(discountText);
                    if (name.text.trim().isEmpty ||
                        parsedPrice == null ||
                        parsedStock == null) {
                      setState(
                        () => errorMessage =
                            'Nama produk, harga, dan stok (angka) wajib diisi.',
                      );
                      return;
                    }
                    if (parsedDiscount == null ||
                        parsedDiscount < 0 ||
                        parsedDiscount > 100) {
                      setState(
                        () => errorMessage =
                            'Diskon harus berupa angka 0 sampai 100 (%).',
                      );
                      return;
                    }
                    setState(() {
                      loading = true;
                      errorMessage = null;
                    });
                    try {
                      final typedUrl = imageUrlInput.text.trim();
                      var imageUrl = typedUrl.isNotEmpty ? typedUrl : existingUrl;
                      if (image != null) {
                        imageUrl = await FirestoreService().uploadImage(
                          image!,
                          'products/${user.id}',
                        );
                      }
                      await FirestoreService().saveProduct(
                        id: product?.id,
                        merchantName: user.extra['business_name'] ?? user.name,
                        name: name.text,
                        description: description.text,
                        category: category.text.trim().isEmpty
                            ? 'Lainnya'
                            : category.text.trim(),
                        price: parsedPrice,
                        discountPercent: parsedDiscount,
                        stock: parsedStock,
                        imageUrl: imageUrl,
                      );
                      if (dialogContext.mounted) Navigator.pop(dialogContext);
                    } catch (e) {
                      if (context.mounted) {
                        setState(() {
                          loading = false;
                          errorMessage = '$e';
                        });
                      }
                    }
                  },
            child: loading
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(),
                  )
                : const Text('Simpan'),
          ),
        ],
      ),
    ),
  );
  name.dispose();
  description.dispose();
  category.dispose();
  price.dispose();
  discount.dispose();
  stock.dispose();
  imageUrlInput.dispose();
}

class _MerchantLocationPickerScreen extends StatefulWidget {
  const _MerchantLocationPickerScreen({this.initialPoint});

  final LatLng? initialPoint;

  @override
  State<_MerchantLocationPickerScreen> createState() =>
      _MerchantLocationPickerScreenState();
}

class _MerchantLocationPickerScreenState
    extends State<_MerchantLocationPickerScreen> {
  static const _babalan = LatLng(4.0217, 98.2810);
  late final MapController _mapController;
  final _location = LocationService();
  LatLng? _selectedPoint;
  String _selectedAddress = '';
  bool _loading = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _selectedPoint = widget.initialPoint;
    if (_selectedPoint != null) {
      _reverse(_selectedPoint!);
    }
  }

  Future<void> _reverse(LatLng point) async {
    setState(() => _loading = true);
    try {
      final address = await _location.reverseGeocode(point);
      if (mounted) {
        setState(() {
          _selectedPoint = point;
          _selectedAddress = address;
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pasteMapsLink() async {
    final clipboard = await Clipboard.getData(Clipboard.kTextPlain);
    final url = clipboard?.text?.trim() ?? '';
    if (url.isEmpty) {
      if (mounted) {
        showMessage(
          context,
          'Salin link Google Maps toko Anda terlebih dahulu.',
          error: true,
        );
      }
      return;
    }
    setState(() => _loading = true);
    try {
      final parsed = await _location.parseGoogleMapsLink(url);
      final target = parsed.destination ?? parsed.pickup;
      if (target == null) {
        throw Exception('Koordinat tidak ditemukan di link.');
      }
      _mapController.move(target, 16);
      await _reverse(target);
    } catch (e) {
      if (mounted) showMessage(context, 'Gagal memuat link: $e', error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    final target = _selectedPoint ?? _mapController.camera.center;
    setState(() => _saving = true);
    try {
      final address = _selectedAddress.isNotEmpty
          ? _selectedAddress
          : await _location.reverseGeocode(target);
      await FirestoreService().updateMerchantLocation(target, address);
      if (!mounted) return;
      Navigator.pop(context);
      showMessage(context, 'Lokasi toko berhasil disimpan.');
    } catch (e) {
      if (mounted) showMessage(context, '$e', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = bottomSystemInset(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Atur Lokasi Toko UMKM')),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: widget.initialPoint ?? _babalan,
              initialZoom: widget.initialPoint != null ? 16 : 14,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'id.gobran.app',
              ),
              if (_selectedPoint != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _selectedPoint!,
                      width: 44,
                      height: 44,
                      child: const Icon(
                        Icons.storefront,
                        color: AppColors.primaryDark,
                        size: 38,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          Center(
            child: Container(
              margin: const EdgeInsets.only(bottom: 36),
              child: const Icon(
                Icons.location_on,
                color: Color(0xFFD92D20),
                size: 46,
                shadows: [Shadow(color: Colors.white, blurRadius: 8)],
              ),
            ),
          ),
          Positioned(
            top: 12,
            right: 12,
            child: Column(
              children: [
                FloatingActionButton.small(
                  heroTag: 'umkm_gps',
                  onPressed: () async {
                    try {
                      final point = await _location.currentLocation();
                      _mapController.move(point, 16);
                      await _reverse(point);
                    } catch (e) {
                      if (context.mounted) {
                        showMessage(context, '$e', error: true);
                      }
                    }
                  },
                  child: const Icon(Icons.my_location),
                ),
                const SizedBox(height: 8),
                FloatingActionButton.small(
                  heroTag: 'umkm_maps_link',
                  onPressed: _pasteMapsLink,
                  child: const Icon(Icons.content_paste),
                ),
              ],
            ),
          ),
          if (_loading)
            const Positioned.fill(
              child: ColoredBox(
                color: Color(0x33000000),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      ),
      bottomNavigationBar: Container(
        color: Colors.white,
        padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + bottomInset),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _selectedAddress.isNotEmpty
                  ? _selectedAddress
                  : 'Geser pin ke lokasi toko UMKM Anda lalu simpan',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _saving
                        ? null
                        : () => _reverse(_mapController.camera.center),
                    child: const Text('Gunakan Titik Tengah'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                            ),
                          )
                        : const Text('Simpan Lokasi'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
