/// Widget test Quick-Entry Sheet — mereproduksi bug modal-overlay Provider.
///
/// Membuktikan bahwa sheet "Tambah pengeluaran" yang di-push via
/// `showModalBottomSheet` dari `GroupDetailScreen` benar-benar menampilkan
/// form (nominal, pembayar, split) — bukan layar blank putih akibat
/// `ProviderNotFoundException` karena modal overlay tidak mewarisi
/// `ChangeNotifierProvider<GroupDetailStore>` di route detail grup.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:debt_splitter/app/services/debt_splitter_service.dart';
import 'package:debt_splitter/app/services/share_service.dart';
import 'package:debt_splitter/app/state/group_list_store.dart';
import 'package:debt_splitter/app/ui/dashboard_screen.dart';
import 'package:debt_splitter/core/db/app_database.dart';

import '../helpers/test_db.dart';

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

  tearDown(() async => db.close());

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

  testWidgets(
    'FAB + pada detail grup membuka form quick-entry (bukan blank)',
    (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      // Buat grup baru dari dashboard.
      await tester.tap(find.text('Grup Baru'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).at(0), 'Trip Bromo');
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'Budi, Andi, Citra',
      );
      await tester.tap(find.text('Buat'));
      await tester.pumpAndSettle();

      // Sudah masuk layar detail grup.
      expect(find.text('Trip Bromo'), findsOneWidget);

      // Tekan FAB '+' untuk membuka quick-entry sheet.
      await tester.tap(find.byTooltip('Tambah pengeluaran'));
      await tester.pumpAndSettle();

      // Form harus terlihat — bukan sheet kosong.
      expect(find.text('Catat Pengeluaran'), findsOneWidget);
      expect(find.text('Nominal (Rp)'), findsOneWidget);
      expect(find.text('Dibayar oleh'), findsOneWidget);
      expect(find.text('Sama rata'), findsOneWidget);
      expect(find.text('Simpan'), findsOneWidget);
    },
  );
}
