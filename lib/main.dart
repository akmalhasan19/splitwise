import 'package:flutter/material.dart';

void main() {
  runApp(const DebtSplitterApp());
}

/// Titik masuk utama aplikasi.
///
/// Prinsip OFFLINE-FIRST (lihat `docs/architecture.md` §2):
/// - 100% berjalan lokal, tanpa backend server & tanpa login/auth;
/// - tidak ada panggilan jaringan pada fitur inti;
/// - seluruh data disimpan di SQLite lokal perangkat.
class DebtSplitterApp extends StatelessWidget {
  const DebtSplitterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Debt-Splitter',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF21A366)),
        useMaterial3: true,
      ),
      home: const HomePlaceholderScreen(),
    );
  }
}

/// Layar sementara sebelum UI Dashboard (Minggu 3) diimplementasikan.
class HomePlaceholderScreen extends StatelessWidget {
  const HomePlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Debt-Splitter')),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.wifi_off, size: 48),
            SizedBox(height: 12),
            Text('Offline-First · tanpa login, tanpa server'),
            SizedBox(height: 4),
            Text('Semua data tersimpan lokal di perangkat'),
          ],
        ),
      ),
    );
  }
}
