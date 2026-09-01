import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../models/app_models.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../services/notification_service.dart';
import '../admin/admin_dashboard.dart';
import '../home/customer_shell.dart';
import '../partner/driver_dashboard.dart';
import '../partner/service_dashboard.dart';
import '../partner/umkm_dashboard.dart';
import 'auth_screens.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: AuthService().authChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _SplashScreen();
        }
        if (snapshot.data == null) return const WelcomeScreen();
        return const _SignedInRouter();
      },
    );
  }
}

class _SplashScreen extends StatefulWidget {
  const _SplashScreen();
  @override
  State<_SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<_SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeIn;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _fadeIn = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _scale = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.elasticOut));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF00880F), Color(0xFF006B0C)],
          ),
        ),
        child: Center(
          child: FadeTransition(
            opacity: _fadeIn,
            child: ScaleTransition(
              scale: _scale,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 130,
                    height: 130,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(32),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 25,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(32),
                      child: Image.asset(
                        'web/icons/loding.png',
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(height: 48),
                  SizedBox(
                    width: 32,
                    height: 32,
                    child: CircularProgressIndicator(
                      strokeWidth: 3.0,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SignedInRouter extends StatefulWidget {
  const _SignedInRouter();

  @override
  State<_SignedInRouter> createState() => _SignedInRouterState();
}

class _SignedInRouterState extends State<_SignedInRouter> {
  bool _notificationStarted = false;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AppUser?>(
      stream: FirestoreService().watchCurrentUser(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _AccountProblem(message: '${snapshot.error}');
        }
        if (!snapshot.hasData) return const _SplashScreen();
        final user = snapshot.data;
        if (user == null) {
          return const _AccountProblem(
            message: 'Profil akun tidak ditemukan di Firestore.',
          );
        }
        if (!_notificationStarted) {
          _notificationStarted = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            NotificationService.instance.initializeForSignedInUser();
          });
        }
        if (user.role != AppRole.customer && user.role != AppRole.admin) {
          if (user.verificationStatus != 'approved') {
            return VerificationWaitingScreen(user: user);
          }
        }
        return switch (user.role) {
          AppRole.customer => CustomerShell(user: user),
          AppRole.driver => DriverDashboard(user: user),
          AppRole.umkm => UmkmDashboard(user: user),
          AppRole.service => ServiceDashboard(user: user),
          AppRole.admin => AdminDashboard(user: user),
        };
      },
    );
  }
}

class VerificationWaitingScreen extends StatelessWidget {
  const VerificationWaitingScreen({required this.user, super.key});
  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final rejected = user.verificationStatus == 'rejected';
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        rejected
                            ? Icons.cancel_outlined
                            : Icons.verified_user_outlined,
                        color: rejected ? AppColors.danger : AppColors.primary,
                        size: 72,
                      ),
                      const SizedBox(height: 18),
                      Text(
                        rejected
                            ? 'Pendaftaran ditolak'
                            : 'Menunggu verifikasi admin',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 23,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        rejected
                            ? 'Periksa kembali data dan dokumen Anda melalui admin GoBran.'
                            : 'Halo ${user.name}, akun ${user.role.label} Anda akan aktif setelah data diperiksa admin.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      OutlinedButton.icon(
                        onPressed: AuthService().signOut,
                        icon: const Icon(Icons.logout),
                        label: const Text('Keluar'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AccountProblem extends StatelessWidget {
  const _AccountProblem({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: AuthService().signOut,
              child: const Text('Kembali ke login'),
            ),
          ],
        ),
      ),
    ),
  );
}
