import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/common_widgets.dart';
import '../../models/app_models.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({required this.user, super.key});
  final AppUser user;

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 5,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Admin GoBran'),
        actions: [IconButton(onPressed: AuthService().signOut, icon: const Icon(Icons.logout))],
        bottom: const TabBar(
          isScrollable: true,
          tabs: [
            Tab(text: 'Verifikasi'),
            Tab(text: 'Berita & Promosi'),
            Tab(text: 'Darurat'),
            Tab(text: 'Zona'),
            Tab(text: 'Tarif & QRIS'),
          ],
        ),
      ),
      body: const TabBarView(
        children: [_VerificationTab(), _ContentAdminTab(), _EmergencyAdminTab(), _ZoneAdminTab(), _PricingAdminTab()],
      ),
    ),
  );
}

class _VerificationTab extends StatelessWidget {
  const _VerificationTab();
  @override
  Widget build(BuildContext context) => StreamBuilder<List<AppUser>>(
    stream: FirestoreService().watchPendingPartners(),
    builder: (context, snapshot) => AsyncView<List<AppUser>>(
      snapshot: snapshot,
      isEmpty: (items) => items.isEmpty,
      emptyMessage: 'Tidak ada mitra yang menunggu verifikasi.',
      builder: (items) => ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final user = items[index];
          return Card(
            child: ExpansionTile(
              leading: CircleAvatar(child: Icon(switch (user.role) { AppRole.driver => Icons.two_wheeler, AppRole.umkm => Icons.storefront, _ => Icons.home_repair_service })),
              title: Text(user.name, style: const TextStyle(fontWeight: FontWeight.w900)),
              subtitle: Text('${user.role.label} • ${user.email}\nZona ${user.zoneId}'),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              children: [
                for (final entry in user.extra.entries)
                  if (!entry.key.endsWith('_url'))
                    ListTile(dense: true, title: Text(entry.key.replaceAll('_', ' ')), subtitle: Text('${entry.value}')),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: user.extra.entries.where((e) => e.key.endsWith('_url') && '${e.value}'.isNotEmpty).map((entry) => OutlinedButton.icon(
                    onPressed: () => showDialog<void>(context: context, builder: (_) => Dialog(child: InteractiveViewer(child: NetworkImageBox(url: '${entry.value}', height: 520)))),
                    icon: const Icon(Icons.image_outlined),
                    label: Text(entry.key.replaceAll('_url', '').replaceAll('_', ' ')),
                  )).toList(),
                ),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: OutlinedButton(onPressed: () => FirestoreService().verifyPartner(user.id, 'rejected'), child: const Text('Tolak'))),
                  const SizedBox(width: 10),
                  Expanded(child: FilledButton(onPressed: () => FirestoreService().verifyPartner(user.id, 'approved'), child: const Text('Setujui'))),
                ]),
              ],
            ),
          );
        },
      ),
    ),
  );
}

class _ContentAdminTab extends StatelessWidget {
  const _ContentAdminTab();
  @override
  Widget build(BuildContext context) => Stack(
    children: [
      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirestoreService().watchAdminCollection('content'),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snapshot.data!.docs;
          if (docs.isEmpty) return const Center(child: Text('Belum ada berita atau promosi.'));
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 9),
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data();
              return Card(
                child: ListTile(
                  leading: Icon(data['type'] == 'news' ? Icons.newspaper : Icons.local_offer),
                  title: Text(data['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.w900)),
                  subtitle: Text('${data['type'] == 'news' ? 'Berita' : 'Promosi'} • ${data['is_published'] == true ? 'Terbit' : 'Draft'}'),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) => value == 'edit' ? _editContent(context, doc: doc) : FirestoreService().deleteAdminDocument('content', doc.id),
                    itemBuilder: (_) => const [PopupMenuItem(value: 'edit', child: Text('Edit')), PopupMenuItem(value: 'delete', child: Text('Hapus'))],
                  ),
                ),
              );
            },
          );
        },
      ),
      Positioned(
        right: 18,
        bottom: 18,
        child: FloatingActionButton.extended(heroTag: 'admin_content', onPressed: () => _editContent(context), icon: const Icon(Icons.add), label: const Text('Konten')),
      ),
    ],
  );
}

