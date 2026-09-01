import 'package:flutter/material.dart';

import '../../core/common_widgets.dart';
import '../../core/formatters.dart';
import '../../models/app_models.dart';
import '../../services/firestore_service.dart';
import '../order/order_detail_screen.dart';

class ServiceMarketplaceScreen extends StatelessWidget {
  const ServiceMarketplaceScreen({required this.user, super.key});
  final AppUser user;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Layanan Jasa')),
    body: StreamBuilder<List<ServiceListing>>(
      stream: FirestoreService().watchServiceListings(),
      builder: (context, snapshot) => AsyncView<List<ServiceListing>>(
        snapshot: snapshot,
        isEmpty: (items) => items.isEmpty,
        emptyMessage: 'Belum ada mitra jasa yang menawarkan layanan.',
        builder: (all) {
          final items = all
              .where(
                (item) => item.zoneId.isEmpty || item.zoneId == user.zoneId,
              )
              .toList();
          return ListView.separated(
            padding: const EdgeInsets.all(18),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final item = items[index];
              return Card(
                clipBehavior: Clip.antiAlias,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    NetworkImageBox(
                      url: item.imageUrl,
                      height: 170,
                      width: double.infinity,
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.name,
                            style: const TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            '${item.category} • ${item.partnerName}',
                            style: const TextStyle(color: Colors.grey),
                          ),
                          const SizedBox(height: 8),
                          Text(item.description),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Estimasi ${rupiah(item.estimatedPrice)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              FilledButton(
                                onPressed: () => _request(context, item),
                                child: const Text('Minta jasa'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    ),
  );

  Future<void> _request(BuildContext context, ServiceListing listing) async {
    final address = TextEditingController();
    final note = TextEditingController();
    final id = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Minta ${listing.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: address,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Alamat layanan'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: note,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Jelaskan kebutuhan Anda',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () async {
              if (address.text.trim().isEmpty || note.text.trim().isEmpty) {
                return;
              }
              final orderId = await FirestoreService().createServiceRequest(
                customer: user,
                listing: listing,
                address: address.text,
                note: note.text,
              );
              if (dialogContext.mounted) Navigator.pop(dialogContext, orderId);
            },
            child: const Text('Kirim permintaan'),
          ),
        ],
      ),
    );
    address.dispose();
    note.dispose();
    if (id != null && context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => OrderDetailScreen(orderId: id)),
      );
    }
  }
}
