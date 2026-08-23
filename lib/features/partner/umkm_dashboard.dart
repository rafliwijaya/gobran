import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/common_widgets.dart';
import '../../core/formatters.dart';
import '../../models/app_models.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';

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
      actions: [IconButton(onPressed: AuthService().signOut, icon: const Icon(Icons.logout))],
    ),
    body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirestoreService().watchMerchantProfile(),
      builder: (context, snapshot) {
        if (snapshot.hasData && !_loaded) {
          _loaded = true;
          _open = snapshot.data!.data()?['is_open'] ?? false;
        }
        return DefaultTabController(
          length: 2,
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: _open ? const Color(0xFFE8F7F0) : Colors.white, borderRadius: BorderRadius.circular(18)),
                child: Row(children: [
                  Icon(_open ? Icons.storefront : Icons.storefront_outlined, color: const Color(0xFF087F5B), size: 32),
                  const SizedBox(width: 12),
                  Expanded(child: Text(_open ? 'Toko sedang buka' : 'Toko sedang tutup', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900))),
                  Switch(
                    value: _open,
                    onChanged: (value) async {
                      await FirestoreService().setMerchantOpen(value);
                      if (mounted) setState(() => _open = value);
                    },
                  ),
                ]),
              ),
              const TabBar(tabs: [Tab(text: 'Pesanan Masuk'), Tab(text: 'Kelola Produk')]),
              Expanded(child: TabBarView(children: [const _MerchantOrders(), _ProductManager(user: widget.user)])),
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
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final order = items[index];
          final next = _next(order.status);
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(children: [
                    Expanded(child: Text(order.customerName, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900))),
                    StatusPill(order.status),
                  ]),
                  const SizedBox(height: 8),
                  ...order.items.map((item) => Text('${item['quantity']}× ${item['name']}')),
                  const Divider(),
                  Text('Antar ke: ${order.destination.address}'),
                  if (order.destination.note.isNotEmpty) Text('Catatan: ${order.destination.note}'),
                  const SizedBox(height: 8),
                  Text(rupiah(order.fare), textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                  if (next != null) ...[
                    const SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: () => FirestoreService().updateOrderStatus(order, next.$1, message: next.$3),
                      child: Text(next.$2),
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

  (String, String, String)? _next(String status) => switch (status) {
    'waiting_merchant' => ('preparing', 'Terima & mulai siapkan', 'Pesanan diterima UMKM dan sedang disiapkan.'),
    'preparing' => ('searching', 'Pesanan siap • Cari driver', 'Pesanan sudah siap. GoBran sedang mencari driver pengantar.'),
    _ => null,
  };
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
              ? const Center(child: Text('Belum ada produk. Tekan + untuk menambahkan.'))
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final product = items[index];
                    return Card(
                      clipBehavior: Clip.antiAlias,
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(10),
                        leading: ClipRRect(borderRadius: BorderRadius.circular(10), child: NetworkImageBox(url: product.imageUrl, width: 68, height: 68)),
                        title: Text(product.name, style: const TextStyle(fontWeight: FontWeight.w900)),
                        subtitle: Text('${rupiah(product.price)} • Stok ${product.stock}'),
                        trailing: PopupMenuButton<String>(
                          onSelected: (value) {
                            if (value == 'edit') {
                              _showProductEditor(context, user, product: product);
                            } else {
                              FirestoreService().deleteProduct(product.id);
                            }
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(value: 'edit', child: Text('Edit')),
                            PopupMenuItem(value: 'delete', child: Text('Hapus')),
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
        bottom: 18,
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

Future<void> _showProductEditor(BuildContext context, AppUser user, {Product? product}) async {
  final name = TextEditingController(text: product?.name);
  final description = TextEditingController(text: product?.description);
  final category = TextEditingController(text: product?.category);
  final price = TextEditingController(text: product?.price.toString());
  final stock = TextEditingController(text: product?.stock.toString());
  XFile? image;
  var loading = false;
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
              TextField(controller: name, decoration: const InputDecoration(labelText: 'Nama produk')),
              const SizedBox(height: 9),
              TextField(controller: description, maxLines: 2, decoration: const InputDecoration(labelText: 'Deskripsi')),
              const SizedBox(height: 9),
              TextField(controller: category, decoration: const InputDecoration(labelText: 'Kategori')),
              const SizedBox(height: 9),
              TextField(controller: price, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Harga')),
              const SizedBox(height: 9),
              TextField(controller: stock, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Stok')),
              const SizedBox(height: 9),
              OutlinedButton.icon(
                onPressed: () async {
                  final selected = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 80, maxWidth: 1600);
                  if (selected != null) setState(() => image = selected);
                },
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: Text(image?.name ?? (product?.imageUrl.isNotEmpty == true ? 'Ganti foto' : 'Pilih foto')),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: loading ? null : () => Navigator.pop(dialogContext), child: const Text('Batal')),
          FilledButton(
            onPressed: loading ? null : () async {
              if (name.text.trim().isEmpty || int.tryParse(price.text) == null || int.tryParse(stock.text) == null) return;
              setState(() => loading = true);
              try {
                var imageUrl = product?.imageUrl ?? '';
                if (image != null) imageUrl = await FirestoreService().uploadImage(image!, 'products/${user.id}');
                await FirestoreService().saveProduct(
                  id: product?.id,
                  merchantName: user.extra['business_name'] ?? user.name,
                  name: name.text,
                  description: description.text,
                  category: category.text.isEmpty ? 'Lainnya' : category.text,
                  price: int.parse(price.text),
                  stock: int.parse(stock.text),
                  imageUrl: imageUrl,
                );
                if (dialogContext.mounted) Navigator.pop(dialogContext);
              } catch (e) {
                if (context.mounted) showMessage(context, '$e', error: true);
                setState(() => loading = false);
              }
            },
            child: loading ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator()) : const Text('Simpan'),
          ),
        ],
      ),
    ),
  );
  name.dispose();
  description.dispose();
  category.dispose();
  price.dispose();
  stock.dispose();
}

