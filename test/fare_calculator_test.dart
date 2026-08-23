import 'package:flutter_test/flutter_test.dart';
import 'package:gobran/core/formatters.dart';

void main() {
  group('FareCalculator', () {
    test('tarif sampai dua kilometer tetap Rp10.000', () {
      expect(FareCalculator.calculate(0.2), 10000);
      expect(FareCalculator.calculate(2), 10000);
    });

    test('kilometer tambahan dibulatkan ke atas', () {
      expect(FareCalculator.calculate(2.1), 15000);
      expect(FareCalculator.calculate(3), 15000);
      expect(FareCalculator.calculate(3.2), 20000);
    });

    test('menerima konfigurasi tarif admin', () {
      expect(FareCalculator.calculate(4, firstTwoKmFare: 12000, additionalPerKm: 6000), 24000);
    });
  });
}

