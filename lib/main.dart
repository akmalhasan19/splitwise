import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:debt_splitter/app/services/backup_service.dart';
import 'package:debt_splitter/app/services/debt_splitter_service.dart';
import 'package:debt_splitter/app/services/share_service.dart';
import 'package:debt_splitter/app/state/group_list_store.dart';
import 'package:debt_splitter/app/ui/dashboard_screen.dart';
import 'package:debt_splitter/core/db/app_database.dart';

/// Titik masuk utama aplikasi.
///
/// Prinsip OFFLINE-FIRST (lihat `docs/architecture.md` §2):
/// - 100% berjalan lokal, tanpa backend server & tanpa login/auth;
/// - tidak ada panggilan jaringan pada fitur inti;
/// - seluruh data disimpan di SQLite lokal perangkat.
void main() {
  runApp(const DebtSplitterApp());
}

/// Membangun root [MultiProvider]berisi DB + service + store yang dipakai
/// seluruh layar. Koneksi DB dibuka idempoten via singleton [AppDatabase.open]
/// (sekali per proses).
class DebtSplitterApp extends StatefulWidget {
  const DebtSplitterApp({super.key});

  @override
  State<DebtSplitterApp> createState() => _DebtSplitterAppState();
}

class _DebtSplitterAppState extends State<DebtSplitterApp> {
  final Future<_Bootstrap> _boot = _bootstrap();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_Bootstrap>(
      future: _boot,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const MaterialApp(
            debugShowCheckedModeBanner: false,
            home: _BootingScreen(),
          );
        }
        if (snap.hasError) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            home: _BootErrorView(error: snap.error!),
          );
        }
        final boot = snap.data!;
        // MultiProvider membungkus MaterialApp ( Navigator) sehingga
        // provider tersedia di seluruh route — termasuk route yang di-push dari
        // Dashboard (GroupDetailScreen), yang juga membaca service via provider.
        return MultiProvider(
          providers: [
            Provider<DebtSplitterService>.value(value: boot.service),
            Provider<ShareService>.value(value: const ShareService()),
            Provider<BackupService>.value(value: const BackupService()),
            ChangeNotifierProvider(create: (_) => GroupListStore(boot.service)),
          ],
          child: MaterialApp(
            title: 'Debt-Splitter',
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF21A366),
              ),
              useMaterial3: true,
            ),
            home: const DashboardScreen(),
          ),
        );
      },
    );
  }
}

/// Hasil bootstrap: koneksi DB live + service yang sudah disuntikkan.
class _Bootstrap {
  const _Bootstrap({required this.service});

  final DebtSplitterService service;
}

Future<_Bootstrap> _bootstrap() async {
  final db = await AppDatabase.open();
  final service = DebtSplitterService(db);
  return _Bootstrap(service: service);
}

class _BootingScreen extends StatelessWidget {
  const _BootingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

class _BootErrorView extends StatelessWidget {
  const _BootErrorView({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              const Text('Gagal memulai database lokal'),
              const SizedBox(height: 4),
              Text('$error', textAlign: TextAlign.center, maxLines: 5),
            ],
          ),
        ),
      ),
    );
  }
}
