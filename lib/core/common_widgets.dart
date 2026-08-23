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
  const StatusPill(this.status, {super.key});

  final String status;

  @override
  Widget build(BuildContext context) {
    final normalized = status.toLowerCase();
    final color = switch (normalized) {
      'completed' || 'approved' || 'ready' => AppColors.primary,
      'cancelled' || 'rejected' => AppColors.danger,
      _ => const Color(0xFFF59E0B),
    };
    final label = switch (normalized) {
      'searching' => 'Mencari driver',
      'pending_confirmation' => 'Menunggu konfirmasi pelanggan',
      'accepted' => 'Diterima',
      'driver_confirmed' => 'Driver dikonfirmasi',
      'heading_to_pickup' => 'Menuju jemput',
      'picked_up' => 'Sudah dijemput',
      'preparing' => 'Disiapkan',
      'ready' => 'Siap',
      'on_delivery' => 'Diantar',
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

void showMessage(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: error ? AppColors.danger : AppColors.primaryDark,
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
    if (url.isEmpty) {
      return Container(
        height: height,
        width: width,
        color: const Color(0xFFE8EFEC),
        child: const Icon(Icons.image_outlined, color: Colors.grey),
      );
    }
    return Image.network(
      url,
      height: height,
      width: width,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(
        height: height,
        width: width,
        color: const Color(0xFFE8EFEC),
        child: const Icon(Icons.broken_image_outlined),
      ),
    );
  }
}
