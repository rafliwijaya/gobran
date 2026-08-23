import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/common_widgets.dart';
import '../../models/app_models.dart';
import '../../services/firestore_service.dart';

class EmergencyScreen extends StatelessWidget {
  const EmergencyScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Kontak Darurat')),
    body: StreamBuilder<List<EmergencyContact>>(
      stream: FirestoreService().watchEmergencyContacts(),
      builder: (context, snapshot) => AsyncView<List<EmergencyContact>>(
        snapshot: snapshot,
        isEmpty: (items) => items.isEmpty,
        emptyMessage: 'Kontak darurat belum ditambahkan admin.',
        builder: (items) {
          final groups = <String, List<EmergencyContact>>{};
          for (final item in items) {
            groups.putIfAbsent(item.category, () => []).add(item);
          }
          return ListView(
            padding: const EdgeInsets.all(18),
            children: [
              const Card(
                color: Color(0xFFFFF3F1),
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Color(0xFFD92D20)),
                      SizedBox(width: 12),
                      Expanded(child: Text('Gunakan nomor ini hanya pada keadaan darurat yang sebenarnya.')),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              for (final category in ['sakit', 'kebakaran', 'kecelakaan']) ...[
                Text(_label(category), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                const SizedBox(height: 9),
                if ((groups[category] ?? []).isEmpty)
                  const Padding(padding: EdgeInsets.only(bottom: 18), child: Text('Belum ada nomor.'))
                else
                  ...groups[category]!.map((item) => Padding(
                    padding: const EdgeInsets.only(bottom: 9),
                    child: Card(
                      child: ListTile(
                        leading: CircleAvatar(backgroundColor: _color(category).withValues(alpha: .12), child: Icon(_icon(category), color: _color(category))),
                        title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                        subtitle: Text(item.phone),
                        trailing: FilledButton.tonalIcon(
                          onPressed: () => launchUrl(Uri(scheme: 'tel', path: item.phone)),
                          icon: const Icon(Icons.call),
                          label: const Text('Hubungi'),
                        ),
                      ),
                    ),
                  )),
                const SizedBox(height: 12),
              ],
            ],
          );
        },
      ),
    ),
  );

  static String _label(String value) => switch (value) {
    'sakit' => 'Sakit Mendadak',
    'kebakaran' => 'Kebakaran',
    'kecelakaan' => 'Kecelakaan',
    _ => value,
  };
  static IconData _icon(String value) => switch (value) {
    'sakit' => Icons.local_hospital_outlined,
    'kebakaran' => Icons.local_fire_department_outlined,
    _ => Icons.car_crash_outlined,
  };
  static Color _color(String value) => switch (value) {
    'sakit' => const Color(0xFF2563EB),
    'kebakaran' => const Color(0xFFD92D20),
    _ => const Color(0xFFF59E0B),
  };
}

