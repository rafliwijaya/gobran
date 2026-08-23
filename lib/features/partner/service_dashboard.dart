import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/common_widgets.dart';
import '../../core/formatters.dart';
import '../../models/app_models.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';

class ServiceDashboard extends StatefulWidget {
  const ServiceDashboard({required this.user, super.key});
  final AppUser user;
  @override
  State<ServiceDashboard> createState() => _ServiceDashboardState();
}

class _ServiceDashboardState extends State<ServiceDashboard> {
  bool _available = false;
  bool _loaded = false;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Dashboard Mitra Jasa'),
      actions: [IconButton(onPressed: AuthService().signOut, icon: const Icon(Icons.logout))],
    ),
    body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirestoreService().watchServiceProfile(),
      builder: (context, snapshot) {
        if (snapshot.hasData && !_loaded) {
          _loaded = true;
          _available = snapshot.data!.data()?['is_available'] ?? false;
        }
        return DefaultTabController(
          length: 2,
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: _available ? const Color(0xFFE8F7F0) : Colors.white, borderRadius: BorderRadius.circular(18)),
                child: Row(children: [
                  const Icon(Icons.home_repair_service, color: Color(0xFF087F5B), size: 32),
                  const SizedBox(width: 12),
                  Expanded(child: Text(_available ? 'Siap menerima permintaan' : 'Sedang tidak tersedia', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17))),
                  Switch(
                    value: _available,
                    onChanged: (value) async {
                      await FirestoreService().setServiceAvailable(value);
                      if (mounted) setState(() => _available = value);
                    },
                  ),
                ]),
              ),
              const TabBar(tabs: [Tab(text: 'Permintaan Masuk'), Tab(text: 'Kelola Layanan')]),
              Expanded(child: TabBarView(children: [const _ServiceOrders(), _ListingManager(user: widget.user)])),
            ],
          ),
        );
      },
    ),
  );
}

class _ServiceOrders extends StatelessWidget {
  const _ServiceOrders();
  @override
  Widget build(BuildContext context) => StreamBuilder<List<AppOrder>>(
    stream: FirestoreService().watchServiceOrders(),
    builder: (context, snapshot) => AsyncView<List<AppOrder>>(
      snapshot: snapshot,
      isEmpty: (items) => items.isEmpty,
      emptyMessage: 'Belum ada permintaan jasa.',
      builder: (items) => ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final order = items[index];
          final next = switch (order.status) {
            'waiting_partner' => ('accepted', 'Terima permintaan'),
            'accepted' => ('completed', 'Tandai selesai'),
            _ => null,
          };
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [Expanded(child: Text(order.meta['listing_name'] ?? 'Permintaan jasa', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17))), StatusPill(order.status)]),
                const SizedBox(height: 8),
                Text('Pelanggan: ${order.customerName}'),
                Text('Alamat: ${order.destination.address}'),
                if (order.destination.note.isNotEmpty) Text('Kebutuhan: ${order.destination.note}'),
                const SizedBox(height: 8),
                Text('Estimasi ${rupiah(order.fare)}', style: const TextStyle(fontWeight: FontWeight.w900)),
                if (next != null) ...[
                  const SizedBox(height: 10),
                  ElevatedButton(onPressed: () => FirestoreService().updateOrderStatus(order, next.$1), child: Text(next.$2)),
                ],
              ]),
            ),
          );
        },
      ),
    ),
  );
}

class _ListingManager extends StatelessWidget {
  const _ListingManager({required this.user});
  final AppUser user;
  @override
  Widget build(BuildContext context) => Stack(
    children: [
      StreamBuilder<List<ServiceListing>>(
        stream: FirestoreService().watchServiceListings(partnerId: user.id),
        builder: (context, snapshot) => AsyncView<List<ServiceListing>>(
          snapshot: snapshot,
          builder: (items) => items.isEmpty
              ? const Center(child: Text('Belum ada layanan. Tekan + untuk menambahkan.'))
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return Card(
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(10),
                        leading: ClipRRect(borderRadius: BorderRadius.circular(10), child: NetworkImageBox(url: item.imageUrl, width: 68, height: 68)),
                        title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w900)),
                        subtitle: Text('${item.category} • ${rupiah(item.estimatedPrice)}'),
                        trailing: PopupMenuButton<String>(
                          onSelected: (value) => value == 'edit' ? _editListing(context, user, item: item) : FirestoreService().deleteServiceListing(item.id),
                          itemBuilder: (_) => const [PopupMenuItem(value: 'edit', child: Text('Edit')), PopupMenuItem(value: 'delete', child: Text('Hapus'))],
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
          heroTag: 'add_service',
          onPressed: () => _editListing(context, user),
          icon: const Icon(Icons.add),
          label: const Text('Layanan'),
        ),
      ),
    ],
  );
}

Future<void> _editListing(BuildContext context, AppUser user, {ServiceListing? item}) async {
  final name = TextEditingController(text: item?.name);
  final description = TextEditingController(text: item?.description);
  final category = TextEditingController(text: item?.category);
  final price = TextEditingController(text: item?.estimatedPrice.toString());
  XFile? image;
  var loading = false;
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text(item == null ? 'Tambah layanan' : 'Edit layanan'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: name, decoration: const InputDecoration(labelText: 'Nama layanan')),
            const SizedBox(height: 9),
            TextField(controller: description, maxLines: 3, decoration: const InputDecoration(labelText: 'Deskripsi')),
            const SizedBox(height: 9),
            TextField(controller: category, decoration: const InputDecoration(labelText: 'Kategori')),
            const SizedBox(height: 9),
            TextField(controller: price, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Estimasi harga')),
            const SizedBox(height: 9),
            OutlinedButton.icon(
              onPressed: () async {
                final selected = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 80, maxWidth: 1600);
                if (selected != null) setState(() => image = selected);
              },
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: Text(image?.name ?? 'Pilih/ganti foto'),
            ),
          ]),
        ),
        actions: [
          TextButton(onPressed: loading ? null : () => Navigator.pop(dialogContext), child: const Text('Batal')),
          FilledButton(
            onPressed: loading ? null : () async {
              if (name.text.trim().isEmpty || int.tryParse(price.text) == null) return;
              setState(() => loading = true);
              try {
                var imageUrl = item?.imageUrl ?? '';
                if (image != null) imageUrl = await FirestoreService().uploadImage(image!, 'services/${user.id}');
                await FirestoreService().saveServiceListing(
                  id: item?.id,
                  partner: user,
                  name: name.text,
                  description: description.text,
                  category: category.text.isEmpty ? 'Lainnya' : category.text,
                  estimatedPrice: int.parse(price.text),
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
}

