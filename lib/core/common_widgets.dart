import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'app_theme.dart';

class AsyncView<T> extends StatelessWidget {
  const AsyncView({
    required this.snapshot,
    required this.builder,
    this.emptyMessage = 'Belum ada data.',
    this.isEmpty,
    super.key,
  });

  final AsyncSnapshot<T> snapshot;
  final Widget Function(T data) builder;
  final String emptyMessage;
  final bool Function(T data)? isEmpty;

  @override
  Widget build(BuildContext context) {
    if (snapshot.hasError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Terjadi kesalahan: ${snapshot.error}',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    if (!snapshot.hasData) {
      return const Center(child: CircularProgressIndicator());
    }
    final data = snapshot.data as T;
    if (isEmpty?.call(data) ?? false) {
      return Center(child: Text(emptyMessage, textAlign: TextAlign.center));
    }
    return builder(data);
  }
}

class StatusPill extends StatelessWidget {
  const StatusPill(this.status, {this.serviceType, super.key});

  final String status;
  final String? serviceType;

  @override
  Widget build(BuildContext context) {
    final normalized = status.toLowerCase();
    final isFood = serviceType == 'food';
    final color = switch (normalized) {
      'completed' || 'approved' || 'ready' => AppColors.primaryDark,
      'cancelled' || 'rejected' => AppColors.danger,
      _ => const Color(0xFFF59E0B),
    };
    final label = switch (normalized) {
      'searching' => isFood ? 'Mencari driver (UMKM proses)' : 'Mencari driver',
      'waiting_partner' => 'Menunggu mitra jasa',
      'waiting_merchant' => 'Menunggu UMKM',
      'pending_confirmation' => 'Menunggu konfirmasi pelanggan',
      'accepted' => 'Diterima',
      'driver_confirmed' => isFood ? 'Driver siap ke UMKM' : 'Driver dikonfirmasi',
      'heading_to_pickup' => isFood ? 'Menuju ke UMKM' : 'Menuju jemput',
      'at_pickup' => isFood ? 'Sampai di UMKM' : 'Di titik jemput',
      'picked_up' => 'Sudah dijemput',
      'preparing' => 'Disiapkan',
      'ready' => 'Siap',
      'on_delivery' => isFood ? 'Menuju lokasi pelanggan' : 'Diantar',
      'completed' => 'Selesai',
      'cancelled' => 'Dibatalkan',
      'pending' => 'Menunggu verifikasi',
      'approved' => 'Disetujui',
      'rejected' => 'Ditolak',
      _ => status,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

/// Returns the bottom system navigation bar inset even if a parent widget
/// already consumed [MediaQuery.padding].
double bottomSystemInset(BuildContext context) {
  final paddingBottom = MediaQuery.paddingOf(context).bottom;
  final viewPaddingBottom = MediaQuery.viewPaddingOf(context).bottom;
  return paddingBottom > viewPaddingBottom ? paddingBottom : viewPaddingBottom;
}

/// Red discount badge shown at the top-right corner of discounted products.
class ProductDiscountBadge extends StatelessWidget {
  const ProductDiscountBadge({required this.discountPercent, super.key});

  final int discountPercent;

  @override
  Widget build(BuildContext context) {
    if (discountPercent <= 0) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.danger,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$discountPercent%',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

/// Renders original strikethrough price (grey) + discounted price (green) when
/// [discountPercent] > 0, or just the normal green price otherwise.
class ProductPriceText extends StatelessWidget {
  const ProductPriceText({
    required this.originalPriceText,
    required this.finalPriceText,
    required this.hasDiscount,
    this.finalFontSize = 14.5,
    this.normalFontSize = 14.0,
    super.key,
  });

  final String originalPriceText;
  final String finalPriceText;
  final bool hasDiscount;
  final double finalFontSize;
  final double normalFontSize;

  @override
  Widget build(BuildContext context) {
    if (!hasDiscount) {
      return Text(
        originalPriceText,
        style: TextStyle(
          color: AppColors.primaryDark,
          fontWeight: FontWeight.w700,
          fontSize: normalFontSize,
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          originalPriceText,
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 11.5,
            fontWeight: FontWeight.w500,
            decoration: TextDecoration.lineThrough,
            decorationColor: Colors.grey,
            decorationThickness: 1.8,
          ),
        ),
        Text(
          finalPriceText,
          style: TextStyle(
            color: AppColors.primaryDark,
            fontWeight: FontWeight.w800,
            fontSize: finalFontSize,
          ),
        ),
      ],
    );
  }
}

void showMessage(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: error ? AppColors.danger : AppColors.primaryDark,
    ),
  );
}

Uint8List? decodeDataImageUri(String url) {
  final trimmed = url.trim();
  if (!trimmed.startsWith('data:image/')) return null;
  final marker = ';base64,';
  final idx = trimmed.indexOf(marker);
  if (idx == -1) return null;
  try {
    return base64Decode(trimmed.substring(idx + marker.length));
  } catch (_) {
    return null;
  }
}

ImageProvider? appImageProvider(String url) {
  final trimmed = url.trim();
  if (trimmed.isEmpty) return null;
  final bytes = decodeDataImageUri(trimmed);
  if (bytes != null) return MemoryImage(bytes);
  return NetworkImage(trimmed);
}

class FormErrorBox extends StatelessWidget {
  const FormErrorBox({required this.message, super.key});
  final String message;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: const Color(0xFFFEF2F2),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: const Color(0xFFFECACA)),
    ),
    child: Text(
      message,
      style: const TextStyle(color: Color(0xFFD92D20), fontSize: 12),
    ),
  );
}

class NetworkImageBox extends StatelessWidget {
  const NetworkImageBox({
    required this.url,
    this.height = 120,
    this.width,
    super.key,
  });
  final String url;
  final double height;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) {
      return Container(
        height: height,
        width: width,
        color: const Color(0xFFE8EFEC),
        child: const Icon(Icons.image_outlined, color: Colors.grey),
      );
    }
    Widget brokenBox(BuildContext _, Object _, StackTrace? _) => Container(
      height: height,
      width: width,
      color: const Color(0xFFE8EFEC),
      child: const Icon(Icons.broken_image_outlined),
    );
    final memoryBytes = decodeDataImageUri(trimmed);
    if (memoryBytes != null) {
      return Image.memory(
        memoryBytes,
        height: height,
        width: width,
        fit: BoxFit.cover,
        errorBuilder: brokenBox,
      );
    }
    return Image.network(
      trimmed,
      height: height,
      width: width,
      fit: BoxFit.cover,
      errorBuilder: brokenBox,
    );
  }
}
