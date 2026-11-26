import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/app_theme.dart';
import '../../core/common_widgets.dart';
import '../../core/formatters.dart';
import '../../models/app_models.dart';
import '../../services/firestore_service.dart';
import '../order/order_detail_screen.dart';

class ContentListScreen extends StatelessWidget {
  const ContentListScreen({required this.type, super.key});
  final String type;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: StreamBuilder<List<ContentItem>>(
      stream: FirestoreService().watchContent(type),
      builder: (context, snapshot) => AsyncView<List<ContentItem>>(
        snapshot: snapshot,
        isEmpty: (items) => items.isEmpty,
        emptyMessage: 'Belum ada konten.',
        builder: (items) => ListView.separated(
          padding: const EdgeInsets.all(18),
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (_, index) => _ContentCard(item: items[index]),
        ),
      ),
    ),
  );
}

class OrdersScreen extends StatelessWidget {
  const OrdersScreen({super.key});

  static const _activeStatuses = [
    'searching',
    'waiting_partner',
    'waiting_merchant',
    'preparing',
    'ready',
    'pending_confirmation',
    'accepted',
    'driver_confirmed',
    'heading_to_pickup',
    'at_pickup',
    'picked_up',
    'on_delivery',
  ];

  @override
  Widget build(BuildContext context) => SafeArea(
    child: StreamBuilder<List<AppOrder>>(
      stream: FirestoreService().watchCustomerHistory(),
      builder: (context, snapshot) => AsyncView<List<AppOrder>>(
        snapshot: snapshot,
        isEmpty: (items) => items.isEmpty,
        emptyMessage: 'Belum ada pesanan.',
        builder: (items) {
          final activeOrders =
              items
                  .where((order) => _activeStatuses.contains(order.status))
                  .toList()
                ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
          if (activeOrders.isEmpty) {
            return const Center(
              child: Text('Tidak ada pesanan yang sedang berjalan.'),
            );
          }
          return ListView.separated(
            padding: EdgeInsets.fromLTRB(
              18,
              18,
              18,
              96 + bottomSystemInset(context),
            ),
            itemCount: activeOrders.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) =>
                _ActiveOrderCard(order: activeOrders[index]),
          );
        },
      ),
    ),
  );
}

class _ActiveOrderCard extends StatelessWidget {
  const _ActiveOrderCard({required this.order});

  final AppOrder order;