Future<void> _editContent(BuildContext context, {QueryDocumentSnapshot<Map<String, dynamic>>? doc}) async {
  final old = doc?.data() ?? <String, dynamic>{};
  final title = TextEditingController(text: old['title']);
  final summary = TextEditingController(text: old['summary']);
  final body = TextEditingController(text: old['body']);
  String type = old['type'] ?? 'news';
  String category = old['category'] ?? 'lainnya';
  bool published = old['is_published'] ?? true;
  XFile? image;
  var loading = false;
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text(doc == null ? 'Tambah konten' : 'Edit konten'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            DropdownButtonFormField<String>(
              initialValue: type,
              decoration: const InputDecoration(labelText: 'Jenis'),
              items: const [DropdownMenuItem(value: 'news', child: Text('Berita')), DropdownMenuItem(value: 'promotion', child: Text('Promosi'))],
              onChanged: (value) => setState(() => type = value ?? 'news'),
            ),
            const SizedBox(height: 9),
            TextField(controller: title, decoration: const InputDecoration(labelText: 'Judul')),
            const SizedBox(height: 9),
            TextField(controller: summary, maxLines: 2, decoration: const InputDecoration(labelText: 'Cuplikan singkat')),
            const SizedBox(height: 9),
            TextField(controller: body, maxLines: 6, decoration: const InputDecoration(labelText: 'Isi lengkap')),
            const SizedBox(height: 9),
            if (type == 'promotion')
              DropdownButtonFormField<String>(
                initialValue: category,
                decoration: const InputDecoration(labelText: 'Kategori promosi'),
                items: const ['makanan', 'jasa', 'ojek', 'lainnya'].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
                onChanged: (value) => category = value ?? 'lainnya',
              ),
            SwitchListTile(contentPadding: EdgeInsets.zero, value: published, onChanged: (value) => setState(() => published = value), title: const Text('Publikasikan')),
            OutlinedButton.icon(
              onPressed: () async {
                final selected = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 80, maxWidth: 1800);
                if (selected != null) setState(() => image = selected);
              },
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: Text(image?.name ?? 'Pilih/ganti gambar'),
            ),
          ]),
        ),
        actions: [
          TextButton(onPressed: loading ? null : () => Navigator.pop(dialogContext), child: const Text('Batal')),
          FilledButton(
            onPressed: loading ? null : () async {
              if (title.text.trim().isEmpty || body.text.trim().isEmpty) return;
              setState(() => loading = true);
              try {
                var imageUrl = old['image_url'] ?? '';
                if (image != null) imageUrl = await FirestoreService().uploadImage(image!, 'content');
                await FirestoreService().saveAdminDocument('content', {
                  'type': type,
                  'title': title.text.trim(),
                  'summary': summary.text.trim(),
                  'body': body.text.trim(),
                  'category': type == 'promotion' ? category : 'berita',
                  'image_url': imageUrl,
                  'is_published': published,
                  'published_at': old['published_at'] ?? FieldValue.serverTimestamp(),
                }, id: doc?.id);
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
  title.dispose();
  summary.dispose();
  body.dispose();
}

class _EmergencyAdminTab extends StatelessWidget {
  const _EmergencyAdminTab();
  @override
  Widget build(BuildContext context) => _SimpleCollectionAdmin(
    collection: 'emergency_contacts',
    emptyText: 'Belum ada kontak darurat.',
    addLabel: 'Kontak',
    icon: Icons.emergency_outlined,
    title: (data) => data['name'] ?? '',
    subtitle: (data) => '${data['category'] ?? ''} • ${data['phone'] ?? ''}',
    onEdit: _editEmergency,
  );
}

Future<void> _editEmergency(BuildContext context, {QueryDocumentSnapshot<Map<String, dynamic>>? doc}) async {
  final old = doc?.data() ?? <String, dynamic>{};
  final name = TextEditingController(text: old['name']);
  final phone = TextEditingController(text: old['phone']);
  String category = old['category'] ?? 'sakit';
  await showDialog<void>(context: context, builder: (dialogContext) => StatefulBuilder(builder: (context, setState) => AlertDialog(
    title: const Text('Kontak darurat'),
    content: Column(mainAxisSize: MainAxisSize.min, children: [
      TextField(controller: name, decoration: const InputDecoration(labelText: 'Nama instansi')),
      const SizedBox(height: 9),
      TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Nomor telepon')),
      const SizedBox(height: 9),
      DropdownButtonFormField<String>(
        initialValue: category,
        decoration: const InputDecoration(labelText: 'Kategori'),
        items: const ['sakit', 'kebakaran', 'kecelakaan'].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
        onChanged: (value) => setState(() => category = value ?? 'sakit'),
      ),
    ]),
    actions: [
      TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Batal')),
      FilledButton(onPressed: () async {
        await FirestoreService().saveAdminDocument('emergency_contacts', {'name': name.text.trim(), 'phone': phone.text.trim(), 'category': category}, id: doc?.id);
        if (dialogContext.mounted) Navigator.pop(dialogContext);
      }, child: const Text('Simpan')),
    ],
  )));
  name.dispose();
  phone.dispose();
}

class _ZoneAdminTab extends StatelessWidget {
  const _ZoneAdminTab();
  @override
  Widget build(BuildContext context) => _SimpleCollectionAdmin(
    collection: 'zones',
    emptyText: 'Belum ada zona. Tambahkan Babalan sebagai zona pertama.',
    addLabel: 'Zona',
    icon: Icons.map_outlined,
    title: (data) => data['name'] ?? '',
    subtitle: (data) => data['is_active'] == false ? 'Tidak aktif' : 'Aktif',
    onEdit: _editZone,
  );
}

Future<void> _editZone(BuildContext context, {QueryDocumentSnapshot<Map<String, dynamic>>? doc}) async {
  final old = doc?.data() ?? <String, dynamic>{};
  final name = TextEditingController(text: old['name']);
  bool active = old['is_active'] ?? true;
  await showDialog<void>(context: context, builder: (dialogContext) => StatefulBuilder(builder: (context, setState) => AlertDialog(
    title: const Text('Zona layanan'),
    content: Column(mainAxisSize: MainAxisSize.min, children: [
      TextField(controller: name, decoration: const InputDecoration(labelText: 'Nama zona')),
      SwitchListTile(contentPadding: EdgeInsets.zero, value: active, onChanged: (value) => setState(() => active = value), title: const Text('Zona aktif')),
    ]),
    actions: [
      TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Batal')),
      FilledButton(onPressed: () async {
        await FirestoreService().saveAdminDocument('zones', {'name': name.text.trim(), 'is_active': active}, id: doc?.id ?? (name.text.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '-')));
        if (dialogContext.mounted) Navigator.pop(dialogContext);
      }, child: const Text('Simpan')),
    ],
  )));
  name.dispose();
}

class _SimpleCollectionAdmin extends StatelessWidget {
  const _SimpleCollectionAdmin({required this.collection, required this.emptyText, required this.addLabel, required this.icon, required this.title, required this.subtitle, required this.onEdit});
  final String collection;
  final String emptyText;
  final String addLabel;
  final IconData icon;
  final String Function(Map<String, dynamic>) title;
  final String Function(Map<String, dynamic>) subtitle;
  final Future<void> Function(BuildContext, {QueryDocumentSnapshot<Map<String, dynamic>>? doc}) onEdit;
  @override
  Widget build(BuildContext context) => Stack(children: [
    StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirestoreService().watchAdminCollection(collection),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) return Center(child: Text(emptyText));
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 9),
          itemBuilder: (context, index) {
            final doc = docs[index];
            return Card(child: ListTile(
              leading: Icon(icon),
              title: Text(title(doc.data()), style: const TextStyle(fontWeight: FontWeight.w900)),
              subtitle: Text(subtitle(doc.data())),
              trailing: PopupMenuButton<String>(
                onSelected: (value) => value == 'edit' ? onEdit(context, doc: doc) : FirestoreService().deleteAdminDocument(collection, doc.id),
                itemBuilder: (_) => const [PopupMenuItem(value: 'edit', child: Text('Edit')), PopupMenuItem(value: 'delete', child: Text('Hapus'))],
              ),
            ));
          },
        );
      },
    ),
    Positioned(right: 18, bottom: 18, child: FloatingActionButton.extended(heroTag: collection, onPressed: () => onEdit(context), icon: const Icon(Icons.add), label: Text(addLabel))),
  ]);
}

