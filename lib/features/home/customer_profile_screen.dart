import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/app_theme.dart';
import '../../core/common_widgets.dart';
import '../../models/app_models.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';

const _kProfileGreen = AppColors.primaryDark;
const _kProfileSoftGreen = AppColors.primaryLight;

/// Customer account & profile tab styled with a header card and preference groups.
class CustomerProfileScreen extends StatelessWidget {
  const CustomerProfileScreen({required this.user, super.key});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AppZone>>(
      stream: FirestoreService().watchZones(),
      builder: (context, snapshot) {
        final zones = snapshot.data ?? const <AppZone>[];
        final zoneName = _resolveZoneName(zones, user.zoneId);

        return ColoredBox(
          color: AppColors.background,
          child: ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              _ProfileHeader(
                user: user,
                zoneName: zoneName,
                onEdit: () => _openEditSheet(context),
              ),
              const SizedBox(height: 18),
              const _SectionHeader(title: 'Informasi Akun'),
              const SizedBox(height: 8),
              _GroupedMenuCard(
                items: [
                  _MenuRowData(
                    icon: Icons.person_outline_rounded,
                    title: 'Nama Lengkap',
                    subtitle: user.name.isEmpty ? 'Belum diisi' : user.name,
                    onTap: () => _openEditSheet(context),
                  ),
                  _MenuRowData(
                    icon: Icons.mail_outline_rounded,
                    title: 'Gmail / Email',
                    subtitle: user.email.isEmpty ? 'Belum diisi' : user.email,
                    onTap: () => _openEditSheet(context),
                  ),
                  _MenuRowData(
                    icon: Icons.location_on_outlined,
                    title: 'Lokasi Zona',
                    subtitle: zoneName,
                    onTap: () => _openEditSheet(context),
                  ),
                  _MenuRowData(
                    icon: Icons.photo_camera_outlined,
                    title: 'Foto Profil',
                    subtitle: user.photoUrl.trim().isEmpty
                        ? 'Belum ada foto profil'
                        : 'Ketuk untuk ubah atau ganti foto',
                    onTap: () => _openEditSheet(context),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const _SectionHeader(title: 'Preferensi'),
              const SizedBox(height: 8),
              _GroupedMenuCard(
                items: [
                  _MenuRowData(
                    icon: Icons.confirmation_num_outlined,
                    title: 'Voucher',
                    badgeText: 'BARU',
                    subtitle: 'Lihat voucher & promo akun Anda',
                    onTap: () => Navigator.push<void>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const VoucherScreen(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: OutlinedButton.icon(
                  onPressed: () => _confirmSignOut(context),
                  icon: const Icon(Icons.logout_rounded, size: 18),
                  label: const Text(
                    'Keluar dari akun',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFD92D20),
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: Color(0xFFF3C6C3)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _resolveZoneName(List<AppZone> zones, String zoneId) {
    for (final zone in zones) {
      if (zone.id == zoneId) return zone.name;
    }
    if (zoneId.trim().isEmpty) return 'Belum dipilih';
    return zoneId[0].toUpperCase() + zoneId.substring(1);
  }

  void _openEditSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _EditProfileSheet(user: user),
    );
  }

  Future<void> _confirmSignOut(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Keluar dari akun?'),
        content: const Text(
          'Anda perlu masuk kembali untuk menggunakan akun ini.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFD92D20),
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await AuthService().signOut();
    }
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.user,
    required this.zoneName,
    required this.onEdit,
  });

  final AppUser user;
  final String zoneName;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          height: topInset + 118,
          width: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.primaryDark, Color(0xFF3F6608)],
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                right: -16,
                top: topInset + 4,
                child: Container(
                  width: 112,
                  height: 112,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                ),
              ),
              Positioned(
                right: 36,
                top: topInset + 14,
                child: Icon(
                  Icons.verified_user_rounded,
                  size: 56,
                  color: Colors.white.withValues(alpha: 0.22),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(20, topInset + 12, 20, 0),
                child: SizedBox(
                  height: 36,
                  width: 142,
                  child: ClipRect(
                    child: OverflowBox(
                      maxHeight: 150,
                      maxWidth: 150,
                      alignment: Alignment.center,
                      child: Image.asset(
                        'web/icons/gobran-white.png',
                        width: 148,
                        height: 148,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(16, topInset + 64, 16, 0),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.grey.shade200),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: onEdit,
                  child: _ProfileAvatar(
                    photoUrl: user.photoUrl,
                    name: user.name,
                    size: 62,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.name.isEmpty ? 'Pelanggan GoBran' : user.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        user.email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: _kProfileSoftGreen,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.location_on_rounded,
                              size: 13,
                              color: _kProfileGreen,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              zoneName,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: _kProfileGreen,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Edit profil',
                  onPressed: onEdit,
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFFF3F4F6),
                  ),
                  icon: const Icon(
                    Icons.edit_outlined,
                    color: Color(0xFF1F2937),
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({
    required this.photoUrl,
    required this.name,
    required this.size,
    this.previewBytes,
  });

  final String photoUrl;
  final String name;
  final double size;
  final Uint8List? previewBytes;

  @override
  Widget build(BuildContext context) {
    final ImageProvider? provider = previewBytes != null
        ? MemoryImage(previewBytes!)
        : appImageProvider(photoUrl);
    final initial = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : 'G';

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _kProfileSoftGreen,
        border: Border.all(color: Colors.grey.shade200),
        image: provider != null
            ? DecorationImage(image: provider, fit: BoxFit.cover)
            : null,
      ),
      child: provider == null
          ? Center(
              child: Text(
                initial,
                style: TextStyle(
                  fontSize: size * 0.38,
                  fontWeight: FontWeight.w700,
                  color: _kProfileGreen,
                ),
              ),
            )
          : null,
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 18),
    child: Text(
      title,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: Colors.grey.shade700,
      ),
    ),
  );
}

class _MenuRowData {
  const _MenuRowData({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.badgeText,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String? badgeText;
  final VoidCallback onTap;
}

class _GroupedMenuCard extends StatelessWidget {
  const _GroupedMenuCard({required this.items});

  final List<_MenuRowData> items;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          children: [
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0)
                Divider(
                  height: 1,
                  indent: 52,
                  endIndent: 16,
                  color: Colors.grey.shade200,
                ),
              InkWell(
                borderRadius: BorderRadius.vertical(
                  top: i == 0 ? const Radius.circular(18) : Radius.zero,
                  bottom: i == items.length - 1
                      ? const Radius.circular(18)
                      : Radius.zero,
                ),
                onTap: items[i].onTap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        items[i].icon,
                        color: const Color(0xFF374151),
                        size: 22,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    items[i].title,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF111827),
                                    ),
                                  ),
                                ),
                                if (items[i].badgeText != null) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _kProfileGreen,
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      items[i].badgeText!,
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            if (items[i].subtitle != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                items[i].subtitle!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: Colors.grey.shade500,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EditProfileSheet extends StatefulWidget {
  const _EditProfileSheet({required this.user});

  final AppUser user;

  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _photoUrlCtrl;
  late String _zoneId;
  late String _preservedPhotoUrl;
  XFile? _pickedFile;
  Uint8List? _pickedBytes;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.user.name);
    _emailCtrl = TextEditingController(text: widget.user.email);
    _preservedPhotoUrl = widget.user.photoUrl;
    _photoUrlCtrl = TextEditingController(
      text: widget.user.photoUrl.startsWith('data:image/')
          ? ''
          : widget.user.photoUrl,
    );
    _zoneId = widget.user.zoneId;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _photoUrlCtrl.dispose();
    super.dispose();
  }

  String get _effectivePreviewUrl {
    final typedUrl = _photoUrlCtrl.text.trim();
    if (typedUrl.isNotEmpty) return typedUrl;
    return _preservedPhotoUrl;
  }

  Future<void> _pickPhoto() async {
    final selected = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 58,
      maxWidth: 720,
    );
    if (selected == null) return;
    final bytes = await selected.readAsBytes();
    if (!mounted) return;
    setState(() {
      _pickedFile = selected;
      _pickedBytes = bytes;
      _error = null;
    });
  }

  void _clearPhoto() {
    setState(() {
      _pickedFile = null;
      _pickedBytes = null;
      _preservedPhotoUrl = '';
      _photoUrlCtrl.clear();
    });
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      var finalPhotoUrl = _photoUrlCtrl.text.trim();
      if (_pickedFile != null) {
        finalPhotoUrl = await FirestoreService().uploadImage(
          _pickedFile!,
          'profiles',
        );
      } else if (finalPhotoUrl.isEmpty) {
        finalPhotoUrl = _preservedPhotoUrl;
      }

      final notice = await FirestoreService().updateCustomerProfile(
        name: _nameCtrl.text,
        email: _emailCtrl.text,
        zoneId: _zoneId,
        photoUrl: finalPhotoUrl,
      );

      if (!mounted) return;
      Navigator.pop(context);
      showMessage(
        context,
        notice ?? 'Profil berhasil diperbarui.',
      );
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset =
        MediaQuery.viewInsetsOf(context).bottom + bottomSystemInset(context);
    final hasAnyPhoto =
        _pickedBytes != null || _effectivePreviewUrl.trim().isNotEmpty;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, bottomInset + 20),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Edit Profil',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _ProfileAvatar(
                    photoUrl: _effectivePreviewUrl,
                    name: _nameCtrl.text,
                    size: 68,
                    previewBytes: _pickedBytes,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _saving ? null : _pickPhoto,
                          icon: const Icon(
                            Icons.photo_library_outlined,
                            size: 18,
                          ),
                          label: const Text('Pilih Foto'),
                        ),
                        if (hasAnyPhoto)
                          TextButton.icon(
                            onPressed: _saving ? null : _clearPhoto,
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFFD92D20),
                            ),
                            icon: const Icon(Icons.delete_outline, size: 18),
                            label: const Text('Hapus'),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _photoUrlCtrl,
                onChanged: (value) => setState(() {
                  if (value.trim().isNotEmpty) {
                    _pickedFile = null;
                    _pickedBytes = null;
                  }
                }),
                decoration: const InputDecoration(
                  labelText: 'Atau tempel URL foto profil (opsional)',
                  prefixIcon: Icon(Icons.link_rounded),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nameCtrl,
                textCapitalization: TextCapitalization.words,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Nama Lengkap',
                  prefixIcon: Icon(Icons.person_outline_rounded),
                ),
                validator: (value) => (value ?? '').trim().isEmpty
                    ? 'Nama tidak boleh kosong.'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Gmail / Email',
                  prefixIcon: Icon(Icons.mail_outline_rounded),
                ),
                validator: (value) {
                  final text = (value ?? '').trim();
                  if (text.isEmpty || !text.contains('@') || !text.contains('.')) {
                    return 'Masukkan alamat email yang valid.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              StreamBuilder<List<AppZone>>(
                stream: FirestoreService().watchZones(),
                builder: (context, snapshot) {
                  final zones = snapshot.data ?? const <AppZone>[];
                  if (zones.isEmpty) {
                    return TextFormField(
                      initialValue: _zoneId,
                      decoration: const InputDecoration(
                        labelText: 'Lokasi Zona',
                        prefixIcon: Icon(Icons.location_on_outlined),
                      ),
                      onChanged: (v) => _zoneId = v.trim(),
                      validator: (v) => (v ?? '').trim().isEmpty
                          ? 'Lokasi zona wajib diisi.'
                          : null,
                    );
                  }
                  final effectiveZone = zones.any((z) => z.id == _zoneId)
                      ? _zoneId
                      : zones.first.id;
                  _zoneId = effectiveZone;
                  return DropdownButtonFormField<String>(
                    initialValue: effectiveZone,
                    decoration: const InputDecoration(
                      labelText: 'Lokasi Zona',
                      prefixIcon: Icon(Icons.location_on_outlined),
                    ),
                    items: zones
                        .map(
                          (z) => DropdownMenuItem(
                            value: z.id,
                            child: Text(z.name),
                          ),
                        )
                        .toList(),
                    onChanged: _saving
                        ? null
                        : (v) {
                            if (v != null) setState(() => _zoneId = v);
                          },
                  );
                },
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                FormErrorBox(message: _error!),
              ],
              const SizedBox(height: 18),
              FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: _kProfileGreen,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Simpan Perubahan',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Dummy voucher page shown when tapping Voucher on the profile screen.
class VoucherScreen extends StatelessWidget {
  const VoucherScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Voucher'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF111827),
        elevation: 0.5,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: const BoxDecoration(
                  color: _kProfileSoftGreen,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.confirmation_num_outlined,
                  size: 38,
                  color: _kProfileGreen,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Belum ada voucher',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Voucher promo yang Anda klaim atau terima akan muncul di sini.',
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
