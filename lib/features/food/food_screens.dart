import 'package:flutter/material.dart';

import '../../core/common_widgets.dart';
import '../../core/formatters.dart';
import '../../models/app_models.dart';
import '../../services/firestore_service.dart';
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

  int get itemCount => _quantities.values.fold(0, (sum, value) => sum + value);
  int get total => _quantities.entries.fold(
    0,
    (sum, entry) => sum + (_selected[entry.key]?.price ?? 0) * entry.value,
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
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: .63,
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
                          NetworkImageBox(
                            url: product.imageUrl,
                            height: 115,
                            width: double.infinity,
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
                                  Text(
                                    rupiah(product.price),
                                    style: const TextStyle(
                                      color: Color(0xFF087F5B),
                                      fontWeight: FontWeight.w900,
                                    ),
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
    bottomSheet: itemCount == 0
        ? null
        : SafeArea(
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              decoration: const BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(color: Color(0x22000000), blurRadius: 12),
                ],
              ),
              child: ElevatedButton(
                onPressed: _checkout,
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: Colors.white24,
                      child: Text(
                        '$itemCount',
                        style: const TextStyle(color: Colors.white),
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
          ),
  );

  Future<void> _checkout() async {
    final address = TextEditingController();
    final note = TextEditingController();
    String payment = 'cash';
    var loading = false;
    final orderId = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Checkout makanan'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ..._quantities.entries.map((entry) {
                  final p = _selected[entry.key]!;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(p.name),
                    subtitle: Text('${entry.value} × ${rupiah(p.price)}'),
                  );
                }),
                const Divider(),
                TextField(
                  controller: address,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Alamat pengantaran',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: note,
                  decoration: const InputDecoration(
                    labelText: 'Catatan lokasi/pesanan',
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: payment,
                  decoration: const InputDecoration(labelText: 'Pembayaran'),
                  items: const [
                    DropdownMenuItem(value: 'cash', child: Text('Tunai')),
                    DropdownMenuItem(value: 'qris', child: Text('QRIS manual')),
                  ],
                  onChanged: (value) => payment = value ?? 'cash',
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    'Total ${rupiah(total)}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: loading ? null : () => Navigator.pop(dialogContext),
              child: const Text('Kembali'),
            ),
            FilledButton(
              onPressed: loading
                  ? null
                  : () async {
                      if (address.text.trim().isEmpty) {
                        showMessage(
                          context,
                          'Alamat pengantaran wajib diisi.',
                          error: true,
                        );
                        return;
                      }
                      setDialogState(() => loading = true);
                      try {
                        final first = _selected.values.first;
                        final id = await FirestoreService().createFoodOrder(
                          customer: widget.user,
                          merchantId: first.merchantId,
                          merchantName: first.merchantName,
                          items: _quantities.entries.map((entry) {
                            final product = _selected[entry.key]!;
                            return {
                              'product_id': product.id,
                              'name': product.name,
                              'price': product.price,
                              'quantity': entry.value,
                            };
                          }).toList(),
                          total: total,
                          destination: AddressPoint(
                            latitude: 0,
                            longitude: 0,
                            address: address.text.trim(),
                            note: note.text.trim(),
                          ),
                          paymentMethod: payment,
                        );
                        if (dialogContext.mounted) {
                          Navigator.pop(dialogContext, id);
                        }
                      } catch (e) {
                        if (context.mounted) {
                          showMessage(context, '$e', error: true);
                        }
                        setDialogState(() => loading = false);
                      }
                    },
              child: loading
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(),
                    )
                  : const Text('Buat pesanan'),
            ),
          ],
        ),
      ),
    );
    address.dispose();
    note.dispose();
    if (orderId != null && mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => OrderDetailScreen(orderId: orderId)),
      );
    }
  }
}