class _PricingAdminTab extends StatefulWidget {
  const _PricingAdminTab();
  @override
  State<_PricingAdminTab> createState() => _PricingAdminTabState();
}

class _PricingAdminTabState extends State<_PricingAdminTab> {
  final _first = TextEditingController();
  final _additional = TextEditingController();
  bool _loaded = false;
  bool _saving = false;
  String _qrisUrl = '';

  @override
  void dispose() {
    _first.dispose();
    _additional.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<PricingConfig>(
    stream: FirestoreService().watchPricing(),
    initialData: const PricingConfig(),
    builder: (context, snapshot) {
      final pricing = snapshot.data ?? const PricingConfig();
      if (!_loaded) {
        _loaded = true;
        _first.text = '${pricing.firstTwoKmFare}';
        _additional.text = '${pricing.additionalPerKm}';
        _qrisUrl = pricing.qrisImageUrl;
      }
      return ListView(
        padding: const EdgeInsets.all(18),
        children: [
          const Text('Aturan tarif Ojek & Express', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
          const SizedBox(height: 14),
          TextField(controller: _first, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Tarif 0–2 km')),
          const SizedBox(height: 12),
          TextField(controller: _additional, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Tarif per km tambahan')),
          const SizedBox(height: 22),
          const Text('QRIS manual', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          if (_qrisUrl.isNotEmpty) Center(child: NetworkImageBox(url: _qrisUrl, height: 260, width: 260)),
          OutlinedButton.icon(
            onPressed: () async {
              final image = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 90, maxWidth: 1600);
              if (image == null) return;
              final url = await FirestoreService().uploadImage(image, 'config');
              if (mounted) setState(() => _qrisUrl = url);
            },
            icon: const Icon(Icons.qr_code_2),
            label: Text(_qrisUrl.isEmpty ? 'Unggah gambar QRIS' : 'Ganti gambar QRIS'),
          ),
          const SizedBox(height: 18),
          ElevatedButton(
            onPressed: _saving ? null : () async {
              setState(() => _saving = true);
              await FirestoreService().saveAdminDocument('app_config', {
                'first_two_km_fare': int.tryParse(_first.text) ?? 10000,
                'additional_per_km': int.tryParse(_additional.text) ?? 5000,
                'qris_image_url': _qrisUrl,
              }, id: 'pricing');
              if (mounted) {
                setState(() => _saving = false);
                showMessage(context, 'Tarif dan QRIS berhasil disimpan.');
              }
            },
            child: _saving ? const CircularProgressIndicator() : const Text('Simpan pengaturan'),
          ),
        ],
      );
    },
  );
}
