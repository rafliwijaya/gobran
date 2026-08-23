import 'dart:math' as math;

import 'package:intl/intl.dart';

final _rupiah = NumberFormat.currency(
  locale: 'id_ID',
  symbol: 'Rp',
  decimalDigits: 0,
);

String rupiah(num value) => _rupiah.format(value);
String shortDate(DateTime value) => DateFormat('dd MMM yyyy, HH:mm', 'id_ID').format(value);

abstract final class FareCalculator {
  static int calculate(
    double distanceKm, {
    int firstTwoKmFare = 10000,
    int additionalPerKm = 5000,
  }) {
    if (distanceKm <= 2) return firstTwoKmFare;
    final additionalKm = math.max(1, (distanceKm - 2).ceil());
    return firstTwoKmFare + additionalKm * additionalPerKm;
  }
}

