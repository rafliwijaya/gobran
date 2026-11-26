import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/app_theme.dart';
import '../../core/common_widgets.dart';
import '../../models/app_models.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  void _openRegister(BuildContext context, AppRole role) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => RegisterScreen(role: role)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                children: [
                  const SizedBox(height: 48),
                  // Logo
                  Container(
                    width: 250,
                    height: 250,
                    decoration: BoxDecoration(
                      // borderRadius: BorderRadius.circular(40),
                      // boxShadow: [
                      //   BoxShadow(
                      //     color: const Color(
                      //       0xFF00880F,
                      //     ).withValues(alpha: 0.15),
                      //     blurRadius: 24,
                      //     offset: const Offset(0, 8),
                      //   ),
                      // ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(40),
                      child: Image.asset(
                        'web/icons/bran.jpeg',
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Semua kebutuhan lokal, dalam satu aplikasi',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 15),
                  ),
                  const SizedBox(height: 56),

                  // Button Pelanggan
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.ink,
                      minimumSize: const Size.fromHeight(56),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    onPressed: () => _openRegister(context, AppRole.customer),
                    icon: const Icon(
                      Symbols.person_rounded,
                      fill: 1,
                      size: 22,
                    ),
                    label: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'Daftar sebagai Pelanggan',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Button Mitra
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primaryDark,
                      side: const BorderSide(
                        color: AppColors.primaryDark,
                        width: 1.8,
                      ),
                      minimumSize: const Size.fromHeight(56),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: () => _showPartnerChoices(context),
                    icon: const Icon(
                      Symbols.handshake_rounded,
                      fill: 1,
                      size: 22,
                    ),
                    label: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'Daftar sebagai Mitra',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 48),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Sudah punya akun? ',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const LoginScreen(),
                          ),
                        ),
                        child: const Text(
                          'Masuk',
                          style: TextStyle(
                            color: AppColors.primaryDark,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showPartnerChoices(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true, // Allow sheet to take more space if needed
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          // Added scroll view to prevent overflow
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Daftar Sebagai Mitra',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Pilih kategori kemitraan yang sesuai dengan Anda',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
              ),
              const SizedBox(height: 20),
              _partnerTile(
                context: sheetContext,
                parentContext: context,
                role: AppRole.driver,
                title: 'Mitra Driver',
                subtitle: 'Gabung menjadi ojek online atau pengiriman barang',
                icon: Symbols.moped_rounded,
                color: const Color(0xFF2563EB),
              ),
              const SizedBox(height: 12),
              _partnerTile(
                context: sheetContext,
                parentContext: context,
                role: AppRole.umkm,
                title: 'Mitra UMKM',
                subtitle: 'Jual produk makanan, minuman, dan kuliner lokal',
                icon: Symbols.storefront_rounded,
                color: const Color(0xFFF59E0B),
              ),
              const SizedBox(height: 12),
              _partnerTile(
                context: sheetContext,
                parentContext: context,
                role: AppRole.service,
                title: 'Mitra Jasa',
                subtitle: 'Tawarkan jasa servis, perbaikan, atau keterampilan',
                icon: Symbols.home_repair_service_rounded,
                color: const Color(0xFF8B5CF6),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _partnerTile({
    required BuildContext context,
    required BuildContext parentContext,
    required AppRole role,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 15,
            color: color,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        trailing: Icon(Icons.chevron_right, color: color),
        onTap: () {
          Navigator.pop(context);
          _openRegister(parentContext, role);
        },
      ),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  bool _obscure = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await AuthService().signIn(email: _email.text, password: _password.text);
      if (mounted) Navigator.popUntil(context, (route) => route.isFirst);
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        showMessage(
          context,
          e.message ?? 'Email atau password salah.',
          error: true,
        );
      }
    } catch (e) {
      if (mounted) showMessage(context, '$e', error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    appBar: AppBar(backgroundColor: Colors.white, elevation: 0),
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Masuk ke GoBran',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Gunakan email dan password yang sudah terdaftar.',
                  ),
                  const SizedBox(height: 28),
                  TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    validator: (v) => (v == null || !v.contains('@'))
                        ? 'Masukkan email yang valid.'
                        : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _password,
                    obscureText: _obscure,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        onPressed: () => setState(() => _obscure = !_obscure),
                        icon: Icon(
                          _obscure ? Icons.visibility : Icons.visibility_off,
                        ),
                      ),
                    ),
                    validator: (v) => (v?.length ?? 0) < 6
                        ? 'Password minimal 6 karakter.'
                        : null,
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _loading ? null : _submit,
                    child: _loading
                        ? const CircularProgressIndicator()
                        : const Text('Masuk'),
                  ),
                  TextButton(
                    onPressed: () async {
                      if (!_email.text.contains('@')) {
                        showMessage(
                          context,
                          'Isi email terlebih dahulu.',
                          error: true,
                        );
                        return;
                      }
                      await AuthService().sendPasswordReset(_email.text);
                      if (context.mounted) {
                        showMessage(
                          context,
                          'Tautan reset password telah dikirim.',
                        );
                      }
                    },
                    child: const Text('Lupa password?'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({required this.role, super.key});
  final AppRole role;
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fields = <String, TextEditingController>{};
  final _picker = ImagePicker();
  final _images = <String, XFile>{};
  bool _loading = false;
  bool _obscure = true;
  String _zoneId = 'babalan';

  TextEditingController c(String key) =>
      _fields.putIfAbsent(key, TextEditingController.new);

  @override
  void dispose() {
    for (final controller in _fields.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _pick(String key) async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 58,
      maxWidth: 720,
    );
    if (file != null) setState(() => _images[key] = file);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if ((widget.role == AppRole.umkm || widget.role == AppRole.service) &&
        !_images.containsKey('photo_url')) {
      showMessage(context, 'Foto profil/usaha wajib dipilih.', error: true);
      return;
    }
    setState(() => _loading = true);
    try {
      final extra = <String, dynamic>{
        if (widget.role == AppRole.driver) ...{
          'vehicle_type': c('vehicle_type').text,
          'vehicle_brand': c('vehicle_brand').text,
          'plate_number': c('plate_number').text,
        },
        if (widget.role == AppRole.umkm) ...{
          'business_name': c('business_name').text,
          'business_category': c('business_category').text,
          'business_address': c('business_address').text,
          'description': c('description').text,
        },
        if (widget.role == AppRole.service) ...{
          'service_type': c('service_type').text,
          'description': c('description').text,
        },
      };
      await AuthService().register(
        name: c('name').text,
        phone: c('phone').text,
        email: c('email').text,
        password: c('password').text,
        role: widget.role,
        zoneId: _zoneId,
        extra: extra,
      );
      final urls = <String, String>{};
      for (final entry in _images.entries) {
        urls[entry.key] = await FirestoreService().uploadImage(
          entry.value,
          'users/${FirestoreService().uid}',
        );
      }
      await FirestoreService().updateRegistrationImages(widget.role, urls);
      if (mounted) Navigator.popUntil(context, (route) => route.isFirst);
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        showMessage(context, e.message ?? 'Pendaftaran gagal.', error: true);
      }
    } catch (e) {
      if (mounted) showMessage(context, '$e', error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Daftar ${widget.role.label}')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Buat akun ${widget.role.label}',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                    const SizedBox(height: 20),
                    _requiredField(
                      'name',
                      'Nama lengkap',
                      Icons.person_outline,
                    ),
                    _requiredField(
                      'phone',
                      'Nomor HP',
                      Icons.phone_outlined,
                      keyboard: TextInputType.phone,
                    ),
                    _requiredField(
                      'email',
                      'Email',
                      Icons.email_outlined,
                      keyboard: TextInputType.emailAddress,
                      email: true,
                    ),
                    TextFormField(
                      controller: c('password'),
                      obscureText: _obscure,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          onPressed: () => setState(() => _obscure = !_obscure),
                          icon: Icon(
                            _obscure ? Icons.visibility : Icons.visibility_off,
                          ),
                        ),
                      ),
                      validator: (v) =>
                          (v?.length ?? 0) < 6 ? 'Minimal 6 karakter.' : null,
                    ),
                    const SizedBox(height: 14),
                    StreamBuilder<List<AppZone>>(
                      stream: FirestoreService().watchZones(),
                      builder: (context, snapshot) {
                        final zones = snapshot.data ?? const <AppZone>[];
                        if (zones.isEmpty) {
                          return const Text(
                            'Zona awal: Babalan',
                            style: TextStyle(color: Colors.grey),
                          );
                        }
                        if (!zones.any((z) => z.id == _zoneId)) {
                          _zoneId = zones.first.id;
                        }
                        return DropdownButtonFormField<String>(
                          initialValue: _zoneId,
                          decoration: const InputDecoration(
                            labelText: 'Zona layanan',
                            prefixIcon: Icon(Icons.map_outlined),
                          ),
                          items: zones
                              .map(
                                (z) => DropdownMenuItem(
                                  value: z.id,
                                  child: Text(z.name),
                                ),
                              )
                              .toList(),
                          onChanged: (v) =>
                              setState(() => _zoneId = v ?? zones.first.id),
                        );
                      },
                    ),
                    const SizedBox(height: 14),
                    ..._roleFields(),
                    const SizedBox(height: 18),
                    ElevatedButton(
                      onPressed: _loading ? null : _submit,
                      child: _loading
                          ? const CircularProgressIndicator()
                          : const Text('Daftar'),
                    ),
                    if (widget.role != AppRole.customer) ...[
                      const SizedBox(height: 10),
                      const Text(
                        'Akun mitra harus diverifikasi admin sebelum dapat menerima order.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _roleFields() {
    if (widget.role == AppRole.customer) {
      return [
        _imagePicker('photo_url', 'Foto profil (opsional)', required: false),
      ];
    }
    if (widget.role == AppRole.driver) {
      return [
        _requiredField(
          'vehicle_type',
          'Jenis kendaraan',
          Symbols.moped_rounded,
        ),
        _requiredField(
          'vehicle_brand',
          'Merek kendaraan',
          Icons.directions_bike,
        ),
        _requiredField('plate_number', 'Nomor plat', Icons.pin_outlined),
        _imagePicker('face_url', 'Foto wajah (opsional)', required: false),
        _imagePicker(
          'identity_url',
          'Foto KTP/STNK (opsional)',
          required: false,
        ),
      ];
    }
    if (widget.role == AppRole.umkm) {
      return [
        _requiredField('business_name', 'Nama usaha', Icons.storefront),
        _requiredField(
          'business_category',
          'Kategori usaha',
          Icons.category_outlined,
        ),
        _requiredField(
          'business_address',
          'Alamat usaha',
          Icons.location_on_outlined,
          lines: 2,
        ),
        _requiredField(
          'description',
          'Deskripsi singkat',
          Icons.notes,
          lines: 3,
        ),
        _imagePicker('photo_url', 'Foto usaha/produk'),
      ];
    }
    return [
      _requiredField(
        'service_type',
        'Jenis jasa',
        Icons.home_repair_service_outlined,
      ),
      _requiredField('description', 'Deskripsi layanan', Icons.notes, lines: 3),
      _imagePicker('photo_url', 'Foto profil/usaha'),
    ];
  }

  Widget _requiredField(
    String key,
    String label,
    IconData icon, {
    TextInputType? keyboard,
    int lines = 1,
    bool email = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: TextFormField(
      controller: c(key),
      keyboardType: keyboard,
      maxLines: lines,
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
      validator: (v) {
        if (v == null || v.trim().isEmpty) return '$label wajib diisi.';
        if (email && !v.contains('@')) return 'Email tidak valid.';
        return null;
      },
    ),
  );

  Widget _imagePicker(String key, String label, {bool required = true}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: OutlinedButton.icon(
          onPressed: () => _pick(key),
          icon: Icon(
            _images.containsKey(key)
                ? Icons.check_circle
                : Icons.add_a_photo_outlined,
          ),
          label: Text(_images[key]?.name ?? '$label${required ? ' *' : ''}'),
        ),
      );
}