  @override
  Widget build(BuildContext context) {
    final foodSummary = order.serviceType == 'food'
        ? '${order.meta['merchant_name'] ?? 'UMKM'} • ${order.items.length} menu'
        : null;
    return Card(
      elevation: 0,
      color: AppColors.primaryLight,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.primary.withValues(alpha: .45)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OrderDetailScreen(orderId: order.id),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: AppColors.primary.withValues(alpha: .25),
                    child: Icon(
                      _serviceIcon(order.serviceType),
                      fill: 1,
                      color: AppColors.primaryDark,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _serviceLabel(order.serviceType),
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          shortDate(order.createdAt),
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(
                    Symbols.route_rounded,
                    fill: 1,
                    color: AppColors.primaryDark,
                    size: 19,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      foodSummary ??
                          ((order.meta['listing_name']
                                      ?.toString()
                                      .trim()
                                      .isNotEmpty ??
                                  false)
                              ? order.meta['listing_name'].toString()
                              : 'Order sedang diproses'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  Text(
                    rupiah(order.fare),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: .45),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Symbols.moped_rounded,
                      fill: 1,
                      size: 18,
                      color: AppColors.primaryDark,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        order.customerProgressLabel,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.center,
                child: StatusPill(
                  order.status,
                  serviceType: order.serviceType,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PromotionScreen extends StatefulWidget {
  const PromotionScreen({super.key});
  @override
  State<PromotionScreen> createState() => _PromotionScreenState();
}

class _PromotionScreenState extends State<PromotionScreen> {
  String _category = 'semua';

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Column(
      children: [
        StreamBuilder<List<ContentItem>>(
          stream: FirestoreService().watchContent('promotion'),
          builder: (context, snapshot) {
            final categories = <String>{
              'semua',
              ...?snapshot.data
                  ?.map((item) => item.category)
                  .where((value) => value.isNotEmpty),
            }.toList();
            return SizedBox(
              height: 56,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                scrollDirection: Axis.horizontal,
                itemCount: categories.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (_, index) {
                  final value = categories[index];
                  return ChoiceChip(
                    label: Text(value[0].toUpperCase() + value.substring(1)),
                    selected: _category == value,
                    onSelected: (_) => setState(() => _category = value),
                  );
                },
              ),
            );
          },
        ),
        Expanded(
          child: StreamBuilder<List<ContentItem>>(
            stream: FirestoreService().watchContent('promotion'),
            builder: (context, snapshot) => AsyncView<List<ContentItem>>(
              snapshot: snapshot,
              isEmpty: (items) => items.isEmpty,
              emptyMessage: 'Belum ada promosi pada kategori ini.',
              builder: (all) {
                final items = _category == 'semua'
                    ? all
                    : all.where((item) => item.category == _category).toList();
                return ListView.separated(
                  padding: const EdgeInsets.all(18),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (_, index) => _ContentCard(item: items[index]),
                );
              },
            ),
          ),
        ),
      ],
    ),
  );
}

class _ContentCard extends StatelessWidget {
  const _ContentCard({required this.item});
  final ContentItem item;
  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ContentDetailScreen(item: item)),
      ),
      child: Row(
        children: [
          NetworkImageBox(url: item.imageUrl, height: 112, width: 118),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    item.summary,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    shortDate(item.publishedAt),
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class ContentDetailScreen extends StatelessWidget {
  const ContentDetailScreen({required this.item, super.key});
  final ContentItem item;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(item.type == 'news' ? 'Berita' : 'Promosi')),
    body: ListView(
      children: [
        NetworkImageBox(
          url: item.imageUrl,
          height: 240,
          width: double.infinity,
        ),
        Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.title,
                style: const TextStyle(
                  fontSize: 27,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                shortDate(item.publishedAt),
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 20),
              Text(
                item.body,
                style: const TextStyle(fontSize: 16, height: 1.6),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  static const _historyStatuses = ['completed', 'cancelled', 'rejected'];

  @override
  Widget build(BuildContext context) => SafeArea(
    bottom: false,
    child: StreamBuilder<List<AppOrder>>(
      stream: FirestoreService().watchCustomerHistory(),
      builder: (context, snapshot) => AsyncView<List<AppOrder>>(
        snapshot: snapshot,
        isEmpty: (items) => items.isEmpty,
        emptyMessage: 'Belum ada aktifitas pemesanan.',
        builder: (items) {
          final activeOrders =
              items
                  .where((order) => OrdersScreen._activeStatuses.contains(order.status))
                  .toList()
                ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
          final history =
              items
                  .where((order) => _historyStatuses.contains(order.status))
                  .toList()
                ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
          if (activeOrders.isEmpty && history.isEmpty) {
            return const Center(
              child: Text('Belum ada aktifitas pemesanan.'),
            );
          }
          return ListView(
            padding: EdgeInsets.fromLTRB(
              18,
              18,
              18,
              96 + bottomSystemInset(context),
            ),
            children: [
              if (activeOrders.isNotEmpty) ...[
                const Text(
                  'Pesanan Sedang Berlangsung',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 10),
                for (var i = 0; i < activeOrders.length; i++) ...[
                  if (i > 0) const SizedBox(height: 10),
                  _ActiveOrderCard(order: activeOrders[i]),
                ],
                if (history.isNotEmpty) const SizedBox(height: 22),
              ],
              if (history.isNotEmpty) ...[
                if (activeOrders.isNotEmpty) ...[
                  const Text(
                    'Riwayat Selesai',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                for (var i = 0; i < history.length; i++) ...[
                  if (i > 0) const SizedBox(height: 10),
                  _HistoryOrderCard(order: history[i]),
                ],
              ],
            ],
          );
        },
      ),
    ),
  );
}

class _HistoryOrderCard extends StatelessWidget {
  const _HistoryOrderCard({required this.order});

  final AppOrder order;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OrderDetailScreen(orderId: order.id),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: AppColors.primaryLight,
                foregroundColor: AppColors.primaryDark,
                child: Icon(
                  _serviceIcon(order.serviceType),
                  fill: 1,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _serviceLabel(order.serviceType),
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      shortDate(order.createdAt),
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      rupiah(order.fare),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 118,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: StatusPill(
                    order.status,
                    serviceType: order.serviceType,
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

class QrisMaintenanceScreen extends StatelessWidget {
  const QrisMaintenanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'web/icons/pemeliharaan.png',
                width: 230,
                height: 230,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 18),
              const Text(
                'Maaf ya, halaman lagi  gak ada..',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Tim pengembang sedang memberikan pelayanan yang terbaik buat kamu.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13.5,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class InboxScreen extends StatelessWidget {
  const InboxScreen({super.key});

  bool _isStandalone(BuildContext context) => Navigator.canPop(context);

  @override
  Widget build(BuildContext context) {
    final standalone = _isStandalone(context);

    final content = StreamBuilder<List<InboxMessage>>(
      stream: FirestoreService().watchInbox(),
      builder: (context, snapshot) => AsyncView<List<InboxMessage>>(
        snapshot: snapshot,
        isEmpty: (items) => items.isEmpty,
        emptyMessage: 'Belum ada pesan masuk.',
        builder: (items) => ListView.separated(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final item = items[index];
            return Card(
              elevation: 0,
              color: item.isRead ? Colors.white : AppColors.primaryLight,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(
                  color: item.isRead
                      ? Colors.grey.shade200
                      : AppColors.primary.withValues(alpha: 0.45),
                ),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: item.isRead
                        ? Colors.grey.shade100
                        : AppColors.primary.withValues(alpha: 0.25),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    item.isRead
                        ? Symbols.notifications_rounded
                        : Symbols.notifications_active_rounded,
                    fill: item.isRead ? 0 : 1,
                    color: item.isRead
                        ? Colors.grey.shade500
                        : AppColors.primaryDark,
                    size: 22,
                  ),
                ),
                title: Text(
                  item.title,
                  style: TextStyle(
                    fontWeight: item.isRead ? FontWeight.w600 : FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '${item.message}\n${shortDate(item.createdAt)}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ),
                isThreeLine: true,
                onTap: () async {
                  await FirestoreService().markInboxRead(item.id);
                  if (item.orderId.isNotEmpty && context.mounted) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            OrderDetailScreen(orderId: item.orderId),
                      ),
                    );
                  }
                },
              ),
            );
          },
        ),
      ),
    );

    // Jika dibuka standalone via Navigator.push, bungkus dengan Scaffold lengkap
    if (standalone) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(
              Symbols.arrow_back_ios_new_rounded,
              color: Color(0xFF1A1A1A),
              size: 20,
            ),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text(
            'Notifikasi',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A1A1A),
            ),
          ),
          centerTitle: true,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Divider(height: 1, color: Colors.grey.shade200),
          ),
        ),
        body: content,
      );
    }

    // Jika di dalam IndexedStack shell (tab), tampil seperti biasa tanpa Scaffold
    return SafeArea(bottom: false, child: content);
  }
}

String _serviceLabel(String type) => switch (type) {
  'ojek' => 'Ojek',
  'express' => 'Express',
  'food' => 'Makanan',
  'service' => 'Jasa',
  _ => type,
};

IconData _serviceIcon(String type) => switch (type) {
  'ojek' => Symbols.moped_rounded,
  'express' => Symbols.local_shipping_rounded,
  'food' => Symbols.restaurant_rounded,
  'service' => Symbols.home_repair_service_rounded,
  _ => Symbols.receipt_long_rounded,
};
