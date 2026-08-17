/// Widget test Dashboard (Minggu 3) — menguji layar utama baru menggantikan
/// placeholder lama. Memakai SQLite in-memory via `sqflite_common_ffi`
/// (konsisten dengan helper `test/helpers/test_db.dart`).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:debt_splitter/app/services/debt_splitter_service.dart';
import 'package:debt_splitter/app/services/share_service.dart';
import 'package:debt_splitter/app/state/group_list_store.dart';
import 'package:debt_splitter/app/ui/dashboard_screen.dart';
import 'package:debt_splitter/app/ui/create_group_dialog.dart';
import 'package:debt_splitter/core/db/app_database.dart';

import 'helpers/test_db.dart';

void main() {
  setUpAll(initSqfliteFfi);

  late AppDatabase db;
  late DebtSplitterService service;
  late GroupListStore store;

  setUp(() async {
    db = await openTestDatabase();
    service = DebtSplitterService(db);
    store = GroupListStore(service);
  });

  tearDown(() async {
    await db.close();
  });

  Widget buildApp() {
    return MultiProvider(
      providers: [
        Provider<DebtSplitterService>.value(value: service),
        Provider<ShareService>.value(value: const ShareService()),
        ChangeNotifierProvider<GroupListStore>.value(value: store),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        home: const DashboardScreen(),
      ),
    );
  }

  testWidgets('Dashboard menampilkan judul & empty-state saat belum ada grup', (
    tester,
  ) async {
    await tester.pumpWidget(buildApp());
    // Tunggu frame loading + FutureBuilder/ChangeNotifier.
    await tester.pumpAndSettle();

    expect(find.text('Debt-Splitter'), findsOneWidget);
    expect(find.text('Belum ada grup'), findsOneWidget);
    expect(find.byIcon(Icons.group_add), findsOneWidget);
  });

  testWidgets('FAB grup-baru tersedia & membuka dialog', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    expect(find.text('Grup Baru'), findsOneWidget);
    await tester.tap(find.text('Grup Baru'));
    await tester.pumpAndSettle();

    // Dialog terbuka.
    expect(find.byType(CreateGroupDialog), findsOneWidget);
    expect(find.text('Nama grup'), findsOneWidget);
    expect(find.text('Anggota'), findsOneWidget);
  });

  testWidgets('CreateGroupDialog menolak submit bila kosong', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Grup Baru'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Buat'));
    await tester.pumpAndSettle();

    // Validator memunculkan pesan error.
    expect(find.text('Nama grup wajib diisi'), findsOneWidget);
    expect(find.text('Minimal satu anggota'), findsOneWidget);
  });

  testWidgets('membuat grup baru memperbarui daftar dashboard', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    // Buka dialog, isi nama + anggota, submit.
    await tester.tap(find.text('Grup Baru'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), 'Trip Bromo');
    await tester.enterText(
      find.byType(TextFormField).at(1),
      'Budi, Andi, Citra',
    );
    await tester.tap(find.text('Buat'));
    await tester.pumpAndSettle();

    // Dialog tertutup & grup baru tampil.
    expect(find.byType(CreateGroupDialog), findsNothing);
    expect(find.text('Trip Bromo'), findsOneWidget);
  });
}
