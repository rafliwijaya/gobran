import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'core/app_theme.dart';
import 'features/auth/auth_gate.dart';
import 'features/auth/splash_intro_screen.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id_ID');
  Object? firebaseError;
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } catch (error) {
    firebaseError = error;
  }
  runApp(GoBranApp(firebaseError: firebaseError));
}

class GoBranApp extends StatelessWidget {
  const GoBranApp({this.firebaseError, super.key});
  final Object? firebaseError;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GoBran',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: firebaseError == null
          ? const GoBranSplashIntroScreen(nextPage: AuthGate())
          : FirebaseSetupScreen(error: firebaseError!),
    );
  }
}

class FirebaseSetupScreen extends StatelessWidget {
  const FirebaseSetupScreen({required this.error, super.key});
  final Object error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.settings_suggest_outlined, size: 64, color: AppColors.primary),
                      const SizedBox(height: 16),
                      const Text('Hubungkan Firebase', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 12),
                      const Text(
                        'Source code GoBran sudah siap. Jalankan `flutterfire configure` dari folder proyek untuk membuat konfigurasi Firebase milik Anda, lalu jalankan ulang aplikasi.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      SelectableText('$error', style: const TextStyle(fontSize: 12, color: Colors.grey)),
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

