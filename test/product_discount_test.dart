import 'package:flutter_test/flutter_test.dart';
import 'package:gobran/models/app_models.dart';

Product _makeProduct({required int price, int discountPercent = 0}) => Product(
  id: 'p1',
  merchantId: 'm1',
  merchantName: 'Kedai Eceran',
  name: 'Roti',
  description: '',
  category: 'Makanan',
  price: price,
  stock: 5,
  imageUrl: '',
  isActive: true,
  discountPercent: discountPercent,
);

void main() {
  test('Product menghitung harga setelah diskon dengan tepat', () {
    final p50 = _makeProduct(price: 60000, discountPercent: 50);
    expect(p50.hasDiscount, isTrue);
    expect(p50.discountedPrice, 30000);

    final p25 = _makeProduct(price: 20000, discountPercent: 25);
    expect(p25.discountedPrice, 15000);
  });

  test('Product tanpa diskon mempertahankan harga asli', () {
    final p0 = _makeProduct(price: 25000, discountPercent: 0);
    expect(p0.hasDiscount, isFalse);
    expect(p0.discountedPrice, 25000);
  });
}
